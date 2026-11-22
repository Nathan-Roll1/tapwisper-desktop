set -euo pipefail
sudo apt-get update -qq
sudo apt-get install -y -qq xvfb xdotool ffmpeg openbox pulseaudio pulseaudio-utils libxtst-dev libx11-xcb-dev libxkbcommon-x11-dev python3-gi gir1.2-gtk-3.0 patchelf ninja-build > /tmp/tap-apt.log
npm ci --no-fund --no-audit >/tmp/tap-npm.log 2>&1 || { tail -40 /tmp/tap-npm.log; exit 1; }
mkdir -p /tmp/tap-legal/{llama,whisper} resources/bin/{llama,whisper}
# Pinned, auditable CPU release and corresponding upstream legal documents.
curl -fsSL --retry 3 https://github.com/ggml-org/llama.cpp/releases/download/b11928/llama-b11928-bin-ubuntu-x64.tar.gz -o /tmp/llama.tar.gz
echo 'c4fdc4b9913c3fc7b0ede9ed1970a43271aff7366889444797e05472f7c365da  /tmp/llama.tar.gz' | sha256sum -c
mkdir /tmp/tap-llama
tar xf /tmp/llama.tar.gz -C /tmp/tap-llama
llama_bin=$(dirname "$(find /tmp/tap-llama -name llama-server -type f -print -quit)")
cp -L "$llama_bin/llama-server" "$llama_bin"/lib*.so* resources/bin/llama/
# The helper is launched from the packaged service directory, without a global LD_LIBRARY_PATH.
for f in resources/bin/llama/*; do patchelf --set-rpath '$ORIGIN' "$f"; done
resources/bin/llama/llama-server --version
curl -fsSL --retry 3 https://codeload.github.com/ggml-org/llama.cpp/tar.gz/7eed6b7685d2abc32182c0df330812e3848b862f | tar -xz --strip-components=1 -C /tmp/tap-legal/llama
curl -fsSL --retry 3 https://codeload.github.com/ggml-org/whisper.cpp/tar.gz/d2a764c648779feb36d44363f212a29b00aad1af | tar -xz --strip-components=1 -C /tmp/tap-legal/whisper
# Preserve the other local speech engines in this preview, with a generic x86-64 CPU build.
cmake -S /tmp/tap-legal/whisper -B /tmp/tap-whisper-build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=ON -DWHISPER_BUILD_SERVER=ON >/tmp/whisper-build.log
cmake --build /tmp/tap-whisper-build --parallel 4 --target whisper-server parakeet-cli >>/tmp/whisper-build.log 2>&1 || { tail -40 /tmp/whisper-build.log; exit 1; }
install /tmp/tap-whisper-build/bin/{whisper-server,parakeet-cli} resources/bin/whisper/
python3 qa-preview/notices.py
npm run build
npx --no-install electron-builder --linux AppImage --x64 --publish never
appimage=$(find dist -maxdepth 1 -iname '*.AppImage' -print -quit)
mkdir -p /tmp/tap-preview-out
cp "$appimage" /tmp/tap-preview-out/TapWisper-Fourier-preview-linux-x86_64.AppImage
cp resources/THIRD-PARTY-NOTICES.txt /tmp/tap-preview-out/
(cd /tmp/tap-preview-out && sha256sum TapWisper-Fourier-preview-linux-x86_64.AppImage > SHA256SUMS)
(cd /tmp && /tmp/tap-preview-out/TapWisper-Fourier-preview-linux-x86_64.AppImage --appimage-extract >/dev/null)
test -x /tmp/squashfs-root/resources/app.asar.unpacked/resources/bin/llama/llama-server
node_modules/.bin/asar list /tmp/squashfs-root/resources/app.asar > /tmp/tap-package-contents.txt
if grep -Ei '/qa-preview/|\.(gguf|onnx|safetensors|pt|pth|tflite)$' /tmp/tap-package-contents.txt; then echo 'Unexpected model or QA files'; exit 1; fi
grep -q 'resources/THIRD-PARTY-NOTICES.txt' /tmp/tap-package-contents.txt
find /tmp/squashfs-root -name 'LICENSE*' | head -8
test -s /tmp/squashfs-root/LICENSES.chromium.html
test -s /tmp/squashfs-root/LICENSE.electron.txt
test -s /tmp/squashfs-root/resources/app.asar.unpacked/resources/THIRD-PARTY-NOTICES.txt
if find /tmp/squashfs-root -type f \( -iname '*.gguf' -o -iname '*.safetensors' -o -iname '*.onnx' -o -iname '*.pth' \) | grep .; then exit 1; fi
# Use the AppImage payload, with Chromium's real sandbox helper available on the headless VM.
sudo chown root:root /tmp/squashfs-root/chrome-sandbox
sudo chmod 4755 /tmp/squashfs-root/chrome-sandbox
