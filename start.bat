@echo off
chcp 65001 >nul
title OCS AI 答题助手 - 启动引导

REM ====== 设置日志 ======
set LOG_FILE=%~dp0start_log.txt
echo ============================================= >"%LOG_FILE%"
echo   OCS 启动日志                         >>"%LOG_FILE%"
echo   %DATE% %TIME%                        >>"%LOG_FILE%"
echo ============================================= >>"%LOG_FILE%"

echo =============================================
echo   OCS AI 答题助手 - 启动引导
echo =============================================
echo.

echo [STEP 0] 脚本已启动 >>"%LOG_FILE%"

setlocal enabledelayedexpansion

REM ====== 1. 检查 Python ======
echo [1/4] 检查 Python 环境...
echo [STEP 1] 开始检查 Python >>"%LOG_FILE%"
set PYTHON=
set PYTHON_FOUND=0

REM 先检查常见路径（不运行 python 命令，避免触发微软商店弹窗）
echo   正在检测常见安装路径...
echo [STEP 1.1] 检查常见路径... >>"%LOG_FILE%"

if exist "C:\Users\HP\AppData\Local\Programs\Python\Python313\python.exe" (
    set PYTHON=C:\Users\HP\AppData\Local\Programs\Python\Python313\python.exe
    set PYTHON_FOUND=1
    echo     [OK] 路径1 找到 Python
    echo [OK] 路径1: C:\Users\HP\AppData\Local\Programs\Python\Python313\python.exe >>"%LOG_FILE%"
)
if !PYTHON_FOUND! equ 0 if exist "C:\Users\HP\AppData\Local\Programs\Python\Python312\python.exe" (
    set PYTHON=C:\Users\HP\AppData\Local\Programs\Python\Python312\python.exe
    set PYTHON_FOUND=1
    echo     [OK] 路径2 找到 Python
    echo [OK] 路径2: C:\Users\HP\AppData\Local\Programs\Python\Python312\python.exe >>"%LOG_FILE%"
)
if !PYTHON_FOUND! equ 0 if exist "C:\Users\HP\AppData\Local\Doubao\User Data\sandbox_runtime\bases\9f6d27f23933fb44a3a1c728c88a5ce4\python\python.exe" (
    set PYTHON=C:\Users\HP\AppData\Local\Doubao\User Data\sandbox_runtime\bases\9f6d27f23933fb44a3a1c728c88a5ce4\python\python.exe
    set PYTHON_FOUND=1
    echo     [OK] 路径3(豆包沙箱) 找到 Python
    echo [OK] 路径3: 豆包沙箱 Python >>"%LOG_FILE%"
)
if !PYTHON_FOUND! equ 0 if exist "C:\Python313\python.exe" (
    set PYTHON=C:\Python313\python.exe
    set PYTHON_FOUND=1
    echo     [OK] 路径4 找到 Python
    echo [OK] 路径4: C:\Python313\python.exe >>"%LOG_FILE%"
)
if !PYTHON_FOUND! equ 0 if exist "C:\Python312\python.exe" (
    set PYTHON=C:\Python312\python.exe
    set PYTHON_FOUND=1
    echo     [OK] 路径5 找到 Python
    echo [OK] 路径5: C:\Python312\python.exe >>"%LOG_FILE%"
)

REM 如果还没找到，再试 where 命令
if !PYTHON_FOUND! equ 0 (
    echo   尝试 where python 命令...
    echo [STEP 1.2] 尝试 where python >>"%LOG_FILE%"
    for /f "delims=" %%i in ('where python 2^>nul') do (
        set PYTHON=%%i
        set PYTHON_FOUND=1
        echo     [OK] where 找到 Python: %%i
        echo [OK] where: %%i >>"%LOG_FILE%"
    )
)

if !PYTHON_FOUND! equ 1 (
    echo     [OK] Python 已找到: !PYTHON!
    echo [OK] Python = !PYTHON! >>"%LOG_FILE%"
    goto :PY_OK
)

REM 都没找到，让用户手动输入
echo     [X] 未自动检测到 Python
echo [X] 未自动检测到 Python >>"%LOG_FILE%"

:ASK_PYTHON
echo.
echo     请手动输入 Python 路径(例如 C:\Python313\python.exe)
echo     (留空或输入 0 则退出)
echo.
set /p PYTHON_PATH="路径: "
echo [INPUT] PYTHON_PATH = "!PYTHON_PATH!" >>"%LOG_FILE%"

