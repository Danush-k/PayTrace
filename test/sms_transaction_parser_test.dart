import 'package:flutter_test/flutter_test.dart';
import 'package:paytrace/core/utils/sms_transaction_parser.dart';

void main() {
  final now = DateTime(2026, 3, 4, 10, 30);

  // ═══════════════════════════════════════════════════════
  //  VALID TRANSACTION SMS — SHOULD PARSE SUCCESSFULLY
  // ═══════════════════════════════════════════════════════

  group('Valid debit (expense) SMS', () {
    test('SBI debit SMS with UPI ref', () {
      final result = SmsTransactionParser.parse(
        body:
            'Dear Customer, Rs.500.00 debited from A/c XX1234 on 04-03-26. '
            'UPI Ref No 412345678901. Info: UPI/P2P/412345678901/JOHN DOE/john@ybl/SBI. '
            'If not done by you call 1800112211.',
        sender: 'BK-SBIINB',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 500.00);
      expect(result.type, 'expense');
      expect(result.merchant, 'JOHN DOE');
      expect(result.upiRef, '412345678901');
      expect(result.accountHint, '1234');
      expect(result.confidence, greaterThanOrEqualTo(0.7));
    });

    test('HDFC debit via IMPS', () {
      final result = SmsTransactionParser.parse(
        body:
            'Rs 1,500.00 has been debited from your A/c XXXX5678 '
            'by IMPS transfer to RAVI KUMAR Ref no 312345678901',
        sender: 'AD-HDFCBK',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 1500.00);
      expect(result.type, 'expense');
      expect(result.merchant, 'RAVI KUMAR');
    });

    test('UPI payment — "paid to"', () {
      final result = SmsTransactionParser.parse(
        body:
            'You have done a UPI txn of Rs 200 paid to SWIGGY via UPI. '
            'UPI Ref No 512345678901. Avl Bal Rs 8,500',
        sender: 'VM-ICICIB',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 200.00);
      expect(result.type, 'expense');
      expect(result.merchant, 'SWIGGY');
      expect(result.category, 'Food & Dining');
    });

    test('₹ symbol amount', () {
      final result = SmsTransactionParser.parse(
        body:
            '₹350 debited from your A/c XX9999 on 04-Mar-26. '
            'UPI/P2M/612345678901/merchant@ybl. Avl Bal ₹12,500',
        sender: 'BK-AXISBK',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 350.00);
      expect(result.type, 'expense');
    });

    test('INR format amount', () {
      final result = SmsTransactionParser.parse(
        body:
            'INR 2,500.00 sent via UPI to UBER INDIA from A/c XX4321. '
            'Ref No 712345678901',
        sender: 'AD-KOTAKB',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 2500.00);
      expect(result.type, 'expense');
      expect(result.category, 'Transport');
    });

    test('NEFT transfer', () {
      final result = SmsTransactionParser.parse(
        body:
            'Rs.10,000.00 transferred from A/c XX7890 via NEFT to '
            'PRIYA SHARMA Ref no NEFTN12345',
        sender: 'BK-PNBSMS',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 10000.00);
      expect(result.type, 'expense');
      expect(result.merchant, 'PRIYA SHARMA');
    });

    test('"spent" keyword', () {
      final result = SmsTransactionParser.parse(
        body:
            'Rs 450 spent on your A/c XX2222 at FLIPKART on 04-Mar. '
            'Txn Id 812345678901. Avl Bal Rs 5,500',
        sender: 'BK-ICICIB',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 450.00);
      expect(result.type, 'expense');
      expect(result.category, 'Shopping');
    });
  });

  group('Valid credit (income) SMS', () {
    test('UPI credit received', () {
      final result = SmsTransactionParser.parse(
        body:
            'Rs 3,000.00 credited to your A/c XX1234 by UPI. '
            'UPI Ref No 912345678901. From ANKIT VERMA via UPI.',
        sender: 'BK-SBIINB',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 3000.00);
      expect(result.type, 'income');
      expect(result.merchant, 'ANKIT VERMA');
    });

    test('IMPS credit', () {
      final result = SmsTransactionParser.parse(
        body:
            '₹15,000 deposited to your A/c XX5555 via IMPS from '
            'SALARY ACCOUNT Ref 012345678901',
        sender: 'AD-HDFCBK',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 15000.00);
      expect(result.type, 'income');
    });

    test('"received from" pattern', () {
      final result = SmsTransactionParser.parse(
        body:
            'Rs.500.00 received from SURESH KUMAR via UPI to A/c XX7777. '
            'UPI Ref: 112345678901',
        sender: 'BK-CANBNK',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 500.00);
      expect(result.type, 'income');
      expect(result.merchant, 'SURESH KUMAR');
    });
  });

  // ═══════════════════════════════════════════════════════
  //  SIMPLE FORMAT — keyword-based detection
  //  Ensures: amount + ONE banking keyword is sufficient.
  //  Bank context words (a/c, account, ref no) are optional.
  // ═══════════════════════════════════════════════════════

  group('Simple credit messages — unknown sender', () {
    test('"Rs 500 credited to your account" — generic sender', () {
      // Core requirement: simple credit with unknown sender must parse.
      final result = SmsTransactionParser.parse(
        body: 'Rs 500 credited to your account',
        sender: 'VM-GENBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.amount, 500.0);
      expect(result.type, 'income');
    });

    test('"₹500 credited to your account" — rupee symbol', () {
      final result = SmsTransactionParser.parse(
        body: '₹500 credited to your account',
        sender: 'VM-ANYBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.amount, 500.0);
      expect(result.type, 'income');
    });

    test('"INR 500 credited to your account"', () {
      final result = SmsTransactionParser.parse(
        body: 'INR 500 credited to your account',
        sender: 'VM-ANYBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.amount, 500.0);
      expect(result.type, 'income');
    });

    test('"Rs 500 credited to your account by Rahul" — merchant extracted', () {
      final result = SmsTransactionParser.parse(
        body: 'Rs 500 credited to your account by RAHUL.',
        sender: 'VM-GENBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.amount, 500.0);
      expect(result.type, 'income');
      expect(result.merchant, 'RAHUL');
    });
  });

  group('Banking keyword detection — each required keyword', () {
    test('"debited" keyword', () {
      final result = SmsTransactionParser.parse(
        body: 'Rs 300 debited from your account',
        sender: 'VM-ANYBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.type, 'expense');
    });

    test('"credited" keyword', () {
      final result = SmsTransactionParser.parse(
        body: 'Rs 300 credited to your account',
        sender: 'VM-ANYBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.type, 'income');
    });

    test('"sent" keyword with amount', () {
      final result = SmsTransactionParser.parse(
        body: 'Rs 300 sent via UPI',
        sender: 'VM-ANYBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.type, 'expense');
    });

    test('"received" keyword', () {
      final result = SmsTransactionParser.parse(
        body: 'Rs 300 received from ARJUN',
        sender: 'VM-ANYBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.type, 'income');
    });

    test('"txn" keyword', () {
      final result = SmsTransactionParser.parse(
        body: 'Your UPI txn of Rs 250 is successful',
        sender: 'VM-ANYBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.amount, 250.0);
    });

    test('"UPI" keyword alone (with amount)', () {
      final result = SmsTransactionParser.parse(
        body: 'Rs 200 paid via UPI',
        sender: 'VM-ANYBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.amount, 200.0);
    });

    test('"IMPS" keyword alone (with amount)', () {
      final result = SmsTransactionParser.parse(
        body: 'Rs 750 transferred via IMPS',
        sender: 'VM-ANYBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.amount, 750.0);
    });

    test('"NEFT" keyword alone (with amount)', () {
      final result = SmsTransactionParser.parse(
        body: 'Rs 5000 transferred via NEFT',
        sender: 'VM-ANYBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.amount, 5000.0);
    });

    test('"RTGS" keyword alone (with amount)', () {
      final result = SmsTransactionParser.parse(
        body: 'Rs 1,00,000 transferred via RTGS',
        sender: 'VM-ANYBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.amount, 100000.0);
    });
  });

  group('Promo keyword rejection — each required keyword', () {
    test('"offer" keyword → REJECT', () {
      final result = SmsTransactionParser.parse(
        body: 'Special offer! Get Rs.500 off your first order. Shop now.',
        sender: 'AD-DEALS',
        timestamp: now,
      );
      expect(result, isNull);
    });

    test('"discount" keyword → REJECT', () {
      final result = SmsTransactionParser.parse(
        body: 'Flat Rs.200 discount on electronics this weekend only.',
        sender: 'AD-SHOPZ',
        timestamp: now,
      );
      expect(result, isNull);
    });

    test('"sale" keyword → REJECT', () {
      final result = SmsTransactionParser.parse(
        body: 'BIG SALE! Up to Rs.2000 off on all orders. Visit now.',
        sender: 'AD-SHOPZ',
        timestamp: now,
      );
      expect(result, isNull);
    });

    test('"cashback" keyword → REJECT', () {
      final result = SmsTransactionParser.parse(
        body: 'Get Rs.100 cashback on your next transaction. Use link.',
        sender: 'AD-PROMO',
        timestamp: now,
      );
      expect(result, isNull);
    });

    test('"coupon" keyword → REJECT', () {
      final result = SmsTransactionParser.parse(
        body: 'Use coupon SAVE50 to get Rs.50 off. Valid till 31-Mar.',
        sender: 'AD-PROMO',
        timestamp: now,
      );
      expect(result, isNull);
    });

    test('Real txn with "cashback" footer — ALLOW (banking override)', () {
      // Banks append promo text to real transaction alerts.
      // Strong banking signal (debited + a/c) must override the promo gate.
      final result = SmsTransactionParser.parse(
        body:
            'Rs 300 debited from A/c XX1234 via UPI to SWIGGY. '
            'Ref 112398765432. Earn cashback on this txn. T&C apply.',
        sender: 'BK-HDFCBK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.amount, 300.0);
      expect(result.type, 'expense');
    });
  });

  group('Amount format coverage', () {
    test('₹ symbol — no space', () {
      final result = SmsTransactionParser.parse(
        body: '₹1500 debited from your account',
        sender: 'VM-ANYBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.amount, 1500.0);
    });

    test('Rs (no dot) — space-separated', () {
      final result = SmsTransactionParser.parse(
        body: 'Rs 500 credited to your account',
        sender: 'VM-ANYBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.amount, 500.0);
    });

    test('INR format', () {
      final result = SmsTransactionParser.parse(
        body: 'INR 500 debited via NEFT',
        sender: 'VM-ANYBNK',
        timestamp: now,
      );
      expect(result, isNotNull);
      expect(result!.amount, 500.0);
    });
  });

  group('Edge cases — should still parse', () {
    test('Both debited and credited — debited first = expense', () {
      final result = SmsTransactionParser.parse(
        body:
            'Rs 1000 debited from your A/c XX1111 and credited to '
            'beneficiary MOHAN DAS via UPI. Ref 212345678901',
        sender: 'BK-SBIINB',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 1000.00);
    });

    test('Large amount with Indian comma format (1,50,000)', () {
      final result = SmsTransactionParser.parse(
        body:
            'Rs.1,50,000.00 debited from your A/c XX9876 via RTGS '
            'Ref no RTGSN56789. Avl Bal Rs 2,30,000',
        sender: 'BK-HDFCBK',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 150000.00);
      expect(result.type, 'expense');
    });

    test('SMS with bank promo footer BUT valid transaction', () {
      // Some banks append "Get 10% cashback offer" at the end
      // of real transaction SMS. Parser should allow it through.
      final result = SmsTransactionParser.parse(
        body:
            'Rs 200 debited from A/c XX1234 via UPI to ZOMATO. '
            'UPI Ref 312345678901. '
            'Get 10% cashback offer on next txn. T&C apply.',
        sender: 'BK-SBIINB',
        timestamp: now,
      );

      // Should STILL parse because debited + a/c is strong banking signal
      expect(result, isNotNull);
      expect(result!.amount, 200.00);
      expect(result.type, 'expense');
    });

    test('Subscription debit from bank = valid expense', () {
      final result = SmsTransactionParser.parse(
        body:
            'Rs 499 debited from A/c XX5555 via UPI for subscription renewal. '
            'UPI Ref 412345678901.',
        sender: 'BK-HDFCBK',
        timestamp: now,
      );

      // Bank debit for subscription IS a real expense
      expect(result, isNotNull);
      expect(result!.amount, 499.00);
      expect(result.type, 'expense');
    });
  });

  // ═══════════════════════════════════════════════════════
  //  INVALID / SPAM SMS — SHOULD BE REJECTED (return null)
  // ═══════════════════════════════════════════════════════

  group('Promotional messages — REJECT', () {
    test('Pure marketing SMS with ₹', () {
      final result = SmsTransactionParser.parse(
        body:
            'Flat ₹200 off on your next order! Use code SAVE200. '
            'Limited time offer. Shop now at example.com',
        sender: 'AD-OFFERS',
        timestamp: now,
      );
      expect(result, isNull);
    });

    test('Cashback promo', () {
      final result = SmsTransactionParser.parse(
        body:
            'Congratulations! You have won Rs.500 cashback. '
            'Claim your reward now at bit.ly/claim500',
        sender: 'VM-REWARD',
        timestamp: now,
      );
      expect(result, isNull);
    });

    test('Sale notification', () {
      final result = SmsTransactionParser.parse(
        body:
            'BIG SALE! Get up to Rs.5000 discount on electronics. '
            'Limited time offer. Visit store now!',
        sender: 'AD-SHOPIT',
        timestamp: now,
      );
      expect(result, isNull);
    });

    test('Premium trial message', () {
      final result = SmsTransactionParser.parse(
        body:
            'Start your premium trial for Rs.1/month. '
            'Watch unlimited movies. Subscribe now!',
        sender: 'VM-STREAM',
        timestamp: now,
      );
      expect(result, isNull);
    });
  });

  group('Non-financial senders — REJECT', () {
    test('Netflix notification', () {
      final result = SmsTransactionParser.parse(
        body:
            'Your Netflix subscription of Rs.649 has been renewed. '
            'Enjoy watching your favorite shows!',
        sender: 'VM-NETFLIX',
        timestamp: now,
      );
      expect(result, isNull);
    });

    test('Hotstar subscription', () {
      final result = SmsTransactionParser.parse(
        body:
            'Disney+ Hotstar premium activated! Rs.1499/year. '
            'Watch live cricket and movies. Download the app.',
        sender: 'AD-HOTSTAR',
        timestamp: now,
      );
      expect(result, isNull);
    });

    test('Swiggy promo', () {
      final result = SmsTransactionParser.parse(
        body:
            'Swiggy: Your order of Rs.350 is confirmed. '
            'Track your food at swiggy.com/track',
        sender: 'AD-SWIGGY',
        timestamp: now,
      );
      expect(result, isNull);
    });
  });

  group('OTP / verification — REJECT', () {
    test('OTP message', () {
      final result = SmsTransactionParser.parse(
        body:
            'Your OTP for UPI transaction of Rs.500 is 123456. '
            'Valid for 5 minutes. Do not share.',
        sender: 'BK-SBIINB',
        timestamp: now,
      );
      expect(result, isNull);
    });
  });

  group('Subscription notifications — REJECT', () {
    test('Plan renewal without banking language', () {
      final result = SmsTransactionParser.parse(
        body:
            'Your subscription of Rs.299/month has been renewed. '
            'Enjoy premium features. Manage at settings.',
        sender: 'VM-APPSVC',
        timestamp: now,
      );
      expect(result, isNull);
    });

    test('Membership expiry', () {
      final result = SmsTransactionParser.parse(
        body:
            'Your membership of Rs.999 expires on 15-Mar-26. '
            'Renew now to continue enjoying benefits.',
        sender: 'AD-CLUBSV',
        timestamp: now,
      );
      expect(result, isNull);
    });
  });

  group('Balance / mini-statement — REJECT', () {
    test('Balance inquiry', () {
      final result = SmsTransactionParser.parse(
        body:
            'Your A/c XX1234 available balance is Rs.25,000.00 as on '
            '04-Mar-26 10:30 AM.',
        sender: 'BK-SBIINB',
        timestamp: now,
      );
      expect(result, isNull);
    });
  });

  group('EMI / loan — REJECT', () {
    test('EMI due reminder', () {
      final result = SmsTransactionParser.parse(
        body:
            'Your EMI due of Rs.5,500 for loan account XX9999 is '
            'payable on 05-Mar-26. Pay your EMI to avoid late charges.',
        sender: 'BK-HDFCBK',
        timestamp: now,
      );
      expect(result, isNull);
    });

    test('Credit card bill', () {
      final result = SmsTransactionParser.parse(
        body:
            'Your credit card bill of Rs.12,500 is due on 10-Mar-26. '
            'Pay now to avoid interest charges.',
        sender: 'BK-ICICIB',
        timestamp: now,
      );
      expect(result, isNull);
    });
  });

  group('No amount — REJECT', () {
    test('SMS without amount', () {
      final result = SmsTransactionParser.parse(
        body:
            'Your UPI transaction has been initiated. '
            'Please check your bank app for details.',
        sender: 'BK-SBIINB',
        timestamp: now,
      );
      expect(result, isNull);
    });
  });

  group('No transaction keyword — REJECT', () {
    test('SMS with amount but no banking keywords', () {
      final result = SmsTransactionParser.parse(
        body:
            'Your order worth Rs.1200 has been shipped. '
            'Track at example.com/track/12345',
        sender: 'AD-SHIPIT',
        timestamp: now,
      );
      expect(result, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════
  //  CATEGORY INFERENCE
  // ═══════════════════════════════════════════════════════

  group('Category inference', () {
    test('Food merchant → Food & Dining', () {
      final result = SmsTransactionParser.parse(
        body:
            'Rs 250 debited from A/c XX1234 via UPI to DOMINOS PIZZA. '
            'Ref 512345678901',
        sender: 'BK-SBIINB',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.category, 'Food & Dining');
    });

    test('Transport merchant → Transport', () {
      final result = SmsTransactionParser.parse(
        body:
            'Rs 150 debited from A/c XX1234 via UPI to OLA CABS. '
            'Ref 612345678901',
        sender: 'BK-SBIINB',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.category, 'Transport');
    });

    test('Credit SMS → Income category', () {
      final result = SmsTransactionParser.parse(
        body:
            'Rs 5000 credited to your A/c XX1234 via UPI from RAHUL. '
            'Ref 712345678901',
        sender: 'BK-SBIINB',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.category, 'Income');
    });
  });

  // ═══════════════════════════════════════════════════════
  //  BATCH PARSING
  // ═══════════════════════════════════════════════════════

  group('Batch parsing', () {
    test('parseBatch filters invalid and returns valid only', () {
      final messages = [
        {
          'sender': 'BK-SBIINB',
          'body':
              'Rs 500 debited from A/c XX1234 via UPI. Ref 812345678901',
          'timestamp': now.millisecondsSinceEpoch.toString(),
        },
        {
          'sender': 'AD-OFFERS',
          'body': 'Get Rs.200 off! Limited time sale!',
          'timestamp': now.millisecondsSinceEpoch.toString(),
        },
        {
          'sender': 'BK-HDFCBK',
          'body':
              'Rs 1000 credited to A/c XX5678 via IMPS. Ref 912345678901',
          'timestamp': now.millisecondsSinceEpoch.toString(),
        },
      ];

      final results = SmsTransactionParser.parseBatch(messages);
      expect(results.length, 2);
      expect(results[0].type, 'expense');
      expect(results[1].type, 'income');
    });
  });

  // ═══════════════════════════════════════════════════════
  //  CONFIDENCE SCORING
  // ═══════════════════════════════════════════════════════

  group('Confidence scoring', () {
    test('Full bank SMS has high confidence', () {
      final result = SmsTransactionParser.parse(
        body:
            'Rs 500 debited from A/c XX1234 via UPI to MERCHANT. '
            'UPI Ref No 012345678901. Avl Bal Rs 8,500',
        sender: 'BK-SBIINB',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.confidence, greaterThanOrEqualTo(0.8));
    });

    test('Minimal SMS has lower confidence', () {
      final result = SmsTransactionParser.parse(
        body: 'Rs 100 sent via UPI',
        sender: 'BK-SBIINB',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.confidence, lessThan(0.8));
    });
  });

  // ═══════════════════════════════════════════════════════
  //  toJson
  // ═══════════════════════════════════════════════════════

  group('Output structure', () {
    test('toJson produces correct shape', () {
      final result = SmsTransactionParser.parse(
        body:
            'Rs 500 debited from A/c XX1234 via UPI to MERCHANT. '
            'UPI Ref No 012345678901.',
        sender: 'BK-SBIINB',
        timestamp: now,
      );

      expect(result, isNotNull);
      final json = result!.toJson();
      expect(json['amount'], isA<double>());
      expect(json['merchant'], isA<String>());
      expect(json['type'], anyOf('expense', 'income'));
      expect(json['category'], isA<String>());
      expect(json['timestamp'], isA<String>());
      expect(json['confidence'], isA<double>());
    });
  });

  // ═══════════════════════════════════════════════════════
  //  ICICI BANK — semicolon format with UPI:NNNN ref
  // ═══════════════════════════════════════════════════════

  group('ICICI Bank semicolon format', () {
    test('ICICI debit — "; NAME credited" with UPI:ref', () {
      final result = SmsTransactionParser.parse(
        body:
            'ICICI Bank Acct XX131 debited for Rs 130.00 on 08-Mar-26; '
            'Saravana Hotel credited. UPI:606736706551.',
        sender: 'AD-ICICIT',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 130.00);
      expect(result.type, 'expense');
      expect(result.merchant, 'Saravana Hotel');
      expect(result.upiRef, '606736706551');
      expect(result.accountHint, '131');
    });

    test('ICICI debit — "; NAME credited" with suffixed sender ICICIT-S', () {
      final result = SmsTransactionParser.parse(
        body:
            'ICICI Bank Acct XX457 debited for Rs 250.00 on 10-Mar-26; '
            'Ajay Kumar Yada credited. UPI:712345678901.',
        sender: 'AD-ICICIT-S',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 250.00);
      expect(result.type, 'expense');
      expect(result.merchant, 'Ajay Kumar Yada');
      expect(result.upiRef, '712345678901');
      expect(result.accountHint, '457');
    });

    test('ICICI credit — "; NAME debited" (received money)', () {
      final result = SmsTransactionParser.parse(
        body:
            'ICICI Bank Acct XX131 credited for Rs 500.00 on 09-Mar-26; '
            'Rahul Sharma debited. UPI:812345678901.',
        sender: 'AD-ICICIT',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 500.00);
      expect(result.type, 'income');
      expect(result.merchant, 'Rahul Sharma');
      expect(result.upiRef, '812345678901');
    });

    test('ICICI debit — 4-digit account hint', () {
      final result = SmsTransactionParser.parse(
        body:
            'ICICI Bank Acct XX4321 debited for Rs 75.00 on 07-Mar-26; '
            'Tea Stall credited. UPI:912345678901.',
        sender: 'AD-ICICIT',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 75.00);
      expect(result.merchant, 'Tea Stall');
      expect(result.accountHint, '4321');
    });

    test('ICICI — merchant with dots and special chars', () {
      final result = SmsTransactionParser.parse(
        body:
            'ICICI Bank Acct XX999 debited for Rs 1,200.00 on 05-Mar-26; '
            "S.K. Pharma D'Cruz credited. UPI:112345678901.",
        sender: 'AD-ICICIT',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 1200.00);
      expect(result.type, 'expense');
      expect(result.merchant, isNotNull);
      expect(result.merchant.length, greaterThan(2));
    });
  });

  // ═══════════════════════════════════════════════════════
  //  GENERIC SEMICOLON FORMAT — works for any bank
  // ═══════════════════════════════════════════════════════

  group('Generic semicolon format (any bank)', () {
    test('Unknown bank — semicolon credited pattern', () {
      final result = SmsTransactionParser.parse(
        body:
            'Your A/c XX5678 debited for Rs 300.00 on 08-Mar-26; '
            'Fresh Mart credited. UPI Ref No 512345678901.',
        sender: 'VM-GENBNK',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 300.00);
      expect(result.type, 'expense');
      expect(result.merchant, 'Fresh Mart');
    });

    test('SBI — semicolon format if ever used', () {
      final result = SmsTransactionParser.parse(
        body:
            'SBI Acct XX1234 debited Rs 450.00 on 08-Mar-26; '
            'Grocery Store credited. UPI:112345678902.',
        sender: 'BK-SBIINB',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 450.00);
      expect(result.merchant, 'Grocery Store');
      expect(result.upiRef, '112345678902');
    });
  });

  // ═══════════════════════════════════════════════════════
  //  UPI: bare ref and Acct hint patterns
  // ═══════════════════════════════════════════════════════

  group('UPI bare ref and Acct hint', () {
    test('UPI:NNNN ref pattern (no "Ref No" prefix)', () {
      final result = SmsTransactionParser.parse(
        body:
            'Rs 200.00 debited from A/c XX9876. '
            'Paid to AMIT via UPI. UPI:998877665544.',
        sender: 'BK-HDFCBK',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.upiRef, '998877665544');
    });

    test('Acct XX with 3 digits', () {
      final result = SmsTransactionParser.parse(
        body:
            'Your Acct XX789 debited Rs 100.00 for UPI txn to Shop. '
            'Ref No 123456789012.',
        sender: 'AD-AXISBK',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.accountHint, '789');
    });

    test('Acct XX with 4 digits', () {
      final result = SmsTransactionParser.parse(
        body:
            'Your Acct XX7890 debited Rs 100.00 for UPI txn to Shop. '
            'Ref No 123456789012.',
        sender: 'AD-AXISBK',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.accountHint, '7890');
    });
  });

  // ═══════════════════════════════════════════════════════
  //  FALLBACK — suffixed senders resolve to bank name
  // ═══════════════════════════════════════════════════════

  group('Sender fallback with suffixes', () {
    test('ICICIT-S falls back to ICICI Bank (not raw sender)', () {
      // When no merchant name is extractable from body, fallback should
      // return "ICICI Bank" not "ICICIT-S"
      final result = SmsTransactionParser.parse(
        body:
            'Rs 50 debited from your account via UPI. '
            'Ref No 212345678901.',
        sender: 'AD-ICICIT-S',
        timestamp: now,
      );

      expect(result, isNotNull);
      // Even without a merchant pattern match, the fallback bank name
      // should be "ICICI Bank" not "ICICIT-S"
      expect(result!.merchant, isNot(contains('ICICIT')));
    });
  });
}
