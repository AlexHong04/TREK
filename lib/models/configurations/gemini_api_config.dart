import 'dart:async';
import 'dart:convert';
import 'package:Trek/models/configurations/google_places_api_config.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import '../entities/future_suggestion.dart';
import '../../view_models/ui_state/travel_information_ui_state.dart';

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
    List<TransitPoint>? arrivals,
    List<TransitPoint>? departures,
    List<HotelStay>? hotels,
    String? arrivalLocation,
    String? arrivalTime,
    String? departureLocation,
    String? departureTime,
    String? hotelLocation,
    String? hotelCheckInTime,
    String? hotelCheckOutTime,
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

    final List<TransitPoint> resolvedArrivals = [];
    if (arrivals != null && arrivals.isNotEmpty) {
      resolvedArrivals.addAll(
        arrivals.where((a) => a.location.trim().isNotEmpty),
      );
    } else if (arrivalLocation != null && arrivalLocation.trim().isNotEmpty) {
      resolvedArrivals.add(
        TransitPoint(
          id: 'arr_0',
          location: arrivalLocation,
          time: arrivalTime ?? '09:00 AM',
        ),
      );
    }

    final List<TransitPoint> resolvedDepartures = [];
    if (departures != null && departures.isNotEmpty) {
      resolvedDepartures.addAll(
        departures.where((d) => d.location.trim().isNotEmpty),
      );
    } else if (departureLocation != null &&
        departureLocation.trim().isNotEmpty) {
      resolvedDepartures.add(
        TransitPoint(
          id: 'dep_0',
          location: departureLocation,
          time: departureTime ?? '06:00 PM',
        ),
      );
    }

    final List<HotelStay> resolvedHotels = [];
    if (hotels != null && hotels.isNotEmpty) {
      resolvedHotels.addAll(hotels.where((h) => h.location.trim().isNotEmpty));
    } else if (hotelLocation != null && hotelLocation.trim().isNotEmpty) {
      resolvedHotels.add(
        HotelStay(
          id: 'hotel_0',
          location: hotelLocation,
          checkInTime: hotelCheckInTime ?? '03:00 PM',
          checkOutTime: hotelCheckOutTime ?? '12:00 PM',
        ),
      );
    }

    final prompt =
        '''
    You are an expert travel planner. Please help me generate a travel itinerary in Malaysia.
    Details:
    - Destination: $destination
    - Dates: $dates (Total: $numberOfDays days)
    - Budget: \$$budget
    ${preference != null ? '- Preference: $preference (You MUST heavily prioritize planning activities that strictly match this theme!)' : ''}
    ${resolvedArrivals.isNotEmpty ? '''- Arrival Details:
${resolvedArrivals.asMap().entries.map((e) => '      * Arrival ${e.key + 1}: ${e.value.location} at ${e.value.time}').join('\n')}
      * CRITICAL FOR DAY 1: Day 1 activities MUST start after the initial arrival time (${resolvedArrivals.first.time}) at "${resolvedArrivals.first.location}". Route connecting activities accordingly!''' : ''}
    ${resolvedDepartures.isNotEmpty ? '''- Departure Details:
${resolvedDepartures.asMap().entries.map((e) => '      * Departure ${e.key + 1}: ${e.value.location} at ${e.value.time}').join('\n')}
      * CRITICAL FOR FINAL DAY: Final day schedule MUST finish in time for the traveler to reach "${resolvedDepartures.last.location}" before ${resolvedDepartures.last.time}!''' : ''}
    ${resolvedHotels.isNotEmpty ? '''- Accommodation / Hotel:
