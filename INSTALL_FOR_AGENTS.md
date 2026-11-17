# Installing Wrought (instructions for AI agents)

Read this fully before running anything. It covers Windows and Debian-based Linux. Wrought is a desktop app; the person you are helping owns the PC.

## Rules for you
1. Do only what the person asked. Installing is one task. Do not pair, change settings or open the app's permissions beyond what is described here.
2. Never ask for, print, log or store the person's join link or key. A pairing code (see below) is typed only into the installer's `-PairCode` option, and never written to a file or repeated in your reply.
3. Do not edit the installer to make it pass. If a check fails, stop and report the exact message.
4. Do not install other software, and do not use admin rights on Windows: the installer is per-user and needs none.
5. Never delete the person's files. Uninstalling keeps their settings unless they ask otherwise.
6. Say plainly what you did not verify (for example, that the app opened and paired).

## What you need
- Windows 10 or 11 (64-bit) with Windows PowerShell 5.1 or newer, and internet access to github.com. Or: Debian-based 64-bit Linux (Ubuntu, Kubuntu, Mint, Debian) with `apt`.
- Release page: https://github.com/OrangeGamer1912/SRV2-App/releases/latest
- Access: the Wrought website is restricted. Installing works for anyone, but pairing and use need the owner's permission. A Cloudflare block or a 502 means the person is not allowed in; that is not an install fault.

## Windows
Files on the release: `install.cmd`, `install.ps1`, `uninstall.ps1`, `SHA256SUMS`, `Wrought-<version>-win.zip`.

1. Download `install.ps1` and `SHA256SUMS` from the latest release into a new, empty folder.
2. Check the installer against the sums file. The line for `install.ps1` in `SHA256SUMS` must equal:
   ```powershell
   (Get-FileHash -Algorithm SHA256 .\install.ps1).Hash.ToLower()
   ```
   If it differs, stop. Do not run it.
3. Run it from a real console, per user, without admin:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
   ```
   With a pairing code the person gave you in this chat, so no prompt appears:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -PairCode <code>
   ```
   A code is 4 to 64 letters, digits, `_` or `-`. Anything else is ignored with a message, and the person can pair inside the app instead.
4. The installer downloads the app zip, verifies its SHA-256 against `SHA256SUMS`, installs to `%LOCALAPPDATA%\Programs\Wrought`, adds Start Menu and Desktop shortcuts, registers a daily update task (12:30) and a sign-in task, and adds an entry in Settings, Apps. On a first install it opens the app in setup mode.
5. Success looks like: `Wrought <version> is installed.` and exit code 0. Any failure prints `Stopped: <reason>` and exits 1. Nothing is half-installed after a failure; the previous version is kept.

Notes:
- If the installer prompts and gets no input, it skips pairing and carries on. If Wrought is already open during an update, it asks to close it. Close Wrought first so no prompt is needed. Do not use `-Scheduled` or `-AtLogon`; those are for the update tasks.
- Only one installer runs at a time. `The Wrought updater is already running.` means wait and retry.
- Log: `%LOCALAPPDATA%\Programs\Wrought\updater.log` (last 300 lines). It holds no codes or keys.

Other options:
| Goal | Command |
|---|---|
| Repair a broken install | `install.ps1 -Repair` |
| Go back to the previous version | `install.ps1 -Rollback` |
| Update | run `install.ps1` again (it also updates itself daily) |
| Uninstall, keep settings | `%LOCALAPPDATA%\Programs\Wrought\updater\uninstall.ps1` |
| Uninstall, no prompt | add `-Quiet` |
| Uninstall and delete settings and pairing | add `-RemoveData` (only if the person asks) |

Double-clicking `install.cmd` does the same as step 3 and downloads `install.ps1` itself if it is not beside it. Prefer the explicit steps above when you are the one running it, so you can verify the hash.

## Linux (Debian-based)
Files on the release: `setup.sh`, `srv2app_<version>_amd64.deb`, `SHA256SUMS`.

1. Download `setup.sh`, the `.deb` and `SHA256SUMS` into one new, empty folder.
2. Verify:
   ```bash
   sha256sum -c --ignore-missing SHA256SUMS
   ```
   Every line it checks must say `OK`.
3. Run `bash ./setup.sh`. It copies the `.deb` to a temp folder and runs `apt install` through `pkexec` (graphical password prompt) or `sudo`. The person must enter their password; do not ask for it in chat. If you have no way to show a prompt, hand this one command to the person to run.
4. Only x86_64 is supported.

## After installing
- Start Wrought from the Start Menu or the desktop shortcut. First run after a fresh install runs automatic setup and, if a valid pairing code was given, pairs.
- Wrought's PC features have their own toggles inside the app. Do not turn them on for the person unless they asked.
- Report: the version installed, whether the hash checks passed, whether the app was seen to open, and whether pairing was attempted.

## If something fails
| Message or symptom | Meaning and next step |
|---|---|
| `The latest release has no SHA256SUMS file` | The release is incomplete. Stop and tell the person. |
| `This installer does not match the one in the latest release` | Download `install.cmd` or `install.ps1` again and verify the hash. |
| Hash mismatch on download | Do not install. Retry once; if it repeats, report it. |
| `running scripts is disabled` | Use the `-ExecutionPolicy Bypass` form above; do not change system policy. |
| Cloudflare error or 502 in the app | The person is not allowed on the website. Not an install fault. |
