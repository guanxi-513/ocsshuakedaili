"""检查 Ollama 是否有可用模型"""
import json, urllib.request, sys

try:
    data = json.loads(urllib.request.urlopen('http://localhost:11434/api/tags', timeout=5).read())
    models = [m['name'] for m in data.get('models', [])]
    if models:
        print(','.join(models))
    else:
        print('none')
except Exception:
    print('none')