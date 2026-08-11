import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'memorization_calc.dart';

void main() {
  runApp(const QuranMemorizationApp());
}

class QuranMemorizationApp extends StatelessWidget {
  const QuranMemorizationApp({super.key});

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
      home: const PlannerScreen(),
    );
  }
}

enum RateMode { lines, fraction }

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _pageController = TextEditingController(text: '1');
  final _rateController = TextEditingController(text: '10');
  RateMode _rateMode = RateMode.lines;
  final Set<int> _restWeekdays = {};

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onChanged);
    _rateController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _rateController.dispose();
    super.dispose();
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
            )
          : MemorizationPlan(
              currentPage: page,
              pagesPerDay: rate,
              restWeekdays: _restWeekdays,
            );
    } on ArgumentError {
      return null;
    }
  }

  void _stepPage(int delta) {
    final current = _page ?? 1;
    final next = (current + delta).clamp(1, MemorizationPlan.totalPages);
    _pageController.text = '$next';
    _pageController.selection = TextSelection.collapsed(
      offset: _pageController.text.length,
    );
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
      ),
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
                        onChanged: (value) {
                          _pageController.text =
                              value.round().clamp(1, 604).toString();
                          _pageController.selection = TextSelection.collapsed(
                            offset: _pageController.text.length,
                          );
                        },
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
                              keyboardType: const TextInputType.numberWithOptions(
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

  bool _rateInputInvalid() {
    final raw = _rateController.text.trim();
    return raw.isNotEmpty &&
        (double.tryParse(raw.replaceAll(',', '.')) == null ||
            double.parse(raw.replaceAll(',', '.')) <= 0);
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
  }) {
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
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
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
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
      DateTime(plan.startDate.year, plan.startDate.month, plan.startDate.day + 1),
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
            const SizedBox(height: 8),
            Text(
              isDone
                  ? 'You finish today'
                  : formatDate(result.finishDate),
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
                backgroundColor:
                    scheme.onPrimaryContainer.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statBlock(
                  '${_trim(remaining)} pages',
                  'remaining',
                  scheme,
                ),
                _statBlock(
                  '${result.studyDays}',
                  'study sessions',
                  scheme,
                ),
                _statBlock(
                  '${result.calendarDays}',
                  'calendar days',
                  scheme,
                ),
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
