# AGENTS.md

Entry point for an AI assistant (or a human) replicating this setup on **another** Windows 11/10
machine. See `README.md` in this folder for what the end result does and how to use/troubleshoot
it. This file is the step-by-step build recipe plus the gotchas hit while building it the first
time, so a repeat run goes faster and avoids the same dead ends.

## Goal

Replicate, on a new machine, the exact behavior documented in `README.md`:
- Left-click drag → copy selection to clipboard.
- Double-click a word → copy the word.
- Triple-click a word → copy the line/paragraph (app-dependent).
- Middle-click → paste, except in browsers (native tab behavior preserved there).

The canonical script to deploy is `SelectCopyMiddlePaste.ahk` in this same folder — copy that exact
file to the new machine (e.g. clone/copy this whole project folder), don't recreate it from
scratch, to avoid drift between machines.

## Prerequisites check

```powershell
winget list --id AutoHotkey.AutoHotkey
Get-Process | Where-Object { $_.ProcessName -match "AutoHotkey" }
```

If AutoHotkey v2 isn't installed, proceed below. There is no native Windows feature for this —
it always requires installing AutoHotkey (or an equivalent third-party automation tool).

## Step 1 — Install AutoHotkey v2

```powershell
winget install --id AutoHotkey.AutoHotkey --accept-package-agreements --accept-source-agreements
```

- Per-user install, no admin/UAC required. Installs to `%LOCALAPPDATA%\Programs\AutoHotkey\`.
- winget verifies the installer's SHA256 itself (`Successfully verified installer hash` in output).
  If you want to independently verify before trusting winget (as was done the first time this was
  set up): the SHA256 of `AutoHotkey_<version>_setup.exe` is published directly on the GitHub
  release page (`https://github.com/AutoHotkey/AutoHotkey/releases/tag/v<version>`), and that
  release tag is GPG-signed/"Verified" by the maintainer (Steve Gray / Lexikos). The installer exe
  itself is **not** Authenticode-signed (expected for small FOSS projects; Windows SmartScreen may
  warn on first run of the exe if downloaded manually — winget install above bypasses that UI).
  No network activity was observed (`Get-NetTCPConnection`/`Get-NetUDPEndpoint` polled every 2s)
  while running the installer or the resulting `AutoHotkey64.exe` script host.
- Confirm install location and interpreter path (needed for later steps):
  ```powershell
  Get-ChildItem "$env:LOCALAPPDATA\Programs\AutoHotkey" -Recurse -Include *.exe
  ```
  Expect: `...\AutoHotkey\v2\AutoHotkey64.exe` (this is the interpreter to launch scripts with).

## Step 2 — Deploy the script

Copy this entire project folder to the new machine at the same relative meaning (path can differ
per-machine; adjust Step 3/4 paths accordingly), e.g.
`C:\Users\<user>\Desktop\Projects\fast_copy_paste\SelectCopyMiddlePaste.ahk`.

Do not edit the script's logic unless intentionally changing behavior — it was iterated and
validated (see "Validation approach" below). If you do need to tweak it, re-validate with the same
method rather than assuming it works.

## Step 3 — Run it now (current session)

```powershell
Start-Process -FilePath "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" `
  -ArgumentList '"C:\Users\<user>\Desktop\Projects\fast_copy_paste\SelectCopyMiddlePaste.ahk"'
