import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/models/category.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/category_provider.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedIcon = '0xe1b1'; // Default to category icon
  Color _selectedColor = Colors.blue;
  bool _isLoading = true;

  // Tab controller for Income/Expense tabs
  late TabController _tabController;

  // Track the currently selected category type
  CategoryType _selectedCategoryType = CategoryType.expense;

  // Icon mapping for the dropdowns - using string values consistently
  final List<Map<String, dynamic>> _iconMap = [
    {'name': 'category', 'code': '0xe1b1'},
    {'name': 'restaurant', 'code': '0xe56c'},
    {'name': 'directions_car', 'code': '0xe531'},
    {'name': 'shopping_cart', 'code': '0xe59d'},
    {'name': 'receipt_long', 'code': '0xef6e'},
    {'name': 'movie', 'code': '0xe02c'},
    {'name': 'home', 'code': '0xe88a'},
    {'name': 'work', 'code': '0xe943'},
    {'name': 'school', 'code': '0xe80c'},
    {'name': 'fitness_center', 'code': '0xeb43'},
    {'name': 'local_hospital', 'code': '0xe548'},
    {'name': 'pets', 'code': '0xe91d'},
    {'name': 'child_care', 'code': '0xeb41'},
    {'name': 'sports_esports', 'code': '0xe50f'},
    {'name': 'music_note', 'code': '0xe403'},
    {'name': 'book', 'code': '0xe865'},
    {'name': 'computer', 'code': '0xe4e5'},
    {'name': 'phone_android', 'code': '0xe324'},
    {'name': 'build', 'code': '0xe869'},
    {'name': 'cleaning_services', 'code': '0xf0ff'},
    {'name': 'attach_money', 'code': '0xe227'},
    {'name': 'card_giftcard', 'code': '0xe8f6'},
    {'name': 'insert_chart', 'code': '0xe24b'},
    {'name': 'account_balance', 'code': '0xe84f'},
    {'name': 'savings', 'code': '0xe2eb'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Listen to tab changes to update the selected category type
    _tabController.addListener(() {
      setState(() {
        _selectedCategoryType = _tabController.index == 0
            ? CategoryType.expense
            : CategoryType.income;
      });
    });

    WidgetsBinding.instance.addObserver(this);
    _loadCategories();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload categories when app is resumed
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId =
          Provider.of<AuthProvider>(context, listen: false).user?.uid;
      if (userId != null) {
        await Provider.of<CategoryProvider>(context, listen: false)
            .loadCategoriesByUser(userId);
      }
    } catch (e) {
      // Handle error
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _showAddCategoryDialog() {
    // Reset selected values
    _nameController.clear();
    _selectedIcon = '0xe1b1';
    _selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (dialogContext) {
        // Use StatefulBuilder to update dialog UI when color is selected
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
                'Add New ${_selectedCategoryType == CategoryType.income ? 'Income' : 'Expense'} Category'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a category name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedIcon,
                      decoration: const InputDecoration(
                        labelText: 'Icon',
                        border: OutlineInputBorder(),
                      ),
                      items: _iconMap.map((Map<String, dynamic> icon) {
                        return DropdownMenuItem<String>(
                          value: icon['code'],
                          child: Row(
                            children: [
                              Icon(IconData(
                                _parseIconCode(icon['code']),
                                fontFamily: 'MaterialIcons',
                              )),
                              const SizedBox(width: 8),
                              Text(icon['name']),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setDialogState(() {
                            _selectedIcon = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        Colors.red,
                        Colors.pink,
                        Colors.purple,
                        Colors.deepPurple,
                        Colors.indigo,
                        Colors.blue,
                        Colors.lightBlue,
                        Colors.cyan,
                        Colors.teal,
                        Colors.green,
                        Colors.lightGreen,
                        Colors.lime,
                        Colors.yellow,
                        Colors.amber,
                        Colors.orange,
                        Colors.deepOrange,
                      ].map((Color color) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              _selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == color
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: _selectedColor == color
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(77),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final userId =
                        Provider.of<AuthProvider>(dialogContext, listen: false)
                            .user
                            ?.uid;
                    if (userId == null) {
                      Navigator.pop(dialogContext);
                      return;
                    }

                    final category = Category(
                      id: '${DateTime.now().millisecondsSinceEpoch}',
                      name: _nameController.text,
                      icon: _selectedIcon,
                      color: _selectedColor,
                      userId: userId,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                      type: _selectedCategoryType,
                    );

                    // Close dialog first, then do async operation
                    Navigator.pop(dialogContext);
                    _addCategory(category);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        });
      },
    );
  }

  // Separate method to handle async operation after dialog is closed
  Future<void> _addCategory(Category category) async {
    try {
      await Provider.of<CategoryProvider>(context, listen: false)
          .addCategory(category);
      _nameController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _showEditCategoryDialog(Category category) {
    _nameController.text = category.name;
    _selectedIcon = category.icon;
    _selectedColor = category.color;

    showDialog(
      context: context,
      builder: (dialogContext) {
        // Use StatefulBuilder to update dialog UI when color is selected
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
                'Edit ${category.type == CategoryType.income ? 'Income' : 'Expense'} Category'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a category name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedIcon,
                      decoration: const InputDecoration(
                        labelText: 'Icon',
                        border: OutlineInputBorder(),
                      ),
                      items: _iconMap.map((Map<String, dynamic> icon) {
                        return DropdownMenuItem<String>(
                          value: icon['code'],
                          child: Row(
                            children: [
                              Icon(IconData(
                                _parseIconCode(icon['code']),
                                fontFamily: 'MaterialIcons',
                              )),
                              const SizedBox(width: 8),
                              Text(icon['name']),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setDialogState(() {
                            _selectedIcon = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        Colors.red,
                        Colors.pink,
                        Colors.purple,
                        Colors.deepPurple,
                        Colors.indigo,
                        Colors.blue,
                        Colors.lightBlue,
                        Colors.cyan,
                        Colors.teal,
                        Colors.green,
                        Colors.lightGreen,
                        Colors.lime,
                        Colors.yellow,
                        Colors.amber,
                        Colors.orange,
                        Colors.deepOrange,
                      ].map((Color color) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              _selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == color
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: _selectedColor == color
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(77),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final updatedCategory = category.copyWith(
                      name: _nameController.text,
                      icon: _selectedIcon,
                      color: _selectedColor,
                      updatedAt: DateTime.now(),
                    );

                    // Close dialog first, then do async operation
                    Navigator.pop(dialogContext);
                    _updateCategory(updatedCategory);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  // Separate method to handle async operation after dialog is closed
  Future<void> _updateCategory(Category category) async {
    try {
      await Provider.of<CategoryProvider>(context, listen: false)
          .updateCategory(category);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = context.watch<AuthProvider>().user?.uid;
    final categoryProvider = context.watch<CategoryProvider>();
    final categories = categoryProvider.categories;

    if (userId == null) {
      return const Center(child: Text('Please sign in to manage categories'));
    }

    // Separate categories into income and expense lists
    final incomeCategories =
        categories.where((c) => c.type == CategoryType.income).toList();
    final expenseCategories =
        categories.where((c) => c.type == CategoryType.expense).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: 'EXPENSES',
              icon: Icon(Icons.arrow_downward),
            ),
            Tab(
              text: 'INCOME',
              icon: Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Expense categories tab
                _buildCategoryList(
                    context, expenseCategories, CategoryType.expense, theme),

                // Income categories tab
                _buildCategoryList(
                    context, incomeCategories, CategoryType.income, theme),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        tooltip: 'Add Category',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, List<Category> categories,
      CategoryType type, ThemeData theme) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == CategoryType.income
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${type == CategoryType.income ? 'income' : 'expense'} categories found',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a category to get started',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCategoryType = type;
                });
                _showAddCategoryDialog();
              },
              icon: const Icon(Icons.add),
              label: Text(
                  'Add ${type == CategoryType.income ? 'Income' : 'Expense'} Category'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: ListView.builder(
        itemCount: categories.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryCard(context, category);
        },
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Category category) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: category.color.withAlpha(51),
              child: Icon(
                IconData(
                  _parseIconCode(category.icon),
                  fontFamily: 'MaterialIcons',
                ),
                color: category.color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    category.type == CategoryType.income ? 'Income' : 'Expense',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: category.type == CategoryType.income
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditCategoryDialog(category),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: theme.colorScheme.error,
              onPressed: () => _showDeleteConfirmation(context, category),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteCategory(category);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(Category category) async {
    try {
      await Provider.of<CategoryProvider>(context, listen: false)
          .deleteCategory(category.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting category: $e')),
      );
    }
  }

  int _parseIconCode(String iconCode) {
    try {
      return int.parse(iconCode, radix: 16);
    } catch (e) {
      return 0xe1b1; // Default to category icon if parsing fails
    }
  }
}
