import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/mushaf_page.dart';
import '../data/quran_audio.dart';
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

  @override
  void initState() {
    super.initState();
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
      return;
    }
    try {
      final mushaf = await MushafData.load();
      if (!mounted) return;
      setState(() {
        _mushaf = mushaf;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the mushaf layout: $e';
        _loading = false;
      });
    }
  }

  MushafPage get _currentPage => _mushaf!.page(_page);

  /// Number of text lines assigned for today (0..lines on the page).
  int _todayLineCount() {
    final lines = _currentPage.textLines.length;
    if (widget.linesPerDay <= 0) return 0;
    return widget.linesPerDay.round().clamp(0, lines);
  }

  /// Row indices (within [page].lines) of today's highlighted text lines.
  Set<int> _highlightedRowIndices(MushafPage page) {
    final n = _todayLineCount();
    if (n <= 0) return const {};
    final texts = page.textLines;
    final total = texts.length;
    final start = widget.direction == MemorizationDirection.backward
        ? total - n
        : 0;
    final result = <int>{};
    var ord = 0;
    for (var i = 0; i < page.lines.length; i++) {
      if (page.lines[i].isText) {
        if (ord >= start && ord < start + n) result.add(i);
        ord++;
      }
    }
    return result;
  }

  List<String> _todayUrls() {
    final page = _currentPage;
    final lines = page.todayLines(
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
        label: '${meta.arabicLong} · page $_page',
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

  void _goToPage(int delta) {
    // Stop playback so the viewer never plays a stale unit on a new page.
    final unit = widget.unit;
    if (unit != null) {
      unit.stop();
    } else {
      _audio.stop();
    }
    setState(() {
      _page = (_page + delta).clamp(1, MushafData.totalPages).toInt();
      _playing = false;
      _audioError = null;
      _ayahIndex = 0;
      _started = false;
    });
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
      appBar: AppBar(title: Text('Page $_page'), centerTitle: false),
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
            child: _mushafCard(context, page, highlighted),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
          child: _audioBar(scheme, textTheme),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            "Highlighted lines are today's portion — the audio plays exactly those ayahs.",
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
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
          Text(
            '$_page / ${MushafData.totalPages}',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
    final label = whole
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
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const pad = 12.0;
    final bandHeight = 40.0;

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
          padding: const EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF211E1A) : const Color(0xFFFFFDF5),
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              _pageHeaderBand(
                context,
                page,
                fontSize: fontSize * 1.1,
                color: textColor,
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: textColor.withValues(alpha: 0.55),
                      width: 1.4,
                    ),
                  ),
                ),
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
        );
      },
    );
  }

  /// Fits the text so all 15 rows plus the band fill the card without
  /// wrapping: bounded by both the available height and the longest line.
  double _fitFont(
    double width,
    double height,
    MushafPage page,
    double bandHeight,
  ) {
    const lineHeight = 1.85;
    var maxEm = 6.0;
    for (final line in page.lines) {
      switch (line.type) {
        case MushafLineType.basmala:
          maxEm = math.max(maxEm, _lineEm(line.text) * 0.9);
          break;
        case MushafLineType.text:
          maxEm = math.max(maxEm, _lineEm(line.text));
          break;
        case MushafLineType.surahHeader:
        case MushafLineType.blank:
          break;
      }
    }
    final heightFit = ((height - bandHeight - 16) / (15 * lineHeight)) * 0.96;
    final widthFit = (width / maxEm) * 0.94;
    return math.max(12.0, math.min(26.0, math.min(heightFit, widthFit)));
  }

  /// Rough width of a line in em units (ornaments are wider than letters).
  static double _lineEm(String text) {
    var em = 0.0;
    for (final r in text.runes) {
      if (r == 0x20) {
        em += 0.32;
      } else if (r >= 0x0660 && r <= 0x0669) {
        em += 1.6; // Arabic-Indic digit → ayah ornament
      } else {
        em += 0.55;
      }
    }
    return em;
  }

  Widget _pageHeaderBand(
    BuildContext context,
    MushafPage page, {
    required double fontSize,
    required Color color,
  }) {
    final meta = _mushaf!.surahMeta(page.surah);
    final bandName = meta.arabicLong;
    final cornerStyle = TextStyle(
      fontFamily: _fontFamily,
      fontSize: fontSize * 0.9,
      height: 1.3,
      color: color,
    );
    return Row(
      key: const ValueKey('page-header'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: Text(
              toArabicIndic(page.page),
              key: const ValueKey('page-header-number'),
              style: cornerStyle,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Center(
            child: Text(
              bandName,
              key: const ValueKey('page-header-surah'),
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: fontSize,
                height: 1.4,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              'الجزء ${toArabicIndic(page.juz)}',
              key: const ValueKey('page-header-juz'),
              style: cornerStyle,
            ),
          ),
        ),
      ],
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
              height: 1.85,
              color: color,
            ),
          ),
        );
      case MushafLineType.text:
        final hi = highlighted.contains(rowIndex);
        return Container(
          key: ValueKey('line-${hi ? 'active' : 'rest'}-$rowIndex'),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: hi
              ? BoxDecoration(
                  color:
                      (dark ? const Color(0xFF9A8A2E) : const Color(0xFFFFE082))
                          .withValues(alpha: dark ? 0.38 : 0.5),
                )
              : null,
          child: Text.rich(
            TextSpan(children: _lineSpans(line.text, fontSize, color)),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: fontSize,
              height: 1.85,
              color: color,
            ),
          ),
        );
    }
  }

  /// Splits a line into text runs and ayah-end ornaments (standalone
  /// Arabic-Indic digits become the ornamental circles of the printed mushaf).
  List<InlineSpan> _lineSpans(String text, double fontSize, Color color) {
    final digitRe = RegExp('^[٠-٩]+\$');
    final spans = <InlineSpan>[];
    var ornament = 0;
    for (final token in text.split(' ')) {
      final t = token.trim();
      if (t.isEmpty) continue;
      if (digitRe.hasMatch(t)) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _AyahOrnament(
              key: ValueKey('ayah-ornament-$ornament'),
              digits: t,
              fontSize: fontSize,
              color: color,
            ),
          ),
        );
        spans.add(
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(width: 2),
          ),
        );
      } else {
        spans.add(TextSpan(text: '$t '));
      }
      ornament++;
    }
    return spans;
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
    final title =
        error ??
        (echoActive
            ? 'Echo — ayah ${pos + 1} of $total'
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
                          : "Play today's portion"),
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
                              v == v.roundToDouble() ? '$v.toInt()×' : '$v×',
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
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.9), width: 1.1),
      ),
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
    );
  }
}
