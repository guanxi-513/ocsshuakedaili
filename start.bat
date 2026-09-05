@echo off
title OCS AI 答题助手 - 启动引导

set LOG_FILE=%~dp0start_log.txt
echo ============================================= >"%LOG_FILE%"
echo   OCS 启动日志                         >>"%LOG_FILE%"
echo   %DATE% %TIME%                        >>"%LOG_FILE%"
echo ============================================= >>"%LOG_FILE%"

echo =============================================
echo   OCS AI 答题助手 - 启动引导
echo =============================================
echo.

echo [STEP 0] 脚本已启�?>>"%LOG_FILE%"

setlocal enabledelayedexpansion

REM ====== 1. 手动输入 Python 路径 ======
echo [1/4] 设置 Python 路径...
echo [STEP 1] 手动输入 Python 路径 >>"%LOG_FILE%"
set PYTHON=

:ASK_PYTHON
echo.
echo     请输�?Python 路径(例如 C:\Python313\python.exe)
echo     或输入目录路�?会自动补�?python.exe)
echo     (留空或输�?0 则退�?
echo.
set /p PYTHON_PATH="路径: "
echo [INPUT] PYTHON_PATH = "!PYTHON_PATH!" >>"%LOG_FILE%"

if "!PYTHON_PATH!"=="" (
    echo [X] 未输入路径，退�?>>"%LOG_FILE%"
    echo.
    echo [X] 未输入路径，退�?    pause
    exit /b 1
)
if "!PYTHON_PATH!"=="0" (
    echo [X] 已取消，退�?>>"%LOG_FILE%"
    echo.
    echo [X] 已取消，退�?    pause
    exit /b 1
)

REM 如果输入的是目录（没�?.exe），自动补全 python.exe
echo !PYTHON_PATH! | findstr /i "\.exe$" >nul
if !errorlevel! neq 0 (
    if exist "!PYTHON_PATH!\python.exe" (
        set PYTHON=!PYTHON_PATH!\python.exe
        echo     [OK] 自动补全 python.exe
        echo [OK] 自动补全: !PYTHON! >>"%LOG_FILE%"
        goto :PY_OK
    )
)

REM 直接检查输入路�?if exist "!PYTHON_PATH!" (
    set PYTHON=!PYTHON_PATH!
    echo     [OK] 有效路径
    echo [OK] 手动输入: !PYTHON! >>"%LOG_FILE%"
    goto :PY_OK
)

REM 路径无效，重新询�?echo     [X] 路径无效，请重新输入
echo [X] 路径无效: "!PYTHON_PATH!" >>"%LOG_FILE%"
goto :ASK_PYTHON

:PY_OK
echo [STEP 1.3] Python 确认: !PYTHON! >>"%LOG_FILE%"
echo.

REM ====== 2. 检查依�?======
echo [2/4] 检查依�?..
echo [STEP 2] 检查依�?>>"%LOG_FILE%"

"!PYTHON!" -c "import playwright" >nul 2>&1
if !errorlevel! neq 0 (
    echo     [X] 缺少 playwright 库，正在安装...
    echo [STEP 2.1] 安装 playwright... >>"%LOG_FILE%"
    "!PYTHON!" -m pip install playwright -i https://pypi.tuna.tsinghua.edu.cn/simple
    if !errorlevel! neq 0 (
        echo     [X] pip 安装失败，尝试直接安�?..
        echo [STEP 2.2] pip 失败，重�?.. >>"%LOG_FILE%"
        "!PYTHON!" -m pip install playwright
    )
    echo     安装浏览器内�?首次需要，稍等)...
    echo [STEP 2.3] 安装 chromium 浏览器内�?.. >>"%LOG_FILE%"
    "!PYTHON!" -m playwright install chromium
) else (
    echo     [OK] playwright 库已安装
    echo [OK] playwright 已安�?>>"%LOG_FILE%"
)
echo.

REM ====== 3. 选择后端 ======
echo [3/4] 选择答题后端�?echo [STEP 3] 选择后端 >>"%LOG_FILE%"
echo.
echo     1 - DeepSeek 网页�?(需账号, 免费, 推荐)
echo     2 - Ollama 本地模型 (需自行部署)
echo     3 - 豆包网页�?(需登录, 免费)
echo.
set /p BACKEND="请输入数�?(1/2/3): "
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
echo [X] 输入无效，请输入 1�? �?3
echo.
pause
exit /b 1

