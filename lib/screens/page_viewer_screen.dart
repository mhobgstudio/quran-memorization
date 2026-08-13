import 'dart:async';

import 'package:flutter/material.dart';

import '../data/quran_audio.dart';
import '../data/quran_text.dart';
import '../memorization_calc.dart' show MemorizationPlan;
import '../services/audio_player.dart';

/// Displays one Madani mushaf page with today's assigned portion highlighted,
/// plus audio playback (loop/repeat) of that same portion.
///
/// [linesPerDay] comes from the planner; the highlighted ayahs approximate
/// "today's lines" via [todayAyahCount]. [quran] and [audio] may be injected
/// in tests; otherwise the bundled asset is loaded and a just_audio player
/// is created.
class PageViewerScreen extends StatefulWidget {
  const PageViewerScreen({
    super.key,
    required this.page,
    required this.linesPerDay,
    this.quran,
    this.audio,
  });

  /// Initial page to show (1..604).
  final int page;

  /// Lines memorized per day (the planner's daily rate).
  final double linesPerDay;

  /// Pre-loaded Quran text; when null it is loaded from the asset.
  final QuranText? quran;

  /// Audio backend; when null a just_audio player is created.
  final QuranAudio? audio;

  @override
  State<PageViewerScreen> createState() => _PageViewerScreenState();
}

class _PageViewerScreenState extends State<PageViewerScreen> {
  static const List<int> _repeatOptions = [1, 3, 5];

  late int _page;
  late final QuranAudio _audio;
  QuranText? _quran;
  bool _loading = true;
  String? _error;

  bool _playing = false;
  String? _audioError;
  int _repeat = 3;
  StreamSubscription<void>? _audioSub;

  @override
  void initState() {
    super.initState();
    _page = widget.page.clamp(1, QuranText.totalPages).toInt();
    _audio = widget.audio ?? JustQuranAudio();
    _audioSub = _audio.onCompleted.listen((_) {
      if (!mounted) return;
      setState(() => _playing = false);
    });
    _load();
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final injected = widget.quran;
    if (injected != null) {
      // Assigned directly: _load runs before the first build.
      _quran = injected;
      _loading = false;
      return;
    }
    try {
      final quran = await QuranText.load();
      if (!mounted) return;
      setState(() {
        _quran = quran;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the Quran text: $e';
        _loading = false;
      });
    }
  }

  int _highlightCount() {
    final quran = _quran;
    if (quran == null) return 0;
    return todayAyahCount(
      ayahsOnPage: quran.ayahCountOnPage(_page),
      linesPerDay: widget.linesPerDay,
      linesPerPage: MemorizationPlan.linesPerPage,
    );
  }

  List<String> _todayUrls() {
    final quran = _quran;
    if (quran == null) return const [];
    final ayahs = quran.pageAyahs(_page);
    final highlight = _highlightCount();
    return [
      for (final a in ayahs.take(highlight))
        ayahAudioUrl(Reciter.alafasy, a.surah, a.ayah),
    ];
  }

  Future<void> _togglePlay() async {
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
      await _audio.play(urls: urls, repeat: _repeat);
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
    _audio.stop();
    setState(() {
      _page = (_page + delta).clamp(1, QuranText.totalPages).toInt();
      _playing = false;
      _audioError = null;
    });
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
    final quran = _quran!;
    final ayahs = quran.pageAyahs(_page);
    final highlight = _highlightCount();
    final wholePage = highlight >= ayahs.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous page',
              onPressed: _page > 1 ? () => _goToPage(-1) : null,
            ),
            Text(
              '$_page / ${QuranText.totalPages}',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next page',
              onPressed: _page < QuranText.totalPages
                  ? () => _goToPage(1)
                  : null,
            ),
          ],
        ),
        _todayChip(scheme, textTheme, highlight, ayahs.length, wholePage),
        const SizedBox(height: 8),
        _audioBar(scheme, textTheme, highlight, wholePage),
        const SizedBox(height: 8),
        for (var i = 0; i < ayahs.length; i++) ...[
          if (i == 0 || ayahs[i].surah != ayahs[i - 1].surah)
            _SurahHeader(info: quran.surahInfo(ayahs[i].surah)),
          _AyahRow(
            ayah: ayahs[i],
            index: i,
            highlighted: i < highlight,
            scheme: scheme,
            textTheme: textTheme,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Highlighted ayahs are today\'s portion — the same ayahs the audio plays.',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _todayChip(
    ColorScheme scheme,
    TextTheme textTheme,
    int highlight,
    int total,
    bool wholePage,
  ) {
    final label = wholePage
        ? "Today's portion: the whole page ($total ayahs)"
        : "Today's portion: $highlight of $total ayahs";
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _audioBar(
    ColorScheme scheme,
    TextTheme textTheme,
    int highlight,
    bool wholePage,
  ) {
    final enabled = highlight > 0;
    final title =
        _audioError ??
        (_playing ? "Playing today's portion" : "Play today's portion");
    final subtitle = wholePage
        ? 'repeat ×$_repeat · all ${_todayUrls().length} ayahs'
        : 'repeat ×$_repeat · ${_todayUrls().length} ayah${_todayUrls().length == 1 ? '' : 's'} · Alafasy';

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
                icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                tooltip: _playing ? 'Pause' : 'Play today\'s portion',
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
                          (_audioError != null
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
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 6),
              child: Row(
                children: [
                  Text('Repeat', style: textTheme.labelMedium),
                  const SizedBox(width: 8),
                  SegmentedButton<int>(
                    key: const ValueKey('repeat-selector'),
                    segments: [
                      for (final n in _repeatOptions)
                        ButtonSegment(value: n, label: Text('$n')),
                    ],
                    selected: {_repeat},
                    onSelectionChanged: (selection) {
                      setState(() => _repeat = selection.first);
                    },
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({required this.info});

  final SurahInfo info;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Center(
        child: Text(
          '${info.transliteration} · ${info.arabicName}',
          textDirection: TextDirection.rtl,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _AyahRow extends StatelessWidget {
  const _AyahRow({
    required this.ayah,
    required this.index,
    required this.highlighted,
    required this.scheme,
    required this.textTheme,
  });

  final Ayah ayah;
  final int index;
  final bool highlighted;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('ayah-${highlighted ? 'active' : 'rest'}-$index'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              ayah.text,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: textTheme.titleMedium?.copyWith(
                fontSize: 20,
                height: 1.9,
                color: highlighted
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlighted
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
            ),
            child: Text(
              '${ayah.ayah}',
              style: textTheme.labelSmall?.copyWith(
                color: highlighted ? scheme.onPrimary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
