@echo off
chcp 65001 >nul
title 注册 Supabase 定时保活

echo ============================================
echo   Supabase 保活任务 - 安装
echo ============================================
echo.

cd /d "%~dp0"

REM 检查管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 请右键点击本脚本，选择"以管理员身份运行"
    pause
    exit /b 1
)

set TASK_NAME=SupabaseKeepAlive
set SCRIPT_PATH=%~dp0keep-alive.js

REM 获取 node.exe 的完整路径
for /f "delims=" %%i in ('where node') do set NODE_PATH=%%i

echo [信息] Node 路径: %NODE_PATH%
echo [信息] 脚本路径: %SCRIPT_PATH%
echo.

REM 删除已有任务
schtasks /Delete /TN "%TASK_NAME%" /F >nul 2>&1

REM 创建每天凌晨 3 点执行的任务
schtasks /Create /TN "%TASK_NAME%" /TR "\"%NODE_PATH%\" \"%SCRIPT_PATH%\"" /SC DAILY /ST 03:00 /RL HIGHEST /F

if %errorlevel% equ 0 (
    echo.
    echo ============================================
    echo   安装成功！
    echo.
    echo   每天凌晨 3:00 会自动向 Supabase 发送请求
    echo   防止项目因 7 天无活动而休眠
    echo ============================================
) else (
    echo [错误] 注册失败
)

echo.
pause
