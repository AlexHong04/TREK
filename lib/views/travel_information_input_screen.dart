import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/presentation_logic/travel_information_input_view_model.dart';

import '../main.dart';

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
      appBar: _buildAppBar(context),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 22.0),
                    _buildCustomTextField(
                      sectionTitle: 'WISHLIST',
                      hintText: 'Total Trip Budget (\$)',
                      prefixIcon: Icons.favorite,
                      controller: viewModel.wishlistController,
                    ),
                    const SizedBox(height: 22.0),
                    _buildCustomTextField(
                      sectionTitle: 'WHERE TO?',
                      hintText: 'City, Country',
                      prefixIcon: Icons.location_on_outlined,
                      controller: viewModel.destinationController,
                      validator: viewModel.validateDestination,
                    ),
                    const SizedBox(height: 22.0),
                    _buildCustomTextField(
                      sectionTitle: 'Dates',
                      hintText: 'Select dates',
                      prefixIcon: Icons.calendar_today_outlined,
                      controller: viewModel.dateController,
                      readOnly: true,
                      onTap: () => viewModel.selectDateRange(context),
                      validator: viewModel.validateDate,
                    ),
                    const SizedBox(height: 22.0),
                    _buildCustomTextField(
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

  Widget _buildCustomTextField({
    required String sectionTitle,
    required String hintText,
    required IconData prefixIcon,
    TextEditingController? controller,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
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
            sectionTitle,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: AppColors.blueGray300,
            ).copyWith(letterSpacing: 1, height: 1.2),
          ),
          TextFormField(
            controller: controller,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
              color: AppColors.gray800,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
                color: AppColors.gray800,
              ).copyWith(color: appTheme.blue_gray_300),
              prefixIcon: Icon(prefixIcon),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 44.0,
                minHeight: 34.0,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 6.0,
                horizontal: 12.0,
              ),
              filled: true,
              fillColor: appTheme.white_A700,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: appTheme.gray_200, width: 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: appTheme.gray_200, width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: appTheme.teal_A700, width: 1.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: appTheme.colorFFEF44, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: appTheme.colorFFEF44, width: 1.0),
              ),
            ),
            validator: validator,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: appTheme.gray_50_02,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 68,
      titleSpacing: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: appTheme.gray_50),
      ),
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Travel Information',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  fontSize: 20,
                  color: appTheme.teal_A700,
                ).copyWith(height: 1.2),
              ),
            ),
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Afacad',
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
                        style:
                            const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Inter',
                            ).copyWith(
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
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: AppColors.blueGray300,
            ).copyWith(letterSpacing: 1, height: 1.2),
          ),
          const SizedBox(height: 12.0),
          Row(
            children: [
              Expanded(child: _buildEmergencyFundButton(viewModel, '5 %')),
              const SizedBox(width: 12.0),
              Expanded(child: _buildEmergencyFundButton(viewModel, '10 %')),
            ],
          ),
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
            color: isSelected
                ? const Color(0xFF14BBA6)
                : appTheme.blue_gray_700,
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Afacad',
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
}
