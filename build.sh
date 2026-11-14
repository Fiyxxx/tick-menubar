#!/bin/zsh
# usage: ./build.sh            build build/Tick.app
#        ./build.sh install    build, copy to /Applications and relaunch
#        ./build.sh test       run the self-test against a debug build
set -e
cd "$(dirname "$0")"

flags=(-swift-version 5 -target arm64-apple-macos14.0 -framework AppKit -framework Carbon -framework ServiceManagement)

if [[ "$1" == "test" ]]; then
    out=build/test
    rm -rf $out && mkdir -p $out
    swiftc -Onone -D DEBUG $flags Sources/*.swift Tests/*.swift -o $out/tick-test
    $out/tick-test --selftest $out
    exit
fi

app=build/Tick.app
rm -rf $app
mkdir -p $app/Contents/MacOS $app/Contents/Resources
swiftc -O $flags Sources/*.swift -o $app/Contents/MacOS/Tick
cp Resources/Info.plist $app/Contents/

if [[ ! -f build/AppIcon.icns ]]; then
    set=build/AppIcon.iconset
    mkdir -p $set
    swiftc Resources/icon.swift -o build/make-icon
    build/make-icon build/icon-1024.png
    for s in 16 32 128 256 512; do
        sips -z $s $s build/icon-1024.png --out $set/icon_${s}x${s}.png >/dev/null
        sips -z $((s * 2)) $((s * 2)) build/icon-1024.png --out $set/icon_${s}x${s}@2x.png >/dev/null
    done
    iconutil -c icns $set -o build/AppIcon.icns
fi
cp build/AppIcon.icns $app/Contents/Resources/
codesign --force --sign - $app

if [[ "$1" == "install" ]]; then
    pkill -x Tick || true
    rm -rf /Applications/Tick.app
    cp -R $app /Applications/
    open /Applications/Tick.app
    echo "installed /Applications/Tick.app"
fi
