# Lamp LED Display

Move Factorio Lamps into the real world. This mod is probably not useful to you, unless you also spend time to setup the supporting infrastructure. And maybe build a bit of hardware.

Allows selecting Lamps in the game and assigning LED channels to them. This information is then sent out through the Factorio UDP interface to a process listening to it.

To use this mod, you *MUST* run Factorio with the `--enable-lua-udp <port number>` option. I use 34199 for the game. UDP packets are, by default, sent to port 34198. This can be changed in the mod settings.

## Credits

Graphics:

* [Bulb icons created by AB Design - Flaticon](https://www.flaticon.com/free-icons/bulb)
* [Order icons created by Magnific - Flaticon](https://www.flaticon.com/free-icons/order)

## Legal & Copyright

The code was partially written and reviewed by AI coding agents. If you are fundamentally opposed to using AI tools to develop software and improve software quality, you are free to not install it.

--------------------------------------------------
Copyright (C) 2026 Henning Schmiedehausen (@hgschmie), licensed under the MIT license.
