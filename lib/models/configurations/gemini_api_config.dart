import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

class GeminiApiRequestException implements Exception {
  final int statusCode;

  const GeminiApiRequestException(this.statusCode);

  @override
  String toString() => 'Gemini API returned status $statusCode.';
}

class GeminiApiConfig {
  // Gemini API Key
  static const String _apiKey =
      'AQ.Ab8RN6I-KX5slDyylnwRrTQFkIUvjmTEs6CB2309RUmE3NS39w';

  static late final GenerativeModel _model;

  static void initialize() {
    _model = GenerativeModel(model: 'gemini-3.5-flash-lite', apiKey: _apiKey);
  }

  // kokhong
  static Future<String> askGeminiForItinerary({
    required String destination,
    required String dates,
    required String budget,
    String? preference,
    String? emergencyFund,
    List<String>? avoidPlaces,
    List<String>? wishlist,
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
    ${(wishlist != null && wishlist.isNotEmpty) ? '- Wishlist Items to try to cover: ' + wishlist.join(', ') : ''}

    Please provide a structured day-by-day itinerary with estimated costs and durations for each activity.
    CRITICAL RULE FOR BUDGET: 
    - Assign realistic cost for "allocatedBudget". 
    - Public parks, sightseeing of landmarks, walking tours, and free attractions MUST have an allocatedBudget of 0.
    - Only assign costs to food/dining, transportation, and places that explicitly require entrance tickets.
    
    CRITICAL RULE FOR ROUTING:
    - Group activities geographically! Each day of the itinerary MUST focus on ONE specific area or neighborhood (e.g., Day 1 is dedicated entirely to "KLCC", Day 2 entirely to "Bukit Bintang").
    - Do NOT jump across the city on the same day. Every single activity on a given "dayNumber" MUST be found within that day's designated area to minimize travel time.
    - Consecutive activities MUST be close to each other in real life to make routing practical.

    CRITICAL RULE FOR DESTINATIONS/RESTAURANTS:
    - Every destination, restaurant, cafe, or eatery MUST be specified using its full, real-world, specific business or place name.
    - Do NOT generate generic dish or food names (such as "Nasi Lemak", "Teh Tarik", "Roti Canai", "Satay") as the destination. You must specify the actual restaurant name where it can be eaten (e.g., "Village Park Restaurant", "Nasi Lemak Antarabangsa").
    - Every "destination" value MUST be an actual, currently operating business or landmark that returns results when searched on Google Places API / Google Maps. Do NOT invent fictional place names.
    - We will programmatically verify each destination against Google Places API. If a destination is NOT found on Google Places, the itinerary is invalid.
    ${(avoidPlaces != null && avoidPlaces.isNotEmpty) ? '\nCRITICAL REJECTION LIST FOR RETRY:\nThe following places were previously generated in a prior attempt but COULD NOT be found on Google Places API. You MUST NOT include any of these in your response. Instead, suggest different, verified, operating real-world venues/landmarks that are definitely searchable on Google Places:\n' + avoidPlaces.map((e) => '- "$e"').join('\n') : ''}
    
    Format your response as a valid JSON object with the following fields:
    - "totalAllocatedBudget": (double) The sum of the allocatedBudget of all activities in the itinerary.
    - "wishlistItemsCoveredCount": (int) The number of user-provided wishlist items that you were actually able to include/cover in this generated itinerary.
    - "estimatedExtraBudgetNeeded": (double) If some of the user-provided wishlist items could NOT be covered due to the budget limit, estimate how much extra budget (in RM) would be needed in total to cover the remaining/uncovered wishlist items. If all wishlist items are covered, return 0.0.
    - "activities": (Array of Objects) A day-by-day itinerary where each activity object has the following fields:
      - "dayNumber": (int) Based on the requested dates ("$dates"), distribute the itinerary across multiple days. Return 1 for Day 1, 2 for Day 2, etc. (e.g., if it's a 3-day trip, activities should have dayNumber 1, 2, or 3). The exact geographical neighborhood or area name for this day (e.g., "KLCC", "Bukit Bintang", "Batu Caves"). Do NOT invent catchy titles or add extra words.
      - "destination": (String) The EXACT, FULL official business name or landmark name as it appears on Google Maps. Examples of CORRECT values: "Village Park Restaurant", "Madam Kwan's KLCC", "Petronas Twin Towers", "Jalan Alor", "Lot 10 Hutong", "Din Tai Fung Pavilion KL". Examples of WRONG values: "Nasi Lemak Breakfast", "Local Coffee Shop", "Relaxation Spa", "Street Food Tour".
      - "imageKeyword": (String) IF it's a famous landmark, use its exact name (e.g. "Petronas Towers"). IF it's a specific restaurant/cafe, DO NOT use its name; instead, use the generic famous food/drink type (e.g. "Nasi Lemak", "Latte Art", "Seafood") so the generated image matches the activity context perfectly.
      - "description": (String) Short description
      - "allocatedBudget": (double) The maximum estimated cost or upper bound of the price range (e.g., if price is RM 15-35, allocatedBudget is 35.0). For free activities, set to 0.0.
      - "duration": (String) e.g., "60-90 min"
      - "activityCategory": (String) You MUST classify the activity into exactly one of these THREE categories ONLY: "Transportation", "Attraction", or "Restaurant". Do NOT use any other categories (e.g., NO "Food", NO "Culture").
      - "startTime": (String) e.g., "09:00"
      - "endTime": (String) e.g., "11:00"
      - "minPrice": (double, optional) The minimum estimated cost or lower bound of the price range (e.g., if price is RM 15-35, minPrice is 15.0). For free activities or fixed price activities, do not include or set to null.

    Return ONLY the JSON object, with no markdown formatting and no extra text.
    ''';

    int retries = 3;
    while (retries > 0) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=$_apiKey',
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

  // yan bin - cost-tips recommendation
  static Future<String> askGeminiForCostSavingTips({
    required String destination,
    required double allocatedBudget,
    required double totalExpense,
    required double remainingBudget,
    required Map<String, double> categoryExpenses,
  }) async {
    final categoryText = categoryExpenses.entries
        .map((entry) => '- ${entry.key}: RM ${entry.value.toStringAsFixed(2)}')
        .join('\n');
    final prompt =
        '''
    You are a practical travel budget assistant. Generate exactly THREE concise cost-saving tips for this completed trip.

    Trip Financial Data:
    - Destination: $destination
    - Total Allocated Budget: RM ${allocatedBudget.toStringAsFixed(2)}
    - Total Expense: RM ${totalExpense.toStringAsFixed(2)}
    - Remaining Budget: RM ${remainingBudget.toStringAsFixed(2)}
    - Expenses By Category:
    $categoryText

    CRITICAL RULES:
    - Base every tip only on the supplied financial data.
    - Focus first on the category with the highest expense.
    - Do NOT invent venue names, discount percentages, travel passes, prices, or facts.
    - Each title MUST contain 6 words or fewer.
    - Each description MUST contain 12 words or fewer.
    - "category" MUST be exactly one of: "Attraction", "Food", "Transport", or "General".
    - Return exactly 3 objects in the "tips" array.

    Format your response as this valid JSON object:
    {
      "tips": [
        {
          "category": "Transport",
          "title": "Short action title",
          "description": "Short practical explanation"
        }
      ]
    }

    Return ONLY the raw JSON object with no markdown formatting.
    ''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=$_apiKey',
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
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        final parts = content['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text'] ?? '{"tips":[]}';
        }
      }
      return '{"tips":[]}';
    } else {
      throw GeminiApiRequestException(response.statusCode);
    }
  }

  // yan bin - future budget recommendation
  static Future<String> askGeminiForFutureBudgetRecommendations({
    required String destination,
    required double allocatedBudget,
    required double totalExpense,
    required Map<String, double> categoryExpenses,
  }) async {
    final categoryText = categoryExpenses.entries
        .map((entry) => '- ${entry.key}: RM ${entry.value.toStringAsFixed(2)}')
        .join('\n');
    final prompt =
        '''
    You are a travel financial planning assistant. Recommend how this user should distribute a future trip budget across exactly THREE categories, based only on the completed trip data below.

    Completed Trip Financial Data:
    - Destination: $destination
    - Total Allocated Budget: RM ${allocatedBudget.toStringAsFixed(2)}
    - Total Expense: RM ${totalExpense.toStringAsFixed(2)}
    - Expenses By Category:
    $categoryText

    CRITICAL RULES:
    - Return exactly one recommendation for each category: "Attraction", "Transport", and "Food".
    - "percentage" MUST be a whole number from 0 to 100.
    - The three percentages MUST add up to exactly 100.
    - Recommend a practical future allocation using the completed trip's spending pattern.
    - Do NOT return currency amounts, explanations, extra categories, or additional fields.

    Format your response as this valid JSON object:
    {
      "recommendations": [
        {"category": "Attraction", "percentage": 30},
        {"category": "Transport", "percentage": 15},
        {"category": "Food", "percentage": 55}
      ]
    }

    Return ONLY the raw JSON object with no markdown formatting.
    ''';

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
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        final parts = content['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text'] ?? '{"recommendations":[]}';
        }
      }
      return '{"recommendations":[]}';
    } else {
      throw GeminiApiRequestException(response.statusCode);
    }
  }

  // kok hong
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

  // wei song
  // TODO: another function to generate alternative for removed activity
  static Future<String> askGeminiForAlternative({
    required String destinationCity,
    required String targetAreaOrNeighborhood,
    required String category,
    required String startTime,
    required String endTime,
    required double budgetLimit,
    required int dayNumber,
    required List<String> existingOrExcludedPlaces,
  }) async {
    final excludedListText = existingOrExcludedPlaces.isNotEmpty
        ? existingOrExcludedPlaces.map((e) => '- "$e"').join('\n')
        : 'None';

    final prompt =
        '''
    You are an expert travel planner in Malaysia. A user removed an activity from their Day $dayNumber itinerary in $destinationCity and needs ONE replacement activity to fill the empty time slot.

    Parameters:
    - City: $destinationCity
    - Target Area / Neighborhood: $targetAreaOrNeighborhood (Must be located nearby this neighborhood to minimize travel time)
    - Preferred Category: ${category.isNotEmpty ? category : "Attraction or Restaurant"}
    - Time Slot: $startTime to $endTime
    - Budget Ceiling: RM ${budgetLimit.toStringAsFixed(2)}

    CRITICAL EXCLUSION LIST (DUPLICATES PROHIBITED):
    The user already has the following places in their itinerary or explicitly rejected them. You MUST NOT suggest any of these places or slight variations of them:
    $excludedListText

    CRITICAL RULES FOR DESTINATION & BUDGET:
    - The destination MUST be an EXACT, FULL official business name or landmark on Google Maps (e.g., "Museum of Illusions Kuala Lumpur", "Limapulo: Baba Can Cook"). Do NOT use generic names (e.g., "Local Cafe", "Museum Visit").
    - Public parks, sightseeing of landmarks, walking tours, and free attractions MUST have an "allocatedBudget" of 0.
    - Only assign costs to food/dining, transportation, and places that explicitly require entrance tickets.
    - "activityCategory" MUST strictly be one of: "Transportation", "Attraction", or "Restaurant".

    Format your response as a valid single JSON object with the following fields:
    {
      "dayNumber": $dayNumber,
      "destination": "Exact Business Name or Landmark",
      "imageKeyword": "Famous landmark name or generic food item (e.g. 'Nasi Lemak', 'Aquarium')",
      "description": "Short 1-2 sentence description",
      "allocatedBudget": 0.0, // Representing the MAX price if there is a price range
      "minPrice": 0.0, // Representing the MIN price if range, else null
      "duration": "60-90 min",
      "activityCategory": "Attraction",
      "startTime": "$startTime",
      "endTime": "$endTime"
    }

    Return ONLY the raw JSON object with no markdown fences, no backticks, and no extra commentary.
    ''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$_apiKey',
    );

    try {
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
            return parts[0]['text'] ?? '{}';
          }
        }
        return '{}';
      } else {
        throw Exception(
          'Gemini Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Gemini API Alternative Error: $e');
      throw Exception('Failed to generate alternative activity: $e');
    }
  }
}
