/// صيغ العدد العربية للمعدود (مفرد، مثنى، جمع 3–10، تمييز مفرد لما فوق 10).
abstract final class ArabicPlural {
  static String services(int count) => switch (count) {
        0 => 'لا خدمات',
        1 => 'خدمة واحدة',
        2 => 'خدمتان',
        <= 10 => '$count خدمات',
        _ => '$count خدمة',
      };
}
