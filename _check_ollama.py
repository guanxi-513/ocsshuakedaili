import subprocess
import json
import sys

def check_ollama_models():
    try:
        result = subprocess.run(
            ["ollama", "list"],
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.returncode != 0:
            print("none")
            return
        
        lines = result.stdout.strip().split("\n")
        # 第一行是标题，跳过
        if len(lines) <= 1:
            print("none")
            return
        
        models = []
        for line in lines[1:]:
            parts = line.split()
            if parts:
                models.append(parts[0])
        
        if models:
            print(", ".join(models))
        else:
            print("none")
    except Exception:
        print("none")

if __name__ == "__main__":
    check_ollama_models()