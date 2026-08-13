import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/mushaf_page.dart';
import '../data/quran_audio.dart';
import '../data/quran_text.dart';
import '../data/quran_translation.dart';
import '../memorization_calc.dart' show MemorizationDirection;
import '../services/audio_player.dart';
import '../services/audio_unit_controller.dart';

/// Displays one page of the mushaf exactly as printed: a header band with the
/// surah name, juz and page number, the 15 justified Uthmani lines, ayah-end
/// ornaments, and today's assigned lines highlighted (direction-aware).
///
/// The audio bar plays exactly the ayahs of today's highlighted lines with
/// repeat ×1/×3/×5/∞. [mushaf] and [audio] may be injected in tests.
class PageViewerScreen extends StatefulWidget {
  const PageViewerScreen({
    super.key,
    required this.page,
    required this.linesPerDay,
    this.direction = MemorizationDirection.forward,
    this.mushaf,
    this.audio,
    this.unit,
    this.reviewDays = 0,
    this.quran,
    this.translation,
  });

  /// Initial page to show (1..604).
  final int page;

  /// Lines memorized per day (the planner's daily rate, in line units).
  final double linesPerDay;

  /// Which end of the mushaf the memorization is progressing from.
  final MemorizationDirection direction;

  /// Pre-loaded mushaf layout; when null it is loaded from the asset.
  final MushafData? mushaf;

  /// Audio backend; when null a just_audio player is created (only used
  /// when [unit] is null).
  final QuranAudio? audio;

  /// Shared app-level audio unit; when provided, playback state lives here so
  /// today's unit keeps playing after this screen is closed (persistent mini
  /// player on the planner).
  final AudioUnitController? unit;

  /// Nightly review window in days (0 = off). When > 0 the viewer opens at
  /// the start of the last [reviewDays] days of memorized lines and queues
  /// them all for listening, instead of just today's portion.
  final int reviewDays;

  /// Pre-loaded Quran text for the meanings view; when null it is loaded
  /// lazily the first time meanings are toggled on.
  final QuranText? quran;

  /// Pre-loaded English translation for the meanings view; when null it is
  /// loaded lazily the first time meanings are toggled on.
  final QuranTranslation? translation;

  @override
  State<PageViewerScreen> createState() => _PageViewerScreenState();
}

class _PageViewerScreenState extends State<PageViewerScreen> {
  static const List<int> _repeatOptions = [1, 3, 5, 0];
  // 0 means "loop until stopped" (infinite).

  /// The Uthmanic Hafs calligraphy font of the printed Madani mushaf.
  static const String _fontFamily = 'UthmanicHafs';

  late int _page;
  late final QuranAudio _audio;
  MushafData? _mushaf;
  bool _loading = true;
  String? _error;

  bool _playing = false;
  String? _audioError;
  int _repeat = 3;
  Reciter _reciter = Reciter.alafasy;
  double _speed = 1.0;
  bool _echo = false;
  int _ayahIndex = 0;
  bool _started = false;
  StreamSubscription<void>? _audioSub;

  /// Meanings view (translation under each ayah) toggle state.
  bool _showTranslation = false;
  bool _translationLoading = false;
  String? _translationError;
  QuranText? _quran;
  QuranTranslation? _translation;

  @override
  void initState() {
    super.initState();
    _quran = widget.quran;
    _translation = widget.translation;
    _page = widget.page.clamp(1, MushafData.totalPages).toInt();
    final unit = widget.unit;
    if (unit != null) {
      // Bind to the shared unit: inherit its last-used settings and mirror
      // its playing/error state. The unit owns the audio and outlives this
      // screen so playback continues after closing the viewer.
      _repeat = unit.repeat;
      _reciter = unit.reciter;
      _speed = unit.speed;
      unit.addListener(_onUnitChanged);
    } else {
      _audio = widget.audio ?? JustQuranAudio();
      _audioSub = _audio.onCompleted.listen((_) {
        if (!mounted) return;
        setState(() {
          _playing = false;
          if (_echo) {
            final total = _todayUrls().length;
            if (total > 0) _ayahIndex = (_ayahIndex + 1) % total;
          }
        });
      });
    }
    _load();
  }

  void _onUnitChanged() {
    if (mounted) setState(() {});
  }

  /// Effective playback state: the shared unit's when bound, local otherwise.
  bool get _isPlaying => widget.unit?.playing ?? _playing;

  String? get _playError => widget.unit?.error ?? _audioError;

