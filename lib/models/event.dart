class EosEvent {
  final int id;
  final String type;        // 'meetup' | 'here' | 'other'
  final String title;
  final String description;
  final double lat;
  final double lon;
  final int timestamp;
  final String creator;
  final int? expiresAt;     // Unix timestamp истечения, null = бессрочно

  const EosEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.lat,
    required this.lon,
    required this.timestamp,
    required this.creator,
    this.expiresAt,
  });

  factory EosEvent.fromJson(Map<String, dynamic> j) => EosEvent(
    id:          j['id']          as int?    ?? 0,
    type:        j['type']        as String? ?? 'other',
    title:       j['title']       as String? ?? '',
    description: j['description'] as String? ?? '',
    lat:         (j['lat']  as num? ?? 0).toDouble(),
    lon:         (j['lon']  as num? ?? 0).toDouble(),
    timestamp:   (j['timestamp']  as num? ?? 0).toInt(),
    creator:     j['creator']     as String? ?? '',
    expiresAt:   (j['expires_at'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'type':        type,
    'title':       title,
    'description': description,
    'lat':         lat,
    'lon':         lon,
    'creator':     creator,
    if (expiresAt != null) 'expires_at': expiresAt,
  };
}
