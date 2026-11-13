import 'package:flutter/material.dart';
import '../models/focus_session.dart';
import '../theme/app_colors.dart';

enum StatsPeriod {
  today('Today'),
  week('This Week'),
  all('All Time');

  final String label;
  const StatsPeriod(this.label);
}

class FocusStatsBar extends StatefulWidget {
  final List<FocusSession> sessions;

  const FocusStatsBar({
    super.key,
    required this.sessions,
  });

  @override
  State<FocusStatsBar> createState() => _FocusStatsBarState();
}

class _FocusStatsBarState extends State<FocusStatsBar> {
  StatsPeriod _selectedPeriod = StatsPeriod.today;

  List<FocusSession> _filterSessions() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case StatsPeriod.today:
        final startOfToday = DateTime(now.year, now.month, now.day);
        return widget.sessions.where((s) => s.timestamp.isAfter(startOfToday)).toList();
      case StatsPeriod.week:
        // Start of current week (Monday)
        final startOfWeek = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return widget.sessions.where((s) => s.timestamp.isAfter(startOfWeek)).toList();
      case StatsPeriod.all:
        return widget.sessions;
    }
  }

  int _calculateStreak() {
    if (widget.sessions.isEmpty) return 0;

    // Collect unique dates (yyyy-mm-dd) of completed sessions
    final Set<String> activeDates = {};
    for (var s in widget.sessions) {
      final key = '${s.timestamp.year}-${s.timestamp.month.toString().padLeft(2, '0')}-${s.timestamp.day.toString().padLeft(2, '0')}';
      activeDates.add(key);
    }

    final now = DateTime.now();
    int streak = 0;
    DateTime checkDate = DateTime(now.year, now.month, now.day);

    final todayKey = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
    if (!activeDates.contains(todayKey)) {
      // If no session today, check if yesterday had one to maintain streak
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    while (true) {
      final key = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (activeDates.contains(key)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final filteredSessions = _filterSessions();

    int totalSeconds = 0;
    final Map<String, int> categorySeconds = {
      'Mind': 0,
      'Work': 0,
      'Health': 0,
      'Personal': 0,
    };

    for (var session in filteredSessions) {
      totalSeconds += session.durationSeconds;
      final cat = session.category;
      if (categorySeconds.containsKey(cat)) {
        categorySeconds[cat] = categorySeconds[cat]! + session.durationSeconds;
      } else {
        categorySeconds[cat] = session.durationSeconds;
      }
    }

    final int totalMinutes = (totalSeconds / 60).round();
    final int streak = _calculateStreak();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Streak and Total Minutes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Focus Balance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (streak > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department, size: 13, color: AppColors.warning),
                          const SizedBox(width: 3),
                          Text(
                            '$streak d',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${totalMinutes}m focused',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Period Filter Tabs
          Row(
            children: StatsPeriod.values.map((period) {
              final isSelected = _selectedPeriod == period;
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPeriod = period;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.white12,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      period.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.white54,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Horizontal Segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (totalSeconds == 0)
                    Expanded(
                      child: Container(color: Colors.white10),
                    )
                  else
                    ...categorySeconds.entries.map((entry) {
                      final seconds = entry.value;
                      if (seconds == 0) return const SizedBox.shrink();
                      final int pct = ((seconds / totalSeconds) * 100).round();
                      if (pct <= 0) return const SizedBox.shrink();
                      return Expanded(
                        flex: pct,
                        child: Container(
                          color: AppColors.getCategoryColor(entry.key),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Category Indicators List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: categorySeconds.entries.map((entry) {
              final String cat = entry.key;
              final int mins = (entry.value / 60).round();
              final double pct = totalSeconds == 0 ? 0.0 : (entry.value / totalSeconds);
              final color = AppColors.getCategoryColor(cat);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${mins}m (${(pct * 100).toInt()}%)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
