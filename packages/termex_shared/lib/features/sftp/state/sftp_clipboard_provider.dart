/// In-memory SFTP clipboard — tracks copy/cut source for cross-pane paste.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SftpClipOp { copy, cut }

enum SftpClipSide { local, remote }

class SftpClipboard {
  final SftpClipSide side;
  final SftpClipOp operation;
  final List<String> filePaths;
  final String sourceDir;

  const SftpClipboard({
    required this.side,
    required this.operation,
    required this.filePaths,
    required this.sourceDir,
  });
}

final sftpClipboardProvider =
    StateProvider.family<SftpClipboard?, String>((ref, sessionId) => null);
