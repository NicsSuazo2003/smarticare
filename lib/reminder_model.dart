import 'package:hive/hive.dart';

part 'reminder_model.g.dart'; // Run: flutter packages pub run build_runner build

@HiveType(typeId: 0)
class Reminder extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  String type; // ✅ Added: "Eye Scan" or "Medication"

  @HiveField(3)
  String title;

  @HiveField(4)
  String description;

  @HiveField(5)
  DateTime dateTime;

  @HiveField(6)
  bool completed;

  @HiveField(7)
  String repeat; // ✅ Added: "None", "Daily", "Weekly", "Monthly"

  @HiveField(8)
  bool notification; // ✅ Added: notification on/off

  @HiveField(9)
  bool needsSync;

  @HiveField(10)
  DateTime lastUpdated;

  Reminder({
    required this.id,
    required this.userId,
    this.type = "Eye Scan",
    required this.title,
    required this.description,
    required this.dateTime,
    this.completed = false,
    this.repeat = "None",
    this.notification = true,
    this.needsSync = false,
    required this.lastUpdated,
  });

  // ✅ Convert to JSON for Firestore
  Map<String, dynamic> toJson() => {
        "id": id,
        "userId": userId,
        "type": type,
        "title": title,
        "description": description,
        "dateTime": dateTime,
        "completed": completed,
        "repeat": repeat,
        "notification": notification,
        "lastUpdated": lastUpdated,
      };

  // ✅ Create from Firestore document
  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] ?? '',
        userId: json['userId'] ?? '',
        type: json['type'] ?? 'Eye Scan',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        dateTime: json['dateTime'] is DateTime
            ? json['dateTime']
            : DateTime.parse(json['dateTime']),
        completed: json['completed'] ?? false,
        repeat: json['repeat'] ?? 'None',
        notification: json['notification'] ?? true,
        needsSync: false,
        lastUpdated: json['lastUpdated'] is DateTime
            ? json['lastUpdated']
            : DateTime.parse(json['lastUpdated']),
      );

  // ✅ Create a copy with updated fields
  Reminder copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? description,
    DateTime? dateTime,
    bool? completed,
    String? repeat,
    bool? notification,
    bool? needsSync,
    DateTime? lastUpdated,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      completed: completed ?? this.completed,
      repeat: repeat ?? this.repeat,
      notification: notification ?? this.notification,
      needsSync: needsSync ?? this.needsSync,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
