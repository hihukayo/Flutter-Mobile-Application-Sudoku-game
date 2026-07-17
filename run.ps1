# Sudoku Launcher for PowerShell

$ROOT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$FLUTTER_DIR = $ROOT_DIR
$SERVER_DIR = Join-Path $ROOT_DIR "server"

# Detect Dart
$DART_EXE = "dart"
if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
    $dartPaths = @(
        "D:\Flutter\bin\dart.bat",
        "D:\Flutter\bin\dart.exe"
    )
    foreach ($p in $dartPaths) {
        if (Test-Path $p) { $DART_EXE = $p; break }
    }
}

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "  ------------------ Sudoku Launcher ------------------"
    Write-Host "     [1]  Install to Phone"
    Write-Host "     [2]  Launch Web App (auto-start backend)"
    Write-Host "     [3]  Start Backend Only"
    Write-Host "     [4]  Stop Backend"
    Write-Host "     [5]  Exit"
    Write-Host "  -----------------------------------------------------"
    Write-Host ""
    $choice = Read-Host "  Select [1/2/3/4/5]"
    return $choice
}

function Wait-ForPort($port, $timeoutSeconds) {
    $end = (Get-Date).AddSeconds($timeoutSeconds)
    while ((Get-Date) -lt $end) {
        $conn = netstat -ano | Select-String ":$port " | Select-String "LISTENING"
        if ($conn) { return $true }
        Start-Sleep -Seconds 1
    }
    return $false
}

function Stop-Backend {
    Write-Host ""
    Write-Host "  ------------------ Stop Backend ------------------"
    Write-Host ""
    $found = $false

    # Kill by window title
    $procs = Get-Process | Where-Object { $_.MainWindowTitle -eq "SudokuBackend" }
    if ($procs) {
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Closed backend terminal window."
        $found = $true
    }

    # Kill dart.exe running server.dart
    Get-Process dart -ErrorAction SilentlyContinue | ForEach-Object {
        $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine
        if ($cmdLine -and $cmdLine.Contains("server.dart")) {
            $_ | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] Killed backend process (PID: $($_.Id))"
            $found = $true
        }
    }

    # Kill whatever is on port 8080
    $pidOnPort = netstat -ano | Select-String ":8080 " | Select-String "LISTENING" | ForEach-Object {
        $_ -replace '.*\s+(\d+)$', '$1'
    }
    if ($pidOnPort) {
        $pidOnPort | ForEach-Object {
            Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] Killed port 8080 process (PID: $_)"
            $found = $true
        }
    }

    if (-not $found) { Write-Host "  No running backend process found." }
}

function Install-Phone {
    Clear-Host
    Write-Host ""
    Write-Host "  ------------------ Phone Install ------------------"
    Write-Host ""
    Set-Location $FLUTTER_DIR

    Write-Host "  [1/4] Checking connected devices..."
    $devices = flutter devices 2>$null | Select-String "mobile"
    if (-not $devices) {
        Write-Host "  [FAILED] No phone detected."
        Write-Host "  Connect USB and enable USB debugging, then try again."
        Read-Host "Press Enter to continue"
        return
    }
    Write-Host "  [OK] Phone found:"
    $devices

    Write-Host ""
    Write-Host "  [2/4] Setting up ADB port forwarding (8080 <-> 8080)..."
    adb reverse tcp:8080 tcp:8080 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "  [INFO] ADB forward skipped or already set." }

    Write-Host ""
    Write-Host "  [3/4] Installing to phone..."
    Write-Host "  (First run will compile the app, please wait.)"
    Write-Host ""
    flutter run
    Write-Host ""
    Write-Host "  [4/4] Done!"
    Read-Host "Press Enter to continue"
}

