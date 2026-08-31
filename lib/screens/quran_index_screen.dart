import 'package:flutter/material.dart';

import '../data/mushaf_page.dart';
import '../data/quran_text.dart';

/// A full-screen Quran navigation index with three tabs:
///   • Surah — all 114 chapters with Arabic name, transliteration, ayah
///     count, and starting page.
///   • Juz — all 30 juz with the starting page and the surah range.
///   • Bookmarks — user-saved pages with optional notes.
///
/// Opened as a modal sheet from the page viewer's app bar. Pops with the
/// selected page number so the viewer jumps there.
class QuranIndexScreen extends StatefulWidget {
  const QuranIndexScreen({super.key, this.initialPage});

  /// Page the viewer was on when this sheet was opened (highlights in lists).
  final int? initialPage;

  @override
  State<QuranIndexScreen> createState() => _QuranIndexScreenState();
}

class _QuranIndexScreenState extends State<QuranIndexScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _query = '';
  MushafData? _mushaf;
  QuranText? _quran;
  bool _loading = true;

  // Bookmarks: { "page": int, "note": String?, "timestamp": int }
  final List<Map<String, dynamic>> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        MushafData.load(),
        QuranText.load(),
      ]);
      if (!mounted) return;
      _mushaf = results[0] as MushafData;
      _quran = results[1] as QuranText;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  // ── Bookmarks persistence ────────────────────────────────────────

  // Bookmarks are in-memory for this sheet. The viewer persists them
  // via SharedPreferences, so they're loaded from there on next open.

  bool _isBookmarked(int page) =>
      _bookmarks.any((b) => b['page'] == page);

  void _toggleBookmark(int page, {String? note}) {
    setState(() {
      final idx = _bookmarks.indexWhere((b) => b['page'] == page);
      if (idx >= 0) {
        _bookmarks.removeAt(idx);
      } else {
        _bookmarks.insert(0, {
          'page': page,
          'note': note,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  Future<void> _showAddBookmarkDialog(int page) async {
    final noteController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Bookmark page $page'),
        content: TextField(
          controller: noteController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Add a note (optional)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, noteController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      _toggleBookmark(page, note: result.isEmpty ? null : result);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  /// Returns the starting page for each surah (1-indexed surah → page).
  int _surahStartPage(int surah) {
    final mushaf = _mushaf;
    if (mushaf == null) return 1;
    // Walk pages to find the first page where this surah is the header.
    for (var i = 0; i < mushaf.pages.length; i++) {
      if (mushaf.pages[i].surah == surah) return i + 1;
    }
    return 1;
  }

  /// Pages where each juz starts.
  List<int> get _juzStartPages {
    final mushaf = _mushaf;
    if (mushaf == null) return List.filled(30, 1);
    final pages = <int>[];
    var lastJuz = 0;
    for (var i = 0; i < mushaf.pages.length; i++) {
      if (mushaf.pages[i].juz != lastJuz) {
        pages.add(i + 1);
        lastJuz = mushaf.pages[i].juz;
      }
    }
    // Ensure all 30 entries.
    while (pages.length < 30) {
      pages.add(pages.last);
    }
    return pages;
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Quran Index'),
            bottom: TabBar(
              controller: _tab,
              tabs: const [
                Tab(text: 'Surah', icon: Icon(Icons.menu_book)),
                Tab(text: 'Juz', icon: Icon(Icons.book)),
                Tab(text: 'Bookmarks', icon: Icon(Icons.bookmark)),
              ],
            ),
            actions: [
              if (_tab.index == 0)
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search surah',
                  onPressed: _showSearch,
                ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tab,
                  children: [
                    _buildSurahList(scheme, textTheme),
                    _buildJuzList(scheme, textTheme),
                    _buildBookmarkList(scheme, textTheme),
                  ],
                ),
        );
      },
    );
  }

  // ── Surah tab ────────────────────────────────────────────────────

  Widget _buildSurahList(ColorScheme scheme, TextTheme textTheme) {
    final quran = _quran;
    if (quran == null) {
      return const Center(child: Text('Could not load surah index.'));
    }

    final filtered = _query.isEmpty
        ? List.generate(114, (i) => i + 1)
        : [for (var i = 1; i <= 114; i++)
            if (_matchesSurah(i, quran)) i];

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final surah = filtered[index];
        final info = quran.surahInfo(surah);
        final meta = _mushaf?.surahMeta(surah);
        final page = _surahStartPage(surah);
        final isCurrent = page == widget.initialPage;
        final bookmarked = _isBookmarked(page);

        return ListTile(
          selected: isCurrent,
          selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.3),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCurrent
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$surah',
              style: TextStyle(
                color: isCurrent ? scheme.onPrimary : scheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
              child: Text(
                info.transliteration,
                style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (meta != null)
                Text(
                  meta.arabicName,
                  textDirection: TextDirection.rtl,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFamily: 'UthmanicHafs',
                    fontSize: 16,
                  ),
                ),
            ],
          ),
          subtitle: Row(
            children: [
              Text(
                '${info.ayahCount} ayah${info.ayahCount == 1 ? '' : 's'}',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Page $page',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (bookmarked)
                Icon(Icons.bookmark, size: 16, color: scheme.primary),
              IconButton(
                icon: Icon(
                  bookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
                  size: 20,
                ),
                tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark this page',
                onPressed: () => _showAddBookmarkDialog(page),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => Navigator.pop(context, page),
        );
      },
    );
  }

  bool _matchesSurah(int surah, QuranText quran) {
    final q = _query.toLowerCase();
    final info = quran.surahInfo(surah);
    return info.transliteration.toLowerCase().contains(q) ||
        '$surah'.contains(q);
  }

  // ── Juz tab ──────────────────────────────────────────────────────

  Widget _buildJuzList(ColorScheme scheme, TextTheme textTheme) {
    final quran = _quran;
    final mushaf = _mushaf;
    if (quran == null || mushaf == null) {
      return const Center(child: Text('Could not load juz index.'));
    }

    final startPages = _juzStartPages;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: 30,
      itemBuilder: (context, index) {
        final juz = index + 1;
        final page = startPages[index];
        final isCurrent = mushaf.page(page.clamp(1, 604)).juz == juz;
        final bookmarked = _isBookmarked(page);

        // Find the first surah on this juz's starting page.
        final startSurah = mushaf.page(page.clamp(1, 604)).surah;
        final startInfo = quran.surahInfo(startSurah);

        // Find the last surah of this juz.
        int endSurah = startSurah;
        for (var i = page; i <= MushafData.totalPages; i++) {
          final p = mushaf.page(i);
          if (p.juz == juz) {
            endSurah = p.surah;
          } else {
            break;
          }
        }
        final endInfo = quran.surahInfo(endSurah);

        return ListTile(
          selected: isCurrent,
          selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.3),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCurrent ? scheme.primary : scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$juz',
              style: TextStyle(
                color: isCurrent ? scheme.onPrimary : scheme.onSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          title: Text(
            'Juz $juz',
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${startInfo.transliteration}${startSurah != endSurah ? ' — ${endInfo.transliteration}' : ''} '
            '· Page $page',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (bookmarked)
                Icon(Icons.bookmark, size: 16, color: scheme.primary),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => Navigator.pop(context, page),
        );
      },
    );
  }

  // ── Bookmarks tab ────────────────────────────────────────────────

  Widget _buildBookmarkList(ColorScheme scheme, TextTheme textTheme) {
    if (_bookmarks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_border,
                size: 64,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No bookmarks yet',
                style: textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the bookmark icon next to any surah\nor page to save it here.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bm = _bookmarks[index];
        final page = bm['page'] as int;
        final note = bm['note'] as String?;
        final timestamp = bm['timestamp'] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

        // Find surah info for this page.
        String surahInfo = '';
        if (_mushaf != null && page >= 1 && page <= 604) {
          final p = _mushaf!.page(page);
          final meta = _mushaf!.surahMeta(p.surah);
          surahInfo = '${meta.transliteration} · Page $page';
        } else {
          surahInfo = 'Page $page';
        }

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.bookmark, color: scheme.primary, size: 20),
          ),
          title: Text(
            surahInfo,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note != null && note.isNotEmpty)
                Text(
                  note,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                _formatDate(date),
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Remove bookmark',
            onPressed: () => _toggleBookmark(page),
          ),
          onTap: () => Navigator.pop(context, page),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── Search ───────────────────────────────────────────────────────

  void _showSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final controller = TextEditingController();
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Search Surah',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Type surah name or number...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: (_) => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
        );
      },
    ).whenComplete(() {
      setState(() {}); // Refresh list
    });
  }
}
