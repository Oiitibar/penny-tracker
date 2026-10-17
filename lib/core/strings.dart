/// English v1 copy is kept here to provide a single localization entry point.
abstract final class S {
  static const appName = 'Student Penny Tracker';
  static const greeting = 'Hi, Crystal 👋';
  static const intro = 'Let’s see how your budget is looking this week.';
  static const home = 'Home', add = 'Add', insights = 'Insights';
  static const budgetLeft = 'Budget Left',
      editBudget = 'Edit budget',
      weeklyBudget = 'Weekly budget';
  static const spentWeek = 'Spent This Week',
      recent = 'Recent Expenses',
      viewAll = 'View All';
  static const addExpense = 'Add Expense',
      editExpense = 'Edit Expense',
      saveExpense = 'Save Expense',
      saveChanges = 'Save changes';
  static const amount = 'Amount',
      expenseName = 'Expense name',
      optional = 'Optional';
  static const nameHint = 'e.g. Campus Coffee',
      category = 'Category',
      customCategory = 'Custom Category',
      customHint = 'Enter category name…';
  static const date = 'Date',
      payment = 'Payment method',
      cash = 'Cash',
      card = 'Card';
  static const history = 'History & Insights',
      breakdown = 'Spending Breakdown',
      topSpending = 'Top Spending',
      allTransactions = 'All Transactions';
  static const noExpenses = 'No expenses yet',
      firstExpense = 'Add your first expense to get started.';
  static const saved = 'Expense saved successfully.',
      updated = 'Expense updated successfully.',
      deleted = 'Expense deleted.';
  static const saveFailed = 'Couldn’t save this expense. Please try again.';
  static const updateFailed = 'Couldn’t update this expense. Please try again.';
  static const deleteFailed = 'Couldn’t delete this expense. Please try again.';
  static const edit = 'Edit',
      delete = 'Delete',
      cancel = 'Cancel',
      close = 'Close',
      retry = 'Try again';
  static const details = 'Expense details',
      budgetSaved = 'Weekly budget updated.';
  static const budgetHelp =
      'Your allowance starts fresh every Monday. This amount applies to every week, with no rollover.';
  static const budgetFailed = 'Couldn’t update your budget. Please try again.';
  static const sampleTitle = 'A little head start',
      sampleText =
          'These are sample expenses. Edit or delete them to make this space yours.',
      dismissSamples = 'Dismiss sample expense notice';
  static const loadFailed = 'Your tracker couldn’t open',
      loadHelp = 'Your saved data has not been reset. Please try again.';
  static const localOnly = 'Just for you. Saved on your device.';
  static const addIntro = 'Little expenses. A clearer picture.';
  static const insightsIntro = 'A little awareness goes a long way.';
  static const noPeriod = 'A fresh page',
      noPeriodHelp =
          'No expenses in this period. Your next one will appear here.';
  static const zeroBreakdown = 'Nothing spent in this period yet.';
  static const dailyTitle = 'A little room to breathe';
  static const overBudgetTitle = 'Your weekly check-in';
  static String weeklyLimit(String amount) => 'of $amount weekly limit';
  static String overBudget(String amount) => 'Over budget by $amount';
  static String topText(String category, String period) =>
      'You spent most on $category $period.';
  static String percentPeriod(int percent) => '$percent% of period spending';
  static String deleteQuestion(String name) => 'Delete “$name”?';
  static const deleteHelp =
      'This expense will be permanently removed from your tracker.';
  static const remainingLabel = 'left', recordedTime = 'Recorded time';
  static const chooseDate = 'Choose date',
      saving = 'Saving…',
      deleting = 'Deleting…';
  static const periodTotal = 'Total spent in this period';
  static const precisionError = 'Use no more than two decimal places.';
  static const amountError = 'Enter a valid amount, such as 4.50.';
  static const rangeError = r'Enter $999,999.99 or less.';
  static const positiveError = r'Enter an amount greater than $0.00.';
  static const categoryError = 'Use a category name with 1–24 characters.';
  static const invalidDate = 'Choose a valid date.',
      futureDate = 'Choose today or an earlier date.';
  static const choosePayment = 'Choose Cash or Card.',
      chooseCategory = 'Choose a category.';
  static const nameTooLong = 'Use no more than 60 characters.';
  static const onTrack = 'On track',
      gettingLow = 'Getting low',
      budgetUsed = 'Budget used',
      over = 'Over budget';
  static String defaultExpense(String category) => '$category expense';
  static String balanceGuidance(String amount, int days) =>
      'You have $amount left for the next $days ${days == 1 ? 'day' : 'days'}.';
  static String overGuidance(String amount) =>
      'You’re over this week’s budget by $amount.';
  static String remainingDescription(int percent) =>
      '$percent% of weekly budget remaining';
}
