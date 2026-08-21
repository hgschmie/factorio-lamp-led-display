# In-game acceptance checklist

1. Launch Factorio 2.1 with `--enable-lua-udp 34199` and enable the mod. Port 34199 is Factorio's local port; the daemon receives the mod's packets on port 34198.
2. Use the shortcut, drag over exactly one assembler or furnace, and assign `smelter-1`.
3. Verify a green circle marks the machine and Ctrl+Shift+D lists it.
4. Rename it and confirm duplicate/invalid names are rejected; remove it and confirm the list updates.
5. Mine or destroy an assigned machine and confirm its next UDP status is `missing`.
6. Observe a state transition arriving within 0.5 seconds and full `snapshot` packets every five seconds.
7. Save/reload and confirm the save ID, sequence, assignments, and marks persist.
