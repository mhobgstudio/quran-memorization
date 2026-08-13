# Implementation Plan — Quran Reading & Listening in Hifz Planner

*Concrete, build-ready plan derived from INTEGRATION_IDEAS.md, with verified
data-source choices. Works with the existing page/line/session model and both
memorization directions (1 → 604 and 604 → 1).*

---

## 1. Goals

Turn the top integration modes into a shipped feature set, in dependency order:

1. **Page viewer** — show the actual mushaf content for the planner's page
2. **Unit audio** — play today's lines with loop/repeat, speed control
3. **Session flow** — read → listen → test → mark done (drives progress)
4. **Progress layer** — per-ayah checkboxes + completion map
5. **Depth layer** — translations, reciters, offline cache, review queue

## 2. Architecture

Layered, mirrors the current clean split between `memorization_calc.dart`
(pure logic) and `main.dart` (UI):

```
lib/
  main.dart                  # app entry + navigation
  memorization_calc.dart     # existing planner math (unchanged)
  data/
    quran_text.dart          # loads bundled Uthmani text + page index
    quran_audio.dart         # reciter table + per-ayah URL builder + cache
    progress_store.dart      # Hive: memorized ayahs, review queue, stats
  services/
    audio_player.dart        # just_audio wrapper: play unit, loop, speed
    audio_service_handler.dart  # background playback (audio_service)
  state/
    session_controller.dart  # Riverpod: current page/lines, playback, marks
  screens/
    planner_screen.dart      # existing planner UI (extracted from main.dart)
    page_viewer_screen.dart  # mushaf page + line highlight
    session_screen.dart      # guided read/listen/test flow
    progress_screen.dart     # completion map + stats
```

Rules:
- `data/` and `services/` are pure Dart + platform packages; no widget code.
- All page/line math stays direction-aware via `MemorizationPlan`.
- Downloading/caching happens only in `quran_audio.dart`; UI never knows URLs.

## 3. Data source decisions (verified)

### 3.1 Quran text — Tanzil Uthmani (bundled, offline-first)

| Choice | Value |
|---|---|
| Source | Tanzil.net Uthmani text, CC-BY 3.0 (attribute "Tanzil Project", link tanzil.net) |
| Format | Static text/JSON bundled as app assets (no runtime API needed) |
| Size | ~1–3 MB — negligible in the bundle |
| Why | Canonical verified text, offline, no keys, no rate limits |

### 3.2 Page → ayah mapping (the 604-page model)

| Choice | Value |
|---|---|
| Primary | Tanzil metadata gives each ayah its `page` (1–604), plus surah/ayah/juz |
| Build step | Small script generates `assets/pages.json`: page → [{surah, ayah}] once, committed |
| Alternative | pub.dev `quran` package claims to ship page/surah/ayah mappings — verify at build time; fall back to generated pages.json |
| Why | Page viewer must list exactly what is on page N to highlight the planner's lines |

### 3.3 Audio — EveryAyah CDN (per-ayah MP3, free, no key)

URL pattern (verified): `https://everyayah.com/data/{reciter}_{bitrate}kbps/{SSS}{NNN}.mp3`

| Reciter | Folder | Bitrate |
|---|---|---|
| Alafasy | Alafasy_128kbps | 128 |
| Husary (murattal) | Husary_128kbps | 128 |
| Husary (mujawwad) | Husary_128kbps_Mujawwad | 128 |
| Minshawi (murattal) | Minshawy_Murattal_128kbps | 128 |
| Sudais | Abdurrahmaan_As-Sudais_192kbps | 192 |

Example: Surah 2, ayah 255 → `Alafasy_128kbps/002255.mp3`

- Fallback CDN (same files, continuous ayah index 1–6236):
  `https://cdn.islamic.network/quran/audio/128/ar.alafasy/{n}.mp3`
  (editions: ar.alafasy, ar.husary, ar.minshawi, ar.sudais)
- Audio is free/charitable for non-commercial apps; cache politely (CDN etiquette).
- Full-mushaf size at 128 kbps is ~1.5–2 GB per reciter — therefore cache
  **per page on demand** (≈1.5 MB/page), never preload the whole mushaf.

### 3.4 Translations & word-by-word (optional, Phase 3)

- AlQuran.cloud v1 (`https://api.alquran.cloud/v1`) — no key, no strict rate
  limits; translations per ayah via edition ids (e.g. en.sahih). Cache results.
- Do NOT rely on Quran.com v4 API: it now requires x-auth-token/x-client-id
  headers — avoid the auth dependency for a free app.

## 4. New dependencies (pubspec.yaml)

