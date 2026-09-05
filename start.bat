@echo off
title OCS AI Answer Helper - Setup

set LOG_FILE=%~dp0start_log.txt
echo ============================================= >"%LOG_FILE%"
echo   OCS Startup Log                        >>"%LOG_FILE%"
echo   %DATE% %TIME%                          >>"%LOG_FILE%"
echo ============================================= >>"%LOG_FILE%"

echo =============================================
echo   OCS AI Answer Helper - Setup Guide
echo =============================================
echo.

echo [STEP 0] Script started >>"%LOG_FILE%"

setlocal enabledelayedexpansion

REM ====== 1. Manual Python Path Input ======
echo [1/4] Python Path Setup...
echo [STEP 1] Manual Python path input >>"%LOG_FILE%"
set PYTHON=

:ASK_PYTHON
echo.
echo     Please enter Python path (e.g. C:\Python313\python.exe)
echo     Or enter a directory path (will auto-add python.exe)
echo     (Leave empty or enter 0 to exit)
echo.
set /p PYTHON_PATH="Path: "
echo [INPUT] PYTHON_PATH = "!PYTHON_PATH!" >>"%LOG_FILE%"

if "!PYTHON_PATH!"=="" (
    echo [X] No path entered, exiting >>"%LOG_FILE%"
    echo.
    echo [X] No path entered, exiting
    pause
    exit /b 1
)
if "!PYTHON_PATH!"=="0" (
    echo [X] Cancelled, exiting >>"%LOG_FILE%"
    echo.
    echo [X] Cancelled, exiting
    pause
    exit /b 1
)

REM If input is a directory (no .exe), try adding python.exe
echo !PYTHON_PATH! | findstr /i "\.exe$" >nul
if !errorlevel! neq 0 (
    if exist "!PYTHON_PATH!\python.exe" (
        set PYTHON=!PYTHON_PATH!\python.exe
        echo     [OK] Auto-completed python.exe
        echo [OK] Auto-completed: !PYTHON! >>"%LOG_FILE%"
        goto :PY_OK
    )
)

REM Direct check
if exist "!PYTHON_PATH!" (
    set PYTHON=!PYTHON_PATH!
    echo     [OK] Valid path
    echo [OK] Manual input: !PYTHON! >>"%LOG_FILE%"
    goto :PY_OK
)

REM Invalid
echo     [X] Invalid path, please try again
echo [X] Invalid: "!PYTHON_PATH!" >>"%LOG_FILE%"
goto :ASK_PYTHON

:PY_OK
echo [STEP 1.3] Python confirmed: !PYTHON! >>"%LOG_FILE%"
echo.

REM ====== 2. Check Dependencies ======
echo [2/4] Checking dependencies...
echo [STEP 2] Check dependencies >>"%LOG_FILE%"

"!PYTHON!" -c "import playwright" >nul 2>&1
if !errorlevel! neq 0 (
    echo     [X] playwright not found, installing...
    echo [STEP 2.1] Installing playwright... >>"%LOG_FILE%"
    "!PYTHON!" -m pip install playwright -i https://pypi.tuna.tsinghua.edu.cn/simple
    if !errorlevel! neq 0 (
        echo     [X] pip install failed, retrying...
        echo [STEP 2.2] pip failed, retrying... >>"%LOG_FILE%"
        "!PYTHON!" -m pip install playwright
    )
    echo     Installing browser engine (first time, please wait)...
    echo [STEP 2.3] Installing chromium browser... >>"%LOG_FILE%"
    "!PYTHON!" -m playwright install chromium
) else (
    echo     [OK] playwright already installed
    echo [OK] playwright installed >>"%LOG_FILE%"
)
echo.

REM ====== 3. Select Backend ======
echo [3/4] Choose answer backend:
echo [STEP 3] Select backend >>"%LOG_FILE%"
echo.
echo     1 - DeepSeek Web (needs account, free)
echo     2 - Ollama Local (needs local setup)
echo     3 - Doubao Web (needs login, free)
echo.
set /p BACKEND="Enter number (1/2/3): "
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

echo [X] Invalid input: "!BACKEND!" >>"%LOG_FILE%"
echo.
echo [X] Invalid input, please enter 1, 2 or 3
echo.
pause
exit /b 1

