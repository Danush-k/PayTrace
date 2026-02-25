import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../data/database/app_database.dart';
import '../core/utils/formatters.dart';

/// Export transactions to CSV for external use
class ExportService {
  ExportService._();

  /// Export list of transactions to CSV and share
  static Future<void> exportToCsv(List<Transaction> transactions) async {
    final headers = [
      'Date',
      'Time',
      'Payee Name',
      'Payee UPI ID',
      'Amount (₹)',
      'Status',
      'Note',
      'Category',
      'UPI App',
      'Transaction ID',
      'Payment Mode',
    ];

    final rows = transactions.map((t) => [
          Formatters.dateShort(t.createdAt),
          Formatters.timeOnly(t.createdAt),
          t.payeeName,
          t.payeeUpiId,
          t.amount.toStringAsFixed(2),
          t.status,
          t.transactionNote ?? '',
          t.category,
          t.upiAppName ?? 'Unknown',
          t.upiTxnId ?? t.transactionRef,
          t.paymentMode,
        ]);

    final csvData = const ListToCsvConverter().convert([headers, ...rows]);

    final dir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/paytrace_export_$timestamp.csv');
    await file.writeAsString(csvData);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'PayTrace Transactions Export',
    );
  }
}
