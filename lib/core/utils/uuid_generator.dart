import 'dart:math';

/// Generates a valid RFC 4122 version 4 UUID.
/// Guaranteed to match Postgres UUID type: `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`.
String generateCoveUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));

  // Set version to 4
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  // Set variant to RFC 4122 (10xxxxxx)
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}
