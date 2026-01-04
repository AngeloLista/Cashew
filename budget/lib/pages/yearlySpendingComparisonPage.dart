import 'dart:async';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addCategoryPage.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/categoryIcon.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/widgets/noResults.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/selectCategory.dart';
import 'package:budget/widgets/slidingSelectorIncomeExpense.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/transactionEntry/transactionEntry.dart';
import 'package:budget/widgets/viewAllTransactionsButton.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class YearlySpendingComparisonPage extends StatefulWidget {
  const YearlySpendingComparisonPage({super.key});

  @override
  State<YearlySpendingComparisonPage> createState() =>
      _YearlySpendingComparisonPageState();
}

class _YearlySpendingComparisonPageState
    extends State<YearlySpendingComparisonPage> {
  late int yearX;
  late int yearY;
  int selectedIncomeExpense = 1; // 1=expense, 2=income
  List<String>? selectedWalletPks;
  List<String> excludedCategoryFks = [
    "0"
  ]; // Exclude balance correction by default
  bool useMonthlyAverage = false;
  int sortMode = 0; // 0=total, 1=biggest decrease, 2=biggest increase
  TransactionCategory? selectedParentCategory; // For subcategory drill-down
  TransactionCategory?
      selectedCategoryForTransactions; // When viewing transactions
  bool viewingDirectParentTransactions =
      false; // When viewing direct parent transactions

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Load persisted years or default
    yearX = appStateSettings["yearlyComparisonYearX"]?.toInt() ?? now.year - 1;
    yearY = appStateSettings["yearlyComparisonYearY"]?.toInt() ?? now.year;
    // Load persisted wallets
    if (appStateSettings["yearlyComparisonWallets"] != null) {
      selectedWalletPks =
          List<String>.from(appStateSettings["yearlyComparisonWallets"]);
    }
  }

  DateTime getYearStart(int year) => DateTime(year, 1, 1);
  DateTime getYearEnd(int year) => DateTime(year, 12, 31, 23, 59, 59);

  bool? get isIncome {
    if (selectedIncomeExpense == 1) return false; // expense
    return true; // income
  }

  void openExcludeCategoriesSheet() {
    openBottomSheet(
      context,
      PopupFramework(
        title: "exclude-categories".tr(),
        child: Column(
          children: [
            SelectCategory(
              labelIcon: true,
              addButton: false,
              selectedCategories: excludedCategoryFks,
              setSelectedCategories: (List<String>? categories) {
                setState(() {
                  excludedCategoryFks = categories ?? [];
                });
              },
              scaleWhenSelected: false,
              allowRearrange: false,
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Button(
                    expandedLayout: true,
                    label: "reset".tr(),
                    onTap: () {
                      setState(() {
                        excludedCategoryFks = ["0"];
                      });
                      popRoute(context);
                    },
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    textColor:
                        Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                SizedBox(width: 13),
                Expanded(
                  child: Button(
                    expandedLayout: true,
                    label: "done".tr(),
                    onTap: () {
                      popRoute(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void openWalletFilterSheet() {
    openBottomSheet(
      context,
      PopupFramework(
        title: "select-accounts".tr(),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return StreamBuilder<List<TransactionWallet>>(
              stream: database.watchAllWallets(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return SizedBox.shrink();
                List<TransactionWallet> wallets = snapshot.data!;
                return Column(
                  children: [
                    ...wallets.map((wallet) {
                      bool isSelected = selectedWalletPks == null ||
                          selectedWalletPks!.contains(wallet.walletPk);
                      return Tappable(
                        onTap: () {
                          setModalState(() {
                            setState(() {
                              if (selectedWalletPks == null) {
                                // First selection - switch from "all" to specific
                                // Logic: If "All" are selected (null), and user clicks one (e.g., Y),
                                // it means they want to toggle Y OFF.
                                // So we select ONLY the others (All - Y).
                                selectedWalletPks = wallets
                                    .map((w) => w.walletPk)
                                    .where((pk) => pk != wallet.walletPk)
                                    .toList();
                              } else if (selectedWalletPks!
                                  .contains(wallet.walletPk)) {
                                selectedWalletPks!.remove(wallet.walletPk);
                                if (selectedWalletPks!.isEmpty) {
                                  selectedWalletPks = null; // Back to all
                                }
                              } else {
                                selectedWalletPks!.add(wallet.walletPk);
                              }
                            });
                            updateSettings(
                                "yearlyComparisonWallets", selectedWalletPks,
                                updateGlobalState: false);
                          });
                        },
                        borderRadius: 10,
                        color: isSelected
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : Colors.transparent,
                        child: Padding(
                          padding: EdgeInsetsDirectional.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.secondary,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: TextFont(
                                  text: wallet.name,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    SizedBox(height: 15),
                    Button(
                      expandedLayout: true,
                      label: "all-accounts".tr(),
                      onTap: () {
                        setState(() {
                          selectedWalletPks = null;
                        });
                        updateSettings(
                            "yearlyComparisonWallets", selectedWalletPks,
                            updateGlobalState: false);
                        popRoute(context);
                      },
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      textColor:
                          Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> selectYear(bool isYearX) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(isYearX ? yearX : yearY),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: "select-year".tr(),
    );
    if (picked != null) {
      setState(() {
        if (isYearX) {
          yearX = picked.year;
          updateSettings("yearlyComparisonYearX", yearX,
              updateGlobalState: false);
        } else {
          yearY = picked.year;
          updateSettings("yearlyComparisonYearY", yearY,
              updateGlobalState: false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);

    return PageFramework(
      title: "yearly-spending-comparison".tr(),
      dragDownToDismiss: true,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: 13),
            child: Column(
              children: [
                // Year selectors
                Row(
                  children: [
                    Expanded(
                      child: _YearSelector(
                        year: yearX,
                        onTap: () => selectYear(true),
                        label: "Year X",
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.compare_arrows_rounded,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    Expanded(
                      child: _YearSelector(
                        year: yearY,
                        onTap: () => selectYear(false),
                        label: "Year Y",
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
              ],
            ),
          ),
        ),
        // Income/Expense toggle
        SliverToBoxAdapter(
          child: SlidingSelectorIncomeExpense(
            options: ["expense", "income"],
            onSelected: (int selected) {
              setState(() {
                selectedIncomeExpense = selected;
              });
            },
            initialIndex: 0, // default to expense
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding:
                EdgeInsetsDirectional.symmetric(horizontal: 13, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Tappable(
                    onTap: openWalletFilterSheet,
                    borderRadius: 10,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            appStateSettings["outlinedIcons"]
                                ? Icons.account_balance_wallet_outlined
                                : Icons.account_balance_wallet_rounded,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: TextFont(
                              text: selectedWalletPks == null
                                  ? "all-accounts".tr()
                                  : "${selectedWalletPks!.length} " +
                                      "accounts".tr().toLowerCase(),
                              fontSize: 14,
                            ),
                          ),
                          Icon(Icons.arrow_drop_down_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Tappable(
                  onTap: openExcludeCategoriesSheet,
                  borderRadius: 10,
                  color: excludedCategoryFks.isNotEmpty
                      ? Theme.of(context).colorScheme.tertiaryContainer
                      : Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: EdgeInsetsDirectional.all(10),
                    child: Icon(
                      appStateSettings["outlinedIcons"]
                          ? Icons.filter_alt_outlined
                          : Icons.filter_alt_rounded,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Total vs Monthly Average toggle + Sort selector
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: 13),
            child: Row(
              children: [
                // Total / Monthly Average toggle
                Expanded(
                  child: Row(
                    children: [
                      _ToggleChip(
                        label: "total".tr(),
                        isSelected: !useMonthlyAverage,
                        onTap: () => setState(() => useMonthlyAverage = false),
                      ),
                      SizedBox(width: 8),
                      _ToggleChip(
                        label: "monthly-average".tr(),
                        isSelected: useMonthlyAverage,
                        onTap: () => setState(() => useMonthlyAverage = true),
                      ),
                    ],
                  ),
                ),
                // Sort selector
                PopupMenuButton<int>(
                  initialValue: sortMode,
                  onSelected: (value) => setState(() => sortMode = value),
                  tooltip: "sort".tr(),
                  icon: Icon(
                    appStateSettings["outlinedIcons"]
                        ? Icons.sort_outlined
                        : Icons.sort_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 0,
                      child: Row(
                        children: [
                          Icon(Icons.functions_rounded, size: 18),
                          SizedBox(width: 8),
                          Text("total".tr()),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 1,
                      child: Row(
                        children: [
                          Icon(Icons.trending_down_rounded,
                              size: 18, color: Colors.green),
                          SizedBox(width: 8),
                          Text("biggest-decrease".tr()),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 2,
                      child: Row(
                        children: [
                          Icon(Icons.trending_up_rounded,
                              size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text("biggest-increase".tr()),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 10)),
        // Comparison content
        SliverToBoxAdapter(
          child: _ComparisonContent(
            yearX: yearX,
            yearY: yearY,
            allWallets: allWallets,
            isIncome: isIncome,
            walletPks: selectedWalletPks,
            excludedCategoryFks: excludedCategoryFks,
            useMonthlyAverage: useMonthlyAverage,
            sortMode: sortMode,
            selectedParentCategory: selectedParentCategory,
            selectedCategoryForTransactions: selectedCategoryForTransactions,
            viewingDirectParentTransactions: viewingDirectParentTransactions,
            onCategorySelected: (category) {
              setState(() => selectedParentCategory = category);
            },
            onBackToMainCategories: () {
              setState(() {
                selectedParentCategory = null;
                selectedCategoryForTransactions = null;
                viewingDirectParentTransactions = false;
              });
            },
            onViewTransactions: (category) {
              setState(() => selectedCategoryForTransactions = category);
            },
            onBackFromTransactions: () {
              setState(() {
                selectedCategoryForTransactions = null;
                viewingDirectParentTransactions = false;
              });
            },
            onViewDirectParentTransactions: () {
              setState(() => viewingDirectParentTransactions = true);
            },
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 50)),
      ],
    );
  }
}

class _YearSelector extends StatelessWidget {
  const _YearSelector({
    required this.year,
    required this.onTap,
    required this.label,
  });

  final int year;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      borderRadius: 15,
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextFont(
              text: year.toString(),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            SizedBox(width: 8),
            Icon(Icons.calendar_month_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      borderRadius: 20,
      color: isSelected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 8),
        child: TextFont(
          text: label,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          textColor: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _ComparisonContent extends StatelessWidget {
  const _ComparisonContent({
    required this.yearX,
    required this.yearY,
    required this.allWallets,
    required this.isIncome,
    required this.walletPks,
    required this.excludedCategoryFks,
    required this.useMonthlyAverage,
    required this.sortMode,
    required this.selectedParentCategory,
    required this.selectedCategoryForTransactions,
    required this.viewingDirectParentTransactions,
    required this.onCategorySelected,
    required this.onBackToMainCategories,
    required this.onViewTransactions,
    required this.onBackFromTransactions,
    required this.onViewDirectParentTransactions,
  });

  final int yearX;
  final int yearY;
  final AllWallets allWallets;
  final bool? isIncome;
  final List<String>? walletPks;
  final List<String> excludedCategoryFks;
  final bool useMonthlyAverage;
  final int sortMode; // 0=total, 1=biggest decrease, 2=biggest increase
  final TransactionCategory? selectedParentCategory;
  final TransactionCategory? selectedCategoryForTransactions;
  final bool viewingDirectParentTransactions;
  final Function(TransactionCategory) onCategorySelected;
  final VoidCallback onBackToMainCategories;
  final Function(TransactionCategory) onViewTransactions;
  final VoidCallback onBackFromTransactions;
  final VoidCallback onViewDirectParentTransactions;

  DateTime getYearStart(int year) => DateTime(year, 1, 1);
  DateTime getYearEnd(int year) => DateTime(year, 12, 31, 23, 59, 59);

  // Helper to count months with transactions for a year using lightweight queries
  Future<int> _countMonthsWithTransactions(int year) async {
    int count = 0;
    for (int month = 1; month <= 12; month++) {
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);
      final transactions = await database
          .watchAllTransactions(
            startDate: monthStart,
            endDate: monthEnd,
            limit: 1,
          )
          .first;
      if (transactions.isNotEmpty) count++;
    }
    return count == 0 ? 1 : count; // Avoid division by zero
  }

  @override
  Widget build(BuildContext context) {
    // Get months with transactions using FutureBuilder (efficient: 12 lightweight queries)
    return FutureBuilder<List<int>>(
      future: Future.wait([
        _countMonthsWithTransactions(yearX),
        _countMonthsWithTransactions(yearY),
      ]),
      builder: (context, monthsSnapshot) {
        final monthsX = monthsSnapshot.hasData ? monthsSnapshot.data![0] : 12;
        final monthsY = monthsSnapshot.hasData ? monthsSnapshot.data![1] : 12;

        return StreamBuilder<List<CategoryWithTotal>>(
          stream:
              database.watchTotalSpentInEachCategoryInTimeRangeFromCategories(
            allWallets: allWallets,
            start: getYearStart(yearX),
            end: getYearEnd(yearX),
            categoryFks: null,
            categoryFksExclude:
                excludedCategoryFks.isEmpty ? null : excludedCategoryFks,
            budgetTransactionFilters: null,
            memberTransactionFilters: null,
            walletPks: walletPks,
            isIncome: isIncome,
            includeAllSubCategories: true,
            countUnassignedTransactions: true,
          ),
          builder: (context, snapshotX) {
            return StreamBuilder<List<CategoryWithTotal>>(
              stream: database
                  .watchTotalSpentInEachCategoryInTimeRangeFromCategories(
                allWallets: allWallets,
                start: getYearStart(yearY),
                end: getYearEnd(yearY),
                categoryFks: null,
                categoryFksExclude:
                    excludedCategoryFks.isEmpty ? null : excludedCategoryFks,
                budgetTransactionFilters: null,
                memberTransactionFilters: null,
                walletPks: walletPks,
                isIncome: isIncome,
                includeAllSubCategories: true,
                countUnassignedTransactions: true,
              ),
              builder: (context, snapshotY) {
                if (!snapshotX.hasData || !snapshotY.hasData) {
                  return Padding(
                    padding: EdgeInsetsDirectional.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                List<CategoryWithTotal> dataX = snapshotX.data!;
                List<CategoryWithTotal> dataY = snapshotY.data!;

                // Filter categories based on selected parent
                bool isViewingSubcategories = selectedParentCategory != null;

                // Filter data: either parent categories only OR subcategories of selected parent
                List<CategoryWithTotal> filteredDataX;
                List<CategoryWithTotal> filteredDataY;

                if (isViewingSubcategories) {
                  // Show subcategories of selected parent
                  filteredDataX = dataX
                      .where((c) =>
                          c.category.mainCategoryPk ==
                          selectedParentCategory!.categoryPk)
                      .toList();
                  filteredDataY = dataY
                      .where((c) =>
                          c.category.mainCategoryPk ==
                          selectedParentCategory!.categoryPk)
                      .toList();
                } else {
                  // Show only parent categories (mainCategoryPk is null)
                  filteredDataX = dataX
                      .where((c) => c.category.mainCategoryPk == null)
                      .toList();
                  filteredDataY = dataY
                      .where((c) => c.category.mainCategoryPk == null)
                      .toList();
                }

                // Calculate totals (use selected parent's data if viewing subcategories)
                double totalX, totalY;
                if (isViewingSubcategories) {
                  // Get parent category total from original data
                  var parentDataX = dataX
                      .where((c) =>
                          c.category.categoryPk ==
                          selectedParentCategory!.categoryPk)
                      .toList();
                  var parentDataY = dataY
                      .where((c) =>
                          c.category.categoryPk ==
                          selectedParentCategory!.categoryPk)
                      .toList();
                  totalX = parentDataX.isNotEmpty
                      ? parentDataX.first.total.abs()
                      : 0.0;
                  totalY = parentDataY.isNotEmpty
                      ? parentDataY.first.total.abs()
                      : 0.0;
                } else {
                  totalX =
                      filteredDataX.fold(0.0, (sum, c) => sum + c.total.abs());
                  totalY =
                      filteredDataY.fold(0.0, (sum, c) => sum + c.total.abs());
                }

                // Calculate subcategory totals if viewing a subcategory's transactions
                double subcategoryTotalX = 0.0;
                double subcategoryTotalY = 0.0;
                bool isViewingSubcategoryTransactions =
                    selectedCategoryForTransactions != null &&
                        selectedCategoryForTransactions!.mainCategoryPk != null;

                if (isViewingSubcategoryTransactions) {
                  var subcatDataX = dataX
                      .where((c) =>
                          c.category.categoryPk ==
                          selectedCategoryForTransactions!.categoryPk)
                      .toList();
                  var subcatDataY = dataY
                      .where((c) =>
                          c.category.categoryPk ==
                          selectedCategoryForTransactions!.categoryPk)
                      .toList();
                  subcategoryTotalX = subcatDataX.isNotEmpty
                      ? subcatDataX.first.total.abs()
                      : 0.0;
                  subcategoryTotalY = subcatDataY.isNotEmpty
                      ? subcatDataY.first.total.abs()
                      : 0.0;
                }

                // Apply monthly average if enabled
                // Use subcategory totals if viewing subcategory transactions
                double displayTotalX = isViewingSubcategoryTransactions
                    ? (useMonthlyAverage
                        ? subcategoryTotalX / monthsX
                        : subcategoryTotalX)
                    : (useMonthlyAverage ? totalX / monthsX : totalX);
                double displayTotalY = isViewingSubcategoryTransactions
                    ? (useMonthlyAverage
                        ? subcategoryTotalY / monthsY
                        : subcategoryTotalY)
                    : (useMonthlyAverage ? totalY / monthsY : totalY);

                // Merge categories from both years
                Map<String, _ComparisonData> categoryComparisons = {};

                for (var cat in filteredDataX) {
                  double amount = cat.total.abs();
                  categoryComparisons[cat.category.categoryPk] =
                      _ComparisonData(
                    category: cat.category,
                    amountX: useMonthlyAverage ? amount / monthsX : amount,
                    amountY: 0,
                  );
                }

                for (var cat in filteredDataY) {
                  double amount = cat.total.abs();
                  double displayAmount =
                      useMonthlyAverage ? amount / monthsY : amount;
                  if (categoryComparisons
                      .containsKey(cat.category.categoryPk)) {
                    categoryComparisons[cat.category.categoryPk]!.amountY =
                        displayAmount;
                  } else {
                    categoryComparisons[cat.category.categoryPk] =
                        _ComparisonData(
                      category: cat.category,
                      amountX: 0,
                      amountY: displayAmount,
                    );
                  }
                }

                if (categoryComparisons.isEmpty && !isViewingSubcategories) {
                  return Padding(
                    padding: EdgeInsetsDirectional.all(20),
                    child: NoResults(message: "no-data-for-year".tr()),
                  );
                }

                // Sort based on sortMode
                var sortedCategories = categoryComparisons.values.toList();
                switch (sortMode) {
                  case 0: // Total (sum of both years)
                    sortedCategories.sort((a, b) => (b.amountX + b.amountY)
                        .compareTo(a.amountX + a.amountY));
                    break;
                  case 1: // Biggest decrease (most negative change)
                    sortedCategories.sort((a, b) {
                      double diffA = a.amountY - a.amountX;
                      double diffB = b.amountY - b.amountX;
                      return diffA.compareTo(diffB); // Most negative first
                    });
                    break;
                  case 2: // Biggest increase (most positive change)
                    sortedCategories.sort((a, b) {
                      double diffA = a.amountY - a.amountX;
                      double diffB = b.amountY - b.amountX;
                      return diffB.compareTo(diffA); // Most positive first
                    });
                    break;
                }

                return Padding(
                  padding: EdgeInsetsDirectional.symmetric(horizontal: 13),
                  child: Column(
                    children: [
                      // Breadcrumb navigation when viewing subcategories or transactions
                      if (isViewingSubcategories)
                        Padding(
                          padding: EdgeInsetsDirectional.only(bottom: 10),
                          child: Tappable(
                            onTap: onBackToMainCategories,
                            borderRadius: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            child: Padding(
                              padding: EdgeInsetsDirectional.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_back_rounded,
                                    size: 20,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: TextFont(
                                      text: "all-categories".tr(),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      textColor: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Summary card with stacked parent tab when viewing subcategory transactions
                      if (isViewingSubcategoryTransactions ||
                          viewingDirectParentTransactions)
                        // Stacked cards: parent tab behind, subcategory card in front
                        Stack(
                          children: [
                            // Parent category card (background) - tappable to go back
                            // This extends behind the child card
                            Tappable(
                              onTap: onBackFromTransactions,
                              borderRadius: 15,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.15),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsetsDirectional.only(
                                  start: 16,
                                  end: 16,
                                  top: 12,
                                  bottom:
                                      60, // Extend below to peek behind child card
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextFont(
                                      text: selectedParentCategory!.name,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      textColor: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    Icon(
                                      Icons.keyboard_return_rounded,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withOpacity(0.7),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Subcategory summary card (foreground) - overlaps parent
                            Padding(
                              padding: EdgeInsetsDirectional.only(top: 38),
                              child: _SummaryCard(
                                title: viewingDirectParentTransactions
                                    ? "transactions-without-subcategory".tr()
                                    : selectedCategoryForTransactions!.name,
                                amountX: displayTotalX,
                                amountY: displayTotalY,
                                yearX: yearX,
                                yearY: yearY,
                                isIncomeMode: isIncome == true,
                                monthsX: useMonthlyAverage ? monthsX : null,
                                monthsY: useMonthlyAverage ? monthsY : null,
                              ),
                            ),
                          ],
                        )
                      else
                        // Regular summary card (no stacking)
                        _SummaryCard(
                          title: isViewingSubcategories
                              ? selectedParentCategory!.name
                              : (useMonthlyAverage
                                  ? "monthly-average".tr()
                                  : "total".tr()),
                          amountX: displayTotalX,
                          amountY: displayTotalY,
                          yearX: yearX,
                          yearY: yearY,
                          isIncomeMode: isIncome == true,
                          monthsX: useMonthlyAverage ? monthsX : null,
                          monthsY: useMonthlyAverage ? monthsY : null,
                        ),
                      SizedBox(height: 15),
                      // Show transactions when viewing a specific category
                      if (selectedCategoryForTransactions != null)
                        _CategoryTransactionsList(
                          categoryPk:
                              selectedCategoryForTransactions!.categoryPk,
                          yearX: yearX,
                          yearY: yearY,
                          walletPks: walletPks,
                          isIncome: isIncome,
                          onBack: onBackFromTransactions,
                          isSubcategory:
                              selectedCategoryForTransactions!.mainCategoryPk !=
                                  null,
                          parentCategoryPk:
                              selectedCategoryForTransactions!.mainCategoryPk,
                        ),
                      // Show transactions for parent category without subcategories
                      if (isViewingSubcategories &&
                          sortedCategories.isEmpty &&
                          selectedCategoryForTransactions == null &&
                          !viewingDirectParentTransactions)
                        _CategoryTransactionsList(
                          categoryPk: selectedParentCategory!.categoryPk,
                          yearX: yearX,
                          yearY: yearY,
                          walletPks: walletPks,
                          isIncome: isIncome,
                          onBack: onBackToMainCategories,
                          isSubcategory: false,
                          parentCategoryPk: null,
                        ),
                      // Category/subcategory list (only if not viewing transactions)
                      if (selectedCategoryForTransactions == null &&
                          !viewingDirectParentTransactions)
                        ...sortedCategories
                            .map((data) => _CategoryComparisonRow(
                                  category: data.category,
                                  amountX: data.amountX,
                                  amountY: data.amountY,
                                  yearX: yearX,
                                  yearY: yearY,
                                  isIncomeMode: isIncome == true,
                                  // Parent categories: drill into subcategories
                                  // Subcategories: show transactions
                                  onTap: isViewingSubcategories
                                      ? () => onViewTransactions(data.category)
                                      : () => onCategorySelected(data.category),
                                ))
                            .toList(),
                      // Direct parent transactions chip (show when viewing subcategories, not viewing other transactions)
                      if (isViewingSubcategories &&
                          sortedCategories.isNotEmpty &&
                          selectedCategoryForTransactions == null &&
                          !viewingDirectParentTransactions)
                        _DirectParentTransactionsChip(
                          parentCategoryPk: selectedParentCategory!.categoryPk,
                          yearX: yearX,
                          yearY: yearY,
                          walletPks: walletPks,
                          isIncome: isIncome,
                          onTap: onViewDirectParentTransactions,
                        ),
                      // Show direct parent transactions when selected
                      if (viewingDirectParentTransactions &&
                          isViewingSubcategories)
                        _CategoryTransactionsList(
                          categoryPk: selectedParentCategory!.categoryPk,
                          yearX: yearX,
                          yearY: yearY,
                          walletPks: walletPks,
                          isIncome: isIncome,
                          onBack: onBackFromTransactions,
                          isSubcategory: false,
                          parentCategoryPk: null,
                          filterDirectParentOnly: true,
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ComparisonData {
  final TransactionCategory category;
  double amountX;
  double amountY;

  _ComparisonData({
    required this.category,
    required this.amountX,
    required this.amountY,
  });
}

// Widget to show a chip when there are transactions directly on the parent category
class _DirectParentTransactionsChip extends StatelessWidget {
  const _DirectParentTransactionsChip({
    required this.parentCategoryPk,
    required this.yearX,
    required this.yearY,
    required this.walletPks,
    required this.isIncome,
    required this.onTap,
  });

  final String parentCategoryPk;
  final int yearX;
  final int yearY;
  final List<String>? walletPks;
  final bool? isIncome;
  final VoidCallback onTap;

  DateTime getYearStart(int year) => DateTime(year, 1, 1);
  DateTime getYearEnd(int year) => DateTime(year, 12, 31, 23, 59, 59);

  @override
  Widget build(BuildContext context) {
    // Query transactions for yearX
    return StreamBuilder<List<Transaction>>(
      stream: database.getTransactionsInTimeRangeFromCategories(
        getYearStart(yearX),
        getYearEnd(yearY), // Use full range from yearX to yearY
        [parentCategoryPk],
        null,
        true,
        isIncome,
        null,
        null,
        walletPks: walletPks,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }

        // Filter transactions without subcategory
        final directTransactions =
            snapshot.data!.where((t) => t.subCategoryFk == null).toList();

        if (directTransactions.isEmpty) {
          return SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsetsDirectional.only(top: 10),
          child: Tappable(
            onTap: onTap,
            borderRadius: 10,
            color: Theme.of(context)
                .colorScheme
                .tertiaryContainer
                .withOpacity(0.6),
            child: Padding(
              padding:
                  EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFont(
                      text: "${directTransactions.length} " +
                          "transactions-without-subcategory".tr(),
                      fontSize: 13,
                      textColor:
                          Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Widget to show transactions for a category in the comparison view
class _CategoryTransactionsList extends StatefulWidget {
  const _CategoryTransactionsList({
    required this.categoryPk,
    required this.yearX,
    required this.yearY,
    required this.walletPks,
    required this.isIncome,
    required this.onBack,
    this.isSubcategory = false,
    this.parentCategoryPk,
    this.filterDirectParentOnly =
        false, // Filter for transactions without subcategory
  });

  final String categoryPk;
  final int yearX;
  final int yearY;
  final List<String>? walletPks;
  final bool? isIncome;
  final VoidCallback onBack;
  final bool isSubcategory;
  final String? parentCategoryPk;
  final bool filterDirectParentOnly;

  @override
  State<_CategoryTransactionsList> createState() =>
      _CategoryTransactionsListState();
}

class _CategoryTransactionsListState extends State<_CategoryTransactionsList> {
  static const int initialLimit = 10;
  static const int loadMoreStep = 30;
  int visibleCount = initialLimit;
  late int selectedYear;
  bool sortByAmount = false; // false = by date, true = by amount

  @override
  void initState() {
    super.initState();
    // Default to yearY (more recent year)
    selectedYear = widget.yearY > widget.yearX ? widget.yearY : widget.yearX;
  }

  DateTime get startDate => DateTime(selectedYear, 1, 1);
  DateTime get endDate => DateTime(selectedYear, 12, 31, 23, 59, 59);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Year tabs with sort toggle
        Row(
          children: [
            Expanded(
              child: _ToggleChip(
                label: widget.yearX.toString(),
                isSelected: selectedYear == widget.yearX,
                onTap: () {
                  setState(() {
                    selectedYear = widget.yearX;
                    visibleCount = initialLimit;
                  });
                },
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _ToggleChip(
                label: widget.yearY.toString(),
                isSelected: selectedYear == widget.yearY,
                onTap: () {
                  setState(() {
                    selectedYear = widget.yearY;
                    visibleCount = initialLimit;
                  });
                },
              ),
            ),
            SizedBox(width: 8),
            // Sort toggle button
            Tappable(
              onTap: () {
                setState(() {
                  sortByAmount = !sortByAmount;
                });
              },
              borderRadius: 20,
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      sortByAmount
                          ? Icons.attach_money_rounded
                          : Icons.access_time_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    SizedBox(width: 4),
                    TextFont(
                      text: sortByAmount ? "amount".tr() : "date".tr(),
                      fontSize: 12,
                      textColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 15),
        // Transaction list for selected year
        // For subcategories: query by parent category, then filter by subCategoryFk
        // For parent categories: query directly by categoryFk
        StreamBuilder<List<Transaction>>(
          stream: database.getTransactionsInTimeRangeFromCategories(
            startDate,
            endDate,
            widget.isSubcategory && widget.parentCategoryPk != null
                ? [widget.parentCategoryPk!]
                : [widget.categoryPk], // categoryFks
            null, // categoryFksExclude
            true, // isPaidOnly
            widget.isIncome,
            null, // budgetTransactionFilters
            null, // memberTransactionFilters
            walletPks: widget.walletPks,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Padding(
                padding: EdgeInsetsDirectional.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            List<Transaction> transactions = snapshot.data!;

            // For subcategories, filter by subCategoryFk
            if (widget.isSubcategory) {
              transactions = transactions
                  .where((t) => t.subCategoryFk == widget.categoryPk)
                  .toList();
            }

            // For direct parent transactions, filter where subCategoryFk is null
            if (widget.filterDirectParentOnly) {
              transactions =
                  transactions.where((t) => t.subCategoryFk == null).toList();
            }

            // Sort by amount or date descending
            if (sortByAmount) {
              transactions
                  .sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
            } else {
              transactions
                  .sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
            }
            if (transactions.isEmpty) {
              return Padding(
                padding: EdgeInsetsDirectional.all(20),
                child: TextFont(
                  text: "no-transactions".tr(),
                  fontSize: 14,
                  textColor: Theme.of(context).colorScheme.secondary,
                  textAlign: TextAlign.center,
                ),
              );
            }

            // Limit visible transactions
            List<Transaction> visibleTransactions =
                transactions.take(visibleCount).toList();
            bool hasMore = transactions.length > visibleCount;

            return Column(
              children: [
                // Transaction list
                ...visibleTransactions.map((transaction) => TransactionEntry(
                      openPage: AddTransactionPage(
                        transaction: transaction,
                        routesToPopAfterDelete: RoutesToPopAfterDelete.One,
                      ),
                      transaction: transaction,
                      containerColor: Colors.transparent,
                      useHorizontalPaddingConstrained: false,
                      listID:
                          "comparison-transactions-${widget.categoryPk}-$selectedYear",
                    )),
                // Show more button
                if (hasMore)
                  Padding(
                    padding: EdgeInsetsDirectional.only(top: 10),
                    child: LowKeyButton(
                      onTap: () {
                        setState(() {
                          visibleCount += loadMoreStep;
                        });
                      },
                      text: "show-more".tr() +
                          " (${transactions.length - visibleCount} " +
                          "remaining".tr() +
                          ")",
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.amountX,
    required this.amountY,
    required this.yearX,
    required this.yearY,
    required this.isIncomeMode,
    this.monthsX,
    this.monthsY,
  });

  final String title;
  final double amountX;
  final double amountY;
  final int yearX;
  final int yearY;
  final bool isIncomeMode;
  final int? monthsX;
  final int? monthsY;

  @override
  Widget build(BuildContext context) {
    double percentChange = amountX == 0
        ? (amountY == 0 ? 0 : 100)
        : ((amountY - amountX) / amountX) * 100;
    bool isIncrease = percentChange > 0;
    bool isPositive = isIncomeMode ? isIncrease : !isIncrease;
    double difference = amountY - amountX;

    return Container(
      padding: EdgeInsetsDirectional.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFont(
            text: title,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            textColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Year X column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFont(
                      text: monthsX != null
                          ? "$yearX (${monthsX}m)"
                          : yearX.toString(),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      textColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                    SizedBox(height: 4),
                    TextFont(
                      text: convertToMoney(
                        Provider.of<AllWallets>(context),
                        amountX,
                      ),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ],
                ),
              ),
              // Arrow
              Padding(
                padding: EdgeInsetsDirectional.only(top: 20),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 24,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
              // Year Y column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextFont(
                      text: monthsY != null
                          ? "$yearY (${monthsY}m)"
                          : yearY.toString(),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      textColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                    SizedBox(height: 4),
                    TextFont(
                      text: convertToMoney(
                        Provider.of<AllWallets>(context),
                        amountY,
                      ),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Change indicators row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Difference chip
              Container(
                padding: EdgeInsetsDirectional.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextFont(
                  text: "${difference >= 0 ? '+' : ''}${convertToMoney(
                    Provider.of<AllWallets>(context),
                    difference,
                  )}",
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  textColor:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              SizedBox(width: 8),
              // Percentage chip
              Container(
                padding: EdgeInsetsDirectional.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: percentChange == 0
                      ? Theme.of(context).colorScheme.secondary.withOpacity(0.2)
                      : isPositive
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (percentChange != 0)
                      Icon(
                        isIncrease
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    SizedBox(width: percentChange != 0 ? 4 : 0),
                    TextFont(
                      text: "${percentChange.abs().toStringAsFixed(1)}%",
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      textColor: percentChange == 0
                          ? Theme.of(context).colorScheme.secondary
                          : isPositive
                              ? Colors.green
                              : Colors.red,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryComparisonRow extends StatelessWidget {
  const _CategoryComparisonRow({
    required this.category,
    required this.amountX,
    required this.amountY,
    required this.yearX,
    required this.yearY,
    required this.isIncomeMode,
    this.onTap,
  });

  final TransactionCategory category;
  final double amountX;
  final double amountY;
  final int yearX;
  final int yearY;
  final bool isIncomeMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    double percentChange = amountX == 0
        ? (amountY == 0 ? 0 : 100)
        : ((amountY - amountX) / amountX) * 100;
    bool isIncrease = percentChange > 0;
    // For income: increase = good (green), decrease = bad (red)
    // For expense: increase = bad (red), decrease = good (green)
    bool isPositive = isIncomeMode ? isIncrease : !isIncrease;

    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: 8),
      child: Tappable(
        onTap: onTap ??
            () {
              // Default: open category edit page
              pushRoute(
                context,
                AddCategoryPage(
                  category: category,
                  routesToPopAfterDelete: RoutesToPopAfterDelete.One,
                ),
              );
            },
        borderRadius: 12,
        color:
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
        child: Padding(
          padding: EdgeInsetsDirectional.all(12),
          child: Row(
            children: [
              CategoryIcon(
                categoryPk: category.categoryPk,
                category: category,
                size: 35,
                sizePadding: 25,
                borderRadius: 100,
                canEditByLongPress: false,
                margin: EdgeInsetsDirectional.zero,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFont(
                      text: category.name,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        TextFont(
                          text: convertToMoney(
                            Provider.of<AllWallets>(context),
                            amountX,
                          ),
                          fontSize: 13,
                          textColor: Theme.of(context).colorScheme.secondary,
                        ),
                        Padding(
                          padding:
                              EdgeInsetsDirectional.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        TextFont(
                          text: convertToMoney(
                            Provider.of<AllWallets>(context),
                            amountY,
                          ),
                          fontSize: 13,
                          textColor: Theme.of(context).colorScheme.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsetsDirectional.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: percentChange == 0
                          ? Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.15)
                          : isPositive
                              ? Colors.green.withOpacity(0.15)
                              : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (percentChange != 0)
                          Icon(
                            isIncrease
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 12,
                            color: isPositive ? Colors.green : Colors.red,
                          ),
                        TextFont(
                          text: "${percentChange.abs().toStringAsFixed(1)}%",
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          textColor: percentChange == 0
                              ? Theme.of(context).colorScheme.secondary
                              : isPositive
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsetsDirectional.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: TextFont(
                      text:
                          "${(amountY - amountX) >= 0 ? '+' : ''}${convertToMoney(
                        Provider.of<AllWallets>(context),
                        amountY - amountX,
                      )}",
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              // Show chevron for drillable categories
              if (onTap != null)
                Padding(
                  padding: EdgeInsetsDirectional.only(start: 8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
