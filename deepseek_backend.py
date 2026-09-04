"""
DeepSeek 网页版后端 - 持久会话模式
用法:
  import deepseek_backend; answer = deepseek_backend.ask(prompt)
"""
import os, sys
import threading
import queue
import time

EDGE_PROFILE = r'd:\appppp\ocs\edge_profile'
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
                headless=True,
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
    """刷新页面 → 发送问题 → 获取答案"""
    t0 = time.time()

    # 刷新页面（比重新 goto 快很多）
    page.reload(wait_until='domcontentloaded')
    page.wait_for_timeout(1500)

    textarea = page.wait_for_selector('textarea:not([disabled])', timeout=15000)
    textarea.click()
    textarea.fill("")
    page.wait_for_timeout(200)
    textarea.fill(prompt)
    page.wait_for_timeout(300)
    page.keyboard.press('Enter')

    print(f'[{time.time()-t0:.1f}s] 已发送', file=sys.stderr, flush=True)

    answer = None
    for i in range(90):
        page.evaluate('window.scrollTo(0, document.body.scrollHeight)')
        page.wait_for_timeout(500)
        replies = page.query_selector_all('.ds-assistant-message-main-content')
        if len(replies) >= 1:
            last = replies[-1]
            loading = (last.query_selector('[class*="cursor"]') or
                       last.query_selector('[class*="blink"]') or
                       last.query_selector('[class*="loading"]'))
            if not loading:
                page.wait_for_timeout(1000)
                replies = page.query_selector_all('.ds-assistant-message-main-content')
                if len(replies) >= 1:
                    answer = replies[-1].inner_text().strip()
                    if answer and len(answer) > 1:
                        break
        page.wait_for_timeout(1000)

    if not answer:
        raise TimeoutError('DeepSeek 回复超时')

    print(f'[{time.time()-t0:.1f}s] 成功', file=sys.stderr, flush=True)
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