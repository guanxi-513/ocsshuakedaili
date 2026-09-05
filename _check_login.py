"""检查 edge_profile 中是否有有效的登录 Cookie"""
import os, sys

profile_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'edge_profile')
cookies_path = os.path.join(profile_dir, 'Default', 'Cookies')

if os.path.exists(cookies_path) and os.path.getsize(cookies_path) > 100:
    print('ok')
else:
    print('need_login')