import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AgentConnectionResult {
  final bool ok;
  final int latencyMs;
  final String statusText;
  final String? error;

  const AgentConnectionResult({
    required this.ok,
    this.latencyMs = 0,
    required this.statusText,
    this.error,
  });
}

class DiscoveredPrinter {
  final String id;
  final String name;
  final String type; // 'usb', 'bluetooth', 'network'
  final String? port;

  const DiscoveredPrinter({
    required this.id,
    required this.name,
    required this.type,
    this.port,
  });

  factory DiscoveredPrinter.fromJson(Map<String, dynamic> json) {
    return DiscoveredPrinter(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['id']?.toString() ?? 'Printer',
      type: json['type']?.toString() ?? 'usb',
      port: json['port']?.toString(),
    );
  }
}

class PrintAgentService {
  static final PrintAgentService _instance = PrintAgentService._internal();
  factory PrintAgentService() => _instance;
  PrintAgentService._internal();

  String _agentUrl = 'http://localhost:9101';

  String get agentUrl => _agentUrl;
  set agentUrl(String url) {
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isNotEmpty) {
      _agentUrl = trimmed;
    }
  }

  /// Check if print agent is active and running
  Future<bool> isAgentRunning() async {
    try {
      final res = await http
          .get(Uri.parse('$_agentUrl/health'))
          .timeout(const Duration(milliseconds: 1500));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['status'] == 'ok';
      }
    } catch (_) {}
    return false;
  }

  /// Discover connected USB and paired Bluetooth printers
  Future<Map<String, List<DiscoveredPrinter>>> discoverPrinters() async {
    final result = <String, List<DiscoveredPrinter>>{
      'usb': [],
      'bluetooth': [],
    };
    try {
      final res = await http
          .get(Uri.parse('$_agentUrl/printers/discover'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['usb'] is List) {
          result['usb'] = (data['usb'] as List)
              .map((e) => DiscoveredPrinter.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
        if (data['bluetooth'] is List) {
          result['bluetooth'] = (data['bluetooth'] as List)
              .map((e) => DiscoveredPrinter.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('discoverPrinters error: $e');
    }
    return result;
  }

  /// Real connection test via agent
  Future<AgentConnectionResult> testConnection({
    required String type, // 'wifi', 'usb', 'bluetooth'
    String? ip,
    int? port,
    String? deviceId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_agentUrl/printer/test-connection'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'type': type,
              'ip': ip,
              'port': port ?? 9100,
              'deviceId': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final ok = data['ok'] == true;
        return AgentConnectionResult(
          ok: ok,
          latencyMs: (data['latencyMs'] as num?)?.toInt() ?? 0,
          statusText: data['statusText']?.toString() ?? (ok ? 'Ulangan' : 'Ulanmadi'),
          error: data['error']?.toString(),
        );
      } else {
        final data = jsonDecode(res.body);
        return AgentConnectionResult(
          ok: false,
          statusText: 'Ulanmadi',
          error: data['error']?.toString() ?? 'Server xatosi (${res.statusCode})',
        );
      }
    } catch (e) {
      return const AgentConnectionResult(
        ok: false,
        statusText: 'Ulanmadi',
        error: 'Print agent bilan bog‘lanib bo‘lmadi. Kompyuterda print-agent ishga tushirilganligini tekshiring.',
      );
    }
  }

  /// Send print job to the agent
  Future<bool> printJob({
    required String jobId,
    required String type, // 'xarid', 'oshpaz', 'test'
    required Map<String, dynamic> printerConfig,
    String? imageBase64,
    List<int>? rawBytes,
    bool openDrawer = false,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_agentUrl/print'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'jobId': jobId,
              'type': type,
              'printerConfig': printerConfig,
              'image': imageBase64,
              'rawBytes': rawBytes,
              'openDrawer': openDrawer,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint('PrintAgentService printJob error: $e');
    }
    return false;
  }

  /// Update print agent config with cafe info for background cloud polling
  Future<void> updateAgentCafeConfig({
    required String cafeId,
    required String backendUrl,
    Map<String, dynamic>? printerConfig,
  }) async {
    try {
      await http
          .post(
            Uri.parse('$_agentUrl/config'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'cafeId': cafeId,
              'backendUrl': backendUrl,
              'printerConfig': printerConfig,
            }),
          )
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }
}

