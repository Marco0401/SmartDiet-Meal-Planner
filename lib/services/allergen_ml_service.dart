import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AllergenMLService {
  static String get _baseUrl {
    final fromEnv = dotenv.env['ML_API_BASE'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return 'http://127.0.0.1:8000';
  }

  static double get _threshold {
    final t = dotenv.env['ML_THRESHOLD'];
    if (t == null) return 0.2; // default more sensitive
    final v = double.tryParse(t);
    return (v == null || v <= 0 || v >= 1) ? 0.2 : v;
  }

  static Future<AllergenMLResult> predictWithScores(String text) async {
    final uri = Uri.parse('$_baseUrl/predict_allergens');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );
    if (res.statusCode != 200) {
      throw Exception('ML API error ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final srvThr = (data['threshold'] is num) ? (data['threshold'] as num).toDouble() : null;
    final thr = srvThr ?? _threshold;

    final scores = (data['scores'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v is num) ? v.toDouble() : 0.0),
        ) ??
        <String, double>{};

    Map<String, int> labels;
    if (scores.isNotEmpty) {
      labels = scores.map((k, v) => MapEntry(k, v >= thr ? 1 : 0));
    } else {
      final raw = (data['labels'] as Map<String, dynamic>?) ?? {};
      labels = raw.map((k, v) => MapEntry(k, (v is num) ? v.toInt() : 0));
    }

    return AllergenMLResult(scores: scores, labels: labels, threshold: thr);
  }

  static Future<Map<String, int>> predictAllergens(String text) async {
    final r = await predictWithScores(text);
    return r.labels;
  }
}

class AllergenMLResult {
  final Map<String, double> scores;
  final Map<String, int> labels;
  final double threshold;

  AllergenMLResult({required this.scores, required this.labels, required this.threshold});
}

