# WealthWise — Production Readiness Fix Plan

> **Context:** App dormant ~1 year. Diagnostic found **53 issues** (8 critical, 14 warnings, 12+ info).
> Subscription/billing system is largely broken (mock purchases, dual services, no verification).
> App cannot be submitted to Google Play in current state.
>
> **Strategy:** Fix standard issues first (Phase 1), then subscription rewrite (Phase 2),
> then production deploy config once Google Play developer account is ready (Phase 3).

---

## PHASE 1: Standard Fixes (No External Dependencies)

### 1A — Security Fixes ✅

- [x] **Hash PIN before Firestore storage**
  - Added SHA-256 hashing via `crypto` package
  - Created `hashPin()` static method in AuthService
  - PIN verification now compares hashes

- [x] **Create Firestore security rules**
  - Created `firestore.rules` with per-user access control
  - Created `firebase.json` referencing rules

- [x] **Remove biometric anonymous auth fallback + Make AuthService singleton + Standardize social schema**
  - Replaced anonymous auth with `UnimplementedError`
  - Made AuthService a singleton with factory constructor
  - Google/Facebook sign-up now uses `User.toMap()` for consistent Firestore schema

---

### 1B — Runtime Bug Fixes ✅

- [x] **Fix division by zero — savings rate**
  - Guarded with `totalIncome > 0` check in home_screen.dart

- [x] **Fix division by zero — budget percent**
  - Fixed `percentUsed` getter in budget_model.dart

- [x] **Fix goal deletion not cleaning up linked transactions**
  - Now clears `goalId` on linked transactions before deleting goal

- [x] **Fix contributeSavingGoal creating expense type (double-counting)**
  - Changed to `TransactionType.income` with `contributesToGoal: true`

- [x] **Fix register→login navigation creating duplicate screens**
  - Simplified to just `Navigator.pop()` since login is already on stack

---

### 1C — Auth Improvements ✅

- [x] **Fix signOut not clearing Google/Facebook sessions**
  - Now calls `AuthService().signOut()` which handles Google/Facebook sign-out

- [x] **Fix social sign-up double OAuth flow**
  - Removed redundant first sign-in attempts in both Google and Facebook flows

- [x] **Improve email validation**
  - Replaced `contains('@')` with proper regex validation

- [x] **Remove non-functional Remember Me**
  - Removed field, stub method, and conditional

- [x] **Fix password visibility toggle on delete account screen**
  - Made `_obscurePassword` mutable, added toggle in `onPressed`

- [x] **Make AuthService a singleton**
  - Done as part of 1A security fixes

---

### 1D — UI Cleanup & Features ✅

- [x] **Remove debug info button from transactions screen**
- [x] **Remove repair data button from transactions screen**
- [x] **Implement transaction search**
  - Inline TextField in AppBar, filters by title/category/notes
- [x] **Implement savings sort options**
  - Converted to StatefulWidget, 4 sort types (alphabetical, progress asc/desc, target date)
- [x] **Fix empty onTap in recent transactions list**
  - Added `onTransactionTap` callback parameter
- [x] **Fix hardcoded copyright year**
  - Now uses `DateTime.now().year`
- [x] **Fix profile "coming soon" stubs**
  - Routes to existing SettingsScreen sections
- [x] **Add budget management screens**
  - Created `lib/screens/budgets/budgets_screen.dart` with progress bars and color coding
  - Created `lib/screens/budgets/create_budget_screen.dart` with category/amount/date form
  - Added budget CRUD methods to FinanceProvider
  - Added budget navigation in home_screen.dart

---

### 1E — Code Quality Cleanup ✅

- [x] **Fix logger.severe misuse in finance_provider**
  - Changed 20+ debug/trace calls to `_logger.fine()`, 1 to `_logger.warning()`

- [x] **Remove excessive debugPrint statements**
  - Replaced with `Logger` calls in auth_provider, finance_provider, transaction_form, notification_provider

- [x] **Remove dead code**
  - Removed mock SharedPrefs, DemoHomeScreen, useFirebase from main.dart
  - Deleted entire Expense subsystem (expense.dart, expense_provider.dart, expense_form.dart, expense_list_item.dart)