| Package | Purpose | Phase |
|---|---|---|
| `just_audio` | Core playback: loop, clip segments, speed 0.5×–2×, ConcatenatingAudioSource for consecutive ayahs | 1 |
| `audio_session` | Audio focus, interruption handling (must pair with just_audio) | 1 |
| `audio_service` | Background playback + lock-screen/notification controls | 2 |
| `hive` + `hive_flutter` | Progress persistence (memorized ayahs, queue, stats) | 0 |
| `flutter_riverpod` | State management at feature scale | 0 |
| `http` | AlQuran.cloud calls (translations) | 3 |
| `quran` (verify) | Surah/ayah/page metadata — use if solid, else generated pages.json | 0 |
| `path_provider` | Cache directory for downloaded audio | 2 |

Platform notes:
- **Web**: just_audio works for basic playback; background audio and some
  loop/speed features are browser-limited — acceptable, note in UI.
- **Android/iOS**: audio_service needs manifest/plist config (foreground
  service + audio session), documented per package README.

## 5. Phased implementation

### Phase 0 — Foundation (data + state)
1. Generate `assets/pages.json` (page → ayahs) from Tanzil metadata; commit.
2. Add Uthmani text asset; `quran_text.dart` exposes `Ayah(surah, ayah, text)`
   and `pageAyahs(page)`.
3. `progress_store.dart` on Hive: mark ayah memorized (direction-aware page
   completion = all ayahs on the page checked), review timestamps.
4. `session_controller.dart` on Riverpod: state = {page, direction, lines
   assigned, current line, playback mode, marks}. Widget tests for the
   controller before any new screens.

### Phase 1 — P0 features (page viewer + unit audio)
1. `quran_audio.dart`: reciter table, URL builder, `unitFor(plan)` = the
   ayahs covering today's lines (from page's ayah list × line fractions).
2. `audio_player.dart`: play unit (ConcatAudioSource), loop count 1–10,
   speed 0.5×–2×, next/prev ayah.
3. `page_viewer_screen.dart`: renders page N text with line highlighting
   (15 lines/page); the planner's page stepper and the viewer stay in sync.
4. `session_screen.dart` (lite): Play today's lines → repeat loop →
   mark line done. Wire to planner's assignment.
   **Acceptance**: 10 lines/day → viewer highlights 10 lines; play loops
   them; marking all = page complete in store.

### Phase 2 — P1 features (memorization loop + offline)
1. Echo mode: play line → auto-pause → user repeats → continue.
2. Active-recall test: play first words of ayah, user completes, reveal.
3. Offline cache: download page audio on demand into documents dir;
   playback prefers cache.
4. Split view + shared mastery: read + audio test both required before a
   line is mastered.
5. Completion map screen: 604-cell grid filled from progress store,
   forward or backward.
6. Background playback via audio_service (lock screen controls).

### Phase 3 — P2 features (depth)
1. Translations under each ayah (AlQuran.cloud, cached).
2. Reciter + style switching (table in 3.3).
3. Word-by-word + tajweed color layer (text_uthmani_tajweed data).
4. Self-recording + playback comparison (device mic, local only).
5. Spaced review queue from progress timestamps; unified stats.
6. (Stretch, cloud) AI pronunciation scoring — needs a backend; do last.

## 6. Testing strategy

| Layer | Approach |
|---|---|
| Data | Unit tests: pages.json integrity (604 pages, every ayah 1–6236 present once), pageAyahs() correctness |
| Audio | Unit tests: URL builder per reciter; mock downloader; loop/speed state |
| State | Widget tests on session_controller: mark-all-completes-page in both directions |
| UI | Widget tests: viewer highlights N lines; session flow marks progress; existing planner tests stay green |
| E2E | Manual: web build served locally; real audio on one mobile device |

Each phase ends green with: `flutter analyze` + `flutter test` + manual smoke.

## 7. Risks & decisions

1. **Quran.com v4 API** — avoid (auth headers required). Use Tanzil + EveryAyah.
2. **Audio licensing** — EveryAyah/Islamic Network audio is free/charitable;
   keep attribution in-app (About screen) and cache politely.
3. **Web audio limits** — background playback impossible on web; loop/speed
   vary by browser. Detect and disable gracefully.
4. **Bundle size** — text is tiny; keep audio out of the bundle (download on
   demand, ≈1.5 MB per page).
5. **`quran` package viability** — verify its page mapping in Phase 0; the
   Tanzil-generated pages.json is the guaranteed fallback.
6. **Tajweed coloring** — needs text_uthmani_tajweed data + a renderer;
   schedule last, isolate behind the word-renderer abstraction.

## 8. Definition of done (this plan)

- Page viewer shows the exact mushaf page and highlights the planner's daily
  lines in both directions.
- Today's unit plays with loop/repeat and speed; echo and active-recall test
  work; audio caches offline.
- Per-ayah checkboxes persist; completion map fills forward or backward;
  page completion feeds back into the planner's current-page field.
- Translations + multi-reciter switching + recording available; attribution
  screen present.
- All phases green on analyze + tests; README updated per feature.
