import 'dart:async';

import 'package:flutter/services.dart';

class ClipboardService {
  Timer? _clearTimer;

  Future<void> copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
  }

  Future<void> copySensitive(
    String value, {
    Duration clearAfter = const Duration(seconds: 30),
  }) async {
    _clearTimer?.cancel();

    await Clipboard.setData(ClipboardData(text: value));

    _clearTimer = Timer(clearAfter, () async {
      final currentData = await Clipboard.getData('text/plain');

      if (currentData?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  void dispose() {
    _clearTimer?.cancel();
  }
}
