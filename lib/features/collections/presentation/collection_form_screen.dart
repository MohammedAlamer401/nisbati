import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatting/currency_formatter.dart';
import '../../../core/formatting/date_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../services/data/services_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../data/collections_repository.dart';
import '../domain/collection_models.dart';

class _FormData {
  const _FormData({required this.service, required this.available, this.collection});

  final ServiceListItem service;

  /// أقصى مبلغ لهذه الدفعة (المتبقي، مضافاً إليه مبلغ الدفعة قيد التعديل).
  final Money available;
  final CollectionEntry? collection;
}

/// تسجيل تحصيل أو تعديله (الشاشة 17).
class CollectionFormScreen extends ConsumerStatefulWidget {
  const CollectionFormScreen({super.key, required this.serviceId, this.collectionId});

  final int serviceId;
  final int? collectionId;

  @override
  ConsumerState<CollectionFormScreen> createState() => _CollectionFormScreenState();
}

class _CollectionFormScreenState extends ConsumerState<CollectionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  late final Future<_FormData> _data = _load();
  DateTime _date = DateFormatter.today();
  var _method = PaymentMethod.cash;
  var _loaded = false;
  var _dirty = false;
  var _saving = false;

  bool get _editing => widget.collectionId != null;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<_FormData> _load() async {
    final service = await ref.read(servicesRepositoryProvider).watchService(widget.serviceId).first;
    final collections = ref.read(collectionsRepositoryProvider);
    final collection = _editing ? await collections.get(widget.collectionId!) : null;
    final available = await collections.available(widget.serviceId, excludeCollectionId: widget.collectionId);
    return _FormData(service: service!, available: available, collection: collection);
  }

  void _fill(_FormData data) {
    if (_loaded) return;
    _loaded = true;
    final collection = data.collection;
    if (collection == null) {
      // اقتراح المتبقي كاملاً.
      _amount.text = CurrencyFormatter.number(data.available);
      return;
    }
    _amount.text = CurrencyFormatter.number(Money(collection.amountMinor));
    _date = DateFormatter.fromStorage(collection.collectionDate);
    _method = collection.paymentMethod;
    _reference.text = collection.reference ?? '';
  }

  Future<void> _pickDate(DateTime serviceDate) async {
    final today = DateFormatter.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(serviceDate) ? serviceDate : _date,
      // لا تسبق تاريخ الخدمة ولا تتجاوز اليوم (القسم 5.5).
      firstDate: serviceDate.isAfter(today) ? today : serviceDate,
      lastDate: today,
      helpText: 'تاريخ التحصيل',
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
        _dirty = true;
      });
    }
  }

  Future<void> _save(_FormData data) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final input = CollectionInput(
      serviceId: widget.serviceId,
      amount: Money.tryParse(_amount.text)!,
      date: _date,
      method: _method,
      reference: _reference.text,
    );
    final repo = ref.read(collectionsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_editing) {
        await repo.update(widget.collectionId!, input);
      } else {
        await repo.create(input);
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      messenger.showSnackBar(SnackBar(content: Text(_editing ? 'تم تعديل الدفعة' : 'تم تسجيل التحصيل')));
      context.pop();
    } on CollectionExceedsRemainingException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final symbol = ref.read(currencySymbolProvider);
      messenger.showSnackBar(SnackBar(
        content: Text('المبلغ أكبر من المتبقي (${CurrencyFormatter.format(e.available, symbol: symbol)})'),
      ));
    }
  }

  Future<void> _confirmLeave() async {
    if (await confirmDiscardChanges(context) && mounted) {
      setState(() => _dirty = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_editing ? 'تعديل الدفعة' : 'تسجيل تحصيل')),
        body: FutureBuilder(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('تعذّر تحميل الخدمة'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final data = snapshot.data!;
            _fill(data);
            return _form(data);
          },
        ),
      ),
    );
  }

  Widget _form(_FormData data) {
    final symbol = ref.watch(currencySymbolProvider);
    String money(Money m) => CurrencyFormatter.format(m, symbol: symbol);
    final service = data.service;
    final serviceDate = DateFormatter.fromStorage(service.service.serviceDate);
    final collectedBefore = service.collection.commission - data.available;

    return Form(
      key: _formKey,
      onChanged: () {
        if (!_dirty) setState(() => _dirty = true);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(service.service.title, style: AppTextStyles.cardTitle),
                    Text(service.clientName, style: AppTextStyles.caption),
                    const Divider(height: 20),
                    _InfoRow('المستحق الكلي', money(service.collection.commission)),
                    _InfoRow('المحصّل سابقاً', money(collectedBefore), color: AppColors.success),
                    _InfoRow('المتبقي قبل الدفعة', money(data.available), color: AppColors.warning),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            MoneyField(
              label: 'مبلغ الدفعة',
              controller: _amount,
              suffixText: symbol,
              validator: (v) {
                final amount = Money.tryParse(v ?? '');
                if (amount == null) return 'يرجى إدخال قيمة صحيحة';
                if (amount.isZero) return 'المبلغ يجب أن يكون أكبر من صفر';
                if (amount > data.available) return 'المبلغ أكبر من المتبقي (${money(data.available)})';
                return null;
              },
            ),
            if (!_editing && data.available.minor > 1)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => setState(() {
                    _amount.text = CurrencyFormatter.number(Money(data.available.minor ~/ 2));
                    _dirty = true;
                  }),
                  child: const Text('نصف المتبقي'),
                ),
              ),
            const SizedBox(height: 12),
            Text('تاريخ التحصيل', style: AppTextStyles.label),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _pickDate(serviceDate),
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_month_rounded)),
                child: Text(DateFormatter.short(_date), style: AppTextStyles.body),
              ),
            ),
            const SizedBox(height: 16),
            Text('طريقة التحصيل', style: AppTextStyles.label),
            const SizedBox(height: 6),
            SegmentedButton<PaymentMethod>(
              segments: [
                for (final method in PaymentMethod.values) ButtonSegment(value: method, label: Text(method.label)),
              ],
              selected: {_method},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _method = s.first;
                _dirty = true;
              }),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'ملاحظة أو رقم مرجع (اختياري)',
              controller: _reference,
              maxLength: 120,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : () => _save(data),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(_editing ? 'حفظ التعديل' : 'تسجيل التحصيل'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.color = AppColors.textPrimary});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.label.copyWith(color: AppColors.textSecondary))),
          Text(value, style: AppTextStyles.money(AppTextStyles.label.copyWith(color: color))),
        ],
      ),
    );
  }
}
