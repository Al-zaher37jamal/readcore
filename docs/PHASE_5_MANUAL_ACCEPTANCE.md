# Phase 5 — Manual Acceptance Testing — Real-Device Instructions (Fixed Version)

**Branch:** `arena/01a0bf89-readmwsh`
**Fix Commit:** Phase 5: Fix LAN host discovery, room state, and Arabic localization
**Environment Required:** 2-3 physical Android devices (or Windows + Android), same Wi-Fi OR mobile hotspot, **Internet disabled** during test, **Host must display real LAN IP e.g. 192.168.0.73:40404 NOT 127.0.0.1:40404**
**PDF:** Real local PDF imported via Phase 2 pipeline, rendered via `pdfx` real renderer

> **Arena Sandbox Limitation:** Arena E2B sandbox has no physical devices, no Wi-Fi/hotspot, no Flutter SDK (`flutter: command not found`). Therefore real-device tests cannot be executed in sandbox and must be marked **BLOCKED — Requires physical devices**. Automated loopback tests cover same logic.

---

## Prerequisites

1. **Devices:**
   - Device A: Host (Android phone)
   - Device B: Participant 1
   - Device C: Participant 2 (for Test D 3-device)
   - All have ReadMesh installed via `flutter run` or APK

2. **Network — No Internet Required:**
   - **Option 1 Same Wi-Fi:** All devices same router SSID, AP isolation OFF, Mobile Data OFF, Internet OFF (airplane mode + Wi-Fi ON)
   - **Option 2 Hotspot (Recommended for No Internet):** Device A enables Hotspot (Settings > Hotspot), Devices B,C connect to A SSID, Mobile Data OFF, Internet OFF, Wi-Fi/Hotspot ON. Host IP typically `192.168.43.1` or `192.168.0.x`
   - **Important:** After fix, Host must show `192.168.x.x:40404` or `10.x.x.x:40404` or `172.16-31.x.x:40404`, NOT `127.0.0.1:40404`. The helper `getLocalLanIPv4()` excludes loopback and prefers 192.168 > 10 > 172.16-31.

3. **App Prep:**
   - Each device: Library > Import Sample PDF (or real PDF) — creates book at `books/<id>.pdf`
   - Verify real PDF renders in Library > Read Now (solo) — actual text/images via pdfx, not simulated
   - First launch language should be Arabic RTL by default (app bar title Arabic, bottom nav Arabic). Toggle via language icon top bar to English if needed, persisted via KVS.

4. **Find Host LAN IP (Fixed):**
   - Host: After creating room, Room Detail top card shows `LAN Host: 192.168.x.x:40404` (example `192.168.0.73:40404`) and `N متصل` / `N connected` — use this IP in Participant join dialog. Should NOT show `127.0.0.1:40404` anymore.
   - Join dialog: No default `127.0.0.1`, empty field with hint `Enter Host IP shown on Host device` / Arabic, must enter Host displayed IP, validates IPv4, shows friendly message if invalid: "Room not found. Please check the room code and Host IP." / Arabic "الغرفة غير موجودة. تحقق من رمز الغرفة وعنوان المضيف."

---

## Test A — Phone A Host + Phone B Participant Same Wi-Fi or Hotspot, Internet OFF, Real IP

**Goal:** Prove Host displays real LAN IP, Participant joins via that IP, Connected=1, Host Page5→Participant Page5, Host Page12→Participant Page12, works without Internet.

**Steps:**

1. **جهاز A (Host) ينشئ الغرفة:**
   - Open ReadMesh (Arabic default) > Library > Import Sample PDF 20 pages
   - Rooms > Create Room > Title "Real PDF Test" > Select book > Create
   - Record room code `RM-XXXX` (e.g., `RM-4821`) and Host LAN IP:Port `192.168.0.73:40404` (must be real, not 127.0.0.1)
   - Verify top card: `رمز الغرفة: RM-XXXX`, `المضيف في الشبكة: 192.168.0.73:40404`, `0 متصل` initially

