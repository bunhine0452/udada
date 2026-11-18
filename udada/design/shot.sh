#!/bin/sh
# usage: ./shot.sh a-rec [suffix]  -> shots/a-rec[suffix].png
mkdir -p shots
out="shots/$1${2:-}.png"; rm -f "$out"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=${W:-1280},${H:-1000} --virtual-time-budget=6000 --screenshot="$out" "file://$PWD/$1.html" >/dev/null 2>&1
for i in 1 2 3 4 5 6 7 8 9 10; do [ -s "$out" ] && break; sleep 0.5; done
ls -l "$out"
