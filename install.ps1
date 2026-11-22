# Wrought installer and updater for Windows. Installs for the current user only; no admin rights needed.
# Run install.cmd, or: powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
param([Parameter(Position = 0)][string]$PairCode = "", [switch]$Scheduled, [switch]$AtLogon, [switch]$Rollback, [switch]$Repair, [switch]$Apply, [switch]$StageOnly)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Repo = "OrangeGamer1912/SRV2-App"
$ReleaseApi = "https://api.github.com/repos/$Repo/releases/latest"
$DownloadPrefix = "https://github.com/$Repo/releases/download/"
$ZipPattern = '^Wrought-(\d+\.\d+\.\d+)-win\.zip$'
$Scripts = @("install.ps1", "uninstall.ps1")
$Root = Join-Path $env:LOCALAPPDATA "Programs\Wrought"
$App = Join-Path $Root "app"
$Previous = Join-Path $Root "previous"
$Staged = Join-Path $Root "staged"
$Download = Join-Path $Root "download"
$Updater = Join-Path $Root "updater"
$LogFile = Join-Path $Root "updater.log"
$VersionFile = "wrought-version.txt"
$Exe = "Wrought.exe"
$PairCodePattern = '^[A-Za-z0-9_-]{4,64}$'
$TaskName = "Wrought updater"
$DailyAt = "12:30"
$JustStartedMinutes = 2
$LogLines = 300
$UninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Wrought"
$StartMenuLink = Join-Path ([Environment]::GetFolderPath("Programs")) "Wrought.lnk"
$DesktopLink = Join-Path ([Environment]::GetFolderPath("Desktop")) "Wrought.lnk"
$Agent = @{ "User-Agent" = "Wrought-installer" }

function Say([string]$Text) {
    if (-not $Scheduled) { Write-Host $Text }
    try {
        New-Item -ItemType Directory -Force -Path $Root | Out-Null
        Add-Content -Path $LogFile -Value ("{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Text)
        $kept = Get-Content -Path $LogFile -Tail $LogLines
        Set-Content -Path $LogFile -Value $kept
    } catch {}
}

function Get-InstalledVersion([string]$Folder) {
    $file = Join-Path $Folder $VersionFile
    if (-not (Test-Path $file)) { return $null }
    try { return [version](Get-Content -Path $file -TotalCount 1).Trim() } catch { return $null }
}

function Get-Running {
    return @(Get-Process -Name "Wrought" -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase) })
}

function Get-Release {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $release = Invoke-RestMethod -Uri $ReleaseApi -Headers $Agent -TimeoutSec 60
    $assets = @{}
    foreach ($asset in $release.assets) {
        if (-not $asset.browser_download_url.StartsWith($DownloadPrefix)) { throw "The release lists a download outside $Repo." }
        $assets[$asset.name] = $asset.browser_download_url
    }
    $zip = $assets.Keys | Where-Object { $_ -match $ZipPattern } | Select-Object -First 1
    if (-not $zip) { throw "The latest release has no Windows build." }
    if (-not $assets.ContainsKey("SHA256SUMS")) { throw "The latest release has no SHA256SUMS file, so nothing was installed." }
    $sumsFile = Join-Path $Download "SHA256SUMS"
    Invoke-WebRequest -UseBasicParsing -Uri $assets["SHA256SUMS"] -Headers $Agent -OutFile $sumsFile -TimeoutSec 60
    $sums = @{}
    foreach ($line in Get-Content -Path $sumsFile) {
        if ($line -match '^([0-9a-fA-F]{64})\s+\*?(\S+)$') { $sums[$Matches[2]] = $Matches[1].ToLower() }
    }
    return @{ Version = [version]([regex]::Match($zip, $ZipPattern).Groups[1].Value); Zip = $zip; Assets = $assets; Sums = $sums }
}

function Get-Verified($Release, [string]$Name, [string]$Target) {
    if (-not $Release.Sums.ContainsKey($Name)) { throw "SHA256SUMS does not list $Name." }
    $part = "$Target.part"
    Invoke-WebRequest -UseBasicParsing -Uri $Release.Assets[$Name] -Headers $Agent -OutFile $part -TimeoutSec 1800
    $hash = (Get-FileHash -Algorithm SHA256 -Path $part).Hash.ToLower()
    if ($hash -ne $Release.Sums[$Name]) {
        Remove-Item -Force $part
        throw "$Name did not match its SHA-256 checksum, so it was thrown away."
    }
    Move-Item -Force -Path $part -Destination $Target
}

function Update-Scripts($Release) {
    New-Item -ItemType Directory -Force -Path $Updater | Out-Null
    foreach ($name in $Scripts) {
        if (-not $Release.Assets.ContainsKey($name)) { continue }
        $target = Join-Path $Updater $name
        if ((Test-Path $target) -and ((Get-FileHash -Algorithm SHA256 -Path $target).Hash.ToLower() -eq $Release.Sums[$name])) { continue }
        Get-Verified $Release $name $target
        Say "Updated $name."
    }
}

