#!/bin/bash
# Installs the Wrought desktop app from the .deb that sits next to this script (or in dist/).
# Double-click it, or run: ./setup.sh
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say() {
  echo "$1"
  if [ -z "${TERM:-}" ] || [ ! -t 1 ]; then
    if command -v kdialog >/dev/null 2>&1; then kdialog --title "Wrought setup" --msgbox "$1"
    elif command -v zenity >/dev/null 2>&1; then zenity --info --title "Wrought setup" --text "$1"
    fi
  fi
}

if [ "$(uname -m)" != "x86_64" ]; then say "This installer is for 64-bit Intel/AMD Linux (x86_64). This machine is $(uname -m)."; exit 1; fi
if ! command -v apt >/dev/null 2>&1; then say "This installer needs a Debian-based system (Ubuntu, Kubuntu, Mint, Debian). Ask for another package type."; exit 1; fi

deb="$(ls -1 "$here"/srv2app_*_amd64.deb "$here"/dist/srv2app_*_amd64.deb 2>/dev/null | sort -V | tail -n 1)"
if [ -z "$deb" ]; then say "No srv2app_*_amd64.deb was found next to setup.sh. Put the .deb in the same folder and run this again."; exit 1; fi

echo "Installing $(basename "$deb") (a password prompt will appear)..."
# apt's own sandbox user cannot read files in a home folder, so copy to /tmp first.
copy="$(mktemp -d)/$(basename "$deb")"
cp "$deb" "$copy" && chmod 644 "$copy" && chmod 755 "$(dirname "$copy")"
if command -v pkexec >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then pkexec apt install -y "$copy"; else sudo apt install -y "$copy"; fi
status=$?
rm -rf "$(dirname "$copy")"
if [ $status -ne 0 ]; then say "The install did not finish. Nothing was changed if you cancelled the password prompt."; exit $status; fi

say "Wrought is installed. Find it in your application menu. Next: open it, join with your family link, then pair your PC from My PCs in Wrought."
nohup srv2app >/dev/null 2>&1 &
