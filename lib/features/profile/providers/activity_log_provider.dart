import 'package:flutter/foundation.dart';

import '../../../core/utils/logger.dart';
import '../data/activity_log_mapper.dart';
import '../data/activity_log_repository.dart';

class ActivityLogProvider extends ChangeNotifier {
  ActivityLogProvider({ActivityLogRepository? repository})
      : _repo = repository ?? ActivityLogRepository();

  final ActivityLogRepository _repo;

  List<ActivityItem> _items = [];
  bool _loading = true;
  String? _error;

  List<ActivityItem> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await _repo.fetchRawActivities();
      _items = raw.map(ActivityLogMapper.fromFirestore).toList();
    } catch (e, st) {
      _error = 'Failed to load activity: $e';
      Logger.e('ActivityLogProvider.load failed', e, st);
      _items = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
