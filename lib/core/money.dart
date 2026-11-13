/// Parses "1,234.50" into minor units (123450). Returns null if invalid.
int? parseMinor(String input) {
  final c = input.replaceAll(',', '').trim();
  final m = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(c);
  if (m == null) return null;
  final whole = int.parse(m.group(1)!);
  final frac = (m.group(2) ?? '').padRight(2, '0').substring(0, 2);
  return whole * 100 + int.parse(frac);
}

String formatMinor(int minor, [String currency = '']) {
  final neg = minor < 0;
  final abs = minor.abs();
  final whole = (abs ~/ 100).toString();
  final frac = (abs % 100).toString().padLeft(2, '0');
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  final cur = currency.isEmpty ? '' : '$currency ';
  return '${neg ? '-' : ''}$cur$buf.$frac';
}

String fmtDate(DateTime d) {
  String t(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${t(d.month)}-${t(d.day)} ${t(d.hour)}:${t(d.minute)}';
}
