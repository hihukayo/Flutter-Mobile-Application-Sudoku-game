@echo off
title Sudoku Launcher
setlocal enabledelayedexpansion

:: ========== Project Paths ==========
set "ROOT_DIR=%~dp0"
set "FLUTTER_DIR=%ROOT_DIR%sudoku"
set "SERVER_DIR=%FLUTTER_DIR%\server"

:: 确保 Flutter/Dart 在 PATH 中（新窗口启动时需要）
set "PATH=D:\Flutter\bin;%PATH%"

:: ========== Main Menu ==========
:menu
cls
echo.
echo   ------------------ Sudoku Launcher ------------------
echo      [1]  Install to Phone
echo      [2]  Launch Web App (auto-start backend)
echo      [3]  Start Backend Only
echo      [4]  Stop Backend
echo      [5]  Exit
echo   -----------------------------------------------------
echo.
set /p choice="  Select [1/2/3/4/5]: "

if "%choice%"=="1" goto phone
if "%choice%"=="2" goto web
if "%choice%"=="3" goto start_backend
if "%choice%"=="4" goto stop_backend
if "%choice%"=="5" goto end
goto menu

:: ======================== Install to Phone ========================
:phone
cls
echo.
echo   ------------------ Phone Install ------------------
echo.
cd /d "%FLUTTER_DIR%" || (
    echo   [ERROR] Project directory not found: %FLUTTER_DIR%
    pause
    goto menu
)

echo   [1/4] Checking connected devices...
flutter devices 2>nul | findstr "mobile" >nul
if errorlevel 1 (
    echo   [FAILED] No phone detected.
    echo   Connect USB and enable USB debugging, then try again.
    pause
    goto menu
)
echo   [OK] Phone found:
flutter devices 2>nul | findstr "mobile"

echo.
echo   [2/4] Setting up ADB port forwarding (8080 ^<-> 8080)...
adb reverse tcp:8080 tcp:8080 2>nul
if errorlevel 1 echo   [INFO] ADB forward skipped or already set.

echo.
echo   [3/4] Installing to phone...
echo   (First run will compile the app, please wait.)
echo.
flutter run
echo.
echo   [4/4] Done!
pause
goto menu

:: ======================== Web App (Build + Serve, no CORS) ========================
:web
cls
echo.
echo   ------------------ Web App (同端口模式) ------------------
echo.
cd /d "%FLUTTER_DIR%" || (
    echo   [ERROR] Project directory not found: %FLUTTER_DIR%
    pause
    goto menu
)

:: 1. Build Flutter Web 静态文件
echo   [1/3] Building web app...
flutter build web --release
if errorlevel 1 (
    echo   [ERROR] Web build failed.
    pause
    goto menu
)
echo   [OK] Web app built.

:: 2. Kill old backend and start fresh
echo.
echo   [2/3] Stopping old backend...
:: 强制杀掉占用 8080 端口的任何进程
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8080 " ^| findstr "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
)
timeout /t 2 /nobreak >nul
echo   Starting backend (serves API + frontend on port 8080)...
cd /d "%SERVER_DIR%"
start "SudokuBackend" /MIN D:\Flutter\bin\dart.exe run bin\server.dart
cd /d "%FLUTTER_DIR%"
call :wait_for_port 8080 30
if errorlevel 1 (
    echo   [ERROR] Backend failed to start.
    pause
    goto menu
)
echo   [OK] Backend started.

:: 3. Open browser
echo.
echo   [3/3] Opening http://127.0.0.1:8080 ...
echo.
echo   ! 前后端都在同一端口，没有跨域问题
echo   ! 如需热重载，请单独运行 flutter run -d edge
echo.
start http://127.0.0.1:8080

:: 4. Wait for user to close backend
echo.
echo   Press any key to stop the backend and return to menu...
pause >nul
call :stop_backend
echo   Backend stopped.
pause
goto menu

:: ======================== Start Backend Only ========================
:start_backend
cls
echo.
echo   ------------------ Start Backend ------------------
echo.
call :is_port_in_use 8080
if not errorlevel 1 (
    echo   Backend is already running on port 8080.
    echo   (Use option 4 to stop it first if you want to restart)
    pause
    goto menu
)
cd /d "%SERVER_DIR%" || (
    echo   [ERROR] Server directory not found: %SERVER_DIR%
    pause
    goto menu
)
echo   Starting backend...
cd /d "%SERVER_DIR%"
start "SudokuBackend" /MIN D:\Flutter\bin\dart.exe run bin\server.dart
echo   Waiting for backend to be ready...
call :wait_for_port 8080 30
if errorlevel 1 (
    echo   [ERROR] Backend failed to start.
) else (
    echo   [OK] Backend started.
)
pause
goto menu

:: ======================== Stop Backend ========================
:stop_backend
cls
echo.
echo   ------------------ Stop Backend ------------------
echo.

set "found="

:: Method 1: Kill by window title
taskkill /F /FI "WINDOWTITLE eq SudokuBackend" >nul 2>&1
if not errorlevel 1 (
    echo   [OK] Closed backend terminal window.
    set found=1
)

:: Method 2: Find dart.exe processes running server.dart
for /f "tokens=2 delims== " %%a in ('wmic process where "name='dart.exe'" get ProcessId /value 2^>nul') do (
    set "pid=%%a"
    if defined pid (
        wmic process where "ProcessId=!pid!" get CommandLine /value 2>nul | findstr /i "server.dart" >nul
        if not errorlevel 1 (
            taskkill /F /PID !pid! >nul 2>&1
            echo   [OK] Killed backend process (PID: !pid!)
            set found=1
        )
    )
)

:: Method 3: Kill whatever is listening on port 8080
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8080 " ^| findstr "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
    echo   [OK] Killed port 8080 process (PID: %%a)
    set found=1
)

if not defined found echo   No running backend process found.
pause
goto menu

:: ======================== Helper Functions ========================

:is_port_in_use <port>
:: Returns errorlevel=0 if port is in use, errorlevel=1 if free
netstat -ano | findstr ":%1 " | findstr "LISTENING" >nul
exit /b %errorlevel%

:wait_for_port <port> <timeout_seconds>
:: Wait for a port to become active (max N seconds)
set /a timeout_remaining=%~2
:wait_loop
call :is_port_in_use %1
if not errorlevel 1 exit /b 0
set /a timeout_remaining-=1
if !timeout_remaining! leq 0 exit /b 1
timeout /t 1 /nobreak >nul
goto wait_loop

:kill_process_on_port <port>
:: Kill all processes listening on a given port
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%1 "') do (
    taskkill /F /PID %%a >nul 2>&1
)
exit /b 0

:: ======================== Exit ========================
:end
cls
echo.
echo   See you!
timeout /t 2 /nobreak >nul
exit /b 0
