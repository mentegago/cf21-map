import 'dart:convert';
import 'package:http/http.dart' as http;

class VersionInfo {
  final int currentVersion;
  final String releaseNotes;

  VersionInfo({
    required this.currentVersion,
    required this.releaseNotes,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      currentVersion: json['current_version'] as int,
      releaseNotes: json['release_notes'] as String,
    );
  }
}

class VersionService {
  static const String _versionUrl = 'https://cf21-config.nnt.gg/version.json';
  static const int _clientVersion = 3; // Current client version

  static Future<VersionInfo?> fetchVersionInfo() async {
    try {
      // Cache busting that I hope hope hope will work...
      final uri = Uri.parse(_versionUrl).replace(
        queryParameters: {
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'CF21-Map-NNT/1.0.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return VersionInfo.fromJson(jsonData);
      } else {
        print('Failed to fetch version info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching version info: $e');
      return null;
    }
  }

  static bool isUpdateAvailable(VersionInfo? versionInfo) {
    if (versionInfo == null) return false;
    return versionInfo.currentVersion > _clientVersion;
  }

  static int get clientVersion => _clientVersion;
}
