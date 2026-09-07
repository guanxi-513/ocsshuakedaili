import sys
try:
    import playwright
    import requests
    print("ok")
except ImportError:
    print("missing")