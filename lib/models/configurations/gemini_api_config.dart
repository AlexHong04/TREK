import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiApiConfig {
  // Gemini API Key 
  static const String _apiKey = 'AQ.Ab8RN6LBMqSFEdLyOqVG7NMIbAT1zEXJ-IqIwgivJRl0jndtOw';
  
  static late final GenerativeModel _model;

  /// Initialize Gemini model
  static void initialize() {
    _model = GenerativeModel(
      model: 'Gemini 3 Flash',
      apiKey: _apiKey,
    );
  }

  /// Ask Gemini for itinerary
  static Future<String> askGeminiForItinerary({
    required String destination,
    required String dates,
    required String budget,
    String? preference,
    String? emergencyFund,
  }) async {
    final prompt = '''
    You are an expert travel planner. Please help me generate a travel itinerary.
    Details:
    - Destination: $destination
    - Dates: $dates
    - Budget: \$$budget
    ${preference != null ? '- Preference: $preference' : ''}
    ${emergencyFund != null ? '- Emergency Fund: $emergencyFund' : ''}

    Please provide a structured day-by-day itinerary with estimated costs and durations for each activity.
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      return response.text ?? 'Gemini returned an empty response.';
    } catch (e) {
      print('Gemini API Error: $e');
      throw Exception('Failed to generate itinerary. Error: $e');
    }
  }

  /// Returns a Base64 encoded image string
  static Future<String?> generateLocationImage(String promptText) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-001:predict');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey,
        },
        body: jsonEncode({
          "instances": [
            {"prompt": promptText}
          ],
          "parameters": {
            "sampleCount": 1,
            // "aspectRatio": "16:9" // "1:1", "3:4", "4:3", "16:9"
          }
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final predictions = data['predictions'] as List?;
        if (predictions != null && predictions.isNotEmpty) {
           final imageBase64 = predictions[0]['bytesBase64Encoded'];
           return imageBase64; 
        }
      } else {
        print('Image Generation Failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Network Error while generating image: $e');
    }
    return null;
  }
}
