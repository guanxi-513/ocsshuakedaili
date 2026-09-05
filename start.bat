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
echo [STEP 1] Manual Python path >>"%LOG_FILE%"
set PYTHON=

:ASK_PYTHON
echo.
echo     Please enter Python path (e.g. C:\Python313\python.exe)
echo     Or enter a directory path (will auto-add python.exe)
echo     (Leave empty or enter 0 to exit)
echo.
set /p PYTHON_PATH="Path: "
echo [INPUT] PYTHON_PATH = "!PYTHON_PATH!" >>"%LOG_FILE%"

if "!PYTHON_PATH!"=="" goto :EXIT_NO_PATH
if "!PYTHON_PATH!"=="0" goto :EXIT_NO_PATH

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

if exist "!PYTHON_PATH!" (
    set PYTHON=!PYTHON_PATH!
    echo     [OK] Valid path
    echo [OK] Manual input: !PYTHON! >>"%LOG_FILE%"
    goto :PY_OK
)

echo     [X] Invalid path, please try again
echo [X] Invalid: "!PYTHON_PATH!" >>"%LOG_FILE%"
goto :ASK_PYTHON

:EXIT_NO_PATH
echo [X] No path or cancelled >>"%LOG_FILE%"
echo.
echo [X] Exiting
pause
exit /b 1

:PY_OK
echo [STEP 1] Python OK: !PYTHON! >>"%LOG_FILE%"
echo.

REM ====== 2. Check Dependencies ======
echo [2/4] Checking dependencies...
echo [STEP 2] Check playwright >>"%LOG_FILE%"

"!PYTHON!" "%~dp0_check_deps.py" >"%TEMP%\ocs_deps_check.txt" 2>&1
echo [STEP 2] _check_deps.py exit code: !errorlevel! >>"%LOG_FILE%"

set /p DEPS_STATE=<"%TEMP%\ocs_deps_check.txt"
echo [STEP 2] DEPS_STATE = [!DEPS_STATE!] >>"%LOG_FILE%"

if "!DEPS_STATE!"=="missing" goto :INSTALL_DEPS

echo     [OK] playwright already installed
echo [STEP 2] OK >>"%LOG_FILE%"
goto :DEPS_DONE

:INSTALL_DEPS
echo     [X] playwright not found, installing...
echo [STEP 2.1] Installing playwright... >>"%LOG_FILE%"
"!PYTHON!" -m pip install playwright -i https://pypi.tuna.tsinghua.edu.cn/simple
echo [STEP 2.1] pip exit: !errorlevel! >>"%LOG_FILE%"
if !errorlevel! neq 0 (
    echo     [X] pip install failed, retrying...
    echo [STEP 2.2] pip retry... >>"%LOG_FILE%"
    "!PYTHON!" -m pip install playwright
    echo [STEP 2.2] pip retry exit: !errorlevel! >>"%LOG_FILE%"
)
echo     Installing browser engine (first time, please wait)...
echo [STEP 2.3] Installing chromium... >>"%LOG_FILE%"
"!PYTHON!" -m playwright install chromium
echo [STEP 2.3] chromium done >>"%LOG_FILE%"

:DEPS_DONE
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

if "%BACKEND%"=="1" goto :BACKEND_DEEPSEEK
if "%BACKEND%"=="2" goto :BACKEND_OLLAMA
if "%BACKEND%"=="3" goto :BACKEND_DOUBAO

echo [X] Invalid input: "!BACKEND!" >>"%LOG_FILE%"
echo.
echo [X] Invalid input, please enter 1, 2 or 3
pause
exit /b 1

REM ====== DeepSeek ======
:BACKEND_DEEPSEEK
echo [STEP 4] DeepSeek >>"%LOG_FILE%"
echo.
echo     [OK] Selected DeepSeek Web backend
echo.
echo [4/4] Checking login status...
"!PYTHON!" "%~dp0_check_login.py" >"%TEMP%\ocs_login_check.txt" 2>nul
set /p LOGIN_STATE=<"%TEMP%\ocs_login_check.txt"
echo [LOGIN] DeepSeek: "!LOGIN_STATE!" >>"%LOG_FILE%"
if "!LOGIN_STATE!"=="need_login" goto :DEEPSEEK_LOGIN
echo     [OK] DeepSeek login detected
goto :DEEPSEEK_START

