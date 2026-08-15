# Offline Chat (Android)

A peer-to-peer chat app that works with **zero internet connection**. Two or
more Android phones near each other (roughly Bluetooth/WiFi range) can
discover one another, connect, and exchange messages directly — no server,
no mobile data, no WiFi router required.

## How it works

Built on **Google's Nearby Connections API** (via the `nearby_connections`
Flutter plugin). The API automatically chooses between Bluetooth Classic,
Bluetooth Low Energy, and WiFi Direct depending on range and message size, so
you don't have to manage the radio layer yourself:

- **Advertising** – your phone announces itself as available to chat.
- **Discovery** – your phone looks for other advertising phones nearby.
- **Connection** – once two phones see each other, either side can request
  a connection; both must be running the app.
- **Messaging** – text is sent as small byte payloads directly between
  connected devices.

Every device advertises *and* discovers at the same time (`Strategy.P2P_CLUSTER`),
so it's genuinely peer-to-peer — there's no fixed "host" phone.

## Project structure

```
lib/
  main.dart                 # App entry, theme, provider setup
  models/message.dart       # ChatMessage + NearbyPeer models, wire format
  services/nearby_service.dart  # All Nearby Connections logic (the core)
  screens/home_screen.dart  # Peer discovery list, permissions flow
  screens/chat_screen.dart  # Message thread + composer
android/
  app/src/main/AndroidManifest.xml  # Bluetooth/WiFi/Location permissions
```

## Setup

1. **Install Flutter** (3.x+) if you haven't: https://docs.flutter.dev/get-started/install
2. From this project folder, fetch dependencies:
   ```
   flutter pub get
   ```
3. Connect **two physical Android phones** via USB (or run on one and use
   `flutter run -d <device_id>` for each). **Bluetooth/WiFi P2P does not
   work in the Android emulator** — you need real hardware to test this.
4. Run on each device:
   ```
   flutter run
   ```

## Using the app

1. Open the app on both phones. Grant the Bluetooth, Location, and Nearby
   Devices permission prompts — these are required by Android for BLE
   scanning to work, even though the app never touches the internet.
2. Each phone starts advertising and scanning automatically. Within a few
   seconds each should see the other in its list.
3. Tap a device to send a connection request; the other phone auto-accepts.
4. Once connected, tap the device again to open the chat thread and start
   messaging.

Turn off WiFi and mobile data entirely and it still works — that's the point.

## Known limitations / things to harden before shipping

- **Auto-accept connections** — `nearby_service.dart` currently accepts every
  incoming connection automatically. For real use, show the
  `ConnectionInfo.authenticationDigits` to both users and require manual
  confirmation, so people can verify they're pairing with the right phone.
- **No mesh relay** — messages only travel directly between connected
  devices (one hop). If you need messages to hop through intermediate
  phones to extend range, that's a substantial addition (message
  deduplication, TTL, routing).
- **No persistence** — chat history lives in memory only and clears on
  app restart. Add local storage (e.g. `sqflite` or `hive`) if you want
  history to survive.
- **No encryption layer on top of the OS-level one** — Nearby Connections
  encrypts the transport, but add end-to-end encryption yourself if you
  need guarantees beyond that.
- **Group chat is "broadcast to all connected"** — every message you send
  goes to every currently connected peer, and the chat screen shows one
  shared history rather than per-peer threads. Split `messages` by peer id
  if you want private 1:1 threads instead.
- **Range** is roughly 10–100m depending on which radio the API picks
  (BLE is shorter range, WiFi Direct is longer) and physical obstructions.

## Why Nearby Connections instead of raw BLE or a mesh SDK

Since this is Android-only, Nearby Connections is the most reliable and
best-documented option: Google maintains it, it auto-negotiates the best
radio for the situation, and it handles the messy parts (multi-radio
switching, payload chunking, endpoint lifecycle) that you'd otherwise have
to build by hand on top of raw BLE GATT. If you later need iOS support too,
you'd need a different approach (e.g. a BLE-based mesh SDK like Bridgefy),
since Nearby Connections has no iOS-side counterpart that interoperates.