REM 检查是否为空
if "!PYTHON_PATH!"=="" (
    echo [X] 未输入路径，退出 >>"%LOG_FILE%"
    echo.
    echo [X] 未输入路径，退出
    pause
    exit /b 1
)
if "!PYTHON_PATH!"=="0" (
    echo [X] 已取消，退出 >>"%LOG_FILE%"
    echo.
    echo [X] 已取消，退出
    pause
    exit /b 1
)

REM 如果输入的是目录，自动补全 python.exe
echo !PYTHON_PATH! | findstr /i "\.exe$" >nul
if !errorlevel! neq 0 (
    if exist "!PYTHON_PATH!\python.exe" (
        set PYTHON=!PYTHON_PATH!\python.exe
        echo     [OK] 自动补全 python.exe
        echo [OK] 自动补全: !PYTHON! >>"%LOG_FILE%"
        goto :PY_OK
    )
)

REM 直接检查输入路径
if exist "!PYTHON_PATH!" (
    set PYTHON=!PYTHON_PATH!
    echo     [OK] 有效路径
    echo [OK] 手动输入: !PYTHON! >>"%LOG_FILE%"
    goto :PY_OK
)

REM 路径无效
echo     [X] 路径无效，请重新输入
echo [X] 路径无效: "!PYTHON_PATH!" >>"%LOG_FILE%"
goto :ASK_PYTHON

:PY_OK
echo [STEP 1.3] Python 确认: !PYTHON! >>"%LOG_FILE%"
echo.

REM ====== 2. 检查依赖 ======
echo [2/4] 检查依赖...
echo [STEP 2] 检查依赖 >>"%LOG_FILE%"

"!PYTHON!" -c "import playwright" >nul 2>&1
if !errorlevel! neq 0 (
    echo     [X] 缺少 playwright 库，正在安装...
    echo [STEP 2.1] 安装 playwright... >>"%LOG_FILE%"
    "!PYTHON!" -m pip install playwright -i https://pypi.tuna.tsinghua.edu.cn/simple
    if !errorlevel! neq 0 (
        echo     [X] pip 安装失败，尝试直接安装...
        echo [STEP 2.2] pip 失败，重试... >>"%LOG_FILE%"
        "!PYTHON!" -m pip install playwright
    )
    echo     安装浏览器内核(首次需要，稍等)...
    echo [STEP 2.3] 安装 chromium 浏览器内核... >>"%LOG_FILE%"
    "!PYTHON!" -m playwright install chromium
) else (
    echo     [OK] playwright 库已安装
    echo [OK] playwright 已安装 >>"%LOG_FILE%"
)
echo.

REM ====== 3. 选择后端 ======
echo [3/4] 选择答题后端：
echo [STEP 3] 选择后端 >>"%LOG_FILE%"
echo.
echo     1 - DeepSeek 网页版 (需账号, 免费, 推荐)
echo     2 - Ollama 本地模型 (需自行部署)
echo     3 - 豆包网页版 (需登录, 免费)
echo.
set /p BACKEND="请输入数字 (1/2/3): "
echo [INPUT] BACKEND = "!BACKEND!" >>"%LOG_FILE%"

if "%BACKEND%"=="1" (
    goto :BACKEND_DEEPSEEK
)
if "%BACKEND%"=="2" (
    goto :BACKEND_OLLAMA
)
if "%BACKEND%"=="3" (
    goto :BACKEND_DOUBAO
)

echo [X] 输入无效: "!BACKEND!" >>"%LOG_FILE%"
echo.
echo [X] 输入无效，请输入 1、2 或 3
echo.
pause
exit /b 1

