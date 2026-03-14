import 'dart:io';
import 'lib/core/utils/sms_transaction_parser.dart';

void main() {
  final tests = [
    {
      'body': "An amount of INR 1.00 has been CREDITED to your account XXX389 on 13/03/2026.Total Avail.bal INR 224.36.- Canara Bank",
      'sender': "AD-CANBNK",
      'expectedMerchant': null, // Falls back to Canara Bank in parser logic
    },
    {
      'body': "INR 500 credited to your a/c XX1234 from Ravi Kumar",
      'sender': "SBIINB",
      'expectedMerchant': "Ravi Kumar",
    },
    {
      'body': "Received Rs.500 from Arjun Kumar. UPI Ref: 12345",
      'sender': "ICICIB",
      'expectedMerchant': "Arjun Kumar",
    },
    {
      'body': "Rahul Sharma has sent you Rs.100 via Google Pay",
      'sender': "GPAY",
      'expectedMerchant': "Rahul Sharma",
    },
    {
      'body': "Your a/c credited with INR 300 from Priya Singh on 12-Mar",
      'sender': "IOBCHN",
      'expectedMerchant': "Priya Singh",
    },
    {
      'body': "Rs.200 credited by MANIKANDAN",
      'sender': "AXISBK",
      'expectedMerchant': "Manikandan", 
    },
    {
      'body': "Rs.500 credited by ARJUN KUMAR-UPI Ref No 12345",
      'sender': "SBINOB",
      'expectedMerchant': "Arjun Kumar",
    }
  ];

  int passed = 0;
  for (final t in tests) {
    print('Testing: ${t['body']}');
    final parsed = SmsTransactionParser.parse(
      body: t['body'] as String,
      sender: t['sender'] as String,
      timestamp: DateTime.now(),
    );
    
    if (parsed == null) {
      print('FAILED: parsed is null');
      continue;
    }

    if (!parsed.isIncome) {
      print('FAILED: Should be income');
      continue;
    }

    final expected = t['expectedMerchant'] as String?;
    final actual = parsed.merchant;

    if (expected != null && actual != expected) {
      print('FAILED: Expected merchant "$expected", got "$actual"');
    } else {
      print('PASSED: Merchant $actual');
      passed++;
    }
    print('---');
  }

  print('$passed/${tests.length} passed');
}
