/// Tests for WorkspaceException.userMessage — the friendly error text
/// shown to the user in the workspace screens.
///
/// 4B carry: error message copy pass — replace raw
/// "WorkspaceException(N): message" strings on the list/detail error
/// states with a short, human-readable line.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:miracle_claw_mobile/core/workspace/workspace_service.dart';

void main() {
  group('WorkspaceException.userMessage', () {
    test('429 → friendly rate-limit copy', () {
      final e = WorkspaceException(429, 'Too Many Requests');
      expect(e.userMessage, contains('too fast'));
      expect(e.userMessage, isNot(contains('WorkspaceException')));
    });

    test('5xx → server error copy', () {
      expect(
        WorkspaceException(502, 'Bad Gateway').userMessage,
        contains('Server temporarily unavailable'),
      );
      expect(
        WorkspaceException(503, '').userMessage,
        contains('Server temporarily unavailable'),
      );
    });

    test('401 → session expired copy', () {
      expect(
        WorkspaceException(401, 'Session archived').userMessage,
        contains('sign in again'),
      );
    });

    test('404 → not found copy', () {
      expect(
        WorkspaceException(404, 'gone').userMessage,
        contains('no longer exists'),
      );
    });

    test('413 → quota full copy', () {
      expect(
        WorkspaceException(413, 'over quota').userMessage,
        contains('full'),
      );
    });

    test('500 → server error copy', () {
      expect(
        WorkspaceException(500, 'oops').userMessage,
        contains('Server error'),
      );
    });

    test('unknown 4xx → generic rejection', () {
      expect(
        WorkspaceException(418, 'I am a teapot').userMessage,
        contains('rejected'),
      );
    });

    test('unknown 5xx → server error with code', () {
      expect(
        WorkspaceException(599, '').userMessage,
        contains('Server error (599)'),
      );
    });

    test('toString still has the raw form for debug logs', () {
      final e = WorkspaceException(429, 'Too Many Requests');
      expect(e.toString(), contains('WorkspaceException'));
      expect(e.toString(), contains('429'));
    });
  });

  group('WorkspaceQuotaException', () {
    test('inherits userMessage from 413', () {
      final e = WorkspaceQuotaException(
        tier: 'pro',
        quotaBytes: 10 * 1024 * 1024 * 1024,
        usedBytes: 10 * 1024 * 1024 * 1024,
        requestedBytes: 1024,
      );
      expect(e.userMessage, contains('full'));
      expect(e.remainingBytes, 0);
    });

    test('remainingBytes is non-negative when used > quota', () {
      // Edge: if quota math underflows (used > quota), we want 0 not a
      // negative number shown to the user.
      final e = WorkspaceQuotaException(
        tier: 'pro',
        quotaBytes: 1024,
        usedBytes: 2048,
        requestedBytes: 512,
      );
      expect(e.remainingBytes, 0);
    });
  });
}
