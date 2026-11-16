# Removes Wrought for the current user. Your settings and pairing in %APPDATA%\Wrought are kept unless you add -RemoveData.
param([switch]$RemoveData, [switch]$Quiet)

$ErrorActionPreference = "Stop"

$Root = Join-Path $env:LOCALAPPDATA "Programs\Wrought"
$Data = Join-Path $env:APPDATA "Wrought"
$TaskNames = @("Wrought updater", "Wrought updater (logon)")
$UninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Wrought"
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$Links = @((Join-Path ([Environment]::GetFolderPath("Programs")) "Wrought.lnk"), (Join-Path ([Environment]::GetFolderPath("Desktop")) "Wrought.lnk"))

function Say([string]$Text) { if (-not $Quiet) { Write-Host $Text } }

try {
    if (-not $Root.EndsWith("\Programs\Wrought") -or -not $Root.StartsWith($env:LOCALAPPDATA)) { throw "Unexpected install folder: $Root" }
    if (-not $Quiet) {
        $answer = Read-Host "Remove Wrought from this PC? Your settings are kept. (y/n)"
        if ($answer -notmatch '^[yY]') { Say "Nothing was changed."; exit 0 }
    }
    Get-Process -Name "Wrought" -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase) } | Stop-Process -Force
    Start-Sleep -Seconds 2
    foreach ($name in $TaskNames) { Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue }
    foreach ($link in $Links) {
        if (-not (Test-Path $link)) { continue }
        $target = (New-Object -ComObject WScript.Shell).CreateShortcut($link).TargetPath
        if ($target -and $target.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -Force $link }
    }
    if (Test-Path $RunKey) {
        $run = Get-ItemProperty -Path $RunKey
        foreach ($property in $run.PSObject.Properties) {
            if ($property.Name -like "PS*") { continue }
            if ([string]$property.Value -like "*$Root*") { Remove-ItemProperty -Path $RunKey -Name $property.Name }
        }
    }
    if (Test-Path $UninstallKey) { Remove-Item -Recurse -Force $UninstallKey }
    if (Test-Path $Root) { Remove-Item -Recurse -Force $Root }
    if ($RemoveData -and (Test-Path $Data)) { Remove-Item -Recurse -Force $Data }
    Say "Wrought is removed."
    if (-not $RemoveData) { Say "Your settings are still in $Data. Delete that folder too if you will not use Wrought again." }
} catch {
    Say "Stopped: $($_.Exception.Message)"
    exit 1
}
