import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'memorization_calc.dart';
import 'screens/page_viewer_screen.dart';
import 'services/audio_settings.dart';
import 'services/audio_unit_controller.dart';
import 'services/memorization_log.dart';
import 'services/planner_settings.dart';
import 'services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore the user's last-used reciter/speed/repeat before the first frame
  // so the audio bar opens with their saved preferences, and restore the
  // saved planner inputs (page, rate, rest days, theme) and completion log.
  final audio = await AudioSettings.load();
  final planner = await PlannerSettings.load();
  final log = await MemorizationLog.load();
  // Set up the daily reminder and learn whether this launch was caused by
  // tapping it (cold start) so we can deep-link to the reminder's page.
  final reminder = ReminderService();
  final launchPage = await reminder.initialize();
  runApp(
    QuranMemorizationApp(
      unit: AudioUnitController(settings: audio),
      plannerSettings: planner,
      log: log,
      reminder: reminder,
      initialReminderPage: launchPage,
    ),
  );
}

class QuranMemorizationApp extends StatefulWidget {
  const QuranMemorizationApp({
    super.key,
    this.unit,
    this.plannerSettings = const PlannerSettings(),
    this.log = const MemorizationLog(),
    this.reminder,
    this.initialReminderPage,
  });

  /// Shared app-level audio unit so today's portion keeps playing after the
  /// mushaf viewer is closed; when null (tests) no mini player is shown.
  final AudioUnitController? unit;

  /// Restored planner inputs applied as the planner's initial state.
  final PlannerSettings plannerSettings;

  /// Restored completion history (mark-today-done + streak).
  final MemorizationLog log;

  /// Daily reminder service; when null no reminder UI is offered.
  final ReminderService? reminder;

  /// Target page when this launch was triggered by tapping the reminder
  /// notification (cold start); the viewer opens on it after the first frame.
  final int? initialReminderPage;

  @override
  State<QuranMemorizationApp> createState() => _QuranMemorizationAppState();
}

class _QuranMemorizationAppState extends State<QuranMemorizationApp> {
  /// Root navigator so notification taps can push the mushaf viewer no matter
  /// which screen is currently visible.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// Last page opened via a reminder tap, with the moment it happened. A tap
  /// that cold-starts the app can reach us twice (once through the launch
  /// details, once through the response callback), so identical pages opened
  /// within this window are collapsed into one navigation.
  int? _lastReminderPage;
  DateTime _lastReminderOpenedAt = DateTime.fromMillisecondsSinceEpoch(0);

  late ThemeMode _themeMode = widget.plannerSettings.themeMode;

  @override
  void initState() {
    super.initState();
    widget.reminder?.onTap = _openReminderPage;
    final initialPage = widget.initialReminderPage;
    if (initialPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openReminderPage(initialPage);
      });
    }
  }

  @override
  void dispose() {
    // Don't leave a dangling reference to this app's state.
    if (widget.reminder?.onTap == _openReminderPage) {
      widget.reminder?.onTap = null;
    }
    super.dispose();
  }

  /// Opens the mushaf viewer at the page carried by the reminder notification,
  /// using the planner's persisted settings (rate → lines/day, direction) and
  /// the shared audio unit.
  Future<void> _openReminderPage(int page) async {
    final now = DateTime.now();
    final justOpened =
        _lastReminderPage == page &&
        now.difference(_lastReminderOpenedAt).inSeconds < 3;
    _lastReminderPage = page;
    _lastReminderOpenedAt = now;
    if (justOpened) return;

    final settings = await PlannerSettings.load();
    final pagesPerDay = settings.rateIsLines
        ? settings.rate / MemorizationPlan.linesPerPage
        : settings.rate;
    final nav = _navigatorKey.currentState;
    if (nav == null || !mounted) return;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => PageViewerScreen(
          page: page,
          linesPerDay: pagesPerDay * MemorizationPlan.linesPerPage,
          direction: settings.direction,
          unit: widget.unit,
          reminder: widget.reminder,
        ),
      ),
    );
  }

  void _setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    setState(() => _themeMode = mode);
    // Persist the choice (fire-and-forget).
    widget.plannerSettings.copyWith(themeMode: mode).save();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
    );
    return MaterialApp(
      title: 'Hifz Planner',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      themeMode: _themeMode,
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
      home: PlannerScreen(
        unit: widget.unit,
        settings: widget.plannerSettings,
        log: widget.log,
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
        reminder: widget.reminder,
      ),
    );
  }
}

