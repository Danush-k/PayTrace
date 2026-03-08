import '../../data/database/app_database.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  SPENDING INSIGHTS ENGINE
//
//  Produces five structured insight objects from a flat list of transactions.
//  All computation is pure Dart — no DB calls — so it can be run on a
//  background isolate if needed.
//
//  Insight types:
//    1. CategoryDistribution  — total + pct per category
//    2. TopMerchants          — merchants ranked by total spend
//    3. DailyAverage          — mean, peak day, weekday heat
//    4. WeeklyComparison      — this week vs last week (daily breakdown)
//    5. TimeOfDay             — hourly spend / peak session
// ═══════════════════════════════════════════════════════════════════════════

class SpendingInsightsEngine {
  SpendingInsightsEngine._();

  /// Run all five analyses in one pass.
  ///
  /// Only considers successful DEBIT transactions. CREDIT / INITIATED /
  /// FAILURE rows are silently ignored.
  static SpendingInsightsResult analyze({
    required List<Transaction> transactions,
  }) {
    final debits = transactions
        .where((t) => t.status == 'SUCCESS' && t.direction == 'DEBIT')
        .toList();

    return SpendingInsightsResult(
      categoryDistribution: _categoryDistribution(debits),
      topMerchants: _topMerchants(debits),
      dailyAverage: _dailyAverage(debits),
      weeklyComparison: _weeklyComparison(debits),
      timeOfDay: _timeOfDay(debits),
      weekendVsWeekday: _weekendVsWeekday(debits),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  1. CATEGORY DISTRIBUTION
  // ─────────────────────────────────────────────────────────────────────────

  static CategoryDistributionInsight _categoryDistribution(
      List<Transaction> debits) {
    final totals = <String, double>{};
    for (final t in debits) {
      totals.update(t.category, (v) => v + t.amount, ifAbsent: () => t.amount);
    }

    final grand = totals.values.fold<double>(0, (s, v) => s + v);

    final categories = totals.entries
        .map((e) => CategorySpendEntry(
              category: e.key,
              totalAmount: e.value,
              percentage: grand > 0 ? (e.value / grand) * 100 : 0,
              transactionCount:
                  debits.where((t) => t.category == e.key).length,
            ))
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return CategoryDistributionInsight(
      entries: categories,
      totalSpent: grand,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  2. TOP MERCHANTS
  // ─────────────────────────────────────────────────────────────────────────

  static TopMerchantsInsight _topMerchants(List<Transaction> debits,
      {int limit = 7}) {
    final byMerchant = <String, _MerchantAccum>{};

    for (final t in debits) {
      final key = t.payeeName.trim().isEmpty ? t.payeeUpiId : t.payeeName;
      final entry = byMerchant.putIfAbsent(
        key,
        () => _MerchantAccum(
          displayName: key,
          upiId: t.payeeUpiId,
          category: t.category,
        ),
      );
      entry.total += t.amount;
      entry.count++;
      // Track most-recent transaction date for tie-breaking
      if (entry.lastTxn == null || t.createdAt.isAfter(entry.lastTxn!)) {
        entry.lastTxn = t.createdAt;
      }
      // If multiple categories, keep the most frequent
      entry.categoryFreq
          .update(t.category, (v) => v + 1, ifAbsent: () => 1);
    }

    final grand = debits.fold<double>(0, (s, t) => s + t.amount);

    final merchants = byMerchant.values
        .map((a) {
          // Resolve dominant category
          final dom = a.categoryFreq.entries
              .reduce((b, c) => b.value >= c.value ? b : c)
              .key;
          return MerchantSpendEntry(
            displayName: a.displayName,
            upiId: a.upiId,
            totalAmount: a.total,
            transactionCount: a.count,
            category: dom,
            shareOfTotal: grand > 0 ? (a.total / grand) * 100 : 0,
          );
        })
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return TopMerchantsInsight(
      merchants: merchants.take(limit).toList(),
      totalSpent: grand,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  3. DAILY AVERAGE
  // ─────────────────────────────────────────────────────────────────────────

  static DailyAverageInsight _dailyAverage(List<Transaction> debits) {
    if (debits.isEmpty) {
      return const DailyAverageInsight(
        averagePerDay: 0,
        activeDays: 0,
        peakDayAmount: 0,
        peakDate: null,
        weekdayAverages: {},
        dailyTotals: {},
      );
    }

    // Group by calendar date
    final byDate = <DateTime, double>{};
    for (final t in debits) {
      final day = DateTime(
          t.createdAt.year, t.createdAt.month, t.createdAt.day);
      byDate.update(day, (v) => v + t.amount, ifAbsent: () => t.amount);
    }

    final totalSpent = byDate.values.fold<double>(0, (s, v) => s + v);

    // Date range — from first txn to today (not just active days)
    final earnedDates = byDate.keys.toList()..sort();
    final firstDate = earnedDates.first;
    final lastDate = earnedDates.last;
    final calendarDays =
        lastDate.difference(firstDate).inDays + 1; // inclusive

    // Active days = days that had spending
    final activeDays = byDate.length;

    final avgPerDay = calendarDays > 0 ? totalSpent / calendarDays : 0.0;

    // Peak day
    final peak =
        byDate.entries.reduce((a, b) => a.value >= b.value ? a : b);

    // Weekday averages: 1=Mon … 7=Sun
    final weekdayTotals = <int, double>{};
    final weekdayCounts = <int, int>{};
    for (final e in byDate.entries) {
      final wd = e.key.weekday; // DateTime.weekday: 1=Mon, 7=Sun
      weekdayTotals.update(wd, (v) => v + e.value, ifAbsent: () => e.value);
      weekdayCounts.update(wd, (v) => v + 1, ifAbsent: () => 1);
    }
    final weekdayAverages = {
      for (final wd in weekdayTotals.keys)
        wd: weekdayTotals[wd]! / weekdayCounts[wd]!,
    };

    return DailyAverageInsight(
      averagePerDay: avgPerDay,
      activeDays: activeDays,
      peakDayAmount: peak.value,
      peakDate: peak.key,
      weekdayAverages: weekdayAverages,
      dailyTotals: byDate,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  4. WEEKLY COMPARISON
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns this-week vs last-week spending.
  /// "This week" = Mon–today; "Last week" = the 7-day block before that.
  static WeeklyComparisonInsight _weeklyComparison(List<Transaction> debits) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Start of ISO week (Monday)
    final thisWeekStart =
        today.subtract(Duration(days: today.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = thisWeekStart.subtract(const Duration(days: 1));

    // Daily totals for both weeks keyed by weekday offset (0=Mon … 6=Sun)
    final thisWeekDaily = <int, double>{for (int i = 0; i < 7; i++) i: 0.0};
    final lastWeekDaily = <int, double>{for (int i = 0; i < 7; i++) i: 0.0};

    double thisWeekTotal = 0;
    double lastWeekTotal = 0;

    for (final t in debits) {
      final day =
          DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      if (!day.isBefore(thisWeekStart) && !day.isAfter(today)) {
        // This week
        final offset = day.difference(thisWeekStart).inDays;
        thisWeekDaily[offset] = (thisWeekDaily[offset] ?? 0) + t.amount;
        thisWeekTotal += t.amount;
      } else if (!day.isBefore(lastWeekStart) &&
          !day.isAfter(lastWeekEnd)) {
        // Last week
        final offset = day.difference(lastWeekStart).inDays;
        lastWeekDaily[offset] = (lastWeekDaily[offset] ?? 0) + t.amount;
        lastWeekTotal += t.amount;
      }
    }

    final change = lastWeekTotal > 0
        ? ((thisWeekTotal - lastWeekTotal) / lastWeekTotal) * 100
        : 0.0;

    return WeeklyComparisonInsight(
      thisWeekTotal: thisWeekTotal,
      lastWeekTotal: lastWeekTotal,
      changePercent: change,
      isIncrease: change > 0,
      thisWeekStart: thisWeekStart,
      lastWeekStart: lastWeekStart,
      thisWeekDaily: thisWeekDaily,
      lastWeekDaily: lastWeekDaily,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  5. TIME-OF-DAY
  // ─────────────────────────────────────────────────────────────────────────

  static TimeOfDayInsight _timeOfDay(List<Transaction> debits) {
    // Aggregate by hour-of-day (0–23)
    final hourlyAmount = <int, double>{for (int h = 0; h < 24; h++) h: 0.0};
    final hourlyCount = <int, int>{for (int h = 0; h < 24; h++) h: 0};

    for (final t in debits) {
      final h = t.createdAt.hour;
      hourlyAmount[h] = hourlyAmount[h]! + t.amount;
      hourlyCount[h] = hourlyCount[h]! + 1;
    }

    final hourlyBreakdown = List.generate(24, (h) {
      return HourlySpendEntry(
        hour: h,
        totalAmount: hourlyAmount[h]!,
        transactionCount: hourlyCount[h]!,
      );
    });

    // Peak hour by transaction count (most active time)
    int peakHour = 12;
    int peakCount = 0;
    for (int h = 0; h < 24; h++) {
      if (hourlyCount[h]! > peakCount) {
        peakCount = hourlyCount[h]!;
        peakHour = h;
      }
    }

    // Peak hour by amount
    int peakAmountHour = peakHour;
    double peakAmount = 0;
    for (int h = 0; h < 24; h++) {
      if (hourlyAmount[h]! > peakAmount) {
        peakAmount = hourlyAmount[h]!;
        peakAmountHour = h;
      }
    }

    // Session totals  (Morning 5–11, Afternoon 12–16, Evening 17–21, Night 22–4)
    final sessionTotals = <SpendingSession, double>{
      SpendingSession.morning: _sessionSum(hourlyAmount, 5, 11),
      SpendingSession.afternoon: _sessionSum(hourlyAmount, 12, 16),
      SpendingSession.evening: _sessionSum(hourlyAmount, 17, 21),
      SpendingSession.night: _sessionSum(hourlyAmount, 22, 23) +
          _sessionSum(hourlyAmount, 0, 4),
    };

    final peakSession = sessionTotals.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    return TimeOfDayInsight(
      hourlyBreakdown: hourlyBreakdown,
      peakHour: peakAmountHour,
      peakHourCount: peakHour,
      peakSession: peakSession,
      sessionTotals: sessionTotals,
    );
  }

  static double _sessionSum(
      Map<int, double> hourly, int startH, int endH) {
    double sum = 0;
    for (int h = startH; h <= endH; h++) {
      sum += hourly[h] ?? 0;
    }
    return sum;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  6. WEEKEND VS WEEKDAY
  // ─────────────────────────────────────────────────────────────────────────

  static WeekendVsWeekdayInsight _weekendVsWeekday(
      List<Transaction> debits) {
    double weekdayTotal = 0;
    double weekendTotal = 0;
    final weekdayDays = <DateTime>{};
    final weekendDays = <DateTime>{};
    int weekdayTxnCount = 0;
    int weekendTxnCount = 0;

    for (final t in debits) {
      final day = DateTime(
          t.createdAt.year, t.createdAt.month, t.createdAt.day);
      final isWeekend = day.weekday == DateTime.saturday ||
          day.weekday == DateTime.sunday;
      if (isWeekend) {
        weekendTotal += t.amount;
        weekendDays.add(day);
        weekendTxnCount++;
      } else {
        weekdayTotal += t.amount;
        weekdayDays.add(day);
        weekdayTxnCount++;
      }
    }

    return WeekendVsWeekdayInsight(
      weekdayTotal: weekdayTotal,
      weekendTotal: weekendTotal,
      weekdayDayCount: weekdayDays.length,
      weekendDayCount: weekendDays.length,
      weekdayTxnCount: weekdayTxnCount,
      weekendTxnCount: weekendTxnCount,
    );
  }
}

// ─── Temp accumulator (internal) ───────────────────────────────────────────

class _MerchantAccum {
  final String displayName;
  final String upiId;
  String category;
  double total = 0;
  int count = 0;
  DateTime? lastTxn;
  final Map<String, int> categoryFreq = {};

  _MerchantAccum({
    required this.displayName,
    required this.upiId,
    required this.category,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  RESULT TYPES
// ═══════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────
//  Top-level result
// ─────────────────────────────────────────────────────────────────────────

class SpendingInsightsResult {
  final CategoryDistributionInsight categoryDistribution;
  final TopMerchantsInsight topMerchants;
  final DailyAverageInsight dailyAverage;
  final WeeklyComparisonInsight weeklyComparison;
  final TimeOfDayInsight timeOfDay;
  final WeekendVsWeekdayInsight weekendVsWeekday;

  const SpendingInsightsResult({
    required this.categoryDistribution,
    required this.topMerchants,
    required this.dailyAverage,
    required this.weeklyComparison,
    required this.timeOfDay,
    required this.weekendVsWeekday,
  });
}

// ─────────────────────────────────────────────────────────────────────────
//  1. Category Distribution
// ─────────────────────────────────────────────────────────────────────────

class CategoryDistributionInsight {
  /// Sorted by totalAmount descending.
  final List<CategorySpendEntry> entries;
  final double totalSpent;

  const CategoryDistributionInsight({
    required this.entries,
    required this.totalSpent,
  });

  /// Convenience: top category (or null if empty).
  CategorySpendEntry? get topCategory =>
      entries.isEmpty ? null : entries.first;
}

class CategorySpendEntry {
  final String category;
  final double totalAmount;

  /// 0–100 percentage of total spending.
  final double percentage;
  final int transactionCount;

  const CategorySpendEntry({
    required this.category,
    required this.totalAmount,
    required this.percentage,
    required this.transactionCount,
  });
}

// ─────────────────────────────────────────────────────────────────────────
//  2. Top Merchants
// ─────────────────────────────────────────────────────────────────────────

class TopMerchantsInsight {
  /// Sorted by totalAmount descending, capped at the requested limit.
  final List<MerchantSpendEntry> merchants;
  final double totalSpent;

  const TopMerchantsInsight({
    required this.merchants,
    required this.totalSpent,
  });
}

class MerchantSpendEntry {
  final String displayName;
  final String upiId;
  final double totalAmount;
  final int transactionCount;
  final String category;

  /// Percentage of the period's total spending.
  final double shareOfTotal;

  const MerchantSpendEntry({
    required this.displayName,
    required this.upiId,
    required this.totalAmount,
    required this.transactionCount,
    required this.category,
    required this.shareOfTotal,
  });

  double get averagePerTransaction =>
      transactionCount > 0 ? totalAmount / transactionCount : 0;
}

// ─────────────────────────────────────────────────────────────────────────
//  3. Daily Average
// ─────────────────────────────────────────────────────────────────────────

class DailyAverageInsight {
  /// Mean spend per calendar day (total ÷ calendar days in range).
  final double averagePerDay;

  /// Number of distinct days with at least one transaction.
  final int activeDays;

  /// Amount spent on the single highest-spend day.
  final double peakDayAmount;

  /// Date of the peak-spend day (null if no transactions).
  final DateTime? peakDate;

  /// Weekday → average spend (1=Mon … 7=Sun).
  final Map<int, double> weekdayAverages;

  /// All calendar-date → total-spend pairs in the dataset.
  final Map<DateTime, double> dailyTotals;

  const DailyAverageInsight({
    required this.averagePerDay,
    required this.activeDays,
    required this.peakDayAmount,
    required this.peakDate,
    required this.weekdayAverages,
    required this.dailyTotals,
  });

  /// Weekday label for [weekday] (1=Mon … 7=Sun).
  static String weekdayLabel(int weekday) {
    const labels = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[weekday.clamp(1, 7)];
  }

  /// The day-of-week with the highest average spend.
  int? get peakWeekday {
    if (weekdayAverages.isEmpty) return null;
    return weekdayAverages.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  4. Weekly Comparison
// ─────────────────────────────────────────────────────────────────────────

class WeeklyComparisonInsight {
  final double thisWeekTotal;
  final double lastWeekTotal;

  /// Signed: positive = more spent this week, negative = less.
  final double changePercent;
  final bool isIncrease;

  /// Monday of the current week.
  final DateTime thisWeekStart;

  /// Monday of last week.
  final DateTime lastWeekStart;

  /// Weekday offset (0=Mon … 6=Sun) → amount, for the current week.
  final Map<int, double> thisWeekDaily;

  /// Weekday offset (0=Mon … 6=Sun) → amount, for last week.
  final Map<int, double> lastWeekDaily;

  const WeeklyComparisonInsight({
    required this.thisWeekTotal,
    required this.lastWeekTotal,
    required this.changePercent,
    required this.isIncrease,
    required this.thisWeekStart,
    required this.lastWeekStart,
    required this.thisWeekDaily,
    required this.lastWeekDaily,
  });

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static String dayLabel(int offset) => _days[offset.clamp(0, 6)];

  double get maxDailyValue {
    double m = 0;
    for (int i = 0; i < 7; i++) {
      final a = thisWeekDaily[i] ?? 0;
      final b = lastWeekDaily[i] ?? 0;
      if (a > m) m = a;
      if (b > m) m = b;
    }
    return m;
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  5. Time-of-Day
// ─────────────────────────────────────────────────────────────────────────

enum SpendingSession { morning, afternoon, evening, night }

extension SpendingSessionLabel on SpendingSession {
  String get label {
    switch (this) {
      case SpendingSession.morning:
        return 'Morning';
      case SpendingSession.afternoon:
        return 'Afternoon';
      case SpendingSession.evening:
        return 'Evening';
      case SpendingSession.night:
        return 'Night';
    }
  }

  String get timeRange {
    switch (this) {
      case SpendingSession.morning:
        return '5 AM–12 PM';
      case SpendingSession.afternoon:
        return '12–5 PM';
      case SpendingSession.evening:
        return '5–10 PM';
      case SpendingSession.night:
        return '10 PM–5 AM';
    }
  }

  String get icon {
    switch (this) {
      case SpendingSession.morning:
        return '🌅';
      case SpendingSession.afternoon:
        return '☀️';
      case SpendingSession.evening:
        return '🌆';
      case SpendingSession.night:
        return '🌙';
    }
  }
}

class HourlySpendEntry {
  final int hour; // 0–23
  final double totalAmount;
  final int transactionCount;

  const HourlySpendEntry({
    required this.hour,
    required this.totalAmount,
    required this.transactionCount,
  });

  /// e.g. "3 PM"
  String get label {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }
}

class TimeOfDayInsight {
  /// 24 entries (one per hour), index = hour.
  final List<HourlySpendEntry> hourlyBreakdown;

  /// Hour (0–23) with the highest total amount spent.
  final int peakHour;

  /// Hour (0–23) with the most transactions (may differ from [peakHour]).
  final int peakHourCount;

  /// The session (morning / afternoon / evening / night) with the most spend.
  final SpendingSession peakSession;

  /// Spend total per session.
  final Map<SpendingSession, double> sessionTotals;

  const TimeOfDayInsight({
    required this.hourlyBreakdown,
    required this.peakHour,
    required this.peakHourCount,
    required this.peakSession,
    required this.sessionTotals,
  });

  double get totalSpent =>
      sessionTotals.values.fold<double>(0, (s, v) => s + v);

  HourlySpendEntry get peakEntry => hourlyBreakdown[peakHour.clamp(0, 23)];
}

// ─────────────────────────────────────────────────────────────────────────
//  6. Weekend vs Weekday
// ─────────────────────────────────────────────────────────────────────────

class WeekendVsWeekdayInsight {
  /// Total amount spent on Mon–Fri transactions.
  final double weekdayTotal;

  /// Total amount spent on Sat–Sun transactions.
  final double weekendTotal;

  /// Number of distinct weekday calendar dates with spending.
  final int weekdayDayCount;

  /// Number of distinct weekend calendar dates with spending.
  final int weekendDayCount;

  /// Number of individual weekday transactions.
  final int weekdayTxnCount;

  /// Number of individual weekend transactions.
  final int weekendTxnCount;

  const WeekendVsWeekdayInsight({
    required this.weekdayTotal,
    required this.weekendTotal,
    required this.weekdayDayCount,
    required this.weekendDayCount,
    required this.weekdayTxnCount,
    required this.weekendTxnCount,
  });

  /// Average spend per active weekday.
  double get weekdayAvgPerDay =>
      weekdayDayCount > 0 ? weekdayTotal / weekdayDayCount : 0;

  /// Average spend per active weekend day.
  double get weekendAvgPerDay =>
      weekendDayCount > 0 ? weekendTotal / weekendDayCount : 0;

  /// True when average weekend daily spend exceeds weekday average.
  bool get spendMoreOnWeekends => weekendAvgPerDay > weekdayAvgPerDay;

  /// Combined total of all transactions.
  double get total => weekdayTotal + weekendTotal;

  /// Category-to-totalSpent map built from [entries] — convenience
  /// alias used by the UI layer; computed from the distribution insight.
  static Map<String, double> buildCategoryMap(
      List<CategorySpendEntry> entries) {
    return {for (final e in entries) e.category: e.totalAmount};
  }
}
