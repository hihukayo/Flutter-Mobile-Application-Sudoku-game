@echo off
title Sudoku Launcher
set PATH=D:\Flutter\bin;%PATH%
cd /d "%~dp0sudoku"

:menu
cls
echo.
echo   ------------------ Sudoku Launcher ------------------
echo      [1]  Install to Phone
echo      [2]  Launch Web App
echo      [3]  Exit
echo   -----------------------------------------------------
echo.

set /p choice="  Select [1/2/3]: "

if "%choice%"=="1" goto phone
if "%choice%"=="2" goto web
if "%choice%"=="3" goto end
goto menu

:phone
cls
echo.
echo   ------------------ Phone Debug ------------------
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
echo   [2/4] Setting up ADB port forwarding (8080 ^<-^> 8080)...
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
echo   [1/2] Starting backend server...
start "SudokuBackend" cmd /c "dart run bin\server.dart"
timeout /t 4 /nobreak >nul
echo   [OK] Backend at http://localhost:8080
echo.
echo   [2/2] Launching web app at http://localhost:8081...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8081 "') do (
    taskkill /F /PID %%a >nul 2>&1
)
flutter run -d edge --web-port 8081
taskkill /F /IM dart.exe >nul 2>&1
pause
goto menu

:end
cls
echo.
echo   See you!
timeout /t 2 /nobreak >nul
