import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/models/budget_model.dart';
import 'package:wealth_wise/models/saving_goal.dart';

class ExportService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Export transactions to CSV and share the file.
  /// Returns the file path on success, null on failure.
  static Future<String?> exportTransactionsToCSV(
    List<Transaction> transactions, {
    DateTime? startDate,
    DateTime? endDate,
    String currencyCode = 'USD',
  }) async {
    // Filter by date range if provided
    var filtered = transactions;
    if (startDate != null) {
      filtered = filtered.where((t) => !t.date.isBefore(startDate)).toList();
    }
    if (endDate != null) {
      filtered = filtered
          .where((t) => !t.date.isAfter(endDate.add(const Duration(days: 1))))
          .toList();
    }

    // Sort by date descending
    filtered.sort((a, b) => b.date.compareTo(a.date));

    final buf = StringBuffer();
    buf.writeln('Date,Title,Type,Category,Amount ($currencyCode),Notes');

    for (final t in filtered) {
      buf.writeln(
        '${_dateFormat.format(t.date)},'
        '${_escapeCsv(t.title)},'
        '${t.type == TransactionType.income ? 'Income' : 'Expense'},'
        '${_escapeCsv(t.category ?? 'Uncategorized')},'
        '${t.amount.toStringAsFixed(2)},'
        '${_escapeCsv(t.note ?? '')}',
      );
    }

    return _writeAndShare(buf.toString(), 'transactions');
  }

  /// Export budgets to CSV and share the file.
  static Future<String?> exportBudgetsToCSV(
    List<Budget> budgets, {
    String currencyCode = 'USD',
  }) async {
    final buf = StringBuffer();
    buf.writeln(
        'Category,Budget Amount ($currencyCode),Spent ($currencyCode),Remaining ($currencyCode),% Used,Start Date,End Date');

    for (final b in budgets) {
      buf.writeln(
        '${_escapeCsv(b.category)},'
        '${b.amount.toStringAsFixed(2)},'
        '${b.spent.toStringAsFixed(2)},'
        '${b.remainingAmount.toStringAsFixed(2)},'
        '${b.percentUsed.toStringAsFixed(1)},'
        '${_dateFormat.format(b.startDate)},'
        '${_dateFormat.format(b.endDate)}',
      );
    }

    return _writeAndShare(buf.toString(), 'budgets');
  }

  /// Export saving goals to CSV and share the file.
  static Future<String?> exportSavingGoalsToCSV(
    List<SavingGoal> goals, {
    String currencyCode = 'USD',
  }) async {
    final buf = StringBuffer();
    buf.writeln(
        'Title,Target ($currencyCode),Current ($currencyCode),Progress %,Target Date,Description');

    for (final g in goals) {
      buf.writeln(
        '${_escapeCsv(g.title)},'
        '${g.targetAmount.toStringAsFixed(2)},'
        '${g.currentAmount.toStringAsFixed(2)},'
        '${g.progressPercentage.toStringAsFixed(1)},'
        '${g.targetDate != null ? _dateFormat.format(g.targetDate!) : 'N/A'},'
        '${_escapeCsv(g.description ?? '')}',
      );
    }

    return _writeAndShare(buf.toString(), 'savings_goals');
  }

  /// Export all data (transactions + budgets + goals) into a single CSV.
  static Future<String?> exportAllToCSV(
    List<Transaction> transactions,
    List<Budget> budgets,
    List<SavingGoal> goals, {
    DateTime? startDate,
    DateTime? endDate,
    String currencyCode = 'USD',
  }) async {
    var filtered = transactions;
    if (startDate != null) {
      filtered = filtered.where((t) => !t.date.isBefore(startDate)).toList();
    }
    if (endDate != null) {
      filtered = filtered
          .where((t) => !t.date.isAfter(endDate.add(const Duration(days: 1))))
          .toList();
    }
    filtered.sort((a, b) => b.date.compareTo(a.date));

    final buf = StringBuffer();

    // Transactions section
    buf.writeln('=== TRANSACTIONS ===');
    buf.writeln('Date,Title,Type,Category,Amount ($currencyCode),Notes');
    for (final t in filtered) {
      buf.writeln(
        '${_dateFormat.format(t.date)},'
        '${_escapeCsv(t.title)},'
        '${t.type == TransactionType.income ? 'Income' : 'Expense'},'
        '${_escapeCsv(t.category ?? 'Uncategorized')},'
        '${t.amount.toStringAsFixed(2)},'
        '${_escapeCsv(t.note ?? '')}',
      );
    }

    buf.writeln();

    // Budgets section
    buf.writeln('=== BUDGETS ===');
    buf.writeln(
        'Category,Budget Amount ($currencyCode),Spent ($currencyCode),Remaining ($currencyCode),% Used,Start Date,End Date');
    for (final b in budgets) {
      buf.writeln(
        '${_escapeCsv(b.category)},'
        '${b.amount.toStringAsFixed(2)},'
        '${b.spent.toStringAsFixed(2)},'
        '${b.remainingAmount.toStringAsFixed(2)},'
        '${b.percentUsed.toStringAsFixed(1)},'
        '${_dateFormat.format(b.startDate)},'
        '${_dateFormat.format(b.endDate)}',
      );
    }

    buf.writeln();

    // Saving goals section
    buf.writeln('=== SAVING GOALS ===');
    buf.writeln(
        'Title,Target ($currencyCode),Current ($currencyCode),Progress %,Target Date,Description');
    for (final g in goals) {
      buf.writeln(
        '${_escapeCsv(g.title)},'
        '${g.targetAmount.toStringAsFixed(2)},'
        '${g.currentAmount.toStringAsFixed(2)},'
        '${g.progressPercentage.toStringAsFixed(1)},'
        '${g.targetDate != null ? _dateFormat.format(g.targetDate!) : 'N/A'},'
        '${_escapeCsv(g.description ?? '')}',
      );
    }

    return _writeAndShare(buf.toString(), 'wealthwise_export');
  }

  /// Escape a CSV field: wrap in quotes if it contains commas, quotes, or newlines.
  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Write CSV content to a temp file and trigger the system share sheet.
  static Future<String?> _writeAndShare(
      String csvContent, String filePrefix) async {
    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/${filePrefix}_$timestamp.csv');
      await file.writeAsString(csvContent);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'WealthWise Export — $filePrefix',
      );

      return file.path;
    } catch (e) {
      return null;
    }
  }
}
