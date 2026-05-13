import 'package:flutter/foundation.dart';

enum TaskStatus { todo, doing, done }

extension TaskStatusX on TaskStatus {
  String get label => switch (this) {
        TaskStatus.todo => 'Todo',
        TaskStatus.doing => 'Doing',
        TaskStatus.done => 'Done',
      };
}

@immutable
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.status,
    this.description = '',
  });

  final String id;
  final String title;
  final String description;
  final TaskStatus status;

  Task copyWith({String? title, String? description, TaskStatus? status}) =>
      Task(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          other.id == id &&
          other.title == title &&
          other.description == description &&
          other.status == status;

  @override
  int get hashCode => Object.hash(id, title, description, status);

  @override
  String toString() => 'Task(id=$id, title=$title, status=$status)';
}

@immutable
class TaskStats {
  const TaskStats({required this.total, required this.byStatus});

  final int total;
  final Map<TaskStatus, int> byStatus;

  int countOf(TaskStatus s) => byStatus[s] ?? 0;
}
