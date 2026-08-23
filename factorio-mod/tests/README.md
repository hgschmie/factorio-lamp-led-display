# In-game acceptance checklist

1. Launch Factorio 2.1 with `--enable-lua-udp 34199` and enable the mod. Port 34199 is Factorio's local port; the daemon receives the mod's packets on port 34198.
2. Use the shortcut, drag over exactly one assembler or furnace, and assign channel `0` using the numeric field.
3. Enable Alt mode and verify a green circle marks the machine; disable Alt mode and confirm the circle is hidden. Ctrl+Shift+D should still list it.
4. Change it to another channel and confirm duplicate values and numbers outside `0..63` are rejected; remove it and confirm the list updates.
5. Mine or destroy an assigned machine and confirm its next UDP status is `missing`.
6. Observe a state transition arriving within 0.5 seconds and full `snapshot` packets every five seconds.
7. Save/reload and confirm the save ID, sequence, numbered assignments, and marks persist.
8. Place both a standard small lamp and a Physical display lamp. Assign each with the shortcut and confirm the assignment dialog includes brightness and effect controls.
9. Open Ctrl+Shift+D, change each lamp's brightness/effect inline, click Apply, and confirm rename/remove still work.
10. Open either lamp normally and confirm the native GUI still offers enable/disable, color mapping, separate RGB signals, and packed RGB mode.
11. Test brightness values 0 and 255 plus solid, blink, and pulse, then drive each native color mode from the circuit network and confirm its evaluated color reaches the corresponding physical pixel.
