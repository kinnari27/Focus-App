import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/focus_session.dart';

class StorageService {
  static const String _keyTasks = 'zentask_tasks';
  static const String _keySessions = 'zentask_focus_sessions';

  // Save tasks to local storage
  Future<void> saveTasks(List<Task> tasks) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> taskJsonList = tasks.map((task) => jsonEncode(task.toJson())).toList();
    await prefs.setStringList(_keyTasks, taskJsonList);
  }

  // Load tasks from local storage
  Future<List<Task>> loadTasks() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? taskJsonList = prefs.getStringList(_keyTasks);
    if (taskJsonList == null) {
      final initial = _getMockTasks();
      await saveTasks(initial);
      return initial;
    }
    try {
      return taskJsonList
          .map((taskJson) => Task.fromJson(jsonDecode(taskJson) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return _getMockTasks();
    }
  }

  // Save focus sessions to local storage
  Future<void> saveFocusSessions(List<FocusSession> sessions) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> sessionJsonList = sessions.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_keySessions, sessionJsonList);
  }

  // Load focus sessions from local storage
  Future<List<FocusSession>> loadFocusSessions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? sessionJsonList = prefs.getStringList(_keySessions);
    if (sessionJsonList == null) {
      final initial = _getMockFocusSessions();
      await saveFocusSessions(initial);
      return initial;
    }
    try {
      return sessionJsonList
          .map((json) => FocusSession.fromJson(jsonDecode(json) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return _getMockFocusSessions();
    }
  }

  // Clear all data (for testing or reset)
  Future<void> clearAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTasks);
    await prefs.remove(_keySessions);
  }

  // Initial mock tasks
  List<Task> _getMockTasks() {
    final now = DateTime.now();
    return [
      Task(
        id: '1',
        title: 'Morning Meditation 🧘',
        description: 'Spend 10 minutes breathing mindfully and setting intentions for the day.',
        category: 'Mind',
        dueDate: now,
        priority: 'High',
        isCompleted: true,
        estimatedSessions: 1,
        completedSessions: 1,
        focusSeconds: 600,
      ),
      Task(
        id: '2',
        title: 'Review ZenTask Design Specs 🎨',
        description: 'Verify visual layout, premium dark gradient themes, and overall UX flow.',
        category: 'Work',
        dueDate: now.add(const Duration(hours: 4)),
        priority: 'Medium',
        isCompleted: false,
        estimatedSessions: 3,
        completedSessions: 1,
        focusSeconds: 1500,
      ),
      Task(
        id: '3',
        title: 'Stay Hydrated 💧',
        description: 'Drink water periodically. Goal is 8 glasses today.',
        category: 'Health',
        dueDate: now.add(const Duration(hours: 8)),
        priority: 'Low',
        isCompleted: false,
        estimatedSessions: 1,
        completedSessions: 0,
        focusSeconds: 0,
      ),
      Task(
        id: '4',
        title: 'Reflect & Journal 📝',
        description: 'Write down 3 positive things about today before sleeping.',
        category: 'Mind',
        dueDate: now.add(const Duration(hours: 12)),
        priority: 'Medium',
        isCompleted: false,
        estimatedSessions: 1,
        completedSessions: 0,
        focusSeconds: 0,
      ),
    ];
  }

  // Initial mock focus sessions for analytics
  List<FocusSession> _getMockFocusSessions() {
    final now = DateTime.now();
    return [
      FocusSession(
        id: 's1',
        taskId: '1',
        taskTitle: 'Morning Meditation 🧘',
        category: 'Mind',
        durationSeconds: 600,
        timestamp: now.subtract(const Duration(hours: 8)),
        sessionType: 'focus',
      ),
      FocusSession(
        id: 's2',
        taskId: '2',
        taskTitle: 'Review ZenTask Design Specs 🎨',
        category: 'Work',
        durationSeconds: 1500,
        timestamp: now.subtract(const Duration(hours: 3)),
        sessionType: 'focus',
      ),
      FocusSession(
        id: 's3',
        taskId: null,
        taskTitle: 'Deep Focus Stream ⚡',
        category: 'Work',
        durationSeconds: 900,
        timestamp: now.subtract(const Duration(hours: 1)),
        sessionType: 'focus',
      ),
    ];
  }
}
