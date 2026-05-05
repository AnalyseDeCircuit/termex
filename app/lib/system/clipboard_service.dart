/// Clipboard integration service (v0.48 spec §6.1).
library;

import 'package:flutter/services.dart';

class ClipboardService {
  ClipboardService._();

  static final ClipboardService instance = ClipboardService._();

  Future<String> read() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text ?? '';
  }

  Future<void> write(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> clear() async {
    await Clipboard.setData(const ClipboardData(text: ''));
  }
}
