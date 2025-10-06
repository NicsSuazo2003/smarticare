import 'package:connectivity_plus/connectivity_plus.dart';
import 'reminder_sync_service.dart';

void listenForConnectivity(String userId, ReminderSyncService syncService) {
  Connectivity().onConnectivityChanged.listen((status) {
    if (status != ConnectivityResult.none) {
      syncService.syncAll(userId);
    }
  });
}