REM ====== DeepSeek ======
:BACKEND_DEEPSEEK
echo [STEP 4] DeepSeek 后端 >>"%LOG_FILE%"
echo.
echo     [OK] 已选择 DeepSeek 网页版后�?echo.
echo [4/4] 检查登录状�?..
"!PYTHON!" "%~dp0_check_login.py" >"%TEMP%\ocs_login_check.txt" 2>nul
set /p LOGIN_STATE=<"%TEMP%\ocs_login_check.txt"
echo [LOGIN] DeepSeek 状�? "!LOGIN_STATE!" >>"%LOG_FILE%"
if "%LOGIN_STATE%"=="need_login" (
    echo     [X] 未检测到 DeepSeek 登录信息
    echo.
    echo     步骤 1：启�?Edge 浏览�?会自动打开 DeepSeek 登录�?
    pause
    echo [STEP 4.1] 启动浏览�?>>"%LOG_FILE%"
    start "" msedge --user-data-dir="%~dp0edge_profile" --no-first-run "https://chat.deepseek.com"
    echo.
    echo     步骤 2：在打开的浏览器中登录你�?DeepSeek 账号
    echo     步骤 3：登录成功后关闭浏览器，回到本窗口按任意键继�?    echo.
    pause
    echo     [OK] 登录状态已保存
    echo [OK] DeepSeek 登录完成 >>"%LOG_FILE%"
) else (
    echo     [OK] 已检测到 DeepSeek 登录状�?)
echo.
echo ============================================
echo  启动 DeepSeek 后端...
echo ============================================
echo [START] 启动 app.py (DeepSeek) >>"%LOG_FILE%"
echo.
"!PYTHON!" "%~dp0app.py"
echo [EXIT] app.py 退�?>>"%LOG_FILE%"
pause
exit /b 0

REM ====== Ollama ======
:BACKEND_OLLAMA
echo [STEP 4] Ollama 后端 >>"%LOG_FILE%"
echo.
echo     [OK] 已选择 Ollama 本地模型后端
echo.
echo [4/4] 检�?Ollama 运行状�?..
curl -s http://localhost:11434 >nul 2>&1
if %errorlevel% neq 0 (
    echo     [X] Ollama 未运行，请先启动 Ollama
    echo     如果已安�?Ollama，在开始菜单中搜索 "Ollama" 并启�?    echo [X] Ollama 未运�?>>"%LOG_FILE%"
    pause
) else (
    echo     [OK] Ollama 正在运行
    echo [OK] Ollama 运行�?>>"%LOG_FILE%"
    "!PYTHON!" "%~dp0_check_ollama.py" >"%TEMP%\ocs_ollama_models.txt" 2>nul
    set /p OLLAMA_MODELS=<"%TEMP%\ocs_ollama_models.txt"
    if "%OLLAMA_MODELS%"=="none" (
        echo     [X] 未检测到已下载的模型
        echo     请先打开命令行运�? ollama pull qwen2.5:7b
        echo [X] Ollama 无模�?>>"%LOG_FILE%"
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
echo [EXIT] app.py 退�?>>"%LOG_FILE%"
pause
exit /b 0

REM ====== 豆包 ======
:BACKEND_DOUBAO
echo [STEP 4] 豆包后端 >>"%LOG_FILE%"
echo.
echo     [OK] 已选择豆包网页版后�?echo.
echo [4/4] 检查登录状�?..
"!PYTHON!" "%~dp0_check_login.py" >"%TEMP%\ocs_login_check.txt" 2>nul
set /p LOGIN_STATE=<"%TEMP%\ocs_login_check.txt"
echo [LOGIN] 豆包状�? "!LOGIN_STATE!" >>"%LOG_FILE%"
if "%LOGIN_STATE%"=="need_login" (
    echo     [X] 未检测到豆包登录信息
    echo.
    echo     步骤 1：启�?Edge 浏览�?会自动打开豆包登录�?
    pause
    echo [STEP 4.1] 启动浏览�?>>"%LOG_FILE%"
    start "" msedge --user-data-dir="%~dp0edge_profile" --no-first-run "https://www.doubao.com/chat"
    echo.
    echo     步骤 2：在打开的浏览器中登录你的豆包账�?    echo     步骤 3：登录成功后关闭浏览器，回到本窗口按任意键继�?    echo.
    pause
    echo     [OK] 登录状态已保存
    echo [OK] 豆包登录完成 >>"%LOG_FILE%"
) else (
    echo     [OK] 已检测到豆包登录状�?)
echo.
echo ============================================
echo  启动豆包后端...
echo ============================================
echo [START] 启动 app.py (豆包) >>"%LOG_FILE%"
echo.
"!PYTHON!" "%~dp0app.py" --mode doubao
echo [EXIT] app.py 退�?>>"%LOG_FILE%"
pause
exit /b 0
