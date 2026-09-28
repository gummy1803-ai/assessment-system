@echo off
chcp 65001 >nul
title 取消开机自启

echo ============================================
echo   取消干部考核系统开机自启
echo ============================================
echo.

REM 检查管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 请右键点击本脚本，选择"以管理员身份运行"
    pause
    exit /b 1
)

schtasks /Delete /TN "CadreAssessmentServer" /F

if %errorlevel% equ 0 (
    echo [成功] 已取消开机自启
) else (
    echo [提示] 未找到自启任务，可能已取消
)

echo.
pause
