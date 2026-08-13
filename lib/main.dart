import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'memorization_calc.dart';
import 'screens/page_viewer_screen.dart';
import 'services/audio_settings.dart';
import 'services/audio_unit_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore the user's last-used reciter/speed/repeat before the first frame
  // so the audio bar opens with their saved preferences.
  final settings = await AudioSettings.load();
  runApp(QuranMemorizationApp(unit: AudioUnitController(settings: settings)));
}

class QuranMemorizationApp extends StatelessWidget {
  const QuranMemorizationApp({super.key, this.unit});

  /// Shared app-level audio unit so today's portion keeps playing after the
  /// mushaf viewer is closed; when null (tests) no mini player is shown.
  final AudioUnitController? unit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
    );
    return MaterialApp(
      title: 'Hifz Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: PlannerScreen(unit: unit),
    );
  }
}

enum RateMode { lines, fraction }

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, this.unit});

  /// Shared audio unit backing the persistent mini player (optional; tests
  /// omit it).
  final AudioUnitController? unit;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _pageController = TextEditingController(text: '1');
  final _rateController = TextEditingController(text: '10');
  RateMode _rateMode = RateMode.lines;
  MemorizationDirection _direction = MemorizationDirection.forward;
  final Set<int> _restWeekdays = {};

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onChanged);
    _rateController.addListener(_onChanged);
    widget.unit?.addListener(_onUnitChanged);
  }

  @override
  void dispose() {
    widget.unit?.removeListener(_onUnitChanged);
    _pageController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _onUnitChanged() {
    if (mounted) setState(() {});
  }

  void _onChanged() => setState(() {});

  int? get _page {
    final raw = _pageController.text.trim();
    if (raw.isEmpty) return null;
    final value = int.tryParse(raw);
    if (value == null) return null;
    return value.clamp(1, MemorizationPlan.totalPages);
  }

  double? get _rate {
    final raw = _rateController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || value <= 0) return null;
    return value;
  }

  MemorizationPlan? _buildPlan() {
    final page = _page;
    final rate = _rate;
    if (page == null || rate == null) return null;
    try {
      return _rateMode == RateMode.lines
          ? MemorizationPlan.fromLinesPerDay(
              currentPage: page,
              linesPerDay: rate,
              restWeekdays: _restWeekdays,
              direction: _direction,
            )
          : MemorizationPlan(
              currentPage: page,
              pagesPerDay: rate,
              restWeekdays: _restWeekdays,
              direction: _direction,
            );
    } on ArgumentError {
      return null;
    }
  }

  void _setDirection(MemorizationDirection direction) {
    if (direction == _direction) return;
    setState(() {
      _direction = direction;
      // Jump to the starting end so the plan reads naturally in the chosen
      // direction: page 1 for forward, page 604 (the last page) for backward.
      _setPage(
        direction == MemorizationDirection.backward
            ? MemorizationPlan.totalPages
            : 1,
      );
    });
  }

  /// Sets the page field, clamping to the valid range and placing the cursor
  /// at the end of the text.
  void _setPage(int value) {
    final clamped = value.clamp(1, MemorizationPlan.totalPages);
    _pageController.text = '$clamped';
    _pageController.selection = TextSelection.collapsed(
      offset: _pageController.text.length,
    );
  }

  void _openPageViewer() {
    final pagesPerDay = _rateMode == RateMode.lines
        ? (_rate ?? 10) / MemorizationPlan.linesPerPage
        : (_rate ?? (2 / 3));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PageViewerScreen(
          page: _page ?? 1,
          linesPerDay: pagesPerDay * MemorizationPlan.linesPerPage,
          direction: _direction,
          unit: widget.unit,
        ),
      ),
    );
  }

  /// Reopens the mushaf viewer at the page and settings of the playing unit.
  void _openUnitViewer() {
    final unit = widget.unit!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PageViewerScreen(
          page: unit.page,
          linesPerDay: unit.linesPerDay,
          direction: unit.direction,
          unit: unit,
        ),
      ),
    );
  }

  void _stepPage(int delta) {
    _setPage((_page ?? 1) + delta);
  }

  static String _trim(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plan = _buildPlan();
    final page = _page;
    final rate = _rate;
    final pagesPerDay = _rateMode == RateMode.lines && rate != null
        ? rate / MemorizationPlan.linesPerPage
        : rate;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hifz Planner'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: "View today's page",
            onPressed: _openPageViewer,
          ),
        ],
      ),
      bottomNavigationBar: _miniPlayer(scheme),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard(
                  title: 'Current page',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<MemorizationDirection>(
                        segments: const [
                          ButtonSegment(
                            value: MemorizationDirection.forward,
                            label: Text('From the first page'),
                          ),
                          ButtonSegment(
                            value: MemorizationDirection.backward,
                            label: Text('From the last page'),
                          ),
                        ],
                        selected: {_direction},
                        onSelectionChanged: (selection) =>
                            _setDirection(selection.first),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: () => _stepPage(-1),
                            icon: const Icon(Icons.remove),
                            tooltip: 'Previous page',
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _pageController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                              decoration: const InputDecoration(
                                labelText: 'Page number',
                                suffixText: '/ 604',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                            onPressed: () => _stepPage(1),
                            icon: const Icon(Icons.add),
                            tooltip: 'Next page',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: (page ?? 1).toDouble().clamp(1, 604),
                        min: 1,
                        max: MemorizationPlan.totalPages.toDouble(),
                        divisions: MemorizationPlan.totalPages - 1,
                        label: '${page ?? 1}',
                        onChanged: (value) => _setPage(value.round()),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Standard Madani mushaf: 604 pages · 15 lines per page',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'Daily memorization',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<RateMode>(
                        segments: const [
                          ButtonSegment(
                            value: RateMode.lines,
                            label: Text('Lines / day'),
                            icon: Icon(Icons.format_list_numbered),
                          ),
                          ButtonSegment(
                            value: RateMode.fraction,
                            label: Text('Fraction of page / day'),
                            icon: Icon(Icons.straighten),
                          ),
                        ],
                        selected: {_rateMode},
                        onSelectionChanged: (selection) {
                          setState(() => _rateMode = selection.first);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _rateController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: _rateMode == RateMode.lines
                                    ? 'Lines memorized per day'
                                    : 'Fraction of page per day',
                                suffixText: _rateMode == RateMode.lines
                                    ? 'lines'
                                    : 'page',
                                errorText: rate == null && _rateInputInvalid()
                                    ? 'Enter a positive number'
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (pagesPerDay != null && rate != null) ...[
                        const SizedBox(height: 8),
                        _equivalenceChip(
                          _rateMode == RateMode.lines
                              ? '≈ ${_trim(pagesPerDay)} pages per day'
                              : '≈ ${_trim(rate * MemorizationPlan.linesPerPage)} lines per day',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'Rest days',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in const [
                            (1, 'Mon'),
                            (2, 'Tue'),
                            (3, 'Wed'),
                            (4, 'Thu'),
                            (5, 'Fri'),
                            (6, 'Sat'),
                            (7, 'Sun'),
                          ])
                            FilterChip(
                              label: Text(entry.$2),
                              selected: _restWeekdays.contains(entry.$1),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _restWeekdays.add(entry.$1);
                                  } else {
                                    _restWeekdays.remove(entry.$1);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Days you do not memorize. Leave empty to study every day.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _resultsCard(plan, scheme),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Persistent mini player for the shared audio unit: lets the user pause /
  /// resume today's portion, dismiss it, or tap to reopen the mushaf viewer.
  Widget? _miniPlayer(ColorScheme scheme) {
    final unit = widget.unit;
    if (unit == null || !unit.hasUnit) return null;
    final textTheme = Theme.of(context).textTheme;
    final fg = scheme.onInverseSurface;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Material(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: const ValueKey('mini-player'),
            borderRadius: BorderRadius.circular(16),
            onTap: _openUnitViewer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('mini-play'),
                    icon: Icon(unit.playing ? Icons.pause : Icons.play_arrow),
                    color: fg,
                    tooltip: unit.playing ? 'Pause' : 'Resume',
                    onPressed: unit.toggle,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          unit.settings,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: fg.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('mini-close'),
                    icon: const Icon(Icons.close),
                    color: fg,
                    tooltip: 'Stop and dismiss',
                    onPressed: unit.stop,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _rateInputInvalid() {
    final raw = _rateController.text.trim();
    return raw.isNotEmpty &&
        (double.tryParse(raw.replaceAll(',', '.')) == null ||
            double.parse(raw.replaceAll(',', '.')) <= 0);
  }

  Widget _sectionCard({required String title, required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _equivalenceChip(String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }

  Widget _resultsCard(MemorizationPlan? plan, ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;

    if (plan == null) {
      return Card(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Fill in a valid page (1–604) and a daily rate to see your finish date.',
                  style: textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final result = plan.compute();
    final remaining = plan.remainingPages;
    final completed = MemorizationPlan.totalPages - remaining;
    final progress = (completed / MemorizationPlan.totalPages).clamp(0.0, 1.0);
    final isDone = result.finishDate.isBefore(
      DateTime(
        plan.startDate.year,
        plan.startDate.month,
        plan.startDate.day + 1,
      ),
    );
    final longHaul = result.calendarDays > 730; // more than ~2 years

    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estimated completion',
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              plan.direction == MemorizationDirection.backward
                  ? 'From the last page · memorizing 604 → 1'
                  : 'From the first page · memorizing 1 → 604',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isDone ? 'You finish today' : formatDate(result.finishDate),
              style: textTheme.headlineSmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isDone
                  ? 'Alhamdulillah — the remaining ${_trim(remaining)} page${remaining == 1 ? '' : 's'} fit in one session.'
                  : '${humanizeDays(result.calendarDays)} · starting today, ${plan.restWeekdays.isEmpty ? 'every day' : 'on your study days'}',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: scheme.onPrimaryContainer.withValues(
                  alpha: 0.15,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statBlock('${_trim(remaining)} pages', 'remaining', scheme),
                _statBlock('${result.studyDays}', 'study sessions', scheme),
                _statBlock('${result.calendarDays}', 'calendar days', scheme),
              ],
            ),
            if (longHaul) ...[
              const SizedBox(height: 12),
              Text(
                'A long journey — take it one page at a time. '
                'Small, consistent daily portions beat big infrequent ones.',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBlock(String value, String label, ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
