import 'package:flutter/material.dart';

import '../../models/entities/activity.dart';
import '../../main.dart';

class ActivityCardWidget extends StatelessWidget {
  final Activity activity;

  const ActivityCardWidget({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.blueGray50, width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.black900_0c,
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
            ),
            child:
                activity.activityImgUrl != null &&
                    activity.activityImgUrl!.isNotEmpty
                ? Image.asset(
                    activity.activityImgUrl!,
                    height: 192,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
            child: Text(
              activity.destination ?? '',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                color: AppColors.gray900,
              ).copyWith(height: 25 / 20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 20, right: 20),
            child: Text(
              activity.description ?? '',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
                color: AppColors.gray800,
              ).copyWith(height: 22 / 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 12,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            child: Wrap(
              spacing: 8,
              children: [
                if (activity.duration != null && activity.duration!.isNotEmpty)
                  _buildChip(
                    label: activity.duration!,
                    backgroundColor: AppColors.tealA200,
                    textColor: AppColors.teal700,
                  ),
                _buildChip(
                  label: 'RM ${activity.allocatedBudget.toStringAsFixed(2)}',
                  backgroundColor: AppColors.amber200,
                  textColor: AppColors.lime900,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ).copyWith(height: 15 / 12),
      ),
    );
  }
}