${resolvedHotels.asMap().entries.map((e) => '      * Hotel ${e.key + 1}: ${e.value.location} (Check-in: ${e.value.checkInTime}, Check-out: ${e.value.checkOutTime})').join('\n')}
      * CRITICAL FOR HOTEL: Daily activities should conveniently route to/from this accommodation area. Factor in hotel check-in on Day 1 (around ${resolvedHotels.first.checkInTime}) and check-out on the final day (around ${resolvedHotels.last.checkOutTime}).''' : ''}
    ${(constraints != null && constraints.isNotEmpty) ? '- Personal Constraints: ' + constraints.join(', ') + ' (You MUST strictly follow these constraints when suggesting places, e.g., food restrictions or accessibility!)' : ''}
    ${(futureSuggestions != null && futureSuggestions.isNotEmpty) ? '- Budget Distribution: ' + futureSuggestions.map((e) => '${e.activityCategory}: ${e.suggestedAmount}%').join(', ') + ' (You MUST strictly allocate the provided Budget according to these category percentages!)' : ''}
    ${(wishlist != null && wishlist.isNotEmpty) ? '- Wishlist Items: ' + wishlist.join(', ') + (strictBudget ? '''
    CRITICAL RULE FOR WISHLIST (TOP-UP ALTERNATIVE RE-RECOMMENDATION MODE):
    - The user has topped up their budget specifically so that ALL wishlist items MUST be covered.
    - MANDATORY: You MUST INCLUDE EVERY SINGLE ONE of these wishlist items in the generated itinerary: ${wishlist.join(', ')}.
    - NEVER omit or exclude ANY of these wishlist items under any circumstances! Every single wishlist item MUST appear as a scheduled activity in the itinerary under its actual place name.
    - To fit the entire plan within the updated Budget (\$$budget), aggressively economize on all other activities:
      * Choose affordable local eateries/hawker stalls (e.g. MYR 5-15) for ordinary meals.
      * Choose free public attractions, parks, or walking tours for other non-wishlist slots.
      * Keep transport minimal or walking (MYR 0.0).
    - "wishlistItemsCoveredCount" MUST BE EXACTLY ${wishlist.length} (since 100% of the wishlist items are included).
    - "estimatedExtraBudgetNeeded" MUST be 0.0 since the plan MUST fit within \$$budget.
    ''' : '''
    CRITICAL RULE FOR WISHLIST:
    - You MUST ALWAYS INCLUDE ALL of these wishlist items in the generated itinerary, NO MATTER how low or insufficient the Budget (\$$budget) is! NEVER exclude them.
    - Because you forcefully included them with their TRUE realistic prices, the total cost will likely exceed a low budget. You MUST add this excess to "estimatedExtraBudgetNeeded".
    - For "wishlistItemsCoveredCount", calculate how many wishlist items can realistically be covered by the user's Budget (\$$budget) after prioritizing basic daily meals and transport:
      * If the Budget (\$$budget) cannot even cover basic meals and transport, or cannot afford any wishlist item at all, return 0 in "wishlistItemsCoveredCount".
      * If the Budget (\$$budget) can cover basic meals and transport plus SOME of the wishlist items (e.g. 1, 2, or more, but not all), return the exact count of wishlist items that fit in "wishlistItemsCoveredCount".
      * Only if the Budget (\$$budget) is fully sufficient to cover all activities and all wishlist items without any shortfall, return the total count of all wishlist items in "wishlistItemsCoveredCount".
    ''') : '- Wishlist Items: None\n    CRITICAL RULE FOR NO WISHLIST:\n    - The user did NOT provide any wishlist items.\n    - "wishlistItemsCoveredCount" MUST BE EXACTLY 0. Do NOT count general attractions, restaurants, or itinerary activities as wishlist items!'}
    // ${(wishlist != null && wishlist.isNotEmpty) ? '- Wishlist Items: ' + wishlist.join(', ') + '''
    // RULE FOR WISHLIST:
    // - Include as many of these wishlist items as can realistically fit into the user's schedule and Budget (\$$budget).
    // - If the budget or schedule cannot accommodate all wishlist items, include the ones that fit best and omit the rest. Wishlist items do NOT all need to be covered.
    // - Set "wishlistItemsCoveredCount" to the number of wishlist items actually included in the schedule.
    // - If none fit within the budget, "wishlistItemsCoveredCount" is 0.
    // ''' : '- Wishlist Items: None\n    CRITICAL RULE FOR NO WISHLIST:\n    - The user did NOT provide any wishlist items.\n    - "wishlistItemsCoveredCount" MUST BE EXACTLY 0. Do NOT count general attractions, restaurants, or itinerary activities as wishlist items!'}

    Please provide a structured day-by-day itinerary with estimated costs and durations for each activity.
    ${strictBudget ? '''
    CRITICAL RULE FOR BUDGET & PRICING (STRICT BUDGET MODE):
    - The user has a HARD budget limit of \$$budget. The sum of ALL allocatedBudget values MUST be LESS THAN OR EQUAL TO \$$budget. This is NON-NEGOTIABLE.
    - You MUST fit the entire itinerary within \$$budget by choosing AFFORDABLE options: hawker centres instead of fine dining, free parks instead of paid attractions, walking or public transit instead of Grab.
    - "totalAllocatedBudget" MUST be <= \$$budget.
    - "estimatedExtraBudgetNeeded" MUST be 0.0.
    - Public parks, sightseeing of landmarks, walking tours, and free attractions MUST have an allocatedBudget of 0.
    - "Transportation" activities: If consecutive activities are close (walking distance), set "allocatedBudget" to 0.0 (Walking). Only assign minimal transit fare (RM2-5) if they are far.
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
    - "Transportation" pricing rule:
      * If consecutive activities are CLOSE to each other (walking distance, e.g. within ~1km or in the same complex/neighborhood), transit is by WALKING and "allocatedBudget" MUST be 0.0.
      * If activities are FAR (different areas or > 1km requiring public transit, LRT, MRT, Monorail, or Grab), "allocatedBudget" MUST have a realistic transit fare greater than 0 (e.g., MYR 2.00 - MYR 15.00).
    - Only assign costs to food/dining, transportation, and places that explicitly require entrance tickets.
    '''}
    
    CRITICAL RULE FOR ROUTING:
    - Group activities geographically! Each day of the itinerary MUST focus on ONE specific area or neighborhood (e.g., Day 1 is dedicated entirely to "KLCC", Day 2 entirely to "Bukit Bintang").
    - Do NOT jump across the city on the same day. Every single activity on a given "dayNumber" MUST be found within that day's designated area to minimize travel time.
    - Consecutive activities MUST be close to each other in real life to make routing practical.

    CRITICAL RULE FOR TIME SCHEDULING:
    - THIS IS THE MOST IMPORTANT RULE: You MUST generate an itinerary exactly for $numberOfDays day(s). If $numberOfDays is 3, return exactly 3 days. If $numberOfDays is 4, return exactly 4 days. The number of days returned MUST strictly match $numberOfDays!
    - The "dayNumber" MUST go sequentially from 1 up to exactly $numberOfDays. DO NOT generate less or more days than $numberOfDays!
    - Daily schedule timing:
      * Day 1 starts at ${resolvedArrivals.isNotEmpty ? resolvedArrivals.first.time : '09:00'} (accommodating traveler arrival).
      * The final day ends at ${resolvedDepartures.isNotEmpty ? resolvedDepartures.last.time : '21:00'} (accommodating traveler departure).
      * All intermediate days strictly start at 09:00 and end at 21:00.
      * Provide a complete continuous schedule filling the active hours, with connecting transportation between destinations.
    - The endTime of each activity must smoothly connect to the startTime of the next activity without large gaps.
    - Do not schedule any activities before 09:00 or after 21:00. 
    - The absolute last activity of EACH day MUST reach the end time specified (or 21:00). If your last activity ends before this time, YOU TRIPLE CHECK AND ADD A NEW SUPPER/NIGHT MARKET ACTIVITY TO REACH THE REQUIRED END TIME.

    CRITICAL RULE FOR COMPOSITION & TRANSPORTATION:
    - EVERY day MUST include at least THREE "Restaurant" category activities (strictly representing Breakfast, Lunch, and Dinner).
    - MANDATORY TRANSPORTATION BETWEEN ACTIVITIES (WALK IF CLOSE, VEHICLE IF FAR):
      * Between consecutive destination activities (Attractions and Restaurants), there MUST be a dedicated "Transportation" category activity representing the commute or walk between them.
      * PROXIMITY & TRANSIT MODE RULE:
        - If two consecutive activities are CLOSE to each other (within walking distance, e.g. < 1km, adjacent streets, or within the same mall/complex like Pavilion KL to Lot 10, or Suria KLCC to KLCC Park):
          + Transit mode is WALKING: set "destination" to "Walk to [Next Destination]" or "Pedestrian Walkway", "description" to "Short 5-10 min walk to the next venue", "duration" to "5-15 min", and "allocatedBudget" to 0.0 (Walking is completely free!).
        - If two consecutive activities are FAR from each other (requiring motorized transit, different neighborhoods, or > 1km):
          + Transit mode is VEHICULAR (MRT, LRT, Bus, or Grab): set "destination" to the station, terminal, or transit route (e.g. "KLCC LRT Station", "Bukit Bintang MRT Station"), "description" to describe the transit route (e.g. "Take MRT Kajang Line / Grab ride to destination"), "duration" to "15-30 min", and "allocatedBudget" to a realistic fare greater than 0 (e.g. MYR 3.00 - MYR 15.00).
      * "activityCategory" for all of these transfer activities MUST strictly be "Transportation".

    CRITICAL RULE FOR DESTINATIONS/RESTAURANTS:
    - Every destination, restaurant, cafe, or eatery MUST be specified using its full, real-world, specific business or place name.
    - Do NOT generate generic dish or food names (such as "Nasi Lemak", "Teh Tarik", "Roti Canai", "Satay") as the destination. You must specify the actual restaurant name where it can be eaten (e.g., "Village Park Restaurant", "Nasi Lemak Antarabangsa").
    - Every "destination" value MUST be an actual, currently operating, highly popular business or landmark that is guaranteed to have a listing and photos on Google Maps. Do NOT invent fictional place names.
    - We will programmatically verify each destination against Google Places API to fetch its image. If a destination is obscure or NOT found on Google Places, the itinerary is invalid.
    
    CRITICAL RULE FOR UNIQUENESS (NO DUPLICATES EXCEPT TRANSPORTATION):
    - EXCEPT for activities with "activityCategory": "Transportation", EVERY single destination, attraction, restaurant, cafe, shop, and landmark across the ENTIRE multi-day itinerary MUST be strictly and 100% UNIQUE.
    - ZERO REPEATED PLACES:
      * Do NOT propose the same restaurant, cafe, or eatery more than once across all days. Every breakfast, lunch, and dinner must be at a completely different venue!
      * Do NOT propose the same attraction, museum, theme park, or landmark more than once across all days. If a place is visited on Day 1, it CANNOT be visited again on Day 2, Day 3, or any other day.
      * Do NOT visit the same shopping mall, market, or complex multiple times (e.g. do NOT schedule lunch at a mall and then shopping at the same mall, and do NOT revisit it on another day).
      * Do NOT use slight variations of the same name to bypass this rule (e.g., "Petronas Twin Towers" and "Petronas Towers", or "Pavilion KL" and "Pavilion Kuala Lumpur" are the same venue and MUST NOT both appear).
    - TRANSPORTATION IS THE ONLY EXCEPTION:
      * Only commute activities with "activityCategory": "Transportation" (e.g., "Walk to ...", "Take MRT from ... to ...") can be repeated between destinations. All other activities must be distinct.
    ${(avoidPlaces != null && avoidPlaces.isNotEmpty) ? '\nCRITICAL REJECTION LIST FOR RETRY:\nThe following places were previously generated in a prior attempt but COULD NOT be found on Google Places API. You MUST NOT include any of these in your response. Instead, suggest different, verified, operating real-world venues/landmarks that are definitely searchable on Google Places:\n' + avoidPlaces.map((e) => '- "$e"').join('\n') : ''}
    
    Format your response STRICTLY as the following JSON object structure. Do NOT include markdown fences (no ```json ... ```), and do NOT include any extra text:
    
    {
      "totalAllocatedBudget": 200.0,
      "wishlistItemsCoveredCount": ${(wishlist != null && wishlist.isNotEmpty) ? (strictBudget ? wishlist.length : 1) : 0},
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
    - wishlistItemsCoveredCount (int): Number of user-provided wishlist items covered. If no wishlist items were provided by the user, this MUST BE EXACTLY 0.
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
        .map((entry) => '- ${entry.key}: MYR ${entry.value.toStringAsFixed(2)}')
        .join('\n');
    final prompt =
        '''
    You are a practical travel budget assistant. Generate exactly THREE concise cost-saving tips for this completed trip.

    Trip Financial Data:
    - Destination: $destination
    - Total Allocated Budget: MYR ${allocatedBudget.toStringAsFixed(2)}
    - Total Expense: MYR ${totalExpense.toStringAsFixed(2)}
    - Remaining Budget: MYR ${remainingBudget.toStringAsFixed(2)}
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
        .map((entry) => '- ${entry.key}: MYR ${entry.value.toStringAsFixed(2)}')
        .join('\n');
    final prompt =
        '''
    You are a travel financial planning assistant. Recommend a balanced and practical future trip budget across exactly THREE essential categories, using the completed trip only as a spending signal rather than copying it directly.

    Completed Trip Financial Data:
    - Destination: $destination
    - Total Allocated Budget: MYR ${allocatedBudget.toStringAsFixed(2)}
    - Total Expense: MYR ${totalExpense.toStringAsFixed(2)}
    - Expenses By Category:
    $categoryText

    CRITICAL RULES:
    - Return exactly one recommendation for each category: "Attraction", "Transport", and "Food".
    - Every category is essential and MUST receive between 20% and 60% inclusive, even when its completed-trip expense was RM 0.
    - "percentage" MUST be a whole number.
    - The three percentages MUST add up to exactly 100.
    - Keep the allocation reasonably balanced. A category with higher historical spending may receive more, but it must never receive the entire budget.
    - Do not interpret missing or zero spending as proof that the tourist will not need that category on the next trip.
    - Do NOT return currency amounts, explanations, extra categories, or additional fields.

    Format your response as this valid JSON object:
    {
      "recommendations": [
        {"category": "Attraction", "percentage": 25},
        {"category": "Transport", "percentage": 50},
        {"category": "Food", "percentage": 25}
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
    - Budget Ceiling: MYR ${budgetLimit.toStringAsFixed(2)}

    CRITICAL EXCLUSION LIST (DUPLICATES PROHIBITED):
    The user already has the following places in their itinerary or explicitly rejected them. You MUST NOT suggest any of these places or slight variations of them:
    $excludedListText

    CRITICAL RULES FOR DESTINATION & BUDGET:
    - The destination MUST be an EXACT, FULL official business name or landmark on Google Maps (e.g., "Museum of Illusions Kuala Lumpur", "Limapulo: Baba Can Cook"). Do NOT use generic names (e.g., "Local Cafe", "Museum Visit").
    - Public parks, sightseeing of landmarks, walking tours, and free attractions MUST have an "allocatedBudget" of 0.
    - "Transportation" activities: 0.0 if walking distance, or realistic fare (> 0) if public transit/Grab is required.
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
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=$_apiKey',
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

  // kokhong
  // Regenerates activities for empty slots using the remaining plan as route context.
  static Future<String> askGeminiToRegenerateEmptySlots({
    required String destinationCity,
    required double remainingBudget,
    required List<Map<String, dynamic>> remainingActivities,
    required List<Map<String, dynamic>> emptySlots,
    required List<String> excludedPlaces,
    List<String>? uncoveredWishlist,
    String? preference,
    List<String>? constraints,
  }) async {
    final excludedListText = excludedPlaces.isNotEmpty
        ? excludedPlaces.map((e) => '- "$e"').join('\n')
        : 'None';

    final prompt =
        '''
    You are an expert travel planner in Malaysia.
    The user has removed some activities from their itinerary in $destinationCity and needs to regenerate replacement activities for the EMPTY SLOTS.
    You MUST use the user's REMAINING ACTIVE ACTIVITIES as your route and schedule context.

    Parameters:
    - Destination City: $destinationCity
    - Remaining Budget Available for Empty Slots: MYR ${remainingBudget.toStringAsFixed(2)}
    ${preference != null && preference.isNotEmpty ? '- Trip Preference / Theme: $preference' : ''}
    ${constraints != null && constraints.isNotEmpty ? '- Personal Constraints: ${constraints.join(', ')}' : ''}
    ${uncoveredWishlist != null && uncoveredWishlist.isNotEmpty ? '- Uncovered Wishlist Items (Optionally place these into suitable empty slots if they fit): ${uncoveredWishlist.join(', ')}' : ''}

    REMAINING ACTIVE ACTIVITIES (KEPT BY USER - DO NOT MODIFY, USE AS ROUTE/TIMING CONTEXT):
    ${jsonEncode(remainingActivities)}

    EMPTY TIME SLOTS TO FILL (GENERATE EXACTLY ONE ACTIVITY FOR EACH):
    ${jsonEncode(emptySlots)}

    CRITICAL EXCLUSION LIST (DUPLICATES STRICTLY PROHIBITED):
    The user already has or has explicitly deleted these places. You MUST NOT suggest any of these:
    $excludedListText

    CRITICAL RULES:
    1. Exact 1-to-1 Mapping:
       - You MUST return a JSON array with EXACTLY ${emptySlots.length} items.
       - For every item, preserve the exact "activitiesId" provided in the corresponding empty slot!
    2. Geographic & Time Coherence:
       - New activities must be logically close in distance and route to the remaining activities on that day.
       - If a slot falls around lunch (12:00-14:00) or dinner (18:00-20:30), prefer suggesting a "Restaurant".
    3. Realistic Places & Budget:
       - Every destination MUST be an EXACT, FULL official business name or landmark on Google Maps in $destinationCity.
       - The total allocatedBudget across all returned slots should fit within MYR ${remainingBudget.toStringAsFixed(2)}.
       - Public parks, walking tours, and free landmarks MUST have an allocatedBudget of 0.0.
       - "activityCategory" MUST strictly be one of: "Attraction", "Restaurant", "Transportation".

    Format your response as a valid JSON array of objects:
    [
      {
        "activitiesId": "exact activitiesId from empty slot input",
        "destination": "Exact Business Name or Landmark",
        "imageKeyword": "Landmark or food name",
        "description": "Short 1-2 sentence description",
        "allocatedBudget": 0.0,
        "duration": "60-90 min",
        "activityCategory": "Attraction",
        "startTime": "HH:mm",
        "endTime": "HH:mm"
      }
    ]

    Return ONLY the raw JSON array with no markdown fences, no backticks, and no extra commentary.
    ''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=$_apiKey',
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
            return parts[0]['text'] ?? '[]';
          }
        }
        return '[]';
      } else {
        throw Exception(
          'Gemini Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Gemini API Regenerate Empty Slots Error: $e');
      throw Exception(
        'Failed to regenerate activities from remaining plan: $e',
      );
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
    DateTime? tripEndDate,
  }) async {
    final locationConstraint = userCoordinates != null
        ? 'Current GPS Coordinates: $userCoordinates (within $tripDestination)'
        : 'Destination: $tripDestination';

    // Derive a time-of-day label from startTime so Gemini knows meal context
    // without being anchored to exact times it must preserve anyway.
    String _timeOfDay(String? startTime) {
      if (startTime == null || startTime.isEmpty) return 'daytime';
      final hour = int.tryParse(startTime.split(':').first) ?? 12;
      if (hour < 12) return 'morning';
      if (hour < 17) return 'afternoon';
      return 'evening';
    }

    // 1. Minify input payload — only fields Gemini needs to make decisions.
    //    activitiesId: for 1-to-1 mapping back.
    //    category: so meal slots stay as meals, attractions stay as attractions.
    //    timeOfDay: morning/afternoon/evening hint for meal appropriateness.
    //    date: which day this slot falls on for day-by-day coherence.
    final sanitizedRemainingSlots = remainingActivities
        .map(
          (act) => {
            'activitiesId': act['activitiesId'],
            'category':
                act['activityCategory'] ?? act['category'] ?? 'Attraction',
            'timeOfDay': _timeOfDay(act['startTime']?.toString()),
            'date': act['date']?.toString().split('T').first ?? '',
          },
        )
        .toList();

    // cache existing image while no need to re-query google place api
    final existingImageMap = <String, String>{};
    for (final act in remainingActivities) {
      final dest = act['destination']?.toString().trim().toLowerCase();
      final img = act['activityImgUrl']?.toString().trim();
      if (dest != null && dest.isNotEmpty && img != null && img.isNotEmpty) {
        existingImageMap[dest] = img;
      }
    }

    final tripEndInfo = tripEndDate != null
        ? '\n    - Trip End Date: ${tripEndDate.toIso8601String().split('T').first}'
        : '';

    final prompt =
        '''
    You are an expert travel itinerary budget recovery engine.
    The tourist has reached a budget constraint. Re-plan their remaining itinerary slots to strictly fit the remaining funds.

    Context:
    - Location / Base: $locationConstraint
    - Current Date/Time: ${currentDate?.toIso8601String() ?? DateTime.now().toIso8601String()}$tripEndInfo
    - Already Spent So Far: MYR ${currentSpentBudget.toStringAsFixed(2)}
    - Remaining Budget Ceiling (total for ALL slots below): MYR ${effectiveRemainingBudget.toStringAsFixed(2)}
    - Number of Remaining Slots: ${sanitizedRemainingSlots.length}

    Remaining Slots to Re-plan:
    ${jsonEncode(sanitizedRemainingSlots)}

    Rules:
    1. Strict Slot Count (1-to-1 Mapping):
       - You MUST return an array with EXACTLY ${sanitizedRemainingSlots.length} items.
       - For every slot, PRESERVE the exact "activitiesId" from the input. Do NOT generate new IDs.
    2. Category Preservation:
       - Match the slot's original category. If the original slot was a restaurant/food category, replace it with an affordable local food spot/hawker stall; do NOT replace a meal slot with a park.
       - Use the "timeOfDay" hint: morning slots should have breakfast options, afternoon slots should have lunch options, evening slots should have dinner options.
    3. Budget Distribution:
       - The sum of ALL "allocatedBudget" values across the returned items MUST be <= MYR ${effectiveRemainingBudget.toStringAsFixed(2)}.
       - Distribute the budget sensibly across remaining days — do not spend everything on early slots and leave later days with nothing.
       - If remaining budget is MYR 0 or near 0, use free activities (public parks, walking tours, free galleries) and minimal meal costs (hawker food MYR 5-10).
       - Public parks, walking tours, and free sights MUST have "allocatedBudget": 0.0.
    4. Geographic Proximity:
       - All venues must be within close walking distance or short public transit of $locationConstraint. Never suggest cross-city travel.
       - Activities on the same date should be geographically close to each other for a practical day plan.
       - Every destination must be a specific, real-world Google Maps place name (no generic names like "Local Eatery").

    Output Schema:
    Return ONLY a raw JSON array matching this structure (no markdown fences, no extra text):
    [
      {
        "activitiesId": "exact activitiesId from input",
        "destination": "Exact Place Name",
        "description": "Short 1-sentence reason (e.g., Free entrance landmark near current location)",
        "activityCategory": "Restaurant | Attraction | Transportation",
        "allocatedBudget": 0.0
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
                final rawItems = List<Map<String, dynamic>>.from(decoded);

                // fetch images concurrently using Google Place
                final enrichedActivities = await Future.wait(
                  rawItems.map((item) async {
                    final tripDestination =
                        item['destination']?.toString().trim() ?? '';
                    final lowerDest = tripDestination.toLowerCase();
                    // Fetch image for the destination

                    // if the same activity occur then use the same image first
                    if (existingImageMap.containsKey(lowerDest)) {
                      item['activityImgUrl'] = existingImageMap[lowerDest];
                      return item;
                    }

                    // if the image url does not exist then get the url from google place
                    try {
                      final url =
                          await GooglePlacesApiConfig.searchPlacePhotoUrl(
                            tripDestination,
                          );
                      item['activityImgUrl'] = url ?? '';
                    } catch (e) {
                      debugPrint(
                        'Error fetching place photo for $tripDestination: $e',
                      );
                      item['activityImgUrl'] = '';
                    }
                    return item;
                  }),
                );

                // Return the enriched recovery activities instead of dropping them.
                return enrichedActivities;
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
