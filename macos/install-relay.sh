#!/bin/bash
# Install vrct-relay on macOS as a background LaunchAgent (starts at login, restarts if it stops).
#
# VRCT and VRChat don't run on macOS, so a Mac is the relay for VRCT on other PCs on the
# same network: they set VRCT's "OpenAI Compatible" engine to this Mac (see the info
# printed at the end). The Obsidian notes (the relay's brain) are copied to
# ~/Documents/VRCT Brain once; edit them there.
#
#   ./install-relay.sh             install (or update) and start it
#   ./install-relay.sh uninstall   stop it and remove the LaunchAgent (keeps notes and keys)
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
label=io.github.koikon.vrct-relay
support="$HOME/Library/Application Support/vrct-relay"
brain="$HOME/Documents/VRCT Brain"
plist="$HOME/Library/LaunchAgents/$label.plist"
log="$HOME/Library/Logs/vrct-relay.log"
domain="gui/$(id -u)"

launchctl bootout "$domain/$label" 2>/dev/null || true
if [ "${1:-}" = uninstall ]; then
    rm -f "$plist"
    echo "vrct-relay stopped and removed. Your notes ($brain) and keys ($support/keys.json) were kept."
    exit 0
fi

python=$(command -v python3) || { echo "Python 3 isn't installed. Run: xcode-select --install (or get it from python.org)"; exit 1; }
"$python" -c 'import sys; sys.exit(sys.version_info < (3, 8))' || { echo "vrct-relay needs Python 3.8 or newer"; exit 1; }

mkdir -p "$support" "$(dirname "$plist")" "$(dirname "$log")" "$(dirname "$brain")"
cp "$repo/bin/vrct-relay" "$support/vrct-relay.py"
if [ ! -d "$brain" ]; then
    cp -R "$repo/obsidian/VRCT Chinese-English" "$brain"
    echo "Notes copied to $brain (open that folder as an Obsidian vault to edit them)."
fi

if [ ! -f "$support/keys.json" ]; then
    read -rsp "Gemini API key (blank to skip): " gemini; echo
    read -rsp "DeepL API key (blank to skip): " deepl; echo
    [ -n "$gemini$deepl" ] || { echo "The relay needs at least one key."; exit 1; }
    (umask 077; GEMINI="$gemini" DEEPL="$deepl" "$python" -c \
        'import json, os; print(json.dumps({"Gemini_API": os.environ["GEMINI"], "DeepL_API": os.environ["DEEPL"]}))' \
        >"$support/keys.json")
fi

xml() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' <<<"$1"; }
cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(xml "$python")</string>
        <string>$(xml "$support/vrct-relay.py")</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict><key>VRCT_BRAIN_DIR</key><string>$(xml "$brain")</string></dict>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>ProcessType</key><string>Background</string>
    <key>StandardOutPath</key><string>$(xml "$log")</string>
    <key>StandardErrorPath</key><string>$(xml "$log")</string>
</dict>
</plist>
EOF
launchctl bootstrap "$domain" "$plist"

for _ in $(seq 1 20); do
    nc -z 127.0.0.1 8765 2>/dev/null && break
    sleep 0.5
done
nc -z 127.0.0.1 8765 2>/dev/null || { echo "The relay didn't start; see $log"; exit 1; }

echo
echo "vrct-relay is running and starts at login. Log: $log"
echo "If macOS asks whether Python may accept incoming connections, allow it (needed for other PCs)."
echo
VRCT_BRAIN_DIR="$brain" "$python" "$support/vrct-relay.py" info
