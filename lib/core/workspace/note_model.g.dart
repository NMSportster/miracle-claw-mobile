// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NoteSummaryImpl _$$NoteSummaryImplFromJson(Map<String, dynamic> json) =>
    _$NoteSummaryImpl(
      noteId: json['note_id'] as String,
      subkeys: (json['subkeys'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      totalBytes: (json['total_bytes'] as num).toInt(),
      lastUpdatedAt: DateTime.parse(json['last_updated_at'] as String),
      lastUpdatedBy: json['last_updated_by'] as String?,
      requestKind: json['request_kind'] as String?,
    );

Map<String, dynamic> _$$NoteSummaryImplToJson(_$NoteSummaryImpl instance) =>
    <String, dynamic>{
      'note_id': instance.noteId,
      'subkeys': instance.subkeys,
      'total_bytes': instance.totalBytes,
      'last_updated_at': instance.lastUpdatedAt.toIso8601String(),
      'last_updated_by': instance.lastUpdatedBy,
      'request_kind': instance.requestKind,
    };

_$SubkeyContentImpl _$$SubkeyContentImplFromJson(Map<String, dynamic> json) =>
    _$SubkeyContentImpl(
      subkey: json['subkey'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      version: (json['version'] as num).toInt(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      updatedBy: json['updated_by'] as String?,
      value: json['value'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$$SubkeyContentImplToJson(_$SubkeyContentImpl instance) =>
    <String, dynamic>{
      'subkey': instance.subkey,
      'size_bytes': instance.sizeBytes,
      'version': instance.version,
      'updated_at': instance.updatedAt.toIso8601String(),
      'updated_by': instance.updatedBy,
      'value': instance.value,
    };

_$NoteDetailImpl _$$NoteDetailImplFromJson(Map<String, dynamic> json) =>
    _$NoteDetailImpl(
      noteId: json['note_id'] as String,
      subkeys: (json['subkeys'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, SubkeyContent.fromJson(e as Map<String, dynamic>)),
      ),
    );

Map<String, dynamic> _$$NoteDetailImplToJson(_$NoteDetailImpl instance) =>
    <String, dynamic>{'note_id': instance.noteId, 'subkeys': instance.subkeys};

_$WorkspaceQuotaImpl _$$WorkspaceQuotaImplFromJson(Map<String, dynamic> json) =>
    _$WorkspaceQuotaImpl(
      tier: json['tier'] as String,
      quotaBytes: (json['quota_bytes'] as num).toInt(),
      usedBytes: (json['used_bytes'] as num).toInt(),
      remainingBytes: (json['remaining_bytes'] as num).toInt(),
      noteTtlDays: (json['note_ttl_days'] as num).toInt(),
    );

Map<String, dynamic> _$$WorkspaceQuotaImplToJson(
  _$WorkspaceQuotaImpl instance,
) => <String, dynamic>{
  'tier': instance.tier,
  'quota_bytes': instance.quotaBytes,
  'used_bytes': instance.usedBytes,
  'remaining_bytes': instance.remainingBytes,
  'note_ttl_days': instance.noteTtlDays,
};

_$WorkspaceEventImpl _$$WorkspaceEventImplFromJson(Map<String, dynamic> json) =>
    _$WorkspaceEventImpl(
      eventId: (json['event_id'] as num).toInt(),
      noteId: json['note_id'] as String,
      subkey: json['subkey'] as String,
      eventKind: json['event_kind'] as String,
      version: (json['version'] as num?)?.toInt(),
      updatedBy: json['updated_by'] as String?,
      emittedAt: DateTime.parse(json['emitted_at'] as String),
    );

Map<String, dynamic> _$$WorkspaceEventImplToJson(
  _$WorkspaceEventImpl instance,
) => <String, dynamic>{
  'event_id': instance.eventId,
  'note_id': instance.noteId,
  'subkey': instance.subkey,
  'event_kind': instance.eventKind,
  'version': instance.version,
  'updated_by': instance.updatedBy,
  'emitted_at': instance.emittedAt.toIso8601String(),
};

_$WriteAckImpl _$$WriteAckImplFromJson(Map<String, dynamic> json) =>
    _$WriteAckImpl(
      noteId: json['note_id'] as String,
      subkey: json['subkey'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      version: (json['version'] as num).toInt(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$WriteAckImplToJson(_$WriteAckImpl instance) =>
    <String, dynamic>{
      'note_id': instance.noteId,
      'subkey': instance.subkey,
      'size_bytes': instance.sizeBytes,
      'version': instance.version,
      'updated_at': instance.updatedAt.toIso8601String(),
    };
