# Install vrct-relay on Windows: it starts hidden at every login and answers VRCT's
# "OpenAI Compatible" translation engine on this PC (and friends on the same network).
#
#   Double-click "Install relay.bat", or from PowerShell:
#   .\install-relay.ps1              install (or update) and start it
#   .\install-relay.ps1 -Uninstall   stop it and remove it from startup (keeps your notes and keys)
#
# API keys come from VRCT's own settings (Gemini and/or DeepL). The Obsidian notes
# (the relay's brain) are copied to Documents\VRCT Brain once; edit them there.
# Kept ASCII-only on purpose: Windows PowerShell 5.1 misreads UTF-8 scripts without a BOM.
param([switch]$Uninstall)
$ErrorActionPreference = "Stop"

$Repo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Dest = Join-Path $env:LOCALAPPDATA "vrct-relay"
$Script = Join-Path $Dest "vrct-relay.py"
$Brain = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "VRCT Brain"
$Shortcut = Join-Path ([Environment]::GetFolderPath("Startup")) "vrct-relay.lnk"
$KeysFile = Join-Path $env:APPDATA "vrct-relay\keys.json"
$VrctConfig = Join-Path $env:LOCALAPPDATA "VRCT\config.json"
$Port = 8765

function Stop-Relay {
    Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" |
        Where-Object { $_.CommandLine -like "*vrct-relay.py*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

# python.exe of an installed Python 3.8+ (the py launcher first; the "python" Store stub prints nothing)
function Find-Python {
    $check = @("-c", "import sys; assert sys.version_info >= (3, 8); print(sys.executable)")
    foreach ($try in @(@{ Exe = "py"; Args = @("-3") + $check }, @{ Exe = "python"; Args = $check })) {
        $exe = $null
        try { $exe = & $try.Exe @($try.Args) 2>$null } catch {}
        if ($exe -and (Test-Path $exe)) { return $exe }
    }
    throw "Python 3.8 or newer isn't installed. Get it from https://www.python.org/downloads/ (tick 'Add python.exe to PATH'), then run this again."
}

function Test-Keys {
    if (Test-Path $KeysFile) { return $true }
    if (-not (Test-Path $VrctConfig)) { return $false }
    $k = ([System.IO.File]::ReadAllText($VrctConfig) | ConvertFrom-Json).AUTH_KEYS
    return [bool]($k.Gemini_API -or $k.DeepL_API)
}

function Wait-Relay {
    for ($i = 0; $i -lt 20; $i++) {
        $tcp = New-Object Net.Sockets.TcpClient
        try { $tcp.Connect("127.0.0.1", $Port); return $true } catch { Start-Sleep -Milliseconds 500 } finally { $tcp.Dispose() }
    }
    return $false
}

try {
    Stop-Relay
    if ($Uninstall) {
        Remove-Item $Shortcut -ErrorAction SilentlyContinue
        [Environment]::SetEnvironmentVariable("VRCT_BRAIN_DIR", $null, "User")
        Write-Host "vrct-relay stopped and removed from startup. Your notes ($Brain) and keys were kept."
        exit 0
    }

    $python = Find-Python
    $pythonw = Join-Path (Split-Path $python) "pythonw.exe"
    [void](New-Item -ItemType Directory -Force $Dest)
    Copy-Item (Join-Path $Repo "bin\vrct-relay") $Script -Force
    if (-not (Test-Path $Brain)) {
        Copy-Item (Join-Path $Repo "obsidian\VRCT Chinese-English") $Brain -Recurse
        Write-Host "Notes copied to $Brain (open that folder as an Obsidian vault to edit them)."
    }
    # Documents may live in OneDrive, so tell the relay exactly where the notes are
    [Environment]::SetEnvironmentVariable("VRCT_BRAIN_DIR", $Brain, "User")
    $env:VRCT_BRAIN_DIR = $Brain

    if (-not (Test-Keys)) {
        Write-Host "No Gemini or DeepL key found in VRCT's settings." -ForegroundColor Yellow
        $gemini = Read-Host "Gemini API key (blank to skip)"
        $deepl = Read-Host "DeepL API key (blank to skip)"
        if (-not ($gemini -or $deepl)) { throw "The relay needs at least one key. Enter one in VRCT's settings or here." }
        [void](New-Item -ItemType Directory -Force (Split-Path $KeysFile))
        [System.IO.File]::WriteAllText($KeysFile, (@{ Gemini_API = $gemini; DeepL_API = $deepl } | ConvertTo-Json))
    }

    $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut($Shortcut)
    $lnk.TargetPath = $pythonw
    $lnk.Arguments = "`"$Script`""
    $lnk.WorkingDirectory = $Dest
    $lnk.Save()
    Start-Process $pythonw -ArgumentList "`"$Script`"" -WorkingDirectory $Dest -WindowStyle Hidden
    if (-not (Wait-Relay)) { throw "The relay didn't start. Run: `"$python`" `"$Script`" to see why." }

    Write-Host "`nvrct-relay is running and starts with Windows." -ForegroundColor Green
    Write-Host "If Windows asks whether Python may use the network, allow Private networks (needed for friends).`n"
    & $python $Script info
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
