@echo off
chcp 65001 >nul
title OCS AI 答题助手 - 启动引导

setlocal enabledelayedexpansion

echo =============================================
echo   OCS AI 答题助手 - 启动引导
echo =============================================
echo.

REM ====== 1. 检查 Python ======
echo [1/4] 检查 Python 环境...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] 未检测到 Python，请先安装 Python 3.10+
    echo     下载地址: https://www.python.org/downloads/
    echo     安装时记得勾选 "Add Python to PATH"
    pause
    exit /b 1
)
for /f "delims=" %%i in ('python --version') do set PY_VER=%%i
echo     ✓ %PY_VER%
echo.

REM ====== 2. 检查依赖 ======
echo [2/4] 检查依赖...
python -c "import playwright" >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] 缺少 playwright 库，正在安装...
    pip install playwright -i https://pypi.tuna.tsinghua.edu.cn/simple
    if !errorlevel! neq 0 (
        echo [!] pip 安装失败，尝试直接安装...
        pip install playwright
    )
    echo     安装浏览器内核（首次需要，稍等）...
    python -m playwright install chromium
) else (
    echo     ✓ playwright 库已安装
)
echo.

REM ====== 3. 选择后端 ======
echo [3/4] 选择答题后端：
echo.
echo     1 - DeepSeek 网页版（需账号，免费，推荐）
echo     2 - Ollama 本地模型（需自行部署模型）
echo.
set /p BACKEND="请输入数字 (1 或 2): "

if "%BACKEND%"=="1" (
    echo.
    echo     ✓ 已选择 DeepSeek 网页版后端
    echo.
    echo [4/4] 检查登录状态...
    
    REM 检查 edge_profile 目录是否存在
    if not exist "%~dp0edge_profile\Default" (
        echo     [!] 未检测到 DeepSeek 登录信息，请按以下步骤操作：
        echo.
        echo     步骤 1：启动 Edge 浏览器（会自动打开）
        pause
        start "" "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --user-data-dir="%~dp0edge_profile" --no-first-run
        echo.
        echo     步骤 2：在打开的浏览器中访问 https://chat.deepseek.com
        echo     步骤 3：登录你的 DeepSeek 账号
        echo     步骤 4：登录成功后关闭浏览器，回到本窗口按任意键继续
        echo.
        pause
        echo.
        echo     ✓ 登录状态已保存
    ) else (
        echo     ✓ 已检测到登录信息
    )
    echo.
    echo ============================================
    echo  启动 DeepSeek 后端...
    echo ============================================
    echo.
    python "%~dp0app.py"
    
) else if "%BACKEND%"=="2" (
    echo.
    echo     ✓ 已选择 Ollama 本地模型后端
    echo.
    echo [4/4] 检查 Ollama 运行状态...
    
    REM 检查 Ollama 是否在运行
    curl -s http://localhost:11434 >nul 2>&1
    if %errorlevel% neq 0 (
        echo     [!] Ollama 未运行，请先启动 Ollama
        echo     如果已安装 Ollama，在开始菜单中搜索 "Ollama" 并启动
        echo     启动后回到本窗口按任意键继续
        pause
    ) else (
        echo     ✓ Ollama 正在运行
    )
    echo.
    echo ============================================
    echo  启动 Ollama 后端...
    echo ============================================
    echo.
    python "%~dp0app.py" --mode ollama
    
) else (
    echo.
    echo [!] 输入无效，请输入 1 或 2
    echo.
    pause
    exit /b 1
)

pause