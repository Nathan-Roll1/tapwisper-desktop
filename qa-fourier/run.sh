set -euo pipefail
export LD_LIBRARY_PATH="$PWD/resources/bin/llama:${LD_LIBRARY_PATH:-}"
export PULSE_SOURCE=tapfixture.monitor
pulseaudio --start --exit-idle-time=-1
pactl load-module module-null-sink sink_name=tapfixture rate=48000 channels=1
pactl set-default-source tapfixture.monitor
mkdir -p /tmp/tap-qa-profile
openbox >/tmp/tap-wm.log 2>&1 &
launch() {
  node_modules/.bin/electron --no-sandbox --disable-gpu --remote-debugging-port=9222 --use-fake-ui-for-media-stream --autoplay-policy=no-user-gesture-required --user-data-dir=/tmp/tap-qa-profile . > /tmp/tap-app.log 2>&1 &
  app=$!
  for i in {1..90}; do curl -fsS http://127.0.0.1:9222/json/version >/dev/null 2>&1 && break; sleep 1; done
}
trap 'tail -n 65 /tmp/tap-app.log /tmp/tap-events.log || true' EXIT
launch
node qa-fourier/setup.cjs
kill "$app" || true
pkill -f 'electron/dist/electron --no-sandbox' || true
sleep 3
launch
/usr/bin/python3 qa-fourier/target.py >/tmp/tap-target.log 2>&1 &
win=$(timeout 25 xdotool search --sync --name '^Fourier GTK target$' | head -1)
node qa-fourier/events.cjs > /tmp/tap-events.log 2>&1 &
sleep 6
xdotool windowactivate --sync "$win"
xdotool windowfocus --sync "$win"
xdotool keydown Control_L keydown space
sleep 2
paplay --device=tapfixture /tmp/tap-fixture.wav
sleep 1
xdotool keyup space keyup Control_L
for i in {1..80}; do [ -s /tmp/tap-inserted.txt ] && break; sleep 1; done
python3 - <<'PY'
import re
from pathlib import Path
path=Path('/tmp/tap-inserted.txt')
if not path.exists(): raise SystemExit('No text arrived in the focused GTK editor')
text=path.read_text(); print('Inserted text:',text)
norm=lambda s:re.findall('[a-z]+',s.lower())
assert norm(text)==norm('And so my fellow Americans ask not what your country can do for you ask what you can do for your country')
PY
