"""Collect upstream licenses and notices for the preview, including compiled JS and fonts."""
from pathlib import Path
import json
import re
import sys

out = Path('resources/THIRD-PARTY-NOTICES.txt')
seen = set()
parts = []
def add(section, path):
    raw = path.read_bytes()
    if not raw or b'\x00' in raw[:4000]:
        return
    text = raw.decode('utf-8', errors='replace')
    entry=(section,str(path))
    if entry in seen:
        return
    seen.add(entry)
    parts.append(f'\n{"=" * 72}\n{section} — {path.name}\n{"=" * 72}\n{text.strip()}\n')

def notice(path):
    return bool(re.match(r'^(licen[cs]es?|notice|copying|copyright|ofl)(?:[.-].*)?$', path.name, re.I))
add('TapWisper Desktop source at 6bb7055dae779984d3e96c3c42397d8e39726577', Path('LICENSE'))
add('Electron', Path('node_modules/electron/dist/LICENSE'))
for label,path in [('llama.cpp b11928', Path('/tmp/tap-legal/llama')), ('whisper.cpp v1.9.5',Path('/tmp/tap-legal/whisper'))]:
    assert (path/'LICENSE').exists(), path
    for f in sorted(path.rglob('*')):
        if f.is_file() and notice(f):
            add(label+' / '+str(f.parent.relative_to(path)), f)
for dep in sorted(Path('node_modules').rglob('package.json')):
    if dep.parent.parent.name!='node_modules' and not dep.parent.parent.name.startswith('@'):
        continue
    try:
        d=json.loads(dep.read_text())
    except (OSError, ValueError):
        continue
    name=d.get('name')
    if not name: continue
    section=f'{name} {d.get("version","")} ({d.get("license","see source")})'
    for f in sorted(dep.parent.iterdir()):
        if f.is_file() and notice(f):
            add(section,f)
# libuiohook ships within the npm prebuilds; its LGPL text is provided with its source.
for f in sorted(Path('node_modules/uiohook-napi/libuiohook').rglob('*')):
    if f.is_file() and notice(f):
        add('libuiohook upstream notices: '+str(f.parent),f)
assert len(parts)>100
intro = """TapWisper Desktop — unofficial Fourier contributor preview
Application source: https://github.com/zeyadelosherey/tapwisper-desktop
This fork and its preview recipes: https://github.com/Nathan-Roll1/tapwisper-desktop/tree/qa/fourier-linux-appimage
llama.cpp: https://github.com/ggml-org/llama.cpp/tree/b11928 (MIT)
whisper.cpp: https://github.com/ggml-org/whisper.cpp/tree/v1.9.5 (MIT)
The bundled uiohook-napi 1.5.4 and libuiohook sources are distributed at https://registry.npmjs.org/uiohook-napi/-/uiohook-napi-1.5.4.tgz and their LGPL terms are included below.
Chromium and Electron notices are also included as LICENSES.chromium.html and LICENSE.electron.txt.
The AppImage contains no model weights. The optional Fourier model is downloaded from Oruk under CC BY-NC 4.0.
"""
out.write_text(intro+''.join(parts))
print('Included',len(parts),'license and notice records.')
