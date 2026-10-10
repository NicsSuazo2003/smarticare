import 'package:flutter/foundation.dart';

class UserSessionProvider extends ChangeNotifier {
  bool _isGuest = false;
  bool get isGuest => _isGuest;

  void setGuest(bool value) {
    _isGuest = value;
    notifyListeners();
  }
}
