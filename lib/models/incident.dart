class Incident {
  final int id;
  final String type;        // 'accident' | 'congestion' | 'roadwork' | 'other'
  final String title;
  final String description;
  final double lat;
  final double lon;
  final String severity;   // 'low' | 'medium' | 'high'
  final int timestamp;
  final String creator;

  const Incident({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.lat,
    required this.lon,
    required this.severity,
    required this.timestamp,
    required this.creator,
  });

  factory Incident.fromJson(Map<String, dynamic> j) => Incident(
    id:          j['id']          as int?    ?? 0,
    type:        j['type']        as String? ?? 'other',
    title:       j['title']       as String? ?? '',
    description: j['description'] as String? ?? '',
    lat:         (j['lat']  as num? ?? 0).toDouble(),
    lon:         (j['lon']  as num? ?? 0).toDouble(),
    severity:    j['severity']    as String? ?? 'medium',
    timestamp:   (j['timestamp']  as num? ?? 0).toInt(),
    creator:     j['creator']     as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'type':        type,
    'title':       title,
    'description': description,
    'lat':         lat,
    'lon':         lon,
    'severity':    severity,
    'creator':     creator,
  };
}