function Start-WebApp {
    Clear-Host
    Write-Host ""
    Write-Host "  ------------------ Web App (Same-Port Mode) ------------------"
    Write-Host ""
    Set-Location $FLUTTER_DIR

    # 1. Build
    Write-Host "  [1/3] Building web app..."
    flutter build web --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Web build failed."
        Read-Host "Press Enter to continue"
        return
    }
    Write-Host "  [OK] Web app built."

    # 2. Start backend
    Write-Host ""
    Write-Host "  [2/3] Starting backend..."
    $serverFile = Join-Path $SERVER_DIR "bin\server.dart"
    if (-not (Test-Path $serverFile)) {
        Write-Host "  [ERROR] Server file not found: $serverFile"
        Read-Host "Press Enter to continue"
        return
    }

    # Kill anything on port 8080
    netstat -ano | Select-String ":8080 " | Select-String "LISTENING" | ForEach-Object {
        $pid = $_ -replace '.*\s+(\d+)$', '$1'
        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
    }

    # Start backend in a new window
    $sw = "-NoExit -Command Set-Location '$SERVER_DIR'; $DART_EXE run bin\server.dart"
    Start-Process powershell -ArgumentList $sw -WindowStyle Minimized

    Write-Host "  Waiting for backend (port 8080) to be ready..."
    $ready = Wait-ForPort 8080 30
    if (-not $ready) {
        Write-Host "  [ERROR] Backend failed to start. Make sure MySQL is running."
        Write-Host ""
        Write-Host "  Tips:"
        Write-Host "    - Check MySQL is running on localhost:3306"
        Write-Host "    - Run option [3] to see error details"
        Write-Host "    - Or manually run: cd server && $DART_EXE run bin\server.dart"
        Read-Host "Press Enter to continue"
        return
    }
    Write-Host "  [OK] Backend started on port 8080."

    # 3. Open browser
    Write-Host ""
    Write-Host "  [3/3] Opening web browser..."
    Write-Host ""
    Write-Host "  ! Frontend and backend share the same port - no CORS issues"
    Write-Host "  ! Open http://127.0.0.1:8080 if it doesn't auto-open"
    Write-Host ""
    Start-Process "http://127.0.0.1:8080"

    # 4. Wait
    Write-Host ""
    Read-Host "Press Enter to stop the backend and return to menu"
    Stop-Backend
    Write-Host "  Backend stopped."
    Read-Host "Press Enter to continue"
}

function Start-BackendOnly {
    Clear-Host
    Write-Host ""
    Write-Host "  ------------------ Start Backend ------------------"
    Write-Host ""
    Set-Location $SERVER_DIR

    if (-not (Test-Path "bin\server.dart")) {
        Write-Host "  [ERROR] Server file not found: bin\server.dart"
        Read-Host "Press Enter to continue"
        return
    }

    $conn = netstat -ano | Select-String ":8080 " | Select-String "LISTENING"
    if ($conn) {
        Write-Host "  Backend is already running on port 8080."
        Write-Host "  (Use option 4 to stop it first if you want to restart)"
        Read-Host "Press Enter to continue"
        return
    }

    Write-Host "  Starting backend..."
    $sw = "-NoExit -Command Set-Location '$SERVER_DIR'; $DART_EXE run bin\server.dart"
    Start-Process powershell -ArgumentList $sw -WindowStyle Minimized

    Write-Host "  Waiting for backend to be ready..."
    $ready = Wait-ForPort 8080 30
    if ($ready) {
        Write-Host "  [OK] Backend started on port 8080."
    } else {
        Write-Host "  [ERROR] Backend failed to start."
        Write-Host ""
        Write-Host "  Run this manually to see the error:"
        Write-Host "    cd $SERVER_DIR && $DART_EXE run bin\server.dart"
    }
    Read-Host "Press Enter to continue"
}

# ======================== Main Loop ========================
while ($true) {
    $choice = Show-Menu
    switch ($choice) {
        "1" { Install-Phone }
        "2" { Start-WebApp }
        "3" { Start-BackendOnly }
        "4" { Stop-Backend; Read-Host "Press Enter to continue" }
        "5" {
            Clear-Host
            Write-Host ""
            Write-Host "  See you!"
            Start-Sleep -Seconds 1
            exit 0
        }
    }
}
