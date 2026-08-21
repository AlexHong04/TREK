import 'dart:convert';
import 'package:http/http.dart' as http;

import '../entities/activity.dart';
import '../configurations/gemini_api_config.dart';
import '../repository/itinerary_repository.dart';
import '../../utils/id_generator.dart';

class ItineraryService {
  final ItineraryRepository _itineraryRepository = ItineraryRepository();

  Future<List<Activity>> generateItinerary({
    required String destination,
    required String dates,
    required String budget,
    String? preference,
    String? emergencyFund,
  }) async {
    try {
      final responseText = await GeminiApiConfig.askGeminiForItinerary(
        destination: destination,
        dates: dates,
        budget: budget,
        preference: preference,
        emergencyFund: emergencyFund,
      );

      // Extract JSON array
      final jsonMatch = RegExp(
        r'\[.*\]',
        dotAll: true,
      ).firstMatch(responseText);
      List<Activity> newActivities = [];
      if (jsonMatch != null) {
        final jsonString = jsonMatch.group(0)!;
        final List<dynamic> jsonList = jsonDecode(jsonString);
        int index = 1;
        String currentActId = 'AC0000';
        String currentDayTripId = IdGenerator.generateNextFormattedId(
          'DT',
          null,
        );

        for (var item in jsonList) {
          currentActId = IdGenerator.generateNextFormattedId(
            'AC',
            currentActId,
          );
          final allocatedBudget =
              (item['allocatedBudget'] as num?)?.toDouble() ?? 0.0;

          final destName = item['destination'] as String? ?? 'Activity';
          final imageKeyword = item['imageKeyword'] as String? ?? destName;

          String imgUrl = '';
          String finalDestinationTitle = destName;
          final query = Uri.encodeComponent(imageKeyword);

          // FREE TIER PRIORITY: English Wikipedia (Good for Title Accuracy and Landmarks)
          if (finalDestinationTitle == destName) {
            try {
              final wikiUrl = Uri.parse(
                'https://en.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=$query&gsrlimit=1&prop=pageimages&format=json&pithumbsize=600&origin=*',
              );
              final wikiRes = await http.get(wikiUrl);
              if (wikiRes.statusCode == 200) {
                final data = jsonDecode(wikiRes.body);
                final pages = data['query']?['pages'] as Map<String, dynamic>?;
                if (pages != null && pages.isNotEmpty) {
                  final page = pages.values.first;
                  // UPDATE Title Accuracy: Swap with Wikipedia's official article name!
                  if (page['title'] != null &&
                      !page['title'].toString().startsWith('File:')) {
                    finalDestinationTitle = page['title'];
                  }
                  if (page.containsKey('thumbnail') && imgUrl.isEmpty) {
                    imgUrl = page['thumbnail']['source'] as String? ?? '';
                  }
                }
              }
            } catch (_) {}
          }

          // FREE TIER PRIORITY: Wikimedia Commons (Richest media library for specific restaurants, streets, food)
          if (imgUrl.isEmpty) {
            try {
              // Use the corrected title for better media search
              final commonsQuery = Uri.encodeComponent(finalDestinationTitle);
              final commonsUrl = Uri.parse(
                'https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch=$commonsQuery&gsrnamespace=6&gsrlimit=1&prop=imageinfo&iiprop=url&iiurlwidth=600&format=json&origin=*',
              );
              final commonsRes = await http.get(commonsUrl);
              if (commonsRes.statusCode == 200) {
                final data = jsonDecode(commonsRes.body);
                final pages = data['query']?['pages'] as Map<String, dynamic>?;
                if (pages != null && pages.isNotEmpty) {
                  final page = pages.values.first;
                  if (page.containsKey('imageinfo')) {
                    final imageInfo = page['imageinfo'] as List;
                    if (imageInfo.isNotEmpty &&
                        imageInfo[0]['thumburl'] != null) {
                      imgUrl = imageInfo[0]['thumburl'] as String;
                    }
                  }
                }
              }
            } catch (_) {}
          }

          if (imgUrl.isEmpty) {
            // Fallback: Relax Flickr tags so it doesn't give random junk if it fails to find strict match
            final keywordQuery = Uri.encodeComponent(
              imageKeyword.replaceAll(RegExp(r'\s+'), ','),
            );
            imgUrl =
                'https://loremflickr.com/600/400/$keywordQuery?lock=$index';
          }

          int dayNumber = item['dayNumber'] as int? ?? 1;
          String startTimeStr = item['startTime'] as String? ?? '09:00';

          DateTime baseDate = DateTime.now().add(Duration(days: dayNumber - 1));
          DateTime parsedDate = baseDate;

          try {
            // Try parsing "09:00" assuming it's HH:mm
            final parts = startTimeStr.split(':');
            final h = int.parse(parts[0]);
            final m = int.parse(parts[1]);
            parsedDate = DateTime(
              baseDate.year,
              baseDate.month,
              baseDate.day,
              h,
              m,
            );
          } catch (_) {
            // keep baseDate if fail
          }

          newActivities.add(
            Activity(
              activitiesId: currentActId,
              dayTripId: currentDayTripId,
              destination: finalDestinationTitle,
              description: item['description'] as String? ?? '',
              activityImgUrl: imgUrl,
              date: parsedDate,
              allocatedBudget: allocatedBudget,
              overspendAmount: allocatedBudget > 0 ? 0 : null,
              status: 'pending',
              startTime: startTimeStr,
              endTime: item['endTime'] as String? ?? '10:00',
              duration: item['duration'] as String? ?? '60 min',
              activityCategory:
                  item['activityCategory'] as String? ?? 'General',
              isOverspend: false,
            ),
          );
          index++;
        }
      } else {
        throw Exception('No JSON found in response: $responseText');
      }
      return newActivities;
    } catch (e) {
      print('Service Error generating itinerary: $e');
      return [
        Activity(
          activitiesId: 'AC9999',
          dayTripId: 'DT9999',
          destination: 'Error Occurred',
          description: e.toString(),
          activityImgUrl: 'assets/logo.png',
          date: DateTime.now(),
          allocatedBudget: 0,
          overspendAmount: null,
          status: 'error',
          startTime: '00:00',
          endTime: '00:00',
          duration: '',
          activityCategory: 'Error',
          isOverspend: false,
        ),
      ];
    }
  }

  Future<bool> saveItinerary(
    List<Activity> activities, {
    required String destination,
    required String datesText,
    required String budgetText,
  }) async {
    if (activities.isEmpty) return false;

    double budget = 0;
    try {
      budget = double.parse(budgetText.replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (_) {}

    try {
      await _itineraryRepository.insertFullTrip(
        destination: destination,
        datesText: datesText,
        totalBudget: budget,
        activities: activities,
      );
      return true;
    } catch (e) {
      rethrow;
    }
  }
}