enum RateMode { lines, fraction }

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({
    super.key,
    this.unit,
    this.settings = const PlannerSettings(),
    this.log = const MemorizationLog(),
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
    this.reminder,
  });

  /// Shared audio unit backing the persistent mini player (optional; tests
  /// omit it).
  final AudioUnitController? unit;

  /// Restored planner inputs applied as this screen's initial state.
  final PlannerSettings settings;

  /// Restored completion history shown in the "today's portion" card.
  final MemorizationLog log;

  /// Current app theme; the toggle in the app bar switches it.
  final ThemeMode themeMode;

  /// Called when the user picks a different theme.
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  /// Daily reminder service threaded through to the mushaf viewer so the
  /// "set reminder" action works from any entry point; optional (tests).
  final ReminderService? reminder;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late final TextEditingController _pageController;
  late final TextEditingController _rateController;
  late RateMode _rateMode;
  late MemorizationDirection _direction;
  late final Set<int> _restWeekdays;
  DateTime? _startDate;
  late MemorizationLog _log;

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController(text: '${widget.settings.page}')
      ..addListener(_onChanged);
    _rateController = TextEditingController(
      text: _trimInput(widget.settings.rate),
    )..addListener(_onChanged);
    _rateMode = widget.settings.rateIsLines
        ? RateMode.lines
        : RateMode.fraction;
    _direction = widget.settings.direction;
    _restWeekdays = {...widget.settings.restWeekdays};
    _startDate = widget.settings.startDate;
    _log = widget.log;
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

  void _onChanged() {
    setState(() {});
    _saveSettings();
  }

  /// Persists the current planner inputs (fire-and-forget) so a page
  /// refresh restores them.
  void _saveSettings() {
    widget.settings
        .copyWith(
          page: _page ?? widget.settings.page,
          rate: _rate ?? widget.settings.rate,
          rateIsLines: _rateMode == RateMode.lines,
          direction: _direction,
          restWeekdays: _restWeekdays,
          startDate: _startDate,
        )
        .save();
  }

  static String _trimInput(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

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
              startDate: _startDate,
              direction: _direction,
            )
          : MemorizationPlan(
              currentPage: page,
              pagesPerDay: rate,
              restWeekdays: _restWeekdays,
              startDate: _startDate,
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
    _saveSettings();
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

  /// The planner's daily rate converted to text lines per day.
  double _effectiveLinesPerDay() {
    final pagesPerDay = _rateMode == RateMode.lines
        ? (_rate ?? 10) / MemorizationPlan.linesPerPage
        : (_rate ?? (2 / 3));
    return pagesPerDay * MemorizationPlan.linesPerPage;
  }

  void _openPageViewer() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PageViewerScreen(
          page: _page ?? 1,
          linesPerDay: _effectiveLinesPerDay(),
          direction: _direction,
          unit: widget.unit,
          reminder: widget.reminder,
        ),
      ),
    );
  }

  /// Nightly review: opens the mushaf viewer with the last [reviewDays] days
  /// of lines queued for listening, oldest-first.
  void _openReviewViewer() {
    const reviewDays = 3;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PageViewerScreen(
          page: _page ?? 1,
          linesPerDay: _effectiveLinesPerDay(),
          direction: _direction,
          unit: widget.unit,
          reviewDays: reviewDays,
          reminder: widget.reminder,
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
          reminder: widget.reminder,
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
          PopupMenuButton<ThemeMode>(
            key: const ValueKey('theme-toggle'),
            icon: Icon(switch (widget.themeMode) {
              ThemeMode.light => Icons.light_mode_outlined,
              ThemeMode.dark => Icons.dark_mode_outlined,
              ThemeMode.system => Icons.brightness_auto_outlined,
            }),
            tooltip: 'Theme',
            initialValue: widget.themeMode,
            onSelected: widget.onThemeModeChanged,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ThemeMode.system,
                child: ListTile(
                  leading: Icon(Icons.brightness_auto_outlined),
                  title: Text('System'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: ThemeMode.light,
                child: ListTile(
                  leading: Icon(Icons.light_mode_outlined),
                  title: Text('Light'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: ThemeMode.dark,
                child: ListTile(
                  leading: Icon(Icons.dark_mode_outlined),
                  title: Text('Dark'),
                  dense: true,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.nightlight_outlined),
            tooltip: 'Nightly review — last 3 days',
            onPressed: _openReviewViewer,
          ),
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Plan starts',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                                Text(
                                  _startDate == null
                                      ? 'Today (${formatDate(DateTime.now())})'
                                      : formatDate(_startDate!),
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(
                              _startDate == null ? 'Change date' : 'Change',
                            ),
                            onPressed: _pickStartDate,
                          ),
                          if (_startDate != null)
                            IconButton(
                              icon: const Icon(Icons.restart_alt),
                              tooltip: 'Start today instead',
                              onPressed: () {
                                setState(() => _startDate = null);
                                _saveSettings();
                              },
                            ),
                        ],
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
                          _saveSettings();
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
                                _saveSettings();
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
                const SizedBox(height: 12),
                _todayCard(plan, scheme),
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
                          unit.liveSettings,
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

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: 'When does your plan start?',
    );
    if (picked == null || !mounted) return;
    setState(
      () => _startDate = DateTime(picked.year, picked.month, picked.day),
    );
    _saveSettings();
  }

  /// The current day's portion (page + lines) as it would be memorized now,
  /// or null when the plan inputs are invalid.
  (int, double)? _todayPortion(MemorizationPlan? plan) {
    if (plan == null) return null;
    return (plan.currentPage, _effectiveLinesPerDay());
  }

  void _markTodayDone(MemorizationPlan? plan) {
    final portion = _todayPortion(plan);
    if (portion == null) return;
    final (page, lines) = portion;
    final now = DateTime.now();
    setState(() {
      _log = _log.record(
        date: DateTime(now.year, now.month, now.day),
        page: page,
        lines: lines,
        direction: _direction,
      );
    });
    _log.save();
  }

  void _undoToday() {
    final now = DateTime.now();
    setState(() {
      _log = _log.remove(DateTime(now.year, now.month, now.day));
    });
    _log.save();
  }

  /// Daily completion card: mark today's portion done, see the streak, and
  /// browse recent sessions.
  Widget _todayCard(MemorizationPlan? plan, ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    final portion = _todayPortion(plan);
    final doneToday = _log.isDoneOn(DateTime.now());
    final latest = _log.latest;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final String title;
    final String subtitle;
    if (portion == null) {
      title = 'Mark today’s portion done';
      subtitle = 'Complete the plan above to enable this.';
    } else if (doneToday) {
      title = 'Done today — barakallahu feek!'; // ‎may Allah bless you
      subtitle = 'Page ${portion.$1} · ${_trim(portion.$2)} lines memorized.';
    } else {
      title = 'Today’s portion: page ${portion.$1}';
      subtitle = '${_trim(portion.$2)} lines — memorize it, then mark it done.';
    }

    final streak = _log.streak;
    final hasHistory = _log.totalSessions > 0;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  doneToday ? Icons.check_circle : Icons.flag_outlined,
                  color: doneToday ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (portion != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: doneToday
                        ? OutlinedButton.icon(
                            key: const ValueKey('undo-today'),
                            icon: const Icon(Icons.undo),
                            label: const Text('Undo'),
                            onPressed: _undoToday,
                          )
                        : FilledButton.icon(
                            key: const ValueKey('mark-done'),
                            icon: const Icon(Icons.check),
                            label: const Text('Mark today’s portion done'),
                            onPressed: () => _markTodayDone(plan),
                          ),
                  ),
                ],
              ),
            ],
            if (hasHistory || streak > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _statBlock('$streak', 'day streak', scheme),
                  _statBlock('${_log.totalSessions}', 'sessions', scheme),
                  _statBlock(_trim(_log.totalLines), 'lines memorized', scheme),
                ],
              ),
              const SizedBox(height: 8),
              if (latest != null &&
                  !latest.date.isBefore(
                    DateTime(today.year, today.month, today.day - 6),
                  ))
                Text(
                  'Last session: ${_shortDate(latest.date)} — '
                  'page ${latest.page} · ${_trim(latest.lines)} lines.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _shortDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (d == today) return 'today';
    if (d == DateTime(today.year, today.month, today.day - 1)) {
      return 'yesterday';
    }
    return '${months[d.month - 1]} ${d.day}';
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
            Text(
              '${hijriDateString(result.finishDate)}'
              '${isDone ? '' : ' · ${humanizeDays(result.calendarDays)}'}',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isDone
                  ? 'Alhamdulillah — the remaining ${_trim(remaining)} page${remaining == 1 ? '' : 's'} fit in one session.'
                  : '${plan.restWeekdays.isEmpty ? 'every day' : 'on your study days'} · '
                        'starting ${_startDate == null ? 'today' : formatDate(_startDate!)}',
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
