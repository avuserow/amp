#!/bin/sh
set -e
if [ ! -d closure-library-read-only ]; then
    echo "You need the Google Closure library!";
    exit 1;
fi
if [ ! -d closure-compiler ]; then
    echo "You need the Google Closure Compiler!";
    exit 1;
fi
python closure-library-read-only/closure/bin/calcdeps.py -i www-data/source.js -p closure-library-read-only -o compiled -c closure-compiler/compiler.jar > www-data/acoustics.js
