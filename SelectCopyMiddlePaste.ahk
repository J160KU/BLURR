; SelectCopyMiddlePaste.ahk
; SPDX-License-Identifier: GPL-2.0-or-later
; Part of the "BLURR" project — see LICENSE in this folder for the full license text.
;
; Linux-style "primary selection" behavior for Windows:
;   - Selecting text with the mouse (left-button drag) automatically copies it to the clipboard.
;   - Double-clicking a word (native word-select) also copies it.
;   - Triple-clicking a word (native line/paragraph-select) also copies it.
;   - Middle-click pastes the clipboard contents at the cursor, EXCEPT in browsers, where middle-click
;     keeps its normal behavior (open link in new tab / close tab / autoscroll).
;
; Runs silently in the tray. No network access, no external dependencies.
; See README.md in this folder for setup/usage, AGENTS.md for replication steps.

#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Mouse", "Screen"

; Minimum drag distance (pixels) before a left-button release is treated as a text selection
; rather than a plain click. Prevents every ordinary click from firing Ctrl+C.
DragThreshold := 4

; Multi-click detection (double/triple click) uses the same timing/position window Windows
; itself uses to recognize a double-click, so this matches native word/line-select behavior.
DoubleClickRadius := 4
LastClickTime := 0
LastClickX := 0
LastClickY := 0
ClickCount := 0

~LButton::
{
    global LastClickTime, LastClickX, LastClickY, ClickCount

    startX := 0
    startY := 0
    MouseGetPos(&startX, &startY)
    KeyWait "LButton"
    endX := 0
    endY := 0
    MouseGetPos(&endX, &endY)
    distance := Sqrt((endX - startX) ** 2 + (endY - startY) ** 2)

    if (distance > DragThreshold) {
        ; Left-button drag: the app just performed a text selection.
        Send "^c"
        ClickCount := 0
        return
    }

    ; No drag: this was a click. Figure out whether it's part of a double/triple-click
    ; sequence (same position, within the system's double-click time), same as the OS does.
    now := A_TickCount
    dt := now - LastClickTime
    distFromLast := Sqrt((startX - LastClickX) ** 2 + (startY - LastClickY) ** 2)
    doubleClickTime := DllCall("GetDoubleClickTime")

    if (dt <= doubleClickTime && distFromLast <= DoubleClickRadius) {
        ClickCount += 1
        if (ClickCount > 3)
            ClickCount := 1
    } else {
        ClickCount := 1
    }
    LastClickTime := now
    LastClickX := startX
    LastClickY := startY

    ; Double-click = word already selected by the app; triple-click = line/paragraph
    ; already selected by the app. Copy whatever got selected.
    if (ClickCount = 2 || ClickCount = 3) {
        Send "^c"
    }
}

; Middle-click: paste instead of the app's default middle-click behavior,
; except inside browsers where middle-click should keep opening/closing tabs.
#HotIf !IsBrowser()
MButton::Send "^v"
#HotIf

IsBrowser() {
    static browsers := ["chrome.exe", "msedge.exe", "firefox.exe", "brave.exe", "opera.exe", "vivaldi.exe"]
    proc := ""
    try proc := WinGetProcessName("A")
    for b in browsers
        if (proc = b)
            return true
    return false
}
