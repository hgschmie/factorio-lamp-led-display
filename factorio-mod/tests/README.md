# In-game acceptance checklist

1. Launch Factorio 2.1 with `--enable-lua-udp 34199` and enable the mod. Port 34199 is Factorio's local port; the daemon receives the mod's packets on port 34198.
2. Place two standard lamps. Use the shortcut or Alt+Shift+D, drag over exactly one lamp, and assign it channel `1` with the numeric field. Assign the other lamp channel `64`.
3. Enable Alt mode and verify each assigned lamp shows its channel marker; disable Alt mode and confirm the markers are hidden.
4. Assign an already-used channel to the other lamp and confirm ownership moves to that lamp. Close an unassigned lamp's dialog and confirm no assignment is created.
5. In the assignment dialog, test brightness values `0` and `255` and select each of `solid`, `blink`, and `pulse`.
6. Open the assignment list with Ctrl+Shift+D. Confirm both channels are sorted numerically, edit brightness and effect values there, use the camera to jump to a lamp, and remove an assignment.
7. Connect a lamp to the circuit network. Verify enabled and disabled states, fractional and byte RGB values, color mapping, separate RGB signals, and packed RGB mode reach the corresponding physical LED.
8. Observe changed lamp state arriving in an `update` within one tick and complete `snapshot` packets every 300 ticks (five seconds at 60 UPS). Confirm channel `1` is sent as UDP channel `0` and channel `64` as UDP channel `63`.
9. Save and reload. Confirm the save ID, sequence, assignments, brightness/effects, and Alt-mode markers persist, and that loading emits a complete `reset` packet before normal updates resume.
