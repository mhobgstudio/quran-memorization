import 'package:shared_preferences/shared_preferences.dart';

import '../memorization_calc.dart' show MemorizationDirection;

/// A named memorization plan that can be saved, loaded, and switched between.
///
/// Each plan stores the same settings as [PlannerSettings] but is identified
/// by a user-chosen name (e.g. "Hifz", "Mujawwad", "Murajah").
class SavedPlan {
  const SavedPlan({
    required this.name,
    this.page = 1,
    this.rate = 10,
    this.rateIsLines = true,
    this.direction = MemorizationDirection.forward,
    this.restWeekdays = const {},
    this.startDate,
  });

  /// User-chosen name for this plan.
  final String name;

  /// Current page being memorized (1-604).
  final int page;

  /// Daily rate: lines per day when [rateIsLines], else fraction of a page.
  final double rate;

  /// Whether [rate] means lines-per-day (true) or pages-per-day (false).
  final bool rateIsLines;

  /// Whether memorization runs page 1 → 604 or 604 → 1.
  final MemorizationDirection direction;

  /// Weekdays (DateTime.weekday: 1=Mon .. 7=Sun) the user rests.
  final Set<int> restWeekdays;

  /// When the plan starts (date only); null means today.
  final DateTime? startDate;

  SavedPlan copyWith({
    String? name,
    int? page,
    double? rate,
    bool? rateIsLines,
    MemorizationDirection? direction,
    Set<int>? restWeekdays,
    DateTime? startDate,
    bool clearStartDate = false,
  }) {
    return SavedPlan(
      name: name ?? this.name,
      page: page ?? this.page,
      rate: rate ?? this.rate,
      rateIsLines: rateIsLines ?? this.rateIsLines,
      direction: direction ?? this.direction,
      restWeekdays: restWeekdays ?? this.restWeekdays,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
    );
  }

  /// Encodes this plan to a compact string for storage.
  ///
  /// Format: "name|page|rate|rateIsLines|direction|restWeekdays|startDate"
  String encode() {
    final y = startDate?.year.toString().padLeft(4, '0') ?? '';
    final m = startDate?.month.toString().padLeft(2, '0') ?? '';
    final d = startDate?.day.toString().padLeft(2, '0') ?? '';
    final startStr = y.isEmpty ? '' : '$y-$m-$d';
    final restStr = restWeekdays.map((w) => '$w').toList()..sort();
    return [
      name,
      page.toString(),
      rate.toStringAsFixed(4),
      rateIsLines ? '1' : '0',
      direction.name,
      restStr.join(','),
      startStr,
    ].join('|');
  }

  /// Decodes a plan from a previously encoded string.
  static SavedPlan? decode(String raw) {
    final parts = raw.split('|');
    if (parts.length < 7) return null;
    final name = parts[0];
    final page = int.tryParse(parts[1]);
    final rate = double.tryParse(parts[2]);
    final rateIsLines = parts[3] == '1';
    final direction = MemorizationDirection.values.firstWhere(
      (d) => d.name == parts[4],
      orElse: () => MemorizationDirection.forward,
    );
    final restWeekdays = parts[5]
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .where((w) => w >= 1 && w <= 7)
        .toSet();
    DateTime? startDate;
    if (parts[6].isNotEmpty) {
      final dateParts = parts[6].split('-');
      if (dateParts.length == 3) {
        final y = int.tryParse(dateParts[0]);
        final m = int.tryParse(dateParts[1]);
        final d = int.tryParse(dateParts[2]);
        if (y != null && m != null && d != null) {
          startDate = DateTime(y, m, d);
        }
      }
    }
    if (page == null || rate == null) return null;
    return SavedPlan(
      name: name,
      page: page.clamp(1, 604),
      rate: rate,
      rateIsLines: rateIsLines,
      direction: direction,
      restWeekdays: restWeekdays,
      startDate: startDate,
    );
  }
}

