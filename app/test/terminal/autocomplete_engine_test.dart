import 'package:flutter_test/flutter_test.dart';
import 'package:termex/terminal/features/autocomplete/autocomplete_engine.dart';
import 'package:termex/terminal/features/autocomplete/suggestion_source.dart';

void main() {
  group('AutocompleteEngine', () {
    late AutocompleteEngine engine;

    setUp(() => engine = AutocompleteEngine());

    test('returns empty for empty input', () {
      expect(engine.query(''), isEmpty);
    });

    test('returns empty for input that ends with space (no token)', () {
      expect(engine.query('git '), isEmpty);
    });

    test('suggests built-in commands matching prefix', () {
      final suggestions = engine.query('gi');
      expect(suggestions.any((s) => s.value == 'git'), isTrue);
    });

    test('limits results to maxResults', () {
      final suggestions = engine.query('c', maxResults: 3);
      expect(suggestions.length, lessThanOrEqualTo(3));
    });

    test('deduplicates across sources', () {
      final hist = HistorySource([]);
      hist.addCommand('git status');
      engine.addSource(hist);

      final suggestions = engine.query('git');
      final values = suggestions.map((s) => s.value).toList();
      final unique = values.toSet();
      expect(values.length, unique.length);
    });

    test('history source suggests recent commands first', () {
      final hist = HistorySource([]);
      hist.addCommand('git rebase -i HEAD~3');
      final engine2 = AutocompleteEngine(sources: [hist]);
      final suggestions = engine2.query('git');
      expect(suggestions.first.value, 'git rebase -i HEAD~3');
    });
  });

  group('AutocompleteController', () {
    late AutocompleteController ctrl;

    setUp(() => ctrl = AutocompleteController());
    tearDown(() => ctrl.dispose());

    test('isOpen false when no suggestions', () {
      ctrl.onInputChanged('zzz_no_match');
      expect(ctrl.isOpen, isFalse);
    });

    test('isOpen true when suggestions exist', () {
      ctrl.onInputChanged('gi');
      expect(ctrl.isOpen, isTrue);
    });

    test('close clears suggestions', () {
      ctrl.onInputChanged('gi');
      ctrl.close();
      expect(ctrl.isOpen, isFalse);
      expect(ctrl.suggestions, isEmpty);
    });

    test('selectNext cycles through suggestions', () {
      ctrl.onInputChanged('gi');
      final initial = ctrl.selectedIndex;
      ctrl.selectNext();
      expect(ctrl.selectedIndex, isNot(initial));
    });

    test('acceptSelected returns suffix', () {
      ctrl.onInputChanged('gi');
      final suffix = ctrl.acceptSelected('gi');
      expect(suffix, isNotNull);
      expect(suffix, isNotEmpty);
    });
  });
}
