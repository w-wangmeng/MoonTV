import 'dart:convert';

import '../lib/models.dart';

const _alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

String base58Encode(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = value * BigInt.from(256) + BigInt.from(byte);
  }
  var out = '';
  while (value > BigInt.zero) {
    final remainder = (value % BigInt.from(58)).toInt();
    out = _alphabet[remainder] + out;
    value = value ~/ BigInt.from(58);
  }
  for (final byte in bytes) {
    if (byte != 0) break;
    out = '1$out';
  }
  return out;
}

void main() {
  final tvbox = jsonEncode({
    'sites': [
      {
        'key': 'json1',
        'name': '🎬 JSON 源',
        'type': 1,
        'api': 'https://example.com/api.php/provide/vod',
      },
      {
        'key': 'spider',
        'name': 'Spider',
        'type': 3,
        'api': 'csp_Spider',
      },
      {
        'key': 'xml1',
        'name': 'XML 源',
        'type': 0,
        'api': 'https://example.com/xml.php',
      },
    ],
  });
  final parsedTvBox = ConfigParser.parse(tvbox);
  assert(parsedTvBox.sites.length == 2, 'expected two usable TVBox sites');
  assert(parsedTvBox.skipped == 1, 'expected one skipped spider site');
  assert(parsedTvBox.sites.first.displayName == 'JSON 源');
  assert(
    !parsedTvBox.warnings.any((warning) => warning.contains('只有直播源')),
    'a TVBox config with sites must not be reported as live-only',
  );

  final moon = jsonEncode({
    'cache_time': 7200,
    'api_site': {
      'one': {
        'name': 'MoonTV 源',
        'api': 'https://moon.example.com/api.php/provide/vod',
        'detail': 'https://moon.example.com',
      },
    },
  });
  final parsedMoon = ConfigParser.parse(moon);
  assert(parsedMoon.sites.length == 1);
  assert(parsedMoon.format.contains('MoonTV'));

  final encoded = base58Encode(utf8.encode(moon));
  final parsedBase58 = ConfigParser.parse(encoded);
  assert(parsedBase58.sites.length == 1);
  assert(parsedBase58.format == 'Base58 JSON');

  final relative = ConfigParser.parse(
    jsonEncode({
      'api_site': {
        'rel': {'name': '相对地址', 'api': '/api.php/provide/vod'},
      },
    }),
    origin: 'https://origin.example.com/config.json',
  );
  assert(
    relative.sites.first.api == 'https://origin.example.com/api.php/provide/vod',
    'expected relative API URL to resolve against origin',
  );

  print('parser checks passed: TVBox, MoonTV api_site, Base58, relative URL');
}
