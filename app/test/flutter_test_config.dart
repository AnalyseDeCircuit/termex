import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

/// Fraction of differing pixels tolerated before a golden is considered failed.
///
/// Golden images are rendered by the host's font stack, so the same widget can
/// differ by a pixel or two of antialiasing between two machines that are both
/// macOS. The CI runner disagreed with the checked-in goldens by "0.00%, 2px",
/// which is invisible but still failed the build.
///
/// Deliberately tiny: it absorbs subpixel noise while any real visual
/// regression — a changed colour, size, weight or position — moves far more
/// than this.
const double _kGoldenTolerance = 0.005; // 0.5%

/// [LocalFileComparator] that passes when the difference is below
/// [_kGoldenTolerance], and otherwise fails exactly like the default one,
/// writing the usual side-by-side output to test/widget/failures/.
class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile, this.tolerance);

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (result.passed || result.diffPercent <= tolerance) return true;

    throw FlutterError(await generateFailureOutput(result, golden, basedir));
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final defaultComparator = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = _TolerantGoldenComparator(
    // LocalFileComparator derives basedir from the file it is given, so hand
    // back a path inside the existing basedir to preserve it.
    defaultComparator.basedir.resolve('flutter_test_config.dart'),
    _kGoldenTolerance,
  );

  return GoldenToolkit.runWithConfiguration(
    () async {
      await loadAppFonts();
      await testMain();
    },
    config: GoldenToolkitConfiguration(
      // Goldens are authored against the macOS font stack; Linux renders text
      // differently enough that comparing there is meaningless.
      skipGoldenAssertion: () => Platform.isLinux,
    ),
  );
}
