@echo off
chcp >nul 2>&1
title OCS AI 答题助手

echo =============================================
echo   OCS AI 答题助手 - 启动引导
echo =============================================
echo.

setlocal enabledelayedexpansion

REM ====== 1. 检查 Python ======
echo [1/4] 检查 Python 环境...
set PYTHON=

REM 先试 python 命令
python --version >nul 2>&1
if %errorlevel% equ 0 (
    set PYTHON=python
    echo     [OK] Python 已找到(python)
    goto :PY_OK
)

REM 再试 python3
python3 --version >nul 2>&1
if %errorlevel% equ 0 (
    set PYTHON=python3
    echo     [OK] Python 已找到(python3)
    goto :PY_OK
)

REM 逐个检查常见路径
if exist "C:\Users\HP\AppData\Local\Programs\Python\Python313\python.exe" (
    set PYTHON=C:\Users\HP\AppData\Local\Programs\Python\Python313\python.exe
    echo     [OK] 自动检测到 Python
    goto :PY_OK
)
if exist "C:\Users\HP\AppData\Local\Programs\Python\Python312\python.exe" (
    set PYTHON=C:\Users\HP\AppData\Local\Programs\Python\Python312\python.exe
    echo     [OK] 自动检测到 Python
    goto :PY_OK
)
if exist "C:\Users\HP\AppData\Local\Doubao\User Data\sandbox_runtime\bases\9f6d27f23933fb44a3a1c728c88a5ce4\python\python.exe" (
    set PYTHON=C:\Users\HP\AppData\Local\Doubao\User Data\sandbox_runtime\bases\9f6d27f23933fb44a3a1c728c88a5ce4\python\python.exe
    echo     [OK] 自动检测到 Python
    goto :PY_OK
)
if exist "C:\Python313\python.exe" (
    set PYTHON=C:\Python313\python.exe
    echo     [OK] 自动检测到 Python
    goto :PY_OK
)
if exist "C:\Python312\python.exe" (
    set PYTHON=C:\Python312\python.exe
    echo     [OK] 自动检测到 Python
    goto :PY_OK
)

REM 都没找到，让用户手动输入
:ASK_PYTHON
echo     [X] 未自动检测到 Python
echo     请手动输入 Python 路径(例如 C:\Python313\python.exe)
echo     (留空或输入 0 则退出)
echo.
set /p PYTHON_PATH="路径: "

REM 检查是否为空
if "!PYTHON_PATH!"=="" (
    echo.
    echo [X] 未输入路径，退出
    pause
    exit /b 1
)
if "!PYTHON_PATH!"=="0" (
    echo.
    echo [X] 已取消，退出
    pause
    exit /b 1
)

REM 如果输入的是目录（没有 .exe），自动补全 python.exe
echo !PYTHON_PATH! | findstr /i "\.exe$" >nul
if !errorlevel! neq 0 (
    if exist "!PYTHON_PATH!\python.exe" (
        set PYTHON=!PYTHON_PATH!\python.exe
        echo     [OK] 找到 Python
        goto :PY_OK
    )
)

REM 直接检查输入路径
if exist "!PYTHON_PATH!" (
    set PYTHON=!PYTHON_PATH!
    echo     [OK] 找到 Python
    goto :PY_OK
)

REM 路径无效，重新询问
echo     [X] 路径无效，请重新输入
echo.
goto :ASK_PYTHON

:PY_OK
echo.

REM ====== 2. 检查依赖 ======
echo [2/4] 检查依赖...
"!PYTHON!" -c "import playwright" >nul 2>&1
if !errorlevel! neq 0 (
    echo     [X] 缺少 playwright 库，正在安装...
    "!PYTHON!" -m pip install playwright -i https://pypi.tuna.tsinghua.edu.cn/simple
    if !errorlevel! neq 0 (
        echo     [X] pip 安装失败，尝试直接安装...
        "!PYTHON!" -m pip install playwright
    )
    echo     安装浏览器内核(首次需要，稍等)...
    "!PYTHON!" -m playwright install chromium
) else (
    echo     [OK] playwright 库已安装
)
echo.

