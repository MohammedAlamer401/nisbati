import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/validation/contact_validators.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/labeled_field.dart';
import '../data/clients_repository.dart';
import '../domain/client_models.dart';

/// إضافة عميل أو تعديله (الشاشة 12). عند الإضافة تُغلق بمعرّف العميل الجديد.
class ClientFormScreen extends ConsumerStatefulWidget {
  const ClientFormScreen({super.key, this.clientId});

  /// `null` للإضافة.
  final int? clientId;

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  late final Future<Client?> _initial = widget.clientId == null
      ? Future.value(null)
      : ref.read(clientsRepositoryProvider).get(widget.clientId!);
  var _loaded = false;
  var _dirty = false;
  var _saving = false;

  bool get _editing => widget.clientId != null;

  @override
  void dispose() {
    for (final c in [_name, _phone, _contact, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Client? client) {
    if (_loaded) return;
    _loaded = true;
    if (client == null) return;
    _name.text = client.name;
    _phone.text = client.phone ?? '';
    _contact.text = client.contactName ?? '';
    _address.text = client.address ?? '';
    _notes.text = client.notes ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(clientsRepositoryProvider);
    if (await repo.hasDuplicateName(_name.text, excludeId: widget.clientId)) {
      if (!mounted) return;
      final proceed = await showConfirmDialog(
        context,
        title: 'اسم مكرر',
        message: 'يوجد عميل بهذا الاسم. هل تريد المتابعة؟',
        confirmLabel: 'متابعة الحفظ',
      );
      if (!proceed) return;
    }
    setState(() => _saving = true);
    final input = ClientInput(
      name: _name.text,
      phone: _phone.text,
      contactName: _contact.text,
      address: _address.text,
      notes: _notes.text,
    );
    try {
      final id = _editing ? widget.clientId! : await repo.create(input);
      if (_editing) await repo.update(id, input);
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ العميل')));
      context.pop(id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر حفظ العميل. حاول مرة أخرى.')));
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
    const gap = SizedBox(height: 16);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_editing ? 'تعديل العميل' : 'إضافة عميل')),
        body: FutureBuilder(
          future: _initial,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            _fill(snapshot.data);
            // كل الحقول تُبنى دائماً (لا ListView) حتى يتحقق النموذج منها ولو كانت خارج الشاشة.
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
                    LabeledField(
                      label: 'اسم العميل أو المؤسسة',
                      required: true,
                      controller: _name,
                      hint: 'مثال: مصنع هابي',
                      maxLength: 100,
                      validator: (v) => ContactValidators.requiredName(v, max: 100),
                    ),
                    gap,
                    LabeledField(
                      label: 'رقم الهاتف',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      validator: ContactValidators.phone,
                    ),
                    gap,
                    LabeledField(label: 'اسم جهة الاتصال', controller: _contact, maxLength: 60),
                    gap,
                    LabeledField(label: 'العنوان', controller: _address, maxLength: 120),
                    gap,
                    LabeledField(
                      label: 'ملاحظات',
                      controller: _notes,
                      maxLength: 500,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('حفظ العميل'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: () => Navigator.maybePop(context), child: const Text('إلغاء')),
                    if (_editing) ...[
                      const SizedBox(height: 16),
                      Text(
                        'تعديل الاسم لا يغيّر الخدمات المسجلة لهذا العميل.',
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
