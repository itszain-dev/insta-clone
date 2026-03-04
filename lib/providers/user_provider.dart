import 'package:flutter/widgets.dart';
import 'package:instagram_clone_flutter/models/user.dart';
import 'package:instagram_clone_flutter/resources/auth_methods.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  final AuthMethods _authMethods = AuthMethods();

  User? get user => _user;

  Future<void> refreshUser() async {
    try {
      final fetched = await _authMethods.getUserDetails();
      _user = fetched;
    } catch (_) {
      // leave user as-is on failure (e.g., offline)
    }
    notifyListeners();
  }
}
