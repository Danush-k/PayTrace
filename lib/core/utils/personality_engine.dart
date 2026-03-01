import '../../data/database/app_database.dart';
import 'spend_velocity_engine.dart';
import 'discipline_score_engine.dart';
import 'category_drift_engine.dart';

/// Spending Personality Engine — assigns users a dynamic, shareable
/// "financial persona" based on their actual spending behavior.
///
/// Combines 4 trait dimensions:
///   1. Time trait     — when they spend (from time-of-day data)
///   2. Category trait — what they spend on (from top category)
///   3. Pace trait     — how they spend through the month (from velocity)
///   4. Discipline trait — how controlled they are (from discipline score)
class PersonalityEngine {
  PersonalityEngine._();

  /// Analyze spending patterns and generate a personality profile.
  static SpendingPersonality analyze({
    required DisciplineScoreResult discipline,
    required CategoryDriftResult drift,
    required SpendVelocityResult velocity,
    required List<Transaction> currentTransactions,
  }) {
    final timeTrait = _analyzeTimeTrait(drift.timeOfDaySpend);
    final categoryTrait = _analyzeCategoryTrait(drift.currentByCategory);
    final paceTrait = _analyzePaceTrait(velocity);
    final disciplineTrait = _analyzeDisciplineTrait(discipline);

    // Build personality title
    final title = 'The ${timeTrait.adjective} ${categoryTrait.noun}';

    // Build description
    final description = _buildDescription(
      timeTrait, categoryTrait, paceTrait, disciplineTrait, velocity, discipline,
    );

    // Pick emoji + colors based on dominant traits
    final emoji = _pickEmoji(categoryTrait, disciplineTrait);
    final gradientColors = _pickGradient(disciplineTrait, categoryTrait);

    return SpendingPersonality(
      title: title,
      emoji: emoji,
      description: description,
      timeTrait: timeTrait,
      categoryTrait: categoryTrait,
      paceTrait: paceTrait,
      disciplineTrait: disciplineTrait,
      gradientColors: gradientColors,
    );
  }

  // ─── Time Trait Analysis ───

  static PersonalityTrait _analyzeTimeTrait(Map<String, double> timeOfDay) {
    final total = timeOfDay.values.fold<double>(0, (s, v) => s + v);
    if (total == 0) {
      return const PersonalityTrait(
        label: 'Balanced Timer',
        adjective: 'Balanced',
        noun: 'Timer',
        icon: '⏰',
        description: 'You spend evenly throughout the day.',
      );
    }

    final morningPct = (timeOfDay['Morning (6–12)'] ?? 0) / total;
    final afternoonPct = (timeOfDay['Afternoon (12–17)'] ?? 0) / total;
    final eveningPct = (timeOfDay['Evening (17–21)'] ?? 0) / total;
    final nightPct = (timeOfDay['Night (21–6)'] ?? 0) / total;

    if (nightPct > 0.30) {
      return const PersonalityTrait(
        label: 'Night Owl',
        adjective: 'Night Owl',
        noun: 'Spender',
        icon: '🦉',
        description: 'You tend to make purchases late at night.',
      );
    } else if (morningPct > 0.40) {
      return const PersonalityTrait(
        label: 'Early Bird',
        adjective: 'Early Bird',
        noun: 'Spender',
        icon: '🌅',
        description: 'You prefer making payments bright and early.',
      );
    } else if (eveningPct > 0.40) {
      return const PersonalityTrait(
        label: 'Evening Spender',
        adjective: 'Twilight',
        noun: 'Spender',
        icon: '🌆',
        description: 'Most of your spending happens in the evening.',
      );
    } else if (afternoonPct > 0.40) {
      return const PersonalityTrait(
        label: 'Afternoon Shopper',
        adjective: 'Midday',
        noun: 'Spender',
        icon: '☀️',
        description: 'Afternoons are your peak spending hours.',
      );
    }

    return const PersonalityTrait(
      label: 'All-Day Spender',
      adjective: 'Steady',
      noun: 'Spender',
      icon: '⏰',
      description: 'Your spending is spread evenly through the day.',
    );
  }

  // ─── Category Trait Analysis ───

