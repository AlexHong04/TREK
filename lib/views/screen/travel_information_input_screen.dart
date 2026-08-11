import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../view_models/presentation_logic/travel_information_input_view_model.dart';

import '../../main.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';

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

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TravelInformationInputViewModel>();

    return Scaffold(
      backgroundColor: appTheme.gray_50_02,
      appBar: CustomAppBar(
        title: 'Travel Information',
        onLeadingTap: () => Navigator.of(context).pop(),
        titleColor: appTheme.teal_A700,
        titleFontSize: 20,
        // titleFontFamily: 'NimbusSans',
        backgroundColor: appTheme.gray_50_02,
        bottomBorderColor: appTheme.gray_50,
        paddingHorizontal: 32,
        paddingVertical: 20,
        leadingIconSize: 24,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 22.0),
                    CustomTextField(
                      sectionTitle: 'WISHLIST',
                      hintText: 'Total Trip Budget (\$)',
                      prefixIcon: Icons.favorite,
                      controller: viewModel.wishlistController,
                    ),
                    const SizedBox(height: 22.0),
                    CustomTextField(
                      sectionTitle: 'WHERE TO?',
                      hintText: 'City, Country',
                      prefixIcon: Icons.location_on_outlined,
                      controller: viewModel.destinationController,
                      validator: viewModel.validateDestination,
                    ),
                    const SizedBox(height: 22.0),
                    CustomTextField(
                      sectionTitle: 'Dates',
                      hintText: 'Select dates',
                      prefixIcon: Icons.calendar_today_outlined,
                      controller: viewModel.dateController,
                      readOnly: true,
                      onTap: () => viewModel.selectDateRange(context),
                      validator: viewModel.validateDate,
                    ),
                    const SizedBox(height: 22.0),
                    CustomTextField(
                      sectionTitle: 'TRIP BUDGET',
                      hintText: 'Total Trip Budget (\$)',
                      prefixIcon: Icons.payments_outlined,
                      controller: viewModel.budgetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: viewModel.validateBudget,
                    ),
                    const SizedBox(height: 22.0),
                    _buildEmergencyFundSection(viewModel),
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Afacad').copyWith(
                  height: 1.22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: viewModel.preferences.map((pref) {
              bool isSelected = viewModel.uiState.selectedPreference == pref.label;
              return GestureDetector(
                onTap: () => viewModel.selectPreference(pref.label),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: isSelected ? 10.0 : 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF0FDFA)
                        : appTheme.transparentCustom,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF14BBA6)
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
                        style: const TextStyle(fontSize: 14, fontFamily: 'Inter').copyWith(
                          color: isSelected
                              ? const Color(0xFF14BBA6)
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

  Widget _buildEmergencyFundSection(TravelInformationInputViewModel viewModel) {
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
            'EMERGENCY FUND',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'Inter', color: AppColors.blueGray300).copyWith(
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12.0),
          Row(
            children: [
              Expanded(
                child: _buildEmergencyFundButton(viewModel, '5 %'),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: _buildEmergencyFundButton(viewModel, '10 %'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmergencyFundButton(
    TravelInformationInputViewModel viewModel,
    String label,
  ) {
    bool isSelected = viewModel.uiState.selectedEmergencyFund == label;
    return GestureDetector(
      onTap: () => viewModel.selectEmergencyFund(label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDFA) : appTheme.white_A700,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected ? const Color(0xFF14BBA6) : appTheme.gray_200,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontFamily: 'Inter').copyWith(
            color: isSelected ? const Color(0xFF14BBA6) : appTheme.blue_gray_700,
            height: 1.21,
          ),
        ),
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
                viewModel.generateItinerary(context);
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
                    'Generate Itinerary',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Afacad').copyWith(
                      color: appTheme.white_A700,
                      height: 22 / 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
