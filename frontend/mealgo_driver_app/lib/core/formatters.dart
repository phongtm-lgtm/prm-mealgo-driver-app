String money(int amount) {
  final digits = amount.abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
  return '${amount < 0 ? '-' : ''}$grouped đ';
}

String shortReference(String id) =>
    id.length > 8 ? id.substring(0, 8).toUpperCase() : id;