/// Manages multiple named memorization plans, persisted in SharedPreferences.
///
/// Plans are stored as a list of encoded strings under the `plans.list` key.
/// The index of the currently active plan is stored under `plans.activeIndex`.
class SavedPlans {
  SavedPlans({
    required List<SavedPlan> plans,
    this.activeIndex = 0,
  })  : plans = List.unmodifiable(plans),
        assert(
          plans.isEmpty || (activeIndex >= 0 && activeIndex < plans.length),
          'activeIndex must be within bounds',
        );

  /// All saved plans.
  final List<SavedPlan> plans;

  /// Index of the currently selected plan.
  final int activeIndex;

  /// The currently active plan, or null if no plans exist.
  SavedPlan? get active =>
      plans.isEmpty ? null : plans[activeIndex.clamp(0, plans.length - 1)];

  /// Whether there are any saved plans.
  bool get isEmpty => plans.isEmpty;

  /// Number of saved plans.
  int get length => plans.length;

  /// Creates a new plan with the given name, adds it to the list, and
  /// returns a new [SavedPlans] with the new plan selected.
  SavedPlans addPlan(String name, {SavedPlan? from}) {
    final newPlan = from ?? SavedPlan(name: name);
    final updated = List<SavedPlan>.from(plans)..add(newPlan);
    return SavedPlans(plans: updated, activeIndex: updated.length - 1);
  }

  /// Removes the plan at [index] and returns a new [SavedPlans].
  /// If the removed plan was active, the selection shifts to the nearest plan.
  SavedPlans removePlan(int index) {
    final updated = List<SavedPlan>.from(plans)..removeAt(index);
    if (updated.isEmpty) {
      return SavedPlans(plans: [], activeIndex: 0);
    }
    final newIndex = activeIndex >= updated.length
        ? updated.length - 1
        : activeIndex;
    return SavedPlans(plans: updated, activeIndex: newIndex);
  }

  /// Renames the plan at [index] and returns a new [SavedPlans].
  SavedPlans renamePlan(int index, String newName) {
    final updated = List<SavedPlan>.from(plans);
    updated[index] = updated[index].copyWith(name: newName);
    return SavedPlans(plans: updated, activeIndex: activeIndex);
  }

  /// Updates the settings of the currently active plan and returns
  /// a new [SavedPlans].
  SavedPlans updateActive({
    int? page,
    double? rate,
    bool? rateIsLines,
    MemorizationDirection? direction,
    Set<int>? restWeekdays,
    DateTime? startDate,
    bool clearStartDate = false,
  }) {
    final current = active;
    if (current == null) return this;
    final updated = List<SavedPlan>.from(plans);
    updated[activeIndex] = current.copyWith(
      page: page,
      rate: rate,
      rateIsLines: rateIsLines,
      direction: direction,
      restWeekdays: restWeekdays,
      startDate: startDate,
      clearStartDate: clearStartDate,
    );
    return SavedPlans(plans: updated, activeIndex: activeIndex);
  }

  /// Switches to the plan at [index] and returns a new [SavedPlans].
  SavedPlans select(int index) {
    if (index < 0 || index >= plans.length) return this;
    return SavedPlans(plans: plans, activeIndex: index);
  }

  // -- Persistence keys --

  static const _kList = 'plans.list';
  static const _kActiveIndex = 'plans.activeIndex';

  /// Loads all saved plans from SharedPreferences.
  static Future<SavedPlans> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kList) ?? const [];
    final plans = raw
        .map(SavedPlan.decode)
        .whereType<SavedPlan>()
        .toList();
    final activeIndex = prefs.getInt(_kActiveIndex) ?? 0;
    return SavedPlans(
      plans: plans,
      activeIndex: plans.isEmpty ? 0 : activeIndex.clamp(0, plans.length - 1),
    );
  }

  /// Persists all plans and the active index.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kList,
      plans.map((p) => p.encode()).toList(),
    );
    await prefs.setInt(_kActiveIndex, activeIndex);
  }
}
