# Integrating the Quran into Hifz Planner — Reading & Listening

*A deep analysis of every practical way the Quran (text and audio) can be
integrated into the app, tied to the planner's existing page/line/session model.*

## 0. The study-unit principle

Hifz Planner already thinks in three units:

- **Pages** — 604-page Madani mushaf
- **Lines** — 15 lines per page
- **Sessions** — study days, derived from pages/day (or lines/day) and rest days

Every integration below should bind to these units. "Today's assignment"
(pagesPerDay × 15 lines) should be, simultaneously: a **reading target**, an
**audio loop**, and a **test scope**. That binding is what turns a calculator
into a hifz coach, and it works identically in forward mode (1 → 604) and the
new backward mode (604 → 1).

---

## Part A — READING (text/mushaf) — 15 ways

1. **Madani mushaf page viewer.** Render the actual mushaf page (604 pages).
   The planner page IS the displayed page — the visual anchor of the app.

2. **Line-accurate display with per-line highlighting.** 15 lines per page;
   highlight exactly the lines assigned today. The planner says 10 lines/day →
   the reader highlights 10 lines.

3. **Ayah-level display and index.** Tap any line to expand its ayahs. Jump
   lists by surah, juz (30 ajza), and page.

4. **Per-ayah memorization checkboxes.** Micro-progress inside a page. A page
   counts as memorized only when all its ayahs are checked (feeds the
   completion map in 14).

5. **Translation layer.** Per-ayah meaning (English, French, etc.), toggled
   on/off under the Arabic — aids comprehension-based memorization.

6. **Tafsir on tap.** Short commentary per ayah, for the "understand before you
   memorize" method.

7. **Tajweed color-coding.** Colored rule markers (madd, qalqalah, ghunnah)
   rendered over the text — teaches correct recitation while reading.

8. **Word-by-word breakdown + transliteration.** Tap a word: its meaning and
   transliteration. Lowers the entry barrier for non-Arabic speakers.

