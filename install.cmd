@echo off
rem Installs or updates Wrought for this Windows user. Double-click to run.
setlocal
set "SCRIPT=%~dp0install.ps1"
if exist "%SCRIPT%" goto run
set "SCRIPT=%TEMP%\wrought-install.ps1"
echo Downloading the Wrought installer...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/OrangeGamer1912/SRV2-App/releases/latest/download/install.ps1' -OutFile (Join-Path $env:TEMP 'wrought-install.ps1')"
if errorlevel 1 (
  echo Could not download the installer. Check the internet connection and try again.
  pause
  exit /b 1
)
:run
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
pause