  @override
  void dispose() {
    final unit = widget.unit;
    if (unit != null) {
      unit.removeListener(_onUnitChanged);
    } else {
      _audioSub?.cancel();
      _audio.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final injected = widget.mushaf;
    if (injected != null) {
      _mushaf = injected;
      _loading = false;
      _jumpToReviewStart();
      return;
    }
    try {
      final mushaf = await MushafData.load();
      if (!mounted) return;
      setState(() {
        _mushaf = mushaf;
        _loading = false;
        _jumpToReviewStart();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the mushaf layout: $e';
        _loading = false;
      });
    }
  }

  /// In review mode the viewer opens where the window begins (the oldest of
  /// the last N days) so the user can follow along as the queue plays.
  void _jumpToReviewStart() {
    if (widget.reviewDays <= 0 || _mushaf == null) return;
    final segments = _mushaf!.reviewSegments(
      currentPage: widget.page,
      linesPerDay: widget.linesPerDay,
      direction: widget.direction,
      reviewDays: widget.reviewDays,
    );
    if (segments.isNotEmpty) {
      _page = segments.first.page;
    }
  }

  MushafPage get _currentPage => _mushaf!.page(_page);

  /// Number of text lines assigned for today (0..lines on the page). In
  /// review mode this is the window's share of the *displayed* page (0 when
  /// the page falls outside the window).
  int _todayLineCount() {
    if (widget.reviewDays > 0) {
      for (final seg in _reviewSegments()) {
        if (seg.page == _page) return seg.lineCount;
      }
      return 0;
    }
    final lines = _currentPage.textLines.length;
    if (widget.linesPerDay <= 0) return 0;
    return widget.linesPerDay.round().clamp(0, lines);
  }

  /// The nightly review window (oldest-first). Empty when review mode is off.
  List<ReviewSegment> _reviewSegments() {
    final mushaf = _mushaf;
    if (mushaf == null || widget.reviewDays <= 0) return const [];
    return mushaf.reviewSegments(
      currentPage: widget.page,
      linesPerDay: widget.linesPerDay,
      direction: widget.direction,
      reviewDays: widget.reviewDays,
    );
  }

  /// Row indices (within [page].lines) of today's highlighted text lines.
  /// In review mode the window's lines are highlighted instead.
  Set<int> _highlightedRowIndices(MushafPage page) {
    if (widget.reviewDays > 0) {
      for (final seg in _reviewSegments()) {
        if (seg.page == page.page) return _rowsForSegment(page, seg);
      }
      return const {};
    }
    final n = _todayLineCount();
    if (n <= 0) return const {};
    final texts = page.textLines;
    final total = texts.length;
    final start = widget.direction == MemorizationDirection.backward
        ? total - n
        : 0;
    return _rowsInRange(page, start, n);
  }

  Set<int> _rowsForSegment(MushafPage page, ReviewSegment seg) =>
      _rowsInRange(page, seg.startLine, seg.lineCount);

  /// Maps [start]..start+[count]-1 text-line ordinals to row indices in the
  /// page's [page.lines] list (skipping header/basmala/blank rows).
  Set<int> _rowsInRange(MushafPage page, int start, int count) {
    final result = <int>{};
    var ord = 0;
    for (var i = 0; i < page.lines.length; i++) {
      if (page.lines[i].isText) {
        if (ord >= start && ord < start + count) result.add(i);
        ord++;
      }
    }
    return result;
  }

  List<String> _todayUrls() {
    final lines = widget.reviewDays > 0
        ? _reviewLines()
        : _currentPage.todayLines(
            lineCount: _todayLineCount(),
            direction: widget.direction,
          );
    // Line verse ranges overlap at ayah boundaries (a line ending mid-ayah
    // and the next continuing it both list that ayah), so collapse
    // consecutive duplicates while preserving order.
    final refs = <String>[];
    for (final line in lines) {
      for (final ref in line.ayahRefs) {
        if (refs.isEmpty || refs.last != ref) refs.add(ref);
      }
    }
    return [for (final ref in refs) _ayahUrl(ref)];
  }

  /// Every text line in the review window, oldest-first, across all pages.
  /// Used to build the listening queue (and its ayah count).
  List<MushafLine> _reviewLines() {
    final mushaf = _mushaf;
    if (mushaf == null) return const [];
    final lines = <MushafLine>[];
    for (final seg in _reviewSegments()) {
      final texts = mushaf.page(seg.page).textLines;
      lines.addAll(texts.sublist(seg.startLine, seg.startLine + seg.lineCount));
    }
    return lines;
  }

  String get _speedLabel {
    final s = _speed == _speed.roundToDouble()
        ? _speed.toInt().toString()
        : _speed.toString();
    return '$s×';
  }

  String _ayahUrl(String ref) {
    final parts = ref.split(':');
    return ayahAudioUrl(_reciter, int.parse(parts[0]), int.parse(parts[1]));
  }

  Future<void> _togglePlay() async {
    final unit = widget.unit;
    if (unit != null) {
      if (unit.playing) {
        await unit.pause();
        return;
      }
      final urls = _todayUrls();
      if (urls.isEmpty) return;
      final meta = _mushaf!.surahMeta(_currentPage.surah);
      await unit.play(
        urls: urls,
        label: widget.reviewDays > 0
            ? '${meta.arabicLong} · review (last ${widget.reviewDays} days)'
            : '${meta.arabicLong} · page $_page',
        settings:
            '${_reciter.label} · $_speedLabel · repeat ${_repeat == 0 ? '∞' : '×$_repeat'}${_echo ? ' · echo' : ''}',
        page: _page,
        linesPerDay: widget.linesPerDay,
        direction: widget.direction,
        repeat: _repeat,
        reciter: _reciter,
        speed: _speed,
        echo: _echo,
      );
      return;
    }
    if (_playing) {
      await _audio.pause();
      if (!mounted) return;
      setState(() => _playing = false);
      return;
    }
    final urls = _todayUrls();
    if (urls.isEmpty) return;
    setState(() => _audioError = null);
    try {
      if (_echo) {
        _started = true;
        final i = _ayahIndex % urls.length;
        await _audio.play(urls: [urls[i]], repeat: _echoRepeat);
      } else {
        await _audio.play(urls: urls, repeat: _repeat);
      }
      if (!mounted) return;
      setState(() => _playing = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _audioError = "Couldn't play audio — check your connection.";
      });
    }
  }