2. **جهاز B (Participant) ينضم عبر نفس Wi-Fi/Hotspot:**
   - Connect same Wi-Fi/hotspot as Host, ensure Mobile Data OFF, Internet OFF
   - Rooms > Join icon > Enter Room Code `RM-XXXX` + Host IP `192.168.0.73` (from Host display) > Join
   - Should NOT default to 127.0.0.1, must enter real IP
   - Verify success, Room Detail shows `LAN: Connected` / Arabic `الشبكة: متصل` green dot
   - Host should now show `1 متصل` / `1 connected` — consistent with Participants list showing 1 active participant

3. **كلا الجهازين يفتحان نفس PDF الحقيقي:**
   - Host: Room Detail > Read as Host → real PDF page 1
   - Participant: Read as Participant → `Synced: Page 1` / Arabic `متزامن: صفحة 1 من 20`, next/prev disabled, green sync icon, real PDF page 1

4. **Host يبدأ الجلسة إذا created:**
   - Host Start → broadcastSessionStarted → active, Participant receives active

5. **Host ينتقل إلى page 5:**
   - Host Next 4 or Jump to Page 5 → saveProgress + broadcastPageChange(5)
   - Expected Host real PDF page 5

6. **Participant يجب أن ينتقل تلقائيًا إلى page 5:**
   - Participant pageStream receives 5 → setState + saveProgress → PdfPageView jumpToPage(5) → real PDF page 5, bottom `Synced: Page 5`, SQLite reading_progress currentPage 5

7. **Host ينتقل إلى page 12:**
   - Host Jump 12 → broadcast, Participant auto page 12 real content

**PASS Criteria:**
- Host displays `192.168.x.x:40404` NOT `127.0.0.1:40404`
- Join does NOT default to 127.0.0.1, uses Host displayed IP
- Participant joins successfully via real IP without Internet
- Connected count: 0→0, 1 active →1 connected (consistent)
- Page sync 5→12 works real PDF
- Works with Mobile Data OFF, Internet OFF, Wi-Fi/Hotspot ON

**FAIL Criteria:**
- Host still shows 127.0.0.1:40404 → FAIL, IP discovery not fixed
- Join defaults 127.0.0.1 → FAIL
- Connected 0 but Participants active → FAIL, count inconsistency
- Participant cannot join via real IP → FAIL

---

## Test B — Pause/Resume/End (Real Device)

**Goal:** Verify lifecycle and participant status after End.

1. From Test A at page 12
2. Host Pause → Participant yellow banner "Reading Session Paused by Host" / Arabic "تم إيقاف جلسة القراءة مؤقتًا بواسطة المضيف", status PAUSED
3. Host Resume → banner disappears ACTIVE
4. Host End Room → broadcastSessionEnded → stops beacon → stops server → Host count 0, Participants list shows left not active, Host shows "This session has ended." / Arabic "انتهت هذه الجلسة."
5. Participant should receive ended → grey banner "Reading Session Ended by Host" / Arabic "تم إنهاء جلسة القراءة بواسطة المضيف", status ENDED, member status left, disconnected state, reading prevented (blocked UI with history note), cannot open book (button disabled or shows history only message)

**PASS Criteria:**
- Pause/Resume propagate
- End: Host ENDED, Participant ENDED not active, connected removed, reading prevented, count 0, history only

**FAIL if:** Participant still active after End, or can still read, or count not 0

---

## Test C — Disconnect/Reconnect State Snapshot Correct Page

**Goal:** Participant disconnects, Host moves, Participant reconnects receives latest via state_snapshot.

1. Host page 12, Participant synced 12
2. Disable Wi-Fi on Participant → Host count 1→0, Participant shows Disconnected + Reconnect button / Arabic "غير متصل" + "إعادة الاتصال"
3. Host changes to 18 → broadcast (no Participant)
4. Enable Wi-Fi Participant → auto-reconnect Timer 2s or tap Reconnect → Socket.connect(lastIP,lastPort) → join → Host sends stateSnapshot with currentPage 18
5. Participant should receive snapshot → pageStream 18 → real PDF page 18, Synced Page 18, SQLite currentPage 18

**PASS Criteria:** Reconnect restores latest authoritative page via snapshot, persistence preserved, works without Internet

---

## Test D — Host+Participant1+Participant2 Both Follow (3-Device)

**Goal:** 1 Host + 2 Participants minimum, both follow, disconnect one continues.

