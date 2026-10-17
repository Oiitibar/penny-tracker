import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/finance.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../shared/widgets.dart';
import '../state/providers.dart';

class BudgetEditor extends ConsumerStatefulWidget {
  const BudgetEditor(this.cents, {super.key});
  final int cents;
  @override
  ConsumerState<BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<BudgetEditor> {
  late final TextEditingController _amount = TextEditingController(
    text: amountText(widget.cents),
  );
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(appStoreProvider.notifier).setBudget(_amount.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = S.budgetFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(S.weeklyBudget, style: heading(20)),
          const SizedBox(height: 12),
          const Text(S.budgetHelp, style: TextStyle(color: C.secondary)),
          const SizedBox(height: 24),
          TextFormField(
            key: const Key('budget-input'),
            controller: _amount,
            autofocus: true,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: S.amount,
              prefixText: r'$ ',
            ),
            validator: (value) {
              try {
                parseCents(value ?? '');
                return null;
              } on FormatException catch (e) {
                return e.message;
              }
            },
            onFieldSubmitted: (_) => _save(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: C.error)),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(S.saveChanges),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> editBudget(BuildContext context, int cents) async {
  final saved = await appSheet<bool>(context, BudgetEditor(cents));
  if (saved == true && context.mounted) feedback(context, S.budgetSaved);
}
