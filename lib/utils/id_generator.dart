import 'dart:math';

class IdGenerator {
  static String generateNextFormattedId(
    String prefix,
    String? lastId, {
    int paddingLength = 4,
  }) {
    if (lastId == null || lastId.isEmpty || !lastId.startsWith(prefix)) {
      return '$prefix${'1'.padLeft(paddingLength, '0')}';
    }

    String numberPart = lastId.substring(prefix.length);

    int nextNumber = (int.tryParse(numberPart) ?? 0) + 1;

    return '$prefix${nextNumber.toString().padLeft(paddingLength, '0')}';
  }
}
