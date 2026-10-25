import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatting/currency_formatter.dart';
import '../../../core/formatting/date_formatter.dart';
import '../../../core/money/commission.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../clients/data/clients_repository.dart';
import '../../settings/data/service_types_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../data/services_repository.dart';
import '../domain/service_models.dart';
import 'widgets/client_picker_sheet.dart';

/// بيانات تحميل النموذج.
class _FormData {
  const _FormData({required this.types, required this.defaultPercent, this.service, this.collected = Money.zero});

  final List<ServiceType> types;
  final Percent defaultPercent;
  final ServiceRecord? service;
  final Money collected;
}

/// إضافة خدمة أو تعديلها (الشاشة 15): المستحق يتحدث مع كل حرف.
class ServiceFormScreen extends ConsumerStatefulWidget {
  const ServiceFormScreen({super.key, this.serviceId, this.initialClientId});

  final int? serviceId;
  final int? initialClientId;

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _value = TextEditingController();
  final _percent = TextEditingController();
  final _description = TextEditingController();

  late final Future<_FormData> _data = _load();
  int? _clientId;
  String? _clientName;
  int? _typeId;
  DateTime _date = DateFormatter.today();
  var _loaded = false;
  var _dirty = false;
  var _saving = false;
  var _submitted = false;

  bool get _editing => widget.serviceId != null;

