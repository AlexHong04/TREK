import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../view_models/presentation_logic/travel_information_input_view_model.dart';

import '../main.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/app_time_picker.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/destination_spending_rates_dialog.dart';
import '../utils/malaysia_states.dart';
import '../utils/transit_schedule_helper.dart';
import '../view_models/ui_state/travel_information_ui_state.dart';

class TravelInformationInputScreen extends StatefulWidget {
  const TravelInformationInputScreen({super.key});

  static Widget builder(BuildContext context) {
    return const TravelInformationInputViewModelScope(
      child: TravelInformationInputScreen(),
    );
  }

  @override
  State<TravelInformationInputScreen> createState() =>
      _TravelInformationInputScreenState();
}

class _TravelInformationInputScreenState
    extends State<TravelInformationInputScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  late final TextEditingController _budgetController;
  late final TextEditingController _wishlistController;
  final List<TextEditingController> _hotelLocationControllers = [];
  String? _previousCurrency;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController();
    _budgetController = TextEditingController();
    _wishlistController = TextEditingController();
    _hotelLocationControllers.add(TextEditingController());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewModel = Provider.of<TravelInformationInputViewModel>(context);
    final currentCurrency = viewModel.preferredCurrency;
    if (_previousCurrency != null && _previousCurrency != currentCurrency) {
      final oldAmount = double.tryParse(_budgetController.text.trim());
      if (oldAmount != null && oldAmount > 0) {
        _convertBudgetOnCurrencyChange(
          viewModel: viewModel,
          oldAmount: oldAmount,
          fromCurrency: _previousCurrency!,
          toCurrency: currentCurrency,
        );
      }
    }
    _previousCurrency = currentCurrency;
  }

  Future<void> _convertBudgetOnCurrencyChange({
    required TravelInformationInputViewModel viewModel,
    required double oldAmount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    try {
      final newAmount = await viewModel.convertAmount(
        amount: oldAmount,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
      );
      if (newAmount != null && mounted) {
        final formatted = newAmount.toStringAsFixed(2);
        _budgetController.text = formatted.endsWith('.00')
            ? formatted.substring(0, formatted.length - 3)
            : formatted;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _dateController.dispose();
    _budgetController.dispose();
    _wishlistController.dispose();
    for (final c in _hotelLocationControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addArrivalAndDeparture(TravelInformationInputViewModel viewModel) {
    viewModel.addTransitLeg();
  }

  void _removeArrivalAndDeparture(
    int index,
    TravelInformationInputViewModel viewModel,
  ) {
    viewModel.removeTransitLeg(index);
  }

  void _syncHotelControllers(List<HotelStay> hotels) {
    while (_hotelLocationControllers.length < hotels.length) {
      final index = _hotelLocationControllers.length;
      _hotelLocationControllers.add(
        TextEditingController(text: hotels[index].location),
      );
    }
    while (_hotelLocationControllers.length > hotels.length) {
      _hotelLocationControllers.removeLast().dispose();
    }
    for (int i = 0; i < hotels.length; i++) {
      if (i < _hotelLocationControllers.length &&
          _hotelLocationControllers[i].text != hotels[i].location &&
          hotels[i].location.isEmpty) {
        _hotelLocationControllers[i].text = '';
      }
    }
  }

  void _addHotel(TravelInformationInputViewModel viewModel) {
    if (viewModel.uiState.selectedDestinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please select destination state(s) first before adding hotels.',
          ),
          backgroundColor: appTheme.redButton,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _hotelLocationControllers.add(TextEditingController());
    });
    viewModel.addHotel();
  }

  void _removeHotel(int index, TravelInformationInputViewModel viewModel) {
    if (_hotelLocationControllers.length > 1 &&
        index < _hotelLocationControllers.length) {
      setState(() {
        _hotelLocationControllers[index].dispose();
        _hotelLocationControllers.removeAt(index);
      });
      viewModel.removeHotel(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TravelInformationInputViewModel>();
    _syncHotelControllers(viewModel.uiState.hotels);

    return Scaffold(
      backgroundColor: appTheme.gray_50_02,
      appBar: const CustomAppBar(title: 'Travel Information'),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (viewModel.uiState.activeHotelField != null) {
                    viewModel.clearHotelSuggestions();
                  }
                  if (viewModel.uiState.suggestions.isNotEmpty) {
                    viewModel.clearSuggestions();
                  }
                },
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 22.0),
                      _buildDestinationSection(context, viewModel),
                      const SizedBox(height: 22.0),
                      CustomTextField(
                        sectionTitle: 'WISHLIST',
                        titleTrailing:
                            viewModel.uiState.wishlistItems.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _wishlistController.clear();
                                  viewModel.clearWishlist();
                                },
                                child: Text(
                                  'Clear all',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                    color: appTheme.teal_A700,
                                  ),
                                ),
                              )
                            : null,
                        hintText:
                            viewModel.uiState.selectedDestinations.isNotEmpty
                            ? 'Search places in ${viewModel.uiState.selectedDestinations.join(", ")}...'
                            : 'Search wishlist...',
                        prefixIcon: Icons.favorite_outline,
                        prefixIconColor: appTheme.teal_A700,
                        controller: _wishlistController,
                        inputFormatters: viewModel.wishlistInputFormatters,
                        errorText: viewModel.uiState.wishlistError,
                        validator: viewModel.validateExplicitWord,
                        // Wishlist items can only be added by tapping a
                        // suggestion, so submitting the field dismisses the keyboard.
                        textInputAction: TextInputAction.search,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).unfocus(),
                        onChanged: viewModel.onWishlistChanged,
                        bottomWidget: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (viewModel.uiState.isSearchingSuggestions) ...[
                              const SizedBox(height: 8.0),
                              LinearProgressIndicator(
                                minHeight: 2.0,
                                backgroundColor: appTheme.transparentCustom,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  appTheme.teal_A700,
                                ),
                              ),
                            ],
                            if (viewModel.uiState.suggestions.isNotEmpty) ...[
                              const SizedBox(height: 8.0),
                              Container(
                                decoration: BoxDecoration(
                                  color: appTheme.white_A700,
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: appTheme.gray_200,
                                    width: 1.0,
                                  ),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount:
                                      viewModel.uiState.suggestions.length,
                                  separatorBuilder: (context, index) => Divider(
                                    color: appTheme.gray_100,
                                    height: 1.0,
                                  ),
                                  itemBuilder: (context, index) {
                                    final suggestion =
                                        viewModel.uiState.suggestions[index];
                                    return ListTile(
                                      title: Text(
                                        suggestion,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.0,
                                          fontFamily: 'Inter',
                                          color: appTheme.gray_800,
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14.0,
                                        color: appTheme.blue_gray_300,
                                      ),
                                      dense: true,
                                      onTap: () {
                                        _wishlistController.clear();
                                        viewModel.addWishlistItem(suggestion);
                                        viewModel.clearSuggestions();
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                            if (viewModel.uiState.wishlistItems.isNotEmpty) ...[
                              const SizedBox(height: 12.0),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: viewModel.uiState.wishlistItems
                                    .map(
                                      (item) => _buildWishlistChip(
                                        item,
                                        () =>
                                            viewModel.removeWishlistItem(item),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 22.0),
                      CustomTextField(
                        sectionTitle: 'WHEN?',
                        hintText: 'Select dates',
                        prefixIcon: Icons.calendar_today_outlined,
                        prefixIconColor: appTheme.teal_A700,
                        controller: _dateController,
                        readOnly: true,
                        onTap: () => _pickTripDateRange(
                          context: context,
                          viewModel: viewModel,
                        ),
                        validator: viewModel.validateDate,
                      ),
                      const SizedBox(height: 22.0),
                      _buildArrivalDepartureSection(context, viewModel),
                      const SizedBox(height: 22.0),
                      _buildHotelSection(context, viewModel),
                      const SizedBox(height: 22.0),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _budgetController,
                        builder: (context, value, _) {
                          final double? enteredAmount = double.tryParse(
                            value.text.trim(),
                          );
                          final preferredCurrency = viewModel.preferredCurrency;

                          return CustomTextField(
                            sectionTitle: 'TRIP BUDGET ($preferredCurrency)',
                            titleTrailing: InkWell(
                              onTap: () => showDestinationSpendingRatesDialog(
                                context,
                                currentDestination:
                                    viewModel
                                        .uiState
                                        .selectedDestinations
                                        .isNotEmpty
                                    ? viewModel.uiState.selectedDestinations
                                          .join(', ')
                                    : null,
                                currency: preferredCurrency,
                                numberOfDays: viewModel.numberOfDays,
                                rateToMyr: viewModel.cachedRateToMyr,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: appTheme.teal_700,
                                ),
                              ),
                            ),
                            hintText: 'Total Trip Budget ($preferredCurrency)',
                            prefixIcon: Icons.account_balance_wallet_outlined,
                            prefixIconColor: appTheme.teal_A700,
                            controller: _budgetController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: viewModel.validateBudget,
                            warningText: viewModel.getBudgetSuggestion(value.text),
                            bottomWidget:
                                (enteredAmount != null && enteredAmount > 0)
                                ? (preferredCurrency != 'MYR'
                                      ? FutureBuilder<double?>(
                                          future: viewModel.getExchangeRate(
                                            fromCurrency: preferredCurrency,
                                            toCurrency: 'MYR',
                                          ),
                                          builder: (context, snapshot) {
                                            final rate = snapshot.data;
                                            final convertedMyr = rate != null
                                                ? enteredAmount * rate
                                                : null;
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14.0,
                                                    vertical: 10.0,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: appTheme.teal_50
                                                    .withValues(alpha: 0.45),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                                border: Border.all(
                                                  color: appTheme.teal_A700
                                                      .withValues(alpha: 0.2),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .currency_exchange_rounded,
                                                        size: 16,
                                                        color:
                                                            appTheme.teal_700,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Equivalent Value:',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontFamily: 'Inter',
                                                          color: appTheme
                                                              .blue_gray_700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        convertedMyr != null
                                                            ? '$preferredCurrency ${enteredAmount.toStringAsFixed(2)}'
                                                            : 'Converting...',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontFamily: 'Inter',
                                                          color:
                                                              appTheme.teal_800,
                                                        ),
                                                      ),
                                                      Text(
                                                        convertedMyr != null
                                                            ? 'MYR ${convertedMyr.toStringAsFixed(2)}'
                                                            : 'Calculating...',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontFamily: 'Inter',
                                                          color: appTheme
                                                              .blue_gray_700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14.0,
                                            vertical: 10.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: appTheme.teal_50.withValues(
                                              alpha: 0.45,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12.0,
                                            ),
                                            border: Border.all(
                                              color: appTheme.teal_A700
                                                  .withValues(alpha: 0.2),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .account_balance_wallet_outlined,
                                                    size: 16,
                                                    color: appTheme.teal_700,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Total Trip Budget:',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontFamily: 'Inter',
                                                      color: appTheme
                                                          .blue_gray_700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'MYR ${enteredAmount.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontFamily: 'Inter',
                                                      color: appTheme.teal_800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ))
                                : (viewModel
                                              .uiState
                                              .selectedDestinations
                                              .length >
                                          1
                                      ? Builder(
                                          builder: (context) {
                                            final rec = viewModel
                                                .getBudgetRecommendationForCurrentTrip();
                                            final rate =
                                                viewModel.cachedRateToMyr ??
                                                1.0;
                                            final minPref =
                                                preferredCurrency == 'MYR'
                                                ? rec.minTotalMyr
                                                : (rec.minTotalMyr /
                                                      (rate > 0 ? rate : 1.0));
                                            final minText =
                                                preferredCurrency == 'MYR'
                                                ? 'RM ${minPref.toStringAsFixed(0)}'
                                                : '$preferredCurrency ${minPref.toStringAsFixed(0)}';
                                            final destNames =
                                                rec
                                                    .matchedDestinations
                                                    .isNotEmpty
                                                ? rec.matchedDestinations.join(
                                                    ', ',
                                                  )
                                                : viewModel
                                                      .uiState
                                                      .selectedDestinations
                                                      .join(', ');
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14.0,
                                                    vertical: 9.0,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: appTheme.teal_50
                                                    .withValues(alpha: 0.45),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                                border: Border.all(
                                                  color: appTheme.teal_A700
                                                      .withValues(alpha: 0.2),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.insights_rounded,
                                                    size: 15,
                                                    color: appTheme.teal_700,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Combined Min ($destNames): $minText',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontFamily: 'Inter',
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            appTheme.teal_800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        )
                                      : null),
                          );
                        },
                      ),
                      const SizedBox(height: 22.0),
                      _buildTravelPreferencesSection(viewModel),
                      const SizedBox(height: 16.0),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomSection(viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelPreferencesSection(
    TravelInformationInputViewModel viewModel,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: appTheme.gray_100, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: appTheme.teal_A700, size: 16.0),
              const SizedBox(width: 6.0),
              Text(
                'TRAVEL PREFERENCES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: appTheme.blue_gray_300,
                  letterSpacing: 1,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: viewModel.preferences.map((pref) {
              bool isSelected =
                  viewModel.uiState.selectedPreference == pref.label;
              return GestureDetector(
                onTap: () => viewModel.selectPreference(pref.label),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: isSelected ? 10.0 : 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? appTheme.gray_50_01
                        : appTheme.transparentCustom,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: isSelected
                          ? appTheme.teal_A700
                          : appTheme.gray_200,
                      width: 2.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        pref.icon,
                        size: 18.0,
                        color: isSelected
                            ? appTheme.teal_A700
                            : appTheme.blue_gray_700,
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        pref.label,
                        style: TextStyle(fontSize: 14, fontFamily: 'Inter')
                            .copyWith(
                              color: isSelected
                                  ? appTheme.teal_A700
                                  : appTheme.blue_gray_700,
                              height: 1.21,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(TravelInformationInputViewModel viewModel) {
    return Container(
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        border: Border(top: BorderSide(color: appTheme.gray_50, width: 1.0)),
      ),
      padding: const EdgeInsets.only(
        top: 22.0,
        left: 24.0,
        right: 24.0,
        bottom: 24.0,
      ),
      child: Container(
        width: double.infinity,
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
              // Dismiss the keyboard first to prevent
              // RenderFlex overflow in the confirmation dialog.
              FocusScope.of(context).unfocus();
              await Future.delayed(const Duration(milliseconds: 100));
              if (!mounted) return;

              if (_formKey.currentState?.validate() ?? false) {
                final destination = viewModel.uiState.selectedDestinations.join(
                  ', ',
                );
                final error = viewModel.generateItinerary(
                  destination: destination,
                  date: _dateController.text,
                  budget: _budgetController.text,
                  wishlistQuery: _wishlistController.text,
                );
                if (error != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error)));
                  return;
                }

                final preferredCurrency = viewModel.preferredCurrency;
                final double? enteredBudget = double.tryParse(
                  _budgetController.text.trim(),
                );

                double? convertedBudgetInMyr;
                if (preferredCurrency != 'MYR' &&
                    enteredBudget != null &&
                    enteredBudget > 0) {
                  try {
                    convertedBudgetInMyr = await viewModel.convertToMyr(
                      enteredBudget,
                    );
                  } catch (_) {}
                }

                if (!mounted) return;

                final confirmed = await _showPlanGenerationConfirmDialog(
                  context: context,
                  destination: destination,
                  dates: _dateController.text,
                  budget: _budgetController.text,
                  currency: preferredCurrency,
                  convertedBudgetInMyr: convertedBudgetInMyr,
                  preference: viewModel.uiState.selectedPreference,
                  wishlistCount: viewModel.uiState.wishlistItems.length,
                  hotelCount: viewModel.uiState.hotels
                      .where((h) => h.location.trim().isNotEmpty)
                      .length,
                  arrivalCount: viewModel.uiState.arrivals
                      .where((a) => a.location.trim().isNotEmpty)
                      .length,
                  departureCount: viewModel.uiState.departures
                      .where((d) => d.location.trim().isNotEmpty)
                      .length,
                );

                if (confirmed != true || !mounted) return;

                final finalBudget =
                    (preferredCurrency != 'MYR' && convertedBudgetInMyr != null)
                    ? convertedBudgetInMyr.toStringAsFixed(2)
                    : _budgetController.text;

                Navigator.pushNamed(
                  context,
                  AppRoutes.wholeItineraryDetailScreen,
                  arguments: {
                    'destination': destination,
                    'dates': _dateController.text,
                    'budget': finalBudget,
                    'preferredCurrency': preferredCurrency,
                    'isForeign':
                        preferredCurrency.trim().toUpperCase() != 'MYR',
                    'preference': viewModel.uiState.selectedPreference,
                    'wishlist': viewModel.uiState.wishlistItems,
                    'arrivals': viewModel.uiState.arrivals
                        .map((e) => e.toJson())
                        .toList(),
                    'departures': viewModel.uiState.departures
                        .map((e) => e.toJson())
                        .toList(),
                    'arrivalLocation': viewModel.uiState.arrivalLocation,
                    'arrivalTime': viewModel.uiState.arrivalTime,
                    'arrivalDate': viewModel.uiState.arrivalDate,
                    'departureLocation': viewModel.uiState.departureLocation,
                    'departureTime': viewModel.uiState.departureTime,
                    'departureDate': viewModel.uiState.departureDate,
                    'hotels': viewModel.uiState.hotels
                        .map((e) => e.toJson())
                        .toList(),
                    'hotelLocation': viewModel.uiState.hotelLocation,
                    'hotelCheckInTime': viewModel.uiState.hotelCheckInTime,
                    'hotelCheckOutTime': viewModel.uiState.hotelCheckOutTime,
                  },
                );
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Generate Trip',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ).copyWith(color: appTheme.white_A700, height: 22 / 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showPlanGenerationConfirmDialog({
    required BuildContext context,
    required String destination,
    required String dates,
    required String budget,
    required String currency,
    double? convertedBudgetInMyr,
    required String? preference,
    required int wishlistCount,
    required int hotelCount,
    required int arrivalCount,
    required int departureCount,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          backgroundColor: appTheme.white_A700,
          elevation: 10.0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 24.0,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420.0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22.0, 24.0, 22.0, 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: appTheme.teal_50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.travel_explore_rounded,
                          color: appTheme.teal_A700,
                          size: 24.0,
                        ),
                      ),
                      const SizedBox(width: 14.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Generate Travel Plan?',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Inter',
                                color: appTheme.gray_900,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              'Please review your trip details',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                                color: appTheme.blue_gray_300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18.0),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14.0,
                              vertical: 12.0,
                            ),
                            decoration: BoxDecoration(
                              color: appTheme.gray_50_02,
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: appTheme.gray_100,
                                width: 1.0,
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildDialogInfoRow(
                                  icon: Icons.location_on_rounded,
                                  label: 'Destination',
                                  value: destination,
                                ),
                                Divider(color: appTheme.gray_100, height: 16.0),
                                _buildDialogInfoRow(
                                  icon: Icons.calendar_today_rounded,
                                  label: 'Dates',
                                  value: dates,
                                ),
                                Divider(color: appTheme.gray_100, height: 16.0),
                                _buildDialogInfoRow(
                                  icon: Icons.account_balance_wallet_rounded,
                                  label: 'Budget',
                                  value:
                                      (currency == 'MYR' ||
                                          convertedBudgetInMyr == null)
                                      ? '$currency $budget'
                                      : '$currency $budget (≈ MYR ${convertedBudgetInMyr.toStringAsFixed(2)})',
                                ),
                                if (preference != null &&
                                    preference.isNotEmpty) ...[
                                  Divider(
                                    color: appTheme.gray_100,
                                    height: 16.0,
                                  ),
                                  _buildDialogInfoRow(
                                    icon: Icons.tune_rounded,
                                    label: 'Preference',
                                    value: preference,
                                  ),
                                ],
                                if (wishlistCount > 0) ...[
                                  Divider(
                                    color: appTheme.gray_100,
                                    height: 16.0,
                                  ),
                                  _buildDialogInfoRow(
                                    icon: Icons.favorite_rounded,
                                    label: 'Wishlist',
                                    value: '$wishlistCount item(s)',
                                  ),
                                ],
                                if (hotelCount > 0) ...[
                                  Divider(
                                    color: appTheme.gray_100,
                                    height: 16.0,
                                  ),
                                  _buildDialogInfoRow(
                                    icon: Icons.hotel_rounded,
                                    label: 'Accommodation',
                                    value:
                                        '$hotelCount stay${hotelCount > 1 ? 's' : ''}',
                                  ),
                                ],
                                if (arrivalCount > 0 || departureCount > 0) ...[
                                  Divider(
                                    color: appTheme.gray_100,
                                    height: 16.0,
                                  ),
                                  _buildDialogInfoRow(
                                    icon: Icons.flight_takeoff_rounded,
                                    label: 'Transit',
                                    value:
                                        '${arrivalCount + departureCount} transit hub(s)',
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14.0),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 10.0,
                            ),
                            decoration: BoxDecoration(
                              color: appTheme.teal_50.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: appTheme.teal_A700.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 16.0,
                                  color: appTheme.teal_700,
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: Text(
                                    'AI will generate a personalized day-by-day itinerary. You can freely edit and customize activities afterwards.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Inter',
                                      color: appTheme.teal_800,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: appTheme.white_A700,
                            foregroundColor: const Color(0xFF718096),
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            elevation: 0,
                            side: BorderSide(
                              color: appTheme.gray_200,
                              width: 1.5,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                              color: Color(0xFF718096),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appTheme.teal_A700,
                            foregroundColor: appTheme.white_A700,
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            elevation: 2.0,
                            shadowColor: appTheme.teal_A700.withValues(
                              alpha: 0.35,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text(
                            'Confirm',
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15.0, color: appTheme.teal_A700),
        const SizedBox(width: 8.0),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
            color: appTheme.blue_gray_300,
          ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
              color: appTheme.gray_900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWishlistChip(String item, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: appTheme.gray_50_01, // Light teal background
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: appTheme.teal_A700, // Teal border
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              item,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                color: appTheme.teal_A700,
              ),
            ),
          ),
          const SizedBox(width: 6.0),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 16.0, color: appTheme.blue_gray_300),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationSection(
    BuildContext context,
    TravelInformationInputViewModel viewModel,
  ) {
    return FormField<List<String>>(
      initialValue: viewModel.uiState.selectedDestinations,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (_) => viewModel.validateDestinations(),
      builder: (FormFieldState<List<String>> field) {
        final selectedDestinations = viewModel.uiState.selectedDestinations;
        final hasError = field.hasError && selectedDestinations.isEmpty;

        if (selectedDestinations.isNotEmpty && field.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (field.mounted) {
              field.didChange(selectedDestinations);
              field.validate();
            }
          });
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24.0),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: appTheme.white_A700,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: hasError ? appTheme.redButton : appTheme.gray_100,
              width: hasError ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: appTheme.black_900_0c,
                offset: const Offset(0, 1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DESTINATION (MALAYSIA)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_300,
                      letterSpacing: 1,
                      height: 1.2,
                    ),
                  ),
                  if (selectedDestinations.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        viewModel.clearDestinations();
                        field.didChange(const []);
                        field.validate();
                      },
                      child: Text(
                        'Clear all',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          color: appTheme.teal_A700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10.0),
              InkWell(
                onTap: () async {
                  await _showDestinationSelectionModal(
                    context,
                    viewModel,
                    onSelectionChanged: () {
                      field.didChange(viewModel.uiState.selectedDestinations);
                      field.validate();
                    },
                  );
                  field.didChange(viewModel.uiState.selectedDestinations);
                  field.validate();
                },
                borderRadius: BorderRadius.circular(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: appTheme.teal_A700,
                      size: 20.0,
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: selectedDestinations.isEmpty
                          ? Text(
                              'Select destination state(s)...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Inter',
                                color: appTheme.blue_gray_300,
                              ),
                            )
                          : Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: [
                                ...selectedDestinations.map(
                                  (dest) => _buildDestinationChip(dest, () {
                                    viewModel.removeDestination(dest);
                                    field.didChange(
                                      viewModel.uiState.selectedDestinations,
                                    );
                                    field.validate();
                                  }),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    await _showDestinationSelectionModal(
                                      context,
                                      viewModel,
                                      onSelectionChanged: () {
                                        field.didChange(
                                          viewModel
                                              .uiState
                                              .selectedDestinations,
                                        );
                                        field.validate();
                                      },
                                    );
                                    field.didChange(
                                      viewModel.uiState.selectedDestinations,
                                    );
                                    field.validate();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10.0,
                                      vertical: 6.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: appTheme.gray_50_01,
                                      borderRadius: BorderRadius.circular(20.0),
                                      border: Border.all(
                                        color: appTheme.gray_200,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add,
                                          size: 14.0,
                                          color: appTheme.teal_A700,
                                        ),
                                        const SizedBox(width: 4.0),
                                        Text(
                                          'Add',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter',
                                            color: appTheme.teal_A700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 6.0),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: appTheme.blue_gray_300,
                      size: 24.0,
                    ),
                  ],
                ),
              ),
              if (hasError) ...[
                const SizedBox(height: 8.0),
                Text(
                  field.errorText ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: appTheme.errorRed,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDestinationChip(String destination, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: appTheme.gray_50_01,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: appTheme.teal_A700, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            destination,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
              color: appTheme.teal_A700,
            ),
          ),
          const SizedBox(width: 6.0),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14.0, color: appTheme.blue_gray_300),
          ),
        ],
      ),
    );
  }

  Future<void> _showDestinationSelectionModal(
    BuildContext context,
    TravelInformationInputViewModel viewModel, {
    VoidCallback? onSelectionChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: appTheme.transparentCustom,
      builder: (modalContext) {
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredList = allMalaysiaDestinations.where((dest) {
              return dest.name.toLowerCase().contains(
                searchQuery.toLowerCase().trim(),
              );
            }).toList();

            final selectedCount = viewModel.uiState.selectedDestinations.length;

            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: BoxDecoration(
                color: appTheme.white_A700,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24.0),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: appTheme.gray_200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Destination',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                                color: appTheme.gray_800,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              'States & Federal Territories of Malaysia',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Inter',
                                color: appTheme.blue_gray_300,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: appTheme.gray_800),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: appTheme.gray_50_01,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: appTheme.gray_200),
                      ),
                      child: TextField(
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val;
                          });
                        },
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Inter',
                          color: appTheme.gray_800,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search state...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Inter',
                            color: appTheme.blue_gray_300,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: appTheme.blue_gray_300,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12.0,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8.0),
                  Divider(height: 1.0, color: appTheme.gray_100),

                  // List of States
                  Expanded(
                    child: filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 48,
                                  color: appTheme.blue_gray_300,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No destinations found',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                    color: appTheme.blue_gray_300,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 12.0,
                            ),
                            itemCount: filteredList.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8.0),
                            itemBuilder: (context, index) {
                              final item = filteredList[index];
                              final isSelected = viewModel
                                  .uiState
                                  .selectedDestinations
                                  .contains(item.name);

                              return InkWell(
                                onTap: () {
                                  viewModel.toggleDestination(item.name);
                                  onSelectionChanged?.call();
                                  setModalState(() {});
                                },
                                borderRadius: BorderRadius.circular(12.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14.0,
                                    vertical: 12.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? appTheme.gray_50_01
                                        : appTheme.white_A700,
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(
                                      color: isSelected
                                          ? appTheme.teal_A700
                                          : appTheme.gray_100,
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8.0),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? appTheme.teal_50
                                              : appTheme.gray_50_01,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.map_outlined,
                                          size: 18.0,
                                          color: isSelected
                                              ? appTheme.teal_A700
                                              : appTheme.blue_gray_300,
                                        ),
                                      ),
                                      const SizedBox(width: 12.0),
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontFamily: 'Inter',
                                            color: isSelected
                                                ? appTheme.teal_A700
                                                : appTheme.gray_800,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked,
                                        color: isSelected
                                            ? appTheme.teal_A700
                                            : appTheme.gray_200,
                                        size: 22.0,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: appTheme.white_A700,
                      border: Border(
                        top: BorderSide(color: appTheme.gray_100, width: 1.0),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          if (selectedCount > 0) ...[
                            TextButton(
                              onPressed: () {
                                viewModel.clearDestinations();
                                onSelectionChanged?.call();
                                setModalState(() {});
                              },
                              child: Text(
                                'Clear All',
                                style: TextStyle(
                                  color: appTheme.blue_gray_700,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                          ],
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: appTheme.teal_A700,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14.0,
                                ),
                              ),
                              child: Text(
                                selectedCount == 0
                                    ? 'Done'
                                    : 'Confirm ($selectedCount Selected)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Inter',
                                  color: appTheme.white_A700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildArrivalDepartureSection(
    BuildContext context,
    TravelInformationInputViewModel viewModel,
  ) {
    final arrivals = viewModel.uiState.arrivals;
    final departures = viewModel.uiState.departures;
    final transitCount = arrivals.length > departures.length
        ? arrivals.length
        : departures.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: appTheme.gray_100, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            offset: const Offset(0, 1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MAIN TRANSIT (ARRIVAL & DEPARTURE) HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    transitCount > 1
                        ? 'ARRIVALS & DEPARTURES'
                        : 'ARRIVAL & DEPARTURE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_300,
                      letterSpacing: 1,
                      height: 1.2,
                    ),
                  ),
                  if (transitCount > 1) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: appTheme.gray_100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$transitCount',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                          color: appTheme.teal_A700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          if (viewModel.uiState.transitError != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: appTheme.redButton.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: appTheme.redButton.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16.0,
                    color: appTheme.redButton,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      viewModel.uiState.transitError!,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: appTheme.redButton,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // START HEADER
          Text(
              'START',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                color: appTheme.teal_700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8.0),

            // 1. ARRIVAL (START)
            _buildTransitLegArrivalCard(
              context: context,
              viewModel: viewModel,
              arrivalIndex: 0,
              cardTitle: 'ARRIVAL',
              isStartOrEnd: true,
            ),

            if (transitCount == 1) ...[
              const SizedBox(height: 14.0),
              _buildAddTransitMiddleButton(
                onTap: () => _addArrivalAndDeparture(viewModel),
              ),
              const SizedBox(height: 14.0),
              Divider(color: appTheme.gray_100, height: 1.0),
              const SizedBox(height: 14.0),
              // Bottom END
              Text(
                'END',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  color: appTheme.teal_700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8.0),
              _buildTransitLegDepartureCard(
                context: context,
                viewModel: viewModel,
                departureIndex: 0,
                cardTitle: 'DEPARTURE',
                minAllowedDate: DateTime.tryParse(arrivals[0].date),
                minAllowedDateString: arrivals[0].date,
                minAllowedTimeString: arrivals[0].time,
                constraintLabel:
                    'Departure time cannot be earlier than arrival time (${arrivals[0].time}).',
                isStartOrEnd: true,
              ),
            ] else ...[
              // Intermediate Transits: Transit 1 to Transit N-1
              for (int i = 0; i < transitCount - 1; i++) ...[
                const SizedBox(height: 14.0),
                Divider(color: appTheme.gray_100, height: 1.0),
                const SizedBox(height: 14.0),

                // TRANSIT HEADER with delete button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TRANSIT ${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        color: appTheme.teal_700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    InkWell(
                      onTap: () => _removeArrivalAndDeparture(i + 1, viewModel),
                      borderRadius: BorderRadius.circular(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18.0,
                          color: appTheme.blue_gray_300,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),

                // DEPARTURE
                _buildTransitLegDepartureCard(
                  context: context,
                  viewModel: viewModel,
                  departureIndex: i,
                  cardTitle: 'DEPARTURE (TRANSIT ${i + 1})',
                  minAllowedDate: i == 0
                      ? DateTime.tryParse(arrivals[0].date)
                      : DateTime.tryParse(arrivals[i].date),
                  minAllowedDateString: i == 0
                      ? arrivals[0].date
                      : arrivals[i].date,
                  minAllowedTimeString: i == 0
                      ? arrivals[0].time
                      : arrivals[i].time,
                  constraintLabel:
                      'Departure cannot be earlier than previous arrival.',
                ),
                const SizedBox(height: 12.0),

                // ARRIVAL
                _buildTransitLegArrivalCard(
                  context: context,
                  viewModel: viewModel,
                  arrivalIndex: i + 1,
                  cardTitle: 'ARRIVAL (TRANSIT ${i + 1})',
                  minAllowedDate: DateTime.tryParse(departures[i].date),
                  minAllowedDateString: departures[i].date,
                  minAllowedTimeString: departures[i].time,
                  constraintLabel: 'Arrival cannot be earlier than departure.',
                  autoSyncOnInvalid: true,
                ),
                const SizedBox(height: 12.0),

                // TRANSIT JOURNEY CARD
                _buildTransitConnectionCardFromPoints(
                  context: context,
                  viewModel: viewModel,
                  departurePoint: departures[i],
                  arrivalPoint: arrivals[i + 1],
                  journeyTitle: 'TRANSIT JOURNEY (Transit ${i + 1})',
                  syncArrivalIndex: i + 1,
                  originLabel: departures[i].location.isNotEmpty
                      ? departures[i].location
                      : 'Transit ${i + 1} Departure',
                  destinationLabel: arrivals[i + 1].location.isNotEmpty
                      ? arrivals[i + 1].location
                      : 'Transit ${i + 1} Arrival',
                ),
              ],

              const SizedBox(height: 14.0),
              // Middle Add Button
              _buildAddTransitMiddleButton(
                onTap: () => _addArrivalAndDeparture(viewModel),
              ),
              const SizedBox(height: 14.0),
              Divider(color: appTheme.gray_100, height: 1.0),
              const SizedBox(height: 14.0),

              // Bottom END
              Text(
                'END',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  color: appTheme.teal_700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8.0),

              // Bottom DEPARTURE (END)
              _buildTransitLegDepartureCard(
                context: context,
                viewModel: viewModel,
                departureIndex: transitCount - 1,
                cardTitle: 'DEPARTURE (END)',
                minAllowedDate: DateTime.tryParse(
                  arrivals[transitCount - 1].date,
                ),
                minAllowedDateString: arrivals[transitCount - 1].date,
                minAllowedTimeString: arrivals[transitCount - 1].time,
                constraintLabel:
                    'Final departure cannot be earlier than previous transit arrival.',
                isStartOrEnd: true,
              ),
            ],
          ],
        ),
      );
  }

  Widget _buildAddTransitMiddleButton({
    required VoidCallback onTap,
    String label = 'Add Transit',
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: appTheme.teal_50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: appTheme.teal_A700.withValues(alpha: 0.4),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: 16.0,
                  color: appTheme.teal_A700,
                ),
                const SizedBox(width: 6.0),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    color: appTheme.teal_A700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransitLegArrivalCard({
    required BuildContext context,
    required TravelInformationInputViewModel viewModel,
    required int arrivalIndex,
    required String cardTitle,
    DateTime? minAllowedDate,
    String? minAllowedDateString,
    String? minAllowedTimeString,
    String? constraintLabel,
    bool autoSyncOnInvalid = false,
    bool isStartOrEnd = false,
  }) {
    final arrivals = viewModel.uiState.arrivals;
    final arrival = arrivalIndex < arrivals.length
        ? arrivals[arrivalIndex]
        : (arrivals.isNotEmpty
              ? arrivals.first
              : const TransitPoint(id: 'arr_0'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cardTitle,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
            color: appTheme.blue_gray_300,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6.0),
        InkWell(
          onTap: () {
            String? connLoc;
            if (!isStartOrEnd && arrivalIndex > 0) {
              if (arrivalIndex - 1 < viewModel.uiState.departures.length) {
                final d = viewModel.uiState.departures[arrivalIndex - 1].location;
                if (d.isNotEmpty) connLoc = d;
              }
            } else if (isStartOrEnd && viewModel.uiState.departures.isNotEmpty) {
              final d = viewModel.uiState.departures.first.location;
              if (d.isNotEmpty) connLoc = d;
            }

            _showTransitHubSelectionModal(
              context,
              viewModel,
              isArrival: true,
              index: arrivalIndex,
              isStartOrEnd: isStartOrEnd,
              connectedLocation: connLoc,
            );
          },
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: appTheme.gray_50_01,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: arrival.location.isNotEmpty
                    ? appTheme.teal_A700.withValues(alpha: 0.35)
                    : appTheme.gray_200,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getArrivalTransitIcon(arrival.type),
                  color: appTheme.teal_A700,
                  size: 20,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    arrival.location.isNotEmpty
                        ? arrival.location
                        : _getArrivalPlaceholder(
                            arrival.type,
                            arrivalIndex,
                            arrivals.length,
                          ),
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: arrival.location.isNotEmpty
                          ? FontWeight.w600
                          : FontWeight.w400,
                      fontFamily: 'Inter',
                      color: arrival.location.isNotEmpty
                          ? appTheme.gray_800
                          : appTheme.blue_gray_300,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4.0),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: appTheme.blue_gray_300,
                  size: 18.0,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DATE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_300,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  _buildDatePickerButton(
                    context: context,
                    date: arrival.date,
                    isFullWidth: true,
                    onTap: () {
                      _pickTransitDate(
                        context: context,
                        viewModel: viewModel,
                        isArrival: true,
                        initialDateString: arrival.date,
                        minAllowedDate: minAllowedDate,
                        transitIndex: arrivalIndex,
                        onDatePicked: (d) =>
                            viewModel.updateArrivalDate(arrivalIndex, d),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TIME',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_300,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  _buildTimePickerButton(
                    context: context,
                    time: arrival.time,
                    isFullWidth: true,
                    onTap: () {
                      _pickTime(
                        context: context,
                        initialTimeString: arrival.time,
                        compareDate: arrival.date.isNotEmpty
                            ? arrival.date
                            : minAllowedDateString,
                        minAllowedDate: minAllowedDateString,
                        minAllowedTimeString: minAllowedTimeString,
                        constraintLabel: constraintLabel,
                        autoSyncOnInvalid: autoSyncOnInvalid,
                        onTimePicked: (t) =>
                            viewModel.updateArrivalTime(arrivalIndex, t),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransitLegDepartureCard({
    required BuildContext context,
    required TravelInformationInputViewModel viewModel,
    required int departureIndex,
    required String cardTitle,
    DateTime? minAllowedDate,
    String? minAllowedDateString,
    String? minAllowedTimeString,
    String? constraintLabel,
    bool isStartOrEnd = false,
  }) {
    final departures = viewModel.uiState.departures;
    final departure = departureIndex < departures.length
        ? departures[departureIndex]
        : (departures.isNotEmpty
              ? departures.first
              : const TransitPoint(id: 'dep_0'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cardTitle,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
            color: appTheme.blue_gray_300,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6.0),
        InkWell(
          onTap: () => _showTransitHubSelectionModal(
            context,
            viewModel,
            isArrival: false,
            index: departureIndex,
            isStartOrEnd: isStartOrEnd,
          ),
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: appTheme.gray_50_01,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: departure.location.isNotEmpty
                    ? appTheme.teal_A700.withValues(alpha: 0.35)
                    : appTheme.gray_200,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getDepartureTransitIcon(departure.type),
                  color: appTheme.teal_A700,
                  size: 20,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    departure.location.isNotEmpty
                        ? departure.location
                        : _getDeparturePlaceholder(
                            departure.type,
                            departureIndex,
                            departures.length,
                          ),
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: departure.location.isNotEmpty
                          ? FontWeight.w600
                          : FontWeight.w400,
                      fontFamily: 'Inter',
                      color: departure.location.isNotEmpty
                          ? appTheme.gray_800
                          : appTheme.blue_gray_300,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4.0),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: appTheme.blue_gray_300,
                  size: 18.0,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DATE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_300,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  _buildDatePickerButton(
                    context: context,
                    date: departure.date,
                    isFullWidth: true,
                    onTap: () {
                      _pickTransitDate(
                        context: context,
                        viewModel: viewModel,
                        isArrival: false,
                        initialDateString: departure.date,
                        minAllowedDate: minAllowedDate,
                        transitIndex: departureIndex,
                        onDatePicked: (d) =>
                            viewModel.updateDepartureDate(departureIndex, d),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TIME',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_300,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  _buildTimePickerButton(
                    context: context,
                    time: departure.time,
                    isFullWidth: true,
                    onTap: () {
                      _pickTime(
                        context: context,
                        initialTimeString: departure.time,
                        compareDate: departure.date,
                        minAllowedDate: minAllowedDateString,
                        minAllowedTimeString: minAllowedTimeString,
                        constraintLabel: constraintLabel,
                        onTimePicked: (t) =>
                            viewModel.updateDepartureTime(departureIndex, t),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransitConnectionCardFromPoints({
    required BuildContext context,
    required TravelInformationInputViewModel viewModel,
    required TransitPoint departurePoint,
    required TransitPoint arrivalPoint,
    required String journeyTitle,
    String? originLabel,
    String? destinationLabel,
    int? syncArrivalIndex,
  }) {
    final durationMin = TransitScheduleHelper.getEstimatedDurationMinutes(
      transitType: departurePoint.type.isNotEmpty
          ? departurePoint.type
          : (arrivalPoint.type.isNotEmpty ? arrivalPoint.type : 'Train'),
      fromLocation: departurePoint.location,
      toLocation: arrivalPoint.location,
      selectedDestinations: viewModel.uiState.selectedDestinations,
    );
    final durationStr = TransitScheduleHelper.formatDuration(durationMin);

    final depDate = departurePoint.date.isNotEmpty
        ? departurePoint.date
        : (viewModel.uiState.startDate?.toLocal().toString().split(' ')[0] ??
              DateTime.now().toLocal().toString().split(' ')[0]);
    final calculated = TransitScheduleHelper.calculateArrivalDateTime(
      departureDate: depDate,
      departureTimeStr: departurePoint.time,
      minutesToAdd: durationMin,
    );
    final isSynced =
        arrivalPoint.time == calculated['time'] &&
        (arrivalPoint.date.isEmpty || arrivalPoint.date == calculated['date']);

    final depLoc =
        originLabel ??
        (departurePoint.location.isNotEmpty
            ? departurePoint.location
            : 'Departure Station');
    final arrLoc =
        destinationLabel ??
        (arrivalPoint.location.isNotEmpty
            ? arrivalPoint.location
            : 'Arrival Destination');

    final isOvernight =
        departurePoint.date.isNotEmpty &&
        arrivalPoint.date.isNotEmpty &&
        departurePoint.date != arrivalPoint.date;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: appTheme.teal_50.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: appTheme.teal_A700.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _getDepartureTransitIcon(departurePoint.type),
                      size: 14.0,
                      color: appTheme.teal_700,
                    ),
                    const SizedBox(width: 5.0),
                    Expanded(
                      child: Text(
                        journeyTitle,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                          color: appTheme.teal_800,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6.0),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7.0,
                  vertical: 2.0,
                ),
                decoration: BoxDecoration(
                  color: appTheme.teal_A700,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 11.0,
                      color: appTheme.white_A700,
                    ),
                    const SizedBox(width: 3.0),
                    Text(
                      '~$durationStr',
                      style: TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        color: appTheme.white_A700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [
              // Origin
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      depLoc,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: appTheme.gray_800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      departurePoint.time.isNotEmpty
                          ? departurePoint.time
                          : '09:00 AM',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        color: appTheme.teal_800,
                      ),
                    ),
                    if (departurePoint.date.isNotEmpty)
                      Text(
                        departurePoint.date,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'Inter',
                          color: appTheme.blue_gray_300,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16.0,
                      color: appTheme.teal_700,
                    ),
                    Text(
                      durationStr,
                      style: TextStyle(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: appTheme.teal_700,
                      ),
                    ),
                  ],
                ),
              ),
              // Destination
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      arrLoc,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: appTheme.gray_800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isOvernight) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                              vertical: 1.0,
                            ),
                            margin: const EdgeInsets.only(right: 3.0),
                            decoration: BoxDecoration(
                              color: appTheme.teal_700.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              '+1d',
                              style: TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                                color: appTheme.teal_800,
                              ),
                            ),
                          ),
                        ],
                        Text(
                          arrivalPoint.time.isNotEmpty
                              ? arrivalPoint.time
                              : '01:30 PM',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                            color: appTheme.teal_800,
                          ),
                        ),
                      ],
                    ),
                    if (arrivalPoint.date.isNotEmpty)
                      Text(
                        arrivalPoint.date,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'Inter',
                          color: appTheme.blue_gray_300,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  departurePoint.type.toLowerCase() == 'bus'
                      ? 'Live OpenRouteService (ORS) Routing'
                      : 'Calculated for ${departurePoint.type} journey in Malaysia',
                  style: TextStyle(
                    fontSize: 10.0,
                    fontFamily: 'Inter',
                    fontStyle: FontStyle.italic,
                    color: departurePoint.type.toLowerCase() == 'bus'
                        ? appTheme.teal_700
                        : appTheme.blue_gray_300,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6.0),
              InkWell(
                onTap: () async {
                  if (syncArrivalIndex != null && syncArrivalIndex > 0) {
                    await viewModel.syncLegArrivalWithDepartureDurationAsync(
                      syncArrivalIndex,
                    );
                  } else {
                    final calcDate = calculated['date'] as String?;
                    final calcTime = calculated['time'] as String?;
                    if (calcDate != null && calcDate.isNotEmpty) {
                      viewModel.updateArrivalDate(
                        syncArrivalIndex ?? 0,
                        calcDate,
                      );
                    }
                    if (calcTime != null && calcTime.isNotEmpty) {
                      viewModel.updateArrivalTime(
                        syncArrivalIndex ?? 0,
                        calcTime,
                      );
                    }
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Arrival synced to departure + $durationStr duration.',
                        ),
                        backgroundColor: appTheme.teal_A700,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(6.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 2.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSynced
                            ? Icons.check_circle_rounded
                            : Icons.sync_rounded,
                        size: 12.0,
                        color: appTheme.teal_700,
                      ),
                      const SizedBox(width: 3.0),
                      Text(
                        isSynced ? 'Auto-Synced' : 'Auto-Sync Arrival',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          color: appTheme.teal_700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHotelSection(
    BuildContext context,
    TravelInformationInputViewModel viewModel,
  ) {
    final hotels = viewModel.uiState.hotels;
    final hasDestinations = viewModel.uiState.selectedDestinations.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: appTheme.gray_100, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            offset: const Offset(0, 1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HOTEL HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    hotels.length > 1
                        ? 'ACCOMMODATIONS / HOTELS'
                        : 'ACCOMMODATION / HOTEL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_300,
                      letterSpacing: 1,
                      height: 1.2,
                    ),
                  ),
                  if (hotels.length > 1) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: appTheme.gray_100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${hotels.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                          color: appTheme.teal_A700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              InkWell(
                onTap: () => _addHotel(viewModel),
                borderRadius: BorderRadius.circular(8.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 2.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 14.0,
                        color: hasDestinations
                            ? appTheme.teal_A700
                            : appTheme.blue_gray_300,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          color: hasDestinations
                              ? appTheme.teal_A700
                              : appTheme.blue_gray_300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!hasDestinations) ...[
            const SizedBox(height: 8.0),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xFFFFD54F)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16.0,
                    color: Color(0xFFF57F17),
                  ),
                  SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'Please select destination state(s) above first to enter hotel details.',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                        color: Color(0xFFF57F17),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10.0),

          // HOTELS LIST
          ...hotels.asMap().entries.map((entry) {
            final index = entry.key;
            final hotel = entry.value;
            final controller = index < _hotelLocationControllers.length
                ? _hotelLocationControllers[index]
                : null;
            final isCurrentActive =
                viewModel.uiState.activeHotelField == 'hotel_$index';

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == hotels.length - 1 ? 0.0 : 14.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hotels.length > 1) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'HOTEL ${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                            color: appTheme.blue_gray_300,
                            letterSpacing: 0.5,
                          ),
                        ),
                        InkWell(
                          onTap: () => _removeHotel(index, viewModel),
                          borderRadius: BorderRadius.circular(8.0),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18.0,
                              color: appTheme.blue_gray_300,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                  ],
                  TextFormField(
                    controller: controller,
                    readOnly: !hasDestinations,
                    validator: viewModel.validateExplicitWord,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onTap: () {
                      if (!hasDestinations) {
                        FocusScope.of(context).unfocus();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Please select destination state(s) first before entering hotel details.',
                            ),
                            backgroundColor: appTheme.redButton,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      viewModel.onHotelFocused(index);
                    },
                    onChanged: (text) =>
                        viewModel.onHotelLocationChanged(index, text),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                      color: hasDestinations
                          ? appTheme.gray_800
                          : appTheme.blue_gray_300,
                    ),
                    decoration: InputDecoration(
                      hintText: !hasDestinations
                          ? 'Select destination state(s) first...'
                          : (hotels.length > 1
                                ? 'Hotel ${index + 1} name or area'
                                : 'Hotel name or area (e.g. George Town)'),
                      hintStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Inter',
                        color: appTheme.blue_gray_300,
                      ),
                      errorStyle: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Inter',
                        color: appTheme.colorFFEF44,
                      ),
                      prefixIcon: Icon(
                        Icons.hotel_outlined,
                        color: hasDestinations
                            ? appTheme.teal_A700
                            : appTheme.blue_gray_300,
                        size: 20,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                    ),
                  ),
                  if (isCurrentActive) ...[
                    if (viewModel.uiState.isSearchingHotelSuggestions) ...[
                      const SizedBox(height: 6.0),
                      LinearProgressIndicator(
                        minHeight: 2.0,
                        backgroundColor: appTheme.transparentCustom,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          appTheme.teal_A700,
                        ),
                      ),
                    ],
                    if (viewModel.uiState.hotelSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 6.0),
                      _buildHotelSuggestionBox(
                        suggestions: viewModel.uiState.hotelSuggestions,
                        onSelect: (suggestion) {
                          if (controller != null) {
                            controller.text = suggestion;
                            controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: suggestion.length),
                            );
                          }
                          viewModel.selectHotelSuggestion(index, suggestion);
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 10.0),
                  // DATE PICKERS ROW
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CHECK-IN DATE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                                color: appTheme.blue_gray_300,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6.0),
                            _buildDatePickerButton(
                              context: context,
                              date: hotel.checkInDate,
                              isFullWidth: true,
                              onTap: () {
                                if (!hasDestinations) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Please select destination state(s) first before setting hotel dates.',
                                      ),
                                      backgroundColor: appTheme.redButton,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                _pickHotelDate(
                                  context: context,
                                  viewModel: viewModel,
                                  initialDateString: hotel.checkInDate,
                                  isCheckIn: true,
                                  hotel: hotel,
                                  onDatePicked: (d) =>
                                      viewModel.updateHotelCheckInDate(index, d),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CHECK-OUT DATE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                                color: appTheme.blue_gray_300,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6.0),
                            _buildDatePickerButton(
                              context: context,
                              date: hotel.checkOutDate,
                              isFullWidth: true,
                              onTap: () {
                                if (!hasDestinations) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Please select destination state(s) first before setting hotel dates.',
                                      ),
                                      backgroundColor: appTheme.redButton,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                _pickHotelDate(
                                  context: context,
                                  viewModel: viewModel,
                                  initialDateString: hotel.checkOutDate,
                                  isCheckIn: false,
                                  hotel: hotel,
                                  onDatePicked: (d) =>
                                      viewModel.updateHotelCheckOutDate(index, d),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  // TIME PICKERS ROW
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CHECK-IN TIME',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                                color: appTheme.blue_gray_300,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6.0),
                            _buildTimePickerButton(
                              context: context,
                              time: hotel.checkInTime,
                              isFullWidth: true,
                              onTap: () {
                                if (!hasDestinations) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Please select destination state(s) first before setting hotel times.',
                                      ),
                                      backgroundColor: appTheme.redButton,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                _pickTime(
                                  context: context,
                                  initialTimeString: hotel.checkInTime,
                                  onTimePicked: (t) => viewModel
                                      .updateHotelCheckInTime(index, t),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CHECK-OUT TIME',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                                color: appTheme.blue_gray_300,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6.0),
                            _buildTimePickerButton(
                              context: context,
                              time: hotel.checkOutTime,
                              isFullWidth: true,
                              onTap: () {
                                if (!hasDestinations) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Please select destination state(s) first before setting hotel times.',
                                      ),
                                      backgroundColor: appTheme.redButton,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                _pickTime(
                                  context: context,
                                  initialTimeString: hotel.checkOutTime,
                                  onTimePicked: (t) => viewModel
                                      .updateHotelCheckOutTime(index, t),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (index < hotels.length - 1) ...[
                    const SizedBox(height: 14.0),
                    Divider(color: appTheme.gray_100, height: 1.0),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDatePickerButton({
    required BuildContext context,
    required String date,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: appTheme.gray_50_01,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: date.isNotEmpty
                ? appTheme.teal_A700.withValues(alpha: 0.35)
                : appTheme.gray_200,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: isFullWidth
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 15.0,
              color: appTheme.teal_A700,
            ),
            const SizedBox(width: 6.0),
            Text(
              date.isNotEmpty ? date : 'Select date',
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: date.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                fontFamily: 'Inter',
                color: date.isNotEmpty
                    ? appTheme.teal_A700
                    : appTheme.blue_gray_300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTripDateRange({
    required BuildContext context,
    required TravelInformationInputViewModel viewModel,
  }) async {
    await viewModel.refreshExistingTrips();
    if (!context.mounted) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maxDate = today.add(const Duration(days: 365));

    final picked = await showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _TripDateRangePickerDialog(
        initialStartDate: viewModel.uiState.startDate,
        initialEndDate: viewModel.uiState.endDate,
        firstDate: today,
        lastDate: maxDate,
        unavailableDateRanges: viewModel.uiState.unavailableDateRanges,
      ),
    );

    if (picked == null) return;

    _dateController.text = viewModel.formatDateRange(picked.start, picked.end);
    viewModel.updateTripDates(picked.start, picked.end);
    if (_budgetController.text.trim().isNotEmpty) {
      _formKey.currentState?.validate();
    }
  }

  Future<void> _pickTransitDate({
    required BuildContext context,
    required TravelInformationInputViewModel viewModel,
    required bool isArrival,
    required String initialDateString,
    required ValueChanged<String> onDatePicked,
    DateTime? minAllowedDate,
    int transitIndex = 0,
  }) async {
    final startDate = viewModel.uiState.startDate;
    final endDate = viewModel.uiState.endDate;

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please select trip dates in the "WHEN?" section first.',
          ),
          backgroundColor: appTheme.redButton,
        ),
      );
      return;
    }

    final firstAllowed =
        (minAllowedDate != null && minAllowedDate.isAfter(startDate))
        ? minAllowedDate
        : startDate;
    final lastAllowed = endDate;
    final effectiveFirstAllowed = firstAllowed.isAfter(lastAllowed)
        ? lastAllowed
        : firstAllowed;

    DateTime initialDate = isArrival ? startDate : endDate;
    if (initialDateString.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(initialDateString.trim());
      if (parsed != null) {
        initialDate = parsed;
      }
    }
    if (initialDate.isBefore(effectiveFirstAllowed)) {
      initialDate = effectiveFirstAllowed;
    } else if (initialDate.isAfter(lastAllowed)) {
      initialDate = lastAllowed;
    }

    final picked = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: effectiveFirstAllowed,
      lastDate: lastAllowed,
      helpText: isArrival ? 'SELECT ARRIVAL DATE' : 'SELECT DEPARTURE DATE',
      selectableDayPredicate: (day) {
        final checkDate = DateTime(day.year, day.month, day.day);
        if (minAllowedDate != null) {
          final minDateOnly = DateTime(
            minAllowedDate.year,
            minAllowedDate.month,
            minAllowedDate.day,
          );
          if (checkDate.isBefore(minDateOnly)) {
            return false;
          }
        }
        if (checkDate.isBefore(startDate) || checkDate.isAfter(endDate)) {
          return false;
        }
        return true;
      },
    );

    if (picked != null) {
      final formatted = picked.toLocal().toString().split(' ')[0];
      onDatePicked(formatted);
    }
  }

  Future<void> _pickHotelDate({
    required BuildContext context,
    required TravelInformationInputViewModel viewModel,
    required String initialDateString,
    required bool isCheckIn,
    required ValueChanged<String> onDatePicked,
    HotelStay? hotel,
  }) async {
    final startDate = viewModel.uiState.startDate;
    final endDate = viewModel.uiState.endDate;

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please select trip dates in the "WHEN?" section first.',
          ),
          backgroundColor: appTheme.redButton,
        ),
      );
      return;
    }

    final otherDateStr = isCheckIn ? hotel?.checkOutDate : hotel?.checkInDate;
    final otherDate = (otherDateStr != null && otherDateStr.trim().isNotEmpty)
        ? DateTime.tryParse(otherDateStr.trim())
        : null;

    DateTime firstAllowed = startDate;
    DateTime lastAllowed = endDate;

    if (isCheckIn) {
      // Check-in date MUST be before check-out date (cannot be same day or after)
      if (otherDate != null) {
        lastAllowed = otherDate.subtract(const Duration(days: 1));
        if (lastAllowed.isBefore(startDate)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Check-out date is already on the first day of the trip. Please adjust check-out date first.',
              ),
              backgroundColor: appTheme.redButton,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
    } else {
      // Check-out date MUST be after check-in date (cannot be same day or before)
      if (otherDate != null) {
        firstAllowed = otherDate.add(const Duration(days: 1));
        if (firstAllowed.isAfter(endDate)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Check-in date is already on the last day of the trip. Please adjust check-in date first.',
              ),
              backgroundColor: appTheme.redButton,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
    }

    DateTime initialDate = isCheckIn ? firstAllowed : lastAllowed;
    if (initialDateString.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(initialDateString.trim());
      if (parsed != null) {
        initialDate = parsed;
      }
    }
    if (initialDate.isBefore(firstAllowed)) {
      initialDate = firstAllowed;
    } else if (initialDate.isAfter(lastAllowed)) {
      initialDate = lastAllowed;
    }

    final picked = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstAllowed,
      lastDate: lastAllowed,
      helpText: isCheckIn ? 'SELECT CHECK-IN DATE' : 'SELECT CHECK-OUT DATE',
      selectableDayPredicate: (day) {
        final checkDate = DateTime(day.year, day.month, day.day);
        if (checkDate.isBefore(firstAllowed) || checkDate.isAfter(lastAllowed)) {
          return false;
        }
        if (otherDate != null) {
          final normalizedOther =
              DateTime(otherDate.year, otherDate.month, otherDate.day);
          if (checkDate.isAtSameMomentAs(normalizedOther)) {
            return false;
          }
          if (isCheckIn && !checkDate.isBefore(normalizedOther)) {
            return false;
          }
          if (!isCheckIn && !checkDate.isAfter(normalizedOther)) {
            return false;
          }
        }
        return true;
      },
    );

    if (picked != null) {
      final formatted = picked.toLocal().toString().split(' ')[0];
      onDatePicked(formatted);
    }
  }

  int? _parseTimeToMinutes(String timeStr) {
    try {
      final trimmed = timeStr.trim();
      if (trimmed.isEmpty) return null;
      final parts = trimmed.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour < 12) {
        hour += 12;
      } else if (parts.length > 1 &&
          parts[1].toUpperCase() == 'AM' &&
          hour == 12) {
        hour = 0;
      }
      return hour * 60 + minute;
    } catch (_) {
      return null;
    }
  }

  Widget _buildTimePickerButton({
    required BuildContext context,
    required String time,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: appTheme.gray_50_01,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: appTheme.gray_200, width: 1.0),
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: isFullWidth
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 16.0,
              color: appTheme.teal_A700,
            ),
            const SizedBox(width: 6.0),
            Text(
              time,
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                color: appTheme.teal_A700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime({
    required BuildContext context,
    required String initialTimeString,
    required ValueChanged<String> onTimePicked,
    String? compareDate,
    String? minAllowedDate,
    String? minAllowedTimeString,
    String? constraintLabel,
    bool autoSyncOnInvalid = false,
  }) async {
    TimeOfDay initialTime = const TimeOfDay(hour: 9, minute: 0);
    try {
      final parts = initialTimeString.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour < 12) {
        hour += 12;
      } else if (parts.length > 1 &&
          parts[1].toUpperCase() == 'AM' &&
          hour == 12) {
        hour = 0;
      }
      initialTime = TimeOfDay(hour: hour, minute: minute);
    } catch (_) {}

    // Compute selectable constraint based on minAllowedTimeString and dates
    bool Function(TimeOfDay)? isSelectable;
    if (minAllowedTimeString != null && minAllowedTimeString.isNotEmpty) {
      final minMinutes = _parseTimeToMinutes(minAllowedTimeString);
      if (minMinutes != null) {
        final chosenD = (compareDate != null && compareDate.isNotEmpty)
            ? DateTime.tryParse(compareDate)
            : null;
        final minD = (minAllowedDate != null && minAllowedDate.isNotEmpty)
            ? DateTime.tryParse(minAllowedDate)
            : null;

        if (chosenD != null && minD != null) {
          final cDay = DateTime(chosenD.year, chosenD.month, chosenD.day);
          final mDay = DateTime(minD.year, minD.month, minD.day);
          if (cDay.isAtSameMomentAs(mDay)) {
            isSelectable = (t) => (t.hour * 60 + t.minute) >= minMinutes;
          } else if (cDay.isBefore(mDay)) {
            isSelectable = (_) => false;
          }
        } else {
          isSelectable = (t) => (t.hour * 60 + t.minute) >= minMinutes;
        }
      }
    }

    final picked = await showAppTimePicker(
      context: context,
      initialTime: initialTime,
      isSelectable: isSelectable,
    );

    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      final formatted = '${hour.toString().padLeft(2, '0')}:$minute $period';
      onTimePicked(formatted);
    }
  }

  IconData _getArrivalTransitIcon(String type) {
    switch (type.toLowerCase()) {
      case 'train':
        return Icons.directions_subway_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'flight':
      default:
        return Icons.flight_land_rounded;
    }
  }

  IconData _getDepartureTransitIcon(String type) {
    switch (type.toLowerCase()) {
      case 'train':
        return Icons.directions_subway_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'flight':
      default:
        return Icons.flight_takeoff_rounded;
    }
  }

  IconData _getTransitHubIcon(String type) {
    switch (type.toLowerCase()) {
      case 'train':
        return Icons.directions_subway_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'flight':
      default:
        return Icons.local_airport_rounded;
    }
  }

  String _getArrivalPlaceholder(String type, int index, int total) {
    return 'Select arrival type';
  }

  String _getDeparturePlaceholder(String type, int index, int total) {
    return 'Select departure type';
  }

  Future<void> _showTransitHubSelectionModal(
    BuildContext context,
    TravelInformationInputViewModel viewModel, {
    required bool isArrival,
    required int index,
    bool isStartOrEnd = false,
    String? connectedLocation,
  }) {
    final currentItem = isArrival
        ? (index < viewModel.uiState.arrivals.length
              ? viewModel.uiState.arrivals[index]
              : const TransitPoint(id: ''))
        : (index < viewModel.uiState.departures.length
              ? viewModel.uiState.departures[index]
              : const TransitPoint(id: ''));

    final currentSelected = currentItem.location;
    final String? lockedMode =
        (isArrival &&
            index > 0 &&
            index - 1 < viewModel.uiState.departures.length)
        ? viewModel.uiState.departures[index - 1].type
        : null;

    final initialMode = (lockedMode != null && lockedMode.isNotEmpty)
        ? lockedMode
        : (currentItem.type.isNotEmpty ? currentItem.type : 'Flight');

    final destinations = viewModel.uiState.selectedDestinations;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: appTheme.transparentCustom,
      builder: (modalContext) {
        String searchQuery = '';
        String activeMode = initialMode;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchQuery.trim().toLowerCase();

            final bool isFlightEnabled =
                lockedMode == null || lockedMode.toLowerCase() == 'flight';
            final bool isTrainEnabled =
                lockedMode == null || lockedMode.toLowerCase() == 'train';
            final bool isBusEnabled =
                lockedMode == null || lockedMode.toLowerCase() == 'bus';

            // 1. Raw candidate hubs: destination-recommended + all available hubs
            final List<String> rawRecommended = destinations.isNotEmpty
                ? getTransitHubSuggestions(
                    destinations,
                    transitType: activeMode,
                  )
                : <String>[];

            final allHubsFull = getAllTransitHubs(transitType: activeMode);
            final rawRecommendedSet = rawRecommended.toSet();
            final List<String> rawAll = allHubsFull
                .where((h) => !rawRecommendedSet.contains(h))
                .toList();

            // 2. Filter candidate hubs by direct route availability
            // If connectedLocation is known, ONLY show destinations with valid direct routes
            bool isHubReachable(String hub) {
              if (!isArrival || connectedLocation == null || connectedLocation.trim().isEmpty) {
                return true;
              }
              return TransitScheduleHelper.isRouteAvailable(
                transitType: activeMode,
                fromLocation: connectedLocation,
                toLocation: hub,
              );
            }

            final List<String> recommendedHubs =
                rawRecommended.where(isHubReachable).toList();
            final List<String> allHubs =
                rawAll.where(isHubReachable).toList();

            bool matchQuery(String hub) {
              if (query.isEmpty) return true;
              final h = hub.toLowerCase();
              if (h.contains(query)) return true;
              final normQ = query.replaceAll('central', 'sentral');
              final normH = h.replaceAll('central', 'sentral');
              return normH.contains(normQ);
            }

            // Apply search query filter to both lists
            final filteredRecommended = query.isEmpty
                ? recommendedHubs
                : recommendedHubs.where(matchQuery).toList();

            final filteredAll = query.isEmpty
                ? allHubs
                : allHubs.where(matchQuery).toList();

            final filteredHubs = [...filteredRecommended, ...filteredAll];

            final isTrain = activeMode.toLowerCase() == 'train';
            final isBus = activeMode.toLowerCase() == 'bus';

            final String typeLabel = isTrain
                ? 'Train Station'
                : (isBus ? 'Bus Terminal' : 'Airport');
            final String modalTitle = isArrival
                ? 'Select Arrival $typeLabel'
                : 'Select Departure $typeLabel';
            final String searchHint = isTrain
                ? 'Search train station (e.g. KL Sentral, Ipoh)...'
                : (isBus
                      ? 'Search bus terminal (e.g. TBS, KL Sentral, Larkin)...'
                      : 'Search airport or city (e.g. KLIA, Penang)...');

            final bool hasExactMatch = filteredHubs.any(
              (h) {
                final hLow = h.toLowerCase();
                if (hLow == query) return true;
                final normQ = query.replaceAll('central', 'sentral');
                final normH = hLow.replaceAll('central', 'sentral');
                return normH == normQ;
              },
            );
            final bool canAddCustom = query.isNotEmpty && !hasExactMatch;

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: appTheme.white_A700,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24.0),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: appTheme.gray_200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                modalTitle,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Inter',
                                  color: appTheme.gray_800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                destinations.isNotEmpty
                                    ? 'Destination: ${destinations.join(", ")}'
                                    : 'Select $typeLabel',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Inter',
                                  color: appTheme.blue_gray_300,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: appTheme.gray_800),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Mode Selector Tabs inside Modal
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 4.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: appTheme.gray_50_01,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: appTheme.gray_200),
                          ),
                          child: Row(
                            children: [
                              _buildModalModeTab(
                                icon: Icons.flight_rounded,
                                label: 'Flight',
                                isSelected:
                                    activeMode.toLowerCase() == 'flight',
                                isEnabled: isFlightEnabled,
                                onTap: () {
                                  if (!isFlightEnabled) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Transit ${index + 1} arrival category is locked to Transit $index departure ($lockedMode).',
                                        ),
                                        backgroundColor: appTheme.redButton,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }
                                  setModalState(() {
                                    activeMode = 'Flight';
                                  });
                                  if (isArrival) {
                                    viewModel.updateArrivalType(
                                      index,
                                      'Flight',
                                    );
                                  } else {
                                    viewModel.updateDepartureType(
                                      index,
                                      'Flight',
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 4.0),
                              _buildModalModeTab(
                                icon: Icons.directions_subway_rounded,
                                label: 'Train',
                                isSelected: activeMode.toLowerCase() == 'train',
                                isEnabled: isTrainEnabled,
                                onTap: () {
                                  if (!isTrainEnabled) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Transit ${index + 1} arrival category is locked to Transit $index departure ($lockedMode).',
                                        ),
                                        backgroundColor: appTheme.redButton,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }
                                  setModalState(() {
                                    activeMode = 'Train';
                                  });
                                  if (isArrival) {
                                    viewModel.updateArrivalType(index, 'Train');
                                  } else {
                                    viewModel.updateDepartureType(
                                      index,
                                      'Train',
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 4.0),
                              _buildModalModeTab(
                                icon: Icons.directions_bus_rounded,
                                label: 'Bus',
                                isSelected: activeMode.toLowerCase() == 'bus',
                                isEnabled: isBusEnabled,
                                onTap: () {
                                  if (!isBusEnabled) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Transit ${index + 1} arrival category is locked to Transit $index departure ($lockedMode).',
                                        ),
                                        backgroundColor: appTheme.redButton,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }
                                  setModalState(() {
                                    activeMode = 'Bus';
                                  });
                                  if (isArrival) {
                                    viewModel.updateArrivalType(index, 'Bus');
                                  } else {
                                    viewModel.updateDepartureType(index, 'Bus');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        if (lockedMode != null) ...[
                          const SizedBox(height: 6.0),
                          Row(
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 13,
                                color: appTheme.teal_700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Arrival category is locked to Transit $index departure ($lockedMode)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                  color: appTheme.teal_700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: appTheme.gray_50_01,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: appTheme.gray_200),
                      ),
                      child: TextField(
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val;
                          });
                        },
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Inter',
                          color: appTheme.gray_800,
                        ),
                        decoration: InputDecoration(
                          hintText: searchHint,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Inter',
                            color: appTheme.blue_gray_300,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: appTheme.blue_gray_300,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12.0,
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (currentSelected.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 4.0,
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: () {
                            if (isArrival) {
                              viewModel.updateArrivalLocation(index, '');
                            } else {
                              viewModel.updateDepartureLocation(index, '');
                            }
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Clear $typeLabel selection',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                              color: appTheme.errorRed,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 4.0),
                  Divider(height: 1.0, color: appTheme.gray_100),

                  // Hubs List
                  Expanded(
                    child: (filteredHubs.isEmpty && !canAddCustom)
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.alt_route_rounded,
                                    size: 48,
                                    color: appTheme.blue_gray_300,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    (connectedLocation != null && connectedLocation.trim().isNotEmpty)
                                        ? 'No direct $typeLabel routes available ${isArrival ? "from" : "to"}\n"$connectedLocation"'
                                        : (destinations.isNotEmpty
                                            ? 'No $typeLabel found for ${destinations.join(", ")}'
                                            : 'No $typeLabel options found'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.4,
                                      fontFamily: 'Inter',
                                      color: appTheme.blue_gray_300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 12.0,
                            ),
                            children: [
                              // Route connectivity hint banner (only when selecting arrival with a known departure)
                              if (isArrival && connectedLocation != null && connectedLocation.trim().isNotEmpty) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12.0),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: 8.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: appTheme.teal_50,
                                    borderRadius: BorderRadius.circular(8.0),
                                    border: Border.all(
                                      color: appTheme.teal_A700.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.alt_route_rounded,
                                        size: 16,
                                        color: appTheme.teal_A700,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Direct routes departing from: $connectedLocation',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter',
                                            color: appTheme.teal_A700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Custom entry option
                              if (canAddCustom) ...[
                                InkWell(
                                  onTap: () {
                                    final customName = searchQuery.trim();
                                    final explicitErr = viewModel
                                        .validateExplicitWord(customName);
                                    if (explicitErr != null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(explicitErr),
                                          backgroundColor: appTheme.redButton,
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                      return;
                                    }

                                    if (isArrival && connectedLocation != null && connectedLocation.trim().isNotEmpty) {
                                      final fromLoc = connectedLocation;
                                      final toLoc = customName;
                                      final routeOk = TransitScheduleHelper.isRouteAvailable(
                                        transitType: activeMode,
                                        fromLocation: fromLoc,
                                        toLocation: toLoc,
                                      );
                                      if (!routeOk) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('No direct $activeMode route available from "$connectedLocation" to "$customName"'),
                                            backgroundColor: appTheme.redButton,
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                        return;
                                      }
                                    }

                                    if (isArrival) {
                                      viewModel.updateArrivalHub(
                                        index,
                                        type: activeMode,
                                        location: customName,
                                      );
                                    } else {
                                      viewModel.updateDepartureHub(
                                        index,
                                        type: activeMode,
                                        location: customName,
                                      );
                                    }
                                    Navigator.pop(context);
                                  },
                                  borderRadius: BorderRadius.circular(12.0),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12.0),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14.0,
                                      vertical: 12.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: appTheme.teal_50,
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: appTheme.teal_A700,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.add_location_alt_rounded,
                                          size: 20,
                                          color: appTheme.teal_A700,
                                        ),
                                        const SizedBox(width: 10.0),
                                        Expanded(
                                          child: Text(
                                            'Use "${searchQuery.trim()}" as $typeLabel',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Inter',
                                              color: appTheme.teal_A700,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 14,
                                          color: appTheme.teal_A700,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              if (filteredRecommended.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        size: 14,
                                        color: appTheme.teal_A700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        destinations.isNotEmpty
                                            ? 'RECOMMENDED FOR ${destinations.join(", ").toUpperCase()}'
                                            : 'RECOMMENDED $typeLabel'.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'Inter',
                                          color: appTheme.teal_A700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...filteredRecommended.map((hub) {
                                  final isSelected = currentSelected == hub;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: _buildTransitHubModalItem(
                                      transitHub: hub,
                                      transitType: activeMode,
                                      isSelected: isSelected,
                                      isRecommended: true,
                                      onTap: () {
                                        if (isArrival) {
                                          viewModel.updateArrivalHub(
                                            index,
                                            type: activeMode,
                                            location: hub,
                                          );
                                        } else {
                                          viewModel.updateDepartureHub(
                                            index,
                                            type: activeMode,
                                            location: hub,
                                          );
                                        }
                                        Navigator.pop(context);
                                      },
                                    ),
                                  );
                                }),
                                if (filteredAll.isNotEmpty) ...[
                                  const SizedBox(height: 8.0),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10.0),
                                    child: Text(
                                      'OTHER AVAILABLE ${typeLabel.toUpperCase()}S',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Inter',
                                        color: appTheme.blue_gray_300,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ] else if (filteredAll.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: Text(
                                    'AVAILABLE ${typeLabel.toUpperCase()}S',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Inter',
                                      color: appTheme.blue_gray_300,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],

                              // Remaining available hubs
                              ...filteredAll.map((hub) {
                                final isSelected = currentSelected == hub;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: _buildTransitHubModalItem(
                                    transitHub: hub,
                                    transitType: activeMode,
                                    isSelected: isSelected,
                                    onTap: () {
                                      if (isArrival) {
                                        viewModel.updateArrivalHub(
                                          index,
                                          type: activeMode,
                                          location: hub,
                                        );
                                      } else {
                                        viewModel.updateDepartureHub(
                                          index,
                                          type: activeMode,
                                          location: hub,
                                        );
                                      }
                                      Navigator.pop(context);
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalModeTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.0),
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: isSelected
                  ? appTheme.teal_A700
                  : appTheme.transparentCustom,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14.0,
                  color: isSelected
                      ? appTheme.white_A700
                      : (isEnabled
                            ? appTheme.blue_gray_300
                            : appTheme.blue_gray_300.withValues(alpha: 0.6)),
                ),
                const SizedBox(width: 6.0),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontFamily: 'Inter',
                    color: isSelected
                        ? appTheme.white_A700
                        : (isEnabled
                              ? appTheme.gray_800
                              : appTheme.blue_gray_300),
                  ),
                ),
                if (!isEnabled) ...[
                  const SizedBox(width: 4.0),
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 11.0,
                    color: isSelected
                        ? appTheme.white_A700
                        : appTheme.blue_gray_300,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransitHubModalItem({
    required String transitHub,
    required String transitType,
    required bool isSelected,
    required VoidCallback onTap,
    bool isRecommended = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isSelected
              ? appTheme.gray_50_01
              : (isRecommended
                    ? appTheme.teal_50.withValues(alpha: 0.35)
                    : appTheme.white_A700),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isSelected
                ? appTheme.teal_A700
                : (isRecommended
                      ? appTheme.teal_A700.withValues(alpha: 0.35)
                      : appTheme.gray_100),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: (isSelected || isRecommended)
                    ? appTheme.teal_50
                    : appTheme.gray_50_01,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getTransitHubIcon(transitType),
                size: 18.0,
                color: (isSelected || isRecommended)
                    ? appTheme.teal_A700
                    : appTheme.blue_gray_300,
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                transitHub,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: (isSelected || isRecommended)
                      ? FontWeight.w700
                      : FontWeight.w500,
                  fontFamily: 'Inter',
                  color: isSelected ? appTheme.teal_A700 : appTheme.gray_800,
                ),
              ),
            ),
            if (isRecommended) ...[
              const SizedBox(width: 6.0),
              Icon(Icons.star_rounded, size: 16.0, color: appTheme.teal_A700),
              const SizedBox(width: 4.0),
            ],
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: isSelected ? appTheme.teal_A700 : appTheme.gray_200,
              size: 22.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotelSuggestionBox({
    required List<String> suggestions,
    required ValueChanged<String> onSelect,
  }) {
    final seen = <String>{};
    final uniqueSuggestions = suggestions.where((s) {
      final key = s
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r',\s*malaysia$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return key.isNotEmpty && seen.add(key);
    }).toList();

    if (uniqueSuggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: appTheme.gray_200, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: appTheme.black_900_0c,
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: uniqueSuggestions.length,
        separatorBuilder: (context, index) =>
            Divider(color: appTheme.gray_100, height: 1.0),
        itemBuilder: (context, index) {
          final suggestion = uniqueSuggestions[index];
          return ListTile(
            leading: Icon(
              Icons.hotel_rounded,
              size: 18.0,
              color: appTheme.teal_A700,
            ),
            title: Text(
              suggestion,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.0,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                color: appTheme.gray_800,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 13.0,
              color: appTheme.blue_gray_300,
            ),
            dense: true,
            visualDensity: const VisualDensity(vertical: -2),
            onTap: () => onSelect(suggestion),
          );
        },
      ),
    );
  }
}

class _TripDateRangePickerDialog extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final List<DateTimeRange> unavailableDateRanges;

  const _TripDateRangePickerDialog({
    required this.initialStartDate,
    required this.initialEndDate,
    required this.firstDate,
    required this.lastDate,
    required this.unavailableDateRanges,
  });

  @override
  State<_TripDateRangePickerDialog> createState() =>
      _TripDateRangePickerDialogState();
}

class _TripDateRangePickerDialogState
    extends State<_TripDateRangePickerDialog> {
  late DateTime _visibleMonth;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final start = widget.initialStartDate;
    final end = widget.initialEndDate;

    if (start != null && !_isUnavailable(start)) {
      _startDate = DateTime(start.year, start.month, start.day);
      if (end != null &&
          !end.isBefore(start) &&
          !_rangeHasUnavailable(
            _startDate!,
            DateTime(end.year, end.month, end.day),
          )) {
        _endDate = DateTime(end.year, end.month, end.day);
      }
      _visibleMonth = DateTime(_startDate!.year, _startDate!.month, 1);
    } else {
      _visibleMonth = DateTime(
        widget.firstDate.year,
        widget.firstDate.month,
        1,
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isUnavailable(DateTime day) {
    final checkDate = DateTime(day.year, day.month, day.day);
    if (checkDate.isBefore(widget.firstDate)) return true;
    if (checkDate.isAfter(widget.lastDate)) return true;
    for (final range in widget.unavailableDateRanges) {
      final rStart = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final rEnd = DateTime(range.end.year, range.end.month, range.end.day);
      if (!checkDate.isBefore(rStart) && !checkDate.isAfter(rEnd)) {
        return true;
      }
    }
    return false;
  }

  bool _rangeHasUnavailable(DateTime start, DateTime end) {
    DateTime cur = start;
    while (!cur.isAfter(end)) {
      if (_isUnavailable(cur)) return true;
      cur = cur.add(const Duration(days: 1));
    }
    return false;
  }

  bool get _canGoPrev {
    final prevMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    final minMonth = DateTime(widget.firstDate.year, widget.firstDate.month, 1);
    return !prevMonth.isBefore(minMonth);
  }

  bool get _canGoNext {
    final nextMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    final maxMonth = DateTime(widget.lastDate.year, widget.lastDate.month, 1);
    return !nextMonth.isAfter(maxMonth);
  }

  void _prevMonth() {
    if (_canGoPrev) {
      setState(() {
        _visibleMonth = DateTime(
          _visibleMonth.year,
          _visibleMonth.month - 1,
          1,
        );
      });
    }
  }

  void _nextMonth() {
    if (_canGoNext) {
      setState(() {
        _visibleMonth = DateTime(
          _visibleMonth.year,
          _visibleMonth.month + 1,
          1,
        );
      });
    }
  }

  void _onDayTapped(DateTime day) {
    if (_isUnavailable(day)) return;

    setState(() {
      _errorMessage = null;

      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = day;
        _endDate = null;
        return;
      }

      if (day.isBefore(_startDate!)) {
        _startDate = day;
        _endDate = null;
      } else if (day.isAtSameMomentAs(_startDate!)) {
        _endDate = day;
      } else {
        if (_rangeHasUnavailable(_startDate!, day)) {
          _errorMessage = 'Selected range overlaps an existing trip';
          _startDate = day;
          _endDate = null;
        } else {
          _endDate = day;
        }
      }
    });
  }

  String get _headerDateText {
    if (_startDate == null) return 'Select date';
    final startWeekdayStr = DateFormat('EEE, MMM d').format(_startDate!);
    if (_endDate == null) return startWeekdayStr;
    if (_isSameDay(_startDate!, _endDate!)) return startWeekdayStr;
    final startStr = DateFormat('MMM d').format(_startDate!);
    final endStr = DateFormat('MMM d').format(_endDate!);
    return '$startStr – $endStr';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: appTheme.white_A700,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 24.0,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 328.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Divider(height: 1.0, thickness: 1.0, color: appTheme.gray_100),
              _buildMonthNav(),
              const SizedBox(height: 4.0),
              _buildWeekdayLabels(),
              const SizedBox(height: 6.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: _buildCalendarGrid(),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8.0),
                _buildErrorMessage(),
              ],
              const SizedBox(height: 8.0),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 16.0, 12.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT TRIP DATES',
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: appTheme.blue_gray_300,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12.0),
          Text(
            _headerDateText,
            style: TextStyle(
              fontSize: 28.0,
              fontWeight: FontWeight.w400,
              color: appTheme.gray_800,
              fontFamily: 'Inter',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 4.0, 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_visibleMonth),
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  color: appTheme.gray_800,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 4.0),
              Icon(Icons.arrow_drop_down, size: 24.0, color: appTheme.gray_800),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 24.0),
                color: _canGoPrev
                    ? appTheme.gray_800
                    : appTheme.blue_gray_300.withValues(alpha: 0.38),
                onPressed: _canGoPrev ? _prevMonth : null,
                splashRadius: 20.0,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 24.0),
                color: _canGoNext
                    ? appTheme.gray_800
                    : appTheme.blue_gray_300.withValues(alpha: 0.38),
                onPressed: _canGoNext ? _nextMonth : null,
                splashRadius: 20.0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF757575),
                  fontFamily: 'Inter',
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadEmptyCount = firstDayOfMonth.weekday % 7;
    final totalCells = leadEmptyCount + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rowCount, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.0),
          child: Row(
            children: List.generate(7, (colIndex) {
              final cellIndex = rowIndex * 7 + colIndex;
              if (cellIndex < leadEmptyCount || cellIndex >= totalCells) {
                return const Expanded(child: SizedBox(height: 40.0));
              }
              final dayNum = cellIndex - leadEmptyCount + 1;
              final cellDate = DateTime(
                _visibleMonth.year,
                _visibleMonth.month,
                dayNum,
              );
              return Expanded(child: _buildDayCell(cellDate));
            }),
          ),
        );
      }),
    );
  }

  Widget _buildDayCell(DateTime cellDate) {
    final isUnavailable = _isUnavailable(cellDate);
    final isToday = _isSameDay(widget.firstDate, cellDate);
    final isStart = _startDate != null && _isSameDay(_startDate!, cellDate);
    final isEnd = _endDate != null && _isSameDay(_endDate!, cellDate);
    final hasRange =
        _startDate != null &&
        _endDate != null &&
        _endDate!.isAfter(_startDate!);
    final isInRange =
        hasRange &&
        cellDate.isAfter(_startDate!) &&
        cellDate.isBefore(_endDate!);
    final isRangeStart = isStart && hasRange;
    final isRangeEnd = isEnd && hasRange;

    final rangeBandColor = appTheme.teal_A700.withValues(alpha: 0.12);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth;
        final halfWidth = cellWidth / 2;

        return SizedBox(
          height: 40.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Continuous range band
              if (isInRange)
                Positioned.fill(child: Container(color: rangeBandColor)),
              if (isRangeStart)
                Positioned(
                  left: halfWidth,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(color: rangeBandColor),
                ),
              if (isRangeEnd)
                Positioned(
                  left: 0,
                  right: halfWidth,
                  top: 0,
                  bottom: 0,
                  child: Container(color: rangeBandColor),
                ),

              // Selected Start or End Date (solid Teal 40x40 circle)
              if (isStart || isEnd)
                GestureDetector(
                  onTap: () => _onDayTapped(cellDate),
                  child: Container(
                    width: 40.0,
                    height: 40.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: appTheme.teal_A700,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${cellDate.day}',
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w400,
                        color: appTheme.white_A700,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                )
              // Today (unselected) - Teal circle outline
              else if (isToday && !isInRange)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isUnavailable ? null : () => _onDayTapped(cellDate),
                    borderRadius: BorderRadius.circular(20.0),
                    child: Container(
                      width: 40.0,
                      height: 40.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: appTheme.teal_A700,
                          width: 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${cellDate.day}',
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: appTheme.teal_A700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                )
              // Other days
              else
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isUnavailable ? null : () => _onDayTapped(cellDate),
                    borderRadius: BorderRadius.circular(20.0),
                    child: Center(
                      child: Text(
                        '${cellDate.day}',
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: isInRange
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: isUnavailable
                              ? appTheme.gray_800.withValues(alpha: 0.38)
                              : appTheme.gray_800,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 13, color: Colors.red.shade700),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final bool canConfirm = _startDate != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                backgroundColor: appTheme.white_A700,
                foregroundColor: const Color(0xFF718096),
                padding: const EdgeInsets.symmetric(vertical: 13.0),
                elevation: 0,
                side: BorderSide(color: appTheme.gray_200, width: 1.5),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color: Color(0xFF718096),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: ElevatedButton(
              onPressed: canConfirm
                  ? () {
                      final start = _startDate!;
                      final end = _endDate ?? _startDate!;
                      Navigator.of(
                        context,
                      ).pop(DateTimeRange(start: start, end: end));
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: appTheme.teal_A700,
                disabledBackgroundColor: appTheme.teal_A700.withValues(
                  alpha: 0.35,
                ),
                foregroundColor: appTheme.white_A700,
                disabledForegroundColor: appTheme.white_A700.withValues(
                  alpha: 0.6,
                ),
                padding: const EdgeInsets.symmetric(vertical: 13.0),
                elevation: canConfirm ? 2.0 : 0,
                shadowColor: appTheme.teal_A700.withValues(alpha: 0.35),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
