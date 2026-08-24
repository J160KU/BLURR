# BLURR v0.1.0

Linux-style ("X11 primary selection") mouse-driven copy/paste behavior for Windows 11, implemented
as an [AutoHotkey](https://www.autohotkey.com/) v2 script that runs in the background at every login.

No native Windows setting provides this — it requires a third-party automation tool. This project
uses AutoHotkey (open source, GPL-2.0) because it's the standard lightweight tool for this kind of
global mouse/keyboard remapping on Windows. See `AGENTS.md` in this folder for exact steps to set
this up (or have an AI assistant set it up) on another machine.

## What it does

| Action                                                                                         | Result                                                                                                          |
| ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Left-click **drag** over text                                                                  | Auto-copies the selection to the clipboard (like X11 primary selection)                                         |
| **Double-click** a word                                                                        | Word gets selected (native OS behavior) *and* copied to the clipboard                                           |
| **Triple-click** a word                                                                        | Line/paragraph gets selected (native OS behavior, app-dependent) *and* copied to the clipboard                  |
| **Middle-click**                                                                               | Pastes the clipboard contents at the cursor                                                                     |
| **Middle-click**, but the active window is a browser (Chrome/Edge/Firefox/Brave/Opera/Vivaldi) | Native browser behavior instead (open link in new tab / close tab / autoscroll) — paste is suppressed only here |

There is only **one clipboard** involved — the normal Windows clipboard (`Ctrl+C`/`Ctrl+V`). There
is no separate "mousewheel-click clipboard"; middle-click just pastes whatever the last copy
action (mouse-driven or a manual `Ctrl+C`) put on the regular clipboard. This mirrors how normal
Ctrl+C/Ctrl+V works — the mouse actions are simply another way to trigger the same clipboard.

## How it works

The script (`SelectCopyMiddlePaste.ahk`) does **not** implement selection itself. It leaves all
actual text/word/line selection to the OS and the active application (that's why triple-click
paragraph-select is app-dependent — it only works in apps that support triple-click natively, e.g.
browsers, VS Code, Word). What the script adds on top:

1. A passthrough hotkey on the physical left mouse button (`~LButton`) that measures how far the
   mouse moved between button-down and button-up.
   - If it moved more than 4px, that was a drag-selection → send `Ctrl+C`.
   - If it didn't move, it was a click. The script then tracks click timing/position exactly like
     Windows' own double-click detection (`GetDoubleClickTime()` Win32 API, small pixel radius) to
     recognize 2nd and 3rd clicks in a row at the same spot. On the 2nd or 3rd click, it sends
     `Ctrl+C` (trusting that the app just word/line-selected on that click, natively).
2. A hotkey on the middle mouse button (`MButton`) that sends `Ctrl+V`, scoped off in known browser
   processes via `#HotIf !IsBrowser()` so browser tab behavior stays intact.

Because it only remaps `Ctrl+C`/`Ctrl+V` keystrokes triggered by mouse events, it works uniformly
across almost any Windows app without per-app integration.

## Requirements

- Windows 11 (also works on Windows 10).
- [AutoHotkey v2](https://www.autohotkey.com/) — free, open source (GPL-2.0), ~3MB, no admin
  rights needed for a per-user install.

## Setup

Already done on this machine. Summary (see `AGENTS.md` for the exact commands):

1. AutoHotkey v2 installed per-user via `winget install --id AutoHotkey.AutoHotkey` to
   `%LOCALAPPDATA%\Programs\AutoHotkey\`.
2. This project's `SelectCopyMiddlePaste.ahk` is the single canonical copy of the script (this
   folder — not copied elsewhere). It's launched via:
   `AutoHotkey64.exe "C:\Users\<username>\Desktop\Projects\fast_copy_paste\SelectCopyMiddlePaste.ahk"`
3. A shortcut to that exact command lives in the Windows Startup folder so it runs at every logon:
   `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\SelectCopyMiddlePaste.lnk`

## Usage / troubleshooting

- The script has a tray icon (green "H" AutoHotkey icon) while running — right-click it → **Exit**
  to stop it for the current session, or **Reload Script** after editing the `.ahk` file.
- If you edit `SelectCopyMiddlePaste.ahk`, either use the tray icon's "Reload Script", or:
  
  ```powershell
  Get-Process | Where-Object { $_.ProcessName -match "AutoHotkey" } | Stop-Process -Force
  Start-Process "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList '"C:\Users\<username>\Desktop\Projects\fast_copy_paste\SelectCopyMiddlePaste.ahk"'
  ```
- To temporarily debug what a click/drag is doing, add this line right after `Send "^c"` calls
  (there are three) or at hotkey entry, then check the file it writes to:
  
  ```ahk
  FileAppend A_Now " ... `n", A_Temp "\select-copy-paste-debug.log"
  ```
  
  Remove the line again once confirmed — this is how the double/triple-click timing logic was
  validated during development (see `AGENTS.md` "Validation approach").
- **Disable permanently**: delete the shortcut in the Startup folder above.
- **Known limitation**: triple-click paragraph-select only copies correctly in apps that natively
  support triple-click-to-select-line/paragraph. Plain single-line inputs generally don't have a
  triple-click meaning — nothing extra gets selected, so the copy just re-copies the double-click
  word/nothing new. This is an app-level limitation, not something this script can fix, since the
  script deliberately doesn't implement its own selection — it defers entirely to the OS/app.
- **Known limitation**: middle-click-paste is scoped off for a fixed list of browser executable
  names (`chrome.exe`, `msedge.exe`, `firefox.exe`, `brave.exe`, `opera.exe`, `vivaldi.exe`). Any
  other app that uses middle-click for something else (e.g. some IDE/terminal features) will still
  have that native behavior overridden by paste. Add more names to the `browsers` array in
  `IsBrowser()` in the script to exclude additional apps the same way.

## License

This project (`SelectCopyMiddlePaste.ahk` and its accompanying docs) is licensed under the
**GNU General Public License v2.0 (or later)** — see [`LICENSE`](LICENSE) for the full text. This
matches the license of the AutoHotkey interpreter it runs on, so the whole stack (script +
runtime) is consistently GPL-2.0. See `BEST_PRACTICE_GITHUB.md` for the reasoning behind this
choice and other repo-preparation decisions.
