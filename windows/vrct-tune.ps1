# VRCT tune (Windows): filters out text Whisper invents from silence and music, translates
# about a second sooner, runs speech-to-text on an NVIDIA card and translation on the CPU,
# keeps VRCT behind every game for CPU time, picks models this PC runs smoothly (no frame
# spikes), plus a safe way to delete models.
#
#   Double-click "VRCT Tune.bat" for the menu, or from PowerShell:
#   .\vrct-tune.ps1 preset              apply the preset
#   .\vrct-tune.ps1 models              list downloaded models
#   .\vrct-tune.ps1 delete small base   delete models you don't want
#   .\vrct-tune.ps1 normalpriority      undo the lower CPU priority (asks for admin)
#
# VRCT saves its settings when it closes and re-downloads a selected model that is
# missing, so VRCT is closed (and reopened) around every change, and deleting the
# selected model switches VRCT to another downloaded one first.
# Kept ASCII-only on purpose: Windows PowerShell 5.1 misreads UTF-8 scripts without a BOM.
param(
    [Parameter(Position = 0)][string]$Command = "menu",
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Names = @(),
    [string]$VrctDir = (Join-Path $env:LOCALAPPDATA "VRCT")
)
$ErrorActionPreference = "Stop"
# PowerShell 5.1 otherwise writes arrays as {"value":[...],"Count":n}
Remove-TypeData System.Array -ErrorAction SilentlyContinue

$Config = Join-Path $VrctDir "config.json"
$Weights = Join-Path $VrctDir "weights"
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

# Best first. Anything VRCT supports that isn't listed ranks last.
$Kinds = [ordered]@{
    whisper     = @{ Dir = "whisper"; Key = "WHISPER_WEIGHT_TYPE"
                     Rank = @("large-v3-turbo", "large-v3-turbo-int8", "large-v3", "large-v2", "large-v1", "medium", "small", "base", "tiny") }
    ctranslate2 = @{ Dir = "ctranslate2"; Key = "CTRANSLATE2_WEIGHT_TYPE"
                     Rank = @("nllb-200-3.3B-ct2-int8", "nllb-200-distilled-1.3B-ct2-int8", "m2m100_1.2B-ct2-int8",
                              "nllb-200-distilled-600M-ct2-int8", "m2m100_418M-ct2-int8") }
}

# VRCT drops a Whisper segment if avg_logprob < AVG_LOGPROB or no_speech_prob > NO_SPEECH_PROB.
# Timeouts: seconds of audio (or silence) VRCT waits for before transcribing; 2 instead of 3
# shows text about a second sooner.
$Preset = [ordered]@{
    MIC_RECORD_TIMEOUT                    = 2
    MIC_PHRASE_TIMEOUT                    = 2
    SPEAKER_RECORD_TIMEOUT                = 2
    SPEAKER_PHRASE_TIMEOUT                = 2
    MIC_AUTOMATIC_THRESHOLD               = $true
    MIC_AVG_LOGPROB                       = -1.0
    MIC_NO_SPEECH_PROB                    = 0.5
    SPEAKER_AUTOMATIC_THRESHOLD           = $false
    SPEAKER_THRESHOLD                     = 300
    SPEAKER_AVG_LOGPROB                   = -1.0
    SPEAKER_NO_SPEECH_PROB                = 0.4
    USE_EXCLUDE_WORDS                     = $true
}
# Text Whisper invents from silence, music and noise. VRCT's word filter drops any
# message containing one of these, on mic and speaker. Whole phrases only.
$Hallucinations = '["\u5b57\u5e55\u5fd7\u613f\u8005", "\u4e2d\u6587\u5b57\u5e55", "\u5b57\u5e55\u7531", "\u5b57\u5e55by", "\u5b57\u5e55\u88fd\u4f5c", "\u4f18\u4f18\u72ec\u64ad\u5267\u573a", "\u512a\u512a\u7368\u64ad\u5287\u5834", "YoYo Television Series Exclusive", "\u8bf7\u4e0d\u541d\u70b9\u8d5e", "\u660e\u955c\u4e0e\u70b9\u70b9\u680f\u76ee", "\u8c22\u8c22\u89c2\u770b", "\u611f\u8c22\u89c2\u770b", "\u8b1d\u8b1d\u89c0\u770b", "Amara.org", "\u3054\u8996\u8074\u3042\u308a\u304c\u3068\u3046\u3054\u3056\u3044\u307e\u3057\u305f", "\u30c1\u30e3\u30f3\u30cd\u30eb\u767b\u9332", "\uc2dc\uccad\ud574\uc8fc\uc154\uc11c \uac10\uc0ac\ud569\ub2c8\ub2e4", "\uad6c\ub3c5\uacfc \uc88b\uc544\uc694", "Thanks for watching", "Thank you for watching", "Subtitles by", "Please subscribe", "Transcribed by", "Transcription by", "\u660e\u955c\u9700\u8981\u60a8\u7684\u652f\u6301", "\u6b22\u8fce\u8ba2\u9605", "\u70b9\u8d5e\u8ba2\u9605", "\u6253\u8d4f\u652f\u6301", "Like and subscribe"]' | ConvertFrom-Json

