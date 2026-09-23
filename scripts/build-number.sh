#!/bin/zsh
# Writes the build number into Config/BuildNumber.xcconfig, which Config/Leser.xcconfig
# includes. The number is the count of Git commits, so every new state counts up.
#
# build.sh runs this by itself. Run it by hand before archiving in Xcode, otherwise the
# archive carries the build number of the last run.
set -euo pipefail
cd "${0:A:h}/.."

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Kein Git-Repository, Build-Nummer bleibt unverändert." >&2
    exit 0
fi

build=$(git rev-list --count HEAD)
cat > Config/BuildNumber.xcconfig <<EOF
// Von scripts/build-number.sh erzeugt, nicht von Hand ändern.
CURRENT_PROJECT_VERSION = $build
EOF
echo "$build"
