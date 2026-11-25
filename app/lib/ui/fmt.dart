const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September',
  'October', 'November', 'December',
];
const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String two(int n) => n.toString().padLeft(2, '0');

/// "8:35" (12h, with [ampm] separate) or "20:35" (24h).
String clock(DateTime t, {bool h24 = false}) =>
    h24 ? '${two(t.hour)}:${two(t.minute)}' : '${t.hour % 12 == 0 ? 12 : t.hour % 12}:${two(t.minute)}';
String ampm(DateTime t) => t.hour < 12 ? 'AM' : 'PM';
String clockFull(DateTime t, {bool h24 = false}) => h24 ? clock(t, h24: true) : '${clock(t)} ${ampm(t)}';

String weekday(DateTime t) => _days[t.weekday - 1];
String weekday3(DateTime t) => weekday(t).substring(0, 3);
String month(DateTime t) => _months[t.month - 1];
String month3(DateTime t) => month(t).substring(0, 3);
String longDate(DateTime t) => '${weekday(t)}, ${month(t)} ${t.day}';

/// "2h 12m", "48m"
String dur(Duration d) {
  final m = d.inMinutes.clamp(0, 1 << 30);
  final h = m ~/ 60;
  return h > 0 ? '${h}h ${m % 60}m' : '${m % 60}m';
}

/// "3d 5h", "2h 4m", "12m"
String durLong(Duration d) {
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
  return dur(d);
}

String ago(Duration d) {
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return d.inDays == 1 ? '1 day ago' : '${d.inDays} days ago';
}

/// mm:ss
String mmss(int ms) {
  final s = (ms / 1000).floor().clamp(0, 1 << 30);
  return '${s ~/ 60}:${two(s % 60)}';
}

/// 48.2M, 182K, 214
String compact(num n) {
  if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(1)}B';
  if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
  if (n >= 1e3) return '${(n / 1e3).round()}K';
  return '${n.round()}';
}

/// Bytes -> "3.2 GB" style with GiB base (matches OS UIs).
String bytes(num b, {int digits = 1}) {
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = b.toDouble();
  var i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : digits)} ${u[i]}';
}

/// Bytes/sec -> ("1.8", "MB/s")
(String, String) rate(num bps) {
  if (bps >= 1024 * 1024) return ((bps / 1048576).toStringAsFixed(1), 'MB/s');
  return ((bps / 1024).round().toString(), 'KB/s');
}

/// Bytes/sec -> Mbps
String mbps(num bps) {
  final v = bps * 8 / 1e6;
  return v >= 100 ? v.round().toString() : v.toStringAsFixed(1);
}
