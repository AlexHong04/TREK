import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../view_models/presentation_logic/home_view_model.dart';
import 'activity_screen.dart';
import '../models/local_data_source/location_source.dart';
import 'package:geolocator/geolocator.dart';
import '../main.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static Widget builder(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>(
      create: (context) => HomeViewModel(),
      child: const HomeScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appTheme.gray_50_02,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24.0),
                      _buildPageIndicator(),
                      const SizedBox(height: 20.0),
                      _buildGreeting(context),
                      const SizedBox(height: 32.0),
                      _buildPlanCard(context),
                      const SizedBox(height: 24.0),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo + Explorer
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: appTheme.teal_A700, width: 2),
                ),
                child: ClipOval(
                  child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Trek',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ).copyWith(color: appTheme.teal_A700, fontSize: 16),
              ),
            ],
          ),
          // Profile avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: appTheme.gray_200,
              border: Border.all(color: appTheme.gray_100, width: 1),
            ),
            child: ClipOval(
              child: Icon(
                Icons.person,
                color: appTheme.blue_gray_300,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: appTheme.teal_A700,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: appTheme.gray_200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, ${viewModel.uiState.displayName}',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
            color: appTheme.gray_900,
          ).copyWith(fontSize: 28, height: 1.2),
        ),
        const SizedBox(height: 6),
        Text(
          "Here's your plan for today",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            fontFamily: 'Inter',
            color: appTheme.gray_800,
          ).copyWith(color: appTheme.blue_gray_300, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildPlanCard(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    if (viewModel.uiState.isLoading) {
      return Container(
        width: double.infinity,
        height: 260,
        decoration: BoxDecoration(
          color: appTheme.gray_100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!viewModel.uiState.hasPlan || viewModel.uiState.latestTrip == null) {
      // Empty state placeholder
      return Container(
        width: double.infinity,
        height: 260,
        decoration: BoxDecoration(
          color: appTheme.gray_100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 48, color: appTheme.blue_gray_300),
              const SizedBox(height: 12),
              Text(
                'No plans yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Inter',
                  color: appTheme.gray_800,
                ).copyWith(color: appTheme.blue_gray_300),
              ),
            ],
          ),
        ),
      );
    }

    // Show existing plan card with dynamic data
    // Show the latest trip plan to able user to view what will be carry on
    final trip = viewModel.uiState.latestTrip!;
    final startDateStr = DateFormat('MMM dd').format(trip.startDate);
    final endDateStr = DateFormat('MMM dd, yyyy').format(trip.endDate);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.of(context).pushNamed(
              '/activityScreen',
              arguments: {
                'trip': trip,
                'isReadOnly': true,
              }
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Stack(
                  children: [
                    if (trip.imgUrl != null && trip.imgUrl!.isNotEmpty)
                      Image.network(
                        trip.imgUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        height: 140,
                        width: double.infinity,
                        color: appTheme.gray_200,
                        child: Icon(
                          Icons.terrain,
                          size: 48,
                          color: appTheme.blue_gray_300,
                        ),
                      ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: appTheme.amber_200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 14,
                              color: appTheme.lime_900,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              trip.status.substring(0, 1).toUpperCase() +
                                  trip.status.substring(1), // e.g. "Pending"
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                                color: appTheme.lime_900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.destination,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        color: appTheme.gray_900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: appTheme.gray_100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: appTheme.teal_A700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$startDateStr - $endDateStr',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Inter',
                                ).copyWith(color: appTheme.gray_800),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'RM${trip.totalBudget.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                            color: appTheme.gray_900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

  }

  // Start Plan button and Plan New button
  Widget _buildBottomButtons(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();

    // Determine if the start button is enabled based on user request:
    // "when pending disable when ongoing enable"
    final bool hasPlan = viewModel.uiState.hasPlan;
    final String? status = viewModel.uiState.latestTrip?.status;
    final bool isStartEnabled = hasPlan && status == 'ongoing';

    return Padding(
      padding: const EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        bottom: 28.0,
        top: 12.0,
      ),
      child: Column(
        children: [
          // Start Plan button
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                color: isStartEnabled ? appTheme.teal_A700 : appTheme.gray_200,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isStartEnabled
                    ? [
                        BoxShadow(
                          color: appTheme.teal_50,
                          offset: const Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
              ),
              child: Material(
                color: appTheme.transparentCustom,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: isStartEnabled
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Starting ongoing plan...'),
                            ),
                          );
                        }
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Start Plan',
                        style:
                            const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                            ).copyWith(
                              color: isStartEnabled
                                  ? appTheme.white_A700
                                  : appTheme.blue_gray_300,
                              height: 22 / 18,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Plan New button
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                color: appTheme.teal_A700,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: appTheme.teal_50,
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Material(
                color: appTheme.transparentCustom,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () async {
                    viewModel.prepareNewPlan();
                    await Navigator.of(
                      context,
                    ).pushNamed('/travelInformationInputScreen');

                    // Refresh the data when returning to home!
                    viewModel.fetchLatestTrip();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Plan New',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ).copyWith(color: appTheme.white_A700, height: 22 / 18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // const SizedBox(height: 16),
          // // Get Current Location button
          // SizedBox(
          //   width: double.infinity,
          //   child: Container(
          //     decoration: BoxDecoration(
          //       color: appTheme.teal_A700,
          //       borderRadius: BorderRadius.circular(14),
          //       boxShadow: [
          //         BoxShadow(
          //           color: appTheme.teal_50,
          //           offset: const Offset(0, 4),
          //           blurRadius: 8,
          //         ),
          //       ],
          //     ),
          //     child: Material(
          //       color: appTheme.transparentCustom,
          //       borderRadius: BorderRadius.circular(14),
          //       child: InkWell(
          //         onTap: () async {
          //           final locationSource = LocationSource();
          //
          //           // Check permissions first and show a dialog if denied
          //           LocationPermission permission = await Geolocator.checkPermission();
          //           if (permission == LocationPermission.denied) {
          //             permission = await Geolocator.requestPermission();
          //             if (permission == LocationPermission.denied && context.mounted) {
          //               showDialog(
          //                 context: context,
          //                 builder: (ctx) => AlertDialog(
          //                   title: const Text('Permission Required'),
          //                   content: const Text('Location permission is required to fetch your current location. Please allow it.'),
          //                   actions: [
          //                     TextButton(
          //                       onPressed: () => Navigator.of(ctx).pop(),
          //                       child: const Text('Cancel'),
          //                     ),
          //                     TextButton(
          //                       onPressed: () async {
          //                         Navigator.of(ctx).pop();
          //                         await Geolocator.requestPermission();
          //                       },
          //                       child: const Text('Grant'),
          //                     ),
          //                   ],
          //                 ),
          //               );
          //               return;
          //             }
          //           }
          //
          //           if (permission == LocationPermission.deniedForever && context.mounted) {
          //             showDialog(
          //               context: context,
          //               builder: (ctx) => AlertDialog(
          //                 title: const Text('Permission Denied'),
          //                 content: const Text('Location permission is permanently denied. Please enable it from app settings.'),
          //                 actions: [
          //                   TextButton(
          //                     onPressed: () => Navigator.of(ctx).pop(),
          //                     child: const Text('Cancel'),
          //                   ),
          //                   TextButton(
          //                     onPressed: () async {
          //                       Navigator.of(ctx).pop();
          //                       await Geolocator.openAppSettings();
          //                     },
          //                     child: const Text('Open Settings'),
          //                   ),
          //                 ],
          //               ),
          //             );
          //             return;
          //           }
          //
          //           final position = await locationSource.getCurrentLocation();
          //           if (context.mounted) {
          //             if (position != null) {
          //               ScaffoldMessenger.of(context).showSnackBar(
          //                 SnackBar(
          //                   content: Text(
          //                     'Location: ${position.latitude}, ${position.longitude}',
          //                   ),
          //                 ),
          //               );
          //             } else {
          //               ScaffoldMessenger.of(context).showSnackBar(
          //                 const SnackBar(
          //                   content: Text('Could not fetch location. Ensure GPS is enabled.'),
          //                 ),
          //               );
          //             }
          //           }
          //         },
          //         borderRadius: BorderRadius.circular(14),
          //         child: Padding(
          //           padding: const EdgeInsets.symmetric(vertical: 16),
          //           child: Center(
          //             child: Text(
          //               'Get Current Location',
          //               style: const TextStyle(
          //                 fontSize: 18,
          //                 fontWeight: FontWeight.w700,
          //                 fontFamily: 'Inter',
          //               ).copyWith(color: appTheme.white_A700, height: 22 / 18),
          //             ),
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