function Load-Config {
    if (-not (Test-Path $Config)) { throw "VRCT settings not found at $Config. Open VRCT once first (or pass -VrctDir)." }
    [System.IO.File]::ReadAllText($Config, $Utf8NoBom) | ConvertFrom-Json
}

function Save-Config($c) {
    Copy-Item $Config "$Config.before-tune" -Force
    # No BOM: VRCT can't read a config that starts with one
    [System.IO.File]::WriteAllText($Config, ($c | ConvertTo-Json -Depth 32), $Utf8NoBom)
}

function Set-Value($c, $key, $value) {
    if ($c.PSObject.Properties[$key]) { $c.$key = $value } else { $c | Add-Member -NotePropertyName $key -NotePropertyValue $value }
}

function Get-Installed($kind) {
    $k = $Kinds[$kind]
    $dir = Join-Path $Weights $k.Dir
    if (-not (Test-Path $dir)) { return @() }
    @(Get-ChildItem $dir -Directory | Where-Object { Test-Path (Join-Path $_.FullName "model.bin") } |
      ForEach-Object { $_.Name } | Sort-Object { Get-Rank $kind $_ })
}

function Get-Rank($kind, $name) {
    $i = [array]::IndexOf($Kinds[$kind].Rank, $name)
    if ($i -lt 0) { $Kinds[$kind].Rank.Count } else { $i }
}

# The next model no bigger than $want, else the smallest bigger one
# (never step up in size when a lighter model is downloaded: that costs frames).
function Get-Closest($kind, $want, $among) {
    $w = Get-Rank $kind $want
    $smaller = @($among | Where-Object { (Get-Rank $kind $_) -ge $w } | Sort-Object { Get-Rank $kind $_ })
    if ($smaller.Count) { return $smaller[0] }
    @($among | Sort-Object { Get-Rank $kind $_ } -Descending)[0]
}

function Get-SizeGB($path) {
    $bytes = (Get-ChildItem $path -Recurse -File | Measure-Object Length -Sum).Sum
    [math]::Round($bytes / 1GB, 2)
}

function Test-VrctRunning { [bool](Get-Process -Name "VRCT", "VRCT-sidecar" -ErrorAction SilentlyContinue) }

# Close VRCT, run $change, and reopen VRCT if it was open.
function Invoke-WithVrctClosed([scriptblock]$change) {
    $running = Test-VrctRunning
    if ($running) {
        Write-Host "Closing VRCT..."
        Get-Process -Name "VRCT" -ErrorAction SilentlyContinue | ForEach-Object { [void]$_.CloseMainWindow() }
        for ($i = 0; $i -lt 30 -and (Test-VrctRunning); $i++) { Start-Sleep -Seconds 1 }
        Get-Process -Name "VRCT", "VRCT-sidecar" -ErrorAction SilentlyContinue | Stop-Process -Force
        for ($i = 0; $i -lt 30 -and (Test-VrctRunning); $i++) { Start-Sleep -Seconds 1 }
        if (Test-VrctRunning) { throw "VRCT didn't close, nothing changed." }
    }
    try { & $change }
    finally {
        if ($running) {
            Write-Host "Reopening VRCT..."
            Start-Process (Join-Path $VrctDir "VRCT.exe") -WorkingDirectory $VrctDir
        }
    }
}

