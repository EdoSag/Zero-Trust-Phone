import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_phone/util/pasted_numbers.dart';

void main() {
  group('PastedNumbers.find', () {
    test('Israeli local formats keep their trunk zero', () {
      expect(PastedNumbers.find('054-123-4567'), <String>['0541234567']);
      expect(PastedNumbers.find('054 1234567'), <String>['0541234567']);
      expect(PastedNumbers.find('(03) 123.4567'), <String>['031234567']);
      expect(PastedNumbers.find('077-1234567'), <String>['0771234567']);
      expect(PastedNumbers.find('1-800-200-300'), <String>['1800200300']);
    });

    test('+972 and its common misspellings become +972 without the zero', () {
      for (final String s in <String>[
        '+972-54-123-4567',
        '+972 (0)54 123 4567',
        '+972 054-1234567',
        '+9720541234567',
        '00972541234567',
        '00 972 54 123 4567',
        '972541234567',
        '972-54-1234567',
        'tel:+972541234567',
      ]) {
        expect(PastedNumbers.find(s), <String>['+972541234567'], reason: s);
      }
      expect(PastedNumbers.find('+972-3-123-4567'), <String>['+97231234567']);
    });

    test('other countries', () {
      expect(PastedNumbers.find('+44 (0)20 7946 0000'), <String>[
        '+442079460000',
      ]);
      expect(PastedNumbers.find('+1 (415) 555-0100'), <String>['+14155550100']);
      expect(PastedNumbers.find('0049 30 1234567'), <String>['+49301234567']);
    });

    test('numbers inside Hebrew and English text', () {
      expect(
        PastedNumbers.find('היי, זה דני. הנייד שלי: 052-765-4321 תודה!'),
        <String>['0527654321'],
      );
      expect(
        PastedNumbers.find(
          'Best,\nDana Cohen\nMobile: +972 52 765 4321\nOffice: 03-1234567',
        ),
        <String>['+972527654321', '031234567'],
      );
      // Hebrew text often carries invisible direction marks.
      expect(
        PastedNumbers.find('טלפון:\u200F \u202A054\u2011123\u20114567\u202C'),
        <String>['0541234567'],
      );
      expect(PastedNumbers.find('לבירורים חייגו *2700'), <String>['*2700']);
    });

    test('two numbers side by side, and stray digits before one', () {
      expect(PastedNumbers.find('054-1234567 03-7654321'), <String>[
        '0541234567',
        '037654321',
      ]);
      expect(PastedNumbers.find('054 123 4567 / 052 765 4321'), <String>[
        '0541234567',
        '0527654321',
      ]);
      expect(PastedNumbers.find('Room 12 054-1234567'), <String>['0541234567']);
    });

    test('Arabic-Indic and full-width digits', () {
      expect(PastedNumbers.find('٠٥٤١٢٣٤٥٦٧'), <String>['0541234567']);
      expect(PastedNumbers.find('＋９７２５４１２３４５６７'), <String>['+972541234567']);
    });

    test('dates, times, prices, codes and card numbers are not numbers', () {
      expect(PastedNumbers.find('Meeting 13.11.2026 at 20:12'), isEmpty);
      expect(PastedNumbers.find('Due 2026-11-13'), isEmpty);
      expect(PastedNumbers.find('Total ₪1,234.50'), isEmpty);
      expect(PastedNumbers.find('Your code is 482913'), isEmpty);
      expect(PastedNumbers.find('4580 1234 5678 9012 3456'), isEmpty);
      expect(PastedNumbers.find('no numbers here'), isEmpty);
    });

    test('the same number twice is offered once', () {
      expect(
        PastedNumbers.find('+972-54-1234567 (or 00972541234567)'),
        <String>['+972541234567'],
      );
    });
  });
}
