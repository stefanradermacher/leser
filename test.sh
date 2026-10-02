#!/bin/zsh
# Runs the tests of Leser: the unit tests in Tests/LeserTests, inside the debug build of the
# app, which has its own settings, so that the tests do not touch those of the installed app.
# Usage: ./test.sh [Suite or Suite/test …]   e.g. ./test.sh PageReferenceTests
set -euo pipefail
cd "${0:A:h}"

only=()
for name in "$@"; do only+=(-only-testing:"LeserTests/$name"); done

signing=(-allowProvisioningUpdates)
grep -q '^DEVELOPMENT_TEAM *= *[A-Z0-9]' Config/Local.xcconfig 2>/dev/null \
    || signing=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=)

mkdir -p .build
log=.build/test.log
if xcodebuild -project Leser.xcodeproj -scheme Leser -configuration Debug \
    -derivedDataPath .build/xcode-test "${signing[@]}" "${only[@]}" test > "$log" 2>&1; then
    grep -E "^􁁛|Test run with" "$log" | tail -1
    echo "Alle Tests bestanden."
else
    grep -E "error:|􀢄|failed|Expectation failed|recorded an issue" "$log" | grep -v "^\s*$" | head -60 >&2 || tail -30 "$log" >&2
    echo "Tests fehlgeschlagen, vollständiges Protokoll: $PWD/$log" >&2
    exit 1
fi
