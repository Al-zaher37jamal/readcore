# Phase 5 — Manual Acceptance Testing — Real-Device Instructions

**Branch:** `arena/01a0bf89-readmwsh`  
**Phase 4 Commit:** `aa3a6b462d170085a2d42c55e61ae51be9f84a`  
**Environment Required:** 2-3 physical Android devices (or Windows + Android), same Wi-Fi OR mobile hotspot, **Internet disabled** during test  
**PDF:** Real local PDF imported via Phase 2 pipeline, rendered via `pdfx` real renderer (not simulated)

> **Arena Sandbox Limitation:** Arena E2B sandbox has no physical devices, no Wi-Fi/hotspot, no Flutter SDK (`flutter: command not found`). Therefore real-device tests cannot be executed in sandbox and must be marked **BLOCKED — Requires physical devices**. Automated loopback tests cover same logic and are used for local verification.

---

## Prerequisites

1. **Devices:**
   - Device A: Host (Android phone/tablet or Windows desktop)
   - Device B: Participant 1
   - Device C: Participant 2 (for Test C)
   - All devices have ReadMesh installed via `flutter run` or APK (`flutter build apk`)

2. **Network:**
   - **Option 1 — Same Wi-Fi:** Connect all devices to same router SSID, disable AP isolation
   - **Option 2 — Mobile Hotspot (No Internet):** Host device enables Hotspot (Settings > Hotspot), Participants connect to Host SSID. No mobile data needed. Host IP typically `192.168.43.1` (Android) or `172.20.10.1` (iOS). Internet disabled via airplane mode + Wi-Fi on.

3. **App Prep:**
   - Each device: Library > Import Sample PDF (or import real PDF file) — creates book with real PDF file at `books/<id>.pdf`
   - Verify real PDF content renders (text/images) in Library > Read Now (solo mode) — should show actual PDF, not simulated text

4. **Find Host LAN IP:**
   - Host: After creating room, Room Detail top card shows `LAN Host: 192.168.x.x:40404` and `N connected` — use this IP in Participant join dialog
   - If shows `127.0.0.1`, find IP manually via Wi-Fi settings or `ifconfig`/`ipconfig`

---

## Test A — Host + Participant (Real PDF Synchronization)

**Goal:** Prove Host's real PDF page becomes authoritative and Participant's real PDF viewer auto-syncs.

**Steps:**

1. **جهاز A (Host) ينشئ الغرفة:**
   - Open ReadMesh > Library > Select imported real PDF (e.g., 20-page document with distinct content per page)
   - Rooms > Create Room > Title "Real PDF Test" > Select book > Create
   - Record room code `RM-XXXX` (e.g., `RM-4821`) and Host LAN IP:Port `192.168.1.10:40404`

2. **جهاز B (Participant) ينضم عبر نفس Wi-Fi/Hotspot:**
   - Connect to same Wi-Fi/hotspot as Host
   - Rooms > Join icon (top bar) > Enter Room Code `RM-XXXX` + Host IP `192.168.1.10` > Join
   - Verify connection state becomes `Connected (LAN)` (green dot) in Room Detail — `LAN: Connected (LAN)`

3. **كلا الجهازين يفتحان نفس PDF الحقيقي:**
   - Host: Room Detail > Tap "Read as Host" → Should show real PDF page 1 content (actual text/images via pdfx `PdfView`)
   - Participant: Room Detail > Tap "Read as Participant" → Should show `Synced: Page 1 of 20`, next/prev disabled (Host-authoritative), green sync icon, real PDF page 1 content

4. **Host يضغط Start:**
   - Host: Room Detail > Start Reading Session (if status `created`) → `broadcastSessionStarted()` → status `active`
   - Participant: Should receive ACTIVE state (no paused banner)

5. **Host ينتقل إلى page 5:**
   - Host: In PdfReaderScreen, tap Next 4 times or Jump to Page 5 → `_currentPage=5`, `_saveProgress()`, `hostServer.broadcastPageChange(5)` → LAN `pageChanged` JSON
   - **Expected:** Host shows real PDF page 5 content

6. **Participant يجب أن ينتقل تلقائيًا إلى page 5 في PDF الحقيقي:**
   - Participant: `LanParticipantClient.pageStream` receives 5 → `PdfReaderScreen` listener `setState(_currentPage=5)` + `_saveProgress()` → `PdfPageView.didUpdateWidget` → `PdfController.jumpToPage(5)` → **Real PDF viewer shows actual page 5 content**, bottom bar `Synced: Page 5 of 20`
   - Verify SQLite: `SELECT * FROM reading_progress WHERE session_id='RM-XXXX' AND device_id='participant_device_id'` → `currentPage=5`

7. **Host ينتقل إلى page 12:**
   - Host: Jump to Page 12 → broadcast
   - Participant: Auto page 12 with real content

