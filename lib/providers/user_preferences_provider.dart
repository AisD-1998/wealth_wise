import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wealth_wise/models/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferencesProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserPreferences? _userPreferences;
  bool _isLoading = false;
  String? _error;

  // Temporary onboarding answers (before user creates an account)
  FinancialGoal? _tempPrimaryGoal;
  List<FinancialGoal> _tempSecondaryGoals = [];
  IncomeRange? _tempIncomeRange;
  FinancialExpertise? _tempExpertise;
  bool _tempHasExistingBudget = false;
  bool _tempInterestedInInvesting = false;

  // Getters
  UserPreferences? get userPreferences => _userPreferences;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Temp preference getters
  FinancialGoal? get tempPrimaryGoal => _tempPrimaryGoal;
  List<FinancialGoal> get tempSecondaryGoals => _tempSecondaryGoals;
  IncomeRange? get tempIncomeRange => _tempIncomeRange;
  FinancialExpertise? get tempExpertise => _tempExpertise;
  bool get tempHasExistingBudget => _tempHasExistingBudget;
  bool get tempInterestedInInvesting => _tempInterestedInInvesting;

  // Set temporary preferences during onboarding
  void setTempPrimaryGoal(FinancialGoal goal) {
    _tempPrimaryGoal = goal;
    notifyListeners();
  }

  void toggleTempSecondaryGoal(FinancialGoal goal) {
    if (_tempSecondaryGoals.contains(goal)) {
      _tempSecondaryGoals.remove(goal);
    } else {
      _tempSecondaryGoals.add(goal);
    }
    notifyListeners();
  }

  void setTempIncomeRange(IncomeRange range) {
    _tempIncomeRange = range;
    notifyListeners();
  }

  void setTempExpertise(FinancialExpertise expertise) {
    _tempExpertise = expertise;
    notifyListeners();
  }

  void setTempHasExistingBudget(bool value) {
    _tempHasExistingBudget = value;
    notifyListeners();
  }

  void setTempInterestedInInvesting(bool value) {
    _tempInterestedInInvesting = value;
    notifyListeners();
  }

  // Reset temporary preferences
  void resetTempPreferences() {
    _tempPrimaryGoal = null;
    _tempSecondaryGoals = [];
    _tempIncomeRange = null;
    _tempExpertise = null;
    _tempHasExistingBudget = false;
    _tempInterestedInInvesting = false;
    notifyListeners();
  }

  // Save temporary preferences to local storage
  Future<void> saveTempPreferencesToLocal() async {
    final prefs = await SharedPreferences.getInstance();

    if (_tempPrimaryGoal != null) {
      await prefs.setInt('tempPrimaryGoal', _tempPrimaryGoal!.index);
    }

    await prefs.setStringList('tempSecondaryGoals',
        _tempSecondaryGoals.map((goal) => goal.index.toString()).toList());

    if (_tempIncomeRange != null) {
      await prefs.setInt('tempIncomeRange', _tempIncomeRange!.index);
    }

    if (_tempExpertise != null) {
      await prefs.setInt('tempExpertise', _tempExpertise!.index);
    }

    await prefs.setBool('tempHasExistingBudget', _tempHasExistingBudget);
    await prefs.setBool(
        'tempInterestedInInvesting', _tempInterestedInInvesting);
  }

  // Load temporary preferences from local storage
  Future<void> loadTempPreferencesFromLocal() async {
    final prefs = await SharedPreferences.getInstance();

    final primaryGoalIndex = prefs.getInt('tempPrimaryGoal');
    if (primaryGoalIndex != null &&
        primaryGoalIndex < FinancialGoal.values.length) {
      _tempPrimaryGoal = FinancialGoal.values[primaryGoalIndex];
    }

    final secondaryGoalsString = prefs.getStringList('tempSecondaryGoals');
    if (secondaryGoalsString != null) {
      _tempSecondaryGoals = secondaryGoalsString
          .map((index) => int.tryParse(index))
          .where(
              (index) => index != null && index < FinancialGoal.values.length)
          .map((index) => FinancialGoal.values[index!])
          .toList();
    }

    final incomeRangeIndex = prefs.getInt('tempIncomeRange');
    if (incomeRangeIndex != null &&
        incomeRangeIndex < IncomeRange.values.length) {
      _tempIncomeRange = IncomeRange.values[incomeRangeIndex];
    }

    final expertiseIndex = prefs.getInt('tempExpertise');
    if (expertiseIndex != null &&
        expertiseIndex < FinancialExpertise.values.length) {
      _tempExpertise = FinancialExpertise.values[expertiseIndex];
    }

    _tempHasExistingBudget = prefs.getBool('tempHasExistingBudget') ?? false;
    _tempInterestedInInvesting =
        prefs.getBool('tempInterestedInInvesting') ?? false;

    notifyListeners();
  }

  // Save user preferences to Firestore after user signs in
  Future<void> saveUserPreferences(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Ensure we have the primary fields
      if (_tempPrimaryGoal == null ||
          _tempIncomeRange == null ||
          _tempExpertise == null) {
        throw Exception('Missing required preference data');
      }

      // Create user preferences
      final userPrefs = UserPreferences(
        userId: userId,
        primaryGoal: _tempPrimaryGoal!,
        secondaryGoals: _tempSecondaryGoals,
        incomeRange: _tempIncomeRange!,
        expertise: _tempExpertise!,
        hasExistingBudget: _tempHasExistingBudget,
        interestedInInvesting: _tempInterestedInInvesting,
      );

      // Save to Firestore
      await _firestore
          .collection('userPreferences')
          .doc(userId)
          .set(userPrefs.toMap());

      // Update local state
      _userPreferences = userPrefs;

      // Clear temporary preferences
      resetTempPreferences();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Load user preferences from Firestore
  Future<void> loadUserPreferences(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final docSnapshot =
          await _firestore.collection('userPreferences').doc(userId).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        _userPreferences = UserPreferences.fromMap(
          docSnapshot.data()!,
          userId,
        );
      } else {
        // If no preferences exist yet but we have temporary ones, save them
        if (_tempPrimaryGoal != null &&
            _tempIncomeRange != null &&
            _tempExpertise != null) {
          await saveUserPreferences(userId);
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user preferences
  Future<void> updateUserPreferences(UserPreferences updatedPreferences) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestore
          .collection('userPreferences')
          .doc(updatedPreferences.userId)
          .update(updatedPreferences.toMap());

      _userPreferences = updatedPreferences;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Clear user preferences on sign out
  void clearUserPreferences() {
    _userPreferences = null;
    notifyListeners();
  }
}
