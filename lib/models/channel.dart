class Channel {
  final String id;
  final String name;
  final String icon;
  final String lastText;
  final int lastTs;

  const Channel({
    required this.id,
    required this.name,
    required this.icon,
    required this.lastText,
    required this.lastTs,
  });

  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
    id:       j['id']        as String? ?? '',
    name:     j['name']      as String? ?? '',
    icon:     j['icon']      as String? ?? '💬',
    lastText: j['last_text'] as String? ?? '',
    lastTs:   j['last_ts']   as int?    ?? 0,
  );

  bool get isDm => id.startsWith('dm_');
}
