import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'memorization_calc.dart';
import 'data/encouraging_verses.dart';
import 'screens/page_viewer_screen.dart';
import 'services/audio_settings.dart';
import 'services/audio_unit_controller.dart';
import 'services/memorization_log.dart';
import 'services/planner_settings.dart';
import 'services/reminder_service.dart';
import 'services/saved_plans.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore the user's last-used reciter/speed/repeat before the first frame
  // so the audio bar opens with their saved preferences, and restore the
  // saved planner inputs (page, rate, rest days, theme) and completion log.
  final audio = await AudioSettings.load();
  final planner = await PlannerSettings.load();
  final log = await MemorizationLog.load();
  final savedPlans = await SavedPlans.load();
  // Set up the daily reminder and learn whether this launch was caused by
  // tapping it (cold start) so we can deep-link to the reminder's page.
  final reminder = ReminderService();
  final launchPage = await reminder.initialize();
  runApp(
    QuranMemorizationApp(
      unit: AudioUnitController(settings: audio),
      plannerSettings: planner,
      log: log,
      savedPlans: savedPlans,
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
    this.savedPlans,
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

  /// Saved named plans for multiple estimations.
  final SavedPlans? savedPlans;

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
        savedPlans: widget.savedPlans,
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
    this.savedPlans,
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

  /// Saved named plans for multiple estimations.
  final SavedPlans? savedPlans;

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
  late SavedPlans _savedPlans;

  @override
  void initState() {
    super.initState();
    final active = widget.savedPlans?.active;
    _pageController = TextEditingController(
      text: '${active?.page ?? widget.settings.page}',
    )..addListener(_onChanged);
    _rateController = TextEditingController(
      text: _trimInput(active?.rate ?? widget.settings.rate),
    )..addListener(_onChanged);
    _rateMode = (active?.rateIsLines ?? widget.settings.rateIsLines)
        ? RateMode.lines
        : RateMode.fraction;
    _direction = active?.direction ?? widget.settings.direction;
    _restWeekdays = {...(active?.restWeekdays ?? widget.settings.restWeekdays)};
    _startDate = active?.startDate ?? widget.settings.startDate;
    _log = widget.log;
    _savedPlans = widget.savedPlans ?? SavedPlans(plans: [], activeIndex: 0);

    // Auto-migrate legacy PlannerSettings: if there are no saved plans but
    // the legacy settings differ from the defaults, create an "Hifz" plan
    // from them so the user’s existing progress is preserved.
    if (_savedPlans.isEmpty && _hasLegacySettings()) {
      final s = widget.settings;
      final from = SavedPlan(
        name: 'Hifz',
        page: s.page,
        rate: s.rate,
        rateIsLines: s.rateIsLines,
        direction: s.direction,
        restWeekdays: s.restWeekdays,
        startDate: s.startDate,
      );
      _savedPlans = _savedPlans.addPlan('Hifz', from: from);
      _savedPlans.save();
    }

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
    final page = _page ?? 1;
    final rate = _rate ?? 10;

    // Update the active saved plan if one exists.
    if (_savedPlans.active != null) {
      _savedPlans = _savedPlans.updateActive(
        page: page,
        rate: rate,
        rateIsLines: _rateMode == RateMode.lines,
        direction: _direction,
        restWeekdays: _restWeekdays,
        startDate: _startDate,
      );
      _savedPlans.save();
    }

    // Also save to the legacy PlannerSettings for backward compatibility.
    widget.settings
        .copyWith(
          page: page,
          rate: rate,
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

  /// Whether the legacy PlannerSettings has non-default values worth
  /// migrating. The defaults are page=1, rate=10, rateIsLines=true,
  /// direction=forward, no rest days, no start date.
  bool _hasLegacySettings() {
    final s = widget.settings;
    return s.page != 1 ||
        s.rate != 10 ||
        !s.rateIsLines ||
        s.direction != MemorizationDirection.forward ||
        s.restWeekdays.isNotEmpty ||
        s.startDate != null;
  }

  /// The planner's daily rate converted to text lines per day.
  double _effectiveLinesPerDay() {
    final pagesPerDay = _rateMode == RateMode.lines
        ? (_rate ?? 10) / MemorizationPlan.linesPerPage
        : (_rate ?? (2 / 3));
    return pagesPerDay * MemorizationPlan.linesPerPage;
  }

  /// Opens the mushaf viewer at the last saved page (from auto-save).
  Future<void> _openContinueReading() async {
    int lastPage;
    try {
      final prefs = await SharedPreferences.getInstance();
      lastPage = prefs.getInt('quran_last_page') ?? 0;
    } catch (_) {
      lastPage = 0;
    }
    if (lastPage < 1 || lastPage > 604) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved reading position yet.')),
      );
      return;
    }
    if (!mounted) return;
    final pagesPerDay = _rateMode == RateMode.lines
        ? (_rate ?? 10) / MemorizationPlan.linesPerPage
        : (_rate ?? (2 / 3));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PageViewerScreen(
          page: lastPage,
          linesPerDay: pagesPerDay * MemorizationPlan.linesPerPage,
          direction: _direction,
          unit: widget.unit,
          reminder: widget.reminder,
        ),
      ),
    );
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

  // -- Plan management --

  /// The date the user wants to finish memorization by, if set.
  DateTime? _targetDate;



  void _switchPlan(int index) {
    if (index == _savedPlans.activeIndex) return;
    setState(() {
      _savedPlans = _savedPlans.select(index);
      _loadPlanIntoFields(_savedPlans.active);
    });
    _savedPlans.save();
  }

  void _loadPlanIntoFields(SavedPlan? plan) {
    if (plan == null) return;
    _pageController.text = '${plan.page}';
    _pageController.selection = TextSelection.collapsed(
      offset: _pageController.text.length,
    );
    _rateController.text = _trimInput(plan.rate);
    _rateController.selection = TextSelection.collapsed(
      offset: _rateController.text.length,
    );
    _rateMode = plan.rateIsLines ? RateMode.lines : RateMode.fraction;
    _direction = plan.direction;
    _restWeekdays
      ..clear()
      ..addAll(plan.restWeekdays);
    _startDate = plan.startDate;
  }

  Widget _planChip(SavedPlan plan, int index, ColorScheme scheme) {
    final isSelected = index == _savedPlans.activeIndex;
    // Calculate progress for this plan.
    final remaining = plan.direction == MemorizationDirection.forward
        ? (MemorizationPlan.totalPages - plan.page + 1)
        : plan.page;
    final completed = MemorizationPlan.totalPages - remaining;
    final progress = (completed / MemorizationPlan.totalPages * 100).round();

    final isSynced = plan.syncGroup != null;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSynced)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(
                Icons.sync,
                size: 14,
                color: isSelected
                    ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                    : scheme.primary.withValues(alpha: 0.7),
              ),
            ),
          Text('${plan.name} '),
          Text(
            '$progress%',
            style: TextStyle(
              fontSize: 11,
              color: isSelected
                  ? scheme.onPrimaryContainer.withValues(alpha: 0.7)
                  : scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => _switchPlan(index),
    );
  }

  void _duplicateCurrentPlan() {
    final current = _savedPlans.active;
    if (current == null) return;
    final duplicate = SavedPlan(
      name: '${current.name} (copy)',
      page: current.page,
      rate: current.rate,
      rateIsLines: current.rateIsLines,
      direction: current.direction,
      restWeekdays: current.restWeekdays,
      startDate: current.startDate,
    );
    setState(() {
      _savedPlans = _savedPlans.addPlan(duplicate.name, from: duplicate);
    });
    _savedPlans.save();
  }

  Future<void> _createNewPlan() async {
    final name = await _showPlanNameDialog(
      title: 'New Plan',
      hint: 'e.g. Hifz, Mujawwad, Murajah',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    // Inherit the current UI state so the new plan starts where the user
    // already is, instead of resetting to defaults.
    final from = SavedPlan(
      name: name.trim(),
      page: _page ?? 1,
      rate: _rate ?? 10,
      rateIsLines: _rateMode == RateMode.lines,
      direction: _direction,
      restWeekdays: _restWeekdays,
      startDate: _startDate,
    );
    setState(() {
      _savedPlans = _savedPlans.addPlan(name.trim(), from: from);
    });
    _savedPlans.save();
  }

  Future<void> _renameCurrentPlan() async {
    final current = _savedPlans.active;
    if (current == null) return;
    final name = await _showPlanNameDialog(
      title: 'Rename Plan',
      initialValue: current.name,
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    setState(() {
      _savedPlans = _savedPlans.renamePlan(
        _savedPlans.activeIndex,
        name.trim(),
      );
    });
    _savedPlans.save();
  }

  void _deleteCurrentPlan() {
    final current = _savedPlans.active;
    if (current == null || _savedPlans.plans.length <= 1) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text('Delete "${current.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _savedPlans = _savedPlans.removePlan(_savedPlans.activeIndex);
                _loadPlanIntoFields(_savedPlans.active);
              });
              _savedPlans.save();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog to pick which plan to sync with (or unsync from).
  void _toggleSyncWithNext() {
    final current = _savedPlans.active;
    if (current == null) return;

    if (current.syncGroup != null) {
      // Currently synced → offer to unsync.
      setState(() {
        _savedPlans = _savedPlans.toggleSync(
          _savedPlans.activeIndex,
          otherIndex: _savedPlans.activeIndex,
        );
      });
      _savedPlans.save();
      return;
    }

    // Not synced → show picker to select which plan to sync with.
    final otherPlans = [
      for (var i = 0; i < _savedPlans.plans.length; i++)
        if (i != _savedPlans.activeIndex) (i, _savedPlans.plans[i].name),
    ];

    if (otherPlans.isEmpty) return;

    showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Sync with which plan?'),
        children: [
          for (final (idx, name) in otherPlans)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(idx),
              child: Row(
                children: [
                  Icon(
                    Icons.sync,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(name),
                ],
              ),
            ),
        ],
      ),
    ).then((otherIndex) {
      if (otherIndex == null || !mounted) return;
      setState(() {
        _savedPlans = _savedPlans.toggleSync(
          _savedPlans.activeIndex,
          otherIndex: otherIndex,
        );
      });
      _savedPlans.save();
    });
  }

  Future<String?> _showPlanNameDialog({
    required String title,
    String? hint,
    String? initialValue,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Plan name',
            hintText: hint,
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.of(context).pop(value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(context).pop(name);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
                // Plan selector
                _planSelectorCard(scheme),
                const SizedBox(height: 12),
                _continueReadingCard(scheme),
                const SizedBox(height: 12),
                if (_savedPlans.plans.length >= 2) ...[
                  _compareButton(scheme),
                  const SizedBox(height: 12),
                ],
                _motivationalQuoteCard(scheme),
                const SizedBox(height: 12),
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
                        _page != null
                            ? 'Juz ${MemorizationPlan.juzForPage(_page!)} · Standard Madani mushaf: 604 pages · 15 lines per page'
                            : 'Standard Madani mushaf: 604 pages · 15 lines per page',
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
                _goalCard(plan, scheme),
                const SizedBox(height: 16),
                _heatmapCard(scheme),
                const SizedBox(height: 16),
                _sessionHistoryCard(scheme),
                const SizedBox(height: 16),
                _estimationHintsCard(scheme),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Card that shows all saved plans with a selector and management actions.
  Widget _planSelectorCard(ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    final plans = _savedPlans.plans;

    // If no plans yet, show a prompt to create one.
    if (plans.isEmpty) {
      return Card(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.folder_open_outlined, color: scheme.primary, size: 32),
              const SizedBox(height: 8),
              Text(
                'No saved plans yet',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create a plan to save and switch between\nhifz, mujawwad, murajah, etc.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _createNewPlan,
                icon: const Icon(Icons.add),
                label: const Text('Create your first plan'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bookmark_outlined, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved Plans',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  tooltip: 'New plan',
                  onPressed: _createNewPlan,
                ),
                if (plans.length > 1)
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'Plan options',
                    onSelected: (value) {
                      if (value == 0) {
                        _renameCurrentPlan();
                      } else if (value == 1) {
                        _duplicateCurrentPlan();
                      } else if (value == 2) {
                        _toggleSyncWithNext();
                      } else if (value == 3) {
                        _deleteCurrentPlan();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 0,
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Rename'),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 1,
                        child: const ListTile(
                          leading: Icon(Icons.copy_outlined),
                          title: Text('Duplicate'),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 2,
                        child: ListTile(
                          leading: Icon(
                            _savedPlans.active?.syncGroup != null
                                ? Icons.sync_disabled
                                : Icons.sync,
                          ),
                          title: Text(
                            _savedPlans.active?.syncGroup != null
                                ? 'Unsync plan'
                                : 'Sync with another plan',
                          ),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 3,
                        enabled: plans.length > 1,
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline,
                            color: scheme.error,
                          ),
                          title: Text(
                            'Delete',
                            style: TextStyle(color: scheme.error),
                          ),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Plan chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < plans.length; i++)
                  _planChip(plans[i], i, scheme),
              ],
            ),
          ],
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

    // Sync other plans in the same group.
    final activeIndex = _savedPlans.activeIndex;
    final syncIndices = _savedPlans.syncGroupIndices(activeIndex);
    if (syncIndices.length > 1) {
      // Calculate page delta based on the active plan's direction.
      final pagesPerDay = _rateMode == RateMode.lines
          ? (_rate ?? 10) / MemorizationPlan.linesPerPage
          : (_rate ?? (2 / 3));
      final pageDelta = pagesPerDay.round();
      final linesDelta = _effectiveLinesPerDay();

      setState(() {
        _savedPlans = _savedPlans.syncGroupProgress(
          sourceIndex: activeIndex,
          pageDelta: pageDelta,
          linesDelta: linesDelta,
          sourceDirection: _direction,
        );
      });
      _savedPlans.save();

      // Reload fields if we switched plan state.
      _loadPlanIntoFields(_savedPlans.active);
    }
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
      title = 'Done today — barakallahu feek!'; // ‏ may Allah bless you
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
                            label: const Text("Mark today’s portion done"),
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
                  ? 'Alhamdulillah — the remaining ${_trim(remaining)} page${_trim(remaining) == '1' ? '' : 's'} fit in one session.'
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

  // ── Continue Reading ─────────────────────────────────────────────

  /// Card that shows the last saved reading position and opens the viewer.
  Widget _continueReadingCard(ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: scheme.primary.withValues(alpha: 0.25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openContinueReading,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.play_circle_fill_rounded,
                color: scheme.primary,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue reading',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pick up where you left off in the mushaf',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Plan comparison ──────────────────────────────────────────────

  /// Button that opens the comparison bottom sheet.
  Widget _compareButton(ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openComparisonSheet,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.compare_arrows, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Compare plans',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the bottom sheet with a side-by-side comparison of two plans.
  Future<void> _openComparisonSheet() async {
    final plans = _savedPlans.plans;
    if (plans.length < 2) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ComparisonSheet(
        plans: plans,
        activeIndex: _savedPlans.activeIndex,
      ),
    );
  }

  // ── Motivational quote card ──────────────────────────────────────

  /// Rotating Quran verse or hadith quote that changes each time the
  /// app is opened, providing spiritual encouragement.
  Widget _motivationalQuoteCard(ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    final quote = rotatingQuote();

    return Card(
      elevation: 0,
      color: scheme.tertiaryContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  quote.isHadith ? Icons.auto_stories : Icons.format_quote,
                  color: scheme.onTertiaryContainer.withValues(alpha: 0.7),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  quote.isHadith ? 'Hadith' : 'Qur\u02ban',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onTertiaryContainer.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  quote.reference,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onTertiaryContainer.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            if (quote.arabic.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                quote.arabic,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 18,
                  height: 1.8,
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              quote.translation,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onTertiaryContainer.withValues(alpha: 0.9),
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
            if (quote.narrator != null) ...[
              const SizedBox(height: 4),
              Text(
                quote.narrator!,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onTertiaryContainer.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Goal card ──────────────────────────────────────────────────────

  /// Lets the user pick a target finish date and shows the required pace.
  Widget _goalCard(MemorizationPlan? plan, ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    final page = _page;
    if (page == null) return const SizedBox.shrink();

    final targetDate = _targetDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate what's needed.
    final remaining = _direction == MemorizationDirection.forward
        ? (MemorizationPlan.totalPages - page + 1).toDouble()
        : page.toDouble();
    String? requiredPace;
    if (targetDate != null) {
      final daysLeft = targetDate.difference(today).inDays;
      if (daysLeft > 0) {
        final pagesPerDay = remaining / daysLeft;
        final linesPerDay = pagesPerDay * MemorizationPlan.linesPerPage;
        requiredPace =
            '${_trim(pagesPerDay)} pages/day (${_trim(linesPerDay)} lines/day)';
      }
    }

    final isSet = targetDate != null;
    final daysUntil = isSet ? targetDate.difference(today).inDays : 0;
    final isPast = isSet && daysUntil < 0;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flag,
                  color: isSet ? scheme.primary : scheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Finish by',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isSet)
                  TextButton(
                    onPressed: () {
                      setState(() => _targetDate = null);
                    },
                    child: const Text('Clear'),
                  ),
                FilledButton.tonal(
                  onPressed: _pickTargetDate,
                  child: Text(isSet ? 'Change' : 'Set a target'),
                ),
              ],
            ),
            if (!isSet) ...[
              const SizedBox(height: 4),
              Text(
                'Set a target date to see the pace needed to finish on time.',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (isSet) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _goalStat(
                    formatDate(targetDate),
                    'Target date',
                    scheme,
                    isError: isPast,
                  ),
                  const SizedBox(width: 12),
                  _goalStat(
                    isPast
                        ? 'Overdue by ${-daysUntil} day${daysUntil == -1 ? '' : 's'}'
                        : daysUntil == 0
                        ? 'Today!'
                        : '$daysUntil day${daysUntil == 1 ? '' : 's'} left',
                    'Time remaining',
                    scheme,
                    isError: isPast,
                    isHighlight: daysUntil >= 0 && daysUntil <= 30,
                  ),
                ],
              ),
              if (requiredPace != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPast
                        ? scheme.errorContainer
                        : scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPast ? Icons.warning_amber : Icons.speed,
                        size: 18,
                        color: isPast
                            ? scheme.onErrorContainer
                            : scheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isPast
                              ? 'Target date is in the past'
                              : 'Required pace: $requiredPace',
                          style: textTheme.bodyMedium?.copyWith(
                            color: isPast
                                ? scheme.onErrorContainer
                                : scheme.onTertiaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPast)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton.tonal(
                      onPressed: () => _applyGoalPace(),
                      child: const Text('Apply this pace to my plan'),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _goalStat(String value, String label, ColorScheme scheme,
      {bool isError = false, bool isHighlight = false}) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isError
                  ? scheme.error
                  : isHighlight
                  ? scheme.primary
                  : null,
            ),
          ),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _applyGoalPace() {
    final page = _page;
    final targetDate = _targetDate;
    if (page == null || targetDate == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysLeft = targetDate.difference(today).inDays;
    if (daysLeft <= 0) return;
    final remaining = _direction == MemorizationDirection.forward
        ? (MemorizationPlan.totalPages - page + 1).toDouble()
        : page.toDouble();
    final pagesPerDay = remaining / daysLeft;
    _applyPace(pagesPerDay);
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _targetDate ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      helpText: 'When do you want to finish?',
    );
    if (picked != null && mounted) {
      setState(() => _targetDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  // ── Heatmap card ───────────────────────────────────────────────────

  /// GitHub-style mini heatmap showing memorization days over the last 28 days.
  Widget _heatmapCard(ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Last 28 days (4 weeks).
    final days = <DateTime>[];
    for (var i = 27; i >= 0; i--) {
      days.add(DateTime(today.year, today.month, today.day - i));
    }

    // Map of date → session lines (0 if no session).
    final sessionMap = <DateTime, double>{};
    for (final s in _log.sessions) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      sessionMap[d] = (sessionMap[d] ?? 0) + s.lines;
    }

    // Find max lines for intensity scaling.
    var maxLines = 0.0;
    for (final v in sessionMap.values) {
      if (v > maxLines) maxLines = v;
    }

    final activeDays = sessionMap.length;
    final totalDaysInPeriod = 28;
    final completionRate = ((activeDays / totalDaysInPeriod) * 100).round();

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Last 4 weeks',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$completionRate% days active',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 4 rows × 7 columns grid.
            for (var row = 0; row < 4; row++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      _heatmapCell(
                        days[row * 7 + col],
                        sessionMap,
                        maxLines,
                        scheme,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            // Day labels.
            Row(
              children: [
                for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heatmapCell(
    DateTime date,
    Map<DateTime, double> sessions,
    double maxLines,
    ColorScheme scheme,
  ) {
    final lines = sessions[date] ?? 0;
    final hasSession = lines > 0;
    final intensity = maxLines > 0 ? (lines / maxLines).clamp(0.2, 1.0) : 0.0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = date == today;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: Tooltip(
          message:
              '${date.month}/${date.day}${hasSession ? ' \u2014 ${_trim(lines)} lines' : ''}',
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              color: hasSession
                  ? scheme.primary.withValues(alpha: intensity)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
              border: isToday
                  ? Border.all(color: scheme.primary, width: 1.5)
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  // ── Session history card ───────────────────────────────────────────

  /// Scrollable list of recent memorization sessions.
  Widget _sessionHistoryCard(ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    final sessions = _log.allSessions;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Session history',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (sessions.isNotEmpty)
                  Text(
                    '${sessions.length} session${sessions.length == 1 ? '' : 's'}',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (sessions.isEmpty)
              Text(
                'No sessions recorded yet. Mark your first day done above!',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              ...sessions.take(14).map((s) => _sessionRow(s, scheme)),
            if (sessions.length > 14)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '… and ${sessions.length - 14} more',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sessionRow(MemorizationSession s, ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _shortDate(s.date),
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            'page ${s.page}',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_trim(s.lines)} lines',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Common memorization paces with estimated finish times, so the user
  /// can quickly see "if I memorize at this rate, when will I finish?".
  Widget _estimationHintsCard(ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    final page = _page;
    if (page == null) return const SizedBox.shrink();

    // (label, pagesPerDay) — common memorization paces.
    final hints = [
      ('1 page / day', 1.0),
      ('Half page / salah', 2.5),
      ('2 pages / day', 2.0),
      ('1 juz / week', 2.86),
      ('1 page / salah', 5.0),
      ('1 juz / 3 days', 6.67),
      ('1 surah / day', 5.3),
      ('2 pages / salah', 10.0),
      ('1 page before & after salah', 10.0),
      ('3 pages / salah', 15.0),
      ('2 pages before & after salah', 20.0),
      ('5 pages / salah', 25.0),
      ('3 pages before & after salah', 30.0),
      ('1 juz / day', 20.13),
      ('10 pages / salah', 50.0),
    ];

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
                Icon(Icons.speed_outlined, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Quick estimates',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a pace to apply it to your plan',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final (label, pace) in hints) ...[
              _hintRow(label, pace, page, scheme),
              if (label != hints.last.$1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  /// A single row in the estimation hints card: pace label on the left,
  /// "finish in X days" with the actual date on the right.
  /// Whether the given pace matches the current planner rate (pages/day).
  bool _isCurrentPace(double pagesPerDay) {
    final rate = _rate;
    if (rate == null) return false;
    final currentPagesPerDay = _rateMode == RateMode.lines
        ? rate / MemorizationPlan.linesPerPage
        : rate;
    // Allow a small tolerance for floating-point comparison.
    return (currentPagesPerDay - pagesPerDay).abs() < 0.05;
  }

  /// Applies the selected pace to the planner: sets rate mode to fraction
  /// (pages/day) and the rate to the given value.
  void _applyPace(double pagesPerDay) {
    setState(() {
      _rateMode = RateMode.fraction;
      _rateController.text = _trimInput(pagesPerDay);
      _rateController.selection = TextSelection.collapsed(
        offset: _rateController.text.length,
      );
    });
    _saveSettings();
  }

  Widget _hintRow(
    String label,
    double pagesPerDay,
    int currentPage,
    ColorScheme scheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final plan = MemorizationPlan(
      currentPage: currentPage,
      pagesPerDay: pagesPerDay,
      restWeekdays: _restWeekdays,
      startDate: _startDate,
      direction: _direction,
    );
    final result = plan.compute();
    final days = result.calendarDays;
    final isDone = days <= 0;
    final selected = _isCurrentPace(pagesPerDay);

    return InkWell(
      onTap: () => _applyPace(pagesPerDay),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.4)
              : null,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: scheme.primary.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          children: [
            if (selected)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.check_circle,
                  size: 16,
                  color: scheme.primary,
                ),
              ),
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? scheme.primary : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isDone
                  ? 'done'
                  : 'finish in ${days == 1 ? '1 day' : '$days days'}',
              style: textTheme.bodyMedium?.copyWith(
                color: isDone ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: isDone ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isDone ? '' : formatDate(result.finishDate),
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Comparison bottom sheet ────────────────────────────────────────

class _ComparisonSheet extends StatefulWidget {
  const _ComparisonSheet({
    required this.plans,
    required this.activeIndex,
  });

  final List<SavedPlan> plans;
  final int activeIndex;

  @override
  State<_ComparisonSheet> createState() => _ComparisonSheetState();
}

class _ComparisonSheetState extends State<_ComparisonSheet> {
  late int _planA;
  late int _planB;
  final GlobalKey _captureKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _planA = widget.activeIndex;
    // Pick the next plan as plan B, or the first if active is the last.
    _planB = (widget.activeIndex + 1) % widget.plans.length;
  }

  /// Builds a MemorizationPlan from a SavedPlan, returning null on invalid.
  MemorizationPlan? _buildPlan(SavedPlan saved) {
    final pagesPerDay = saved.rateIsLines
        ? saved.rate / MemorizationPlan.linesPerPage
        : saved.rate;
    try {
      return MemorizationPlan(
        currentPage: saved.page,
        pagesPerDay: pagesPerDay,
        restWeekdays: saved.restWeekdays,
        startDate: saved.startDate,
        direction: saved.direction,
      );
    } on ArgumentError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final planAData = widget.plans[_planA];
    final planBData = widget.plans[_planB];
    final planA = _buildPlan(planAData);
    final planB = _buildPlan(planBData);
    final resultA = planA?.compute();
    final resultB = planB?.compute();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Scaffold(
        appBar: AppBar(
          title: const Text('Compare Plans'),
          centerTitle: false,
          actions: [
            if (!_sharing)
              PopupMenuButton<String>(
                icon: const Icon(Icons.share),
                tooltip: 'Share comparison',
                onSelected: (value) {
                  if (value == 'image') _shareAsImage();
                  if (value == 'pdf') _shareAsPdf();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'image',
                    child: ListTile(
                      leading: Icon(Icons.image_outlined),
                      title: Text('Share as Image'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'pdf',
                    child: ListTile(
                      leading: Icon(Icons.picture_as_pdf),
                      title: Text('Share as PDF'),
                      dense: true,
                    ),
                  ),
                ],
              ),
            if (_sharing)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        body: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // Plan selectors
            Row(
              children: [
                Expanded(
                  child: _planDropdown(
                    label: 'Plan A',
                    value: _planA,
                    onChanged: (v) => setState(() => _planA = v!),
                    scheme: scheme,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.compare_arrows,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: _planDropdown(
                    label: 'Plan B',
                    value: _planB,
                    onChanged: (v) => setState(() => _planB = v!),
                    scheme: scheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Wrap comparison content in RepaintBoundary for image capture
            RepaintBoundary(
              key: _captureKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header for the captured image
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.compare_arrows, color: scheme.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Text(
                          'Plan Comparison',
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

            // Side-by-side stats
            if (planA == null || planB == null)
              Card(
                elevation: 0,
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'One or both plans have invalid settings. '
                    'Check page numbers and daily rates.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              )
            else ...[
              _comparisonRow(
                'Start page',
                '${planAData.page}',
                '${planBData.page}',
                scheme,
                isPage: true,
              ),
              _comparisonRow(
                'Direction',
                planAData.direction == MemorizationDirection.forward
                    ? 'Forward'
                    : 'Backward',
                planBData.direction == MemorizationDirection.forward
                    ? 'Forward'
                    : 'Backward',
                scheme,
              ),
              _comparisonRow(
                'Daily rate',
                _formatRate(planAData),
                _formatRate(planBData),
                scheme,
              ),
              _comparisonRow(
                'Rest days',
                planAData.restWeekdays.isEmpty
                    ? 'None'
                    : '${planAData.restWeekdays.length} days/week',
                planBData.restWeekdays.isEmpty
                    ? 'None'
                    : '${planBData.restWeekdays.length} days/week',
                scheme,
              ),
              _comparisonRow(
                'Start date',
                planAData.startDate == null
                    ? 'Today'
                    : formatDate(planAData.startDate!),
                planBData.startDate == null
                    ? 'Today'
                    : formatDate(planBData.startDate!),
                scheme,
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              // Finish date comparison
              _comparisonRow(
                'Finish date',
                formatDate(resultA!.finishDate),
                formatDate(resultB!.finishDate),
                scheme,
                isHighlight: true,
              ),
              _comparisonRow(
                'Calendar days',
                '${resultA.calendarDays}',
                '${resultB.calendarDays}',
                scheme,
              ),
              _comparisonRow(
                'Study sessions',
                '${resultA.studyDays}',
                '${resultB.studyDays}',
                scheme,
              ),
              _comparisonRow(
                'Pages remaining',
                _trim(planA.remainingPages),
                _trim(planB.remainingPages),
                scheme,
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              // Progress
              _comparisonRow(
                'Progress',
                '${(planA.progressBeforeCurrentPage * 100).round()}%',
                '${(planB.progressBeforeCurrentPage * 100).round()}%',
                scheme,
                isHighlight: true,
              ),

              // Winner badge
              const SizedBox(height: 16),
              _winnerBadge(
                planA: planA,
                planB: planB,
                nameA: planAData.name,
                nameB: planBData.name,
                scheme: scheme,
                textTheme: textTheme,
              ),
            ],
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Captures the comparison content as an image and shares it.
  Future<void> _shareAsImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _sharing = false);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        setState(() => _sharing = false);
        return;
      }

      // Draw a watermark on the captured image.
      final buffer = await _addWatermark(
        byteData.buffer.asUint8List(),
        image.width,
        image.height,
      );

      // Share using share_plus v10 API.
      final xFile = XFile.fromData(
        buffer,
        mimeType: 'image/png',
        name: 'plan_comparison.png',
      );

      await Share.shareXFiles(
        [xFile],
        subject: 'Plan Comparison',
        text: 'Check out my Quran memorization plan comparison!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Adds a semi-transparent watermark to the bottom-right of the image.
  Future<Uint8List> _addWatermark(Uint8List pngBytes, int width, int height) async {
    // Decode the PNG into a ui.Image.
    final codec = await ui.instantiateImageCodec(pngBytes);
    final frame = await codec.getNextFrame();
    final originalImage = frame.image;

    // Create a new picture to draw on.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw the original image.
    canvas.drawImage(originalImage, Offset.zero, Paint());

    // Draw the watermark.
    final watermarkText = 'Hifz Planner';
    final textStyle = TextStyle(
      color: const Color(0x66FFFFFF), // 40% white opacity
      fontSize: width * 0.025,
      fontWeight: FontWeight.w600,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: watermarkText, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Position in the bottom-right corner with padding.
    final padding = width * 0.03;
    final textX = width - textPainter.width - padding;
    final textY = height - textPainter.height - padding;

    // Draw a semi-transparent background pill behind the text.
    final bgPaint = Paint()
      ..color = const Color(0x44000000) // 25% black opacity
      ..style = PaintingStyle.fill;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        textX - 8,
        textY - 4,
        textPainter.width + 16,
        textPainter.height + 8,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(bgRect, bgPaint);

    // Draw the watermark text.
    textPainter.paint(canvas, Offset(textX, textY));

    // Convert back to an image and then to PNG bytes.
    final outputImage = await recorder.endRecording().toImage(width, height);
    final outputByteData = await outputImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    originalImage.dispose();
    outputImage.dispose();

    return outputByteData!.buffer.asUint8List();
  }

  /// Generates a PDF of the comparison and shares it.
  Future<void> _shareAsPdf() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final planAData = widget.plans[_planA];
      final planBData = widget.plans[_planB];
      final planA = _buildPlan(planAData);
      final planB = _buildPlan(planBData);
      final resultA = planA?.compute();
      final resultB = planB?.compute();

      // Load the logo image from assets.
      final logoBytes = await rootBundle.load('assets/logo.png');
      final logoImage = pw.MemoryImage(
        logoBytes.buffer.asUint8List(),
      );

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey500,
              ),
            ),
          ),
          build: (context) => [
            // Branded header
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 16),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.teal700, width: 2),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      // App logo
                      pw.ClipRRect(
                        horizontalRadius: 8,
                        verticalRadius: 8,
                        child: pw.Image(
                          logoImage,
                          width: 36,
                          height: 36,
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Hifz Planner',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.teal700,
                              ),
                            ),
                            pw.Text(
                              'Quran Memorization Plan Comparison',
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Date badge
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          borderRadius: pw.BorderRadius.circular(12),
                        ),
                        child: pw.Text(
                          formatDate(DateTime.now()),
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  // Plan names
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.teal50,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'Plan A',
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.grey600,
                                ),
                              ),
                              pw.Text(
                                planAData.name,
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.teal700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Text(
                        'vs',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey500,
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.teal50,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'Plan B',
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.grey600,
                                ),
                              ),
                              pw.Text(
                                planBData.name,
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.teal700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Settings comparison table
            pw.Header(
              level: 1,
              child: pw.Text('Settings', style: pw.TextStyle(fontSize: 16)),
            ),
            pw.SizedBox(height: 8),
            _pdfComparisonTable(
              headers: ['', planAData.name, planBData.name],
              rows: [
                ['Start page', '${planAData.page}', '${planBData.page}'],
                ['Direction',
                  planAData.direction == MemorizationDirection.forward ? 'Forward' : 'Backward',
                  planBData.direction == MemorizationDirection.forward ? 'Forward' : 'Backward'],
                ['Daily rate', _formatRate(planAData), _formatRate(planBData)],
                ['Rest days',
                  planAData.restWeekdays.isEmpty ? 'None' : '${planAData.restWeekdays.length} days/week',
                  planBData.restWeekdays.isEmpty ? 'None' : '${planBData.restWeekdays.length} days/week'],
                ['Start date',
                  planAData.startDate == null ? 'Today' : formatDate(planAData.startDate!),
                  planBData.startDate == null ? 'Today' : formatDate(planBData.startDate!)],
              ],
            ),
            pw.SizedBox(height: 16),

            // Results comparison table
            if (planA != null && planB != null && resultA != null && resultB != null) ...[
              pw.Header(
                level: 1,
                child: pw.Text('Results', style: pw.TextStyle(fontSize: 16)),
              ),
              pw.SizedBox(height: 8),
              _pdfComparisonTable(
                headers: ['', planAData.name, planBData.name],
                rows: [
                  ['Finish date', formatDate(resultA.finishDate), formatDate(resultB.finishDate)],
                  ['Calendar days', '${resultA.calendarDays}', '${resultB.calendarDays}'],
                  ['Study sessions', '${resultA.studyDays}', '${resultB.studyDays}'],
                  ['Pages remaining', _trim(planA.remainingPages), _trim(planB.remainingPages)],
                  ['Progress',
                    '${(planA.progressBeforeCurrentPage * 100).round()}%',
                    '${(planB.progressBeforeCurrentPage * 100).round()}%'],
                ],
              ),
              pw.SizedBox(height: 16),

              // Winner
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  children: [
                    pw.Icon(pw.IconData(0xe5ca), size: 16), // emoji_events
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(
                        _winnerMessage(planA, planB, planAData.name, planBData.name),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Footer with branding (on last page)
            pw.SizedBox(height: 32),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated by Hifz Planner',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
                pw.Text(
                  'mhobgstudio.github.io/quran-memorization',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.teal600,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final bytes = await pdf.save();

      final xFile = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: 'plan_comparison.pdf',
      );

      await Share.shareXFiles(
        [xFile],
        subject: 'Plan Comparison',
        text: 'Check out my Quran memorization plan comparison!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Builds a PDF comparison table.
  pw.Widget _pdfComparisonTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignment: pw.Alignment.center,
      headerAlignment: pw.Alignment.center,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellHeight: 24,
      headerHeight: 28,
      border: pw.TableBorder(
        horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
      headers: headers,
      data: rows,
    );
  }

  /// Generates the winner message for PDF export.
  static String _winnerMessage(
    MemorizationPlan planA,
    MemorizationPlan planB,
    String nameA,
    String nameB,
  ) {
    final resultA = planA.compute();
    final resultB = planB.compute();
    final aFinishesFirst = resultA.finishDate.isBefore(resultB.finishDate);
    final sameFinish = resultA.finishDate == resultB.finishDate;

    if (sameFinish) return 'Both plans finish on the same date.';
    if (aFinishesFirst) {
      final diff = resultB.finishDate.difference(resultA.finishDate).inDays;
      return '$nameA finishes $diff day${diff == 1 ? '' : 's'} before $nameB.';
    } else {
      final diff = resultA.finishDate.difference(resultB.finishDate).inDays;
      return '$nameB finishes $diff day${diff == 1 ? '' : 's'} before $nameA.';
    }
  }

  Widget _planDropdown({
    required String label,
    required int value,
    required ValueChanged<int?> onChanged,
    required ColorScheme scheme,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        for (var i = 0; i < widget.plans.length; i++)
          DropdownMenuItem(
            value: i,
            child: Text(widget.plans[i].name),
          ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _comparisonRow(
    String label,
    String valueA,
    String valueB,
    ColorScheme scheme, {
    bool isHighlight = false,
    bool isPage = false,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isHighlight
                    ? scheme.primaryContainer.withValues(alpha: 0.5)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                valueA,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isHighlight
                    ? scheme.primaryContainer.withValues(alpha: 0.5)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                valueB,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows which plan finishes first or has the most progress.
  Widget _winnerBadge({
    required MemorizationPlan planA,
    required MemorizationPlan planB,
    required String nameA,
    required String nameB,
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    final resultA = planA.compute();
    final resultB = planB.compute();
    final aFinishesFirst = resultA.finishDate.isBefore(resultB.finishDate);
    final sameFinish = resultA.finishDate == resultB.finishDate;

    String message;
    if (sameFinish) {
      message = 'Both plans finish on the same date.';
    } else if (aFinishesFirst) {
      final diff = resultB.finishDate.difference(resultA.finishDate).inDays;
      message = '$nameA finishes $diff day${diff == 1 ? '' : 's'} before $nameB.';
    } else {
      final diff = resultA.finishDate.difference(resultB.finishDate).inDays;
      message = '$nameB finishes $diff day${diff == 1 ? '' : 's'} before $nameA.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sameFinish
            ? scheme.secondaryContainer
            : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            sameFinish ? Icons.handshake : Icons.emoji_events,
            color: sameFinish
                ? scheme.onSecondaryContainer
                : scheme.onPrimaryContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: sameFinish
                    ? scheme.onSecondaryContainer
                    : scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRate(SavedPlan plan) {
    if (plan.rateIsLines) {
      final pagesPerDay = plan.rate / MemorizationPlan.linesPerPage;
      return '${plan.rate} lines/day (${pagesPerDay.toStringAsFixed(1)} pages)';
    }
    return '${plan.rate} pages/day (${(plan.rate * MemorizationPlan.linesPerPage).toStringAsFixed(0)} lines)';
  }

  static String _trim(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  }
}
