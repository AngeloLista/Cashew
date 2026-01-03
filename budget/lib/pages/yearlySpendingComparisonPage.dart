import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addCategoryPage.dart';
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    yearY = now.year;
    yearX = now.year - 1;
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
                                selectedWalletPks = [wallet.walletPk];
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
        } else {
          yearY = picked.year;
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
        // Comparison content
        SliverToBoxAdapter(
          child: _ComparisonContent(
            yearX: yearX,
            yearY: yearY,
            allWallets: allWallets,
            isIncome: isIncome,
            walletPks: selectedWalletPks,
            excludedCategoryFks: excludedCategoryFks,
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

class _ComparisonContent extends StatelessWidget {
  const _ComparisonContent({
    required this.yearX,
    required this.yearY,
    required this.allWallets,
    required this.isIncome,
    required this.walletPks,
    required this.excludedCategoryFks,
  });

  final int yearX;
  final int yearY;
  final AllWallets allWallets;
  final bool? isIncome;
  final List<String>? walletPks;
  final List<String> excludedCategoryFks;

  DateTime getYearStart(int year) => DateTime(year, 1, 1);
  DateTime getYearEnd(int year) => DateTime(year, 12, 31, 23, 59, 59);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CategoryWithTotal>>(
      stream: database.watchTotalSpentInEachCategoryInTimeRangeFromCategories(
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
          stream:
              database.watchTotalSpentInEachCategoryInTimeRangeFromCategories(
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

            // Calculate totals
            double totalX = dataX.fold(0.0, (sum, c) => sum + c.total.abs());
            double totalY = dataY.fold(0.0, (sum, c) => sum + c.total.abs());

            // Merge categories from both years
            Map<String, _ComparisonData> categoryComparisons = {};

            for (var cat in dataX) {
              categoryComparisons[cat.category.categoryPk] = _ComparisonData(
                category: cat.category,
                amountX: cat.total.abs(),
                amountY: 0,
              );
            }

            for (var cat in dataY) {
              if (categoryComparisons.containsKey(cat.category.categoryPk)) {
                categoryComparisons[cat.category.categoryPk]!.amountY =
                    cat.total.abs();
              } else {
                categoryComparisons[cat.category.categoryPk] = _ComparisonData(
                  category: cat.category,
                  amountX: 0,
                  amountY: cat.total.abs(),
                );
              }
            }

            if (categoryComparisons.isEmpty) {
              return Padding(
                padding: EdgeInsetsDirectional.all(20),
                child: NoResults(message: "no-data-for-year".tr()),
              );
            }

            // Sort by highest total (sum of both years)
            var sortedCategories = categoryComparisons.values.toList()
              ..sort((a, b) =>
                  (b.amountX + b.amountY).compareTo(a.amountX + a.amountY));

            return Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: 13),
              child: Column(
                children: [
                  // Total summary card
                  _SummaryCard(
                    title: "total".tr(),
                    amountX: totalX,
                    amountY: totalY,
                    yearX: yearX,
                    yearY: yearY,
                    isIncomeMode: isIncome == true,
                  ),
                  SizedBox(height: 15),
                  // Category list
                  ...sortedCategories
                      .map((data) => _CategoryComparisonRow(
                            category: data.category,
                            amountX: data.amountX,
                            amountY: data.amountY,
                            yearX: yearX,
                            yearY: yearY,
                            isIncomeMode: isIncome == true,
                          ))
                      .toList(),
                ],
              ),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.amountX,
    required this.amountY,
    required this.yearX,
    required this.yearY,
    required this.isIncomeMode,
  });

  final String title;
  final double amountX;
  final double amountY;
  final int yearX;
  final int yearY;
  final bool isIncomeMode;

  @override
  Widget build(BuildContext context) {
    double percentChange = amountX == 0
        ? (amountY == 0 ? 0 : 100)
        : ((amountY - amountX) / amountX) * 100;
    bool isIncrease = percentChange > 0;
    // For income: increase = good (green), decrease = bad (red)
    // For expense: increase = bad (red), decrease = good (green)
    bool isPositive = isIncomeMode ? isIncrease : !isIncrease;

    return Container(
      padding: EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFont(
            text: title,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFont(
                      text: yearX.toString(),
                      fontSize: 12,
                      textColor: Theme.of(context).colorScheme.secondary,
                    ),
                    TextFont(
                      text: convertToMoney(
                        Provider.of<AllWallets>(context),
                        amountX,
                      ),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextFont(
                      text: yearY.toString(),
                      fontSize: 12,
                      textColor: Theme.of(context).colorScheme.secondary,
                    ),
                    TextFont(
                      text: convertToMoney(
                        Provider.of<AllWallets>(context),
                        amountY,
                      ),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Container(
                padding: EdgeInsetsDirectional.symmetric(
                    horizontal: 10, vertical: 6),
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
                        size: 14,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    TextFont(
                      text: "${percentChange.abs().toStringAsFixed(1)}%",
                      fontSize: 13,
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
  });

  final TransactionCategory category;
  final double amountX;
  final double amountY;
  final int yearX;
  final int yearY;
  final bool isIncomeMode;

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
        onTap: () {
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
              Container(
                padding:
                    EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4),
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
            ],
          ),
        ),
      ),
    );
  }
}
