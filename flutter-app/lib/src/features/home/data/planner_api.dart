import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

const String _defaultBackendBaseUrl = String.fromEnvironment(
  'PLANGENIE_API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

final backendBaseUriProvider = Provider<Uri>((ref) {
  return Uri.parse(_defaultBackendBaseUrl);
});

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final plannerApiClientProvider = Provider<PlannerApiClient>((ref) {
  final baseUri = ref.watch(backendBaseUriProvider);
  final client = ref.watch(httpClientProvider);
  return PlannerApiClient(
    client: client,
    baseUri: baseUri,
  );
});

class PlannerApiClient {
  PlannerApiClient({required http.Client client, required Uri baseUri})
      : _client = client,
        _baseUri = baseUri;

  final http.Client _client;
  final Uri _baseUri;

  Future<PlanResponse> createPlan(PlanRequest request) async {
    final uri = _baseUri.resolve('/plan');
    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlanApiException(
        statusCode: response.statusCode,
        message: 'Backend returned ${response.statusCode}',
        body: response.body,
      );
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    return PlanResponse.fromJson(json);
  }
}

class PlanApiException implements Exception {
  PlanApiException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  final int statusCode;
  final String message;
  final String? body;

  @override
  String toString() {
    final bodyText = body == null || body!.isEmpty ? '' : '\n$body';
    return 'PlanApiException($statusCode): $message$bodyText';
  }
}

class PlanRequest {
  const PlanRequest({
    required this.origin,
    required this.destination,
    required this.startDate,
    required this.endDate,
    this.pax = 2,
    this.budget = 25000,
    this.mood = 2,
  });

  final String origin;
  final String destination;
  final String startDate;
  final String endDate;
  final int pax;
  final int budget;
  final int mood;

  Map<String, dynamic> toJson() {
    return {
      'origin': origin,
      'destination': destination,
      'startDate': startDate,
      'endDate': endDate,
      'pax': pax,
      'budget': budget,
      'mood': mood,
    };
  }
}

class PlanResponse {
  PlanResponse({required this.tripId, required this.draft});

  final String tripId;
  final PlanDraft draft;

  factory PlanResponse.fromJson(Map<String, dynamic> json) {
    return PlanResponse(
      tripId: json['tripId'] as String,
      draft: PlanDraft.fromJson(json['draft'] as Map<String, dynamic>),
    );
  }
}

class PlanDraft {
  PlanDraft({required this.city, required this.days});

  final String city;
  final List<PlanDay> days;

  factory PlanDraft.fromJson(Map<String, dynamic> json) {
    final daysJson = json['days'] as List<dynamic>?;
    return PlanDraft(
      city: json['city'] as String? ?? 'Unknown',
      days: daysJson == null
          ? const []
          : daysJson
              .map((dynamic day) =>
                  PlanDay.fromJson(day as Map<String, dynamic>))
              .toList(),
    );
  }
}

class PlanDay {
  PlanDay({required this.date, required this.blocks});

  final String date;
  final List<PlanBlock> blocks;

  factory PlanDay.fromJson(Map<String, dynamic> json) {
    final blocksJson = json['blocks'] as List<dynamic>?;
    return PlanDay(
      date: json['date'] as String? ?? '',
      blocks: blocksJson == null
          ? const []
          : blocksJson
              .map((dynamic block) =>
                  PlanBlock.fromJson(block as Map<String, dynamic>))
              .toList(),
    );
  }
}

class PlanBlock {
  PlanBlock({
    required this.time,
    required this.title,
    this.tag,
    this.placeId,
    this.lat,
    this.lng,
  });

  final String time;
  final String title;
  final String? tag;
  final String? placeId;
  final double? lat;
  final double? lng;

  factory PlanBlock.fromJson(Map<String, dynamic> json) {
    final lat = json['lat'];
    final lng = json['lng'];
    return PlanBlock(
      time: json['time'] as String? ?? '',
      title: json['title'] as String? ?? '',
      tag: json['tag'] as String?,
      placeId: json['place_id'] as String? ?? json['placeId'] as String?,
      lat: lat is num ? lat.toDouble() : null,
      lng: lng is num ? lng.toDouble() : null,
    );
  }
}
