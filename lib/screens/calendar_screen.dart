import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/focus_session.dart';
import '../models/task.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

class CalendarScreen extends StatefulWidget {
  final List<FocusSession>? initialSessions;
  final List<Task>? initialTasks;
  final Function(FocusSession, Task?)? onSessionComplete;

  const CalendarScreen({
    super.key,
    this.initialSessions,
    this.initialTasks,
    this.onSessionComplete,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final StorageService _storageService = StorageService();
  List<FocusSession> _sessions = [];
  List<Task> _tasks = [];
  bool _isLoading = true;

  late DateTime _displayedMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);

    if (widget.initialSessions != null && widget.initialTasks != null) {
      _sessions = widget.initialSessions!;
      _tasks = widget.initialTasks!;
      _isLoading = false;
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final sessions = await _storageService.loadFocusSessions();
    final tasks = await _storageService.loadTasks();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _tasks = tasks;
        _isLoading = false;
      });
    }
  }

  void _previousMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        1,
      );
    });
  }

  void _jumpToToday() {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    setState(() {
      _displayedMonth = DateTime(now.year, now.month, 1);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  // Filter sessions for the entire displayed month
  List<FocusSession> _getMonthSessions() {
    return _sessions
        .where(
          (s) =>
              s.timestamp.year == _displayedMonth.year &&
              s.timestamp.month == _displayedMonth.month,
        )
        .toList();
  }

  // Filter sessions for a specific day
  List<FocusSession> _getDaySessions(DateTime day) {
    return _sessions
        .where(
          (s) =>
              s.timestamp.year == day.year &&
              s.timestamp.month == day.month &&
              s.timestamp.day == day.day,
        )
        .toList();
  }

  // Filter tasks for a specific day
  List<Task> _getDayTasks(DateTime day) {
    return _tasks
        .where(
          (t) =>
              t.dueDate.year == day.year &&
              t.dueDate.month == day.month &&
              t.dueDate.day == day.day,
        )
        .toList();
  }

  int _calculateTotalSeconds(List<FocusSession> sessionList) {
    return sessionList.fold<int>(0, (sum, s) => sum + s.durationSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final monthSessions = _getMonthSessions();
    final monthTotalSeconds = _calculateTotalSeconds(monthSessions);
    final monthTotalMinutes = (monthTotalSeconds / 60).round();

    // Unique active days in this month
    final Set<int> activeDaysSet = monthSessions
        .map((s) => s.timestamp.day)
        .toSet();
    final daysInMonth = DateUtils.getDaysInMonth(
      _displayedMonth.year,
      _displayedMonth.month,
    );
    final dailyAvgMinutes = activeDaysSet.isNotEmpty
        ? (monthTotalMinutes / activeDaysSet.length).round()
        : 0;

    final selectedDaySessions = _getDaySessions(_selectedDay);
    final selectedDayTasks = _getDayTasks(_selectedDay);
    final selectedDayTotalMinutes =
        (_calculateTotalSeconds(selectedDaySessions) / 60).round();

    final now = DateTime.now();
    final isCurrentMonth =
        _displayedMonth.year == now.year && _displayedMonth.month == now.month;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mindful Calendar'),
        centerTitle: true,
        actions: [
          if (!isCurrentMonth)
            TextButton(
              onPressed: _jumpToToday,
              child: const Text(
                'Today',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            )
          : CustomScrollView(
              slivers: [
                // Month Navigation Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white,
                            ),
                            onPressed: _previousMonth,
                            tooltip: 'Previous month',
                          ),
                          Text(
                            DateFormat('MMMM yyyy').format(_displayedMonth),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                            ),
                            onPressed: _nextMonth,
                            tooltip: 'Next month',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Month Overview Stats Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.2),
                            AppColors.secondary.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Total Focus',
                            '${monthTotalMinutes}m',
                            Icons.timer_outlined,
                            AppColors.secondary,
                          ),
                          _buildStatDivider(),
                          _buildStatItem(
                            'Sessions',
                            '${monthSessions.length}',
                            Icons.self_improvement,
                            AppColors.primary,
                          ),
                          _buildStatDivider(),
                          _buildStatItem(
                            'Active Days',
                            '${activeDaysSet.length}/$daysInMonth',
                            Icons.calendar_today,
                            AppColors.warning,
                          ),
                          _buildStatDivider(),
                          _buildStatItem(
                            'Daily Avg',
                            '${dailyAvgMinutes}m',
                            Icons.trending_up_rounded,
                            AppColors.info,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Calendar Grid
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Weekday Labels
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children:
                                [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun',
                                ].map((day) {
                                  return SizedBox(
                                    width: 36,
                                    child: Center(
                                      child: Text(
                                        day,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 10),

                          // Days Matrix
                          _buildMonthDaysGrid(now),
                        ],
                      ),
                    ),
                  ),
                ),

                // Selected Day Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, MMMM d').format(_selectedDay),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$selectedDayTotalMinutes min focused • ${selectedDaySessions.length} session${selectedDaySessions.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: selectedDayTotalMinutes > 0
                                    ? AppColors.secondary
                                    : Colors.white38,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (DateUtils.isSameDay(_selectedDay, now))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Today',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Selected Day Activity Breakdown
                if (selectedDaySessions.isEmpty && selectedDayTasks.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.nightlight_round,
                              size: 42,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No focus recorded on this day',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white60,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Take time to rest or begin a mindful focus stream.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  // Focus Sessions List
                  if (selectedDaySessions.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final session = selectedDaySessions[index];
                          final minutes = (session.durationSeconds / 60)
                              .round();
                          final timeString = DateFormat(
                            'h:mm a',
                          ).format(session.timestamp);
                          final catColor = AppColors.getCategoryColor(
                            session.category,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: catColor.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: catColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.taskTitle,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${session.category} • $timeString',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${minutes}m',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }, childCount: selectedDaySessions.length),
                      ),
                    ),

                  // Tasks for this Day
                  if (selectedDayTasks.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                        child: Text(
                          'Tasks Due (${selectedDayTasks.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final task = selectedDayTasks[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  task.isCompleted
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: task.isCompleted
                                      ? AppColors.secondary
                                      : Colors.white38,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    task.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: task.isCompleted
                                          ? Colors.white38
                                          : Colors.white,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                Text(
                                  task.priority,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.getPriorityColor(
                                      task.priority,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }, childCount: selectedDayTasks.length),
                      ),
                    ),
                  ],
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 32, color: Colors.white12);
  }

  Widget _buildMonthDaysGrid(DateTime now) {
    final firstDayOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );
    final daysInMonth = DateUtils.getDaysInMonth(
      _displayedMonth.year,
      _displayedMonth.month,
    );

    // Monday is 1, Sunday is 7. We want Mon=0 to Sun=6.
    final int firstWeekdayOffset = firstDayOfMonth.weekday - 1;
    final int totalCells = ((firstWeekdayOffset + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 4,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final dayNumber = index - firstWeekdayOffset + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final cellDate = DateTime(
          _displayedMonth.year,
          _displayedMonth.month,
          dayNumber,
        );
        final isSelected = DateUtils.isSameDay(cellDate, _selectedDay);
        final isToday = DateUtils.isSameDay(cellDate, now);

        final daySessions = _getDaySessions(cellDate);
        final dayMinutes = (_calculateTotalSeconds(daySessions) / 60).round();
        final dayTasks = _getDayTasks(cellDate);

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedDay = cellDate;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : (isToday
                        ? AppColors.secondary.withValues(alpha: 0.12)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : (isToday ? AppColors.secondary : Colors.transparent),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected || isToday
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isToday ? AppColors.secondary : Colors.white70),
                  ),
                ),
                const SizedBox(height: 3),
                // Activity indicator dot / minutes pill
                if (dayMinutes > 0)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : AppColors.secondary,
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? []
                          : [
                              BoxShadow(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.8,
                                ),
                                blurRadius: 4,
                              ),
                            ],
                    ),
                  )
                else if (dayTasks.isNotEmpty)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white70 : AppColors.info,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }
}