1. Host creates room, B and C join same RM-XXXX + Host IP (real), both Connected, Host shows 2 connected
2. Host page 5 → B and C both auto page 5 real content
3. Disconnect B (Wi-Fi OFF) → Host count 2→1, C continues normally, Host page 8 → C shows page 8
4. Reconnect B → receives latest page 8
5. Host ends → all ENDED, no active, count 0, history only

**PASS Criteria:** Broadcast reaches all via _clients map, count accurate, remaining continues, reconnected receives latest, each separate reading_progress row, works without Internet

---

## Edge Cases

- **Invalid room code:** Rooms > Join > Enter invalid code e.g., RM-9999 + valid IP → Should show friendly "Room not found. Please check the room code and Host IP." / Arabic "الغرفة غير موجودة. تحقق من رمز الغرفة وعنوان المضيف." NOT technical exception
- **Ended room join:** Try join ended room RM-5890 → Should show "Cannot join an ended room. It is history only." / Arabic "لا يمكن الانضمام إلى غرفة منتهية. متاحة كسجل فقط." and room list shows ENDED history only not joinable
- **Invalid IP:** Join dialog empty IP or invalid like "999.999.999.999" → Should show "Invalid Host IP. Please enter a valid LAN IP like 192.168.1.50." / Arabic
- **Duplicate book:** Library > Import same PDF twice → Should show friendly dialog "This book is already in your library." with Open Book/OK / Arabic "هذا الكتاب موجود بالفعل في مكتبتك." with "فتح الكتاب"/"موافق", no stack
- **Language toggle:** AppBar language icon → dialog Choose Language Arabic/English, select Arabic → RTL, all UI Arabic, icons alignment RTL, dialogs bottom nav Arabic, persisted, restart app still Arabic. Select English → LTR English.
- **RTL:** When Arabic, Directionality RTL, Room Code label RTL, Participants RTL, Host Controls RTL, bottom nav RTL

---

## No Internet Test

Repeat Test A-D with Internet disabled (airplane mode + Wi-Fi ON, or hotspot without mobile data):

- Room creation → PASS (SQLite only)
- Room joining via real LAN IP → PASS (TCP 40404)
- LAN connection → PASS (Socket)
- Page sync → PASS (broadcast)
- Start/Pause/Resume/End/Reconnect → PASS
- Persistence → PASS (SQLite)
- Language toggle → PASS (KVS local)

Must work using only local network — no PostgreSQL, Supabase, cloud, Internet APIs, no 127.0.0.1 for remote.

---

## Important Notes

- **Real-device requirement:** Real LAN acceptance requires physical Android devices on same Wi-Fi/hotspot with Internet disabled. Arena sandbox cannot truthfully perform these tests → Must be marked BLOCKED — Requires physical devices until actually performed.
- **PDF Renderer:** Real via pdfx (Pdfium) — renders actual PDF content, not simulated. Implemented Phase 3.
- **Do NOT claim PASS for manual tests unless actually executed on real devices.**
- **After fix, expected real-device results:**
  - Host displays 192.168.x.x:40404 (example 192.168.0.73:40404)
  - Join uses Host displayed IP, not 127.0.0.1
  - Connected count consistent 0→0,1→1,2→2
  - Participant status after End becomes ended/left not active, reading prevented
  - Old ENDED rooms history only
  - Duplicate friendly Arabic/English
  - Arabic default RTL, toggle persisted
  - All hard-coded strings localized, RTL
  - Works without Internet

---

## Checklist for Real-Device Execution

- [ ] Device A Host shows real LAN IP 192.168.x.x:40404 NOT 127.0.0.1:40404
- [ ] Device B joins via real IP, Connected=1
- [ ] Page sync 5→12 works real PDF without Internet
- [ ] Pause/Resume/End propagate, Participant after End not active, reading blocked
- [ ] Disconnect/Reconnect snapshot restores correct page
- [ ] Host+2 Participants both follow, disconnect one continues, reconnect receives latest
- [ ] No Internet (Mobile Data OFF, Internet OFF, Wi-Fi/Hotspot ON) works
- [ ] Ended rooms history only not joinable
- [ ] Duplicate friendly dialog Arabic/English Open Book/OK
- [ ] Arabic default RTL first launch, toggle Arabic/English persisted, RTL icons alignment dialogs bottom nav
- [ ] Room not found friendly messages Arabic/English
- [ ] All hard-coded strings localized
