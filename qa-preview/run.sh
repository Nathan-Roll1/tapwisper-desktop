set -euo pipefail
test -x "$TAP_PACKAGED_APP"
# FUSE-free extraction preserves the package and sandbox. These standard variables normally come from the AppImage runtime.
export APPDIR="$(dirname "$TAP_PACKAGED_APP")"
export APPIMAGE=/tmp/tap-preview-out/TapWisper-Fourier-preview-linux-x86_64.AppImage
export PULSE_SOURCE=tapfixture.monitor
pulseaudio --start --exit-idle-time=-1
pactl load-module module-null-sink sink_name=tapfixture rate=48000 channels=1
pactl set-default-source tapfixture.monitor
mkdir -p /tmp/tap-qa-profile
ffmpeg -hide_banner -loglevel error -y -i /tmp/tap-fixture.wav -af "adelay=700,apad=pad_dur=9" -ar 44100 -ac 2 /tmp/tap-chromium-mic.wav
openbox >/tmp/tap-wm.log 2>&1 &
launch() {
  "$TAP_PACKAGED_APP" --disable-gpu --remote-debugging-port=9222 --use-fake-device-for-media-stream --use-file-for-fake-audio-capture=/tmp/tap-chromium-mic.wav --use-fake-ui-for-media-stream --autoplay-policy=no-user-gesture-required --user-data-dir=/tmp/tap-qa-profile > /tmp/tap-app.log 2>&1 &
  app=$!
  for i in {1..90}; do curl -fsS http://127.0.0.1:9222/json/version >/dev/null 2>&1 && return; kill -0 "$app" 2>/dev/null || { cat /tmp/tap-app.log; return 1; }; sleep 1; done
  return 1
}
trap 'tail -n 65 /tmp/tap-app.log /tmp/tap-events.log || true; find /tmp/tap-qa-profile/recordings -maxdepth 1 -printf "%f %s bytes\n" 2>/dev/null || true' EXIT
launch
node qa-preview/setup.cjs
kill "$app" || true
wait "$app" || true
sleep 2
launch
/usr/bin/python3 qa-preview/target.py >/tmp/tap-target.log 2>&1 &
win=$(timeout 25 xdotool search --sync --name '^Fourier GTK target$' | head -1)
node qa-preview/events.cjs > /tmp/tap-events.log 2>&1 &
sleep 6
xdotool windowactivate --sync "$win"
xdotool windowfocus --sync "$win"
xdotool type --clearmodifiers ready
sleep 0.3
grep -qx ready /tmp/tap-inserted.txt
xdotool key --clearmodifiers ctrl+a BackSpace
sleep 0.2
[ ! -s /tmp/tap-inserted.txt ]
xdotool keydown Control_L keydown space
sleep 2
paplay --device=tapfixture /tmp/tap-fixture.wav
sleep 1
xdotool keyup space keyup Control_L
sleep 1
xdotool windowactivate --sync "$win"
xdotool windowfocus --sync "$win"
for i in {1..360}; do
   [ -s /tmp/tap-inserted.txt ] && break
   focus=$(xdotool getwindowfocus 2>/dev/null || true)
   if [ "$focus" != "$win" ]; then xdotool windowfocus "$win" || true; fi
   sleep 0.25
done
python3 - <<'PY'
import re
from pathlib import Path
path=Path('/tmp/tap-inserted.txt')
if not path.exists(): raise SystemExit('No text arrived in the focused GTK editor')
text=path.read_text(); print('Inserted text:',text)
norm=lambda s:re.findall('[a-z]+',s.lower())
assert norm(text)==norm('And so my fellow Americans ask not what your country can do for you ask what you can do for your country')
PY
