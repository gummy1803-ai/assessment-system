@echo off
chcp 65001 >nul
title 注册开机自启

REM ============================================
REM 干部考核管理系统 - 开机自启安装脚本
REM 功能：将服务器启动注册为 Windows 计划任务
REM ============================================

cd /d "%~dp0"

echo ============================================
echo   干部考核管理系统 - 开机自启安装
echo ============================================
echo.

REM 检查是否以管理员身份运行
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 请右键点击本脚本，选择"以管理员身份运行"
    pause
    exit /b 1
)

REM 定义任务名称和脚本路径
set TASK_NAME=CadreAssessmentServer
set SCRIPT_PATH=%~dp0start.bat

echo [信息] 任务名称: %TASK_NAME%
echo [信息] 启动脚本: %SCRIPT_PATH%
echo.

REM 先删除已存在的同名任务
schtasks /Delete /TN "%TASK_NAME%" /F >nul 2>&1

REM 创建开机自启任务（登录时启动）
schtasks /Create /TN "%TASK_NAME%" /TR "\"%SCRIPT_PATH%\"" /SC ONLOGON /RL HIGHEST /F

if %errorlevel% equ 0 (
    echo.
    echo ============================================
    echo   安装成功！
    echo.
    echo   每次电脑开机登录后，服务器会自动启动
    echo   访问地址: http://127.0.0.1:3000
    echo.
    echo   如需取消自启，运行 uninstall-autostart.bat
    echo ============================================
) else (
    echo [错误] 注册失败，请检查权限
)

echo.
pause