REM ====== 3. 选择后端 ======
echo [3/4] 选择答题后端：
echo.
echo     1 - DeepSeek 网页版 (需账号, 免费, 推荐)
echo     2 - Ollama 本地模型 (需自行部署)
echo     3 - 豆包网页版 (需登录, 免费)
echo.
set /p BACKEND="请输入数字 (1/2/3): "

if "%BACKEND%"=="1" (
    goto :BACKEND_DEEPSEEK
)
if "%BACKEND%"=="2" (
    goto :BACKEND_OLLAMA
)
if "%BACKEND%"=="3" (
    goto :BACKEND_DOUBAO
)

echo.
echo [X] 输入无效，请输入 1、2 或 3
echo.
pause
exit /b 1

REM ====== DeepSeek ======
:BACKEND_DEEPSEEK
echo.
echo     [OK] 已选择 DeepSeek 网页版后端
echo.
echo [4/4] 检查登录状态...
"!PYTHON!" "%~dp0_check_login.py" >"%TEMP%\ocs_login_check.txt" 2>nul
set /p LOGIN_STATE=<"%TEMP%\ocs_login_check.txt"
if "%LOGIN_STATE%"=="need_login" (
    echo     [X] 未检测到 DeepSeek 登录信息
    echo.
    echo     步骤 1：启动 Edge 浏览器(会自动打开 DeepSeek 登录页)
    pause
    start "" msedge --user-data-dir="%~dp0edge_profile" --no-first-run "https://chat.deepseek.com"
    echo.
    echo     步骤 2：在打开的浏览器中登录你的 DeepSeek 账号
    echo     步骤 3：登录成功后关闭浏览器，回到本窗口按任意键继续
    echo.
    pause
    echo     [OK] 登录状态已保存
) else (
    echo     [OK] 已检测到 DeepSeek 登录状态
)
echo.
echo ============================================
echo  启动 DeepSeek 后端...
echo ============================================
echo.
"!PYTHON!" "%~dp0app.py"
pause
exit /b 0

REM ====== Ollama ======
:BACKEND_OLLAMA
echo.
echo     [OK] 已选择 Ollama 本地模型后端
echo.
echo [4/4] 检查 Ollama 运行状态...
curl -s http://localhost:11434 >nul 2>&1
if %errorlevel% neq 0 (
    echo     [X] Ollama 未运行，请先启动 Ollama
    echo     如果已安装 Ollama，在开始菜单中搜索 "Ollama" 并启动
    pause
) else (
    echo     [OK] Ollama 正在运行
    "!PYTHON!" "%~dp0_check_ollama.py" >"%TEMP%\ocs_ollama_models.txt" 2>nul
    set /p OLLAMA_MODELS=<"%TEMP%\ocs_ollama_models.txt"
    if "%OLLAMA_MODELS%"=="none" (
        echo     [X] 未检测到已下载的模型
        echo     请先打开命令行运行: ollama pull qwen2.5:7b
        pause
    ) else (
        echo     [OK] 可用模型: %OLLAMA_MODELS%
    )
)
echo.
echo ============================================
echo  启动 Ollama 后端...
echo ============================================
echo.
"!PYTHON!" "%~dp0app.py" --mode ollama
pause
exit /b 0

REM ====== 豆包 ======
:BACKEND_DOUBAO
echo.
echo     [OK] 已选择豆包网页版后端
echo.
echo [4/4] 检查登录状态...
"!PYTHON!" "%~dp0_check_login.py" >"%TEMP%\ocs_login_check.txt" 2>nul
set /p LOGIN_STATE=<"%TEMP%\ocs_login_check.txt"
if "%LOGIN_STATE%"=="need_login" (
    echo     [X] 未检测到豆包登录信息
    echo.
    echo     步骤 1：启动 Edge 浏览器(会自动打开豆包登录页)
    pause
    start "" msedge --user-data-dir="%~dp0edge_profile" --no-first-run "https://www.doubao.com/chat"
    echo.
    echo     步骤 2：在打开的浏览器中登录你的豆包账号
    echo     步骤 3：登录成功后关闭浏览器，回到本窗口按任意键继续
    echo.
    pause
    echo     [OK] 登录状态已保存
) else (
    echo     [OK] 已检测到豆包登录状态
)
echo.
echo ============================================
echo  启动豆包后端...
echo ============================================
echo.
"!PYTHON!" "%~dp0app.py" --mode doubao
pause
exit /b 0