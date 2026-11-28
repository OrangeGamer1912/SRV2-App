This is an application for my SRV2 website.

Currently, it is usable only to those who are allowed on the website.
Note: **The website is locked for most regions and gaining permanent access needs my permission. If you see a Cloudflare error (403 or 502), it means you were blocked automatically.**

This is a private project.
All rights reserved.

Author: https://github.com/OrangeGamer1912

## Install on Windows (recommended: the personal installer)

1. Sign in to the Wrought website, open My PCs and press **Add a PC**.
2. Download the file it gives you, `wrought-install.cmd`, and double-click it. Windows may warn that the file comes from the internet; choose More info, then Run anyway.
3. Leave the window open. It downloads Wrought (about 160 MB, about a minute), checks it, installs it for your Windows user only (no admin rights needed) and opens it. Wrought pairs itself with your account and asks which things it may do on this PC. When the window says it has finished, press a key and it deletes itself.

The file belongs to you and works once. It is valid for about an hour. Do not share it, forward it or post it anywhere. If you want to put Wrought on another PC, press Add a PC again.

Wrought then keeps itself up to date: it checks this repository for a newer release, checks every download against the release's SHA256SUMS file and installs it once Wrought is closed. The version before is kept, so it can be put back.

To remove Wrought, use Settings, Apps, Installed apps, Wrought, Uninstall. Your settings are kept in %APPDATA%\Wrought.

### Without the website file

You can also download `install.cmd` from the latest release and double-click it. That installs Wrought but does not pair it. Then either open the join link from your Wrought website once, or press Add a PC on My PCs and type the 5-minute code into Wrought (Ctrl+Shift+P, PC access).

## Install on Linux (Debian-based, 64-bit)

1. Sign in to the Wrought website, open My PCs and press **Add a PC**, and choose Linux.
2. Download `wrought-install.sh` and run `bash wrought-install.sh` in a terminal. It asks for your password once, to install the package. Do not run it with sudo yourself.
3. It installs Wrought, starts it and pairs it with your account, then deletes itself.

Without the website file: download the .deb from the latest release and run setup.sh next to it, or open the .deb with your software installer. That does not pair the PC.

## When it fails

Read the last message in the installer window first. It says what went wrong.

| What you see | What to do |
|---|---|
| "Could not download the Wrought installer" | Check the internet connection and that github.com opens. Press Add a PC again. |
| "did not match its checksum" | Something changed the download on its way. Nothing was installed. Try again once, on another network if you can. If it repeats, tell the owner. |
| Windows blocks the file or says it cannot run scripts | Choose More info, then Run anyway. Do not change Windows security settings. |
| Antivirus removes or quarantines the file | Allow it for this one run, or ask the owner. Wrought is not code-signed yet, so some antivirus programs flag it by mistake. |
| The window closes at once | Right-click the file, Open with, Command Prompt. Or open Command Prompt and run it from there so the message stays. |
| Wrought opens but shows "Setup did not finish" or is not paired | The file expired (one hour), was already used, or the website was restarted. Press Add a PC again and run the new file. Or pair by hand: open the join link from your website, then type the 5-minute code from Add a PC into Wrought (Ctrl+Shift+P). |
| Wrought says the PC limit is reached | Remove a PC you no longer use from My PCs, then run the installer again. |
| Cloudflare error (403 or 502) | You are not allowed on the website. Not an install fault. Ask the owner. |
| "The Wrought updater is already running" | Wait a minute and try again. |
| Something is broken after an update | Run `install.ps1 -Repair` (to fix) or `install.ps1 -Rollback` (to go back to the version before) from the release page's `install.ps1`. |
| It does not help | Open `%LOCALAPPDATA%\Programs\Wrought\updater.log` (the install) and `%APPDATA%\Wrought\logs\app.log` (the app) and send me the last lines. On Linux the app log is `~/.config/srv2app/logs/app.log`. Neither holds a token or a key. |

To start again from nothing on Windows, uninstall Wrought, delete `%APPDATA%\Wrought\device.bin` and press Add a PC for a new file.

## For AI agents

If an AI is helping you, point it at INSTALL_FOR_AGENTS.md in this repository. It must not ask for or repeat your install file, token, join link or pairing code.
