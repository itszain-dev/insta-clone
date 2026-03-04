import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(false);
  final ValueNotifier<bool> hasResult = ValueNotifier<bool>(false);
  Timer? _timer;

  Future<void> _checkOnce() async {
    try {
      await Supabase.instance.client.from('posts').select('post_id').limit(1);
      if (!isOnline.value) isOnline.value = true;
      if (!hasResult.value) hasResult.value = true;
    } catch (_) {
      if (isOnline.value) isOnline.value = false;
      if (!hasResult.value) hasResult.value = true;
    }
  }

  void start() {
    _timer?.cancel();
    hasResult.value = false;
    unawaited(_checkOnce());
    _timer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _checkOnce();
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}
