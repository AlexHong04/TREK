import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  required bool Function(TimeOfDay) isSelectable,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    barrierColor: appTheme.gray_900.withValues(alpha: 0.25),
    builder: (_) => _AppTimePickerDialog(
      initialTime: initialTime,
      isSelectable: isSelectable,
    ),
  );
}

enum _ClockMode { hour, minute }

class _AppTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final bool Function(TimeOfDay) isSelectable;

  const _AppTimePickerDialog({
    required this.initialTime,
    required this.isSelectable,
  });

  @override
  State<_AppTimePickerDialog> createState() => _AppTimePickerDialogState();
}

class _AppTimePickerDialogState extends State<_AppTimePickerDialog> {
  late TimeOfDay _pendingTime;
  _ClockMode _mode = _ClockMode.hour;

  @override
  void initState() {
    super.initState();
    _pendingTime = widget.initialTime;
    if (!widget.isSelectable(_pendingTime)) {
      _pendingTime = _firstSelectableTime() ?? widget.initialTime;
    }
  }

  TimeOfDay? _firstSelectableTime() {
    for (var hour = 0; hour < 24; hour++) {
      for (var minute = 0; minute < 60; minute++) {
        final candidate = TimeOfDay(hour: hour, minute: minute);
        if (widget.isSelectable(candidate)) return candidate;
      }
    }
    return null;
  }

  bool _hourEnabled(int hour) {
    for (var minute = 0; minute < 60; minute++) {
      if (widget.isSelectable(TimeOfDay(hour: hour, minute: minute))) {
        return true;
      }
    }
    return false;
  }

  bool _periodEnabled(bool isPm) {
    final start = isPm ? 12 : 0;
    for (var hour = start; hour < start + 12; hour++) {
      if (_hourEnabled(hour)) return true;
    }
    return false;
  }

  void _selectPeriod(bool isPm) {
    if (!_periodEnabled(isPm)) return;

    final currentIsPm = _pendingTime.hour >= 12;
    if (currentIsPm == isPm) return;

    final convertedHour = (_pendingTime.hour + 12) % 24;
    final converted = TimeOfDay(
      hour: convertedHour,
      minute: _pendingTime.minute,
    );
    setState(() {
      _pendingTime = widget.isSelectable(converted)
          ? converted
          : _nearestSelectableTime(preferredHour: convertedHour) ??
                _pendingTime;
    });
  }

  TimeOfDay? _nearestSelectableTime({
    int? preferredHour,
    int? preferredMinute,
  }) {
    TimeOfDay? best;
    var bestScore = 1000000;

    for (var hour = 0; hour < 24; hour++) {
      for (var minute = 0; minute < 60; minute++) {
        final candidate = TimeOfDay(hour: hour, minute: minute);
        if (!widget.isSelectable(candidate)) continue;

        final hourScore = preferredHour == null
            ? (hour - _pendingTime.hour).abs() * 60
            : (hour - preferredHour).abs() * 60;
        final minuteScore = preferredMinute == null
            ? (minute - _pendingTime.minute).abs()
            : (minute - preferredMinute).abs();
        final score = hourScore + minuteScore;
        if (score < bestScore) {
          best = candidate;
          bestScore = score;
        }
      }
    }

    return best;
  }

  void _selectHour(int hour) {
    if (!_hourEnabled(hour)) return;

    final candidate = TimeOfDay(hour: hour, minute: _pendingTime.minute);
    setState(() {
      _pendingTime = widget.isSelectable(candidate)
          ? candidate
          : _nearestSelectableTime(preferredHour: hour) ?? _pendingTime;
      _mode = _ClockMode.minute;
    });
  }

