# Factorio Lamp LED Display

Adds a mod to the Factorio game (2.1 version needed) that sends out UDP packets to a local receiver daemon. The daemon creates MQTT messages that can be picked up by embedded microcontrollers that in turn drive Neopixel LEDs which reflect the color and status of in-game Lamps.

Factorio -> UDP to local receiver -> daemon (golang code) -> MQTT (mosquitto broker) -> ESP32-C3 receiver -> Neopixel LEDs

This repository contains most of the pieces required to build this. You need to bring some skills/tools though:

- at least breadboarding, better soldering for the hardware
- a 3D printer to make the Lamp cases
- a local docker installation on the machine where you run Factorio (or you need to run the daemon manually, it is a single binary)

What you find:

- `daemon` contains the golang code for the local receiver daemon
- `factorio-mod` contains the code for the [Lamp LED Display](https://mods.factorio.com/mod/lamp_led_display) mod. Or get it from the mod portal
- `firmware` contains the software for the ESP32-C3 supermini board
- `pcb` contains the KiCAD files for a controller board. Or you can breadboard this together, either works fine.
- `3dprint` contains the 3MF files for the Lamp.

## How to get it to work

(All of this is intended to be run in a local network that is firewalled/secured against the internet. There is little security besides bare-bones passwords that are written in cleartext in config files locally. If you care deeply about security, there is room for improvement)

### Local setup

This sets up runtime config, broker credentials and starts the daemon.

```sh
cp config.example.yaml config.yaml
./scripts/create-credentials.sh
docker compose up -d --build
```

The `config.yaml` file is read by the daemon on startup. The secrets created by the script are stored in the `secrets` directory.

If everything goes well, this is what docker ps should show:

```text
❯ docker ps
CONTAINER ID   IMAGE                      COMMAND                  CREATED       STATUS       PORTS                                         NAMES
208767bb72bf   display-daemon             "/factorio-display"      6 hours ago   Up 6 hours   127.0.0.1:34198->34198/udp                    display-daemon-1
9c2e8b83e011   eclipse-mosquitto:2.0.22   "/docker-entrypoint.…"   6 hours ago   Up 6 hours   0.0.0.0:1883->1883/tcp, [::]:1883->1883/tcp   display-mosquitto-1
```

### Factorio Setup

- add the mod from the mod portal (or copy the `factorio-mod/lamp_led_display` folder into your mod folder). Add `--enable-lua-udp 34199` to the Factorio start command. If you run Factorio from Steam, you can add this to the "Launch Options" directly in Steam.

- Start Factorio and load a game that has the mod activated. Then run `docker logs -f display-daemon-1` from a command line window. You should see something like this:

```text
daemon-1     | {"time":"2026-08-27T01:00:59.183286626Z","level":"INFO","msg":"factorio packet accepted","save_id":"1f0288b3-4937613a","sequence":1,"type":"snapshot","channels":0}
```

If you see this, congrats, Factorio is talking to the locally running daemon and writes MQTT messages.

### Get some LEDs

Make sure to get an ESP32-C3 supermini board (most other ESP32-C3 boards should work, too).

- Install the PlatformIO framework. On a mac, do `brew install platformio`. Otherwise, go to [PlatformIO Core installation](https://platformio.org/install/cli) and follow the instructions

- connect your board to the computer with an USB cable

- run

```sh
cd firmware
pio run -e esp32-c3-supermini -t upload
pio device monitor
```

If all goes well, you should see a `Factorio-Display-xxxxxx` WiFi network appear. Connect to it (e.g. with a smartphone), it should pop open a capturing portal to enter WiFi credentials, MQTT broker information. Leave the pixel count as "8" and the "channel offset" as 0. Save, reboot and now the device should show (in the shell that does the `pio device monitor`) something like this:

```text
Connected!
*wm:AutoConnect: SUCCESS
*wm:STA IP Address: 172.16.10.102
Configuration page: http://172.16.10.102/ or http://factorio-display-shop-floor-a.local/
```

running `docker logs display-mosquitto-1` should show something like this:

```text
1787807093: New client connected from 192.168.65.1:46373 as factorio-display-shop-floor-a (p2, c1, k30, u'device').
```

### Assign a lamp

If you have any Neopixels connected to the ESP32-C3 chip, you are now ready to assign a lamp to them. If you are not running the game right now, after a few seconds, all LEDs should start to slowly pulse cyan to show that "no Factorio game is sending any information". This also happens when you pause the game.

Put a Lamp down, give it some color, make sure that "always on" is checked.

Press ALT/Option + Shift + D. The cursor should now show a lamp.

Click on the Lamp you just placed. In the dialog, set the Channel Number to "1". PRESS ENTER!

The first LED on your ESP32-C3 should now have the same color as the lamp in the game.

Press Control + Shift + D to open the Channel list where you can control other aspects or delete a channel.

----

## Project background

This project owes its existence to the lucky confluence of a few things.

- I found a Factorio Lamp on Makerworld that is designed for RGB (Neopixel) LEDs.
- I really wanted to play around with ESP32-C3 Supermini boards and I had a few lying around.
- Adafruit sells nice 5mm discrete multi-color LEDs that are Neopixel compatible.

And while all of this is great, some obstacles were in the way:

- The Factorio Lamp was single-color white and not gray/translucent. So some remixing was required.
- Besides 3D printing, this project requires some hardware and quite a bit of software.
- Firmware for the ESP32-C3
- Some daemon that takes UDP from Factorio and sends it to the board
- An actual Factorio mod that sends out UDP data messages.

That project was shelved for a year or so. Not much happened.

__If you are concerned about AI and can no longer sit back and allow AI infiltration, AI indoctrination, AI subversion and the international AI conspiracy to sap and impurify all of your precious bodily fluids, then this is the moment where you need to stop reading.__

----

I read [Matthew Brunelle's Blog](https://blog.matthewbrunelle.com/its-ok-to-use-coding-assistance-tools-to-revive-the-projects-you-never-were-going-to-finish/) and a new AI model arrived (GPT-5.6-sol if you are interested) and anyway, I wanted to find out how good AI really is.

I resurrected that project with a single prompt (typos and all):

```text
"here is what I want to do: I play the game factorio and I want to bring some of the aspects of the game to the real world. For that, I want to connect a few multi-color LEDs to a microcontroller, which can connect to WiFi. The factorio game should send some events out through its UDP interface to a local daemon (same host where the game runs) which in turn can turn these LEDs on and off.

I have a bunch of ESP-C3 microcontrollers, NeoPixel LEDs and passive components that would be needed to breadboard that together. I want to use the PlatformIO for the framework. The code on the ESP-C3 should allow me to configure WiFi when it boots up, then connect to a daemon running on my host using MQTT. In the long run, it should be possible to have multiple microcontrollers. The code on the microcontroller can be written in C or Rust, the daemon should be written in golang. If you have any questions, ask me, then create a plan on what we want to do."
```

~ 15 clarification questions and 20 Minutes later, I had about ~75% of this git repo. It went through a few iterations (some protocol additions, simplification of configuration, adding configuration pages to the microcontroller) afterwards.

And it worked on the first try.

It put together some documentation (the contents of the [docs folder](https://github.com/hgschmie/factorio-lamp-led-display/tree/main/docs) and the [README-codex](https://github.com/hgschmie/factorio-lamp-led-display/blob/main/README-codex.md)). None of those are 100% correct but pretty close.

What this project contains is not just AI generated code. I rewrote the factorio mod from scratch (the AI generated one was functional but ugly and iterating a few times made the code very convoluted) and while I got ChatGPT to put together ~50% of the PCB (KiCAD MCP is difficult to get to work but once it does, codex gets a lot done with it), I ultimately re-layouted it and routed it manually.

AI put together all of the tests (and updated them once I rewrote the factorio mod), the docker setup, all scripts and the docs. It verified the things I did and pointed out errors that I did not notice.

But I never touched (nor read) the ESP32-C3 firmware and the UDP daemon code. And the firmware has way more feature that I would have built myself (configuration pages! mDNS!). I assume the code is ugly for a human but so is the compiler output from a high level language compiler.
