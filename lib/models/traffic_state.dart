class RoadState {
  final String state;     // 'green' | 'yellow' | 'red'
  final int remaining;
  final int toGreen;

  const RoadState({required this.state, required this.remaining, required this.toGreen});

  factory RoadState.fromJson(Map<String, dynamic> j) => RoadState(
    state:     j['state']     as String? ?? 'red',
    remaining: j['remaining'] as int?    ?? 0,
    toGreen:   j['to_green']  as int?    ?? 0,
  );
}

class TrafficSnapshot {
  final RoadState pereval;
  final RoadState abaza;
  final RoadState zarechka;

  const TrafficSnapshot({required this.pereval, required this.abaza, required this.zarechka});

  factory TrafficSnapshot.fromJson(Map<String, dynamic> j) => TrafficSnapshot(
    pereval:  RoadState.fromJson(j['pereval']  as Map<String, dynamic>? ?? {}),
    abaza:    RoadState.fromJson(j['abaza']    as Map<String, dynamic>? ?? {}),
    zarechka: RoadState.fromJson(j['zarechka'] as Map<String, dynamic>? ?? {}),
  );

  RoadState operator [](String road) {
    switch (road) {
      case 'pereval':  return pereval;
      case 'zarechka': return zarechka;
      default:         return abaza;
    }
  }
}