function Stage-Release($Release) {
    if ((Get-InstalledVersion $Staged) -eq $Release.Version) { return }
    $zipFile = Join-Path $Download $Release.Zip
    Get-Verified $Release $Release.Zip $zipFile
    $unpack = "$Staged.new"
    if (Test-Path $unpack) { Remove-Item -Recurse -Force $unpack }
    Expand-Archive -Path $zipFile -DestinationPath $unpack -Force
    $folder = $unpack
    if (-not (Test-Path (Join-Path $folder $Exe))) {
        $inner = Get-ChildItem -Path $unpack -Directory | Where-Object { Test-Path (Join-Path $_.FullName $Exe) } | Select-Object -First 1
        if (-not $inner) { throw "The download has no $Exe in it." }
        $folder = $inner.FullName
    }
    Get-ChildItem -Path $folder -Recurse -File | Unblock-File
    Set-Content -Path (Join-Path $folder $VersionFile) -Value $Release.Version.ToString()
    if (Test-Path $Staged) { Remove-Item -Recurse -Force $Staged }
    Move-Item -Path $folder -Destination $Staged
    if (Test-Path $unpack) { Remove-Item -Recurse -Force $unpack }
    Remove-Item -Force $zipFile
    Say "Wrought $($Release.Version) is downloaded and checked."
}

function Swap-In {
    if (Test-Path $Previous) { Remove-Item -Recurse -Force $Previous }
    if (Test-Path $App) { Move-Item -Path $App -Destination $Previous }
    try {
        Move-Item -Path $Staged -Destination $App
    } catch {
        if (Test-Path $Previous) { Move-Item -Path $Previous -Destination $App }
        throw
    }
    if (-not (Test-Path (Join-Path $App $Exe))) {
        Remove-Item -Recurse -Force $App
        if (Test-Path $Previous) { Move-Item -Path $Previous -Destination $App }
        throw "The new version was incomplete, so the old one was put back."
    }
}

