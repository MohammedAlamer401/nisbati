import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/formatting/currency_formatter.dart';
import '../../../../core/formatting/date_formatter.dart';
import '../../../../core/money/money.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../settings/data/settings_repository.dart';
import '../../data/services_repository.dart';

/// عنصر خدمة في القوائم: العنوان، والنوع والتاريخ، والقيمة، والنسبة والمستحق، والحالة.
class ServiceTile extends ConsumerWidget {
  const ServiceTile({super.key, required this.item, this.showClient, this.onTap});

  final ServiceListItem item;

  /// اسم العميل عند العرض خارج صفحة العميل.
  final String? showClient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.watch(currencySymbolProvider);
    final service = item.service;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      service.title,
                      style: AppTextStyles.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(item.collection.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  ?showClient,
                  item.typeName,
                  DateFormatter.short(DateFormatter.fromStorage(service.serviceDate)),
                ].join(' · '),
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _Figure(
                      label: 'قيمة الخدمة',
                      value: CurrencyFormatter.format(Money(service.serviceValueMinor), symbol: symbol),
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      label: 'مستحقاتي (${CurrencyFormatter.percent(Percent(service.commissionBp))})',
                      value: CurrencyFormatter.format(item.collection.commission, symbol: symbol),
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color = AppColors.textPrimary});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value, style: AppTextStyles.money(AppTextStyles.label.copyWith(color: color))),
        ),
      ],
    );
  }
}
