import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  SelectableDayPredicate? selectableDayPredicate,
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

  const AppDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.selectableDayPredicate,
    this.useOutlinedCancel = false,
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
                    'Select date',
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
                    child: _DatePickerActionButton(
                      label: 'Cancel',
                      backgroundColor: appTheme.errorRed,
                      isOutlined: widget.useOutlinedCancel,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DatePickerActionButton(
                      label: 'Confirm',
                      onPressed: () => Navigator.pop(context, _pendingDate),
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

class _DatePickerActionButton extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final bool isOutlined;
  final VoidCallback onPressed;

  const _DatePickerActionButton({
    required this.label,
    this.backgroundColor,
    this.isOutlined = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: isOutlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                backgroundColor: appTheme.white_A700,
                foregroundColor: appTheme.blue_gray_300,
                side: BorderSide(color: appTheme.gray_200, width: 1.5),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(label),
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: backgroundColor ?? appTheme.teal_A700,
                foregroundColor: appTheme.white_A700,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(label),
            ),
    );
  }
}