function Show-Models {
    $c = Load-Config
    foreach ($kind in $Kinds.Keys) {
        $sel = $c.($Kinds[$kind].Key)
        Write-Host "`n$kind (selected: $sel)"
        foreach ($n in Get-Installed $kind) {
            $mark = if ($n -eq $sel) { "*" } else { " " }
            Write-Host ("  {0} {1,-36} {2,5} GB" -f $mark, $n, (Get-SizeGB (Join-Path (Join-Path $Weights $Kinds[$kind].Dir) $n)))
        }
    }
}

# Draw VRCT's window without the GPU so it can't cause VRChat frame spikes. VRCT's window is a
# WebView2 page; this is its "use hardware acceleration" setting, read when VRCT starts.
function Disable-WindowGpu {
    $dir = Join-Path $env:LOCALAPPDATA "com.vrct.app\EBWebView"
    $file = Join-Path $dir "Local State"
    # WebView2 writes this file as it exits, so let VRCT's leftover WebView processes finish first
    for ($i = 0; $i -lt 15 -and (Get-CimInstance Win32_Process -Filter "Name='msedgewebview2.exe'" |
            Where-Object { $_.CommandLine -like "*com.vrct.app*" }); $i++) { Start-Sleep -Seconds 1 }
    $state = $null
    if (Test-Path $file) {
        try { $state = [System.IO.File]::ReadAllText($file, $Utf8NoBom) | ConvertFrom-Json }
        catch { Write-Host "Couldn't read VRCT's window settings, left the GPU setting alone."; return }
    }
    if ($null -eq $state) { $state = New-Object PSObject; [void](New-Item -ItemType Directory -Force $dir) }
    Set-Value $state "hardware_acceleration_mode" ([PSCustomObject]@{ enabled = $false })
    [System.IO.File]::WriteAllText($file, ($state | ConvertTo-Json -Depth 100 -Compress), $Utf8NoBom)
}

# VRCT (window and VRCT-sidecar.exe, where speech-to-text and translation run) starts at
# below-normal priority from now on, so VRChat and any other game always get the CPU first
# and VRCT waits instead of causing frame spikes. It's a machine-wide setting (Image File
# Execution Options), so it needs admin.
$Ifeo = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
$PriorityKeys = @("VRCT.exe", "VRCT-sidecar.exe" | ForEach-Object { "$Ifeo\$_\PerfOptions" })
$BelowNormal = 5

# The NVIDIA card as VRCT lists it, or $null when speech-to-text has to stay on the CPU.
# Only VRCT's GPU edition can use the card (the CPU edition has no CUDA). VRCT only accepts a
# device exactly as it lists it, so this rebuilds its entry: name, and the compute types
# CTranslate2 supports on that card generation (RTX 20: no bfloat16; RTX 30 and newer: bfloat16).
# If it doesn't match, VRCT keeps its default, the CPU, so nothing breaks.
function Get-CudaDevice {
    if (-not (Test-Path (Join-Path $VrctDir "_internal\torch\lib\torch_cuda.dll"))) {
        Write-Host "VRCT is the CPU edition, so speech-to-text stays on the CPU. For the GPU: VRCT >" -ForegroundColor Yellow
        Write-Host "Settings > update (version) > CUDA (CPU/GPU), then apply this preset again." -ForegroundColor Yellow
        return $null
    }
    $gpu = @(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match "NVIDIA .*RTX \d0\d0" })
    if (-not $gpu.Count -or $gpu[0].Name -notmatch "RTX (\d)0\d0") {
        Write-Host "No NVIDIA RTX card found, speech-to-text stays on the CPU." -ForegroundColor Yellow
        return $null
    }
    $types = if ([int]$Matches[1] -ge 3) { @("bfloat16", "float16", "float32", "int8", "int8_bfloat16", "int8_float16", "int8_float32") }
             else { @("float16", "float32", "int8", "int8_float16", "int8_float32") }
    [ordered]@{ device = "cuda"; device_index = 0; device_name = $gpu[0].Name; compute_types = @("auto") + $types }
}

