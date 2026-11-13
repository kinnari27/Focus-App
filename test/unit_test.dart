import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focus_app/models/task.dart';
import 'package:focus_app/models/focus_session.dart';
import 'package:focus_app/services/storage_service.dart';

void main() {
  group('Task Model Unit Tests', () {
    test('Task serialization and deserialization', () {
      final now = DateTime.now();
      final task = Task(
        id: 't100',
        title: 'Complete Project Architecture',
        description: 'Verify all modules and units',
        category: 'Work',
        dueDate: now,
        priority: 'High',
        isCompleted: false,
        estimatedSessions: 4,
        completedSessions: 2,
        focusSeconds: 3000,
      );

      final json = task.toJson();
      final fromJson = Task.fromJson(json);

      expect(fromJson.id, 't100');
      expect(fromJson.title, 'Complete Project Architecture');
      expect(fromJson.category, 'Work');
      expect(fromJson.priority, 'High');
      expect(fromJson.priorityWeight, 3);
      expect(fromJson.isCompleted, false);
      expect(fromJson.estimatedSessions, 4);
      expect(fromJson.completedSessions, 2);
      expect(fromJson.focusSeconds, 3000);
    });

    test('Task copyWith immutability test', () {
      final task = Task(
        id: '1',
        title: 'Initial',
        category: 'Mind',
        dueDate: DateTime.now(),
        isCompleted: false,
      );

      final updated = task.copyWith(isCompleted: true, title: 'Updated');
      expect(task.isCompleted, false);
      expect(updated.isCompleted, true);
      expect(updated.title, 'Updated');
    });

    test('Task overdue and due status calculation', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final futureDate = DateTime.now().add(const Duration(days: 3));

      final overdueTask = Task(
        id: '1',
        title: 'Overdue Task',
        category: 'Work',
        dueDate: pastDate,
        isCompleted: false,
      );

      final completedOverdueTask = Task(
        id: '2',
        title: 'Completed Task',
        category: 'Work',
        dueDate: pastDate,
        isCompleted: true,
      );

      final futureTask = Task(
        id: '3',
        title: 'Future Task',
        category: 'Work',
        dueDate: futureDate,
        isCompleted: false,
      );

      expect(overdueTask.isOverdue, true);
      expect(completedOverdueTask.isOverdue, false);
      expect(futureTask.isOverdue, false);
    });
  });

  group('FocusSession Model Tests', () {
    test('FocusSession JSON serialization', () {
      final now = DateTime.now();
      final session = FocusSession(
        id: 's1',
        taskId: 't1',
        taskTitle: 'Deep Study',
        category: 'Work',
        durationSeconds: 1500,
        timestamp: now,
        sessionType: 'focus',
      );

      final json = session.toJson();
      final deserialized = FocusSession.fromJson(json);

      expect(deserialized.id, 's1');
      expect(deserialized.taskTitle, 'Deep Study');
      expect(deserialized.durationSeconds, 1500);
      expect(deserialized.sessionType, 'focus');
    });
  });

  group('StorageService Tests', () {
    test('StorageService saves and loads tasks correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();

      final tasks = [
        Task(
          id: '1',
          title: 'Test Task',
          category: 'Personal',
          dueDate: DateTime.now(),
        ),
      ];

      await service.saveTasks(tasks);
      final loaded = await service.loadTasks();

      expect(loaded.length, 1);
      expect(loaded.first.title, 'Test Task');
      expect(loaded.first.category, 'Personal');
    });
  });
}

