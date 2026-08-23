import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiApiConfig {
  // Gemini API Key
  static const String _apiKey =
      'AQ.Ab8RN6I-KX5slDyylnwRrTQFkIUvjmTEs6CB2309RUmE3NS39w';

  static late final GenerativeModel _model;

  static void initialize() {
    _model = GenerativeModel(model: 'gemini-3.6-flash', apiKey: _apiKey);
  }

  /// Ask Gemini for itinerary
  static Future<String> askGeminiForItinerary({
    required String destination,
    required String dates,
    required String budget,
    String? preference,
    String? emergencyFund,
  }) async {
    final prompt =
        '''
    You are an expert travel planner. Please help me generate a travel itinerary in Malaysia.
    Details:
    - Destination: $destination
    - Dates: $dates
    - Budget: \$$budget
    ${preference != null ? '- Preference: $preference' : ''}
    ${emergencyFund != null ? '- Emergency Fund: $emergencyFund' : ''}

    Please provide a structured day-by-day itinerary with estimated costs and durations for each activity.
    CRITICAL RULE FOR BUDGET: 
    - Assign realistic cost for "allocatedBudget". 
    - Public parks, sightseeing of landmarks, walking tours, and free attractions MUST have an allocatedBudget of 0.
    - Only assign costs to food/dining, transportation, and places that explicitly require entrance tickets.
    
    CRITICAL RULE FOR ROUTING:
    - Group activities geographically! Each day of the itinerary MUST focus on ONE specific area or neighborhood (e.g., Day 1 is dedicated entirely to "KLCC", Day 2 entirely to "Bukit Bintang").
    - Do NOT jump across the city on the same day. Every single activity on a given "dayNumber" MUST be found within that day's designated area to minimize travel time.
    - Consecutive activities MUST be close to each other in real life to make routing practical.
    
    Format your response as a valid JSON array of activities, where each activity has the following fields:
    - "dayNumber": (int) Based on the requested dates ("$dates"), distribute the itinerary across multiple days. Return 1 for Day 1, 2 for Day 2, etc. (e.g., if it's a 3-day trip, activities should have dayNumber 1, 2, or 3). The exact geographical neighborhood or area name for this day (e.g., "KLCC", "Bukit Bintang", "Batu Caves"). Do NOT invent catchy titles or add extra words.
    - "destination": (String) Specify the EXACT full name of the place, restaurant, or landmark. Do NOT use generic terms like "Lunch".
    - "imageKeyword": (String) IF it's a famous landmark, use its exact name (e.g. "Petronas Towers"). IF it's a specific restaurant/cafe, DO NOT use its name; instead, use the generic famous food/drink type (e.g. "Nasi Lemak", "Latte Art", "Seafood") so the generated image matches the activity context perfectly.
    - "description": (String) Short description
    - "allocatedBudget": (double) Estimated cost
    - "duration": (String) e.g., "60-90 min"
    - "activityCategory": (String) You MUST classify the activity into exactly one of these THREE categories ONLY: "Transportation", "Attraction", or "Restaurant". Do NOT use any other categories (e.g., NO "Food", NO "Culture").
    - "startTime": (String) e.g., "09:00"
    - "endTime": (String) e.g., "11:00"

    Return ONLY the JSON array, with no markdown formatting and no extra text.
    ''';

    int retries = 3;
    while (retries > 0) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$_apiKey',
        );

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "contents": [
              {
                "parts": [
                  {"text": prompt},
                ],
              },
            ],
            "generationConfig": {"responseMimeType": "application/json"},
          }),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'];
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              return parts[0]['text'] ?? '';
            }
          }
          return 'Gemini returned an empty response.';
        } else if (response.statusCode == 503) {
          retries--;
          print('Server overloaded, retries left: $retries');
          if (retries == 0) {
            throw Exception(
              'API Error: 503 - Server overloaded, please try again later.',
            );
          }
          await Future.delayed(Duration(seconds: 3));
          continue;
        } else {
          throw Exception(
            'API Error: ${response.statusCode} - ${response.body}',
          );
        }
      } catch (e) {
        if (e.toString().contains('503') && retries > 0) {
          continue;
        }
        print('Gemini API Error: $e');
        throw Exception('Failed to generate itinerary. Error: $e');
      }
    }
    throw Exception('Failed to generate itinerary after retries.');
  }

  /// Returns a Base64 encoded image string (Bypassing Imagen with LoremFlickr)
  static Future<String?> generateLocationImage(String promptText) async {
    final keyword = Uri.encodeComponent(
      promptText.replaceAll(RegExp(r'\s+'), ','),
    );
    final url = Uri.parse('https://loremflickr.com/600/400/$keyword,travel');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return base64Encode(response.bodyBytes);
      } else {
        // Silent fall through
      }
    } catch (e) {
      // Silent fall through
    }
    return null;
  }

  // TODO: another function to generate alternative for removed activity
  static Future<String> askGeminiForAlternative({
    required String destinationCity,
    required String category,
    required String startTime,
    required String endTime,
    required List<String> excludedActivities,
  }) async{
    final excludedListText = excludedActivities.isNotEmpty ? excludedActivities.map((e) => '-$e').join('\n') : 'None';
    final prompt = '''
    You are a travel assistant in Malaysia. Suggest ONE replacement activity for a trip in $destinationCity.

    Parameters:
    - Category: ${category.isNotEmpty ? category : "Attraction or Restaurant"}
    - Time Window: $startTime to $endTime
    
    CRITICAL EXCLUSIONS:
    The user explicitly removed/visited these places. You MUST NOT suggest any of these places or direct variations of them:
    $excludedListText
    
    Format your response as a valid single JSON object:
    {
      "destination": "Name of Landmark or Venue",
      "description": "Short 1-2 sentence description",
      "imageUrl": "https://picsum.photos/600/400",
      "allocatedBudget": 0.0,
      "duration": "60 min",
      "activityCategory": "Attraction",
      "startTime": "$startTime",
      "endTime": "$endTime"
    }
    
    Return ONLY the raw JSON object with no markdown formatting.
    ''';

    final url = Uri.parse(
      ''
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [{"text": prompt}]
          }
        ],
        "generatingConfig": {"responseMimeType": "application/json"}
      })
    );

    if(response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '{}';
    } else{
      throw Exception('Gemini Error: ${response.statusCode}');
    }
  }
}
