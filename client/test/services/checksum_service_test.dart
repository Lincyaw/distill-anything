import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for checksum computation logic.
///
/// Since ChecksumService.computeSha256 uses dart:io (File),
/// we test the underlying crypto logic directly.
void main() {
  group('Checksum computation', () {
    test('SHA256 with UTF-8 encoding produces correct hash', () {
      final bytes = utf8.encode('hello world');
      final digest = sha256.convert(bytes);
      final hex = digest.toString();

      // Known SHA-256 of UTF-8 "hello world"
      expect(
        hex,
        'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
      );
    });

    test('SHA256 is consistent for same input', () {
      const input = 'test data for checksum';
      final digest1 = sha256.convert(utf8.encode(input));
      final digest2 = sha256.convert(utf8.encode(input));

      expect(digest1.toString(), digest2.toString());
    });

    test('SHA256 differs for different inputs', () {
      final digest1 = sha256.convert(utf8.encode('input A'));
      final digest2 = sha256.convert(utf8.encode('input B'));

      expect(digest1.toString(), isNot(digest2.toString()));
    });

    test('SHA256 of empty input produces known hash', () {
      final digest = sha256.convert([]);
      expect(
        digest.toString(),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('SHA256 of non-ASCII string with UTF-8 differs from codeUnits', () {
      const input = '你好世界'; // Chinese characters
      final utf8Digest = sha256.convert(utf8.encode(input));
      final codeUnitsDigest = sha256.convert(input.codeUnits);

      // UTF-8 and UTF-16 code units produce different hashes for non-ASCII
      expect(utf8Digest.toString(), isNot(codeUnitsDigest.toString()));
    });

    test('MD5 of bytes produces correct hex string', () {
      final bytes = utf8.encode('hello world');
      final digest = md5.convert(bytes);

      // Known MD5 of "hello world"
      expect(digest.toString(), '5eb63bbbe01eeed093cb22bb8f5acdc3');
    });

    test('MD5 is consistent for same input', () {
      const input = 'consistent input';
      final digest1 = md5.convert(utf8.encode(input));
      final digest2 = md5.convert(utf8.encode(input));

      expect(digest1.toString(), digest2.toString());
    });
  });
}
