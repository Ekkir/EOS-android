class Channel {
  final String id;
  final String name;
  final String icon;
  final String lastText;
  final int lastTs;
  final int lastMessageId;

  const Channel({
    required this.id,
    required this.name,
    required this.icon,
    required this.lastText,
    required this.lastTs,
    this.lastMessageId = 0,
  });

  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
    id:            j['id']              as String? ?? '',
    name:          j['name']            as String? ?? '',
    icon:          j['icon']            as String? ?? '💬',
    lastText:      j['last_text']       as String? ?? '',
    lastTs:        j['last_ts']         as int?    ?? 0,
    lastMessageId: j['last_message_id'] as int?    ?? 0,
  );

  bool get isDm => id.startsWith('dm_');

  String get displayName {
    final n = name.isNotEmpty ? name : id;
    return n.startsWith('dm_') ? n.substring(3) : n;
  }
}
