import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/focus_session.dart';
import '../services/storage_service.dart';
import '../widgets/progress_card.dart';
import '../widgets/category_selector.dart';
import '../widgets/task_tile.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/focus_stats_bar.dart';
import '../theme/app_colors.dart';
import 'timer_screen.dart';
import 'calendar_screen.dart';

enum TaskSortOption {
  dueDate('Due Date'),
  priority('Priority'),
  estimatedSessions('Effort'),
  alphabetical('Title');

  final String label;
  const TaskSortOption(this.label);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  List<Task> _tasks = [];
  List<FocusSession> _focusSessions = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  TaskSortOption _sortOption = TaskSortOption.dueDate;
  bool _isSearchExpanded = false;
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = ['All', 'Mind', 'Work', 'Health', 'Personal'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final tasks = await _storageService.loadTasks();
    final sessions = await _storageService.loadFocusSessions();
    setState(() {
      _tasks = tasks;
      _focusSessions = sessions;
      _isLoading = false;
    });
  }

  Future<void> _saveTasks() async {
    await _storageService.saveTasks(_tasks);
  }

  Future<void> _saveSessions() async {
    await _storageService.saveFocusSessions(_focusSessions);
  }

  void _toggleTask(Task task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      setState(() {
        _tasks[index] = task.copyWith(isCompleted: !task.isCompleted);
      });
      _saveTasks();
    }
  }

  void _deleteTask(Task task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      setState(() {
        _tasks.removeAt(index);
      });
      _saveTasks();

      // Show Undo SnackBar
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${task.title}"'),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.secondary,
            onPressed: () {
              setState(() {
                _tasks.insert(index, task);
              });
              _saveTasks();
            },
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
    }
  }

  void _addTask(Task task) {
    setState(() {
      _tasks.insert(0, task);
    });
    _saveTasks();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Task added to your stream'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }

  void _editTask(Task task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      setState(() {
        _tasks[index] = task;
      });
      _saveTasks();
    }
  }

  void _openEditTaskSheet(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditTaskSheet(
        task: task,
        onTaskUpdated: _editTask,
      ),
    );
  }

  void _recordFocusSession(FocusSession session, Task? updatedTask) {
    setState(() {
      _focusSessions.insert(0, session);
      if (updatedTask != null) {
        final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
        if (index != -1) {
          _tasks[index] = updatedTask;
        }
      }
    });
    _saveSessions();
    _saveTasks();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning 🌅';
    } else if (hour < 17) {
      return 'Good Afternoon ☀️';
    } else {
      return 'Good Evening 🌌';
    }
  }

  List<Task> _getFilteredAndSortedTasks() {
    List<Task> list = List.from(_tasks);

    // Filter by Category
    if (_selectedCategory != 'All') {
      list = list.where((t) => t.category == _selectedCategory).toList();
    }

    // Filter by Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      list = list.where((t) =>
          t.title.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query)).toList();
    }

    // Sort Tasks (Uncompleted first, then by sort option)
    list.sort((a, b) {
      // Completed tasks sink to the bottom
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }

      switch (_sortOption) {
        case TaskSortOption.dueDate:
          return a.dueDate.compareTo(b.dueDate);
        case TaskSortOption.priority:
          return b.priorityWeight.compareTo(a.priorityWeight);
        case TaskSortOption.estimatedSessions:
          return b.estimatedSessions.compareTo(a.estimatedSessions);
        case TaskSortOption.alphabetical:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _getFilteredAndSortedTasks();
    final totalCount = _tasks.length;
    final completedCount = _tasks.where((t) => t.isCompleted).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.secondary))
            : CustomScrollView(
                slivers: [
                  // Title / Date Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  _isSearchExpanded ? Icons.close : Icons.search_rounded,
                                  color: Colors.white70,
                                  size: 22,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSearchExpanded = !_isSearchExpanded;
                                    if (!_isSearchExpanded) {
                                      _searchQuery = '';
                                      _searchController.clear();
                                    }
                                  });
                                },
                                tooltip: 'Search tasks',
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.timer_outlined, color: AppColors.secondary, size: 22),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TimerScreen(
                                        onSessionComplete: _recordFocusSession,
                                      ),
                                    ),
                                  );
                                },
                                tooltip: 'Start focus timer',
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.calendar_month_rounded, color: AppColors.info, size: 22),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CalendarScreen(
                                        initialSessions: _focusSessions,
                                        initialTasks: _tasks,
                                        onSessionComplete: _recordFocusSession,
                                      ),
                                    ),
                                  );
                                },
                                tooltip: 'Month View & Calendar',
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 22),
                                onPressed: () {
                                  setState(() {
                                    _isLoading = true;
                                  });
                                  _loadData();
                                },
                                tooltip: 'Sync data',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Collapsible Search Input Field
                  if (_isSearchExpanded)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search tasks by keyword...',
                            prefixIcon: const Icon(Icons.search, size: 20, color: Colors.white54),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: Colors.white54),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                      ),
                    ),

                  // Progress Analytics Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: ProgressCard(
                        completedCount: completedCount,
                        totalCount: totalCount,
                      ),
                    ),
                  ),

                  // Focus Balance Statistics Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: FocusStatsBar(sessions: _focusSessions),
                    ),
                  ),

                  // Category Header & List Selector
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            child: Text(
                              'Categories',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          CategorySelector(
                            selectedCategory: _selectedCategory,
                            categories: _categories,
                            onCategorySelected: (category) {
                              setState(() {
                                _selectedCategory = category;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Task stream label & Sorting Dropdown
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Focus List (${filteredTasks.length})',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          // Sort options button
                          PopupMenuButton<TaskSortOption>(
                            initialValue: _sortOption,
                            onSelected: (option) {
                              setState(() {
                                _sortOption = option;
                              });
                            },
                            color: AppColors.surfaceElevated,
                            itemBuilder: (context) => TaskSortOption.values.map((opt) {
                              return PopupMenuItem(
                                value: opt,
                                child: Row(
                                  children: [
                                    if (_sortOption == opt)
                                      const Icon(Icons.check, size: 16, color: AppColors.secondary)
                                    else
                                      const SizedBox(width: 16),
                                    const SizedBox(width: 8),
                                    Text(opt.label, style: const TextStyle(color: Colors.white)),
                                  ],
                                ),
                              );
                            }).toList(),
                            child: Row(
                              children: [
                                const Icon(Icons.sort_rounded, size: 16, color: AppColors.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  _sortOption.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tasks list or empty state
                  filteredTasks.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.self_improvement,
                                    size: 72,
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Stream is clear',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No tasks matching "$_searchQuery".'
                                        : 'No tasks in $_selectedCategory. Take a deep breath or add a new task to focus.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.4),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final task = filteredTasks[index];
                                return TaskTile(
                                  task: task,
                                  onToggle: () => _toggleTask(task),
                                  onDelete: () => _deleteTask(task),
                                  onEdit: () => _openEditTaskSheet(task),
                                  onStartTimer: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TimerScreen(
                                          task: task,
                                          onSessionComplete: _recordFocusSession,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              childCount: filteredTasks.length,
                            ),
                          ),
                        ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80), // Padding for FloatingActionButton
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AddTaskSheet(onTaskCreated: _addTask),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
