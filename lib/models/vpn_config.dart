import 'dart:convert';

class VpnConfig {
  final String id;
  final String name;
  final String rawConfig;

  final String privateKey;
  final String address;
  final String dns;

  // AmneziaWG обфускация
  final int? jc;
  final int? jmin;
  final int? jmax;
  final int? s1;
  final int? s2;
  final int? h1;
  final int? h2;
  final int? h3;
  final int? h4;

  final String publicKey;
  final String allowedIPs;
  final String endpoint;
  final String? presharedKey;
  final int? keepalive;

  const VpnConfig({
    required this.id,
    required this.name,
    required this.rawConfig,
    required this.privateKey,
    required this.address,
    required this.dns,
    this.jc, this.jmin, this.jmax,
    this.s1, this.s2,
    this.h1, this.h2, this.h3, this.h4,
    required this.publicKey,
    required this.allowedIPs,
    required this.endpoint,
    this.presharedKey,
    this.keepalive,
  });

  bool get isAmneziaWg => jc != null || jmin != null || jmax != null;

  String get shortEndpoint {
    final parts = endpoint.split(':');
    return parts.isNotEmpty ? parts[0] : endpoint;
  }

  static VpnConfig? parse(String raw, {String? nameHint}) {
    try {
      final lines = raw.replaceAll('\r\n', '\n').split('\n');
      String? privateKey, address, dns, publicKey, allowedIPs, endpoint, presharedKey;
      int? jc, jmin, jmax, s1, s2, h1, h2, h3, h4, keepalive;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        if (trimmed.startsWith('[')) continue;
        final eqIdx = trimmed.indexOf('=');
        if (eqIdx < 0) continue;
        final key = trimmed.substring(0, eqIdx).trim().toLowerCase();
        final value = trimmed.substring(eqIdx + 1).trim();
        final val = value.contains('#') ? value.substring(0, value.indexOf('#')).trim() : value;

        switch (key) {
          case 'privatekey':          privateKey = val;
          case 'address':             address = val;
          case 'dns':                 dns = val;
          case 'publickey':           publicKey = val;
          case 'allowedips':          allowedIPs = val;
          case 'endpoint':            endpoint = val;
          case 'presharedkey':        presharedKey = val;
          case 'jc':                  jc = int.tryParse(val);
          case 'jmin':                jmin = int.tryParse(val);
          case 'jmax':                jmax = int.tryParse(val);
          case 's1':                  s1 = int.tryParse(val);
          case 's2':                  s2 = int.tryParse(val);
          case 'h1':                  h1 = int.tryParse(val);
          case 'h2':                  h2 = int.tryParse(val);
          case 'h3':                  h3 = int.tryParse(val);
          case 'h4':                  h4 = int.tryParse(val);
          case 'persistentkeepalive': keepalive = int.tryParse(val);
        }
      }

      if (privateKey == null || address == null ||
          publicKey == null || allowedIPs == null || endpoint == null) {
        return null;
      }

      final endpointHost = endpoint.contains(':')
          ? endpoint.substring(0, endpoint.lastIndexOf(':'))
          : endpoint;

      return VpnConfig(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: nameHint ?? endpointHost,
        rawConfig: raw,
        privateKey: privateKey,
        address: address,
        dns: dns ?? '1.1.1.1',
        jc: jc, jmin: jmin, jmax: jmax,
        s1: s1, s2: s2,
        h1: h1, h2: h2, h3: h3, h4: h4,
        publicKey: publicKey,
        allowedIPs: allowedIPs,
        endpoint: endpoint,
        presharedKey: presharedKey,
        keepalive: keepalive,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'rawConfig': rawConfig,
    'privateKey': privateKey, 'address': address, 'dns': dns,
    'jc': jc, 'jmin': jmin, 'jmax': jmax,
    's1': s1, 's2': s2,
    'h1': h1, 'h2': h2, 'h3': h3, 'h4': h4,
    'publicKey': publicKey, 'allowedIPs': allowedIPs,
    'endpoint': endpoint, 'presharedKey': presharedKey, 'keepalive': keepalive,
  };

  factory VpnConfig.fromJson(Map<String, dynamic> j) => VpnConfig(
    id: j['id'] as String,
    name: j['name'] as String,
    rawConfig: j['rawConfig'] as String,
    privateKey: j['privateKey'] as String,
    address: j['address'] as String,
    dns: j['dns'] as String,
    jc: j['jc'] as int?, jmin: j['jmin'] as int?, jmax: j['jmax'] as int?,
    s1: j['s1'] as int?, s2: j['s2'] as int?,
    h1: j['h1'] as int?, h2: j['h2'] as int?,
    h3: j['h3'] as int?, h4: j['h4'] as int?,
    publicKey: j['publicKey'] as String,
    allowedIPs: j['allowedIPs'] as String,
    endpoint: j['endpoint'] as String,
    presharedKey: j['presharedKey'] as String?,
    keepalive: j['keepalive'] as int?,
  );

  String toJsonString() => jsonEncode(toJson());
  static VpnConfig fromJsonString(String s) =>
      VpnConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