:DEEPSEEK_LOGIN
echo     [X] DeepSeek login not detected
echo.
echo     Step 1: Starting Edge browser (will open DeepSeek login page)
pause
echo [STEP 4.1] Starting browser >>"%LOG_FILE%"
start "" msedge --user-data-dir="%~dp0edge_profile" --no-first-run "https://chat.deepseek.com"
echo.
echo     Step 2: Login to your DeepSeek account in the browser
echo     Step 3: Close the browser after login, then press any key here
pause
echo     [OK] Login status saved
echo [OK] DeepSeek login done >>"%LOG_FILE%"

:DEEPSEEK_START
echo.
echo ============================================
echo  Starting DeepSeek backend...
echo ============================================
echo [START] app.py (DeepSeek) >>"%LOG_FILE%"
echo.
"!PYTHON!" "%~dp0app.py"
echo [EXIT] app.py exited >>"%LOG_FILE%"
pause
exit /b 0

REM ====== Ollama ======
:BACKEND_OLLAMA
echo [STEP 4] Ollama >>"%LOG_FILE%"
echo.
echo     [OK] Selected Ollama local backend
echo.
echo [4/4] Checking Ollama status...
curl -s http://localhost:11434 >nul 2>&1
if %errorlevel% neq 0 goto :OLLAMA_NOT_RUNNING

echo     [OK] Ollama is running
echo [OK] Ollama running >>"%LOG_FILE%"
"!PYTHON!" "%~dp0_check_ollama.py" >"%TEMP%\ocs_ollama_models.txt" 2>nul
set /p OLLAMA_MODELS=<"%TEMP%\ocs_ollama_models.txt"
if "!OLLAMA_MODELS!"=="none" goto :OLLAMA_NO_MODELS
echo     [OK] Available models: %OLLAMA_MODELS%
echo [OK] Models: %OLLAMA_MODELS% >>"%LOG_FILE%"
goto :OLLAMA_START

:OLLAMA_NOT_RUNNING
echo     [X] Ollama is not running
echo     If Ollama is installed, start it from the Start Menu
echo [X] Ollama not running >>"%LOG_FILE%"
pause
goto :OLLAMA_START

:OLLAMA_NO_MODELS
echo     [X] No models found
echo     Please run: ollama pull qwen2.5:7b
echo [X] Ollama no models >>"%LOG_FILE%"
pause

:OLLAMA_START
echo.
echo ============================================
echo  Starting Ollama backend...
echo ============================================
echo [START] app.py (Ollama) >>"%LOG_FILE%"
echo.
"!PYTHON!" "%~dp0app.py" --mode ollama
echo [EXIT] app.py exited >>"%LOG_FILE%"
pause
exit /b 0

REM ====== Doubao ======
:BACKEND_DOUBAO
echo [STEP 4] Doubao >>"%LOG_FILE%"
echo.
echo     [OK] Selected Doubao Web backend
echo.
echo [4/4] Checking login status...
"!PYTHON!" "%~dp0_check_login.py" >"%TEMP%\ocs_login_check.txt" 2>nul
set /p LOGIN_STATE=<"%TEMP%\ocs_login_check.txt"
echo [LOGIN] Doubao: "!LOGIN_STATE!" >>"%LOG_FILE%"
if "!LOGIN_STATE!"=="need_login" goto :DOUBAO_LOGIN
echo     [OK] Doubao login detected
goto :DOUBAO_START

:DOUBAO_LOGIN
echo     [X] Doubao login not detected
echo.
echo     Step 1: Starting Edge browser (will open Doubao login page)
pause
echo [STEP 4.1] Starting browser >>"%LOG_FILE%"
start "" msedge --user-data-dir="%~dp0edge_profile" --no-first-run "https://www.doubao.com/chat"
echo.
echo     Step 2: Login to your Doubao account in the browser
echo     Step 3: Close the browser after login, then press any key here
pause
echo     [OK] Login status saved
echo [OK] Doubao login done >>"%LOG_FILE%"

:DOUBAO_START
echo.
echo ============================================
echo  Starting Doubao backend...
echo ============================================
echo [START] app.py (Doubao) >>"%LOG_FILE%"
echo.
"!PYTHON!" "%~dp0app.py" --mode doubao
echo [EXIT] app.py exited >>"%LOG_FILE%"
pause
exit /b 0
