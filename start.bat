@echo off
chcp 65001 >nul
title OCS 自动答题服务

echo =============================================
echo   OCS AI 答题助手 - 启动中...
echo =============================================
echo.

REM 尝试使用系统 Python，如果找不到则尝试自定义路径
python --version >nul 2>&1
if %errorlevel% equ 0 (
    python "%~dp0app.py"
    goto :end
)

REM 备用：尝试 python3
python3 --version >nul 2>&1
if %errorlevel% equ 0 (
    python3 "%~dp0app.py"
    goto :end
)

echo [错误] 找不到 Python，请安装 Python 3.10+ 并加入 PATH
echo 或者手动修改本脚本中的 Python 路径
pause
exit /b 1

:end
pause