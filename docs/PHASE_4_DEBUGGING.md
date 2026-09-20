# Phase 4 Debugging Guide

## Architecture Overview
- **Host:** `LanHostServer` — TCP ServerSocket on `0.0.0.0:40404` (or dynamic 0), authoritative page/status, broadcasts to all clients, sends `joinAck` + `stateSnapshot` on join.
- **Participant:** `LanParticipantClient` — TCP Socket, sends `join`, receives `stateSnapshot`, `pageChanged`, session lifecycle, handles reconnect.
- **Discovery:** `LanDiscoveryService` — UDP broadcast `255.255.255.255:40405` every 2s, JSON `readmesh_beacon`, optional.
- **Coordinator:** `LanSyncCoordinator` — bridges LAN + SQLite `reading_progress` and `sessions` tables.
- **UI:** `RoomDetailScreen` starts Host server + beacon, shows `LAN Host: IP:Port` and `N connected` or `LAN: Connected`. `PdfReaderScreen` Host mode broadcasts page changes, Participant mode disables manual nav and follows `pageStream`/`statusStream`.

## Key Files
- `lib/features/lan/lan_connection_state.dart` — 4 states
- `lib/features/lan/lan_message.dart` — newline-delimited JSON protocol
- `lib/features/lan/lan_host_server.dart` — host logic
- `lib/features/lan/lan_participant_client.dart` — participant logic
- `lib/features/lan/lan_discovery_service.dart` — UDP beacon
- `lib/features/lan/lan_sync_coordinator.dart` — SQLite persistence
- `lib/features/room/room_detail_screen.dart` — Host/Participant init, UI
- `lib/features/reader/pdf_reader_screen.dart` — page sync UI

## Logs

### Host
```dart
hostServer.messageStream.listen((msg) => print('Host recv: $msg'));
hostServer.participantsStream.listen((list) => print('Host participants: ${list.length}'));
```

### Participant
```dart
participantClient.stateStream.listen((s) => print('Participant state: $s'));
participantClient.messageStream.listen((m) => print('Participant msg: $m'));
participantClient.pageStream.listen((p) => print('Participant page: $p'));
participantClient.statusStream.listen((s) => print('Participant status: $s'));
```

### Discovery
```dart
discoveryService.roomsStream.listen((rooms) => print('Discovered: $rooms'));
```

## Common Failures and Fixes

### 1. Participant stuck Connecting
- **Cause:** Wrong Host IP, Host not started, port blocked, firewall
- **Debug:** 
  - Host: Check `hostServer.isRunning`, `hostServer.port`, `hostServer.localIp`
  - Participant: Check `Socket.connect` exception, `state` remains connecting
  - Try `adb shell ping HostIP`, `nc -vz HostIP 40404`
  - Ensure Host app foreground, not killed
- **Fix:** Correct IP, restart Host server, allow port in firewall, use hotspot

### 2. Host shows 0 connected after join
- **Cause:** Participant didn't send join, or Host didn't process
- **Debug:** 
  - Participant: Check `send(join)` called in `connect()` after socket connect
  - Host: Add print in `_processClientLine` and `_handleJoin`
  - Check newline terminator: `serialize()` adds `\n`, required for `LineSplitter`
- **Fix:** Ensure join sent, socket not closed prematurely

### 3. Page change not syncing
- **Cause:** Host didn't broadcast, or Participant not listening
- **Debug:**
  - Host: Check `broadcastPageChange` called in `PdfReaderScreen.nextPage()` when `isHost`
  - Host: Check `broadcast()` iterates `_clients.keys`, writes `msg.serialize()`
  - Participant: Check `pageStream` subscription in `PdfReaderScreen._setupLanSyncSubscriptions`, `currentPage` updated
  - Check `messageStream` receives `pageChanged`
- **Fix:** Ensure Host mode, ensure subscription active, check `mounted`

### 4. Reconnect fails
- **Cause:** Last address null, autoReconnect false, Host stopped
- **Debug:**
  - Check `_lastHostAddress` and `_lastPort` set in `connect()`
  - Check `_intentionallyDisconnected` false, `_autoReconnect` true
  - Check `reconnect()` called, Timer scheduled
  - Host still running?
- **Fix:** Call `reconnect()` manually via Reconnect button, ensure Host running

### 5. State snapshot shows old page
- **Cause:** Host `_currentPage` not updated before snapshot
- **Debug:**
  - Check `broadcastPageChange` updates `_currentPage` before `broadcast`
  - Check `_handleJoin` sends snapshot with `_currentPage`, `_totalPages`, `_sessionStatus`
- **Fix:** Update internal state before broadcast

### 6. UDP discovery not working
- **Cause:** OS blocks broadcast, emulator isolation, AP isolation
- **Debug:** Check `roomsStream` empty, `discoveredRooms` empty, try manual IP
- **Fix:** Discovery is optional — manual IP entry always works. For emulator, use `10.0.2.2` or host LAN IP

### 7. SQLite persistence not happening
- **Cause:** Repo not injected, deviceId empty, writeTx fails
- **Debug:**
  - Check `DeviceService.getOrCreateCurrentProfile()` returns id
  - Check `progressId` format `prog_session_book_device`
  - Check `ReadingProgressRepository.getProgress(sessionId, deviceId)` after page change
  - Check `AppDatabase` writeTx logs
- **Fix:** Ensure profile exists, ensure coordinator subscriptions active, check `await` on `updateProgress`

## Manual Socket Test
```bash
# Terminal 1: Start host (via app or simple dart server)
# Terminal 2:
nc -v 192.168.1.10 40404
# Then type:
{"type":"join","sessionId":"RM-1234","senderDeviceId":"test_device","senderName":"Tester"}
# Expect 2 lines back:
# {"type":"joinAck",...}
# {"type":"stateSnapshot","currentPage":1,...}
# Then host turns page, you should see:
# {"type":"pageChanged","currentPage":2,...}
```

## SQLite Inspection
```dart
// In app or test:
final progress = await progressRepo.getProgress('RM-4821', 'deviceId');
print(progress?.currentPage);

// On device via adb (root or debug):
adb shell
run-as com.example.readmesh
sqlite3 /data/data/com.example.readmesh/app_flutter/readmesh.db
SELECT * FROM reading_progress WHERE session_id='RM-4821';
```

## Deterministic Local Tests (No Devices)
```bash
flutter test test/unit/phase4/lan_message_test.dart
flutter test test/unit/phase4/lan_communication_sync_test.dart
flutter test test/unit/phase4/lan_discovery_test.dart
flutter test test/unit/phase4/lan_ui_sync_widget_test.dart
# Or all:
flutter test test/unit/phase4/
```
These use `InternetAddress.loopbackIPv4` and dynamic port 0, no physical devices.

## Network Tools
- **Find Host IP:** `LanHostServer.getLocalIpAddress()` or Settings > Wi-Fi > IP
- **Check Port:** `hostServer.port` after start
- **Ping:** `ping HostIP`
- **Port Check:** `telnet HostIP 40404` or `nc -vz HostIP 40404`
- **Flutter Logs:** `flutter logs`, `adb logcat | grep flutter`

## Checklist Before Reporting Bug
- [ ] Host IP correct and reachable via ping?
- [ ] Host server isRunning true, port 40404?
- [ ] Participant state transitions: connecting -> connected?
- [ ] Host receives join and sends joinAck + stateSnapshot?
- [ ] Participant pageStream receives pageChanged?
- [ ] SQLite reading_progress updated?
- [ ] No encryption or forbidden functionality added?
- [ ] Clean shutdown: stop() closes sockets, dispose() closes controllers?

