#!/bin/bash
# Gebruik: ./build.sh            (alle PDF's)   of   ./build.sh src/week01.md
cd "$(dirname "$0")"
# Pad naar Chrome/Chromium; overschrijf met  CHROME=/pad/naar/chrome ./build.sh
# Extra opties voor Chrome (bijvoorbeeld in CI):  CHROME_FLAGS=--no-sandbox
if [ -z "$CHROME" ]; then
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" google-chrome google-chrome-stable chromium chromium-browser; do
    if command -v "$c" >/dev/null 2>&1; then CHROME="$c"; break; fi
  done
fi
[ -z "$CHROME" ] && { echo "Chrome of Chromium niet gevonden; zet CHROME=/pad/naar/chrome" >&2; exit 1; }
mkdir -p build pdf
files=("$@"); [ ${#files[@]} -eq 0 ] && files=(src/*.md)
for f in "${files[@]}"; do
  name=$(basename "$f" .md)
  pandoc "$f" -f markdown+pipe_tables+fenced_code_blocks -t html5 --standalone --embed-resources \
    --css style.css --highlight-style=pygments --metadata lang=nl -o "build/$name.html" 2>/dev/null \
    || pandoc "$f" -t html5 --standalone --self-contained --css style.css -o "build/$name.html"
  "$CHROME" ${CHROME_FLAGS:-} --headless=new --disable-gpu --no-pdf-header-footer \
    --print-to-pdf="pdf/$name.pdf" "file://$PWD/build/$name.html" >/dev/null 2>&1
  echo "ok  pdf/$name.pdf"
done
