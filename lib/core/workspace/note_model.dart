/// Workspace data model for the MAIC per-user note bus.
///
/// A note is the unit of work passing from phone → desktop. Each note
/// has a UUID and up to 5 fixed subkeys (request, status, result,
/// approval, history). Subkeys have separate version counters so writes
/// to "status" don't invalidate "result" reads.
///
/// Spec: memory/projects/workspace_architecture.md
/// MAIC backend: api/routes/workspace.py
library;

// JsonKey on factory params triggers an analyzer warning because
// factory params are technically not "fields or getters" — but the
// generated freezed code reads the annotation correctly. Suppress here.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'note_model.g.dart';
part 'note_model.freezed.dart';

/// A note summary as returned by `GET /v1/users/me/workspace`.
///
/// This is what the phone's "Tasks" list shows — the most-recent state
/// of each note, no full values. Tap a note to load the detail view.
@freezed
sealed class NoteSummary with _$NoteSummary {
  const factory NoteSummary({
    @JsonKey(name: 'note_id') required String noteId,
    required List<String> subkeys,
    @JsonKey(name: 'total_bytes') required int totalBytes,
    @JsonKey(name: 'last_updated_at') required DateTime lastUpdatedAt,
    @JsonKey(name: 'last_updated_by') String? lastUpdatedBy,
    @JsonKey(name: 'request_kind') String? requestKind,
    /// Task state, derived server-side so the Tasks list can show
    /// pending / in_progress / done / failed without a detail fetch
    /// per row.
    ///
    /// Server-side derivation: the `status` subkey is optional, so a note
    /// that has a `result` but no `status` (daily summaries, voice memos,
    /// photo OCR) is reported as `done`.
    @JsonKey(name: 'status') String? status,
    /// Whether this note already has a `result` subkey. `true` means the
    /// work is done — the same "result-exists" rule the desktop guard uses.
    @JsonKey(name: 'has_result') @Default(false) bool hasResult,
  }) = _NoteSummary;

  factory NoteSummary.fromJson(Map<String, dynamic> json) =>
      _$NoteSummaryFromJson(json);
}

/// Full subkey content as returned by `GET /v1/users/me/workspace/notes/{id}`.
///
/// `value` is whatever JSON was PUT — for `request` it's the user's
/// task description (kind, title, text, needs_approval_for), for `result`
/// it's the desktop's output (summary, details, attachments).
@freezed
sealed class SubkeyContent with _$SubkeyContent {
  const factory SubkeyContent({
    required String subkey,
    @JsonKey(name: 'size_bytes') required int sizeBytes,
    required int version,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'updated_by') String? updatedBy,
    required Map<String, dynamic> value,
  }) = _SubkeyContent;

  factory SubkeyContent.fromJson(Map<String, dynamic> json) =>
      _$SubkeyContentFromJson(json);
}

/// Full note detail (all subkeys at once).
@freezed
sealed class NoteDetail with _$NoteDetail {
  const factory NoteDetail({
    @JsonKey(name: 'note_id') required String noteId,
    required Map<String, SubkeyContent> subkeys,
  }) = _NoteDetail;

  factory NoteDetail.fromJson(Map<String, dynamic> json) =>
      _$NoteDetailFromJson(json);
}

/// Quota state for the authenticated user, returned by
/// `GET /v1/users/me/workspace/quota`.
@freezed
sealed class WorkspaceQuota with _$WorkspaceQuota {
  const factory WorkspaceQuota({
    required String tier,
    @JsonKey(name: 'quota_bytes') required int quotaBytes,
    @JsonKey(name: 'used_bytes') required int usedBytes,
    @JsonKey(name: 'remaining_bytes') required int remainingBytes,
    @JsonKey(name: 'note_ttl_days') required int noteTtlDays,
  }) = _WorkspaceQuota;

  factory WorkspaceQuota.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceQuotaFromJson(json);
}

/// A change event from the SSE stream or long-poll feed.
///
/// Maps to one of three MAIC event_kinds: "created", "updated", "deleted".
@freezed
sealed class WorkspaceEvent with _$WorkspaceEvent {
  const factory WorkspaceEvent({
    @JsonKey(name: 'event_id') required int eventId,
    @JsonKey(name: 'note_id') required String noteId,
    required String subkey,
    @JsonKey(name: 'event_kind') required String eventKind,
    int? version,
    @JsonKey(name: 'updated_by') String? updatedBy,
    @JsonKey(name: 'emitted_at') required DateTime emittedAt,
  }) = _WorkspaceEvent;

  factory WorkspaceEvent.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceEventFromJson(json);
}

/// Acknowledgement returned by PUT endpoints.
///
/// `version` is monotonically increasing per (note_id, subkey) pair —
/// clients can use it to detect "stale" UI when a newer write arrives.
@freezed
sealed class WriteAck with _$WriteAck {
  const factory WriteAck({
    @JsonKey(name: 'note_id') required String noteId,
    required String subkey,
    @JsonKey(name: 'size_bytes') required int sizeBytes,
    required int version,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _WriteAck;

  factory WriteAck.fromJson(Map<String, dynamic> json) =>
      _$WriteAckFromJson(json);
}

/// The 5 valid subkey names. Keep in sync with the MAIC backend CHECK
/// constraint in db/migrations/040_user_workspace.sql.
const validSubkeys = <String>{
  'request', 'status', 'result', 'approval', 'history',
};

/// Convenience: extract the `request` subkey's title for list display.
String? noteTitleFromDetail(NoteDetail detail) {
  final req = detail.subkeys['request'];
  if (req == null) return null;
  return req.value['title'] as String?;
}

/// Convenience: extract the `request` subkey's kind (reminder, search,
/// file_request, etc.) for list display + icons.
String? noteKindFromDetail(NoteDetail detail) {
  final req = detail.subkeys['request'];
  if (req == null) return null;
  return req.value['kind'] as String?;
}

/// Extract a short preview string from a note for list-tile display.
///
/// Preference order:
///   1. `result.summary` — LLM-generated recap (most informative for
///      daily_summary / voice_memo / photo_ocr / command)
///   2. `result.text` — raw model output if no summary key
///   3. `request.text` — the user's original task description
///   4. `request.title` — short user-supplied title (if any)
///
/// Returns null when none of those fields exist. The caller should
/// fall back to the request_kind label so the tile is never blank.
String? extractNotePreview(NoteDetail detail, {int maxLen = 80}) {
  String? pick(Map<String, dynamic>? v, List<String> keys) {
    if (v == null) return null;
    for (final k in keys) {
      final s = v[k];
      if (s is String && s.trim().isNotEmpty) return s.trim();
    }
    return null;
  }

  final result = detail.subkeys['result']?.value;
  final request = detail.subkeys['request']?.value;
  final raw = pick(result, const ['summary', 'text', 'transcript']) ??
      pick(request, const ['text', 'title', 'description']);

  if (raw == null) return null;
  // Collapse whitespace so "OCR of an\ninvoice" reads as one line.
  final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.length <= maxLen) return collapsed;
  return '${collapsed.substring(0, maxLen - 1).trimRight()}…';
}
