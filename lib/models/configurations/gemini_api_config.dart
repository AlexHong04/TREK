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
    - Destination: $destination (Malaysia)
    - Dates: $dates (Total: $numberOfDays days)
    - Target Total Budget: MYR $budget (Malaysian Ringgit, for the ENTIRE $numberOfDays-day trip)
    - Currency: All activity budgets, prices, and totals MUST be in Malaysian Ringgit (MYR).
    
    CRITICAL MANDATORY GEOGRAPHIC BOUNDARY RULE:
    - Target Destination: "$destination", Malaysia.
    - STRICT ENFORCEMENT: EVERY single activity, attraction, restaurant, cafe, hawker stall, shop, landmark, and transit stop MUST be physically located within "$destination", Malaysia!
    - ABSOLUTELY FORBIDDEN: NEVER include or recommend places from other cities or states (for example, if Destination is "Penang", you MUST ONLY choose places located within Penang state, e.g. George Town, Batu Ferringhi, Air Itam, Bayan Lepas, Gurney Drive, etc. DO NOT include places in Kuala Lumpur such as KLCC, Petronas Towers, Batu Caves, Bukit Bintang, Pavilion KL, etc.!).
    - Suggesting places outside "$destination" is strictly forbidden and invalid.
    ${preference != null ? '- Preference: $preference (You MUST heavily prioritize planning activities that strictly match this theme!)' : ''}
    ${resolvedArrivals.isNotEmpty ? '''- Arrival Details:
${resolvedArrivals.asMap().entries.map((e) => '      * Arrival ${e.key + 1} (${e.value.type}): ${e.value.location}${e.value.date.isNotEmpty ? ' on ${e.value.date}' : ''} at ${e.value.time}').join('\n')}
      * CRITICAL FOR DAY 1: Day 1 activities MUST start after the initial arrival time (${resolvedArrivals.first.time}${resolvedArrivals.first.date.isNotEmpty ? ' on ${resolvedArrivals.first.date}' : ''}) at "${resolvedArrivals.first.location}" (arriving via ${resolvedArrivals.first.type}). Route connecting activities accordingly!''' : ''}
    ${resolvedDepartures.isNotEmpty ? '''- Departure Details:
${resolvedDepartures.asMap().entries.map((e) => '      * Departure ${e.key + 1} (${e.value.type}): ${e.value.location}${e.value.date.isNotEmpty ? ' on ${e.value.date}' : ''} at ${e.value.time}').join('\n')}
      * CRITICAL FOR FINAL DAY (MANDATORY DEPARTURE COVERAGE):
        - The traveler departs from "${resolvedDepartures.last.location}" via ${resolvedDepartures.last.type} at ${resolvedDepartures.last.time}.
        - YOU MUST EXPLICITLY SCHEDULE A DEDICATED ACTIVITY TO COVER DEPARTURE on the final day (dayNumber: $numberOfDays)!
        - The absolute LAST activity on the final day MUST be:
          * "destination": "${resolvedDepartures.last.location}"
          * "activityCategory": "Transportation"
          * "description": "Travel to ${resolvedDepartures.last.location} for departure via ${resolvedDepartures.last.type}"
          * "endTime": "${resolvedDepartures.last.time}"
          * "startTime": 45-90 minutes before ${resolvedDepartures.last.time} (allowing ample travel and check-in time)
        - All sightseeing, attractions, and meals on the final day MUST conclude before this departure transfer begins! Do NOT schedule dinner or night markets after this departure!''' : ''}
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
    - MANDATORY HARD BUDGET LIMIT: The total cost of the generated activities ("totalAllocatedBudget") MUST BE STRICTLY LESS THAN OR EQUAL TO MYR $budget! (Aim for around MYR ${(double.tryParse(budget) ?? 85.0) * 0.9} to $budget, NEVER above $budget!). If budget is 85, totalAllocatedBudget CANNOT be 88!
    - To fit the entire plan strictly within MYR $budget, aggressively economize on all other activities:
      * Choose affordable local eateries/hawker stalls (e.g. MYR 5-10) for ordinary meals.
      * Choose free public attractions, parks, or walking tours for other non-wishlist slots.
      * Keep transport minimal or walking (MYR 0.0).
    - "wishlistItemsCoveredCount" MUST BE EXACTLY ${wishlist.length} (since 100% of the wishlist items are included).
    - "estimatedExtraBudgetNeeded" MUST be 0.0 since the plan MUST fit within MYR $budget.
    ''' : '''
    CRITICAL RULE FOR WISHLIST & BUDGET (BUDGET-CONSTRAINED GENERATION):
    - Target Total Budget: MYR $budget for the entire $numberOfDays-day trip.
    - Wishlist destinations requested by user (${wishlist.length} total): ${wishlist.join(', ')}.
    - MANDATORY HARD BUDGET LIMIT: The total cost of the generated activities ("totalAllocatedBudget") MUST BE STRICTLY LESS THAN OR EQUAL TO the user's Target Total Budget of MYR $budget! You MUST keep the planned itinerary strictly within MYR $budget (aim for around MYR ${(double.tryParse(budget) ?? 60.0) * 0.9} to $budget, NEVER above $budget!).
    - WISHLIST SELECTION WITHIN BUDGET:
      * Allocate the available budget (MYR $budget) to include ONLY as many wishlist items as can realistically fit into the budget, alongside essential affordable meals (MYR 5-12 per meal) and minimal transit.
      * If MYR $budget is INSUFFICIENT to cover all ${wishlist.length} wishlist items:
        - NEVER try to squeeze too many wishlist items into the plan if it would make the total cost exceed MYR $budget! For example, if including 3 wishlist items pushes the cost to 67.50, you MUST ONLY include 1 or 2 wishlist items so the total cost stays strictly <= MYR $budget!
        - ONLY include the wishlist items that can realistically fit into the MYR $budget plan!
        - DO NOT include the remaining wishlist items that cannot fit into MYR $budget in the activities list! Leave them out of the activities list.
        - "wishlistItemsCoveredCount" MUST BE EXACTLY the number of wishlist items actually scheduled in the "activities" list (e.g. 1 or 2 out of ${wishlist.length}). NEVER report more than the items actually included!
        - "estimatedExtraBudgetNeeded": Estimate the realistic extra budget in MYR needed to cover the remaining (${wishlist.length} - wishlistItemsCoveredCount) uncovered wishlist items (including their admission tickets and required transport/meals, e.g. MYR 50.00 - 150.00).
      * If MYR $budget is SUFFICIENT to cover all ${wishlist.length} wishlist items:
        - Include ALL ${wishlist.length} wishlist items in the activities.
        - "wishlistItemsCoveredCount" = ${wishlist.length}.
        - "estimatedExtraBudgetNeeded" = 0.0.
    - Wishlist scheduling: For the wishlist items that are included, distribute them appropriately across the trip dates.
    ''') : '- Wishlist Items: None\n    CRITICAL RULE FOR NO WISHLIST:\n    - The user did NOT provide any wishlist items.\n    - "wishlistItemsCoveredCount" MUST BE EXACTLY 0. Do NOT count general attractions, restaurants, or itinerary activities as wishlist items!'}

    Please provide a structured day-by-day itinerary with estimated costs and durations for each activity.
    ${strictBudget ? '''
    CRITICAL RULE FOR BUDGET & PRICING (STRICT BUDGET / TOP-UP MODE):
    - The user has topped up the budget to MYR $budget to cover all wishlist items.
    - HARD BUDGET CEILING: "totalAllocatedBudget" MUST BE STRICTLY LESS THAN OR EQUAL TO MYR $budget! NEVER exceed MYR $budget. Aim for around MYR ${(double.tryParse(budget) ?? 85.0) * 0.9} to $budget.
    - You MUST fit the itinerary within MYR $budget:
      * Choose affordable local eateries/hawkers (MYR 5.00 - 10.00). Food is NEVER free (minimum MYR 4.00).
      * Free parks/sightseeing/walking tours (0.0).
      * Walking (0.0) or minimal public transit (MYR 2-4).
    - "totalAllocatedBudget" MUST equal the exact mathematical sum of all "allocatedBudget" fields (and MUST be <= MYR $budget).
    - "estimatedExtraBudgetNeeded" MUST be 0.0.
    ''' : '''
    CRITICAL RULE FOR BUDGET & PRICING (STRICT BUDGET CONSTRAINED):
    - The user provided a budget cap of MYR $budget for the entire $numberOfDays-day trip.
    - HARD BUDGET LIMIT: The planned itinerary ("totalAllocatedBudget") MUST NOT exceed MYR $budget. Work strictly within this budget!
    - PRICING GUIDELINES:
      * Meals: Hawker stalls, kopitiams, mamak eateries (MYR 5.00 - 12.00 per meal). EVERY "Restaurant" MUST have allocatedBudget >= 4.0. Food is NEVER free.
      * Transport: WALKING (MYR 0.0) whenever possible. Public transit (MYR 2.00 - 4.00) only when far.
      * Non-wishlist attractions: MUST be FREE (public parks, heritage streets, temples, beaches, etc.) with allocatedBudget: 0.0.
      * Paid wishlist items: Use their realistic admission price, but ONLY include as many wishlist items as can fit within MYR $budget.
    - "totalAllocatedBudget" MUST ALWAYS equal the exact mathematical sum of all "allocatedBudget" fields in the activities list, and MUST be <= MYR $budget.
    - SUMMARY OF estimatedExtraBudgetNeeded:
      * If all wishlist items are covered and totalAllocatedBudget <= $budget → estimatedExtraBudgetNeeded = 0.0
      * If some wishlist items were omitted due to budget shortage → estimatedExtraBudgetNeeded = realistic extra MYR needed to cover the omitted wishlist items.
    '''}
    
    CRITICAL RULE FOR ROUTING:
    - Group activities geographically within "$destination"! Each day of the itinerary MUST focus on ONE specific area or neighborhood within "$destination" (for example, if "$destination" is Penang, Day 1 could focus on George Town Heritage Zone, Day 2 on Batu Ferringhi / Teluk Bahang, Day 3 on Bayan Lepas; if "$destination" is Melaka, Day 1 on Bandar Hilir / Jonker, Day 2 on Ayer Keroh).
    - Do NOT jump across distant parts of the city/state on the same day. Every single activity on a given "dayNumber" MUST be found within that day's designated area in "$destination" to minimize travel time.
    - Consecutive activities MUST be close to each other in real life to make routing practical.

    CRITICAL RULE FOR TIME SCHEDULING:
    - THIS IS THE MOST IMPORTANT RULE: You MUST generate an itinerary exactly for $numberOfDays day(s). If $numberOfDays is 3, return exactly 3 days. If $numberOfDays is 4, return exactly 4 days. The number of days returned MUST strictly match $numberOfDays!
    - The "dayNumber" MUST go sequentially from 1 up to exactly $numberOfDays. DO NOT generate less or more days than $numberOfDays!
    - Daily schedule timing:
      * Day 1 starts at ${resolvedArrivals.isNotEmpty ? resolvedArrivals.first.time : '09:00'} (accommodating traveler arrival at "${resolvedArrivals.isNotEmpty ? resolvedArrivals.first.location : 'arrival location'}").
      * The final day ends at ${resolvedDepartures.isNotEmpty ? resolvedDepartures.last.time : '21:00'} with the traveler reaching their departure hub "${resolvedDepartures.isNotEmpty ? resolvedDepartures.last.location : 'departure location'}".
      * All intermediate days strictly start at 09:00 and end at 21:00.
      * Provide a complete continuous schedule filling the active hours, with connecting transportation between destinations.
    - The endTime of each activity must smoothly connect to the startTime of the next activity without large gaps.
    - Do not schedule any activities before 09:00 or after 21:00 (unless Day 1 arrival or final day departure dictates earlier or later). 
    - On intermediate days, the last activity of the day should reach 21:00. On the final day with departure, the final activity MUST be the departure transfer to "${resolvedDepartures.isNotEmpty ? resolvedDepartures.last.location : 'departure point'}" ending at ${resolvedDepartures.isNotEmpty ? resolvedDepartures.last.time : '21:00'}.

    CRITICAL RULE FOR COMPOSITION & TRANSPORTATION:
    - Meal planning:
      * For full days, include THREE "Restaurant" category activities (strictly representing Breakfast, Lunch, and Dinner).
      * On the final day, only include meals that occur BEFORE the departure time (e.g. if departure is in the afternoon, include Breakfast and Lunch; do NOT force Dinner after the traveler has already departed!).
    - MANDATORY TRANSPORTATION BETWEEN ACTIVITIES (WALK IF CLOSE, VEHICLE IF FAR):
      * Between consecutive destination activities (Attractions and Restaurants), there MUST be a dedicated "Transportation" category activity representing the commute or walk between them.
      * PROXIMITY & TRANSIT MODE RULE:
        - If two consecutive activities are CLOSE to each other (within walking distance, e.g. < 1km, adjacent streets, or within the same neighborhood/complex in "$destination"):
          + Transit mode is WALKING: set "destination" to "Walk to [Next Destination]" or "Pedestrian Walkway", "description" to "Short 5-10 min walk to the next venue", "duration" to "5-15 min", and "allocatedBudget" to 0.0 (Walking is completely free!).
        - If two consecutive activities are FAR from each other (requiring motorized transit, different neighborhoods, or > 1km):
          + Transit mode is VEHICULAR (Bus, Grab, Taxi, or local transit): set "destination" to the local station, terminal, or transit route within "$destination" (e.g. "Rapid Penang Bus / Grab to next destination"), "description" to describe the local commute within "$destination", "duration" to "15-30 min", and "allocatedBudget" to a realistic fare greater than 0 (e.g. MYR 3.00 - MYR 15.00).
      * "activityCategory" for all of these transfer activities MUST strictly be "Transportation".

    CRITICAL RULE FOR DESTINATIONS/RESTAURANTS:
    - Every destination, restaurant, cafe, or eatery MUST be located within "$destination" and specified using its full, real-world, specific business or place name.
    - Do NOT generate generic dish or food names (such as "Nasi Lemak", "Teh Tarik", "Roti Canai", "Satay") as the destination. You must specify the actual restaurant name where it can be eaten.
    - Every "destination" value MUST be an actual, currently operating, highly popular business or landmark in "$destination" that is guaranteed to have a listing and photos on Google Maps. Do NOT invent fictional place names.
    - We will programmatically verify each destination against Google Places API to fetch its image. If a destination is obscure or NOT found on Google Places, the itinerary is invalid.
    
    CRITICAL RULE FOR UNIQUENESS (NO DUPLICATES EXCEPT TRANSPORTATION):
    - EXCEPT for activities with "activityCategory": "Transportation", EVERY single destination, attraction, restaurant, cafe, shop, and landmark across the ENTIRE multi-day itinerary MUST be strictly and 100% UNIQUE.
    - ZERO REPEATED PLACES:
      * Do NOT propose the same restaurant, cafe, or eatery more than once across all days. Every breakfast, lunch, and dinner must be at a completely different venue!
      * Do NOT propose the same attraction, museum, theme park, or landmark more than once across all days. If a place is visited on Day 1, it CANNOT be visited again on Day 2, Day 3, or any other day.
      * Do NOT visit the same shopping mall, market, or complex multiple times (e.g. do NOT schedule lunch at a mall and then shopping at the same mall, and do NOT revisit it on another day).
      * Do NOT use slight variations of the same name to bypass this rule.
    - TRANSPORTATION IS THE ONLY EXCEPTION:
      * Only commute activities with "activityCategory": "Transportation" (e.g., "Walk to ...", "Local Transit to ...") can be repeated between destinations. All other activities must be distinct.
    ${(avoidPlaces != null && avoidPlaces.isNotEmpty) ? '\nCRITICAL REJECTION LIST FOR RETRY:\nThe following places were previously generated in a prior attempt but COULD NOT be found on Google Places API. You MUST NOT include any of these in your response. Instead, suggest different, verified, operating real-world venues/landmarks that are definitely searchable on Google Places:\n' + avoidPlaces.map((e) => '- "$e"').join('\n') : ''}
    
    Format your response STRICTLY as the following JSON object structure. Do NOT include markdown fences (no ```json ... ```), and do NOT include any extra text:
    
    {
      "totalAllocatedBudget": 200.0,
      "wishlistItemsCoveredCount": ${(wishlist != null && wishlist.isNotEmpty) ? wishlist.length : 0},
      "estimatedExtraBudgetNeeded": 0.0,
      "activities": [
        {
          "dayNumber": 1,
          "destination": "Actual Google Maps Business/Landmark Name in $destination",
          "imageKeyword": "Famous Landmark in $destination",
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
    - totalAllocatedBudget (double): The exact mathematical sum of all "allocatedBudget" in the activities list in MYR. MUST stay within MYR $budget (unless top-up mode).
    - wishlistItemsCoveredCount (int): Number of user-provided wishlist items actually scheduled as activities in the itinerary. If only some wishlist items fit within the budget, report ONLY the number actually included. If all ${(wishlist != null && wishlist.isNotEmpty) ? wishlist.length : 0} items are included, set to ${(wishlist != null && wishlist.isNotEmpty) ? wishlist.length : 0}. If no wishlist was provided, set to 0.
    - estimatedExtraBudgetNeeded (double): If not all wishlist items could fit within the MYR $budget, return the estimated additional budget in MYR needed to cover the remaining uncovered wishlist items. Return 0.0 if all wishlist items are covered and totalAllocatedBudget <= $budget.
    - dayNumber (int): Sequential day (1 for Day 1, 2 for Day 2...).
    - destination (String): EXACT, FULL official business name or landmark on Google Maps. No generic names.
    - imageKeyword (String): Landmark name or generic food type (e.g. "Nasi Lemak" instead of restaurant name).
    - allocatedBudget (double): Max estimated cost or fixed price in MYR. 0.0 for free.
    - duration (String): e.g., "60-90 min".
    - activityCategory (String): MUST be "Transportation", "Attraction", or "Restaurant".
    - startTime/endTime (String): 24-hour format "HH:mm".
    - minPrice (double): Min estimated cost in MYR. Set to 0.0 or null if free/fixed.
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
    String? preference,
    List<String>? constraints,
    String? previousActivityDestination,
    String? nextActivityDestination,
    bool isFirstDay = false,
    bool isLastDay = false,
    int totalDays = 1,
  }) async {
    final excludedListText = existingOrExcludedPlaces.isNotEmpty
        ? existingOrExcludedPlaces.map((e) => '- "$e"').join('\n')
        : 'None';

    // Build surrounding activities context for geographic coherence
    final surroundingContext = StringBuffer();
    if (previousActivityDestination != null &&
        previousActivityDestination.isNotEmpty) {
      surroundingContext.write(
        '    - Previous Activity (before this slot): "$previousActivityDestination"\n',
      );
    }
    if (nextActivityDestination != null && nextActivityDestination.isNotEmpty) {
      surroundingContext.write(
        '    - Next Activity (after this slot): "$nextActivityDestination"\n',
      );
    }

    // Build day position context (arrival/departure awareness)
    final dayPositionContext = StringBuffer();
    if (isFirstDay) {
      dayPositionContext.write(
        '''
    DAY 1 AWARENESS:
    - This is the FIRST day of the trip. The traveler may have just arrived.
    - If this slot is early in the day, suggest activities near common arrival points (airports, train stations, bus terminals) or the hotel area.
    - Avoid suggesting far-flung locations that require long transit from arrival points.\n''',
      );
    }
    if (isLastDay) {
      dayPositionContext.write(
        '''
    FINAL DAY AWARENESS:
    - This is the LAST day (Day $dayNumber of $totalDays) of the trip. The traveler will depart later today.
    - If this slot is in the afternoon or evening, suggest activities near departure points or the hotel area so the traveler can leave on time.
    - Avoid suggesting activities far from the city center or transit hubs.\n''',
      );
    }

    final prompt =
        '''
    You are an expert travel planner in Malaysia. A user removed an activity from their Day $dayNumber itinerary in $destinationCity and needs ONE replacement activity to fill the empty time slot.

    CONTEXT:
    - City: $destinationCity
    - Trip Duration: $totalDays day(s)
    - Target Area / Neighborhood: $targetAreaOrNeighborhood (The replacement MUST be located nearby this area to minimize travel time)
    - Preferred Category: ${category.isNotEmpty ? category : "Attraction or Restaurant"}
    - Time Slot: $startTime to $endTime
    - Budget Ceiling: MYR ${budgetLimit.toStringAsFixed(2)}
    ${preference != null && preference.isNotEmpty ? '- Trip Theme / Preference: $preference (The replacement activity MUST align with this theme!)' : ''}
    ${(constraints != null && constraints.isNotEmpty) ? '- Personal Constraints: ${constraints.join(', ')} (You MUST strictly follow these constraints, e.g., dietary restrictions, accessibility needs!)' : ''}
    ${surroundingContext.isNotEmpty ? '\n    SURROUNDING ACTIVITIES (for geographic coherence):\n$surroundingContext    - The replacement activity MUST be geographically close to these surrounding activities. Do NOT suggest a place on the opposite side of the city.' : ''}
    $dayPositionContext
    CRITICAL EXCLUSION LIST (DUPLICATES PROHIBITED):
    The user already has the following places in their itinerary or explicitly rejected them. You MUST NOT suggest any of these places:
    $excludedListText
    - Do NOT use slight variations of excluded names to bypass this rule (e.g., "Petronas Twin Towers" and "Petronas Towers" are the same venue).

    CRITICAL RULES FOR DESTINATION:
    - The destination MUST be an EXACT, FULL official business name or landmark on Google Maps located in "$destinationCity". Do NOT use generic names (e.g., "Local Cafe", "Museum Visit").
    - Every "destination" MUST be an actual, currently operating, highly popular business or landmark that is guaranteed to have a listing and photos on Google Maps.
    - We will programmatically verify the destination against Google Places API to fetch its image. If the destination is obscure or NOT found on Google Places, it will be rejected.

    CRITICAL RULES FOR BUDGET & PRICING:
    - You MUST assign TRUE, REALISTIC market-rate costs for the activity's "allocatedBudget".
    - Realistic price ranges in Malaysia: meals at hawker stalls MYR 5-15, casual restaurants MYR 15-40, fine dining MYR 50+, attraction tickets MYR 10-80, public transit MYR 1-5, Grab rides MYR 5-20.
    - NEVER invent fake MYR 0.0 or insanely low prices for restaurants or paid attractions.
    - Public parks, sightseeing of landmarks, walking tours, and free attractions MUST have an "allocatedBudget" of 0.
    - Only assign costs to food/dining, transportation, and places that explicitly require entrance tickets.
    - The "allocatedBudget" MUST NOT exceed the Budget Ceiling of MYR ${budgetLimit.toStringAsFixed(2)}.
    - "activityCategory" MUST strictly be one of: "Transportation", "Attraction", or "Restaurant".

    TRANSPORTATION AWARENESS:
    - Consider how the traveler will get to this activity from the previous one, and from this activity to the next one.
    - Prefer locations that are within walking distance of the surrounding activities, or easily reachable by MRT/LRT.
    - Do NOT suggest a location that would require an expensive or time-consuming Grab ride if there are closer alternatives.

    Format your response as a valid single JSON object with the following fields:
    {
      "dayNumber": $dayNumber,
      "destination": "Exact Business Name or Landmark",
      "imageKeyword": "Famous landmark name or generic food item (e.g. 'Nasi Lemak', 'Aquarium')",
      "description": "Short 1-2 sentence description",
      "allocatedBudget": 0.0,
      "minPrice": 0.0,
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
