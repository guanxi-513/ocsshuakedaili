"""
OCS 自动答题服务 - 对接本地 Ollama
===================================
OCS 浏览器插件 → 本服务 → Ollama → 返回答案

完全兼容 OCS 题库配置格式：
  URL: http://localhost:8080/search?title=${title}&type=${type}&options=${options}
  Handler: return (res)=> [undefined, res[1]]
  响应格式: [null, "答案内容"]
"""

import json
import re
import urllib.parse
import os
import uuid
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
from datetime import datetime


class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    """支持并发处理请求的 HTTP 服务器"""
    pass

# 日志文件路径
LOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "server.log")


def log(msg: str):
    """同时输出到控制台和日志文件"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {msg}"
    print(line)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass

import sys
import requests
import subprocess
PYTHON_EXE = sys.executable
BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))

# 导入 DeepSeek 后端模块（仅在 DeepSeek 模式下导入）
# 所有问题都在同一个 DeepSeek 聊天窗口发送，不会每次开新对话
sys.path.insert(0, BACKEND_DIR)


# ============================================================
# 全局配置
# ============================================================
PORT = 8080
MODEL_NAME = "qwen2.5:7b"                     # Ollama 默认模型
CURRENT_MODEL = MODEL_NAME
BACKEND_MODE = "deepseek"                     # 默认使用 DeepSeek 后端
OLLAMA_BASE_URL = "http://localhost:11434"
OLLAMA_TAGS_URL = f"{OLLAMA_BASE_URL}/api/tags"

# 支持命令行参数：--mode ollama / --mode doubao
if "--mode" in sys.argv:
    idx = sys.argv.index("--mode")
    if idx + 1 < len(sys.argv):
        mode = sys.argv[idx + 1].lower()
        if mode in ("ollama", "deepseek", "doubao"):
            BACKEND_MODE = mode

# 根据模式按需导入
if BACKEND_MODE == "deepseek":
    import deepseek_backend as ds_backend
elif BACKEND_MODE == "doubao":
    import doubao_backend as db_backend


def call_ollama(prompt: str, system_prompt: str = "") -> str:
    """调用本地 Ollama 获取答案"""
    payload = {
        "model": CURRENT_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {"num_predict": 512, "temperature": 0.1},
    }
    if system_prompt:
        payload["system"] = system_prompt
    resp = requests.post(
        f"{OLLAMA_BASE_URL}/api/generate",
        json=payload,
        timeout=120,
    )
    resp.raise_for_status()
    return resp.json().get("response", "").strip()


def normalize_type(raw_type: str) -> str:
    """标准化题型"""
    t = raw_type.strip().lower()
    if t in ("single", "1", "单选", "单选题"):
        return "single"
    if t in ("multiple", "2", "多选", "多选题"):
        return "multiple"
    if t in ("judgement", "3", "判断", "判断题"):
        return "judgement"
    if t in ("completion", "4", "填空", "填空题"):
        return "completion"
    return "single"


def clean_title(raw_title: str) -> str:
    """清洗题目，去掉 HTML 标签和多余空白"""
    from html import unescape
    title = unescape(raw_title)
    title = re.sub(r'<[^>]+>', '', title)
    title = re.sub(r'\s+', ' ', title).strip()
    return title


def clean_options_raw(raw_options: str) -> str:
    """清洗原始选项字符串"""
    cleaned = raw_options.strip()
    # 去掉可能的 HTML 标签
    cleaned = re.sub(r'<[^>]+>', '', cleaned)
    # 标准化换行
    cleaned = cleaned.replace('\\n', '\n').replace('\r\n', '\n')
    # 去掉空行
    lines = [l.strip() for l in cleaned.split('\n') if l.strip()]
    return '\n'.join(lines)


def format_options_with_labels(options_str: str) -> str:
    """将选项格式化为 A. xxx 形式"""
    import string
    lines = [l.strip() for l in options_str.split('\n') if l.strip()]
    result = []
    for i, line in enumerate(lines):
        if i < 26:
            letter = string.ascii_uppercase[i]
            # 去掉已存在的字母前缀
            cleaned = re.sub(r'^[A-Za-z]\.\s*', '', line)
            result.append(f"{letter}. {cleaned}")
        else:
            result.append(line)
    return '\n'.join(result)


def build_system_prompt(qtype: str) -> str:
    """构建系统提示词"""
    prompts = {
        "single": "你是一个答题助手。请直接回答单选题的答案，只输出答案内容，不要解释。",
        "multiple": "你是一个答题助手。请回答多选题的所有正确答案，用 === 分隔多个答案，例如 A===C，只输出答案字母，不要解释。",
        "judgement": "你是一个答题助手。请回答判断题，输出 '正确' 或 '错误'，不要解释。",
        "completion": "你是一个答题助手。请回答填空题，直接输出答案，不要解释。",
    }
    return prompts.get(qtype, "你是一个答题助手，请直接给出答案，不要解释。")


def build_prompt(title: str, options: str, qtype: str) -> str:
    """构建发送给 AI 的提示词"""
    type_names = {
        "single": "单选题", "multiple": "多选题",
        "judgement": "判断题", "completion": "填空题",
    }
    type_name = type_names.get(qtype, "题目")
    prompt_parts = [f"【{type_name}】{title}"]
    if options:
        prompt_parts.append(f"\n选项：\n{options}")
    prompt_parts.append("\n\n请直接给出答案，不要解释。")
    return "".join(prompt_parts)


def call_deepseek(prompt: str) -> str:
    """直接调用 deepseek_backend 模块（全局会话复用）"""
    return ds_backend.ask(prompt)


def call_doubao(prompt: str) -> str:
    """直接调用 doubao_backend 模块（全局会话复用）"""
    return db_backend.ask(prompt)


# ============================================================
# 答案匹配逻辑
# ============================================================

def parse_options(options: str) -> list:
    """解析选项字符串为列表"""
    lines = options.strip().split("\n")
    result = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        # 去掉 A. B. C. D. 前缀，保留内容
        cleaned = re.sub(r'^[A-Za-z]\.\s*', '', line)
        result.append(cleaned.strip())
    return result


def _match_single(answer: str, option_list: list) -> str:
    """单个答案的匹配逻辑"""
    answer = answer.strip()
    # 去掉空格后比较（AI 可能在选项内容中加空格）
    answer_no_space = answer.replace(' ', '')

    # 精确匹配（选项完整内容）
    for opt in option_list:
        if opt == answer:
            return opt

    # 去空格后匹配
    for opt in option_list:
        if opt.replace(' ', '') == answer_no_space:
            return opt

    # 包含匹配（AI 答案包含在选项中，或选项包含在 AI 答案中）
    for opt in option_list:
        if answer in opt or opt in answer:
            return opt
        # 去空格后包含匹配
        if answer_no_space in opt.replace(' ', '') or opt.replace(' ', '') in answer_no_space:
            return opt

    # 字母编号匹配：如果 AI 返回了 A/B/C/D 等字母，映射到选项索引
    letter_map = {
        "a": 0, "b": 1, "c": 2, "d": 3, "e": 4, "f": 5, "g": 6, "h": 7,
        "A": 0, "B": 1, "C": 2, "D": 3, "E": 4, "F": 5, "G": 6, "H": 7,
    }
    answer_clean = answer.strip()
    if answer_clean in letter_map:
        idx = letter_map[answer_clean]
        if idx < len(option_list):
            return option_list[idx]

    return ""


def match_answer(ai_answer: str, option_list: list) -> str:
    """
    将 AI 返回的答案与选项列表进行匹配。
    返回匹配到的选项完整内容。
    """
    ai_answer = ai_answer.strip()

    letter_map = {
        "a": 0, "b": 1, "c": 2, "d": 3, "e": 4, "f": 5, "g": 6, "h": 7,
        "A": 0, "B": 1, "C": 2, "D": 3, "E": 4, "F": 5, "G": 6, "H": 7,
    }

    # 先尝试逐行匹配（兼容 AI 直接输出字母/内容的情况）
    lines = ai_answer.split('\n')
    for line in lines:
        line = line.strip()
        if not line:
            continue
        # 跳过 AI 回显的选项行（如 "A. 上海" "B. 北京"）
        if re.match(r'^[A-Za-z]\.\s', line):
            continue
        # 跳过 AI 回显的"选项："行
        if line.startswith('选项') or line.startswith('答案'):
            continue
        found = _match_single(line, option_list)
        if found:
            return found

    # 从 AI 回答中提取字母答案（仅提取"干净"的字母行，排除回显的选项行）
    # 把回显选项行去掉后再提取字母
    clean_lines = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        if re.match(r'^[A-Za-z]\.\s', line):  # 跳过 "A. xxx"
            continue
        if line.startswith('选项') or line.startswith('答案'):
            continue
        clean_lines.append(line)

    clean_text = ' '.join(clean_lines)
    found_letters = []
    for ch in clean_text:
        if ch in letter_map:
            idx = letter_map[ch]
            if idx < len(option_list) and ch not in found_letters:
                found_letters.append(ch)

    # 多选题：多个字母 → === 分隔
    if len(found_letters) >= 2:
        matched = [option_list[letter_map[ch]] for ch in found_letters]
        return "===".join(matched)

    # 单选题：单个字母
    if len(found_letters) == 1:
        return option_list[letter_map[found_letters[0]]]

    # 最后尝试全文本匹配
    found = _match_single(ai_answer, option_list)
    if found:
        return found

    return ai_answer


# ============================================================
# HTTP 服务
# ============================================================

class AnswerHandler(BaseHTTPRequestHandler):
    """处理 OCS 发来的请求"""

    def do_GET(self):
        global CURRENT_MODEL
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)

        # 处理 /config 路径（返回题库配置，供 OCS URL 加载）
        if parsed.path == "/config" or parsed.path == "/config/":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            config = [
                {
                    "contentType": "json",
                    "handler": "return (res)=> [undefined, res[1]]",
                    "homepage": "http://localhost:8080",
                    "method": "get",
                    "name": "AI 自动答题",
                    "type": "GM_xmlhttpRequest",
                    "url": "http://localhost:8080/search?title=${title}&type=${type}&options=${options}",
                }
            ]
            self.wfile.write(json.dumps(config, ensure_ascii=False).encode("utf-8"))
            return

        # 处理 /models 路径（列出 Ollama 可用模型）
        if parsed.path == "/models" or parsed.path == "/models/":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            try:
                resp = requests.get(OLLAMA_TAGS_URL, timeout=10)
                resp.raise_for_status()
                data = resp.json()
                models = [m["name"] for m in data.get("models", [])]
            except Exception as e:
                models = []
            self.wfile.write(json.dumps({
                "current_model": CURRENT_MODEL,
                "models": models,
            }, ensure_ascii=False).encode("utf-8"))
            return

        # 处理 /set_model 路径（切换模型）
        if parsed.path == "/set_model" or parsed.path == "/set_model/":
            model = params.get("model", [""])[0].strip()
            if model:
                CURRENT_MODEL = model
                self._send_json({"code": 1, "message": f"已切换到模型: {CURRENT_MODEL}"})
            else:
                self._send_json({"code": 0, "message": "请指定 model 参数"})
            return

        # 处理 /current_model 路径（查看当前模型）
        if parsed.path == "/current_model" or parsed.path == "/current_model/":
            self._send_json({"code": 1, "current_model": CURRENT_MODEL})
            return

        # 处理 /set_mode 路径（切换后端模式）
        if parsed.path == "/set_mode" or parsed.path == "/set_mode/":
            global BACKEND_MODE
            mode = params.get("mode", [""])[0].strip().lower()
            if mode in ("ollama", "deepseek", "doubao"):
                BACKEND_MODE = mode
                self._send_json({"code": 1, "message": f"已切换到后端模式: {BACKEND_MODE}"})
            else:
                self._send_json({"code": 0, "message": "请指定 mode 参数: ollama、deepseek 或 doubao"})
            return

        # 处理 /status 路径（查看当前状态）
        if parsed.path == "/status" or parsed.path == "/status/":
            self._send_json({
                "code": 1,
                "backend_mode": BACKEND_MODE,
                "current_model": CURRENT_MODEL if BACKEND_MODE == "ollama" else None,
            })
            return

        # 处理 /logs 路径（查看日志）
        if parsed.path == "/logs" or parsed.path == "/logs/":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            try:
                with open(LOG_FILE, "r", encoding="utf-8", errors="replace") as f:
                    lines = f.readlines()
                # 只显示最近 200 行
                html_lines = "".join(
                    f"<div>{line.strip()}</div>" for line in lines[-200:]
                )
                html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>服务器日志</title>
<style>
body {{ background:#1e1e1e; color:#d4d4d4; font:14px/1.6 Consolas,monospace; padding:20px; }}
div {{ white-space:pre-wrap; word-break:break-all; }}
div:nth-child(odd) {{ background:#252526; }}
</style></head>
<body><h2>服务器日志（最近 200 行）</h2>
{html_lines}
<script>setTimeout(()=>location.reload(),5000)</script>
</body></html>"""
                self.wfile.write(html.encode("utf-8"))
            except FileNotFoundError:
                self.wfile.write("<h2>暂无日志</h2>".encode("utf-8"))
            return

        # 只处理 /search 路径
        if parsed.path != "/search":
            self._send_json([None, "未知路径，请使用 /search"])
            return

        # === 1. 原始数据 ===
        raw_title = params.get("title", [""])[0].strip()
        raw_type = params.get("type", [""])[0].strip()
        raw_options = params.get("options", [""])[0].strip()

        if not raw_title:
            self._send_json([None, "缺少题目参数 (title)"])
            return

        # === 2. 数据清洗 ===
        qtype = normalize_type(raw_type)
        title = clean_title(raw_title)
        cleaned_options = clean_options_raw(raw_options)
        formatted_options = format_options_with_labels(cleaned_options)
        option_list = parse_options(cleaned_options)

        # === 3. 日志：处理好的请求 ===
        type_map = {"single": "单选", "multiple": "多选", "judgement": "判断", "completion": "填空"}
        log(f"\n{'='*40}")
        log(f"========== 处理好的请求 ==========")
        log(f"题型：{type_map.get(qtype, qtype)}")
        log(f"题目：{title}")
        if formatted_options:
            log(f"选项：")
            for line in formatted_options.split("\n"):
                log(f"  {line}")
        log(f"{'='*40}")

        # 构建提示词
        prompt = build_prompt(title, formatted_options, qtype)
        system_prompt = build_system_prompt(qtype)

        log(f"\n========== 发送给 AI 的内容 ==========")
        log(prompt)
        log(f"{'='*40}")

        # 调用后端（Ollama / DeepSeek / 豆包）
        try:
            if BACKEND_MODE == "deepseek":
                ai_answer = call_deepseek(prompt)
            elif BACKEND_MODE == "doubao":
                ai_answer = call_doubao(prompt)
            else:
                ai_answer = call_ollama(prompt, system_prompt)
            log(f"\n========== AI 原始回答 ==========")
            log(f"{ai_answer[:120]}")
            log(f"{'='*40}")

            # 答案匹配
            if option_list:
                matched = match_answer(ai_answer, option_list)
                log(f"\n========== 匹配后答案 ==========")
                log(f"'{matched}'")
                log(f"{'='*40}")
            else:
                matched = ai_answer

            # 返回 [null, "答案"] 格式（匹配 OCS 配置的 handler: [undefined, res[1]]）
            self._send_json([None, matched])

        except requests.exceptions.ConnectionError:
            log("  [错误] 无法连接到 Ollama")
            self._send_json([None, "错误：无法连接到 Ollama，请确认服务已启动"])
        except Exception as e:
            log(f"  [错误] {e}")
            self._send_json([None, f"错误：{str(e)}"])

    def _send_json(self, data):
        """发送 JSON 响应"""
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))

    def do_OPTIONS(self):
        """处理 CORS 预检请求"""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def log_message(self, format, *args):
        """自定义日志格式"""
        log(f"  [{self.command}] {args[0]}")


def run_server():
    """启动 HTTP 服务"""
    server = ThreadingHTTPServer(("0.0.0.0", PORT), AnswerHandler)
    log("=" * 50)
    log("  OCS AI 答题助手 - 代理服务已启动")
    log("=" * 50)
    log(f"  Ollama 模型: {MODEL_NAME}")
    log(f"  监听端口  : {PORT}")
    log(f"  服务地址  : http://localhost:{PORT}/search")
    log("")
    log("  OCS 题库配置:")
    log(f"  URL: http://localhost:{PORT}/search?title=${{title}}&type=${{type}}&options=${{options}}")
    log(f"  Method: GET")
    log(f"  ContentType: json")
    log(f"  Handler: return (res)=> [undefined, res[1]]")
    log("=" * 50)
    log("等待请求...")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("\n服务已停止")
        server.server_close()


if __name__ == "__main__":
    run_server()