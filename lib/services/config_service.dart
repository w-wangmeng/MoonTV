import 'dart:convert';

import 'package:dio/dio.dart';

import '../models.dart';

class ConfigService {
  ConfigService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 25),
              sendTimeout: const Duration(seconds: 15),
              followRedirects: true,
              maxRedirects: 5,
              responseType: ResponseType.plain,
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
                'Accept': 'application/json, text/plain, */*',
              },
            ),
          );

  final Dio _dio;

  Future<ConfigLoadResult> load(String url) async {
    final normalized = _normalizeUrl(url);
    final result = await _loadOne(normalized);
    if (result.subConfigUrls.isEmpty) return result;

    var merged = result;
    final urls = result.subConfigUrls.take(12).toList();
    for (final subUrl in urls) {
      try {
        final sub = await _loadOne(subUrl);
        merged = merged.merge(sub);
      } catch (error) {
        merged = ConfigLoadResult(
          sites: merged.sites,
          format: merged.format,
          warnings: [...merged.warnings, '子配置加载失败：$subUrl（$error）'],
          skipped: merged.skipped,
        );
      }
    }
    if (merged.sites.isEmpty) {
      throw ApiException('配置及其子配置都没有可用的点播源');
    }
    return merged;
  }

  Future<ConfigLoadResult> _loadOne(String url) async {
    late final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(url);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status != null) {
        throw ApiException('配置地址返回 HTTP $status');
      }
      throw ApiException(_friendlyDioError(error));
    }

    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 400) {
      throw ApiException('配置地址返回 HTTP $status');
    }

    final data = response.data;
    final raw = data is String ? data : jsonEncode(data);
    if (raw.trim().isEmpty) throw ApiException('配置地址返回了空内容');
    try {
      return ConfigParser.parse(raw, origin: url);
    } on FormatException catch (error) {
      throw ApiException('配置解析失败：${error.message}');
    }
  }

  String _normalizeUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) throw ApiException('请输入配置地址');
    if (!url.contains('://')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ApiException('只支持 HTTP/HTTPS 配置地址');
    }
    return uri.toString();
  }

  String _friendlyDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时，请检查网络或换一个配置地址';
      case DioExceptionType.connectionError:
        return '无法连接配置地址，请检查网络或域名';
      case DioExceptionType.badCertificate:
        return '配置地址的 HTTPS 证书无效';
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        return '加载配置失败：${error.message ?? error.type.name}';
    }
  }
}
