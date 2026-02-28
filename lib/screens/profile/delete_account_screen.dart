import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:provider/provider.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/services/database_service.dart';
import 'package:wealth_wise/screens/auth/login_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  bool _isLoading = false;
  String? _errorMessage;
  bool _confirmDelete = false;
  bool _confirmUnderstand = false;
  bool _confirmDataDeletion = false;

  final DatabaseService _databaseService = DatabaseService();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _exportUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not found');
      }

      // Get user data from database
      final userData = await _databaseService.getUserData(user.uid);
      if (userData == null) {
        throw Exception('User data not found');
      }

      // Get user transactions
      final transactions = await _databaseService.getTransactions(user.uid);

      // Get user categories
      final categories = await _databaseService.getCategories(user.uid);

      // Get user budgets
      final budgets = await _databaseService.getBudgets(user.uid);

      // Get saving goals
      final savingGoals = await _databaseService.getSavingGoals(user.uid);

      // Create export data
      final exportData = {
        'user': userData.toMap(),
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'categories': categories.map((c) => c.toMap()).toList(),
        'budgets': budgets.map((b) => b.toMap()).toList(),
        'savingGoals': savingGoals.map((g) => g.toMap()).toList(),
      };

      // Show dialog with export data
      if (!mounted) return;

      // In a real app, this would generate a file to download
      // For now, we just show the data in a dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Your Data Export'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Here\'s a copy of your data:'),
                const SizedBox(height: 8),
                const Text(
                    'User info, transactions, categories, budgets, and saving goals.'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Export data available\n${exportData.keys.join(', ')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'In a production app, this would download a file to your device.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _allConfirmationsChecked =>
      _confirmDelete && _confirmUnderstand && _confirmDataDeletion;

  Future<void> _deleteAccount() async {
    if (!_formKey.currentState!.validate() || !_allConfirmationsChecked) {
      setState(() {
        _errorMessage =
            'Please confirm all checkboxes and provide your password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _reauthenticateUser();
      await _deleteAllUserData(user.uid);
      await user.delete();

      if (!mounted) return;
      _navigateAfterDeletion();
    } on firebase_auth.FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _firebaseAuthErrorMessage(e);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Re-authenticate the current user with their password.
  /// Throws if the user or email is missing.
  Future<firebase_auth.User> _reauthenticateUser() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not found');

    final email = user.email;
    if (email == null || email.isEmpty) throw Exception('User email not found');

    final credential = firebase_auth.EmailAuthProvider.credential(
      email: email,
      password: _passwordController.text,
    );
    await user.reauthenticateWithCredential(credential);
    return user;
  }

  /// Delete all Firestore data for the given user and mark the user record
  /// as deleted.
  Future<void> _deleteAllUserData(String userId) async {
    await _deleteUserTransactions(userId);
    await _deleteUserCategories(userId);
    await _deleteUserBudgets(userId);
    await _deleteUserSavingGoals(userId);
    await _markUserAsDeleted(userId);
  }

  Future<void> _deleteUserTransactions(String userId) async {
    final transactions = await _databaseService.getTransactions(userId);
    for (final transaction in transactions) {
      if (transaction.id != null && transaction.id!.isNotEmpty) {
        await _databaseService.deleteTransaction(transaction.id!);
      }
    }
  }

  Future<void> _deleteUserCategories(String userId) async {
    final categories = await _databaseService.getCategories(userId);
    for (final category in categories) {
      if (category.id.isNotEmpty) {
        await _databaseService.deleteCategory(category.id);
      }
    }
  }

  Future<void> _deleteUserBudgets(String userId) async {
    final budgets = await _databaseService.getBudgets(userId);
    for (final budget in budgets) {
      if (budget.id.isNotEmpty) {
        await _databaseService.deleteBudget(budget.id);
      }
    }
  }

  Future<void> _deleteUserSavingGoals(String userId) async {
    final savingGoals = await _databaseService.getSavingGoals(userId);
    for (final goal in savingGoals) {
      if (goal.id != null && goal.id!.isNotEmpty) {
        await _databaseService.deleteSavingGoal(goal.id!);
      }
    }
  }

  Future<void> _markUserAsDeleted(String userId) async {
    final userData = await _databaseService.getUserData(userId);
    if (userData != null) {
      await _databaseService.updateUserData(userData.copyWith(
        displayName: "DELETED_USER",
        email: "deleted_$userId@deleted.com",
        photoUrl: null,
        phoneNumber: null,
      ));
    }
  }

  /// Map a FirebaseAuthException to a user-friendly message.
  String _firebaseAuthErrorMessage(firebase_auth.FirebaseAuthException e) {
    const errorMessages = {
      'wrong-password': 'Password is incorrect.',
      'too-many-requests': 'Too many attempts. Please try again later.',
      'requires-recent-login':
          'Please sign out and sign in again before deleting your account.',
    };
    return errorMessages[e.code] ?? 'Error: ${e.message}';
  }

  void _navigateAfterDeletion() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearUser();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your account has been deleted')),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning card
              Card(
                color: theme.colorScheme.errorContainer.withAlpha(
                  (theme.colorScheme.errorContainer.a * 0.8).round(),
                ),
                margin: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: theme.colorScheme.error,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Warning: This Cannot Be Undone',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Deleting your account will permanently remove all your data including transactions, budgets, categories, and settings.',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Error message
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),

              // Data export section
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        'GDPR Data Export',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'You can download a copy of all your personal data before deleting your account.',
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _exportUserData,
                              icon: const Icon(Icons.download),
                              label: const Text('Export My Data'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Confirmation checkboxes
              CheckboxListTile(
                title: const Text(
                  'I understand that all my data will be permanently deleted',
                ),
                value: _confirmDelete,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _confirmDelete = value ?? false;
                        });
                      },
                activeColor: theme.colorScheme.primary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

              CheckboxListTile(
                title: const Text(
                  'I understand that this action cannot be undone',
                ),
                value: _confirmUnderstand,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _confirmUnderstand = value ?? false;
                        });
                      },
                activeColor: theme.colorScheme.primary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

              CheckboxListTile(
                title: const Text(
                  'I understand I will lose access to my data and transaction history',
                ),
                value: _confirmDataDeletion,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _confirmDataDeletion = value ?? false;
                        });
                      },
                activeColor: theme.colorScheme.primary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

              const SizedBox(height: 16),

              // Password confirmation
              Text(
                'Please enter your password to confirm:',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // Delete button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _deleteAccount,
                  icon: const Icon(Icons.delete_forever),
                  label: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(),
                        )
                      : const Text('Permanently Delete My Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
