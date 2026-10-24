#!/bin/sh
# download.sh — fetch the prebuilt bin/sigil for this OS and CPU from the GitHub release
# instead of building it (no compiler needed).   make download
set -eu
VERSION=v0.1.4	# the release this checkout matches (check.sh keeps it equal to the README's latest)
cd "$(dirname "$0")/.."
case "$(uname -s)" in
Linux) os=linux ;;
Darwin) os=macos ;;
*) echo "no prebuilt sigil for $(uname -s); build it: make" >&2; exit 1 ;;
esac
case "$(uname -m)" in
x86_64 | amd64) arch=x86_64 ;;
arm64 | aarch64) arch=arm64 ;;
*) echo "no prebuilt sigil for $(uname -m); build it: make" >&2; exit 1 ;;
esac
url="https://github.com/vim-nvim-plugins/sigil/releases/download/$VERSION/sigil-$os-$arch"
mkdir -p bin
curl -fL --progress-bar -o bin/sigil.part "$url" || { rm -f bin/sigil.part; echo "download failed: $url — build it instead: make" >&2; exit 1; }
chmod +x bin/sigil.part
mv bin/sigil.part bin/sigil
./bin/sigil --list > /dev/null
echo "downloaded bin/sigil ($VERSION, $os $arch)"
