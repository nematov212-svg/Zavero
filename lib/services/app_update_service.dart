import 'package:flutter/material.dart';

class AppUpdateInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final bool forceUpdate;
  final String releaseNotes;

  AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.forceUpdate,
    required this.releaseNotes,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> j) {
    return AppUpdateInfo(
      version: j['version'] as String? ?? '1.0.0',
      buildNumber: (j['buildNumber'] as num?)?.toInt() ?? 1,
      downloadUrl: j['downloadUrl'] as String? ?? '',
      forceUpdate: j['forceUpdate'] == true,
      releaseNotes: j['releaseNotes'] as String? ?? '',
    );
  }
}

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  static const String currentVersion = '1.0.0';
  static const int currentBuildNumber = 1;

  /// Update tekshiruvi butunlay o'chirilgan
  Future<AppUpdateInfo?> checkUpdate() async => null;

  /// Update popup oynasi o'chirilgan
  Future<void> showUpdateDialog(BuildContext context, AppUpdateInfo info) async {}
}