```

Verify it's running (note: the resulting PID is often *different* from any PID reported by a
process-launcher wrapper/tool — AutoHotkey can relaunch itself once; always re-query by name):

```powershell
Get-Process | Where-Object { $_.ProcessName -match "AutoHotkey" } | Select-Object Id,StartTime,Path
```

## Step 4 — Autostart at every logon

Use a Startup-folder shortcut (a `.lnk` in the Startup folder, not a registry Run key or a
Scheduled Task, though either of those would also work):

```powershell
$startup = [Environment]::GetFolderPath("Startup")
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut("$startup\SelectCopyMiddlePaste.lnk")
$shortcut.TargetPath = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$shortcut.Arguments = '"C:\Users\<user>\Desktop\Projects\fast_copy_paste\SelectCopyMiddlePaste.ahk"'
$shortcut.WorkingDirectory = "C:\Users\<user>\Desktop\Projects\fast_copy_paste"
$shortcut.Save()
```

**Known failure mode**: if this project folder is ever moved/renamed, this `.lnk`'s
target/arguments become stale and it will fail **silently** at next logon — no error, the script
just won't start. If the feature stops working after moving things around, check this shortcut's
Arguments path first.

## Validation approach (use this, don't just eyeball the code)

Trusting "the code looks right" was not sufficient during development — click-count/timing logic
especially needs empirical confirmation. Recommended approach for verifying on a new machine:

1. Temporarily add a debug line inside `~LButton::` (after the click-count is computed) and inside
   `MButton::`:
   ```ahk
   FileAppend A_Now " click#" ClickCount " dt=" dt " dist=" Round(distFromLast) " on [" proc "]`n", A_Temp "\select-copy-paste-debug.log"
   ```
   (`proc` needs `try proc := WinGetProcessName("A")` added first if not already in scope.)
2. Restart the script (kill by process name, relaunch — see Step 3).
3. Physically perform: a drag-select, a double-click, a triple-click, and a middle-click (in both
   a browser and a non-browser app).
4. Read back `%TEMP%\select-copy-paste-debug.log` and confirm each action logged the expected
   click-count/behavior and that no unexpected app-name showed unwanted middle-click firing (e.g.
   zero `MButton on [firefox.exe]`-style lines proves the browser exclusion is working, since that
   hotkey is disabled entirely via `#HotIf` for browsers — it won't log at all there, by design).
5. Remove the debug line again once confirmed (or leave it if actively iterating).

Attempting to simulate this end-to-end with synthetic input (e.g. `MouseClickDrag` against a
scratch Notepad/Gui window from a second script) was tried during development and is **not
recommended** as the primary validation method — it's unreliable (Windows 11's modern Notepad
isn't a classic `Edit1` control, so `ControlGetHwnd` fails; synthetic input timing/targeting is
fiddly) and, on a real desktop with many windows open, capturing screenshots to debug is invasive
and hard to interpret. Real physical input + the debug log above is faster and more trustworthy.

## Gotchas encountered (avoid repeating)

- **PowerShell call operator**: `& "C:\path with spaces\setup.exe" /flag` — the leading `&` is
  required; without it PowerShell throws a parser error on the first `/`.
- **Silent/unattended install flags hang forever**: `setup.exe /VERYSILENT /DIR="..."` (Inno-Setup
  style flags) triggered a UAC elevation prompt that blocks headlessly with no visible error —
  the process just sits there "Responding: True" using ~0% CPU. `winget install` avoids this
  entirely for the per-user install path used here. If installing the exe directly and it hangs,
  check for a hidden UAC consent prompt before assuming something else is wrong.
- **Background-process PID drift**: whatever tool launches `AutoHotkey64.exe` may report a PID
  that differs from the actual long-running process's PID (AutoHotkey can re-exec itself once at
  startup). Always re-verify with `Get-Process -ProcessName AutoHotkey64` (or `AutoHotkey*`) rather
  than trusting a launcher's reported PID for later monitoring.
- **AHK v2 scoping**: variables assigned inside a hotkey body (like the click-tracking state:
  `ClickCount`, `LastClickTime`, `LastClickX`, `LastClickY`) must be declared `global` inside the
  hotkey block to persist across invocations; variables only *read* (like `DragThreshold`) do not
  need an explicit `global` declaration in AHK v2.
- Scoping middle-click-paste off for browsers uses `#HotIf !IsBrowser()` ... `#HotIf` (with no
  condition) to close the conditional scope — forgetting the closing bare `#HotIf` would leave
  every hotkey defined afterward incorrectly scoped to the same condition.

## License

This project is licensed GPL-2.0-or-later — see `LICENSE` in this folder.
