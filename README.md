# Tick

A tiny native menu-bar to-do list for macOS. No web view, about 380 KB on disk and around 20 MB of memory.

Click the menu-bar icon or press ⌥Space to open it. It stays open when you switch apps. Click the icon again, press ⌥Space or press esc to close it.

| key | action |
| --- | --- |
| ↩ | new task below |
| ⌫ on an empty line | remove it |
| ⌘↩ | mark done / undo |
| ⌘⌫ | delete task |
| ↑ ↓, tab | move between tasks |
| ⌘, | settings |

Drag the panel by its bottom bar or any empty space to move it; it remembers the spot. Right-click the icon and pick "Move Back Under Icon" to reset.

Settings (gear, or right-click the icon) has switches for keep on top and open at login.

Tasks live in `~/Library/Application Support/Tick/todos.json`.

```sh
./build.sh           # build build/Tick.app
./build.sh install   # build, copy to /Applications, relaunch
./build.sh test      # run the self-test
```
