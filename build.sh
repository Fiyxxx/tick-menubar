#!/bin/zsh
# usage: ./build.sh            build build/Tick.app (apple silicon + intel)
#        ./build.sh install    build, copy to /Applications and relaunch
#        ./build.sh zip        build and pack build/Tick.zip for a release
#        ./build.sh test       run the self-test against a debug build
set -e
cd "$(dirname "$0")"

flags=(-swift-version 5 -framework AppKit -framework Carbon -framework ServiceManagement)

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
for arch in arm64 x86_64; do
    swiftc -O $flags -target $arch-apple-macos14.0 Sources/*.swift -o build/Tick-$arch
done
lipo -create build/Tick-arm64 build/Tick-x86_64 -output $app/Contents/MacOS/Tick
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

if [[ "$1" == "zip" ]]; then
    rm -f build/Tick.zip
    ditto -c -k --keepParent $app build/Tick.zip
    echo "packed build/Tick.zip"
fi

if [[ "$1" == "install" ]]; then
    pkill -x Tick || true
    rm -rf /Applications/Tick.app
    cp -R $app /Applications/
    open /Applications/Tick.app
    echo "installed /Applications/Tick.app"
fi