8. **Pause:**
   - Host: Room Detail > Pause → `broadcastSessionPaused()` → status `paused`
   - Participant: Yellow banner "Reading Session Paused by Host", status PAUSED

9. **Resume:**
   - Host: Resume → `broadcastSessionResumed()` → status `active`
   - Participant: Banner disappears, ACTIVE

10. **End:**
    - Host: End Room → `broadcastSessionEnded()` → status `ended`
    - Participant: Grey banner "Reading Session Ended by Host", status ENDED

**PASS Criteria:**
- Real PDF file opens (not simulated)
- Host page authoritative
- Participant real PDF auto-syncs via `jumpToPage`
- Lifecycle Start/Pause/Resume/End propagate
- Persistence via `reading_progress`
- Participant cannot manually control (next/prev disabled)

---

## Test B — Reconnect (Real PDF)

**Goal:** Participant disconnects, Host moves, Participant reconnects and receives state_snapshot with correct real page.

1. **اجعل الصفحة 12:** Host at page 12, Participant synced to 12
2. **افصل شبكة Participant:** Disable Wi-Fi/hotspot on Participant → Verify `Disconnected` / `Reconnecting` state in Room Detail, Host count 1→0
3. **تحقق من Disconnected/Reconnecting:** Participant UI shows red dot `Disconnected`, Reconnect button appears
4. **غيّر Host الصفحة إلى 18:** Host Jump to Page 18 → `_currentPage=18`, broadcast (no Participant to receive)
5. **أعد اتصال Participant:** Enable Wi-Fi, tap Reconnect or auto-reconnect Timer 2s → `Socket.connect(lastIP, lastPort)` → `join` message → Host `_handleJoin` sends `stateSnapshot` with `_currentPage=18`
6. **يجب أن يستلم State Snapshot ويرجع إلى page 18:** Participant `pageStream` receives 18 → `setState` → `PdfPageView.jumpToPage(18)` → **Real PDF viewer shows actual page 18 content**, `Synced: Page 18`
7. **تحقق من reading_progress في SQLite:** Query `reading_progress` for participant device → `currentPage=18`

**PASS Criteria:** Reconnect restores latest authoritative real page via stateSnapshot, persistence preserved.

---

## Test C — 1 Host + 2 Participants (Real PDF)

**Goal:** 1 Host + 2 Participants minimum, all sync, disconnect one, other continues, reconnect receives latest.

1. **Host + Participant 1 + Participant 2:** Host creates room, B and C join same `RM-XXXX` + Host IP, both show `Connected`, Host shows `2 connected`
2. **غيّر الصفحة:** Host page 5 → B and C both auto page 5 with real content
3. **يجب أن يصل التغيير للمشاركين الاثنين:** Verify both `Synced: Page 5`
4. **افصل Participant 1:** Disable Wi-Fi on B → Host count 2→1, C continues normally, still syncs when Host changes to page 8
5. **يجب أن يستمر Participant 2:** C shows page 8
6. **أعد Participant 1:** Enable Wi-Fi on B, reconnect → Receives stateSnapshot with latest page 8, real PDF returns to 8
7. **يجب أن يستلم آخر صفحة من Host:** B shows page 8
8. **Host ends:** All receive ENDED

**PASS Criteria:** Broadcast reaches all clients via `_clients` map, Host participant count accurate, remaining participant continues, reconnected receives latest, each participant separate `reading_progress` row.

---

## Edge Cases — To Verify Where Practical

- Invalid room code → NotFoundException, join fails
- Ended room join attempt → DatabaseOperationException
- Participant disconnect → Host count decrements
- Reconnect → Restores via snapshot
- Rapid host page changes → All participants receive latest (ordered)
- Host pause/resume → Banners
- Host ends session → All ENDED
- Participant leaves → Host count decrements, member status left

Record PASS/FAIL/BLOCKED per case.

---

## No Internet Test

Repeat Test A with Internet disabled (airplane mode + Wi-Fi on, or hotspot without mobile data):

- Room creation → PASS (SQLite only)
- Room joining → PASS (LAN TCP)
- LAN connection → PASS (Socket)
- Page synchronization → PASS (broadcast)
- Start/Pause/Resume/Reconnect → PASS
- Local persistence → PASS (SQLite)

Must work using only local network — no PostgreSQL, Supabase, cloud, Internet APIs.

---

## Important Notes

- **Real-device requirement:** Real LAN acceptance requires physical Android devices on same Wi-Fi/hotspot with Internet disabled. Arena sandbox cannot truthfully perform these tests → Must be marked **BLOCKED — Requires physical devices** until actually performed on real devices.
- **PDF Renderer:** Current renderer is real via `pdfx` (Pdfium) — renders actual PDF content, not simulated. Implemented in Phase 3 commit `765af26`.
- **Do NOT claim PASS for manual tests unless actually executed on real devices.**

