import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/presentation_logic/travel_information_input_view_model.dart';

import '../main.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';
import '../utils/malaysia_states.dart';

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
  late final TextEditingController _arrivalLocationController;
  late final TextEditingController _departureLocationController;
  late final TextEditingController _hotelLocationController;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController();
    _budgetController = TextEditingController();
    _wishlistController = TextEditingController();
    _arrivalLocationController = TextEditingController();
    _departureLocationController = TextEditingController();
    _hotelLocationController = TextEditingController();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _budgetController.dispose();
    _wishlistController.dispose();
    _arrivalLocationController.dispose();
    _departureLocationController.dispose();
    _hotelLocationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TravelInformationInputViewModel>();

    return Scaffold(
      backgroundColor: appTheme.gray_50_02,
      appBar: const CustomAppBar(title: 'Travel Information'),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
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
                      prefixIcon: Icons.favorite,
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
                      controller: _dateController,
                      readOnly: true,
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
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
              Icon(Icons.favorite, color: appTheme.teal_A700, size: 20.0),
              const SizedBox(width: 8.0),
              Text(
                'Travel Preferences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ).copyWith(height: 1.22),
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
                      width: isSelected ? 2.0 : 1.0,
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
                      'arrivalLocation': _arrivalLocationController.text.trim(),
                      'arrivalTime': viewModel.uiState.arrivalTime,
                      'departureLocation':
                          _departureLocationController.text.trim(),
                      'departureTime': viewModel.uiState.departureTime,
                      'hotelLocation': _hotelLocationController.text.trim(),
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
                      fontSize: 10,
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
                      size: 22.0,
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
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
      backgroundColor: Colors.transparent,
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
                              '13 States of Malaysia',
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
          Text(
            'ARRIVAL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: appTheme.blue_gray_300,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _arrivalLocationController,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                    color: appTheme.gray_800,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Arrival location (e.g. Airport / Station)',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_300,
                    ),
                    prefixIcon: Icon(
                      Icons.flight_land_outlined,
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
              ),
              const SizedBox(width: 8.0),
              _buildTimePickerButton(
                context: context,
                time: viewModel.uiState.arrivalTime,
                onTap: () => _pickTime(
                  context: context,
                  initialTimeString: viewModel.uiState.arrivalTime,
                  onTimePicked: viewModel.setArrivalTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Divider(color: appTheme.gray_100, height: 1.0),
          const SizedBox(height: 12.0),
          Text(
            'DEPARTURE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: appTheme.blue_gray_300,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _departureLocationController,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                    color: appTheme.gray_800,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Departure location (e.g. Airport / Station)',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                      color: appTheme.blue_gray_300,
                    ),
                    prefixIcon: Icon(
                      Icons.flight_takeoff_outlined,
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
              ),
              const SizedBox(width: 8.0),
              _buildTimePickerButton(
                context: context,
                time: viewModel.uiState.departureTime,
                onTap: () => _pickTime(
                  context: context,
                  initialTimeString: viewModel.uiState.departureTime,
                  onTimePicked: viewModel.setDepartureTime,
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
          Text(
            'ACCOMMODATION / HOTEL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: appTheme.blue_gray_300,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: _hotelLocationController,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
              color: appTheme.gray_800,
            ),
            decoration: InputDecoration(
              hintText: 'Hotel name or area (e.g. George Town)',
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
          const SizedBox(height: 12.0),
          Divider(color: appTheme.gray_100, height: 1.0),
          const SizedBox(height: 12.0),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHECK-IN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        color: appTheme.blue_gray_300,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    _buildTimePickerButton(
                      context: context,
                      time: viewModel.uiState.hotelCheckInTime,
                      isFullWidth: true,
                      onTap: () => _pickTime(
                        context: context,
                        initialTimeString: viewModel.uiState.hotelCheckInTime,
                        onTimePicked: viewModel.setHotelCheckInTime,
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
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        color: appTheme.blue_gray_300,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    _buildTimePickerButton(
                      context: context,
                      time: viewModel.uiState.hotelCheckOutTime,
                      isFullWidth: true,
                      onTap: () => _pickTime(
                        context: context,
                        initialTimeString: viewModel.uiState.hotelCheckOutTime,
                        onTimePicked: viewModel.setHotelCheckOutTime,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          mainAxisAlignment:
              isFullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
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
}
