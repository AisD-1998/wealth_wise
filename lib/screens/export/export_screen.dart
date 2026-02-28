import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/providers/currency_provider.dart';
import 'package:wealth_wise/services/export_service.dart';
import 'package:wealth_wise/theme/app_theme.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _exportTransactions = true;
  bool _exportBudgets = true;
  bool _exportSavingGoals = true;
  bool _isExporting = false;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  final DateFormat _displayFormat = DateFormat('MMM dd, yyyy');

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _handleExport() async {
    if (!_exportTransactions && !_exportBudgets && !_exportSavingGoals) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one data type to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final financeProvider =
        Provider.of<FinanceProvider>(context, listen: false);
    final currencyProvider =
        Provider.of<CurrencyProvider>(context, listen: false);
    final currencyCode = currencyProvider.currencyCode;

    try {
      String? result;

      // If exporting all selected types, use the combined export
      if (_exportTransactions && _exportBudgets && _exportSavingGoals) {
        result = await ExportService.exportAllToCSV(
          financeProvider.transactions,
          financeProvider.budgets,
          financeProvider.savingGoals,
          startDate: _startDate,
          endDate: _endDate,
          currencyCode: currencyCode,
        );
      } else if (_exportTransactions) {
        result = await ExportService.exportTransactionsToCSV(
          financeProvider.transactions,
          startDate: _startDate,
          endDate: _endDate,
          currencyCode: currencyCode,
        );
      } else if (_exportBudgets) {
        result = await ExportService.exportBudgetsToCSV(
          financeProvider.budgets,
          currencyCode: currencyCode,
        );
      } else if (_exportSavingGoals) {
        result = await ExportService.exportSavingGoalsToCSV(
          financeProvider.savingGoals,
          currencyCode: currencyCode,
        );
      }

      if (mounted) {
        if (result != null) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Export ready!'),
              backgroundColor: AppTheme.positiveGreen,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Export failed. Please try again.'),
              backgroundColor: AppTheme.negativeRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: AppTheme.negativeRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financeProvider = Provider.of<FinanceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info card
          Card(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 77),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Export your financial data as CSV files that can be opened in Excel, Google Sheets, or any spreadsheet app.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Date range section
          Text(
            'Date Range',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDateCard(
                  context,
                  label: 'From',
                  date: _startDate,
                  onTap: () => _pickDate(context, true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateCard(
                  context,
                  label: 'To',
                  date: _endDate,
                  onTap: () => _pickDate(context, false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Data types section
          Text(
            'Data to Export',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildDataTypeToggle(
            context,
            icon: Icons.receipt_long,
            title: 'Transactions',
            subtitle:
                '${financeProvider.transactions.length} transactions',
            value: _exportTransactions,
            onChanged: (v) => setState(() => _exportTransactions = v),
          ),
          const SizedBox(height: 8),
          _buildDataTypeToggle(
            context,
            icon: Icons.account_balance_wallet,
            title: 'Budgets',
            subtitle: '${financeProvider.budgets.length} budgets',
            value: _exportBudgets,
            onChanged: (v) => setState(() => _exportBudgets = v),
          ),
          const SizedBox(height: 8),
          _buildDataTypeToggle(
            context,
            icon: Icons.savings,
            title: 'Saving Goals',
            subtitle:
                '${financeProvider.savingGoals.length} goals',
            value: _exportSavingGoals,
            onChanged: (v) => setState(() => _exportSavingGoals = v),
          ),

          const SizedBox(height: 32),

          // Export button
          FilledButton.icon(
            onPressed: _isExporting ? null : _handleExport,
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(_isExporting ? 'Exporting...' : 'Export as CSV'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(
    BuildContext context, {
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              _displayFormat.format(date),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTypeToggle(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
