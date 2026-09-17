import 'dart:convert';
import 'dart:io';

/// 本地开发未经过 CI 注入时使用的版本；正式构建由 --dart-define 覆盖。
const String kFallbackAppVersion = '1.0.0';
const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: kFallbackAppVersion,
);
const String kAppBuildNumber = String.fromEnvironment(
  'APP_BUILD_NUMBER',
  defaultValue: '0',
);

final Uri kLatestReleaseUri = Uri.parse(
  'https://api.github.com/repos/NoelOrin/apex-cfg-editor/releases/latest',
);

final Uri kRepositoryUri = Uri.parse(
  'https://github.com/NoelOrin/apex-cfg-editor',
);

typedef UpdateJsonFetcher = Future<String> Function(Uri uri);

/// 按数字组件比较版本号，允许 v1.2.3 和 1.2.3 两种形式。
int compareVersions(String left, String right) {
  final a = _versionParts(left);
  final b = _versionParts(right);
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final leftPart = i < a.length ? a[i] : 0;
    final rightPart = i < b.length ? b[i] : 0;
    if (leftPart != rightPart) return leftPart.compareTo(rightPart);
  }
  return 0;
}

List<int> _versionParts(String raw) {
  var normalized = raw.trim();
  if (normalized.startsWith('v') || normalized.startsWith('V')) {
    normalized = normalized.substring(1);
  }
  normalized = normalized.split(RegExp(r'[-+]')).first;
  if (normalized.isEmpty) throw const FormatException('Version is empty');

  final result = <int>[];
  for (final part in normalized.split('.')) {
    final value = int.tryParse(part);
    if (value == null) {
      throw FormatException('Invalid version: $raw');
    }
    result.add(value);
  }
  return result;
}

class LatestRelease {
  final String version;
  final String name;
  final Uri url;

  const LatestRelease({
    required this.version,
    required this.name,
    required this.url,
  });
}

class UpdateCheckResult {
  final String currentVersion;
  final LatestRelease latestRelease;

  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestRelease,
  });

  bool get hasUpdate =>
      compareVersions(latestRelease.version, currentVersion) > 0;
}

class UpdateCheckException implements Exception {
  final String message;
  final Object? cause;

  const UpdateCheckException(this.message, {this.cause});

  @override
  String toString() => 'UpdateCheckException: $message';
}

/// 读取 GitHub Releases 的最新稳定版本。
class UpdateService {
  final String currentVersion;
  final Uri endpoint;
  final UpdateJsonFetcher fetchJson;

  UpdateService({
    this.currentVersion = kAppVersion,
    Uri? endpoint,
    UpdateJsonFetcher? fetchJson,
  }) : endpoint = endpoint ?? kLatestReleaseUri,
       fetchJson = fetchJson ?? _fetchLatestRelease;

  Future<UpdateCheckResult> checkForUpdates() async {
    try {
      final body = await fetchJson(
        endpoint,
      ).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Release payload is not an object');
      }

      final tag = decoded['tag_name'];
      final rawUrl = decoded['html_url'];
      if (tag is! String ||
          tag.trim().isEmpty ||
          rawUrl is! String ||
          rawUrl.trim().isEmpty) {
        throw const FormatException('Release payload is incomplete');
      }

      final version = tag.trim().replaceFirst(RegExp(r'^[vV]'), '');
      _versionParts(version);
      final url = Uri.tryParse(rawUrl.trim());
      if (url == null || (url.scheme != 'https' && url.scheme != 'http')) {
        throw const FormatException('Release URL is invalid');
      }

      final rawName = decoded['name'];
      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestRelease: LatestRelease(
          version: version,
          name: rawName is String && rawName.trim().isNotEmpty
              ? rawName.trim()
              : version,
          url: url,
        ),
      );
    } on UpdateCheckException {
      rethrow;
    } catch (error) {
      throw UpdateCheckException('Unable to check for updates', cause: error);
    }
  }

  static Future<String> _fetchLatestRelease(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'ApexCfgEditor/$kAppVersion');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('GitHub returned ${response.statusCode}', uri: uri);
      }
      return response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }
}
