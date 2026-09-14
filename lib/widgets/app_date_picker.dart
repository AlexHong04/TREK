import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  SelectableDayPredicate? selectableDayPredicate,
  String? helpText,
}) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: appTheme.gray_900.withValues(alpha: 0.25),
    builder: (dialogContext) => MediaQuery.removeViewInsets(
      context: dialogContext,
      removeBottom: true,
      child: AppDatePickerDialog(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        selectableDayPredicate: selectableDayPredicate,
        helpText: helpText,
      ),
    ),
  );
}

class AppDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final SelectableDayPredicate? selectableDayPredicate;
  final bool useOutlinedCancel;
  final String? helpText;

  const AppDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.selectableDayPredicate,
    this.useOutlinedCancel = false,
    this.helpText,
  });

  @override
  State<AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<AppDatePickerDialog> {
  late DateTime _pendingDate;

  @override
  void initState() {
    super.initState();
    _pendingDate = DateUtils.dateOnly(widget.initialDate);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12),
      backgroundColor: appTheme.white_A700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.helpText ?? 'Select date',
                    style: TextStyle(
                      color: appTheme.gray_900,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    DateFormat('EEE, MMM d').format(_pendingDate),
                    style: TextStyle(
                      color: appTheme.gray_900,
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: appTheme.gray_200, height: 1),
            Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: appTheme.teal_A700,
                  onPrimary: appTheme.white_A700,
                  surface: appTheme.white_A700,
                  onSurface: appTheme.gray_900,
                ),
              ),
              child: CalendarDatePicker(
                initialDate: _pendingDate,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                selectableDayPredicate: widget.selectableDayPredicate,
                onDateChanged: (date) {
                  setState(() => _pendingDate = DateUtils.dateOnly(date));
                },
              ),
            ),
            Divider(color: appTheme.gray_200, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: appTheme.white_A700,
                        foregroundColor: const Color(0xFF718096),
                        padding: const EdgeInsets.symmetric(vertical: 13.0),
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
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          color: Color(0xFF718096),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _pendingDate),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appTheme.teal_A700,
                        foregroundColor: appTheme.white_A700,
                        padding: const EdgeInsets.symmetric(vertical: 13.0),
                        elevation: 2.0,
                        shadowColor:
                            appTheme.teal_A700.withValues(alpha: 0.35),
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
            ),
          ],
        ),
      ),
    );
  }
}

