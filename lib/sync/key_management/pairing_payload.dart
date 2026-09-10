import 'dart:convert';
import 'dart:typed_data';

/// Encapsulates the pairing invitation payload encoded inside a QR code.
/// The 256-bit symmetric home key is transferred directly device-to-device
/// via this payload, and NEVER touches Supabase in plaintext or ciphertext.
class PairingPayload {
  static const int currentVersion = 1;

  final int version;
  final String homeId;
  final String homeName;
  final Uint8List symmetricKey;
  final String inviterId;
  final DateTime createdAt;

  const PairingPayload({
    this.version = currentVersion,
    required this.homeId,
    required this.homeName,
    required this.symmetricKey,
    required this.inviterId,
    required this.createdAt,
  });

  /// Serializes into a JSON string suitable for QR code encoding.
  String toQrString() {
    final map = <String, dynamic>{
      'v': version,
      'h': homeId,
      'n': homeName,
      'k': base64UrlEncode(symmetricKey),
      'i': inviterId,
      't': createdAt.millisecondsSinceEpoch,
    };
    return jsonEncode(map);
  }

  /// Deserializes from a scanned QR code JSON string.
  factory PairingPayload.fromQrString(String qrString) {
    try {
      final map = jsonDecode(qrString) as Map<String, dynamic>;
      final version = (map['v'] as num?)?.toInt() ?? currentVersion;
      final homeId = map['h'] as String;
      final homeName = map['n'] as String;
      final keyBase64 = map['k'] as String;
      final inviterId = map['i'] as String;
      final timestamp = (map['t'] as num).toInt();

      return PairingPayload(
        version: version,
        homeId: homeId,
        homeName: homeName,
        symmetricKey: base64Url.decode(keyBase64),
        inviterId: inviterId,
        createdAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
      );
    } catch (e) {
      throw FormatException('Invalid Cove pairing QR code: $e');
    }
  }
}