REM ====== DeepSeek ======
:BACKEND_DEEPSEEK
echo [STEP 4] DeepSeek 后端 >>"%LOG_FILE%"
echo.
echo     [OK] 已选择 DeepSeek 网页版后端
echo.
echo [4/4] 检查登录状态...
"!PYTHON!" "%~dp0_check_login.py" >"%TEMP%\ocs_login_check.txt" 2>nul
set /p LOGIN_STATE=<"%TEMP%\ocs_login_check.txt"
echo [LOGIN] DeepSeek 状态: "!LOGIN_STATE!" >>"%LOG_FILE%"
if "%LOGIN_STATE%"=="need_login" (
    echo     [X] 未检测到 DeepSeek 登录信息
    echo.
    echo     步骤 1：启动 Edge 浏览器(会自动打开 DeepSeek 登录页)
    pause
    echo [STEP 4.1] 启动浏览器 >>"%LOG_FILE%"
    start "" msedge --user-data-dir="%~dp0edge_profile" --no-first-run "https://chat.deepseek.com"
    echo.
    echo     步骤 2：在打开的浏览器中登录你的 DeepSeek 账号
    echo     步骤 3：登录成功后关闭浏览器，回到本窗口按任意键继续
    echo.
    pause
    echo     [OK] 登录状态已保存
    echo [OK] DeepSeek 登录完成 >>"%LOG_FILE%"
) else (
    echo     [OK] 已检测到 DeepSeek 登录状态
)
echo.
echo ============================================
echo  启动 DeepSeek 后端...
echo ============================================
echo [START] 启动 app.py (DeepSeek) >>"%LOG_FILE%"
echo.
"!PYTHON!" "%~dp0app.py"
echo [EXIT] app.py 退出 >>"%LOG_FILE%"
pause
exit /b 0

REM ====== Ollama ======
:BACKEND_OLLAMA
echo [STEP 4] Ollama 后端 >>"%LOG_FILE%"
echo.
echo     [OK] 已选择 Ollama 本地模型后端
echo.
echo [4/4] 检查 Ollama 运行状态...
curl -s http://localhost:11434 >nul 2>&1
if %errorlevel% neq 0 (
    echo     [X] Ollama 未运行，请先启动 Ollama
    echo     如果已安装 Ollama，在开始菜单中搜索 "Ollama" 并启动
    echo [X] Ollama 未运行 >>"%LOG_FILE%"
    pause
) else (
    echo     [OK] Ollama 正在运行
    echo [OK] Ollama 运行中 >>"%LOG_FILE%"
    "!PYTHON!" "%~dp0_check_ollama.py" >"%TEMP%\ocs_ollama_models.txt" 2>nul
    set /p OLLAMA_MODELS=<"%TEMP%\ocs_ollama_models.txt"
    if "%OLLAMA_MODELS%"=="none" (
        echo     [X] 未检测到已下载的模型
        echo     请先打开命令行运行: ollama pull qwen2.5:7b
        echo [X] Ollama 无模型 >>"%LOG_FILE%"
        pause
    ) else (
        echo     [OK] 可用模型: %OLLAMA_MODELS%
        echo [OK] Ollama 模型: %OLLAMA_MODELS% >>"%LOG_FILE%"
    )
)
echo.
echo ============================================
echo  启动 Ollama 后端...
echo ============================================
echo [START] 启动 app.py (Ollama) >>"%LOG_FILE%"
echo.
"!PYTHON!" "%~dp0app.py" --mode ollama
echo [EXIT] app.py 退出 >>"%LOG_FILE%"
pause
exit /b 0

REM ====== 豆包 ======
:BACKEND_DOUBAO
echo [STEP 4] 豆包后端 >>"%LOG_FILE%"
echo.
echo     [OK] 已选择豆包网页版后端
echo.
echo [4/4] 检查登录状态...
"!PYTHON!" "%~dp0_check_login.py" >"%TEMP%\ocs_login_check.txt" 2>nul
set /p LOGIN_STATE=<"%TEMP%\ocs_login_check.txt"
echo [LOGIN] 豆包状态: "!LOGIN_STATE!" >>"%LOG_FILE%"
if "%LOGIN_STATE%"=="need_login" (
    echo     [X] 未检测到豆包登录信息
    echo.
    echo     步骤 1：启动 Edge 浏览器(会自动打开豆包登录页)
    pause
    echo [STEP 4.1] 启动浏览器 >>"%LOG_FILE%"
    start "" msedge --user-data-dir="%~dp0edge_profile" --no-first-run "https://www.doubao.com/chat"
    echo.
    echo     步骤 2：在打开的浏览器中登录你的豆包账号
    echo     步骤 3：登录成功后关闭浏览器，回到本窗口按任意键继续
    echo.
    pause
    echo     [OK] 登录状态已保存
    echo [OK] 豆包登录完成 >>"%LOG_FILE%"
) else (
    echo     [OK] 已检测到豆包登录状态
)
echo.
echo ============================================
echo  启动豆包后端...
echo ============================================
echo [START] 启动 app.py (豆包) >>"%LOG_FILE%"
echo.
"!PYTHON!" "%~dp0app.py" --mode doubao
echo [EXIT] app.py 退出 >>"%LOG_FILE%"
pause
exit /b 0