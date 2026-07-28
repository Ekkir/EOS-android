class Message {
  final int id;
  final String channel;
  final String sender;
  final String text;
  final int ts;
  final String type;     // 'text' | 'image' | 'file' | 'video'
  final String mediaId;

  const Message({
    required this.id,
    required this.channel,
    required this.sender,
    required this.text,
    required this.ts,
    required this.type,
    required this.mediaId,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
    id:      j['id']       as int?    ?? 0,
    channel: j['channel']  as String? ?? 'general',
    sender:  j['sender']   as String? ?? '',
    text:    j['text']     as String? ?? '',
    ts:      j['ts']       as int?    ?? 0,
    type:    j['type']     as String? ?? 'text',
    mediaId: j['media_id'] as String? ?? '',
  );

  bool get hasMedia => mediaId.isNotEmpty;
}
