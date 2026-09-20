# Phase 4 Manual LAN Testing Guide

This guide covers manual testing of LAN Communication + Reading Synchronization without Internet, using same Wi-Fi or mobile hotspot.

## Setup

### Devices
- Minimum 2 devices: 1 Host, 1 Participant
- For multi-participant: 3+ devices (1 Host + 2 Participants)
- Each device: Android/iOS phone, tablet, or desktop with ReadMesh installed
- Same Wi-Fi OR Host's mobile hotspot (no Internet required)

### Network
**Option A - Same Wi-Fi:**
- Connect all devices to same router SSID
- Disable AP/client isolation in router settings if present
- Note Host IP from Room Detail: `LAN Host: 192.168.x.x:40404`

**Option B - Mobile Hotspot (No Internet):**
- Host: Settings > Hotspot > Enable, set SSID `ReadMeshHost`, no password or simple
- Participants: Wi-Fi > Connect to `ReadMeshHost`
- Host IP typically `192.168.43.1` (Android) or `172.20.10.1` (iOS)
- No mobile data needed, only local LAN

### App Prep
- Each device: Open Library > Import Sample PDF (creates 20-page dummy PDF)
- Ensure storage permission granted

## Test 1: 1 Host + 1 Participant

### Host Steps
1. Rooms > Create Room > Title "Study Room" > Select imported book > Create
2. Note Room Code e.g., `RM-4821` and LAN endpoint `192.168.1.10:40404` and `0 connected`
3. Tap Start Reading Session (if status created)
4. Tap Read as Host > Verify Page 1, next/prev enabled
5. Keep app foreground

### Participant Steps
1. Rooms > Join icon (top bar) > Enter Room Code `RM-4821` + Host IP `192.168.1.10` > Join
2. Room Detail should show `LAN: Connecting...` -> `Connected (LAN)` (green dot)
3. If stuck, check Host IP correct, Host server running, firewall not blocking 40404
4. Tap Read as Participant > Verify `Synced: Page 1 of 20`, next/prev disabled (Host-authoritative), green sync icon
5. **Host turns page to 2** > Participant should auto-flip to `Synced: Page 2 of 20` within 200ms
6. **Host pauses** > Participant sees yellow banner "Reading Session Paused by Host"
7. **Host resumes** > Banner disappears
8. **Host turns to page 10** > Participant follows to 10
9. **Disconnect:** Participant turn off Wi-Fi 5s, then on > Should go `Disconnected` -> `Reconnecting...` -> `Connected (LAN)`, auto-receives stateSnapshot with page 10
10. **Host ends** > Participant sees grey banner "Reading Session Ended by Host"

### Verify Persistence
- Participant: Close reader, reopen Library > Book shows progress 10/20 (50%) — from SQLite `reading_progress` table
- Query: `SELECT * FROM reading_progress WHERE session_id='RM-4821' AND device_id='participant_device_id'` should show currentPage 10

### Pass Criteria
- Join: Host count 1, participant gets stateSnapshot
- Page sync: Host page change -> participant follows
- Session lifecycle: pause/resume/end banners
- Reconnect: Restores latest page via stateSnapshot
- Persistence: SQLite row matches host page

## Test 2: 1 Host + Multiple Participants (2 Participants)

### Host
- Same as Test 1, but observe `N connected` count in Room Detail

### Participants B and C
- Both join same Room Code + Host IP
- Both open Read as Participant > Both show `Synced: Page 1`
- Host turns to 5 > Both B and C sync to 5 simultaneously
- Host pauses > Both see paused banner
- Disconnect B's Wi-Fi > Host count drops 2->1, C still syncs, B disconnected
- B reconnects > Receives snapshot with current page, count back to 2
- Host ends > Both see ended banner

### Pass Criteria
- Host participants list contains both deviceIds
- Broadcast reaches all clients
- No race when one reconnects while host changes page
- Each participant has separate `reading_progress` row with same page, different deviceId

## Troubleshooting Quick Checks
- **Cannot connect:** Verify Host IP via Room Detail, try `ping HostIP` from participant, check `telnet HostIP 40404`, ensure Host app foreground and server running
- **Discovery not showing rooms:** UDP beacon may be blocked — use manual IP entry (always works)
- **Page not syncing:** Ensure Host tapped next (calls `broadcastPageChange`), Participant subscribed to `pageStream`
- **Emulator:** Use `10.0.2.2` for Host IP if Host is on host machine, or host's LAN IP, not `127.0.0.1`

## No Internet Verification
- Disable mobile data on all devices, keep Wi-Fi/hotspot on — LAN TCP 40404 and UDP 40405 work without Internet
- Confirm by turning on airplane mode, then enable Wi-Fi only, repeat Test 1