REM ====== DeepSeek ======
:BACKEND_DEEPSEEK
echo [STEP 4] DeepSeek backend >>"%LOG_FILE%"
echo.
echo     [OK] Selected DeepSeek Web backend
echo.
echo [4/4] Checking login status...
"!PYTHON!" "%~dp0_check_login.py" >"%TEMP%\ocs_login_check.txt" 2>nul
set /p LOGIN_STATE=<"%TEMP%\ocs_login_check.txt"
echo [LOGIN] DeepSeek status: "!LOGIN_STATE!" >>"%LOG_FILE%"
if "%LOGIN_STATE%"=="need_login" (
    echo     [X] DeepSeek login not detected
    echo.
    echo     Step 1: Starting Edge browser (will open DeepSeek login page)
    pause
    echo [STEP 4.1] Starting browser >>"%LOG_FILE%"
    start "" msedge --user-data-dir="%~dp0edge_profile" --no-first-run "https://chat.deepseek.com"
    echo.
    echo     Step 2: Login to your DeepSeek account in the browser
    echo     Step 3: Close the browser after login, then press any key here
    echo.
    pause
    echo     [OK] Login status saved
    echo [OK] DeepSeek login done >>"%LOG_FILE%"
) else (
    echo     [OK] DeepSeek login detected
)
echo.
echo ============================================
echo  Starting DeepSeek backend...
echo ============================================
echo [START] Starting app.py (DeepSeek) >>"%LOG_FILE%"
echo.
"!PYTHON!" "%~dp0app.py"
echo [EXIT] app.py exited >>"%LOG_FILE%"
pause
exit /b 0

REM ====== Ollama ======
:BACKEND_OLLAMA
echo [STEP 4] Ollama backend >>"%LOG_FILE%"
echo.
echo     [OK] Selected Ollama local backend
echo.
echo [4/4] Checking Ollama status...
curl -s http://localhost:11434 >nul 2>&1
if %errorlevel% neq 0 (
    echo     [X] Ollama is not running
    echo     If Ollama is installed, start it from the Start Menu
    echo [X] Ollama not running >>"%LOG_FILE%"
    pause
) else (
    echo     [OK] Ollama is running
    echo [OK] Ollama running >>"%LOG_FILE%"
    "!PYTHON!" "%~dp0_check_ollama.py" >"%TEMP%\ocs_ollama_models.txt" 2>nul
    set /p OLLAMA_MODELS=<"%TEMP%\ocs_ollama_models.txt"
    if "%OLLAMA_MODELS%"=="none" (
        echo     [X] No models found
        echo     Please run: ollama pull qwen2.5:7b
        echo [X] Ollama no models >>"%LOG_FILE%"
        pause
    ) else (
        echo     [OK] Available models: %OLLAMA_MODELS%
        echo [OK] Ollama models: %OLLAMA_MODELS% >>"%LOG_FILE%"
    )
)
echo.
echo ============================================
echo  Starting Ollama backend...
echo ============================================
echo [START] Starting app.py (Ollama) >>"%LOG_FILE%"
echo.
"!PYTHON!" "%~dp0app.py" --mode ollama
echo [EXIT] app.py exited >>"%LOG_FILE%"
pause
exit /b 0

REM ====== Doubao ======
:BACKEND_DOUBAO
echo [STEP 4] Doubao backend >>"%LOG_FILE%"
echo.
echo     [OK] Selected Doubao Web backend
echo.
echo [4/4] Checking login status...
"!PYTHON!" "%~dp0_check_login.py" >"%TEMP%\ocs_login_check.txt" 2>nul
set /p LOGIN_STATE=<"%TEMP%\ocs_login_check.txt"
echo [LOGIN] Doubao status: "!LOGIN_STATE!" >>"%LOG_FILE%"
if "%LOGIN_STATE%"=="need_login" (
    echo     [X] Doubao login not detected
    echo.
    echo     Step 1: Starting Edge browser (will open Doubao login page)
    pause
    echo [STEP 4.1] Starting browser >>"%LOG_FILE%"
    start "" msedge --user-data-dir="%~dp0edge_profile" --no-first-run "https://www.doubao.com/chat"
    echo.
    echo     Step 2: Login to your Doubao account in the browser
    echo     Step 3: Close the browser after login, then press any key here
    echo.
    pause
    echo     [OK] Login status saved
    echo [OK] Doubao login done >>"%LOG_FILE%"
) else (
    echo     [OK] Doubao login detected
)
echo.
echo ============================================
echo  Starting Doubao backend...
echo ============================================
echo [START] Starting app.py (Doubao) >>"%LOG_FILE%"
echo.
"!PYTHON!" "%~dp0app.py" --mode doubao
echo [EXIT] app.py exited >>"%LOG_FILE%"
pause
exit /b 0
