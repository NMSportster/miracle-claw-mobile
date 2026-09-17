// transport.dart — Pick the base URL for the next API call.
//
// Spec: docs/specs/mobile-desktop-pairing.md § "Transport ladder".
//
// Per request, the phone tries the ladder top-down with short timeouts:
//   1. Direct LAN to desktop  (100ms connect timeout)
//   2. MAIC presence relay    (uses endpoint URL from MAIC, no timeout pressure)
//   3. Direct MAIC cloud      (fallback; same as CloudOnly state)
//
// For v1 we keep the ladder simple: the api_client's baseUrl is set
// from ConnectionState. On Paired, the baseUrl is the desktop's
// endpoint. If a call fails with network error / 401, the caller can
// ask `pickFallback()` for the next-best URL.

import 'discovery_state.dart';

const Duration _lanConnectTimeout = Duration(milliseconds: 100);

const Duration _desktopRequestTimeout = Duration(seconds: 5);

/// Decide which URL to try first for the next API call.
///
/// - `CloudOnly` → MAIC cloud.
/// - `Paired` with `endpointKind=lan` → desktop endpoint (with short timeout).
/// - `Paired` with `endpointKind=tailnet` → desktop endpoint.
/// - `Paired` with `endpointKind=relay` → desktop endpoint (it's already relayed).
/// - `PairingInFlight` → MAIC cloud (handshake is in flight; don't hammer desktop).
class TransportLadder {
  const TransportLadder();

  /// The URL to use as Dio's baseUrl for the next call.
  String pickBaseUrl(ConnectionState state) {
    switch (state) {
      case CloudOnly():
        return _maicCloudUrl;
      case Paired(:final desktop):
        if (desktop.endpoint.isEmpty) return _maicCloudUrl;
        return desktop.endpoint;
      case PairingInFlight():
        return _maicCloudUrl;
    }
  }

  /// Timeout to set on Dio's connectTimeout for the next call.
  Duration pickConnectTimeout(ConnectionState state) {
    switch (state) {
      case Paired(:final desktop) when desktop.endpointKind == 'lan':
        return _lanConnectTimeout;
      default:
        return _desktopRequestTimeout;
    }
  }

  /// MAIC cloud fallback. Hardcoded for v1 — future phases can override
  /// via AppConfig (e.g. for staging).
  String get maicCloudUrl => _maicCloudUrl;
}

const String _maicCloudUrl = 'https://api.maicserver.com';