  static PersonalityTrait _analyzeCategoryTrait(
      Map<String, double> categorySpend) {
    if (categorySpend.isEmpty) {
      return const PersonalityTrait(
        label: 'Explorer',
        adjective: 'Exploring',
        noun: 'Explorer',
        icon: '🧭',
        description: 'Just getting started with spending.',
      );
    }

    final total = categorySpend.values.fold<double>(0, (s, v) => s + v);
    if (total == 0) {
      return const PersonalityTrait(
        label: 'Explorer',
        adjective: 'Exploring',
        noun: 'Explorer',
        icon: '🧭',
        description: 'Just getting started with spending.',
      );
    }

    final sorted = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategory = sorted.first.key;
    final topPct = sorted.first.value / total;

    // Only label if dominant (>25%)
    if (topPct > 0.25) {
      return _categoryPersonality[topCategory] ??
          PersonalityTrait(
            label: topCategory,
            adjective: topCategory,
            noun: 'Enthusiast',
            icon: '💳',
            description: 'You spend most on $topCategory.',
          );
    }

    return const PersonalityTrait(
      label: 'Diversified',
      adjective: 'Well-Rounded',
      noun: 'Spender',
      icon: '🎯',
      description: 'Your spending is well-distributed across categories.',
    );
  }

  // ─── Pace Trait Analysis ───

  static PersonalityTrait _analyzePaceTrait(SpendVelocityResult velocity) {
    if (velocity.trend == SpendTrend.accelerating) {
      return const PersonalityTrait(
        label: 'Back Loader',
        adjective: 'Accelerating',
        noun: 'Spender',
        icon: '🚀',
        description: 'You spend more as the month progresses.',
      );
    } else if (velocity.trend == SpendTrend.decelerating) {
      return const PersonalityTrait(
        label: 'Front Loader',
        adjective: 'Front-Loading',
        noun: 'Planner',
        icon: '📋',
        description: 'You handle big expenses early and ease off later.',
      );
    }

    return const PersonalityTrait(
      label: 'Steady Pacer',
      adjective: 'Consistent',
      noun: 'Pacer',
      icon: '⚖️',
      description: 'You maintain a consistent spending pace.',
    );
  }

  // ─── Discipline Trait Analysis ───

  static PersonalityTrait _analyzeDisciplineTrait(
      DisciplineScoreResult discipline) {
    if (discipline.totalScore >= 75) {
      return const PersonalityTrait(
        label: 'Disciplined',
        adjective: 'Disciplined',
        noun: 'Saver',
        icon: '🏆',
        description: 'Your financial habits are excellent.',
      );
    } else if (discipline.totalScore >= 55) {
      return const PersonalityTrait(
        label: 'Balanced',
        adjective: 'Balanced',
        noun: 'Manager',
        icon: '👍',
        description: 'You maintain decent control over your finances.',
      );
    } else if (discipline.totalScore >= 35) {
      return const PersonalityTrait(
        label: 'Casual',
        adjective: 'Casual',
        noun: 'Spender',
        icon: '🎲',
        description: 'Room for improvement in spending discipline.',
      );
    }

    return const PersonalityTrait(
      label: 'Freewheeler',
      adjective: 'Free-Spirited',
      noun: 'Spender',
      icon: '🎡',
      description: 'You spend freely without much constraint.',
    );
  }

  // ─── Description Builder ───

  static String _buildDescription(
    PersonalityTrait time,
    PersonalityTrait category,
    PersonalityTrait pace,
    PersonalityTrait discipline,
    SpendVelocityResult velocity,
    DisciplineScoreResult score,
  ) {
    final buf = StringBuffer();

    buf.write('You\'re a ${time.adjective.toLowerCase()} spender ');
    buf.write('who mostly spends on ${category.label.toLowerCase()}. ');

    if (pace.label == 'Front Loader') {
      buf.write('You tend to get big expenses out of the way early. ');
    } else if (pace.label == 'Back Loader') {
      buf.write('Your spending picks up towards month-end. ');
    } else {
      buf.write('You keep a steady spending rhythm. ');
    }

    if (score.totalScore >= 70) {
      buf.write('Keep it up — your financial discipline is strong!');
    } else if (score.totalScore >= 50) {
      buf.write('You\'re doing alright, with room to tighten up.');
    } else {
      buf.write('Consider setting stricter spending limits.');
    }

    return buf.toString();
  }

