# Cashew

A budget and financial tracking Flutter application. Built with Flutter, Drift (SQL), and Firebase.

## Project Architecture

The Flutter app source code is located in `budget/lib/`. Here's the structure:

```
budget/lib/
├── main.dart              # App entry point
├── colors.dart            # Theme and color definitions
├── functions.dart         # Global utility functions
├── database/              # Drift SQL database
│   ├── tables.dart        # Table definitions and queries
│   └── schema_versions.dart # Migration logic
├── pages/                 # App screens (40+ files)
│   ├── homePage/          # Home page components
│   ├── addTransactionPage.dart
│   ├── budgetPage.dart
│   ├── settingsPage.dart
│   └── ...
├── widgets/               # Reusable UI components (90+ files)
│   ├── transactionEntry/  # Transaction display widgets
│   ├── navigationFramework.dart
│   ├── budgetContainer.dart
│   └── ...
└── struct/                # Configuration and helpers
    ├── settings.dart      # App settings management
    ├── defaultPreferences.dart
    ├── syncClient.dart    # Cloud sync logic
    └── ...
```

**Key files for common modifications:**
- **New screen** → Create in `pages/`, use `pushRoute(context, page)` for navigation
- **New UI component** → Create in `widgets/`
- **Database changes** → Modify `database/tables.dart`, follow migration steps below
- **Utility functions** → Add to `functions.dart` or create in `struct/`

## Changelog

Changes and progress about development is documented in GitHub [commits](https://github.com/jameskokoska/Cashew/commits/main) and in the [changelog](https://github.com/jameskokoska/Cashew/blob/main/budget/lib/widgets/showChangelog.dart).

## App Links

App links allow direct navigation and automation of actions using application URLs. Discussion: https://github.com/jameskokoska/Cashew/issues/127#issuecomment-1975096357

### Routes

| Routes for Android and iOS                  | Routes for Web App                             |
| ------------------------------------------- | ---------------------------------------------- |
| `https://cashewapp.web.app/[Endpoint here]` | `https://budget-track.web.app/[Endpoint here]` |

### Endpoints

| Endpoint               | Description                                                               |
| ---------------------- | ------------------------------------------------------------------------- |
| `/addTransaction`      | Add a new transaction without a UI prompt (unless a category is missing). |
| `/addTransactionRoute` | Open the add new transaction route with information filled in.            |

### Parameters

| Parameter     | Description                                                                | Required | Default         |
| ------------- | -------------------------------------------------------------------------- | -------- | --------------- |
| `amount`      | Transaction amount. Negative = expense, positive = income.                 | No       | 0               |
| `title`       | Transaction title. If associated title found, uses its category.          | No       | Empty string    |
| `notes`       | Notes for the transaction.                                                 | No       | Empty string    |
| `date`        | Transaction date. See `getCommonDateFormats()` in `commonDateFormats.dart` | No       | Current time    |
| `category`    | Category name (search, first match, case insensitive).                     | No       | Prompt user     |
| `subcategory` | Subcategory name (overwrites category if found).                           | No       | None            |
| `account`     | Account/wallet name (search, first match, case insensitive).               | No       | Primary account |
| `JSON`        | List of transaction objects keyed with `transactions`.                     | No       | None            |

App link parsing: [`lib/widgets/util/deepLinks.dart`](https://github.com/jameskokoska/Cashew/blob/main/budget/lib/widgets/util/deepLinks.dart)

## Bundled Packages

Modified versions of discontinued packages in `/budget/packages`:
- https://pub.dev/packages/implicitly_animated_reorderable_list
- https://pub.dev/packages/sliding_sheet

## Translations

Translations spreadsheet: https://docs.google.com/spreadsheets/d/1QQqt28cmrby6JqxLm-oxUXCuM3alniLJ6IRhcPJDOtk

To update: run `budget/assets/translations/generate-translations.py` and restart app.

## Developer Notes

### Build Commands

| Platform | Command                            | Notes           |
| -------- | ---------------------------------- | --------------- |
| Android  | `flutter build appbundle --release` | Requires SDK    |
| iOS      | `flutter build ipa`                 | Requires macOS  |
| Firebase | `firebase deploy`                   | Requires Firebase CLI |

### Scripts

| Script                        | Description                                    |
| ----------------------------- | ---------------------------------------------- |
| `deploy_and_build_windows.bat` | Deploy to Firebase, build apk and appbundle   |
| `open_release_builds.bat`      | Open built apk/appbundle location             |
| `update_translations.bat`      | Download and generate latest translations     |

### Wireless Android Development

```bash
adb tcpip 5555
adb connect <IP>  # Get IP from About Phone > Status Information > IP Address
```

### Database Migration

1. Modify schema in `tables.dart`
2. Bump `schemaVersionGlobal` in `tables.dart`
3. `cd budget/`
4. `dart run build_runner build`
5. `dart run drift_dev schema dump lib/database/tables.dart drift_schemas/drift_schema_v[VERSION].json`
6. `dart run drift_dev schema steps drift_schemas/ lib/database/schema_versions.dart`
7. Add migration strategy in `stepByStep(...)` function in `tables.dart`

### Important Conventions

| Topic | Details |
| ----- | ------- |
| Get Platform | Use `getPlatform()` from `functions.dart` (Platform not supported on web) |
| Navigation | Use `pushRoute(context, page)` from `functions.dart` |
| Wallets vs Accounts | `Wallet` used internally, `Account` in UI |
| Objectives vs Goals | `Objective` used internally, `Goal` in UI |

### Long Term Loans

Long term loans create a goal. The goal total is calculated by totalling transactions with opposite polarity. Example: loan of $100 lent out = initial $100 expense. Payments are made as income. Remaining = difference between expense and income totals.
