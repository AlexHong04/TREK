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

class GeminiReceiptItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double? lineTotal;

  const GeminiReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.lineTotal,
  });
}

class GeminiReceiptParseResult {
  final String merchantName;
  final DateTime? transactionDateTime;
  final double? totalAmount;
  final double? taxAmount;
  final double? discountAmount;
  final double? roundingAmount;
  final List<GeminiReceiptItem> items;

  const GeminiReceiptParseResult({
    required this.merchantName,
    required this.transactionDateTime,
    required this.totalAmount,
    required this.taxAmount,
    required this.discountAmount,
    required this.roundingAmount,
    required this.items,
  });
}

class GeminiApiConfig {
  // Gemini API Key
  static const String _apiKey =
      'AQ.Ab8RN6Lymr_XH98EC38B2Po-XWNQmqksO4uCMLPgzCfWmCHSPA';

  static late final GenerativeModel _model;

  static void initialize() {
    _model = GenerativeModel(model: 'gemini-3.5-flash-lite', apiKey: _apiKey);
  }

  static String _formatTo24Hour(String? timeStr, String default24H) {
    if (timeStr == null || timeStr.trim().isEmpty) return default24H;
    final trimmed = timeStr.trim();
    try {
      final tParts = trimmed.split(RegExp(r'[:\s]'));
      if (tParts.length >= 2) {
        int h = int.parse(tParts[0]);
        int m = int.parse(tParts[1]);
        final lower = trimmed.toLowerCase();
        final isPm = lower.contains('pm');
        final isAm = lower.contains('am');
        if (isPm && h < 12) h += 12;
        if (isAm && h == 12) h = 0;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    return trimmed.contains(':') ? trimmed : default24H;
  }

  static Future<GeminiReceiptParseResult?> parseReceiptOcrText({
    required String receiptText,
  }) async {
    final prompt =
        '''
Parse this Malaysian receipt OCR text into expense fields.

Rules:
- Return only valid JSON. No markdown, no explanation.
- Use MYR amounts as numbers only.
- Translate item names to English when they are clearly in another language.
- Chinese receipt labels may appear, for example 名称=item name, 重/数量=weight/quantity, 单价=unit price, 小计=subtotal, 原价=original subtotal, 应收/实收/合计/总计=total paid.
- If no currency symbol is printed but the receipt is from a Malaysian expense flow, treat the amounts as MYR.
- Numeric dates like 04/09/2026 must be interpreted as DD/MM/YYYY.
- Use ISO 8601 local datetime format for transactionDateTime when detected.
- If tax, discount, or rounding is not clearly shown, return null for that field.
- Do not infer tax from missing items unless a tax/GST/SST/service tax label exists.
- Rounding can be positive or negative.
- Items must be purchased product/service rows only, not subtotal, tax, rounding, total, payment, invoice, cashier, table, address, or thank-you lines.
- For receipt table rows like weight/quantity + unit price + subtotal, unitPrice is the per-unit price and lineTotal is the row subtotal.
- If quantity is decimal or measured by kg, set quantity to 1 and unitPrice to the row subtotal, then also set lineTotal to the same row subtotal because this app only supports whole-number item quantity.
- Quantity defaults to 1 only when the item and price are clearly a purchased row.

JSON shape:
{
  "merchantName": "string or empty",
  "transactionDateTime": "YYYY-MM-DDTHH:mm:ss or null",
  "totalAmount": 0.0,
  "taxAmount": 0.0 or null,
  "discountAmount": 0.0 or null,
  "roundingAmount": 0.0 or null,
  "items": [
    {"name": "string", "quantity": 1, "unitPrice": 0.0, "lineTotal": 0.0}
  ]
}

OCR text:
$receiptText
''';

    try {
      final response = await http
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=$_apiKey',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.1,
                'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        debugPrint('Gemini receipt OCR parse failed: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final content = candidates[0]['content'];
      final parts = content?['parts'] as List?;
      final rawText = parts?.isNotEmpty == true ? parts!.first['text'] : null;
      if (rawText is! String || rawText.trim().isEmpty) return null;

      final cleaned = rawText
          .trim()
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map<String, dynamic>) return null;

      final itemValues = decoded['items'];
      final items = <GeminiReceiptItem>[];
      if (itemValues is List) {
        for (final item in itemValues) {
          if (item is! Map) continue;
          final name = item['name']?.toString().trim() ?? '';
          final quantity = _intValue(item['quantity']) ?? 1;
          final unitPrice = _doubleValue(item['unitPrice']);
          if (name.isEmpty || quantity <= 0 || unitPrice == null) continue;
          items.add(
            GeminiReceiptItem(
              name: name,
              quantity: quantity,
              unitPrice: unitPrice,
              lineTotal: _doubleValue(item['lineTotal']),
            ),
          );
        }
      }

      return GeminiReceiptParseResult(
        merchantName: decoded['merchantName']?.toString().trim() ?? '',
        transactionDateTime: _dateTimeValue(decoded['transactionDateTime']),
        totalAmount: _doubleValue(decoded['totalAmount']),
        taxAmount: _doubleValue(decoded['taxAmount']),
        discountAmount: _doubleValue(decoded['discountAmount']),
        roundingAmount: _doubleValue(decoded['roundingAmount']),
        items: items,
      );
    } catch (error) {
      debugPrint('Gemini receipt OCR parse error: $error');
      return null;
    }
  }

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static double? _doubleValue(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^0-9.\-]'), '').trim());
    }
    return null;
  }

  static DateTime? _dateTimeValue(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
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
    bool isForeign = false,
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
          time: arrivalTime != null && arrivalTime.trim().isNotEmpty
              ? arrivalTime
              : '09:00 AM',
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
          time: departureTime != null && departureTime.trim().isNotEmpty
              ? departureTime
              : '09:00 PM',
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

    final String rawStartTime;
    final String day1StartTime24H;
    if (!isForeign &&
        resolvedDepartures.isNotEmpty &&
        resolvedDepartures.first.location.trim().isNotEmpty &&
        resolvedDepartures.first.time.trim().isNotEmpty) {
      rawStartTime = resolvedDepartures.first.time;
      day1StartTime24H = _formatTo24Hour(rawStartTime, '09:00');
    } else {
      rawStartTime = (resolvedArrivals.isNotEmpty &&
              resolvedArrivals.first.time.trim().isNotEmpty)
          ? resolvedArrivals.first.time
          : (arrivalTime != null && arrivalTime.trim().isNotEmpty
              ? arrivalTime
              : '09:00 AM');
      day1StartTime24H = _formatTo24Hour(rawStartTime, '09:00');
    }

    final String finalDayEndTime24H;
    final bool hasFinalDeparture;
    final String rawDepartureTime;
    if (!isForeign) {
      if (resolvedDepartures.length > 1 &&
          resolvedDepartures.last.location.trim().isNotEmpty &&
          resolvedDepartures.last.time.trim().isNotEmpty) {
        hasFinalDeparture = true;
        rawDepartureTime = resolvedDepartures.last.time;
        finalDayEndTime24H = _formatTo24Hour(rawDepartureTime, '21:00');
      } else {
        hasFinalDeparture = false;
        rawDepartureTime = '09:00 PM';
        finalDayEndTime24H = '21:00';
      }
    } else {
      if (resolvedDepartures.isNotEmpty &&
          resolvedDepartures.last.location.trim().isNotEmpty &&
          resolvedDepartures.last.time.trim().isNotEmpty) {
        hasFinalDeparture = true;
        rawDepartureTime = resolvedDepartures.last.time;
        finalDayEndTime24H = _formatTo24Hour(rawDepartureTime, '21:00');
      } else {
        hasFinalDeparture = false;
        rawDepartureTime = '09:00 PM';
        finalDayEndTime24H = '21:00';
      }
    }

    final String transitFlowPrompt;
    if (!isForeign) {
      // Local Malaysian Flow:
      // START: Leg 1 Departure (origin) -> Leg 1 Arrival (destination) -> Transit Journey
      // INTERMEDIATE: Leg i Departure -> Leg i Arrival
      // END: Final Departure -> Final Return Arrival
      final bool hasStartDeparture = resolvedDepartures.isNotEmpty &&
          resolvedDepartures.first.location.trim().isNotEmpty;
      final bool hasStartArrival = resolvedArrivals.isNotEmpty &&
          resolvedArrivals.first.location.trim().isNotEmpty;

      final StringBuffer sb = StringBuffer();
      sb.writeln('    - LOCAL MALAYSIAN TRAVEL FLOW (START):');
      if (hasStartDeparture && hasStartArrival) {
        sb.writeln('      * START Leg 1 Departure: Departs from "${resolvedDepartures.first.location}" at ${resolvedDepartures.first.time} (${_formatTo24Hour(resolvedDepartures.first.time, '09:00')}) via ${resolvedDepartures.first.type}.');
        sb.writeln('      * START Leg 1 Arrival: Arrives in "$destination" at "${resolvedArrivals.first.location}" at ${resolvedArrivals.first.time} (${_formatTo24Hour(resolvedArrivals.first.time, '11:00')}) via ${resolvedArrivals.first.type}.');
        sb.writeln('      * CRITICAL MANDATORY FIRST ACTIVITY ON DAY 1 (TRANSIT JOURNEY):');
        sb.writeln('        - The very first activity on Day 1 MUST BE the transit connection:');
        sb.writeln('          * "destination": "${resolvedArrivals.first.location}"');
        sb.writeln('          * "activityCategory": "Transportation"');
        sb.writeln('          * "description": "Travel from ${resolvedDepartures.first.location} to ${resolvedArrivals.first.location} via ${resolvedDepartures.first.type}"');
        sb.writeln('          * "startTime": "${_formatTo24Hour(resolvedDepartures.first.time, '09:00')}"');
        sb.writeln('          * "endTime": "${_formatTo24Hour(resolvedArrivals.first.time, '11:00')}"');
        sb.writeln('        - All subsequent Day 1 activities (sightseeing, hotel check-in, lunch) MUST strictly start AFTER ${_formatTo24Hour(resolvedArrivals.first.time, '11:00')}!');
      } else if (hasStartArrival) {
        sb.writeln('      * Day 1 Arrival Time: $day1StartTime24H ($rawStartTime) at "${resolvedArrivals.first.location}" (${resolvedArrivals.first.type}).');
        sb.writeln('      * Day 1 activities in "$destination" begin strictly at $day1StartTime24H.');
      } else {
        sb.writeln('      * Day 1 starts at 09:00.');
      }

      if (resolvedDepartures.length > 2 && resolvedArrivals.length > 2) {
        sb.writeln('    - INTERMEDIATE TRANSIT LEGS:');
        for (int idx = 1; idx < resolvedDepartures.length - 1; idx++) {
          final dep = resolvedDepartures[idx];
          final arr = resolvedArrivals[idx];
          sb.writeln('      * Transit $idx: Depart from "${dep.location}"${dep.date.isNotEmpty ? ' on ${dep.date}' : ''} at ${dep.time} via ${dep.type}, arriving at "${arr.location}" at ${arr.time}. Schedule this Transportation connection on that day!');
        }
      }

      if (hasFinalDeparture) {
        sb.writeln('    - LOCAL MALAYSIAN TRAVEL FLOW (END / RETURN):');
        sb.writeln('      * The traveler concludes their trip and returns home on Day $numberOfDays:');
        sb.writeln('        - Return Departure: Departs from "${resolvedDepartures.last.location}"${resolvedDepartures.last.date.isNotEmpty ? ' on ${resolvedDepartures.last.date}' : ''} at ${resolvedDepartures.last.time} (${_formatTo24Hour(resolvedDepartures.last.time, '21:00')}) via ${resolvedDepartures.last.type}.');
        if (resolvedArrivals.length > 1) {
          sb.writeln('        - Return Arrival: Arrives back at "${resolvedArrivals.last.location}" at ${resolvedArrivals.last.time}.');
        }
        sb.writeln('      * CRITICAL FOR FINAL DAY (MANDATORY RETURN ACTIVITY):');
        sb.writeln('        - All sightseeing and meals on Day $numberOfDays MUST conclude before ${resolvedDepartures.last.time}!');
        sb.writeln('        - The absolute LAST activity on Day $numberOfDays MUST be the return departure transfer:');
        sb.writeln('          * "destination": "${resolvedDepartures.last.location}"');
        sb.writeln('          * "activityCategory": "Transportation"');
        sb.writeln('          * "description": "Return travel: Depart from ${resolvedDepartures.last.location}${resolvedArrivals.length > 1 ? ' to ${resolvedArrivals.last.location}' : ''} via ${resolvedDepartures.last.type}"');
        sb.writeln('          * "endTime": "${resolvedDepartures.last.time}"');
        sb.writeln('          * "startTime": 45-90 minutes before ${resolvedDepartures.last.time}');
        sb.writeln('        - DO NOT schedule dinner or attractions after ${resolvedDepartures.last.time} on the final day!');
      } else {
        sb.writeln('    - FINAL DAY SCHEDULE:');
        sb.writeln('      * Final day concludes normally in the evening at 21:00 without an extra departure transfer.');
      }
      transitFlowPrompt = sb.toString();
    } else {
      // Foreign Traveler Flow:
      // START: Arrival into Malaysia at arrivals[0]
      // INTERMEDIATE: Departures[i] -> Arrivals[i+1]
      // END: Departures.last out of Malaysia
      final StringBuffer sb = StringBuffer();
      sb.writeln('    - FOREIGN TRAVELER ARRIVAL & DEPARTURE FLOW:');
      if (resolvedArrivals.isNotEmpty) {
        sb.writeln('      * Day 1 Arrival Time: $day1StartTime24H ($rawStartTime) at "${resolvedArrivals.first.location}" (${resolvedArrivals.first.type}).');
        sb.writeln('      * CRITICAL FOR DAY 1 START TIME:');
        sb.writeln('        The traveler only begins Day 1 upon arrival at $day1StartTime24H ($rawStartTime).');
        sb.writeln('        Day 1\'s very first activity MUST start strictly at $day1StartTime24H ("startTime": "$day1StartTime24H") with arrival transfer from "${resolvedArrivals.first.location}"!');
        sb.writeln('        NEVER schedule any activity before $day1StartTime24H on Day 1!');
      } else {
        sb.writeln('      * Day 1 Schedule: Day 1 starts normally at 09:00 with morning sightseeing or breakfast.');
      }

      if (resolvedArrivals.length > 1) {
        sb.writeln('    - Additional Transit Arrivals:');
        for (final a in resolvedArrivals.skip(1)) {
          sb.writeln('      * Arrival (${a.type}): ${a.location}${a.date.isNotEmpty ? ' on ${a.date}' : ''} at ${a.time}');
        }
      }

      if (hasFinalDeparture) {
        sb.writeln('    - Traveler Departure & Final Day End Time:');
        sb.writeln('      * Final Day (Day $numberOfDays) Departure Time: $finalDayEndTime24H ($rawDepartureTime) at "${resolvedDepartures.last.location}" (${resolvedDepartures.last.type}).');
        sb.writeln('      * CRITICAL FOR FINAL DAY END TIME:');
        sb.writeln('        All activities on Day $numberOfDays MUST conclude by $finalDayEndTime24H ($rawDepartureTime).');
        sb.writeln('        The absolute LAST activity on the final day MUST be:');
        sb.writeln('          * "destination": "${resolvedDepartures.last.location}"');
        sb.writeln('          * "activityCategory": "Transportation"');
        sb.writeln('          * "description": "Travel to ${resolvedDepartures.last.location} for departure via ${resolvedDepartures.last.type}"');
        sb.writeln('          * "endTime": "${resolvedDepartures.last.time}"');
        sb.writeln('          * "startTime": 45-90 minutes before ${resolvedDepartures.last.time}');
        sb.writeln('        ABSOLUTELY DO NOT schedule any activities after $finalDayEndTime24H on Day $numberOfDays!');
      } else {
        sb.writeln('    - FINAL DAY SCHEDULE:');
        sb.writeln('      * Final day concludes normally in the evening at 21:00 without an extra departure transfer.');
      }
      transitFlowPrompt = sb.toString();
    }

    final prompt =
        '''
    You are an expert travel planner. Please help me generate a travel itinerary in Malaysia.
    Details:
    - Destination: $destination (Malaysia)
    - Dates: $dates (Total: $numberOfDays days)
    - Target Total Budget: MYR $budget (Malaysian Ringgit, for the ENTIRE $numberOfDays-day trip)
    - Currency: All activity budgets, prices, and totals MUST be in Malaysian Ringgit (MYR).
    
    - ABSOLUTELY FORBIDDEN: NEVER include or recommend places from other cities or states (for example, if Destination is "$destination", you MUST ONLY choose places located within "$destination", Malaysia. DO NOT include places from other states outside of "$destination"!).
    - Suggesting places outside "$destination" is strictly forbidden and invalid.
    ${preference != null ? '- Preference: $preference (You MUST heavily prioritize planning activities that strictly match this theme!)' : ''}
$transitFlowPrompt
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
    - User's Wishlist Destinations requested (${wishlist.length} total): ${wishlist.join(', ')}.
    - MANDATORY HARD BUDGET LIMIT:
      * The total cost of the generated itinerary ("totalAllocatedBudget") MUST BE STRICTLY LESS THAN OR EQUAL TO MYR $budget! NEVER exceed MYR $budget!
      * AI Allocated Budget CANNOT exceed the user's budget ($budget).
    - BUDGET EVALUATION LOGIC FOR WISHLIST CAPACITY (DO NOT SQUEEZE ALL ITEMS IF INSUFFICIENT):
      * You MUST look at the user's budget first and calculate how many wishlist items it can ACTUALLY cover!
      * Do NOT force or cram all ${wishlist.length} items into the itinerary if the budget cannot afford them!
      * STEP 1: Calculate essential baseline expenses for $numberOfDays day(s):
        - Basic meals (local hawkers / mamak at MYR 5.00 - 8.00 per meal * 3 meals = ~MYR 18.00 - 24.00/day) and minimal transit.
      * STEP 2: The remaining budget is what is available for wishlist attraction entrance tickets.
      * STEP 3: Based on realistic entrance ticket prices for the user's wishlist (${wishlist.join(', ')}):
        - Determine how many wishlist items this remaining budget can genuinely cover!
        - If the budget can only afford 1 item: INCLUDE ONLY 1 WISHLIST ITEM!
        - If the budget can afford 2 items: INCLUDE ONLY 2 WISHLIST ITEMS!
        - If the budget can afford 3 items: INCLUDE ONLY 3 WISHLIST ITEMS!
        - Only if the budget can afford ALL ${wishlist.length} items alongside meals should all be included!
        - Do NOT set fake RM 5 ticket prices just to fit all items into an impossible budget.
      * STEP 4: Scheduling included vs omitted items:
        - For the affordable wishlist items that FIT within budget: schedule them in "activities" under their exact place name with realistic ticket costs.
        - For the wishlist items that CANNOT fit in budget: YOU MUST OMIT THEM from "activities"! Replace their slots with free public spots (parks, walking streets with allocatedBudget: 0.0).
      * STEP 5: Output consistency:
        - "wishlistItemsCoveredCount": MUST BE the EXACT count of wishlist items actually included in "activities" (e.g. 1, 2, or 3).
        - "estimatedExtraBudgetNeeded":
          + If "wishlistItemsCoveredCount" < ${wishlist.length}: Calculate the realistic additional MYR needed to cover ONLY the omitted/uncovered wishlist items!
          + If "wishlistItemsCoveredCount" == ${wishlist.length}: MUST BE 0.0! (If all wishlist items are covered within budget, ZERO extra budget is needed!).
    - Wishlist scheduling: Distribute any included wishlist items sensibly across the itinerary days.
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
    CRITICAL RULE FOR BUDGET & PRICING (REALISTIC BUDGETING):
    - The user provided a target budget of MYR $budget for the entire $numberOfDays-day trip.
    - HARD BUDGET LIMIT: "totalAllocatedBudget" MUST BE LESS THAN OR EQUAL TO MYR $budget (totalAllocatedBudget <= $budget). NEVER exceed MYR $budget!
    - PRICING GUIDELINES:
      * Meals: Hawker stalls, kopitiams, mamak eateries (MYR 5.00 - 12.00 per meal). Food is NEVER free (minimum MYR 4.00 per meal). If budget is extremely tight, schedule fewer or lighter meals within budget.
      * Transport: WALKING (MYR 0.0) whenever possible. Public transit (MYR 2.00 - 4.00) only when needed.
      * Non-wishlist attractions: MUST be FREE (public parks, heritage streets, temples, beaches, etc.) with allocatedBudget: 0.0.
      * Wishlist items: Prioritize including affordable wishlist items within MYR $budget. If an individual wishlist item cannot fit alongside necessary meals, omit it.
    - "totalAllocatedBudget" MUST equal the exact mathematical sum of all "allocatedBudget" fields in the activities list (and MUST be <= MYR $budget).
    - SHORTFALL & EXTRA BUDGET:
      * If any wishlist items were omitted due to budget constraints:
        - "estimatedExtraBudgetNeeded" MUST be the realistic extra amount needed to afford the omitted wishlist items.
      * If all wishlist items are included and totalAllocatedBudget <= $budget:
        - "estimatedExtraBudgetNeeded" = 0.0.
    '''}
    
    CRITICAL RULE FOR ROUTING:
    - Group activities geographically within "$destination"! Each day of the itinerary MUST focus on ONE specific area or neighborhood within "$destination" (for example, if "$destination" is Penang, Day 1 could focus on George Town Heritage Zone, Day 2 on Batu Ferringhi / Teluk Bahang, Day 3 on Bayan Lepas; if "$destination" is Melaka, Day 1 on Bandar Hilir / Jonker, Day 2 on Ayer Keroh).
    - Do NOT jump across distant parts of the city/state on the same day. Every single activity on a given "dayNumber" MUST be found within that day's designated area in "$destination" to minimize travel time.
    - Consecutive activities MUST be close to each other in real life to make routing practical.

    CRITICAL RULE FOR TIME SCHEDULING:
    - THIS IS THE MOST IMPORTANT RULE: You MUST generate an itinerary exactly for $numberOfDays day(s). If $numberOfDays is 3, return exactly 3 days. If $numberOfDays is 4, return exactly 4 days. The number of days returned MUST strictly match $numberOfDays!
    - The "dayNumber" MUST go sequentially from 1 up to exactly $numberOfDays. DO NOT generate less or more days than $numberOfDays!
    - Daily schedule timing:
      * Day 1 starts at $day1StartTime24H (the very first activity on Day 1 MUST have "startTime": "$day1StartTime24H").
      * The final day ends at $finalDayEndTime24H${hasFinalDeparture ? ' with the traveler reaching their departure hub "${resolvedDepartures.last.location}"' : ''}.
      * All intermediate days strictly start at 09:00 and end at 21:00.
      * Provide a complete continuous schedule filling the active hours, with connecting transportation between destinations.
    - The endTime of each activity must smoothly connect to the startTime of the next activity without large gaps.
    - Do not schedule any activities before $day1StartTime24H on Day 1, or after $finalDayEndTime24H on the final day. 
    - On intermediate days, the last activity of the day should reach 21:00.${hasFinalDeparture ? ' On the final day with departure, the final activity MUST be the departure transfer to "${resolvedDepartures.last.location}" ending at $finalDayEndTime24H.' : ''}

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
      "wishlistItemsCoveredCount": ${(wishlist != null && wishlist.isNotEmpty) ? (wishlist.length > 2 ? 2 : wishlist.length) : 0},
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
          "startTime": "$day1StartTime24H",
          "endTime": "...",
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
    - startTime/endTime (String): 24-hour format "HH:mm". Note: Day 1's first activity startTime MUST be "$day1StartTime24H".
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
            "generationConfig": {
              "responseMimeType": "application/json",
              "maxOutputTokens": 8192,
            },
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
        "generationConfig": {
          "responseMimeType": "application/json",
          "maxOutputTokens": 8192,
        },
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
    ${surroundingContext.isNotEmpty ? '\n    SURROUNDING ACTIVITIES (for geographic coherence):\n$surroundingContext    - The replacement MUST be within a short walk (roughly 15 minutes or less) of the surrounding activities listed above.\n    - Stay in the SAME neighbourhood / area as those activities. Do NOT suggest a place on the opposite side of the city.\n    - A restaurant and an attraction placed next to each other MUST be walkable, so the traveler never needs a long Grab ride between them.' : ''}
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
    - You MUST also return "minPrice": the minimum realistic cost you canNOT go below for this venue (a hawker meal can never drop below MYR 5, a paid attraction can never be free). It MUST be <= "allocatedBudget", and 0.0 only for genuinely free places.
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

  /// Generates a single transportation activity between two places.
  /// Used when an attraction is replaced and adjacent transport needs updating.
  static Future<String> askGeminiForTransportation({
    required String originPlace,
    required String destinationPlace,
    required String city,
  }) async {
    final prompt =
        '''
    You are an expert travel planner in Malaysia. A user's itinerary has changed and the transportation between two activities needs to be updated.

    CONTEXT:
    - City: $city
    - Origin (departing from): $originPlace
    - Destination (going to): $destinationPlace

    PROXIMITY & TRANSIT MODE RULE:
    - If the two places are CLOSE to each other (within walking distance, e.g. < 1km, adjacent streets, or within the same mall/complex):
      + Transit mode is WALKING: set "destination" to "Walk to $destinationPlace", "description" to a short sentence about the walk (e.g. "Short 5-10 min walk to the next venue"), "duration" to "5-15 min", and "allocatedBudget" to 0.0.
    - If the two places are FAR from each other (requiring motorized transit, different neighborhoods, or > 1km):
      + Transit mode is VEHICULAR (MRT, LRT, Bus, or Grab): set "destination" to the station, terminal, or transit route (e.g. "KLCC LRT Station", "Bukit Bintang MRT Station"), "description" to describe the transit route (e.g. "Take MRT Kajang Line from ... to ..."), "duration" to "15-30 min", and "allocatedBudget" to a realistic fare (e.g. MYR 1.00 - MYR 15.00).

    Format your response as a valid single JSON object:
    {
      "destination": "Walk to ... or Station Name",
      "imageKeyword": "Station name or landmark name for image lookup (e.g. 'KLCC LRT Station', 'Bukit Bintang MRT Station', 'Pavilion KL')",
      "description": "Short commute description",
      "duration": "10 min",
      "allocatedBudget": 0.0,
      "activityCategory": "Transportation"
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
      debugPrint('Gemini API Transportation Error: $e');
      throw Exception('Failed to generate transportation: $e');
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
    You are an expert travel planner in Malaysia acting as a budget recovery engine.
    The tourist has reached their budget ceiling. Re-plan their REMAINING itinerary slots so the whole trip still fits within the money left.

    CONTEXT:
    - Location / Base: $locationConstraint
    - Current Date/Time: ${currentDate?.toIso8601String() ?? DateTime.now().toIso8601String()}$tripEndInfo
    - Already Spent So Far: MYR ${currentSpentBudget.toStringAsFixed(2)}
    - Remaining Budget Ceiling (total for ALL slots below): MYR ${effectiveRemainingBudget.toStringAsFixed(2)}
    - Number of Remaining Slots: ${sanitizedRemainingSlots.length}

    REMAINING SLOTS TO RE-PLAN:
    ${jsonEncode(sanitizedRemainingSlots)}

    CRITICAL EXCLUSION LIST (DUPLICATES STRICTLY PROHIBITED):
    - Every "destination" in your response MUST be UNIQUE. Never use the same venue for two different slots.
    - Do NOT use slight variations of a name to bypass this rule (e.g. "Petronas Twin Towers" and "Petronas Towers" are the same venue).

    CRITICAL RULES:
    1. Strict Slot Count (1-to-1 Mapping):
       - You MUST return an array with EXACTLY ${sanitizedRemainingSlots.length} items.
       - For every slot, PRESERVE the exact "activitiesId" from the input. Do NOT generate new IDs.
       - Do NOT drop a slot and do NOT invent an extra one, even if the budget is very tight.
    2. Category Preservation:
       - Match the slot's original category. If the original slot was a restaurant/food category, replace it with an affordable local food spot/hawker stall; do NOT replace a meal slot with a park.
       - Use the "timeOfDay" hint: morning slots should have breakfast options, afternoon slots should have lunch options, evening slots should have dinner options.
    3. Budget Distribution:
       - The sum of ALL "allocatedBudget" values across the returned items MUST be <= MYR ${effectiveRemainingBudget.toStringAsFixed(2)}.
       - Distribute the budget sensibly across remaining days - do not spend everything on early slots and leave later days with nothing.
       - If remaining budget is MYR 0 or near 0, use free activities (public parks, walking tours, free galleries) and minimal meal costs (hawker food MYR 5-10).
       - Realistic Malaysian market rates: hawker meals MYR 5-15, casual restaurants MYR 15-40, attraction tickets MYR 10-80, public transit MYR 1-5.
       - NEVER invent a fake MYR 0.0 price for a restaurant or a paid attraction.
       - For every item you MUST also return "minPrice": the minimum realistic cost you canNOT go below for that venue (a hawker meal can never drop below MYR 5, a paid attraction can never be free). It MUST be <= "allocatedBudget", and 0.0 only for genuinely free places.
       - Public parks, walking tours, and free sights MUST have "allocatedBudget": 0.0.
       - "activityCategory" MUST strictly be one of: "Attraction", "Restaurant", "Transportation".
    4. Geographic Proximity:
       - All venues must be within close walking distance or short public transit of $locationConstraint. Never suggest cross-city travel.
       - Activities on the same date should be geographically close to each other for a practical day plan.
    5. Real, Verifiable Places:
       - Every destination MUST be an EXACT, FULL official business name or landmark that exists on Google Maps in $tripDestination. No generic names (e.g. "Local Eatery", "Museum Visit").
       - We programmatically verify each destination against Google Places API to fetch its photo. Obscure or non-existent venues are rejected, so only pick places guaranteed to have a Google Maps listing and photos.

    Output Schema:
    Return ONLY a raw JSON array matching this structure (no markdown fences, no backticks, no extra commentary):
    [
      {
        "activitiesId": "exact activitiesId from input",
        "destination": "Exact Business Name or Landmark",
        "description": "Short 1-sentence reason (e.g., Free entrance landmark near your current location)",
        "activityCategory": "Attraction",
        "allocatedBudget": 0.0,
        "minPrice": 0.0
      }
    ]
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
