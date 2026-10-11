import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// One rendered activity row.
class ActivityItem {
  const ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.timeLabel, // "14:05"
    required this.dateKey, // "2026-10-11"
    required this.dateLabel, // "Today" / "Yesterday" / "2026/10/11"
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String timeLabel;
  final String dateKey;
  final String dateLabel;
}

class ActivityLogMapper {
  ActivityLogMapper._();

  static const _primary = Color(0xFFFF6B6B);

  /// Convert a raw audit_log doc to a display-ready [ActivityItem].
  static ActivityItem fromFirestore(Map<String, dynamic> data) {
    final action = data['action'] as String? ?? '';
    final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final subtitle = (data['details'] ?? '') as String;

    final visual = _visualFor(action);

    return ActivityItem(
      icon: visual.icon,
      color: visual.color,
      title: visual.title,
      subtitle: subtitle,
      timeLabel: _formatTime(ts),
      dateKey: _formatDateKey(ts),
      dateLabel: _formatDateLabel(ts),
    );
  }

  // ---- Action → visual mapping ----
  static _Visual _visualFor(String action) {
    switch (action) {
      case 'scan_completed':
        return const _Visual(Icons.camera_alt, _primary, 'Eye Scan Completed');
      case 'symptom_assessment_completed':
        return const _Visual(Icons.help, Colors.teal, 'Symptom Assessment');
      case 'appointment_completed':
        return const _Visual(Icons.local_hospital, Colors.blue,
            "Doctor's Appointment Completed");
      case 'appointment_cancelled':
        return const _Visual(
            Icons.local_hospital, Colors.red, "Doctor's Appointment Cancelled");
      case 'reminder_created':
        return const _Visual(
            Icons.notification_important, Colors.amber, 'Reminder Created');
      case 'reminder_completed':
        return const _Visual(
            Icons.notification_important, Colors.green, 'Reminder Completed');
      case 'reminder_deleted':
        return const _Visual(
            Icons.delete_outline, Colors.red, 'Reminder Deleted');
      case 'profile_updated':
        return const _Visual(Icons.person, Colors.purple, 'Profile Updated');
      case 'password_changed':
        return const _Visual(Icons.lock, Colors.deepPurple, 'Password Changed');
      case 'email_changed':
        return const _Visual(Icons.email, Colors.orange, 'Email Changed');
      case 'account_deleted':
        return const _Visual(
            Icons.person_off, Colors.redAccent, 'Account Deleted');
      default:
        return _Visual(Icons.help_outline, Colors.grey, _humanize(action));
    }
  }

  // ---- Formatting ----
  static String _formatTime(DateTime ts) =>
      '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

  static String _formatDateKey(DateTime ts) =>
      '${ts.year.toString().padLeft(4, '0')}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';

  static String _formatDateLabel(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${ts.year}/${ts.month.toString().padLeft(2, '0')}/${ts.day.toString().padLeft(2, '0')}';
  }

  static String _humanize(String action) {
    if (action.isEmpty) return 'Unknown';
    return action
        .replaceAll('_', ' ')
        .replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());
  }
}

class _Visual {
  const _Visual(this.icon, this.color, this.title);
  final IconData icon;
  final Color color;
  final String title;
}
