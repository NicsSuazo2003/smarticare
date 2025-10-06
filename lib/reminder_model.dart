import 'package:hive/hive.dart';

part 'reminder_model.g.dart'; // Run build_runner to generate this

@HiveType(typeId: 0)
class Reminder extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String userId;
  @HiveField(2)
  String title;
  @HiveField(3)
  String description;
  @HiveField(4)
  DateTime dateTime;
  @HiveField(5)
  bool completed;
  @HiveField(6)
  bool needsSync;
  @HiveField(7)
  DateTime lastUpdated;

  Reminder({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.dateTime,
    this.completed = false,
    this.needsSync = false,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "userId": userId,
        "title": title,
        "description": description,
        "dateTime": dateTime.toIso8601String(),
        "completed": completed,
        "lastUpdated": lastUpdated.toIso8601String(),
      };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'],
        userId: json['userId'],
        title: json['title'],
        description: json['description'],
        dateTime: DateTime.parse(json['dateTime']),
        completed: json['completed'] ?? false,
        needsSync: false,
        lastUpdated: DateTime.parse(json['lastUpdated']),
      );
}
