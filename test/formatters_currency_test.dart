import 'package:flutter_test/flutter_test.dart';
import 'package:paytrace/core/utils/formatters.dart';

void main() {
  group('INR currency formatting', () {
    test('formats whole amounts with rupee symbol for chart use', () {
      expect(Formatters.currencyWhole(0), '₹0');
      expect(Formatters.currencyWhole(100), '₹100');
      expect(Formatters.currencyWhole(250), '₹250');
    });

    test('keeps Indian digit grouping for larger values', () {
      expect(Formatters.currencyWhole(1234), '₹1,234');
      expect(Formatters.currencyWhole(1234567), '₹12,34,567');
    });
  });
}
