# Tick

A tiny to-do list that lives in your Mac's menu bar. Native Swift, no web view: under 1 MB on disk and about 20 MB of memory.

<img src="docs/screenshot.png" width="320" alt="Tick panel with a few tasks, two of them ticked off">

Click the menu-bar icon or press **⌥Space** and a small dark panel drops down, ready to type. It stays open while you work in other apps. Click the icon again, press ⌥Space or hit esc to close it.

## Install

1. Download `Tick.zip` from the [latest release](https://github.com/Fiyxxx/tick-menubar/releases/latest), unzip it and drag **Tick** into Applications.
2. Open it. macOS will say it can't verify the developer, because Tick isn't signed with a paid Apple developer account. Click **Done**, then go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**. You only need to do this once.

   Or, from Terminal: `xattr -dr com.apple.quarantine /Applications/Tick.app`

Requires macOS 14 or later, on Apple Silicon or Intel.

## Use

| key | action |
| --- | --- |
| ⌥Space | open or close from anywhere |
| ↩ | new task below |
| ⌫ on an empty line | remove it |
| ⌘↩ | mark done / undo |
| ⌘⌫ | delete task |
| ↑ ↓, tab | move between tasks |
| ⌘, | settings |
| esc | close |

Click a circle to tick a task off; it stays struck through until you press **Clear done**.

Drag the panel by its bottom bar or any empty space to put it anywhere; it remembers the spot. Right-click the menu-bar icon and pick **Move Back Under Icon** to reset it.

Settings (the gear, or right-click the icon) has switches for **Keep on top** and **Open at login**.

Your tasks are a plain JSON file at `~/Library/Application Support/Tick/todos.json`.

## Build from source

Needs Xcode or the Xcode command line tools.

```sh
git clone https://github.com/Fiyxxx/tick-menubar.git
cd tick-menubar
./build.sh install   # build and copy to /Applications
```

`./build.sh` builds `build/Tick.app`, `./build.sh test` runs the self-test, and `./build.sh zip` packs a release zip. Pushing a `v*` tag builds and publishes a release through GitHub Actions.

## License

MIT
