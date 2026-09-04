import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import '../entities/future_suggestion.dart';

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
    List<String>? avoidPlaces,
    List<String>? wishlist,
    List<String>? constraints,
    List<FutureSuggestion>? futureSuggestions,
    bool strictBudget = false,
  }) async {
    int numberOfDays = 1;
    try {
      final parts = dates.split(' - ');
      if (parts.length == 2) {
        final start = DateTime.parse(parts[0].trim());
        final end = DateTime.parse(parts[1].trim());
        numberOfDays = end.difference(start).inDays + 1;
      }
    } catch (_) {}

    final prompt =
        '''
    You are an expert travel planner. Please help me generate a travel itinerary in Malaysia.
    Details:
    - Destination: $destination
    - Dates: $dates (Total: $numberOfDays days)
    - Budget: \$$budget
    ${preference != null ? '- Preference: $preference (You MUST heavily prioritize planning activities that strictly match this theme!)' : ''}
    ${(constraints != null && constraints.isNotEmpty) ? '- Personal Constraints: ' + constraints.join(', ') + ' (You MUST strictly follow these constraints when suggesting places, e.g., food restrictions or accessibility!)' : ''}
    ${(futureSuggestions != null && futureSuggestions.isNotEmpty) ? '- Budget Distribution: ' + futureSuggestions.map((e) => '${e.activityCategory}: ${e.suggestedAmount}%').join(', ') + ' (You MUST strictly allocate the provided Budget according to these category percentages!)' : ''}
    ${(wishlist != null && wishlist.isNotEmpty) ? '- Wishlist Items: ' + wishlist.join(', ') + (strictBudget ? '\n    CRITICAL RULE FOR WISHLIST (BUDGET-CONSTRAINED MODE):\n    - Try to INCLUDE these wishlist items in the itinerary IF they fit within the Budget (\$$budget).\n    - You MUST adjust other activities (use cheaper restaurants, free attractions, walking instead of transport) to make room for wishlist items.\n    - If a wishlist item genuinely cannot fit even after adjustments, you may exclude it.\n    - Return the actual number of wishlist items successfully included in "wishlistItemsCoveredCount".\n    - "estimatedExtraBudgetNeeded" MUST be 0.0 since the plan MUST fit within \$$budget.' : '\n    CRITICAL RULE FOR WISHLIST:\n    - You MUST ALWAYS INCLUDE ALL of these wishlist items in the generated itinerary, NO MATTER how low or insufficient the Budget (\$$budget) is! NEVER exclude them.\n    - Because you forcefully included them with their TRUE realistic prices, the total cost will likely exceed a low budget. You MUST add this excess to "estimatedExtraBudgetNeeded".\n    - IF the realistic total cost exceeds the Budget (\$$budget), you MUST artificially return "wishlistItemsCoveredCount" as 0 (to flag to the system that the user cannot afford them yet). NEVER return the full count if budget is exceeded! \n    - ONLY if the Budget (\$$budget) is fully sufficient to cover everything without shortfall, return the full number of wishlist items mapped in "wishlistItemsCoveredCount".') : ''}

    Please provide a structured day-by-day itinerary with estimated costs and durations for each activity.
    ${strictBudget ? '''
    CRITICAL RULE FOR BUDGET & PRICING (STRICT BUDGET MODE):
    - The user has a HARD budget limit of \$$budget. The sum of ALL allocatedBudget values MUST be LESS THAN OR EQUAL TO \$$budget. This is NON-NEGOTIABLE.
    - You MUST fit the entire itinerary within \$$budget by choosing AFFORDABLE options: hawker centres instead of fine dining, free parks instead of paid attractions, walking or public transit instead of Grab.
    - "totalAllocatedBudget" MUST be <= \$$budget.
    - "estimatedExtraBudgetNeeded" MUST be 0.0.
    - Public parks, sightseeing of landmarks, walking tours, and free attractions MUST have an allocatedBudget of 0.
    - "Transportation" activities MUST have a realistic but minimal allocatedBudget (e.g., MRT/LRT tickets RM2-5).
    - Only assign costs to food/dining, transportation, and places that explicitly require entrance tickets.
    ''' : '''
    CRITICAL RULE FOR BUDGET & PRICING: 
    - The user provided a target budget of \$$budget. 
    - You MUST assign TRUE, REALISTIC market-rate costs for EVERY activity's "allocatedBudget" (e.g., meals cost RM15-40, transport RM5-30). 
    - NEVER invent fake RM0.0, RM0.5, or insanely low prices for restaurants or paid attractions just to blindly fit into an impossibly low budget.
    - If the \$$budget is extremely low (like RM1 or RM10), YOU MUST STILL USE REALISTIC PRICES. If assigning realistic prices causes the itinerary's total cost to heavily exceed the \$$budget, THAT IS PERFECTLY FINE. 
    - You MUST calculate the exact shortfall (Sum of ALL realistic allocatedBudgets - \$$budget) and return this positive shortfall amount in "estimatedExtraBudgetNeeded".
    - If the \$$budget is sufficient, distribute it fairly but DO NOT artificially inflate prices beyond realistic maximums.
    - "totalAllocatedBudget" MUST ALWAYS perfectly match the mathematical sum of all "allocatedBudget" fields in the activities list. (It is completely fine if this total sum exceeds the \$$budget).
    - Public parks, sightseeing of landmarks, walking tours, and free attractions MUST have an allocatedBudget of 0.
    - "Transportation" activities MUST ALWAYS have a realistic allocatedBudget greater than 0 (e.g., Grab fare, MRT tickets). NEVER assign 0 to Transportation!
    - Only assign costs to food/dining, transportation, and places that explicitly require entrance tickets.
    '''}
    
    CRITICAL RULE FOR ROUTING:
    - Group activities geographically! Each day of the itinerary MUST focus on ONE specific area or neighborhood (e.g., Day 1 is dedicated entirely to "KLCC", Day 2 entirely to "Bukit Bintang").
    - Do NOT jump across the city on the same day. Every single activity on a given "dayNumber" MUST be found within that day's designated area to minimize travel time.
    - Consecutive activities MUST be close to each other in real life to make routing practical.

    CRITICAL RULE FOR TIME SCHEDULING:
    - THIS IS THE MOST IMPORTANT RULE: You MUST generate an itinerary exactly for $numberOfDays day(s). If $numberOfDays is 3, return exactly 3 days. If $numberOfDays is 4, return exactly 4 days. The number of days returned MUST strictly match $numberOfDays!
    - The "dayNumber" MUST go sequentially from 1 up to exactly $numberOfDays. DO NOT generate less or more days than $numberOfDays!
    - EVERY single day of the itinerary MUST strictly start at exactly 09:00 and the FINAL activity MUST end at exactly 21:00.
    - You MUST provide between 6 to 8 activities per day to completely fill the 12-hour span from 09:00 to 21:00.
    - Do not schedule any activities before 09:00 or after 21:00. 
    - The first activity of EACH day MUST have a startTime of "09:00". 
    - The absolute last activity of EACH day MUST have an endTime of "21:00". THIS IS MANDATORY. Do NOT end the day at 18:00, 19:00, or 20:00. If your last activity ends before 21:00, YOU TRIPLE CHECK AND ADD A NEW SUPPER/NIGHT MARKET ACTIVITY TO REACH EXACTLY 21:00.

    CRITICAL RULE FOR COMPOSITION:
    - EVERY day MUST include at least THREE "Restaurant" category activities (strictly representing Breakfast, Lunch, and Dinner).
    - EVERY day MUST include at least ONE "Transportation" category activity representing the journey/commute. For "Transportation", the "destination" MUST be the exact name of the physical station or arrival landmark (e.g. "KL Sentral", "Bukit Bintang MRT Stage", NOT vague terms like "Grab", "Taxi" or "Walking").

    CRITICAL RULE FOR DESTINATIONS/RESTAURANTS:
    - Every destination, restaurant, cafe, or eatery MUST be specified using its full, real-world, specific business or place name.
    - Do NOT generate generic dish or food names (such as "Nasi Lemak", "Teh Tarik", "Roti Canai", "Satay") as the destination. You must specify the actual restaurant name where it can be eaten (e.g., "Village Park Restaurant", "Nasi Lemak Antarabangsa").
    - Every "destination" value MUST be an actual, currently operating, highly popular business or landmark that is guaranteed to have a listing and photos on Google Maps. Do NOT invent fictional place names.
    - We will programmatically verify each destination against Google Places API to fetch its image. If a destination is obscure or NOT found on Google Places, the itinerary is invalid.
    
    CRITICAL RULE FOR UNIQUENESS (NO DUPLICATES):
    - EVERY single destination and activity across the ENTIRE itinerary MUST be strictly UNIQUE. 
    - Do NOT propose the same restaurant, attraction, or landmark more than once across all the days. If a place is visited on Day 1, it CANNOT be visited again on any other day.
    ${(avoidPlaces != null && avoidPlaces.isNotEmpty) ? '\nCRITICAL REJECTION LIST FOR RETRY:\nThe following places were previously generated in a prior attempt but COULD NOT be found on Google Places API. You MUST NOT include any of these in your response. Instead, suggest different, verified, operating real-world venues/landmarks that are definitely searchable on Google Places:\n' + avoidPlaces.map((e) => '- "$e"').join('\n') : ''}
    
    Format your response STRICTLY as the following JSON object structure. Do NOT include markdown fences (no ```json ... ```), and do NOT include any extra text:
    
    {
      "totalAllocatedBudget": 200.0,
      "wishlistItemsCoveredCount": 1,
      "estimatedExtraBudgetNeeded": 0.0,
      "activities": [
        {
          "dayNumber": 1,
          "destination": "Actual Google Maps Business/Landmark Name",
          "imageKeyword": "Petronas Towers",
          "description": "Short description of the activity",
          "allocatedBudget": 50.0,
          "duration": "60-90 min",
          "activityCategory": "Attraction",
          "startTime": "09:00",
          "endTime": "11:00",
          "minPrice": 20.0 
        }
      ]
    }

    Field definitions:
    - totalAllocatedBudget (double): The sum of all allocatedBudget.
    - wishlistItemsCoveredCount (int): Number of user-provided wishlist items covered.
    - estimatedExtraBudgetNeeded (double): If the true realistic cost of the itinerary + wishlist items exceeds the \$$budget, return the shortfall amount here. Return 0.0 ONLY if \$$budget is genuinely sufficient.
    - dayNumber (int): Sequential day (1 for Day 1, 2 for Day 2...).
    - destination (String): EXACT, FULL official business name or landmark on Google Maps. No generic names.
    - imageKeyword (String): Landmark name or generic food type (e.g. "Nasi Lemak" instead of restaurant name).
    - allocatedBudget (double): Max estimated cost or fixed price. 0.0 for free.
    - duration (String): e.g., "60-90 min".
    - activityCategory (String): MUST be "Transportation", "Attraction", or "Restaurant".
    - startTime/endTime (String): 24-hour format "HH:mm".
    - minPrice (double): Min estimated cost. Set to 0.0 or null if free/fixed.
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
    - "Transportation" activities MUST ALWAYS have a realistic allocatedBudget greater than 0. Do NEVER assign 0 to Transportation.
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

  // weisong
  // budget recovery point and change remaining activities
  static Future<List<Map<String, dynamic>>> generateRecoveryItinerary({
    required double effectiveRemainingBudget,
    required double currentSpentBudget,
    required double topUpAmount,
    required List<Map<String, dynamic>> remainingActivities,
    required String tripDestination,
    String? userCoordinates,
    DateTime? currentDate,
  }) async {

    final locationConstraint = userCoordinates != null
        ? 'Current GPS Coordinates: $userCoordinates (within $tripDestination)'
        : 'Destination: $tripDestination';
    final prompt =
        '''
    You are an AI travel itinerary and budget optimizer.
    A tourist has hit a critical budget threshold and needs a revised schedule for their remaining trip.

    Trip Constraints:
    - Destination: $tripDestination
    - Current Date/Time: ${currentDate?.toIso8601String() ?? DateTime.now().toIso8601String()}
    - Total Spent So Far: RM ${currentSpentBudget.toStringAsFixed(2)}
    - Added Top-Up: RM ${topUpAmount.toStringAsFixed(2)}
    - Max Usable Budget for Remaining Plan: RM ${effectiveRemainingBudget.toStringAsFixed(2)}

    Remaining Activities Before Re-planning:
    ${jsonEncode(remainingActivities)}

    Instructions:
    1. Minimise Transit Time & Costs: Prioritize activities, cultural sights, free parks, or food spots that are within easy walking distance or a short, cheap public transit ride from the tourist's current location ($locationConstraint). Strictly avoid destinations requiring expensive taxi, Grab, or long-distance travel.
    2. Budget Compliance: The sum of allocatedBudget for all returned items MUST NOT exceed RM ${effectiveRemainingBudget.toStringAsFixed(2)}.
    3. Slot Continuity: Preserve the original "activitiesId" for modified or replaced slots so database references remain valid.
    4. Logical Sequence: Organize startTime and endTime chronologically from the current time forward.
    5. Return ONLY a valid JSON array matching the schema below.

    JSON Schema:
    [
      {
        "activitiesId": "keep original ID if retained, or generate a new unique string if replaced",
        "destination": "Activity / Place Name",
        "description": "Short explanation highlighting walkability/affordability",
        "date": "YYYY-MM-DDTHH:mm:ss",
        "startTime": "HH:mm",
        "endTime": "HH:mm",
        "allocatedBudget": 0.0,
        "activityImgUrl": "placeholder or original URL"
      }
    ]
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
        // ).timeout(
        //   const Duration(seconds: 25),
        //   onTimeout: () {
        //     throw TimeoutException("Gemini API request timed out after 25 seconds. Please Try Again.");
        //   }
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final rawText = parts[0]['text'] as String?;
            if (rawText != null && rawText.isNotEmpty) {
              final decoded = jsonDecode(rawText);
              if (decoded is List) {
                return List<Map<String, dynamic>>.from(decoded);
              }
            }
          }
        }
        return [];
      } else {
        throw Exception(
          'Gemini Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error generating recovery itinerary: $e');
      rethrow;
    }
  }
}