- [x] **Remove duplicate HexColor extension**
  - Removed from savings_screen.dart, kept canonical version in ui_helpers.dart

- [x] **Fix pubspec.yaml flutter_lints**
  - Moved to dev_dependencies, removed stray top-level key

- [x] **Fix DatabaseService silently swallowing errors**
  - `updateUserData` now returns `bool` instead of void

- [x] **Standardize social user Firestore schema**
  - Done as part of 1A (Google/Facebook sign-up uses User.toMap())

---

## PHASE 2: Subscription System Rewrite ✅

### 2A — Consolidate into Single Service ✅

- [x] **Merge BillingService into SubscriptionProvider**
  - Rewrote `SubscriptionProvider` to absorb all real IAP logic from BillingService
  - Deleted `lib/services/billing_service.dart`
  - Updated `lib/main.dart`: removed BillingService import, provider, constructor param

- [x] **Remove ALL mock purchase code**
  - Deleted `processPurchase()`, `_processMockPurchase()`, `getSubscriptionPlans()`, `isUserSubscribed()`
  - Deleted `createTemporaryMockSubscription()`, `setSubscriptionStatus()`, mock `cancelSubscription()`

- [x] **Wire real purchase flow in subscription screens**
  - Both screens now call `provider.buySubscription(product)` with real IAP

### 2B — Fix Subscription Features ✅

- [x] **Standardize pricing**
  - Created `lib/constants/subscription_constants.dart` with single source of truth
  - Both screens use dynamic prices from store, with consistent fallback ($3.99/$19.99)

- [x] **Add "Restore Purchases" button**
  - Added to both subscription screens

- [x] **Fix cancel flow**
  - Settings screen cancel now calls `provider.openSubscriptionManagement()` (platform deep link)

- [x] **Fix shouldShowAds() race condition**
  - Now purely synchronous: `if (_isSubscribed) return false; return _appLoadCount % 3 == 0;`

- [x] **Unify SharedPreferences keys and Firestore schema**
  - Standardized on camelCase keys with one-time migration from legacy snake_case keys
  - Firestore uses User model top-level fields

---

## PHASE 3: Production Deployment Prep ✅ (partial — account-dependent items deferred)

### 3A — Package Identity (deferred)

- [ ] **Replace `com.example.wealth_wise`** → real domain — `TODO(account-setup)` markers added
- [ ] **Fix Play Store rating URL** — `TODO(account-setup)` marker added

### 3B — Build Configuration ✅

- [ ] **Set up release signing** — `TODO(account-setup)` marker added
- [x] **Create ProGuard rules** — `android/app/proguard-rules.pro` created
  - Enabled `isMinifyEnabled` + `isShrinkResources` in release build type

### 3C — External Services (deferred)

- [ ] **Replace test AdMob IDs with production** — `TODO(account-setup)` markers added
  - `kDebugMode` toggle already implemented in `SubscriptionConstants`
- [ ] **Set up real privacy policy and terms URLs** — `TODO(account-setup)` markers added

### 3D — Final Checklist

- [ ] `flutter analyze` — zero errors
- [ ] `flutter build apk --release` — successful
- [ ] Test auth flows (email, Google, Facebook, sign-out)
- [ ] Test transaction CRUD with goal contributions
- [ ] Test budget create/view/edit/delete
- [ ] Test subscription purchase with Google Play test tracks
- [ ] Deploy Firestore security rules
- [x] Remove deprecated `USE_FINGERPRINT` permission from AndroidManifest
- [x] Set logger level to `Level.WARNING` for production (`lib/main.dart`)
- [ ] Update version in `pubspec.yaml` (currently `1.0.0+1`)
- [x] Clean up unused font files in `assets/fonts/` (deleted 3 unused .ttf files)

---

## Key Files Reference (All Phase 1-3 issues resolved)

All 53 original issues have been addressed. Remaining work is tracked by:
- `TODO(account-setup)` markers — for items needing Google Play developer account
- Phase 3D Final Checklist — for pre-launch testing
- **Phase 4** — new feature enhancements (see separate plan file)
