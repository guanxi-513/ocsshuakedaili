import sys
try:
    import playwright
    print("ok")
except ImportError:
    print("missing")