  void _selectMinute(int minute) {
    final candidate = TimeOfDay(hour: _pendingTime.hour, minute: minute);
    setState(() {
      _pendingTime = widget.isSelectable(candidate)
          ? candidate
          : _nearestSelectableTime(
                  preferredHour: _pendingTime.hour,
                  preferredMinute: minute,
                ) ??
                _pendingTime;
    });
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
                    'Select time',
                    style: TextStyle(
                      color: appTheme.gray_900,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        _pendingTime.format(context),
                        style: TextStyle(
                          color: appTheme.gray_900,
                          fontSize: 28,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
                      _PeriodChip(
                        label: 'AM',
                        selected: _pendingTime.hour < 12,
                        enabled: _periodEnabled(false),
                        onTap: () => _selectPeriod(false),
                      ),
                      const SizedBox(width: 8),
                      _PeriodChip(
                        label: 'PM',
                        selected: _pendingTime.hour >= 12,
                        enabled: _periodEnabled(true),
                        onTap: () => _selectPeriod(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: appTheme.gray_200, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  _ModeButton(
                    label: 'Hour',
                    selected: _mode == _ClockMode.hour,
                    onTap: () => setState(() => _mode = _ClockMode.hour),
                  ),
                  const SizedBox(width: 10),
                  _ModeButton(
                    label: 'Minute',
                    selected: _mode == _ClockMode.minute,
                    onTap: () => setState(() => _mode = _ClockMode.minute),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
              child: _ClockFace(
                mode: _mode,
                selectedTime: _pendingTime,
                isSelectable: widget.isSelectable,
                hourEnabled: _hourEnabled,
                onHourSelected: _selectHour,
                onMinuteSelected: _selectMinute,
              ),
            ),
            Divider(color: appTheme.gray_200, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _TimePickerActionButton(
                      label: 'Cancel',
                      backgroundColor: appTheme.errorRed,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimePickerActionButton(
                      label: 'OK',
                      backgroundColor: appTheme.teal_A700,
                      onPressed: () => Navigator.pop(context, _pendingTime),
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

class _ClockFace extends StatelessWidget {
  final _ClockMode mode;
  final TimeOfDay selectedTime;
  final bool Function(TimeOfDay) isSelectable;
  final bool Function(int) hourEnabled;
  final ValueChanged<int> onHourSelected;
  final ValueChanged<int> onMinuteSelected;

  const _ClockFace({
    required this.mode,
    required this.selectedTime,
    required this.isSelectable,
    required this.hourEnabled,
    required this.onHourSelected,
    required this.onMinuteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final clockSize = math.min(constraints.maxWidth, 286.0);
        return Center(
          child: SizedBox.square(
            dimension: clockSize,
            child: GestureDetector(
              onTapDown: (details) => _selectFromOffset(
                details.localPosition,
                Size.square(clockSize),
              ),
              onPanUpdate: (details) => _selectFromOffset(
                details.localPosition,
                Size.square(clockSize),
              ),
              child: CustomPaint(
                painter: _ClockFacePainter(
                  mode: mode,
                  selectedTime: selectedTime,
                  isSelectable: isSelectable,
                  hourEnabled: hourEnabled,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectFromOffset(Offset position, Size size) {
    final value = _clockValueFromOffset(
      position,
      size,
      divisions: mode == _ClockMode.hour ? 12 : 60,
    );

    if (mode == _ClockMode.hour) {
      final hour12 = value == 0 ? 12 : value;
      final isPm = selectedTime.hour >= 12;
      final hour = isPm
          ? (hour12 == 12 ? 12 : hour12 + 12)
          : (hour12 == 12 ? 0 : hour12);
      onHourSelected(hour);
    } else {
      onMinuteSelected(value);
    }
  }

  int _clockValueFromOffset(
    Offset localPosition,
    Size size, {
    required int divisions,
  }) {
    final center = Offset(size.width / 2, size.height / 2);
    final delta = localPosition - center;
    final angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    final normalized = angle < 0 ? angle + math.pi * 2 : angle;
    return (normalized / (math.pi * 2) * divisions).round() % divisions;
  }
}

class _ClockFacePainter extends CustomPainter {
  final _ClockMode mode;
  final TimeOfDay selectedTime;
  final bool Function(TimeOfDay) isSelectable;
  final bool Function(int) hourEnabled;

  _ClockFacePainter({
    required this.mode,
    required this.selectedTime,
    required this.isSelectable,
    required this.hourEnabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final labelRadius = radius - 31;

    canvas.drawCircle(center, radius, Paint()..color = appTheme.gray_50);

    if (mode == _ClockMode.hour) {
      _drawHourFace(canvas, center, labelRadius);
    } else {
      _drawMinuteFace(canvas, center, labelRadius);
    }
  }

  void _drawHourFace(Canvas canvas, Offset center, double labelRadius) {
    final isPm = selectedTime.hour >= 12;
    for (var value = 1; value <= 12; value++) {
      final hour = isPm ? (value == 12 ? 12 : value + 12) : value % 12;
      final selected = selectedTime.hour == hour;
      _drawLabel(
        canvas,
        center,
        labelRadius,
        value,
        value.toString(),
        enabled: hourEnabled(hour),
        selected: selected,
        divisions: 12,
      );
    }

    final displayHour = selectedTime.hourOfPeriod == 0
        ? 12
        : selectedTime.hourOfPeriod;
    _drawHand(canvas, center, labelRadius, displayHour, 12);
  }

  void _drawMinuteFace(Canvas canvas, Offset center, double labelRadius) {
    for (var minute = 0; minute < 60; minute += 5) {
      final selected = selectedTime.minute == minute;
      _drawLabel(
        canvas,
        center,
        labelRadius,
        minute,
        minute.toString().padLeft(2, '0'),
        enabled: isSelectable(
          TimeOfDay(hour: selectedTime.hour, minute: minute),
        ),
        selected: selected,
        divisions: 60,
      );
    }

    _drawHand(canvas, center, labelRadius, selectedTime.minute, 60);
  }

  void _drawLabel(
    Canvas canvas,
    Offset center,
    double radius,
    int value,
    String text, {
    required bool enabled,
    required bool selected,
    required int divisions,
  }) {
    final angle = (value / divisions) * math.pi * 2 - math.pi / 2;
    final position = Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );

    if (selected) {
      canvas.drawCircle(position, 20, Paint()..color = appTheme.teal_A700);
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: selected
              ? appTheme.white_A700
              : enabled
              ? appTheme.gray_900
              : appTheme.gray_400,
          fontSize: mode == _ClockMode.hour ? 15 : 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      position - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawHand(
    Canvas canvas,
    Offset center,
    double radius,
    int value,
    int divisions,
  ) {
    final angle = (value / divisions) * math.pi * 2 - math.pi / 2;
    final end = Offset(
      center.dx + math.cos(angle) * (radius - 22),
      center.dy + math.sin(angle) * (radius - 22),
    );

    final paint = Paint()
      ..color = appTheme.teal_A700.withValues(alpha: 0.55)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, end, paint);
    canvas.drawCircle(center, 4, Paint()..color = appTheme.teal_A700);
  }

  @override
  bool shouldRepaint(covariant _ClockFacePainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.selectedTime != selectedTime ||
        oldDelegate.isSelectable != isSelectable;
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? appTheme.teal_A700 : appTheme.gray_50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? appTheme.white_A700 : appTheme.gray_900,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 34,
        width: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? appTheme.teal_A700 : appTheme.gray_50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? appTheme.teal_A700 : appTheme.gray_200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? appTheme.white_A700
                : enabled
                ? appTheme.gray_900
                : appTheme.gray_400,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TimePickerActionButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final VoidCallback onPressed;

  const _TimePickerActionButton({
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: appTheme.white_A700,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