  // ─── Emoji & Color Pickers ───

  static String _pickEmoji(
      PersonalityTrait category, PersonalityTrait discipline) {
    if (discipline.label == 'Disciplined') return '🏆';
    return category.icon;
  }

  static List<int> _pickGradient(
      PersonalityTrait discipline, PersonalityTrait category) {
    // Return gradient colors as hex integers
    if (discipline.label == 'Disciplined') {
      return [0xFF00B09B, 0xFF96C93D]; // Green
    } else if (discipline.label == 'Balanced') {
      return [0xFF667EEA, 0xFF764BA2]; // Purple-blue
    } else if (discipline.label == 'Casual') {
      return [0xFFFF8C00, 0xFFFFAB40]; // Orange
    }
    return [0xFFFF5252, 0xFFFF8A80]; // Red
  }

  static const _categoryPersonality = <String, PersonalityTrait>{
    'Food & Dining': PersonalityTrait(
      label: 'Food & Dining',
      adjective: 'Foodie',
      noun: 'Foodie',
      icon: '🍕',
      description: 'You love spending on food and dining.',
    ),
    'Shopping': PersonalityTrait(
      label: 'Shopping',
      adjective: 'Shopaholic',
      noun: 'Shopper',
      icon: '🛍️',
      description: 'Shopping is your top spending category.',
    ),
    'Transport': PersonalityTrait(
      label: 'Transport',
      adjective: 'On-the-Go',
      noun: 'Commuter',
      icon: '🚗',
      description: 'You spend a lot on getting around.',
    ),
    'Bills & Utilities': PersonalityTrait(
      label: 'Bills & Utilities',
      adjective: 'Bill-Paying',
      noun: 'Bill Payer',
      icon: '🏠',
      description: 'Most of your spending goes to essential bills.',
    ),
    'Entertainment': PersonalityTrait(
      label: 'Entertainment',
      adjective: 'Fun-Loving',
      noun: 'Entertainer',
      icon: '🎬',
      description: 'Entertainment is where your money goes.',
    ),
    'Health': PersonalityTrait(
      label: 'Health',
      adjective: 'Health-Conscious',
      noun: 'Wellness Seeker',
      icon: '💊',
      description: 'You invest in health and wellness.',
    ),
    'Education': PersonalityTrait(
      label: 'Education',
      adjective: 'Knowledge-Seeking',
      noun: 'Learner',
      icon: '📚',
      description: 'Education is your priority spend.',
    ),
    'Rent': PersonalityTrait(
      label: 'Rent',
      adjective: 'Rent-Heavy',
      noun: 'Renter',
      icon: '🏡',
      description: 'Rent takes a big chunk of your spend.',
    ),
    'Transfer': PersonalityTrait(
      label: 'Transfer',
      adjective: 'Generous',
      noun: 'Giver',
      icon: '💸',
      description: 'You frequently transfer money to others.',
    ),
    'Others': PersonalityTrait(
      label: 'Others',
      adjective: 'Eclectic',
      noun: 'Spender',
      icon: '🔮',
      description: 'Your spending is unique and varied.',
    ),
  };
}

// ─── Data Models ───

class PersonalityTrait {
  final String label;
  final String adjective;
  final String noun;
  final String icon;
  final String description;

  const PersonalityTrait({
    required this.label,
    required this.adjective,
    required this.noun,
    required this.icon,
    required this.description,
  });
}

class SpendingPersonality {
  final String title;
  final String emoji;
  final String description;
  final PersonalityTrait timeTrait;
  final PersonalityTrait categoryTrait;
  final PersonalityTrait paceTrait;
  final PersonalityTrait disciplineTrait;
  final List<int> gradientColors;

  const SpendingPersonality({
    required this.title,
    required this.emoji,
    required this.description,
    required this.timeTrait,
    required this.categoryTrait,
    required this.paceTrait,
    required this.disciplineTrait,
    required this.gradientColors,
  });
}
