import 'package:hive/hive.dart';
import 'data/models/reminder_model.dart';
import 'package:uuid/uuid.dart';

Future<void> addReminder(
    String userId, String title, String desc, DateTime dateTime) async {
  final box = Hive.box<Reminder>('remindersBox');
  final reminder = Reminder(
    id: const Uuid().v4(),
    userId: userId,
    title: title,
    description: desc,
    dateTime: dateTime,
    completed: false,
    needsSync: true,
    lastUpdated: DateTime.now(),
  );
  await box.put(reminder.id, reminder);
}

Future<void> updateReminder(Reminder reminder,
    {String? title, String? desc, DateTime? dateTime, bool? completed}) async {
  if (title != null) reminder.title = title;
  if (desc != null) reminder.description = desc;
  if (dateTime != null) reminder.dateTime = dateTime;
  if (completed != null) reminder.completed = completed;
  reminder.needsSync = true;
  reminder.lastUpdated = DateTime.now();
  await reminder.save();
}

Future<void> deleteReminder(Reminder reminder) async {
  await reminder.delete();
}