function Register-Wrought([version]$Version, [bool]$FirstInstall) {
    $shell = New-Object -ComObject WScript.Shell
    $links = @($StartMenuLink)
    if ($FirstInstall) { $links += $DesktopLink }
    foreach ($path in $links) {
        $link = $shell.CreateShortcut($path)
        $link.TargetPath = Join-Path $App $Exe
        $link.WorkingDirectory = $App
        $link.IconLocation = (Join-Path $App $Exe) + ",0"
        $link.Description = "Wrought"
        $link.Save()
    }
    $uninstall = Join-Path $Updater "uninstall.ps1"
    $size = [int]((Get-ChildItem -Path $App -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1KB)
    New-Item -Force -Path $UninstallKey | Out-Null
    $values = @{
        DisplayName = "Wrought"; DisplayVersion = $Version.ToString(); Publisher = "OrangeGamer1912"; InstallLocation = $Root
        DisplayIcon = (Join-Path $App $Exe); URLInfoAbout = "https://github.com/$Repo"
        UninstallString = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$uninstall`""
    }
    foreach ($name in $values.Keys) { New-ItemProperty -Force -Path $UninstallKey -Name $name -Value $values[$name] -PropertyType String | Out-Null }
    foreach ($name in @("NoModify", "NoRepair")) { New-ItemProperty -Force -Path $UninstallKey -Name $name -Value 1 -PropertyType DWord | Out-Null }
    New-ItemProperty -Force -Path $UninstallKey -Name "EstimatedSize" -Value $size -PropertyType DWord | Out-Null
}

function Repoint-Legacy {
    $old = Join-Path $Root $Exe
    $new = Join-Path $App $Exe
    try {
        $run = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        if (Test-Path $run) {
            foreach ($prop in (Get-ItemProperty -Path $run).PSObject.Properties) {
                if ($prop.Value -is [string] -and $prop.Value.IndexOf($old, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $fixed = [regex]::Replace($prop.Value, [regex]::Escape($old), { param($m) $new }, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
                    Set-ItemProperty -Path $run -Name $prop.Name -Value $fixed
                    Say "Moved the startup entry $($prop.Name) to the new Wrought."
                }
            }
        }
        $shell = New-Object -ComObject WScript.Shell
        $folders = @([Environment]::GetFolderPath("Desktop"), [Environment]::GetFolderPath("Programs"), [Environment]::GetFolderPath("Startup"), (Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"))
        foreach ($folder in $folders) {
            if (-not (Test-Path $folder)) { continue }
            foreach ($file in Get-ChildItem -Path $folder -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue) {
                $link = $shell.CreateShortcut($file.FullName)
                if ($link.TargetPath -ieq $old) {
                    $link.TargetPath = $new
                    $link.WorkingDirectory = $App
                    $link.IconLocation = "$new,0"
                    $link.Save()
                    Say "Moved the shortcut $($file.Name) to the new Wrought."
                }
            }
        }
    } catch { Say "Could not move the old startup entries: $($_.Exception.Message)" }
}

function Register-Task {
    $script = Join-Path $Updater "install.ps1"
    $arguments = "--headless powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$script`" -Scheduled"
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $daily = New-ScheduledTaskTrigger -Daily -At $DailyAt
    $logon = New-ScheduledTaskTrigger -AtLogOn -User $user
    $actions = @(
        (New-ScheduledTaskAction -Execute "conhost.exe" -Argument $arguments),
        (New-ScheduledTaskAction -Execute "conhost.exe" -Argument "$arguments -AtLogon")
    )
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $TaskName -Trigger @($daily) -Action $actions[0] -Settings $settings -Principal $principal -Description "Keeps Wrought up to date from github.com/$Repo." | Out-Null
    Unregister-ScheduledTask -TaskName "$TaskName (logon)" -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName "$TaskName (logon)" -Trigger @($logon) -Action $actions[1] -Settings $settings -Principal $principal -Description "Finishes a waiting Wrought update when you sign in." | Out-Null
}

function Invoke-Rollback {
    if (-not (Test-Path (Join-Path $Previous $Exe))) { throw "There is no previous version to go back to." }
    if ((Get-Running).Count -gt 0) { throw "Close Wrought (right-click the tray icon, Quit) and run this again." }
    $back = "$App.rollback"
    if (Test-Path $back) { Remove-Item -Recurse -Force $back }
    Move-Item -Path $App -Destination $back
    Move-Item -Path $Previous -Destination $App
    Move-Item -Path $back -Destination $Previous
    Register-Wrought (Get-InstalledVersion $App) $false
    Say "Went back to Wrought $(Get-InstalledVersion $App)."
}

function Main {
    New-Item -ItemType Directory -Force -Path $Root, $Download | Out-Null
    if ($Rollback) { Invoke-Rollback; return }
    $installed = Get-InstalledVersion $App
    $firstInstall = -not $installed
    $legacy = $firstInstall -and (Test-Path (Join-Path $Root $Exe))
    if ($legacy) { Say "An older Wrought install was found in $Root. This installs the new version beside it. Once it works, remove the old one from Settings, Apps." }
    if ($firstInstall -and -not $legacy -and -not $Scheduled -and -not $PairCode) { $PairCode = "$(Read-Host "Pairing code from the Wrought website (press Enter to skip)")".Trim() }
    if ($PairCode -and $PairCode -notmatch $PairCodePattern) { Say "That pairing code does not look right, so pairing is skipped. You can pair inside the app."; $PairCode = "" }
    $release = Get-Release
    if ($PSCommandPath -and (Split-Path -Leaf $PSCommandPath) -eq "wrought-install.ps1" -and $release.Sums.ContainsKey("install.ps1")) {
        if ((Get-FileHash -Algorithm SHA256 -Path $PSCommandPath).Hash.ToLower() -ne $release.Sums["install.ps1"]) { throw "This installer does not match the one in the latest release. Download install.cmd again." }
    }
    Update-Scripts $release
    $stagedVersion = Get-InstalledVersion $Staged
    if ($installed -and $installed -ge $release.Version -and -not $Repair) {
        if (Test-Path $Staged) { Remove-Item -Recurse -Force $Staged }
        Say "Wrought $installed is up to date."
        if (-not $Scheduled) { Register-Task }
        return
    }
    if (-not $stagedVersion -or $stagedVersion -lt $release.Version) { Stage-Release $release }
    if ($StageOnly) { return }
    $running = Get-Running
    if ($running.Count -gt 0) {
        $young = $AtLogon -and -not ($running | Where-Object { $_.StartTime -lt (Get-Date).AddMinutes(-$JustStartedMinutes) })
        $agreed = (-not $Scheduled) -and ((Read-Host "Wrought is open. Close it now and update? (y/n)") -match '^[yY]')
        if (-not $young -and -not $agreed -and -not $Apply) {
            Say "Wrought $($release.Version) is ready and will be installed once Wrought is closed (or at the next sign-in)."
            return
        }
        $running | Stop-Process -Force
        Start-Sleep -Seconds 2
    }
    Swap-In
    Register-Wrought $release.Version $firstInstall
    Repoint-Legacy
    Register-Task
    Say "Wrought $($release.Version) is installed."
    if (-not $Scheduled) {
        $launch = @{ FilePath = (Join-Path $App $Exe); WorkingDirectory = $App }
        if ($firstInstall -and -not $legacy) {
            $flags = @("--auto-setup")
            if ($PairCode) { $flags += "--pair-code=$PairCode" }
            $launch.ArgumentList = $flags
        }
        Start-Process @launch
    }
    elseif ($running.Count -gt 0 -or $Apply) { Start-Process -FilePath (Join-Path $App $Exe) -ArgumentList "--hidden" -WorkingDirectory $App }
}

$lock = New-Object System.Threading.Mutex($false, "Local\WroughtUpdater")
if (-not $lock.WaitOne(0)) {
    Say "The Wrought updater is already running."
    exit 0
}
try {
    Main
    $code = 0
} catch {
    Say "Stopped: $($_.Exception.Message)"
    $code = 1
} finally {
    $lock.ReleaseMutex()
}
exit $code
