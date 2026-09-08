"""
DeepSeek 网页版后端 - 持久会话模式
用法:
  import deepseek_backend; answer = deepseek_backend.ask(prompt)
"""
import os, sys
import threading
import queue
import time

EDGE_PROFILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'edge_profile')
EDGE_BINARY = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

_REQUEST_QUEUE = queue.Queue()
_RESPONSE_QUEUE = queue.Queue()
_WORKER_READY = threading.Event()
_WORKER_ERROR = None


def _worker():
    """Playwright 工作线程 - 持久会话"""
    from playwright.sync_api import sync_playwright

    print("[worker] 启动...", file=sys.stderr, flush=True)
    try:
        with sync_playwright() as p:
            context = p.chromium.launch_persistent_context(
                user_data_dir=EDGE_PROFILE,
                executable_path=EDGE_BINARY,
                headless=False,
                viewport={'width':1280,'height':800},
            )
            page = context.pages[0] if context.pages else context.new_page()
            for pg in context.pages[1:]:
                pg.close()
            # 初次加载
            page.goto('https://chat.deepseek.com', timeout=30000, wait_until='domcontentloaded')
            page.wait_for_timeout(2000)
            print("[worker] 就绪", file=sys.stderr, flush=True)
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
        print(f"[worker] 初始化失败: {e}", file=sys.stderr, flush=True)
        global _WORKER_ERROR
        _WORKER_ERROR = e
        _WORKER_READY.set()


def _do_ask(page, prompt: str) -> str:
    """发送问题 → 校验发送成功 → 等待回复完成 → 提取答案"""
    t0 = time.time()

    def _send():
        textarea = page.wait_for_selector('textarea:not([disabled])', timeout=15000)
        textarea.click()
        page.wait_for_timeout(300)
        textarea.fill("")
        page.wait_for_timeout(200)
        textarea.fill(prompt)
        page.wait_for_timeout(300)
        page.keyboard.press('Enter')

    # 发送 + 校验（最多重试 2 次，用题目片段做锚点）
    prefix = prompt.split('\n')[0][:10]
    sent = False
    for attempt in range(3):
        if attempt > 0:
            print(f'[{time.time()-t0:.1f}s] 发送检查未通过，重试 {attempt}', file=sys.stderr, flush=True)
        _send()
        page.wait_for_timeout(1500)
        try:
            sent = page.evaluate('(p) => document.body.innerText.includes(p)', prefix)
        except Exception:
            sent = False
        if sent:
            break

    print(f'[{time.time()-t0:.1f}s] 已发送 (校验{"通过" if sent else "未通过"})', file=sys.stderr, flush=True)

    # 记录页面文本长度，据此判断 AI 是否仍在生成（文本在变长则继续等）
    def _text_len():
        try:
            return len(page.evaluate('() => document.body.innerText'))
        except Exception:
            return None

    last_len = -1
    stable = 0
    answer = None
    for _ in range(90):
        page.wait_for_timeout(1000)
        cur_len = _text_len()
        if cur_len is None:
            continue
        if cur_len != last_len:
            last_len = cur_len
            stable = 0
        else:
            stable += 1
        # 整页文本连续 5 秒不再变长，认为回复完成
        if stable >= 5:
            # 从页面文本中提取"单独的纯字母答案行"（如 A / ACD）
            try:
                answer = page.evaluate('''() => {
                    const lines = document.body.innerText.split('\\n').map(l => l.trim()).filter(l => l.length > 0);
                    const candidates = [];
                    for (const line of lines) {
                        if (/^[A-H]{1,8}$/.test(line)) {
                            candidates.push(line.toUpperCase());
                        }
                    }
                    return candidates.length ? candidates[candidates.length - 1] : null;
                }''')
            except Exception:
                answer = None
            if answer:
                break

    if not answer:
        raise TimeoutError('DeepSeek 回复超时')

    print(f'[{time.time()-t0:.1f}s] 成功 (答案字母={answer})', file=sys.stderr, flush=True)
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
        print('用法: python deepseek_backend.py <prompt_file>', file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1], 'r', encoding='utf-8-sig') as f:
        prompt = f.read().strip()
    answer = ask(prompt)
    sys.stdout.write(answer)
    sys.stdout.flush()