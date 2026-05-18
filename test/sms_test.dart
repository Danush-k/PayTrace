import 'package:flutter_test/flutter_test.dart';
import 'package:paytrace/core/utils/sms_transaction_parser.dart';

void main() {
  test('parse canara bank sms', () {
    final sms = "An amount of INR 1.00 has been CREDITED to your account XXX389 on 13/03/2026.Total Avail.bal INR 224.36.- Canara Bank";
    
    final parsed = SmsTransactionParser.parse(
      body: sms,
      sender: "AD-CANBNK",
      timestamp: DateTime.now(),
    );
    expect(parsed, isNotNull);
    expect(parsed?.isIncome, true);
    expect(parsed?.amount, 1.00);
  });

  group('Credit Sender Name Extraction Fixes', () {
    test('P16g - SBI: credited to your a/c from NAME', () {
      final parsed = SmsTransactionParser.parse(
        body: "INR 500 credited to your a/c XX1234 from Ravi Kumar",
        sender: "SBIINB",
        timestamp: DateTime.now(),
      );
      expect(parsed?.isIncome, true);
      expect(parsed?.merchant, "Ravi Kumar");
    });

    test('P16b - Received Rs.X from NAME', () {
      final parsed = SmsTransactionParser.parse(
        body: "Received Rs.500 from Arjun Kumar. UPI Ref: 12345",
        sender: "ICICIB",
        timestamp: DateTime.now(),
      );
      expect(parsed?.isIncome, true);
      expect(parsed?.merchant, "Arjun Kumar");
    });

    test('P16c - NAME has sent you Rs.X (GPay/PhonePe)', () {
      final parsed = SmsTransactionParser.parse(
        body: "Rahul Sharma has sent you Rs.100 via Google Pay",
        sender: "GPAY",
        timestamp: DateTime.now(),
      );
      expect(parsed?.isIncome, true);
      expect(parsed?.merchant, "Rahul Sharma");
    });

    test('P16a - credited with INR X from NAME', () {
      final parsed = SmsTransactionParser.parse(
        body: "Your a/c credited with INR 300 from Priya Singh on 12-Mar",
        sender: "IOBCHN",
        timestamp: DateTime.now(),
      );
      expect(parsed?.isIncome, true);
      expect(parsed?.merchant, "Priya Singh");
    });

    test('P16 - credited by NAME without trailing context', () {
      final parsed = SmsTransactionParser.parse(
        body: "Rs.200 credited by MANIKANDAN",
        sender: "AXISBK",
        timestamp: DateTime.now(),
      );
      expect(parsed?.isIncome, true);
      expect(parsed?.merchant, "Manikandan"); // Note normalization Title Case
    });

    test('P16h - SBI style credited by NAME-UPI', () {
      final parsed = SmsTransactionParser.parse(
        body: "Rs.500 credited by ARJUN KUMAR-UPI Ref No 12345",
        sender: "SBINOB",
        timestamp: DateTime.now(),
      );
      expect(parsed?.isIncome, true);
      expect(parsed?.merchant, "Arjun Kumar");
    });
  });
}
