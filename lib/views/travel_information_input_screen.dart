import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/presentation_logic/travel_information_input_view_model.dart';

import '../main.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';
import '../utils/malaysia_states.dart';
import '../view_models/ui_state/travel_information_ui_state.dart';

class TravelInformationInputScreen extends StatefulWidget {
  const TravelInformationInputScreen({super.key});

  static Widget builder(BuildContext context) {
    return ChangeNotifierProvider<TravelInformationInputViewModel>(
      create: (context) => TravelInformationInputViewModel(),
      child: const TravelInformationInputScreen(),
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

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController();
    _budgetController = TextEditingController();
    _wishlistController = TextEditingController();
    _hotelLocationControllers.add(TextEditingController());
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

  void _addArrival(TravelInformationInputViewModel viewModel) {
    viewModel.addArrival();
  }

  void _removeArrival(int index, TravelInformationInputViewModel viewModel) {
    viewModel.removeArrival(index);
  }

  void _addDeparture(TravelInformationInputViewModel viewModel) {
    viewModel.addDeparture();
  }

  void _removeDeparture(int index, TravelInformationInputViewModel viewModel) {
    viewModel.removeDeparture(index);
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
  }

  void _addHotel(TravelInformationInputViewModel viewModel) {
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
                      hintText:
                          viewModel.uiState.selectedDestinations.isNotEmpty
                          ? 'Search places in ${viewModel.uiState.selectedDestinations.join(", ")}...'
                          : 'Search wishlist...',
                      prefixIcon: Icons.favorite_outline,
                      prefixIconColor: appTheme.teal_A700,
                      controller: _wishlistController,
                      // Wishlist items can only be added by tapping a
                      // suggestion, so submitting the field dismisses the keyboard.
                      textInputAction: TextInputAction.search,
                      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
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
                                itemCount: viewModel.uiState.suggestions.length,
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
                                      () => viewModel.removeWishlistItem(item),
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
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: appTheme.teal_A700,
                                  onPrimary: appTheme.white_A700,
                                  surface: appTheme.white_A700,
                                  onSurface: appTheme.gray_800,
                                ),
                              ),
                              child: child!,
                            );
                          },
                          selectableDayPredicate:
                              (DateTime day, DateTime? start, DateTime? end) {
                                final checkDate = DateTime(
                                  day.year,
                                  day.month,
                                  day.day,
                                );
                                for (final range
                                    in viewModel
                                        .uiState
                                        .unavailableDateRanges) {
                                  if (checkDate.compareTo(range.start) >= 0 &&
                                      checkDate.compareTo(range.end) <= 0) {
                                    return false; // Disable if date falls within an existing trip
                                  }
                                }
                                return true;
                              },
                        );
                        if (picked != null) {
                          _dateController.text = viewModel.formatDateRange(
                            picked.start,
                            picked.end,
                          );
                        }
                      },
                      validator: viewModel.validateDate,
                    ),
                    const SizedBox(height: 22.0),
                    _buildArrivalDepartureSection(context, viewModel),
                    const SizedBox(height: 22.0),
                    _buildHotelSection(context, viewModel),
                    const SizedBox(height: 22.0),
                    CustomTextField(
                      sectionTitle: 'TRIP BUDGET',
                      hintText: 'Total Trip Budget (\$)',
                      prefixIcon: Icons.account_balance_wallet_outlined,
                      prefixIconColor: appTheme.teal_A700,
                      controller: _budgetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: viewModel.validateBudget,
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
            onTap: () {
              if (_formKey.currentState?.validate() ?? false) {
                final destination = viewModel.uiState.selectedDestinations.join(
                  ', ',
                );
                final error = viewModel.generateItinerary(
                  destination: destination,
                  date: _dateController.text,
                  budget: _budgetController.text,
                );
                if (error != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error)));
                } else {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.wholeItineraryDetailScreen,
                    arguments: {
                      'destination': destination,
                      'dates': _dateController.text,
                      'budget': _budgetController.text,
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
                      'departureLocation': viewModel.uiState.departureLocation,
                      'departureTime': viewModel.uiState.departureTime,
                      'hotels': viewModel.uiState.hotels
                          .map((e) => e.toJson())
                          .toList(),
                      'hotelLocation': viewModel.uiState.hotelLocation,
                      'hotelCheckInTime': viewModel.uiState.hotelCheckInTime,
                      'hotelCheckOutTime': viewModel.uiState.hotelCheckOutTime,
                    },
                  );
                }
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: appTheme.white_A700,
                    size: 20.0,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Generate trip',
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
      validator: (_) => viewModel.validateDestinations(),
      builder: (FormFieldState<List<String>> field) {
        final selectedDestinations = viewModel.uiState.selectedDestinations;
        final hasError = field.hasError;

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
                  await _showDestinationSelectionModal(context, viewModel);
                  field.didChange(viewModel.uiState.selectedDestinations);
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
                                  }),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    await _showDestinationSelectionModal(
                                      context,
                                      viewModel,
                                    );
                                    field.didChange(
                                      viewModel.uiState.selectedDestinations,
                                    );
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
                                            fontSize: 13,
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
              fontSize: 13,
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
    TravelInformationInputViewModel viewModel,
  ) {
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
          // ARRIVALS HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    arrivals.length > 1 ? 'ARRIVALS' : 'ARRIVAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_300,
                      letterSpacing: 1,
                      height: 1.2,
                    ),
                  ),
                  if (arrivals.length > 1) ...[
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
                        '${arrivals.length}',
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
                onTap: () => _addArrival(viewModel),
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
                        color: appTheme.teal_A700,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12.0,
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
          const SizedBox(height: 8.0),

          // ARRIVALS LIST
          ...arrivals.asMap().entries.map((entry) {
            final index = entry.key;
            final arrival = entry.value;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == arrivals.length - 1 ? 0.0 : 8.0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showAirportSelectionModal(
                        context,
                        viewModel,
                        isArrival: true,
                        index: index,
                      ),
                      borderRadius: BorderRadius.circular(10.0),
                      child: Container(
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
                              Icons.flight_land_rounded,
                              color: appTheme.teal_A700,
                              size: 18,
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                arrival.location.isNotEmpty
                                    ? arrival.location
                                    : (arrivals.length > 1
                                        ? 'Select arrival airport ${index + 1}'
                                        : 'Select arrival airport'),
                                style: TextStyle(
                                  fontSize: 13.5,
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
                  ),
                  const SizedBox(width: 8.0),
                  _buildTimePickerButton(
                    context: context,
                    time: arrival.time,
                    onTap: () => _pickTime(
                      context: context,
                      initialTimeString: arrival.time,
                      onTimePicked: (t) =>
                          viewModel.updateArrivalTime(index, t),
                    ),
                  ),
                  if (arrivals.length > 1) ...[
                    const SizedBox(width: 4.0),
                    InkWell(
                      onTap: () => _removeArrival(index, viewModel),
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
                ],
              ),
            );
          }),

          const SizedBox(height: 10.0),

          const SizedBox(height: 14.0),
          Divider(color: appTheme.gray_100, height: 1.0),
          const SizedBox(height: 14.0),

          // DEPARTURES HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    departures.length > 1 ? 'DEPARTURES' : 'DEPARTURE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_300,
                      letterSpacing: 1,
                      height: 1.2,
                    ),
                  ),
                  if (departures.length > 1) ...[
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
                        '${departures.length}',
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
                onTap: () => _addDeparture(viewModel),
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
                        color: appTheme.teal_A700,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12.0,
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
          const SizedBox(height: 8.0),

          // DEPARTURES LIST
          ...departures.asMap().entries.map((entry) {
            final index = entry.key;
            final departure = entry.value;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == departures.length - 1 ? 0.0 : 8.0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showAirportSelectionModal(
                        context,
                        viewModel,
                        isArrival: false,
                        index: index,
                      ),
                      borderRadius: BorderRadius.circular(10.0),
                      child: Container(
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
                              Icons.flight_takeoff_rounded,
                              color: appTheme.teal_A700,
                              size: 18,
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                departure.location.isNotEmpty
                                    ? departure.location
                                    : (departures.length > 1
                                        ? 'Select departure airport ${index + 1}'
                                        : 'Select departure airport'),
                                style: TextStyle(
                                  fontSize: 13.5,
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
                  ),
                  const SizedBox(width: 8.0),
                  _buildTimePickerButton(
                    context: context,
                    time: departure.time,
                    onTap: () => _pickTime(
                      context: context,
                      initialTimeString: departure.time,
                      onTimePicked: (t) =>
                          viewModel.updateDepartureTime(index, t),
                    ),
                  ),
                  if (departures.length > 1) ...[
                    const SizedBox(width: 4.0),
                    InkWell(
                      onTap: () => _removeDeparture(index, viewModel),
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
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHotelSection(
    BuildContext context,
    TravelInformationInputViewModel viewModel,
  ) {
    final hotels = viewModel.uiState.hotels;

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
                        color: appTheme.teal_A700,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12.0,
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
                  TextField(
                    controller: controller,
                    onTap: () => viewModel.onHotelFocused(index),
                    onChanged: (text) =>
                        viewModel.onHotelLocationChanged(index, text),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                      color: appTheme.gray_800,
                    ),
                    decoration: InputDecoration(
                      hintText: hotels.length > 1
                          ? 'Hotel ${index + 1} name or area'
                          : 'Hotel name or area (e.g. George Town)',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Inter',
                        color: appTheme.blue_gray_300,
                      ),
                      prefixIcon: Icon(
                        Icons.hotel_outlined,
                        color: appTheme.teal_A700,
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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CHECK-IN',
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
                              onTap: () => _pickTime(
                                context: context,
                                initialTimeString: hotel.checkInTime,
                                onTimePicked: (t) =>
                                    viewModel.updateHotelCheckInTime(index, t),
                              ),
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
                              'CHECK-OUT',
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
                              onTap: () => _pickTime(
                                context: context,
                                initialTimeString: hotel.checkOutTime,
                                onTimePicked: (t) =>
                                    viewModel.updateHotelCheckOutTime(index, t),
                              ),
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

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: appTheme.teal_A700,
              onPrimary: appTheme.white_A700,
              surface: appTheme.white_A700,
              onSurface: appTheme.gray_800,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      final formatted = '${hour.toString().padLeft(2, '0')}:$minute $period';
      onTimePicked(formatted);
    }
  }

  Future<void> _showAirportSelectionModal(
    BuildContext context,
    TravelInformationInputViewModel viewModel, {
    required bool isArrival,
    required int index,
  }) {
    final currentSelected = isArrival
        ? (index < viewModel.uiState.arrivals.length
            ? viewModel.uiState.arrivals[index].location
            : '')
        : (index < viewModel.uiState.departures.length
            ? viewModel.uiState.departures[index].location
            : '');

    final destinations = viewModel.uiState.selectedDestinations;
    final recommendedAirports = getTransitHubSuggestions(destinations);
    final allAirports = getAllMalaysiaAirports();

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: appTheme.transparentCustom,
      builder: (modalContext) {
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchQuery.trim().toLowerCase();

            final filteredRecommended = query.isEmpty
                ? recommendedAirports
                : recommendedAirports
                    .where((a) => a.toLowerCase().contains(query))
                    .toList();

            final otherAirports = allAirports
                .where((a) => !recommendedAirports.contains(a))
                .toList();

            final filteredOthers = query.isEmpty
                ? otherAirports
                : otherAirports
                    .where((a) => a.toLowerCase().contains(query))
                    .toList();

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
                              isArrival
                                  ? 'Select Arrival Airport'
                                  : 'Select Departure Airport',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                                color: appTheme.gray_800,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              destinations.isNotEmpty
                                  ? 'Based on destination: ${destinations.join(", ")}'
                                  : 'Major Commercial Airports of Malaysia',
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
                          hintText: 'Search airport or city (e.g. KLIA, Penang)...',
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
                            'Clear airport selection',
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

                  // Airport List
                  Expanded(
                    child: (filteredRecommended.isEmpty && filteredOthers.isEmpty)
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
                                  'No airports found',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                    color: appTheme.blue_gray_300,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 12.0,
                            ),
                            children: [
                              if (destinations.isNotEmpty &&
                                  filteredRecommended.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.stars_rounded,
                                      size: 15,
                                      color: appTheme.teal_A700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'RECOMMENDED FOR YOUR TRIP',
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
                                const SizedBox(height: 8.0),
                                ...filteredRecommended.map((airport) {
                                  final isSelected = currentSelected == airport;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: _buildAirportModalItem(
                                      airport: airport,
                                      isSelected: isSelected,
                                      isRecommended: true,
                                      onTap: () {
                                        if (isArrival) {
                                          viewModel.updateArrivalLocation(
                                            index,
                                            airport,
                                          );
                                        } else {
                                          viewModel.updateDepartureLocation(
                                            index,
                                            airport,
                                          );
                                        }
                                        Navigator.pop(context);
                                      },
                                    ),
                                  );
                                }),
                                const SizedBox(height: 12.0),
                              ],

                              if (filteredOthers.isNotEmpty) ...[
                                if (destinations.isNotEmpty &&
                                    filteredRecommended.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text(
                                      'OTHER MALAYSIA AIRPORTS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Inter',
                                        color: appTheme.blue_gray_300,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ...filteredOthers.map((airport) {
                                  final isSelected = currentSelected == airport;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: _buildAirportModalItem(
                                      airport: airport,
                                      isSelected: isSelected,
                                      isRecommended: false,
                                      onTap: () {
                                        if (isArrival) {
                                          viewModel.updateArrivalLocation(
                                            index,
                                            airport,
                                          );
                                        } else {
                                          viewModel.updateDepartureLocation(
                                            index,
                                            airport,
                                          );
                                        }
                                        Navigator.pop(context);
                                      },
                                    ),
                                  );
                                }),
                              ],
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

  Widget _buildAirportModalItem({
    required String airport,
    required bool isSelected,
    required bool isRecommended,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14.0,
          vertical: 12.0,
        ),
        decoration: BoxDecoration(
          color: isSelected ? appTheme.gray_50_01 : appTheme.white_A700,
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
                color: isSelected
                    ? appTheme.teal_50
                    : (isRecommended ? appTheme.teal_50 : appTheme.gray_50_01),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_airport_rounded,
                size: 18.0,
                color: (isSelected || isRecommended)
                    ? appTheme.teal_A700
                    : appTheme.blue_gray_300,
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                airport,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontFamily: 'Inter',
                  color: isSelected ? appTheme.teal_A700 : appTheme.gray_800,
                ),
              ),
            ),
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
    return Container(
      decoration: BoxDecoration(
        color: appTheme.white_A700,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: appTheme.gray_200,
          width: 1.0,
        ),
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
        itemCount: suggestions.length,
        separatorBuilder: (context, index) => Divider(
          color: appTheme.gray_100,
          height: 1.0,
        ),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
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
                fontSize: 13.5,
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
