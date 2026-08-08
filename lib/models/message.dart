class Message {
  final int id;
  final String channel;
  final String sender;
  final String text;
  final int ts;
  final String type;     // 'text' | 'image' | 'file' | 'video' | 'audio' | 'video_circle'
  final String mediaId;
  final bool edited;
  final int? editedAt;
  final int? replyToId;
  final String? replyToText;

  const Message({
    required this.id,
    required this.channel,
    required this.sender,
    required this.text,
    required this.ts,
    required this.type,
    required this.mediaId,
    this.edited = false,
    this.editedAt,
    this.replyToId,
    this.replyToText,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
    id:          j['id']           as int?    ?? 0,
    channel:     j['channel']      as String? ?? 'general',
    sender:      j['sender']       as String? ?? '',
    text:        j['text']         as String? ?? '',
    ts:          j['ts']           as int?    ?? 0,
    type:        j['type']         as String? ?? 'text',
    mediaId:     j['media_id']     as String? ?? '',
    edited:      j['edited']       == true,
    editedAt:    j['edited_at']    as int?,
    replyToId:   j['reply_to_id']  as int?,
    replyToText: j['reply_to_text'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id':            id,
    'channel':       channel,
    'sender':        sender,
    'text':          text,
    'ts':            ts,
    'type':          type,
    'media_id':      mediaId,
    'edited':        edited,
    'edited_at':     editedAt,
    'reply_to_id':   replyToId,
    'reply_to_text': replyToText,
  };

  Message copyWith({
    String? text,
    bool? edited,
    int? editedAt,
  }) => Message(
    id:          id,
    channel:     channel,
    sender:      sender,
    text:        text ?? this.text,
    ts:          ts,
    type:        type,
    mediaId:     mediaId,
    edited:      edited ?? this.edited,
    editedAt:    editedAt ?? this.editedAt,
    replyToId:   replyToId,
    replyToText: replyToText,
  );

  bool get hasMedia => mediaId.isNotEmpty;
}
