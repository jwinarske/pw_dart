// Copyright 2026 Joel Winarske
// Licensed under the Apache License, Version 2.0

import 'package:pw_dart/pw_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PwVersion', () {
    test('isCompatible when versions match', () {
      final v = PwVersion(
        const PwVersionInfo(
          headerVersion: (0, 3, 77),
          libraryVersion: (0, 3, 77),
        ),
      );
      expect(v.isCompatible, isTrue);
    });

    test('isCompatible when library is newer minor', () {
      final v = PwVersion(
        const PwVersionInfo(
          headerVersion: (0, 3, 77),
          libraryVersion: (0, 3, 80),
        ),
      );
      expect(v.isCompatible, isTrue);
    });

    test('incompatible when library is older minor', () {
      final v = PwVersion(
        const PwVersionInfo(
          headerVersion: (0, 3, 77),
          libraryVersion: (0, 3, 50),
        ),
      );
      expect(v.isCompatible, isFalse);
    });

    test('incompatible when major differs', () {
      final v = PwVersion(
        const PwVersionInfo(
          headerVersion: (0, 3, 77),
          libraryVersion: (1, 0, 0),
        ),
      );
      expect(v.isCompatible, isFalse);
    });

    test('meetsMinimumVersion with good version', () {
      final v = PwVersion(
        const PwVersionInfo(
          headerVersion: (0, 3, 77),
          libraryVersion: (0, 3, 77),
        ),
      );
      expect(v.meetsMinimumVersion, isTrue);
    });

    test('meetsMinimumVersion with exact minimum', () {
      final v = PwVersion(
        const PwVersionInfo(
          headerVersion: (0, 3, 40),
          libraryVersion: (0, 3, 40),
        ),
      );
      expect(v.meetsMinimumVersion, isTrue);
    });

    test('does not meet minimum version', () {
      final v = PwVersion(
        const PwVersionInfo(
          headerVersion: (0, 3, 30),
          libraryVersion: (0, 3, 30),
        ),
      );
      expect(v.meetsMinimumVersion, isFalse);
    });

    test('version strings', () {
      final v = PwVersion(
        const PwVersionInfo(
          headerVersion: (0, 3, 77),
          libraryVersion: (0, 3, 80),
        ),
      );
      expect(v.headerVersionString, '0.3.77');
      expect(v.libraryVersionString, '0.3.80');
    });

    test('toString', () {
      final v = PwVersion(
        const PwVersionInfo(
          headerVersion: (0, 3, 77),
          libraryVersion: (0, 3, 77),
        ),
      );
      expect(v.toString(), contains('PwVersion'));
      expect(v.toString(), contains('0.3.77'));
    });
  });

  group('PwVersionInfo', () {
    test('toString', () {
      const info = PwVersionInfo(
        headerVersion: (0, 3, 77),
        libraryVersion: (0, 3, 80),
      );
      expect(info.toString(), contains('header=0.3.77'));
      expect(info.toString(), contains('lib=0.3.80'));
    });
  });
}
