"""
DeepSeek 工作进程 - 每次独立启动，使用复制 profile
用法: python _deepseek_worker.py <prompt_file> <profile_dir>
"""
import sys, os, time
from playwright.sync_api import sync_playwright

EDGE_BINARY = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

prompt_file = sys.argv[1]
profile_dir = sys.argv[2]  # 由调用方创建的临时 profile 目录

with open(prompt_file, 'r', encoding='utf-8-sig') as f:
    prompt = f.read().strip()

t0 = time.time()
with sync_playwright() as p:
    context = p.chromium.launch_persistent_context(
        user_data_dir=profile_dir,
        executable_path=EDGE_BINARY,
        headless=True,
        viewport={'width':1280,'height':800},
    )
    page = context.pages[0] if context.pages else context.new_page()
    page.goto('https://chat.deepseek.com', timeout=30000, wait_until='domcontentloaded')
    page.wait_for_timeout(2000)
    textarea = page.wait_for_selector('textarea:not([disabled])', timeout=15000)
    textarea.click()
    textarea.fill("")
    page.wait_for_timeout(200)
    textarea.fill(prompt)
    page.wait_for_timeout(300)
    page.keyboard.press('Enter')
    sec = lambda: time.time() - t0
    print(f'[{sec():.1f}s] 已发送', file=sys.stderr, flush=True)
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
    if answer:
        print(answer, flush=True)
        print(f'[{sec():.1f}s] 成功', file=sys.stderr, flush=True)
    else:
        print('ERROR: 超时', file=sys.stderr, flush=True)
        sys.exit(1)
    context.close()