  @override
  void dispose() {
    for (final c in [_title, _value, _percent, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<_FormData> _load() async {
    final services = ref.read(servicesRepositoryProvider);
    final types = await ref.read(serviceTypesRepositoryProvider).all();
    final prefs = await ref.read(settingsRepositoryProvider).preferences();
    final service = _editing ? await services.get(widget.serviceId!) : null;
    final collected = _editing ? await services.collectedFor(widget.serviceId!) : Money.zero;
    final clientId = service?.clientId ?? widget.initialClientId;
    if (clientId != null) await _selectClient(clientId, markDirty: false);
    return _FormData(types: types, defaultPercent: prefs.defaultCommission, service: service, collected: collected);
  }

  void _fill(_FormData data) {
    if (_loaded) return;
    _loaded = true;
    final service = data.service;
    if (service == null) {
      _percent.text = data.defaultPercent.toPlainString();
      final active = data.types.where((t) => t.isActive);
      if (active.isNotEmpty) _typeId = active.first.id;
      return;
    }
    _title.text = service.title;
    _description.text = service.description ?? '';
    _value.text = CurrencyFormatter.number(Money(service.serviceValueMinor));
    _percent.text = Percent(service.commissionBp).toPlainString();
    _typeId = service.serviceTypeId;
    _date = DateFormatter.fromStorage(service.serviceDate);
  }

  Future<void> _selectClient(int id, {bool markDirty = true}) async {
    final client = await ref.read(clientsRepositoryProvider).get(id);
    if (!mounted || client == null) return;
    setState(() {
      _clientId = client.id;
      _clientName = client.name;
      if (markDirty) _dirty = true;
    });
  }

  Future<void> _pickDate() async {
    final today = DateFormatter.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1, today.month, today.day),
      helpText: 'تاريخ الخدمة',
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
        _dirty = true;
      });
    }
  }

  Money? get _commission {
    final value = Money.tryParse(_value.text);
    final percent = Percent.tryParse(_percent.text);
    return value == null || percent == null ? null : computeCommission(value, percent);
  }

  Future<void> _save(_FormData data) async {
    setState(() => _submitted = true);
    final formOk = _formKey.currentState!.validate();
    if (!formOk || _clientId == null || _typeId == null) return;

    final input = ServiceInput(
      clientId: _clientId!,
      serviceTypeId: _typeId!,
      title: _title.text,
      serviceDate: _date,
      value: Money.tryParse(_value.text)!,
      percent: Percent.tryParse(_percent.text)!,
      description: _description.text,
    );
    if (input.commission < data.collected) return; // البطاقة تشرح السبب.
    if (input.value.isZero &&
        !await showConfirmDialog(
          context,
          title: 'قيمة الخدمة صفر',
          message: 'قيمة الخدمة صفر، فلن يكون لك مستحق منها. هل تريد المتابعة؟',
          confirmLabel: 'متابعة',
        )) {
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(servicesRepositoryProvider);
    try {
      if (_editing) {
        await repo.update(widget.serviceId!, input);
      } else {
        final id = await repo.create(input);
        if (!mounted) return;
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الخدمة بنجاح')));
        context.pushReplacement(AppRoutes.serviceDetails(id));
        return;
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الخدمة بنجاح')));
      context.pop();
    } on CommissionBelowCollectedException {
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر حفظ الخدمة. حاول مرة أخرى.')));
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
        appBar: AppBar(title: Text(_editing ? 'تعديل الخدمة' : 'إضافة خدمة جديدة')),
        body: FutureBuilder(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('تعذّر تحميل النموذج'));
            }
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
    const gap = SizedBox(height: 16);
    // الأنواع النشطة، مع النوع الحالي للخدمة حتى لو كان معطّلاً.
    final types = data.types.where((t) => t.isActive || t.id == data.service?.serviceTypeId).toList();

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
            _SectionTitle('بيانات الخدمة'),
            _PickerField(
              label: 'العميل',
              value: _clientName,
              placeholder: 'اختر العميل',
              error: _submitted && _clientId == null ? 'اختر العميل' : null,
              onTap: () async {
                final id = await showClientPicker(context);
                if (id != null) await _selectClient(id);
              },
            ),
            gap,
            Text.rich(
              const TextSpan(text: 'نوع الخدمة', children: [
                TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
              ]),
              style: AppTextStyles.label,
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: _typeId,
              items: [
                for (final type in types) DropdownMenuItem(value: type.id, child: Text(type.name)),
              ],
              onChanged: (id) => setState(() {
                _typeId = id;
                _dirty = true;
              }),
              validator: (id) => id == null ? 'اختر نوع الخدمة' : null,
              style: AppTextStyles.body,
              decoration: const InputDecoration(),
            ),
            gap,
            LabeledField(
              label: 'عنوان الخدمة',
              required: true,
              controller: _title,
              hint: 'مثال: تركيب 5 نقاط شبكة',
              maxLength: 120,
              validator: (v) => (v ?? '').trim().isEmpty ? 'عنوان الخدمة مطلوب' : null,
            ),
            gap,
            _PickerField(
              label: 'تاريخ الخدمة',
              value: DateFormatter.short(_date),
              icon: Icons.calendar_month_rounded,
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),
            _SectionTitle('الحساب'),
            MoneyField(label: 'قيمة الخدمة / اليد العاملة', controller: _value, suffixText: symbol),
            gap,
            LabeledField(
              label: 'نسبة استحقاقي (%)',
              required: true,
              controller: _percent,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              suffixText: '%',
              validator: (v) => Percent.tryParse(v ?? '') == null ? 'أدخل نسبة من 0 إلى 100' : null,
            ),
            const SizedBox(height: 16),
            // يُعاد بناء الحساب وحده مع كل حرف في القيمة أو النسبة.
            ListenableBuilder(
              listenable: Listenable.merge([_value, _percent]),
              builder: (context, _) {
                final commission = _commission;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CommissionCard(commission: commission, symbol: symbol),
                    if (_editing && data.service != null && commission != null)
                      _EditImpact(
                        before: CollectionSummary(
                          commission: Money(data.service!.commissionMinor),
                          collected: data.collected,
                        ),
                        after: CollectionSummary(commission: commission, collected: data.collected),
                        symbol: symbol,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            LabeledField(
              label: 'تفاصيل العمل (اختياري)',
              controller: _description,
              maxLength: 1000,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
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
                  : const Text('حفظ الخدمة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: AppTextStyles.cardTitle.copyWith(color: AppColors.primary)),
    );
  }
}

/// حقل يُفتح منه اختيار (عميل أو تاريخ) بشكل الحقول العادية.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.onTap,
    this.value,
    this.placeholder,
    this.error,
    this.icon = Icons.keyboard_arrow_down_rounded,
  });

  final String label;
  final String? value;
  final String? placeholder;
  final String? error;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(text: label, children: const [TextSpan(text: ' *', style: TextStyle(color: AppColors.error))]),
          style: AppTextStyles.label,
        ),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: InputDecoration(errorText: error, suffixIcon: Icon(icon)),
              child: Text(
                value ?? placeholder ?? '',
                style: AppTextStyles.body.copyWith(color: value == null ? AppColors.textSecondary : null),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// بطاقة الناتج الفورية: «مستحقاتي من الخدمة».
class _CommissionCard extends StatelessWidget {
  const _CommissionCard({required this.commission, required this.symbol});

  final Money? commission;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مستحقاتي من الخدمة', style: AppTextStyles.label.copyWith(color: AppColors.primaryDark)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                commission == null ? '—' : CurrencyFormatter.format(commission!, symbol: symbol),
                style: AppTextStyles.amountLarge.copyWith(color: AppColors.primaryDark),
              ),
            ),
            const SizedBox(height: 4),
            Text('قيمة الخدمة × النسبة ÷ 100', style: AppTextStyles.caption),
            Text('النسبة تُحسب من قيمة الخدمة المدخلة', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

/// أثر التعديل على خدمة لها دفعات: قبل وبعد، أو منع إن صار المستحق أقل من المحصّل (القسم 5.4).
class _EditImpact extends StatelessWidget {
  const _EditImpact({required this.before, required this.after, required this.symbol});

  final CollectionSummary before;
  final CollectionSummary after;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    if (before.collected.isZero || before.commission == after.commission) return const SizedBox.shrink();
    String money(Money m) => CurrencyFormatter.format(m, symbol: symbol);
    final blocked = after.commission < after.collected;
    final color = blocked ? AppColors.error : AppColors.warning;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            blocked
                ? 'المحصّل (${money(after.collected)}) أكبر من المستحق الجديد (${money(after.commission)}). عدّل الدفعات أولاً.'
                : 'لهذه الخدمة دفعات مسجلة. سيتغير المستحق والمتبقي، وتبقى الدفعات كما هي.',
            style: AppTextStyles.label.copyWith(color: color),
          ),
          if (!blocked) ...[
            const SizedBox(height: 10),
            Table(
              columnWidths: const {0: FlexColumnWidth(1.2)},
              children: [
                TableRow(children: [
                  const SizedBox.shrink(),
                  Text('قبل', style: AppTextStyles.caption),
                  Text('بعد', style: AppTextStyles.caption),
                ]),
                _row('مستحقاتي', money(before.commission), money(after.commission)),
                _row('المتبقي', money(before.remaining), money(after.remaining)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  TableRow _row(String label, String before, String after) => TableRow(children: [
        Text(label, style: AppTextStyles.label),
        Text(before, style: AppTextStyles.money(AppTextStyles.label)),
        Text(after, style: AppTextStyles.money(AppTextStyles.label.copyWith(color: AppColors.primary))),
      ]);
}
