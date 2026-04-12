import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// Service for computing file checksums.
///
/// Used to verify data integrity after upload (client vs server comparison).
class ChecksumService {
  /// Compute the SHA-256 checksum of a file at [filePath].
  ///
  /// Returns the hex-encoded checksum string.
  Future<String> computeSha256(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Compute the MD5 checksum of a file at [filePath].
  ///
  /// Returns the hex-encoded checksum string.
  Future<String> computeMd5(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Compute SHA-256 checksum for a string [content].
  String computeStringSha256(String content) {
    final bytes = content.codeUnits;
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