# Models that run without falling behind (so VRCT isn't pinning cores the game needs). On the
# NVIDIA card speech-to-text is fast with the best model (~1 GB of video memory); on the CPU
# VRCT runs each model on 4 threads, so spare cores are what keeps games smooth.
# Never picks a heavier model than the one already selected.
function Get-FitModels([bool]$whisperOnGpu) {
    $cores = (Get-CimInstance Win32_Processor | Measure-Object NumberOfCores -Sum).Sum
    $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    # Speech-to-text runs non-stop on mic and speaker, so on the CPU "small" is the ceiling:
    # large-v3-turbo on the CPU keeps several cores busy all the time, even on 8+ core PCs
    $fit = if ($cores -ge 8) { @{ whisper = "small"; ctranslate2 = "nllb-200-distilled-1.3B-ct2-int8" } }
           elseif ($cores -ge 6) { @{ whisper = "small"; ctranslate2 = "nllb-200-distilled-600M-ct2-int8" } }
           else { @{ whisper = "base"; ctranslate2 = "nllb-200-distilled-600M-ct2-int8" } }
    if ($ramGB -lt 16) { $fit.ctranslate2 = "nllb-200-distilled-600M-ct2-int8" }  # leave RAM to the game
    if ($whisperOnGpu) { $fit.whisper = "large-v3-turbo" }
    Write-Host "This PC: $cores CPU cores, $ramGB GB RAM"
    $fit
}

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Run this script's $command as admin (Windows asks first); false if that was declined.
function Invoke-AsAdmin([string]$command) {
    try {
        $p = Start-Process powershell -Verb RunAs -Wait -PassThru -WindowStyle Hidden `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $command"
        return $p.ExitCode -eq 0
    } catch { return $false }
}

function Set-LowPriority {
    $set = @($PriorityKeys | Where-Object { (Get-ItemProperty $_ -ErrorAction SilentlyContinue).CpuPriorityClass -eq $BelowNormal })
    if ($set.Count -eq $PriorityKeys.Count) { return }
    if (Test-Admin) {
        foreach ($key in $PriorityKeys) {
            [void](New-Item $key -Force)
            Set-ItemProperty $key CpuPriorityClass $BelowNormal -Type DWord
        }
    } elseif (Invoke-AsAdmin "lowpriority") {
        Write-Host "VRCT now runs behind your games for CPU time."
    } else {
        Write-Host "Skipped the lower CPU priority (needs admin). Everything else was applied." -ForegroundColor Yellow
    }
}

function Set-NormalPriority {
    if (Test-Admin) { $PriorityKeys | ForEach-Object { Remove-Item (Split-Path $_) -Recurse -ErrorAction SilentlyContinue } }
    elseif (Invoke-AsAdmin "normalpriority") { Write-Host "VRCT runs at normal priority again (from its next start)." }
    else { throw "Needs admin to change it back." }
}

function Invoke-Preset {
    Invoke-WithVrctClosed {
        Disable-WindowGpu
        Set-LowPriority
        $c = Load-Config  # read only once VRCT is closed: it saves settings as it exits
        foreach ($key in $Preset.Keys) { Set-Value $c $key $Preset[$key] }
        # Speech-to-text on the NVIDIA card when VRCT can use it; translation on the CPU. Without
        # a device key VRCT uses its default device, the CPU. "auto" picks int8 on the card, the
        # lightest on video memory.
        $gpu = Get-CudaDevice
        if ($gpu) { Set-Value $c "SELECTED_TRANSCRIPTION_COMPUTE_DEVICE" ([PSCustomObject]$gpu); Write-Host "speech-to-text: $($gpu.device_name)" }
        else { $c.PSObject.Properties.Remove("SELECTED_TRANSCRIPTION_COMPUTE_DEVICE") }
        $c.PSObject.Properties.Remove("SELECTED_TRANSLATION_COMPUTE_DEVICE")
        Write-Host "translation: CPU"
        Set-Value $c "SELECTED_TRANSCRIPTION_COMPUTE_TYPE" "auto"
        Set-Value $c "SELECTED_TRANSLATION_COMPUTE_TYPE" "auto"
        # VRCT downloads a selected model that isn't there yet when it starts
        $fit = Get-FitModels ([bool]$gpu)
        foreach ($kind in $Kinds.Keys) {
            $key = $Kinds[$kind].Key
            if ((Get-Rank $kind $fit[$kind]) -gt (Get-Rank $kind $c.$key)) {
                Write-Host "$kind model: $($c.$key) -> $($fit[$kind])"
                Set-Value $c $key $fit[$kind]
            } else { Write-Host "$kind model: $($c.$key) (fits)" }
        }
        $have = @($c.MIC_WORD_FILTER | ForEach-Object { "$_".ToLower() })
        $add = @($Hallucinations | Where-Object { $have -notcontains $_.ToLower() })
        Set-Value $c "MIC_WORD_FILTER" @(@($c.MIC_WORD_FILTER | Where-Object { $_ -ne $null }) + $add)
        Save-Config $c
    }
    Write-Host "Applied the preset."
}

function Invoke-Delete([string[]]$names) {
    $plan = @()
    foreach ($n in $names) {
        $kind = @($Kinds.Keys | Where-Object { (Get-Installed $_) -contains $n })
        if (-not $kind.Count) { throw "'$n' isn't downloaded. Run: .\vrct-tune.ps1 models" }
        $plan += , @($kind[0], $n)
    }
    foreach ($kind in $Kinds.Keys) {
        $doomed = @($plan | Where-Object { $_[0] -eq $kind } | ForEach-Object { $_[1] })
        $left = @(Get-Installed $kind | Where-Object { $doomed -notcontains $_ })
        if ($doomed.Count -and -not $left.Count) { throw "Refusing to delete every $kind model: VRCT would just download one again." }
    }
    Invoke-WithVrctClosed {
        $c = Load-Config  # read only once VRCT is closed: it saves settings as it exits
        $switched = $false
        foreach ($kind in $Kinds.Keys) {
            $key = $Kinds[$kind].Key
            $doomed = @($plan | Where-Object { $_[0] -eq $kind } | ForEach-Object { $_[1] })
            if ($doomed -contains $c.$key) {
                $new = Get-Closest $kind $c.$key @(Get-Installed $kind | Where-Object { $doomed -notcontains $_ })
                Write-Host "$($c.$key) is selected; switching VRCT to $new"
                $c.$key = $new
                $switched = $true
            }
        }
        if ($switched) { Save-Config $c }
        foreach ($p in $plan) {
            $path = Join-Path (Join-Path $Weights $Kinds[$p[0]].Dir) $p[1]
            $gb = Get-SizeGB $path
            Remove-Item $path -Recurse -Force
            Write-Host "Deleted $($p[1]) ($gb GB)"
        }
    }
}

function Show-Menu {
    while ($true) {
        Write-Host "`nVRCT tune`n  1) Apply the preset`n  2) Show downloaded models`n  3) Delete models`n  q) Quit"
        switch (Read-Host "Choose") {
            "1" { Invoke-Preset }
            "2" { Show-Models }
            "3" {
                Show-Models
                $names = @((Read-Host "`nModel names to delete, separated by spaces (blank = cancel)") -split "\s+" | Where-Object { $_ })
                if ($names.Count) { Invoke-Delete $names }
            }
            "q" { return }
        }
    }
}

try {
    switch ($Command) {
        "menu" { Show-Menu }
        "preset" { Invoke-Preset }
        "models" { Show-Models }
        "delete" { if (-not $Names.Count) { throw "Name the models to delete, e.g. .\vrct-tune.ps1 delete medium" }; Invoke-Delete $Names }
        "normalpriority" { Set-NormalPriority }
        "lowpriority" { Set-LowPriority }  # run as admin by Set-LowPriority
        default { throw "Unknown command '$Command'. Use: menu, preset, models, delete <names>, normalpriority" }
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($Command -eq "menu") { Read-Host "Press Enter to close" }
    exit 1
}