9. **Full-text search.** Find any word or ayah instantly and jump to its page
   (ties back into the planner's page model).

10. **Bookmarks, notes, highlights.** Mark hard passages, annotate them, and
    revisit. Exportable later.

11. **Copy/share ayah.** Share an ayah as text or a stylized image card.

12. **Reading-mode sessions (tilaawah).** A mode separate from memorization:
    daily pages-read target, reading streaks, time spent reading. Reading and
    memorization progress stay independent.

13. **Text self-test modes.** Gap-fill (blank a word and recall it), jumbled-
    line ordering, first-word prompts to complete an ayah from memory.

14. **Completion map.** A visual 604-cell grid (or 30-juz strip) showing
    memorized pages — fills forward in forward mode, backward in backward mode.

15. **Script and reading settings.** Uthmani vs Indo-Pak script, adjustable
    font size, night-friendly mushaf styling.

---

## Part B — LISTENING (audio) — 18 ways

1. **Ayah audio on tap.** Tap any ayah → plays just that ayah.

2. **Unit playback.** Plays today's lines (or the whole current page) as one
   continuous track — the memorization unit defined by the planner.

3. **Loop and repeat counts.** Loop a line or ayah N times (1–10). The
   workhorse of audio memorization.

4. **Playback speed.** 0.5×–2×; ~0.75× is ideal for repeat-after practice.

5. **Reciter selection.** Alafasy, Husary, Minshawi, Sudais, Al-Ajmi, Ghamadi,
   and others — reciter choice strongly affects recall for many huffaz.

6. **Style: murattal vs mujawwad.** Tarteel (steady) or tajweed-emphasized
   recitation for the same ayah.

7. **Listen-and-repeat (echo) mode.** Plays a segment, auto-pauses, the user
   repeats aloud, taps to continue. The classic memorization loop.

8. **Blanked listening.** Audio plays while the text is hidden; text reveals
   after playback — ear-first memorization.

9. **Karaoke word highlighting.** Audio + text in sync, the current word
   highlighted — reading while listening builds strong visual-audio memory.

10. **Active-recall audio test.** Plays only the opening words of an ayah; the
    user completes it aloud; reveal to check.

11. **Segment scoping.** Select an ayah range or line range to loop — feeds
    modes 3, 7, 8, and 10.

12. **Background playback + sleep timer.** Keep listening with the app closed;
    auto-stop after a chosen duration (very common for hifz review).

13. **Offline audio.** Cache downloaded audio per page or juz for offline use
    (requires storage management and a download UI).

14. **Dictation.** Play audio, user types the ayah (Arabic or transliteration),
    auto-checked.

15. **Self-recording and comparison.** Record your own recitation and play it
    back side-by-side with the reciter.

16. **Pronunciation feedback (AI, cloud).** Score the recording against the
    reference recitation (optional — needs a speech model and a backend; see
    D6).

17. **Listening stats and goals.** Minutes listened, listening streaks, daily
    listening target — listening becomes a first-class habit.

18. **Audio-first session mode.** A whole session built around the ear: listen
    → echo → blanked listen → active-recall test (combines 7, 8, 10). For
    learners who memorize by hearing before reading.

---

## Part C — COMBINED reading + listening — 8 ways

1. **Split view.** Mushaf page on top, audio player pinned at the bottom of
   the same screen.

2. **Session templates.** One-tap "today's session": read the assigned lines →
   listen twice → repeat after → self-record → gap-test → mark done. The whole
   flow is driven by the planner's daily assignment.

3. **Position sync.** Reading position and audio position stay in sync; jump
   from either side.

4. **Shared mastery.** A line is "mastered" only when it passes BOTH a reading
   check and an audio test; a page completes only then.

5. **Spaced review queue.** A review schedule of older pages mixing reading
   recall and listening recall (e.g., 1 page daily from 7 days ago).

6. **Unified stats.** Reading minutes + listening minutes merge into one study
   diary with streaks, totals, and a weekly rhythm chart.

7. **Daily reminders.** "Your 10 lines await" notification with Read and
   Listen shortcuts straight into today's session.

8. **Progress sharing.** Certificate-style share cards — "Page 300 of 604 ·
   memorizing backward" — great for motivation and accountability groups.

---

## Part D — Technical foundations (what each integration rests on)

1. **Quran text data.** Bundle ayah-level Uthmani text (Tanzil/EveryAyah JSON,
   roughly 1–3 MB) as app assets. Page→ayah boundaries are standard metadata,
   so the existing 604-page model maps directly.

2. **Audio sources.** Per-ayah MP3 CDNs (e.g. EveryAyah / AlQuran.cloud CDN)
   streamed and cached locally. Most well-known reciters are freely
   redistributable for non-commercial use; verify licensing per reciter.

3. **Local persistence.** Hive / Isar / sqflite for progress (memorized lines,
   review queue, stats); downloaded audio in the app documents directory.

4. **State management.** The app currently uses plain setState; a feature of
   this scale justifies Provider or Riverpod.

5. **Background audio.** Platform work: Android foreground service + audio
   focus; iOS audio session; web plays audio but background playback is
   limited by browser policy.

6. **AI speech scoring (optional).** Recording comparison needs a cloud
   backend (e.g., Whisper-based alignment). Consider privacy and per-user cost;
   this is the only item that is not purely local.

---

## Part E — Prioritized roadmap

**P0 — build first (biggest value, lowest effort)**
- A1 mushaf page viewer (the visual anchor)
- B2 unit playback + B3 loop/repeat (the audio workhorse for "today's lines")
- C2-lite: a Session button that plays today's assignment

**P1 — core memorization experience**
- A2 line highlighting, A4 ayah checkboxes, A14 completion map
- B7 echo mode, B10 active recall, B13 offline caching
- C1 split view, C4 shared mastery

**P2 — depth**
- A5 translation, A6 tafsir, A7 tajweed, A8 word-by-word, A9 search
- B5 reciters, B6 styles, B15 self-recording, B16 AI feedback
- C5 spaced review, C6 unified stats

---

## Bottom line

**15 reading + 18 listening + 8 combined = 41 concrete integration modes**
(plus 6 technical foundations). They are additive: each one plugs into the
planner's existing page/line/session model and works in both memorization
directions. The first five to build — A1 page viewer, B2 unit playback, B3
loop/repeat, A4 ayah checkboxes, and a C2 session template — together convert
Hifz Planner from a finish-date calculator into a complete hifz coach.
