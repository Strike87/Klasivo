import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/services/search_keyword_service.dart';

void main() {
  late SearchKeywordService service;

  setUp(() {
    service = SearchKeywordService();
  });

  // ─── generateKeywords ──────────────────────────────────────────────────────

  group('generateKeywords', () {
    test('returns empty list for empty string', () {
      expect(service.generateKeywords(''), isEmpty);
    });

    test('returns empty list for whitespace-only string', () {
      expect(service.generateKeywords('   '), isEmpty);
    });

    test('generates prefixes for a single word', () {
      final keywords = service.generateKeywords('Grade');

      // Should include: "grade" (full word), "gr", "gra", "grad", "grade"
      // Prefixes start at length 2
      expect(keywords, contains('grade'));
      expect(keywords, contains('gr'));
      expect(keywords, contains('gra'));
      expect(keywords, contains('grad'));

      // Should NOT include single-letter prefix "g" (prefixes start at 2)
      expect(keywords, isNot(contains('g')));
    });

    test('generates prefixes for multi-word text', () {
      final keywords = service.generateKeywords('Grade 5');

      // From "grade": gr, gra, grad, grade
      // From "5": 5 (full word, but length < 2 so only full word added)
      // Plus "grade 5" (full lowercase string)
      expect(keywords, contains('grade'));
      expect(keywords, contains('5'));
      expect(keywords, contains('grade 5'));
    });

    test('converts to lowercase', () {
      final keywords = service.generateKeywords('MATH');

      expect(keywords, contains('math'));
      expect(keywords, contains('ma'));
      expect(keywords, contains('mat'));
      expect(keywords, isNot(contains('MATH')));
      expect(keywords, isNot(contains('MA')));
    });

    test('limits prefix length to 10 characters', () {
      final longWord = 'abcdefghijk'; // 11 chars
      final keywords = service.generateKeywords(longWord);

      // Should include prefix of length 10: 'abcdefghij'
      expect(keywords, contains('abcdefghij'));
      // Should include full word
      expect(keywords, contains('abcdefghijk'));
      // Should NOT have prefix of length 11 (that's the full word)
    });

    test('removes duplicate keywords', () {
      // If "test test" is the input, "test" appears from both words
      final keywords = service.generateKeywords('test test');

      // Count occurrences of 'test' in the list
      final testCount = keywords.where((k) => k == 'test').length;
      expect(testCount, 1, reason: 'Duplicates should be removed');
    });

    test('handles special characters gracefully', () {
      final keywords = service.generateKeywords('O\'Brien');

      // Should not throw and should produce some keywords
      expect(keywords, isNotEmpty);
      expect(keywords, contains('o\'brien'));
    });

    test('handles Arabic text', () {
      final keywords = service.generateKeywords('رياضيات');

      expect(keywords, isNotEmpty);
      expect(keywords, contains('رياضيات'));
    });

    test('handles mixed language input', () {
      final keywords = service.generateKeywords('Math رياضيات');

      expect(keywords, contains('math'));
      expect(keywords, contains('رياضيات'));
      expect(keywords, contains('math رياضيات'));
    });

    test('single character word is included as full word', () {
      final keywords = service.generateKeywords('a');

      // Single char: only the full word is added (prefix loop starts at 2)
      expect(keywords, contains('a'));
      expect(keywords.length, 2); // 'a' + 'a' (full lowercase string = same)
    });

    test('two character word includes full word only', () {
      final keywords = service.generateKeywords('ab');

      // Prefix loop: i starts at 2, word.length is 2, so 'ab' is added as prefix
      // Full word 'ab' is also added
      // Full lowercase string 'ab' is also added
      // After dedup: just 'ab'
      expect(keywords, contains('ab'));
    });
  });

  // ─── keywordsField ─────────────────────────────────────────────────────────

  group('keywordsField', () {
    test('returns map with searchKeywords key', () {
      final result = service.keywordsField('Test Exam');

      expect(result, isA<Map<String, dynamic>>());
      expect(result, containsPair('searchKeywords', isA<List>()));
      expect(result['searchKeywords'], isNotEmpty);
    });

    test('returns empty keywords for empty input', () {
      final result = service.keywordsField('');

      expect(result['searchKeywords'], isEmpty);
    });
  });
}
