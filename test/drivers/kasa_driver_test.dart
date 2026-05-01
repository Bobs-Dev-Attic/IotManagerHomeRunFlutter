import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:iot_manager/drivers/kasa/kasa_driver.dart';

void main() {
  group('KasaDriver — XOR cipher', () {
    const key = 171; // KasaDriver.xorKey

    test('encrypt produces 4-byte header followed by XOR payload', () {
      const plaintext = 'hello';
      final encrypted = KasaDriver.encrypt(plaintext);

      // Header encodes the payload length as big-endian uint32.
      final expectedLength = plaintext.length;
      expect(encrypted[0], 0);
      expect(encrypted[1], 0);
      expect(encrypted[2], 0);
      expect(encrypted[3], expectedLength);

      // Manually verify the XOR stream.
      final bytes = plaintext.codeUnits;
      int k = key;
      for (int i = 0; i < bytes.length; i++) {
        final expected = bytes[i] ^ k;
        expect(encrypted[4 + i], expected);
        k = expected; // autokey
      }
    });

    test('decrypt(encrypt(s)) == s (round-trip)', () {
      const inputs = [
        '{"system":{"get_sysinfo":{}}}',
        'hello world',
        'short',
        '',
        'Special chars: !@#\$%^&*()',
      ];

      for (final input in inputs) {
        final encrypted = KasaDriver.encrypt(input);
        final decrypted = KasaDriver.decrypt(encrypted);
        expect(decrypted, equals(input), reason: 'Failed for: $input');
      }
    });

    test('decrypt without header stripping works correctly', () {
      const plaintext = 'test';
      final encrypted = KasaDriver.encrypt(plaintext);
      // Extract only the payload (skip header).
      final payload = Uint8List.fromList(encrypted.skip(4).toList());
      final decrypted = KasaDriver.decrypt(payload, stripHeader: false);
      expect(decrypted, equals(plaintext));
    });

    test('encrypt and decrypt known vector', () {
      // Known test vector from https://github.com/softScheck/tplink-smartplug
      // Input: 'A' (0x41 = 65), Key start: 0xAB (171)
      // Cipher byte 0 = 65 ^ 171 = 226 = 0xE2
      const plaintext = 'A';
      final encrypted = KasaDriver.encrypt(plaintext);
      expect(encrypted[4], equals(65 ^ 171));
    });

    test('XOR key constant is 171', () {
      expect(KasaDriver.xorKey, equals(171));
    });

    test('encrypt preserves payload length in header', () {
      const payload = '{"system":{"set_relay_state":{"state":1}}}';
      final encrypted = KasaDriver.encrypt(payload);
      final headerLength =
          (encrypted[0] << 24) | (encrypted[1] << 16) | (encrypted[2] << 8) | encrypted[3];
      expect(headerLength, equals(payload.length));
    });
  });
}
