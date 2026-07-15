@echo off
title Sudoku Launcher
setlocal enabledelayedexpansion

set PATH=D:\Flutter\bin;%PATH%
cd /d "%~dp0"

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

:phone
cls
echo.
echo   ------------------ Phone Install ------------------
echo.
echo   [1/4] Checking connected devices...
echo.
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
adb reverse tcp:8080 tcp:8080
echo.
echo   [3/4] Installing to phone...
flutter run
echo.
echo   [4/4] Done!
pause
goto menu

:web
cls
echo.
echo   ------------------ Web App ------------------
echo.

call :is_port_in_use 8080
if errorlevel 1 (
    echo   [INFO] Backend not running. Starting it now...
    start "SudokuBackend" cmd /c "cd /d server && dart run bin\server.dart"
    echo   Waiting for backend to be ready...
    call :wait_for_port 8080 30
    if errorlevel 1 (
        echo   [ERROR] Backend failed to start within 30 seconds.
        pause
        goto menu
    )
    echo   [OK] Backend started at http://localhost:8080
) else (
    echo   [OK] Backend already running at http://localhost:8080
)

echo.
call :kill_process_on_port 8081

echo   Launching web app at http://localhost:8081...
echo   (Press Ctrl+C in this window to stop the app)
echo.
flutter run -d edge --web-port 8081

echo.
set /p close_backend="  Stop the backend as well? [y/N]: "
if /i "!close_backend!"=="y" (
    call :stop_backend
    echo   Backend stopped.
) else (
    echo   Backend remains running (you can stop it later from main menu).
)
pause
goto menu

:start_backend
cls
echo.
echo   Starting backend...
call :is_port_in_use 8080
if not errorlevel 1 (
    echo   Backend is already running on port 8080.
    pause
    goto menu
)
start "SudokuBackend" cmd /c "cd /d server && dart run bin\server.dart"
echo   Waiting for backend to be ready...
call :wait_for_port 8080 30
if errorlevel 1 (
    echo   [ERROR] Backend failed to start.
) else (
    echo   [OK] Backend started.
)
pause
goto menu

:stop_backend
cls
echo.
echo   Stopping backend...
set "found="

taskkill /F /FI "WINDOWTITLE eq SudokuBackend" >nul 2>&1
if not errorlevel 1 (
    echo   [OK] Closed backend terminal window.
    set found=1
)

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

for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8080 " ^| findstr "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
    echo   [OK] Killed port 8080 process (PID: %%a)
    set found=1
)

if not defined found echo   No running backend process found.
pause
goto menu

:is_port_in_use
netstat -ano | findstr ":%1 " | findstr "LISTENING" >nul
exit /b %errorlevel%

:wait_for_port
set /a timeout=%2
:wait_loop
call :is_port_in_use %1
if not errorlevel 1 exit /b 0
set /a timeout-=1
if %timeout% leq 0 exit /b 1
timeout /t 1 /nobreak >nul
goto wait_loop

:kill_process_on_port
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%1 "') do (
    taskkill /F /PID %%a >nul 2>&1
)
exit /b 0

:end
cls
echo.
echo   See you!
timeout /t 2 /nobreak >nul
exit /b
