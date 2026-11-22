import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/dio_client.dart';

/// Service managing dynamic Google Gemini model discovery, preference ordering,
/// 24-hour caching, and 404 auto-skipping.
class GeminiModelService {
  GeminiModelService._();
  static final GeminiModelService instance = GeminiModelService._();

  /// Preferred model order (Dart + Kotlin shared standard, zero 1.5/2.0 legacy models)
  static const List<String> preferredModelOrder = [
    'gemini-3.5-flash-lite',
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-3.1-flash-lite',
    'gemini-flash-lite-latest',
    'gemini-flash-latest',
    'gemini-2.5-flash',
  ];

  static const String keyGeminiModels = "vf_gemini_models";
  static const String keyGeminiModelsDiscoveredAt = "vf_gemini_models_discovered_at";
  static const String keyGeminiUnavailableModels = "vf_gemini_unavailable_models";

  Dio? _dio;
  Dio get dio => _dio ??= DioClient.createDio();

  @visibleForTesting
  set dioClient(Dio client) => _dio = client;

  /// Discover models from Google API and intersect with preferred order.
  /// Caches result in SharedPreferences as `vf_gemini_models`.
  /// Runs at most once per 24 hours unless [force] is true.
  Future<List<String>> discoverModels(String apiKey, {bool force = false}) async {
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) return preferredModelOrder;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastDiscoveredAt = prefs.getInt(keyGeminiModelsDiscoveredAt) ?? 0;

    // Check 24-hour rate limit unless forced
    if (!force && (now - lastDiscoveredAt) < const Duration(hours: 24).inMilliseconds) {
      final cached = getCachedModels(prefs);
      if (cached.isNotEmpty) return cached;
    }

    try {
      final response = await dio.get(
        "https://generativelanguage.googleapis.com/v1beta/models",
        options: Options(
          headers: {"x-goog-api-key": trimmedKey},
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final rawModels = data['models'];
        if (rawModels is List) {
          final discoveredNames = <String>{};
          for (final item in rawModels) {
            if (item is Map) {
              final methods = item['supportedGenerationMethods'];
              final hasGenerateContent = methods is List && methods.contains('generateContent');
              if (hasGenerateContent) {
                var name = (item['name'] ?? '').toString();
                if (name.startsWith('models/')) {
                  name = name.substring('models/'.length);
                }
                if (name.isNotEmpty) {
                  discoveredNames.add(name);
                }
              }
            }
          }

          final intersected = filterAndOrderModels(discoveredNames);
          if (intersected.isNotEmpty) {
            await prefs.setString(keyGeminiModels, jsonEncode(intersected));
            await prefs.setInt(keyGeminiModelsDiscoveredAt, now);
            debugPrint("[GeminiModelService] Discovered ${intersected.length} supported models: $intersected");
            return intersected;
          }
        }
      }
    } catch (e) {
      debugPrint("[GeminiModelService] Discovery failed: $e. Using fallback list.");
    }

    // Fallback: cached or default preferred order
    final cached = getCachedModels(prefs);
    if (cached.isNotEmpty) return cached;

    await prefs.setString(keyGeminiModels, jsonEncode(preferredModelOrder));
    return preferredModelOrder;
  }

  /// Pure helper to intersect and order models according to preferred order
  static List<String> filterAndOrderModels(Set<String> discoveredModels) {
    return preferredModelOrder
        .where((model) => discoveredModels.contains(model))
        .toList();
  }

  /// Get cached models from SharedPreferences
  List<String> getCachedModels(SharedPreferences prefs) {
    final raw = prefs.getString(keyGeminiModels);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded.map((e) => e.toString()).toList();
        return list.isNotEmpty ? list : [];
      }
    } catch (_) {}
    return [];
  }

  /// Get active models excluding any currently marked unavailable (e.g. 404-skipped)
  Future<List<String>> getActiveModels() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = getCachedModels(prefs);
    final baseList = cached.isNotEmpty ? cached : preferredModelOrder;

    final unavailable = getUnavailableModelsMap(prefs);
    final now = DateTime.now().millisecondsSinceEpoch;

    final active = baseList.where((m) {
      final unavailUntil = unavailable[m];
      if (unavailUntil != null && unavailUntil > now) {
        return false;
      }
      return true;
    }).toList();

    return active.isNotEmpty ? active : preferredModelOrder;
  }

  /// Marks a model as unavailable for 24 hours on 404
  Future<void> markModelUnavailable(String model) async {
    final prefs = await SharedPreferences.getInstance();
    final map = getUnavailableModelsMap(prefs);
    final until = DateTime.now().millisecondsSinceEpoch + const Duration(hours: 24).inMilliseconds;
    map[model] = until;
    await prefs.setString(keyGeminiUnavailableModels, jsonEncode(map));
    debugPrint("[GeminiModelService] Model $model marked unavailable until ${DateTime.fromMillisecondsSinceEpoch(until)}");
  }

  Map<String, int> getUnavailableModelsMap(SharedPreferences prefs) {
    final raw = prefs.getString(keyGeminiUnavailableModels);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v is num ? v.toInt() : 0));
      }
    } catch (_) {}
    return {};
  }
}
