@echo off
chcp 65001 >nul
title 干部考核管理系统服务器

REM ============================================
REM 干部考核管理系统 - 服务器启动脚本
REM 功能：自动启动 Node.js 服务器，处理端口占用
REM ============================================

REM 切换到脚本所在目录
cd /d "%~dp0"

echo ============================================
echo   干部考核管理系统 - 服务器启动中...
echo ============================================
echo.

REM 检查 Node.js 是否安装
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未检测到 Node.js，请先安装 Node.js
    echo 下载地址: https://nodejs.org/
    pause
    exit /b 1
)

REM 检查依赖是否安装
if not exist "node_modules" (
    echo [提示] 首次运行，正在安装依赖...
    call npm install
    if %errorlevel% neq 0 (
        echo [错误] 依赖安装失败
        pause
        exit /b 1
    )
)

REM 检查并清理占用 3000 端口的进程
echo [检查] 正在检测 3000 端口...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":3000" ^| findstr "LISTENING"') do (
    echo [清理] 终止占用端口的进程 PID: %%a
    taskkill /PID %%a /F >nul 2>nul
)

REM 获取本机 IP 地址
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set LOCAL_IP=%%a
    goto :got_ip
)
:got_ip
set LOCAL_IP=%LOCAL_IP: =%

echo.
echo ============================================
echo   服务器启动成功！
echo.
echo   本机访问: http://127.0.0.1:3000
echo   局域网访问: http://%LOCAL_IP%:3000
echo.
echo   提示: 关闭此窗口将停止服务器
echo ============================================
echo.

REM 启动服务器，日志写入文件
node server.js

echo.
echo [警告] 服务器已停止运行
pause