  void _goToPage(int delta) => _jumpToPage(_page + delta);

  /// Navigates to an absolute page (clamped to the mushaf), stopping any
  /// playback so the viewer never plays a stale unit on a new page.
  void _jumpToPage(int target) {
    final unit = widget.unit;
    if (unit != null) {
      unit.stop();
    } else {
      _audio.stop();
    }
    setState(() {
      _page = target.clamp(1, MushafData.totalPages).toInt();
      _playing = false;
      _audioError = null;
      _ayahIndex = 0;
      _started = false;
    });
  }

  /// Opens the page-jump dialog: type a page number (1..604) and press Go,
  /// or submit directly from the keyboard.
  Future<void> _openPageJump() async {
    final int? target = await showDialog<int>(
      context: context,
      builder: (_) => _PageJumpDialog(initial: '$_page'),
    );
    if (target != null && mounted) _jumpToPage(target);
  }

  /// Echo-mode repeat count: an infinite loop makes no sense for one-ayah
  /// playback, so it degrades to a single play.
  int get _echoRepeat => _repeat > 0 ? _repeat : 1;

  void _onEchoChanged(bool sel) {
    if (sel == _echo) return;
    final unit = widget.unit;
    setState(() => _echo = sel);
    if (unit != null) {
      unit.setEcho(sel);
    } else if (_playing) {
      _audio.stop();
      _playing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Page $_page'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              _showTranslation ? Icons.menu_book_outlined : Icons.translate,
            ),
            tooltip: _showTranslation
                ? 'Back to the mushaf page'
                : 'Show meanings',
            onPressed: _toggleTranslation,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
            : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final page = _currentPage;
    final highlighted = _highlightedRowIndices(page);
    final today = _todayLineCount();
    final total = page.textLines.length;
    final whole = today >= total;

    return Column(
      children: [
        _topBar(scheme, textTheme),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _todayChip(scheme, textTheme, today, total, whole),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            // Swipe left for the next page, right for the previous one.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v <= -250) {
                  _goToPage(1);
                } else if (v >= 250) {
                  _goToPage(-1);
                }
              },
              child: _showTranslation
                  ? _translationView(context, page, highlighted)
                  : // The printed Madani full-view page is 699×1020
                  // (h/w ≈ 1.4592). Lock the card to that ratio and center
                  // it so it never warps to the screen — it scales, keeping
                  // the mushaf's real shape.
                  Center(
                      child: AspectRatio(
                        aspectRatio: 0.6853,
                        child: _mushafCard(context, page, highlighted),
                      ),
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
          child: _audioBar(scheme, textTheme),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            widget.reviewDays > 0
                ? "Highlighted lines are the last ${widget.reviewDays} days — the audio queues them oldest-first."
                : "Highlighted lines are today's portion — the audio plays exactly those ayahs.",
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  /// Toggles the meanings view. The Quran text and translation are bundled
  /// assets, loaded lazily on first use so startup stays fast; errors are
  /// surfaced inside the panel with a retry.
  Future<void> _toggleTranslation() async {
    if (_showTranslation) {
      setState(() => _showTranslation = false);
      return;
    }
    if (_quran != null && _translation != null) {
      setState(() => _showTranslation = true);
      return;
    }
    setState(() {
      _translationLoading = true;
      _translationError = null;
    });
    try {
      final results = await Future.wait([
        QuranText.load(),
        QuranTranslation.load(),
      ]);
      if (!mounted) return;
      setState(() {
        _quran = results[0] as QuranText;
        _translation = results[1] as QuranTranslation;
        _translationLoading = false;
        _showTranslation = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _translationLoading = false;
        _translationError = 'Could not load meanings: $e';
      });
    }
  }

  /// The meanings view: every ayah on the page, Arabic with the English
  /// translation underneath, today's ayahs highlighted.
  Widget _translationView(
    BuildContext context,
    MushafPage page,
    Set<int> highlighted,
  ) {
    if (_translationLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _translationError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _toggleTranslation,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final quran = _quran;
    final translation = _translation;
    if (quran == null || translation == null) {
      return const SizedBox.shrink();
    }

    // (line index, surah, ayah) in reading order. Line verse ranges overlap
    // at ayah boundaries (a line ending mid-ayah and the next continuing it
    // both list that ayah), so collapse consecutive duplicates.
    final ayahs = <({int line, int surah, int ayah})>[];
    for (var i = 0; i < page.lines.length; i++) {
      for (final ref in page.lines[i].ayahRefs) {
        final parts = ref.split(':');
        final s = int.parse(parts[0]);
        final a = int.parse(parts[1]);
        if (ayahs.isEmpty ||
            ayahs.last.surah != s ||
            ayahs.last.ayah != a) {
          ayahs.add((line: i, surah: s, ayah: a));
        }
      }
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: ayahs.length,
      itemBuilder: (context, index) {
        final entry = ayahs[index];
        final isToday = highlighted.contains(entry.line);
        return _translationAyahCard(
          surah: entry.surah,
          ayah: entry.ayah,
          arabic: quran.ayahAtRef(entry.surah, entry.ayah).text,
          english: translation.translationAt(
            quran.globalIndex(entry.surah, entry.ayah),
          ),
          isToday: isToday,
          dark: dark,
          scheme: scheme,
          textTheme: textTheme,
        );
      },
    );
  }

  /// One ayah in the meanings view: reference badge, the Uthmani Arabic,
  /// and the English meaning beneath. Today's ayahs get the highlight tint.
  Widget _translationAyahCard({
    required int surah,
    required int ayah,
    required String arabic,
    required String english,
    required bool isToday,
    required bool dark,
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    final base = dark ? const Color(0xFF211E1A) : const Color(0xFFFFFDF5);
    return Container(
      key: ValueKey('translation-ayah-$surah-$ayah'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: isToday
            ? scheme.primaryContainer.withValues(alpha: dark ? 0.35 : 0.55)
            : base,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isToday
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.8),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${toArabicIndic(surah)}:${toArabicIndic(ayah)}',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            arabic,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 22,
              height: 1.9,
              color: dark ? const Color(0xFFF0EDE4) : const Color(0xFF231F1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            english,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(ColorScheme scheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous page',
            onPressed: _page > 1 ? () => _goToPage(-1) : null,
          ),
          Tooltip(
            message: 'Jump to page',
            child: InkWell(
              onTap: _openPageJump,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  '$_page / ${MushafData.totalPages}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
            onPressed: _page < MushafData.totalPages
                ? () => _goToPage(1)
                : null,
          ),
          const SizedBox(width: 8),
          Icon(
            widget.direction == MemorizationDirection.backward
                ? Icons.arrow_back
                : Icons.arrow_forward,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _todayChip(
    ColorScheme scheme,
    TextTheme textTheme,
    int today,
    int total,
    bool whole,
  ) {
    final label = widget.reviewDays > 0
        ? (whole
              ? 'Review (last ${widget.reviewDays} days): this whole page'
              : widget.direction == MemorizationDirection.backward
              ? 'Review (last ${widget.reviewDays} days): last $today of $total lines'
              : 'Review (last ${widget.reviewDays} days): first $today of $total lines')
        : whole
        ? "Today's portion: the whole page ($total lines)"
        : widget.direction == MemorizationDirection.backward
        ? "Today's portion: last $today of $total lines"
        : "Today's portion: first $today of $total lines";
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// The printed page: parchment card, header band, 15 evenly spaced rows.
  Widget _mushafCard(
    BuildContext context,
    MushafPage page,
    Set<int> highlighted,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const pad = 12.0;
    final bandHeight = 46.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textColor = dark
            ? const Color(0xFFF0EDE4)
            : const Color(0xFF231F1A);
        final fontSize = _fitFont(
          constraints.maxWidth - pad * 2,
          constraints.maxHeight - pad * 2,
          page,
          bandHeight,
        );

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF211E1A) : const Color(0xFFFFFDF5),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              // The printed page frame: a double rule with ornamental corner
              // flourishes, drawn just inside the card edge.
              Positioned.fill(
                child: CustomPaint(
                  key: const ValueKey('mushaf-frame'),
                  painter: _MushafFramePainter(
                    color: textColor.withValues(alpha: dark ? 0.8 : 0.9),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(pad),
                child: Column(
                  children: [
                    _pageHeaderBand(
                      context,
                      page,
                      fontSize: fontSize * 1.08,
                      color: textColor,
                    ),
                    for (var i = 0; i < page.lines.length; i++)
                      Expanded(
                        child: _lineRow(
                          context,
                          page.lines[i],
                          rowIndex: i,
                          fontSize: fontSize,
                          color: textColor,
                          highlighted: highlighted,
                          isFirstRow: i == 0,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Fits the text so all 15 rows plus the band fill the card without
  /// wrapping: bounded by both the available height and the widest line
  /// (measured with the real font at a reference size, then scaled).
  double _fitFont(
    double width,
    double height,
    MushafPage page,
    double bandHeight,
  ) {
    // The real printed page is dense horizontally and airy vertically;
    // a 1.5 line-height lets the width fit bind so lines fill ~95% of the
    // width and the inter-word gaps stay tight like the printed mushaf.
    const lineHeight = 1.5;
    // Natural width of the widest text line at a reference size of 100,
    // including the minimum inter-word gaps the justification needs.
    var widest100 = 0.0;
    final style = TextStyle(
      fontFamily: _fontFamily,
      fontSize: 100,
      height: 1.0,
    );
    for (final line in page.lines) {
      if (line.type != MushafLineType.text) continue;
      final tokens = _tokenize(line.text);
      if (tokens.isEmpty) continue;
      var w = 0.0;
      for (final t in tokens) {
        w += t.isRosette
            ? _rosetteWidth(t.text, 100)
            : _measureText(t.text, style);
      }
      // 0.10 em minimum gap — the printed Madani mushaf sets words very
      // tight (measured gap ≈ 0.09× word width), so the stretch must stay
      // small; most of the line width is words, not whitespace.
      w += (tokens.length - 1) * 10;
      widest100 = math.max(widest100, w);
    }
    final heightFit = ((height - bandHeight - 16) / (15 * lineHeight)) * 0.96;
    // widest100 is measured at font size 100, so scale back up (x100) and
    // fill the whole line: the inter-word stretch stays minimal and lines
    // stay as dense as the printed page. Shorter lines get a little more
    // gap, exactly like the printed mushaf, where sparse lines are airier.
    final widthFit = widest100 > 0 ? (width / widest100) * 100 * 1.0 : 26.0;
    // No small hard cap: let the width fit bind so the text actually fills
    // the line (a low cap left lines ~70% full and spaceBetween stretched
    // the gaps into airy rivers — the printed page is dense).
    return math.max(12.0, math.min(46.0, math.min(heightFit, widthFit)));
  }

  /// The page header of the printed mushaf: an ornamented band whose center
  /// holds the surah name between two rules, with the page number and juz in
  /// small corner medallions.
  /// The page header of the printed mushaf: an ornamented band whose center
  /// holds the surah name in large calligraphy, with the page number and juz
  /// in ornate corner medallions and a fine ornamental ribbon along the top.
  Widget _pageHeaderBand(
    BuildContext context,
    MushafPage page, {
    required double fontSize,
    required Color color,
  }) {
    final meta = _mushaf!.surahMeta(page.surah);
    final cornerStyle = TextStyle(
      fontFamily: _fontFamily,
      fontSize: fontSize * 0.72,
      height: 1.15,
      color: color,
    );
    final rule = BorderSide(color: color.withValues(alpha: 0.55), width: 1.2);
    return Container(
      key: const ValueKey('page-header'),
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        border: Border(top: rule, bottom: rule),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The ornamental ribbon that runs along the top of the printed
          // band, a fine repeat of vertical strokes.
          SizedBox(
            height: fontSize * 0.52,
            width: double.infinity,
            child: CustomPaint(
              painter: _RibbonPainter(
                color: color.withValues(alpha: 0.95),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Page number in a corner medallion (top-left of the page).
              _Medallion(
                size: fontSize * 1.95,
                color: color,
                child: Text(
                  toArabicIndic(page.page),
                  key: const ValueKey('page-header-number'),
                  style: cornerStyle,
                  textDirection: TextDirection.rtl,
                ),
              ),
              const SizedBox(width: 6),
              _Diamond(color: color, size: fontSize * 0.3),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: color.withValues(alpha: 0.45),
                          width: 1,
                        ),
                        right: BorderSide(
                          color: color.withValues(alpha: 0.45),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      meta.arabicLong,
                      key: const ValueKey('page-header-surah'),
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: fontSize * 1.35,
                        height: 1.25,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              _Diamond(color: color, size: fontSize * 0.3),
              const SizedBox(width: 6),
              // Juz in a corner medallion (top-right of the page).
              _Medallion(
                size: fontSize * 1.95,
                color: color,
                child: Text(
                  'الجزء ${toArabicIndic(page.juz)}',
                  key: const ValueKey('page-header-juz'),
                  style: cornerStyle,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lineRow(
    BuildContext context,
    MushafLine line, {
    required int rowIndex,
    required double fontSize,
    required Color color,
    required Set<int> highlighted,
    required bool isFirstRow,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (line.type) {
      case MushafLineType.blank:
        return const SizedBox.shrink();
      case MushafLineType.surahHeader:
        // The page header band covers the first row; later header rows are
        // drawn as ornamented banners, exactly like the printed mushaf.
        if (isFirstRow) return const SizedBox.shrink();
        return _surahBanner(
          line,
          rowIndex: rowIndex,
          fontSize: fontSize * 1.02,
          color: color,
        );
      case MushafLineType.basmala:
        return Align(
          alignment: Alignment.center,
          child: Text(
            line.text,
            textDirection: TextDirection.rtl,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: fontSize,
              height: 1.5,
              color: color,
            ),
          ),
        );
      case MushafLineType.text:
        final hi = highlighted.contains(rowIndex);
        final isBasmala = line.text.trimLeft().startsWith('بِسْمِ');
        return Container(
          key: ValueKey('line-${hi ? 'active' : 'rest'}-$rowIndex'),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: hi
              ? BoxDecoration(
                  color:
                      (dark ? const Color(0xFF9A8A2E) : const Color(0xFFFFE082))
                          .withValues(alpha: dark ? 0.38 : 0.5),
                )
              : null,
          child: isBasmala
              // The basmala of the printed mushaf is a centred, decorative
              // line (its ayah-one mark sits in a small rosette), not a
              // justified full-width line.
              ? Align(
                  alignment: Alignment.center,
                  child: _tokenRow(line.text, fontSize, color),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => _justifiedLine(
                    line.text,
                    fontSize,
                    color,
                    constraints.maxWidth,
                  ),
                ),
        );
    }
  }

  /// Words (and ayah rosettes) of [text] laid out inline in reading order,
  /// at natural width — used for centred lines such as the basmala.
  Widget _tokenRow(String text, double fontSize, Color color) {
    final tokens = _tokenize(text);
    if (tokens.isEmpty) return const SizedBox.shrink();
    final style = TextStyle(
      fontFamily: _fontFamily,
      fontSize: fontSize,
      height: 1.5,
      color: color,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < tokens.length; i++)
          if (tokens[i].isRosette)
            _AyahOrnament(
              key: ValueKey('ayah-ornament-$i'),
              digits: tokens[i].text,
              fontSize: fontSize,
              color: color,
            )
          else
            Text(
              tokens[i].text,
              textDirection: TextDirection.rtl,
              softWrap: false,
              style: style,
            ),
      ],
    );
  }

  /// Splits a mushaf line into word tokens and ayah-rosette tokens, keeping
  /// reading order (a standalone Arabic-Indic digit is the ayah rosette).
  List<_LineToken> _tokenize(String text) {
    final digitRe = RegExp('^[٠-٩]+\$');
    final tokens = <_LineToken>[];
    for (final token in text.split(' ')) {
      final t = token.trim();
      if (t.isEmpty) continue;
      tokens.add(_LineToken(t, isRosette: digitRe.hasMatch(t)));
    }
    return tokens;
  }

  /// Width of an ayah rosette (kept in sync with [_AyahOrnament]).
  double _rosetteWidth(String digits, double fontSize) {
    final height = fontSize * 1.2;
    return math.max(
      height,
      fontSize * (1.05 + 0.42 * (digits.length - 1)),
    );
  }

  double _measureText(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
    )..layout();
    return tp.width;
  }

  /// Letters that never connect to the following letter — a tatweel must
  /// never be placed right after one of these.
  static const _nonConnecting = '\u0627\u0623\u0625\u0622\u0624\u062F\u0630\u0631\u0632\u0648';

  /// True when [ch] connects forward, so a tatweel can follow it.
  static bool _connectsToNext(String ch) => !_nonConnecting.contains(ch);

  /// Indices i (1..len-1) where a tatweel can be inserted: directly after a
  /// connecting letter, so the word keeps its natural final letter form and
  /// the stretch happens on genuine letter connections, like the printed
  /// mushaf's calligraphy.
  static List<int> _kashidaPositions(String word) {
    final positions = <int>[];
    for (var i = 1; i < word.length; i++) {
      if (_connectsToNext(word[i - 1])) positions.add(i);
    }
    return positions;
  }

  /// Rebuilds [word] with `marks[i]` tatweels inserted after character i-1.
  static String _withTatweels(String word, Map<int, int> marks) {
    final buf = StringBuffer();
    for (var i = 0; i < word.length; i++) {
      buf.write(word[i]);
      final count = marks[i + 1] ?? 0;
      for (var k = 0; k < count; k++) {
        buf.write('\u0640'); // tatweel
      }
    }
    return buf.toString();
  }

  /// Greedily inserts tatweels into [word] (one at a time, measuring each
  /// insertion with the real font, reverting any that gains no width) until
  /// [budgetPx] of extra width has been added. Returns the stretched word.
  String _stretchToFill(
    String word,
    double budgetPx,
    double Function(String) measure,
  ) {
    if (budgetPx <= 0) return word;
    final positions = _kashidaPositions(word);
    if (positions.isEmpty) return word;
    final marks = <int, int>{};
    var width = measure(word);
    var used = 0.0;
    var pass = 0;
    while (used < budgetPx && pass < 6) {
      var addedThisPass = false;
      for (final p in positions) {
        if (used >= budgetPx) break;
        marks[p] = (marks[p] ?? 0) + 1;
        final w = measure(_withTatweels(word, marks));
        final gain = w - width;
        // Never overshoot the budget — a single overshooting tatweel per
        // word would overflow the line and collapse the word gaps.
        if (gain > 0 && used + gain <= budgetPx) {
          width = w;
          used += gain;
          addedThisPass = true;
        } else {
          marks[p] = marks[p]! - 1; // no room there; revert
        }
      }
      if (!addedThisPass) break;
      pass++;
    }
    return _withTatweels(word, marks);
  }

  /// Renders one full-width mushaf line justified like the printed page:
  /// the inter-word gaps stay tight (≈0.10 em) and most of the leftover
  /// width is absorbed by kashida — tatweel letter-stretching inside the
  /// words — exactly how the Madani calligrapher filled sparse lines. The
  /// small residual after stretching is shared between the word groups by
  /// spaceBetween, so no manual gap arithmetic can drift from the glyphs.
  /// Words run right-to-left; each ayah rosette is glued to its word.
  Widget _justifiedLine(
    String text,
    double fontSize,
    Color color,
    double availableWidth,
  ) {
    final tokens = _tokenize(text);
    if (tokens.isEmpty) return const SizedBox.shrink();
    final style = TextStyle(
      fontFamily: _fontFamily,
      fontSize: fontSize,
      height: 1.5,
      color: color,
    );
    double measure(String s) => _measureText(s, style);

    // Group consecutive tokens so a rosette sticks to the word it follows;
    // track each word's natural width for the kashida budget.
    final words = <({String word, double w, String? rosette, double rw})>[];
    double natural = 0;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.isRosette) {
        if (words.isEmpty) continue;
        final rw = _rosetteWidth(t.text, fontSize);
        natural += rw;
        words[words.length - 1] = (
          word: words.last.word,
          w: words.last.w,
          rosette: t.text,
          rw: rw,
        );
      } else {
        final ww = measure(t.text);
        natural += ww;
        words.add((word: t.text, w: ww, rosette: null, rw: 0));
      }
    }
    if (words.isEmpty) return const SizedBox.shrink();

    // Tight minimum gap (0.10 em) like the printed page; the rest of the
    // line width is converted to kashida, keeping the gaps near this floor.
    const minGapEm = 0.10;
    final gapCount = words.length - 1;
    final minGaps = gapCount * minGapEm * fontSize;
    var leftover = availableWidth - (natural + minGaps);

    if (leftover > 0) {
      // Give most of the leftover to letter-stretching, weighted by word
      // width so longer words carry more of the stretch. Reserve ~3% of the
      // line for the small render-vs-measurement glyph drift so a fully
      // stretched line never overflows its box.
      final wordSum = words.fold<double>(0, (s, g) => s + g.w);
      if (wordSum > 0) {
        final kashidaBudget =
            math.max(0.0, leftover - availableWidth * 0.03) * 0.92;
        var stretched = 0.0;
        final updated = <({String word, double w, String? rosette, double rw})>[];
        for (final g in words) {
          final share = g.w / wordSum;
          final stretchedWord = _stretchToFill(g.word, kashidaBudget * share, measure);
          final ww = measure(stretchedWord);
          stretched += ww - g.w;
          updated.add((word: stretchedWord, w: ww, rosette: g.rosette, rw: g.rw));
        }
        words
          ..clear()
          ..addAll(updated);
        // Residual (and any kashida that couldn't be inserted) stays in the
        // word gaps via spaceBetween below.
        leftover = availableWidth - (natural + stretched + minGaps);
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.max,
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final g in words)
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                g.word,
                textDirection: TextDirection.rtl,
                softWrap: false,
                style: style,
              ),
              if (g.rosette != null)
                _AyahOrnament(
                  key: ValueKey('ayah-ornament'),
                  digits: g.rosette!,
                  fontSize: fontSize,
                  color: color,
                ),
            ],
          ),
      ],
    );
  }

  /// Mid-page surah name in an ornamented band (used when a new surah starts
  /// below the first line, e.g. Juz Amma pages).
  Widget _surahBanner(
    MushafLine line, {
    required int rowIndex,
    required double fontSize,
    required Color color,
  }) {
    return Container(
      key: ValueKey('surah-banner-$rowIndex'),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: color.withValues(alpha: 0.55), width: 1),
          bottom: BorderSide(color: color.withValues(alpha: 0.55), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Diamond(color: color, size: fontSize * 0.3),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              line.text,
              textDirection: TextDirection.rtl,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: fontSize,
                height: 1.6,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _Diamond(color: color, size: fontSize * 0.3),
        ],
      ),
    );
  }

  Widget _audioBar(ColorScheme scheme, TextTheme textTheme) {
    final enabled = _todayLineCount() > 0;
    final playing = _isPlaying;
    final error = _playError;
    final unit = widget.unit;
    final echoActive = _echo && (unit != null ? unit.hasUnit : _started);
    final pos = unit != null ? unit.ayahIndex : _ayahIndex;
    final total = unit != null ? unit.totalAyahs : _todayUrls().length;
    final reviewing = widget.reviewDays > 0;
    final title =
        error ??
        (echoActive
            ? 'Echo — ayah ${pos + 1} of $total'
            : reviewing
            ? (playing
                  ? 'Playing review — last ${widget.reviewDays} days'
                  : 'Play review — last ${widget.reviewDays} days')
            : (playing ? "Playing today's portion" : "Play today's portion"));
    final repeatText = _repeat == 0 ? '∞ (until stopped)' : '×$_repeat';
    final ayahCount = _todayUrls().length;
    final subtitle = echoActive
        ? 'echo · ayah ${pos + 1} of $total · $_speedLabel · ${_reciter.label}'
        : 'repeat $repeatText · $ayahCount ayah${ayahCount == 1 ? '' : 's'} · $_speedLabel · ${_reciter.label}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                tooltip: playing
                    ? 'Pause'
                    : (echoActive
                          ? 'Next ayah (listen & repeat)'
                          : (widget.reviewDays > 0
                                ? 'Play the review queue'
                                : "Play today's portion")),
                onPressed: enabled ? _togglePlay : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (error != null
                                  ? textTheme.bodySmall?.copyWith(
                                      color: scheme.error,
                                    )
                                  : textTheme.bodyMedium)
                              ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 6),
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Repeat', style: textTheme.labelMedium),
                    const SizedBox(width: 8),
                    SegmentedButton<int>(
                      key: const ValueKey('repeat-selector'),
                      segments: [
                        for (final n in _repeatOptions)
                          ButtonSegment(
                            value: n,
                            label: Text(n == 0 ? '∞' : '$n'),
                          ),
                      ],
                      selected: {_repeat},
                      onSelectionChanged: (selection) {
                        setState(() => _repeat = selection.first);
                        final unit = widget.unit;
                        if (unit != null) {
                          unawaited(unit.saveDefaults(repeat: selection.first));
                        }
                      },
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Reciter', style: textTheme.labelMedium),
                    const SizedBox(width: 8),
                    DropdownButton<Reciter>(
                      key: const ValueKey('reciter-selector'),
                      value: _reciter,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        for (final r in Reciter.values)
                          DropdownMenuItem(value: r, child: Text(r.label)),
                      ],
                      onChanged: (reciter) {
                        if (reciter == null || reciter == _reciter) return;
                        if (_isPlaying) {
                          final unit = widget.unit;
                          if (unit != null) {
                            unit.pause();
                          } else {
                            _audio.stop();
                            _playing = false;
                          }
                        }
                        setState(() => _reciter = reciter);
                        final unit = widget.unit;
                        if (unit != null) {
                          unawaited(unit.saveDefaults(reciter: reciter));
                        }
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Speed', style: textTheme.labelMedium),
                    const SizedBox(width: 8),
                    DropdownButton<double>(
                      key: const ValueKey('speed-selector'),
                      value: _speed,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        for (final v in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                          DropdownMenuItem(
                            value: v,
                            child: Text(
                              v == v.roundToDouble()
                                  ? '${v.toInt()}×'
                                  : '$v×',
                            ),
                          ),
                      ],
                      onChanged: (speed) {
                        if (speed == null || speed == _speed) return;
                        setState(() => _speed = speed);
                        final unit = widget.unit;
                        if (unit != null) {
                          unawaited(unit.saveDefaults(speed: speed));
                          unit.setSpeed(speed);
                        } else {
                          _audio.setSpeed(speed);
                        }
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Echo', style: textTheme.labelMedium),
                    const SizedBox(width: 8),
                    FilterChip(
                      key: const ValueKey('echo-toggle'),
                      label: const Text('listen & repeat'),
                      tooltip:
                          'Auto-pause after each ayah so you can repeat '
                          'it aloud; press play for the next ayah',
                      selected: _echo,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: _onEchoChanged,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for jumping straight to a mushaf page by number.
class _PageJumpDialog extends StatefulWidget {
  const _PageJumpDialog({required this.initial});

  final String initial;

  @override
  State<_PageJumpDialog> createState() => _PageJumpDialogState();
}

class _PageJumpDialogState extends State<_PageJumpDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_controller.text.trim());
    if (n == null) {
      setState(
        () => _error = 'Enter a page number (1-${MushafData.totalPages}).',
      );
      return;
    }
    Navigator.of(context).pop(n.clamp(1, MushafData.totalPages).toInt());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Jump to page'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: '1 – ${MushafData.totalPages}',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Go')),
      ],
    );
  }
}


/// The ornamental ayah-end circle with the Arabic-Indic verse number inside,
/// as printed in the Madani mushaf.
class _AyahOrnament extends StatelessWidget {
  const _AyahOrnament({
    super.key,
    required this.digits,
    required this.fontSize,
    required this.color,
  });

  final String digits;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final height = fontSize * 1.2;
    final width = math.max(
      height,
      fontSize * (1.05 + 0.42 * (digits.length - 1)),
    );
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _RosettePainter(color: color),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              digits,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'UthmanicHafs',
                fontSize: fontSize * 0.68,
                height: 1,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One word or ayah-rosette token of a mushaf line, in reading order.
class _LineToken {
  const _LineToken(this.text, {required this.isRosette});

  final String text;

  /// True when this token is a standalone ayah number (rendered as a rosette).
  final bool isRosette;
}

/// A small rotated square used as a corner/border ornament.
class _Diamond extends StatelessWidget {
  const _Diamond({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
        ),
      ),
    );
  }
}

/// The ayah-end rosette of the printed mushaf: a ring of small petals around
/// the number circle.
class _RosettePainter extends CustomPainter {
  const _RosettePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = color,
    );
    final petal = Paint()..color = color;
    final ring = radius - 3.2;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawCircle(
        center + Offset(math.cos(a) * ring, math.sin(a) * ring),
        1.1,
        petal,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RosettePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The page frame of the printed mushaf: a double rule with a small diagonal
/// flourish at each corner.
/// The page number / juz medallion of the printed mushaf: an ornate
/// rounded square with a double rule around the number.
class _Medallion extends StatelessWidget {
  const _Medallion({
    required this.size,
    required this.color,
    required this.child,
  });

  final double size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: color.withValues(alpha: 0.85),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Container(
        margin: const EdgeInsets.all(2.4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: color.withValues(alpha: 0.5),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        child: child,
      ),
    );
  }
}

/// The fine ornamental ribbon along the top of the mushaf header band: a
/// repeating run of short vertical strokes, like the printed page's band.
class _RibbonPainter extends CustomPainter {
  const _RibbonPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    const step = 6.0;
    final top = 0.6;
    final bottom = size.height - 0.6;
    var x = step / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
      x += step;
    }
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The page frame of the printed mushaf: a sharp-cornered double rule with a
/// small diagonal flourish at each corner.
class _MushafFramePainter extends CustomPainter {
  const _MushafFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 2.5;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final outer = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    canvas.drawRect(outer, stroke);
    canvas.drawRect(outer.deflate(2.6), stroke);

    // Corner flourishes: short diagonal ticks fanning out from each corner.
    final tick = Paint()
      ..color = color
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    const l = 7.0;
    for (final (sx, sy) in const [
      (-1.0, -1.0),
      (1.0, -1.0),
      (-1.0, 1.0),
      (1.0, 1.0),
    ]) {
      final ox = sx < 0 ? inset : size.width - inset;
      final oy = sy < 0 ? inset : size.height - inset;
      canvas.drawLine(
        Offset(ox, oy),
        Offset(ox + sx * l, oy + sy * l),
        tick,
      );
      canvas.drawLine(
        Offset(ox + sx * l * 0.45, oy),
        Offset(ox, oy + sy * l * 0.45),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MushafFramePainter oldDelegate) =>
      oldDelegate.color != color;
}
