"""
豆包网页版后端 - 持久会话模式
用法:
  import doubao_backend; answer = doubao_backend.ask(prompt)
"""
import os, sys
import threading
import queue
import time

EDGE_PROFILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'edge_profile')
EDGE_BINARY = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
DOUBAO_URL = 'https://www.doubao.com/chat'

_REQUEST_QUEUE = queue.Queue()
_RESPONSE_QUEUE = queue.Queue()
_WORKER_READY = threading.Event()
_WORKER_ERROR = None
_DEBUG_DIR = os.path.dirname(__file__)


def _worker():
    from playwright.sync_api import sync_playwright

    print("[doubao-worker] 启动...", file=sys.stderr, flush=True)
    try:
        with sync_playwright() as p:
            context = p.chromium.launch_persistent_context(
                user_data_dir=EDGE_PROFILE,
                executable_path=EDGE_BINARY,
                headless=False,
                viewport={'width': 1280, 'height': 800},
            )
            page = context.pages[0] if context.pages else context.new_page()
            for pg in context.pages[1:]:
                pg.close()
            page.goto(DOUBAO_URL, timeout=60000, wait_until='domcontentloaded')
            page.wait_for_timeout(3000)

            # 等待用户登录（可见窗口，用户自己登录）
            print("="*60, file=sys.stderr, flush=True)
            print("[doubao-worker] 浏览器窗口已打开，请在浏览器中登录豆包账号", file=sys.stderr, flush=True)
            print("[doubao-worker] 登录后，等待输入框出现...", file=sys.stderr, flush=True)
            print("="*60, file=sys.stderr, flush=True)

            try:
                page.wait_for_selector('.ProseMirror[role="textbox"]', timeout=120000)
                print("[doubao-worker] 已检测到登录状态", file=sys.stderr, flush=True)
            except Exception:
                print("[doubao-worker] 等待登录超时，继续尝试...", file=sys.stderr, flush=True)

            print("[doubao-worker] 就绪", file=sys.stderr, flush=True)
            _WORKER_READY.set()

            while True:
                prompt = _REQUEST_QUEUE.get()
                if prompt is None:
                    break
                try:
                    answer = _do_ask(page, prompt)
                    _RESPONSE_QUEUE.put(answer)
                except Exception as e:
                    _RESPONSE_QUEUE.put(e)

            context.close()
    except Exception as e:
        print(f"[doubao-worker] 初始化失败: {e}", file=sys.stderr, flush=True)
        global _WORKER_ERROR
        _WORKER_ERROR = e
        _WORKER_READY.set()


def _do_ask(page, prompt: str) -> str:
    t0 = time.time()

    # 不刷新页面，直接清空输入框（避免触发人机验证）
    editor = page.wait_for_selector('.ProseMirror[role="textbox"]', timeout=20000)
    page.wait_for_timeout(500)
    editor.click()
    page.wait_for_timeout(500)
    page.keyboard.press('Control+a')
    page.wait_for_timeout(200)
    page.keyboard.press('Delete')
    page.wait_for_timeout(300)
    # 用剪贴板粘贴的方式设置编辑器内容
    page.evaluate('''(text) => {
        const ta = document.createElement('textarea');
        ta.value = text;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        ta.remove();
    }''', prompt)
    page.wait_for_timeout(300)
    editor.focus()
    page.wait_for_timeout(200)
    page.keyboard.press('Control+v')
    page.wait_for_timeout(800)

    # 发送
    page.keyboard.press('Enter')
    page.wait_for_timeout(3000)
    print(f'[{time.time()-t0:.1f}s] 已发送', file=sys.stderr, flush=True)

    # 等待 AI 完整回复 — 监听 body.innerText 稳定后，找 prompt 位置的回复
    answer = None
    prev_text = None
    stable_count = 0

    for i in range(90):
        page.wait_for_timeout(1000)

        try:
            current_text = page.evaluate('''() => {
                return document.body.innerText;
            }''')
        except Exception:
            continue

        if not current_text:
            continue

        if current_text == prev_text:
            stable_count += 1
        else:
            stable_count = 0
            prev_text = current_text

        # 文本连续 5 秒没变化，认为 AI 已生成完毕
        if stable_count >= 5:
            # 用 JS 找 prompt 之后的 AI 回复（找最后出现的 prompt）
            answer = page.evaluate('''(promptPrefix) => {
                const text = document.body.innerText;
                const lines = text.split('\\n').map(l => l.trim()).filter(l => l.length > 0);
                // 找最后一个包含 prompt 的行
                let promptIdx = -1;
                for (let i = lines.length - 1; i >= 0; i--) {
                    if (lines[i].includes(promptPrefix)) {
                        promptIdx = i;
                        break;
                    }
                }
                if (promptIdx < 0 || promptIdx + 1 >= lines.length) return null;
                // 取 prompt 之后的所有文本，直到遇到侧边栏/UI 关键词
                const result = [];
                for (let i = promptIdx + 1; i < lines.length; i++) {
                    const line = lines[i];
                    if (['对话','图像生成','帮我写作','视频生成','解题答疑','AI 搜索','AI 阅读','代码','夸夸','翻译','PPT','PDF','发消息','按住空格','深度思考','联网搜索','分享','删除','导出','发起对话','豆包','新工作任务','Ctrl J','新对话','Ctrl Shift K','定时任务','技能 · 连接器','云盘','API 服务','更多','项目','汉堡','最近','下载电脑版','登录','登录以','To pick up','拖放文件','ProseMirror','tiptap'].includes(line)) {
                        break;
                    }
                    if (line.endsWith('？') || line.endsWith('?')) {
                        break;
                    }
                    if (/^(今天|昨天|前天|\\d{1,2}月\\d{1,2}日)\\s*\\d{1,2}:\\d{2}/.test(line)) {
                        continue;
                    }
                    result.push(line);
                }
                return result.join('\\n') || null;
            }''', prompt[:8])
            if answer:
                break

        if i % 30 == 0 and i > 0:
            page.screenshot(path=os.path.join(_DEBUG_DIR, f'_doubao_poll_{i}.png'))

    if not answer:
        page.screenshot(path=os.path.join(_DEBUG_DIR, '_doubao_timeout.png'))
        raise TimeoutError('豆包回复超时 (90s)')

    print(f'[{time.time()-t0:.1f}s] 成功 ({len(answer)} 字符)', file=sys.stderr, flush=True)
    return answer


_thread = threading.Thread(target=_worker, daemon=True)
_thread.start()


def ask(prompt: str, timeout: int = 180) -> str:
    _WORKER_READY.wait(timeout=30)
    if _WORKER_ERROR:
        raise RuntimeError(f'工作线程初始化失败: {_WORKER_ERROR}')

    _REQUEST_QUEUE.put(prompt)
    result = _RESPONSE_QUEUE.get(timeout=timeout)
    if isinstance(result, Exception):
        raise result
    return result


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('用法: python doubao_backend.py <prompt_file>', file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        prompt = f.read().strip()
    answer = ask(prompt)
    sys.stdout.write(answer)
    sys.stdout.flush()