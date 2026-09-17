// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'note_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

NoteSummary _$NoteSummaryFromJson(Map<String, dynamic> json) {
  return _NoteSummary.fromJson(json);
}

/// @nodoc
mixin _$NoteSummary {
  @JsonKey(name: 'note_id')
  String get noteId => throw _privateConstructorUsedError;
  List<String> get subkeys => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_bytes')
  int get totalBytes => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_updated_at')
  DateTime get lastUpdatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_updated_by')
  String? get lastUpdatedBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'request_kind')
  String? get requestKind => throw _privateConstructorUsedError;

  /// Serializes this NoteSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NoteSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NoteSummaryCopyWith<NoteSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NoteSummaryCopyWith<$Res> {
  factory $NoteSummaryCopyWith(
    NoteSummary value,
    $Res Function(NoteSummary) then,
  ) = _$NoteSummaryCopyWithImpl<$Res, NoteSummary>;
  @useResult
  $Res call({
    @JsonKey(name: 'note_id') String noteId,
    List<String> subkeys,
    @JsonKey(name: 'total_bytes') int totalBytes,
    @JsonKey(name: 'last_updated_at') DateTime lastUpdatedAt,
    @JsonKey(name: 'last_updated_by') String? lastUpdatedBy,
    @JsonKey(name: 'request_kind') String? requestKind,
  });
}

/// @nodoc
class _$NoteSummaryCopyWithImpl<$Res, $Val extends NoteSummary>
    implements $NoteSummaryCopyWith<$Res> {
  _$NoteSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NoteSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? noteId = null,
    Object? subkeys = null,
    Object? totalBytes = null,
    Object? lastUpdatedAt = null,
    Object? lastUpdatedBy = freezed,
    Object? requestKind = freezed,
  }) {
    return _then(
      _value.copyWith(
            noteId: null == noteId
                ? _value.noteId
                : noteId // ignore: cast_nullable_to_non_nullable
                      as String,
            subkeys: null == subkeys
                ? _value.subkeys
                : subkeys // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            totalBytes: null == totalBytes
                ? _value.totalBytes
                : totalBytes // ignore: cast_nullable_to_non_nullable
                      as int,
            lastUpdatedAt: null == lastUpdatedAt
                ? _value.lastUpdatedAt
                : lastUpdatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            lastUpdatedBy: freezed == lastUpdatedBy
                ? _value.lastUpdatedBy
                : lastUpdatedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            requestKind: freezed == requestKind
                ? _value.requestKind
                : requestKind // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NoteSummaryImplCopyWith<$Res>
    implements $NoteSummaryCopyWith<$Res> {
  factory _$$NoteSummaryImplCopyWith(
    _$NoteSummaryImpl value,
    $Res Function(_$NoteSummaryImpl) then,
  ) = __$$NoteSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'note_id') String noteId,
    List<String> subkeys,
    @JsonKey(name: 'total_bytes') int totalBytes,
    @JsonKey(name: 'last_updated_at') DateTime lastUpdatedAt,
    @JsonKey(name: 'last_updated_by') String? lastUpdatedBy,
    @JsonKey(name: 'request_kind') String? requestKind,
  });
}

/// @nodoc
class __$$NoteSummaryImplCopyWithImpl<$Res>
    extends _$NoteSummaryCopyWithImpl<$Res, _$NoteSummaryImpl>
    implements _$$NoteSummaryImplCopyWith<$Res> {
  __$$NoteSummaryImplCopyWithImpl(
    _$NoteSummaryImpl _value,
    $Res Function(_$NoteSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NoteSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? noteId = null,
    Object? subkeys = null,
    Object? totalBytes = null,
    Object? lastUpdatedAt = null,
    Object? lastUpdatedBy = freezed,
    Object? requestKind = freezed,
  }) {
    return _then(
      _$NoteSummaryImpl(
        noteId: null == noteId
            ? _value.noteId
            : noteId // ignore: cast_nullable_to_non_nullable
                  as String,
        subkeys: null == subkeys
            ? _value._subkeys
            : subkeys // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        totalBytes: null == totalBytes
            ? _value.totalBytes
            : totalBytes // ignore: cast_nullable_to_non_nullable
                  as int,
        lastUpdatedAt: null == lastUpdatedAt
            ? _value.lastUpdatedAt
            : lastUpdatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        lastUpdatedBy: freezed == lastUpdatedBy
            ? _value.lastUpdatedBy
            : lastUpdatedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        requestKind: freezed == requestKind
            ? _value.requestKind
            : requestKind // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NoteSummaryImpl implements _NoteSummary {
  const _$NoteSummaryImpl({
    @JsonKey(name: 'note_id') required this.noteId,
    required final List<String> subkeys,
    @JsonKey(name: 'total_bytes') required this.totalBytes,
    @JsonKey(name: 'last_updated_at') required this.lastUpdatedAt,
    @JsonKey(name: 'last_updated_by') this.lastUpdatedBy,
    @JsonKey(name: 'request_kind') this.requestKind,
  }) : _subkeys = subkeys;

  factory _$NoteSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$NoteSummaryImplFromJson(json);

  @override
  @JsonKey(name: 'note_id')
  final String noteId;
  final List<String> _subkeys;
  @override
  List<String> get subkeys {
    if (_subkeys is EqualUnmodifiableListView) return _subkeys;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_subkeys);
  }

  @override
  @JsonKey(name: 'total_bytes')
  final int totalBytes;
  @override
  @JsonKey(name: 'last_updated_at')
  final DateTime lastUpdatedAt;
  @override
  @JsonKey(name: 'last_updated_by')
  final String? lastUpdatedBy;
  @override
  @JsonKey(name: 'request_kind')
  final String? requestKind;

  @override
  String toString() {
    return 'NoteSummary(noteId: $noteId, subkeys: $subkeys, totalBytes: $totalBytes, lastUpdatedAt: $lastUpdatedAt, lastUpdatedBy: $lastUpdatedBy, requestKind: $requestKind)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NoteSummaryImpl &&
            (identical(other.noteId, noteId) || other.noteId == noteId) &&
            const DeepCollectionEquality().equals(other._subkeys, _subkeys) &&
            (identical(other.totalBytes, totalBytes) ||
                other.totalBytes == totalBytes) &&
            (identical(other.lastUpdatedAt, lastUpdatedAt) ||
                other.lastUpdatedAt == lastUpdatedAt) &&
            (identical(other.lastUpdatedBy, lastUpdatedBy) ||
                other.lastUpdatedBy == lastUpdatedBy) &&
            (identical(other.requestKind, requestKind) ||
                other.requestKind == requestKind));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    noteId,
    const DeepCollectionEquality().hash(_subkeys),
    totalBytes,
    lastUpdatedAt,
    lastUpdatedBy,
    requestKind,
  );

  /// Create a copy of NoteSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NoteSummaryImplCopyWith<_$NoteSummaryImpl> get copyWith =>
      __$$NoteSummaryImplCopyWithImpl<_$NoteSummaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NoteSummaryImplToJson(this);
  }
}

abstract class _NoteSummary implements NoteSummary {
  const factory _NoteSummary({
    @JsonKey(name: 'note_id') required final String noteId,
    required final List<String> subkeys,
    @JsonKey(name: 'total_bytes') required final int totalBytes,
    @JsonKey(name: 'last_updated_at') required final DateTime lastUpdatedAt,
    @JsonKey(name: 'last_updated_by') final String? lastUpdatedBy,
    @JsonKey(name: 'request_kind') final String? requestKind,
  }) = _$NoteSummaryImpl;

  factory _NoteSummary.fromJson(Map<String, dynamic> json) =
      _$NoteSummaryImpl.fromJson;

  @override
  @JsonKey(name: 'note_id')
  String get noteId;
  @override
  List<String> get subkeys;
  @override
  @JsonKey(name: 'total_bytes')
  int get totalBytes;
  @override
  @JsonKey(name: 'last_updated_at')
  DateTime get lastUpdatedAt;
  @override
  @JsonKey(name: 'last_updated_by')
  String? get lastUpdatedBy;
  @override
  @JsonKey(name: 'request_kind')
  String? get requestKind;

  /// Create a copy of NoteSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NoteSummaryImplCopyWith<_$NoteSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SubkeyContent _$SubkeyContentFromJson(Map<String, dynamic> json) {
  return _SubkeyContent.fromJson(json);
}

/// @nodoc
mixin _$SubkeyContent {
  String get subkey => throw _privateConstructorUsedError;
  @JsonKey(name: 'size_bytes')
  int get sizeBytes => throw _privateConstructorUsedError;
  int get version => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_by')
  String? get updatedBy => throw _privateConstructorUsedError;
  Map<String, dynamic> get value => throw _privateConstructorUsedError;

  /// Serializes this SubkeyContent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SubkeyContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SubkeyContentCopyWith<SubkeyContent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SubkeyContentCopyWith<$Res> {
  factory $SubkeyContentCopyWith(
    SubkeyContent value,
    $Res Function(SubkeyContent) then,
  ) = _$SubkeyContentCopyWithImpl<$Res, SubkeyContent>;
  @useResult
  $Res call({
    String subkey,
    @JsonKey(name: 'size_bytes') int sizeBytes,
    int version,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    @JsonKey(name: 'updated_by') String? updatedBy,
    Map<String, dynamic> value,
  });
}

/// @nodoc
class _$SubkeyContentCopyWithImpl<$Res, $Val extends SubkeyContent>
    implements $SubkeyContentCopyWith<$Res> {
  _$SubkeyContentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SubkeyContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? subkey = null,
    Object? sizeBytes = null,
    Object? version = null,
    Object? updatedAt = null,
    Object? updatedBy = freezed,
    Object? value = null,
  }) {
    return _then(
      _value.copyWith(
            subkey: null == subkey
                ? _value.subkey
                : subkey // ignore: cast_nullable_to_non_nullable
                      as String,
            sizeBytes: null == sizeBytes
                ? _value.sizeBytes
                : sizeBytes // ignore: cast_nullable_to_non_nullable
                      as int,
            version: null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as int,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedBy: freezed == updatedBy
                ? _value.updatedBy
                : updatedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            value: null == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SubkeyContentImplCopyWith<$Res>
    implements $SubkeyContentCopyWith<$Res> {
  factory _$$SubkeyContentImplCopyWith(
    _$SubkeyContentImpl value,
    $Res Function(_$SubkeyContentImpl) then,
  ) = __$$SubkeyContentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String subkey,
    @JsonKey(name: 'size_bytes') int sizeBytes,
    int version,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    @JsonKey(name: 'updated_by') String? updatedBy,
    Map<String, dynamic> value,
  });
}

/// @nodoc
class __$$SubkeyContentImplCopyWithImpl<$Res>
    extends _$SubkeyContentCopyWithImpl<$Res, _$SubkeyContentImpl>
    implements _$$SubkeyContentImplCopyWith<$Res> {
  __$$SubkeyContentImplCopyWithImpl(
    _$SubkeyContentImpl _value,
    $Res Function(_$SubkeyContentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SubkeyContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? subkey = null,
    Object? sizeBytes = null,
    Object? version = null,
    Object? updatedAt = null,
    Object? updatedBy = freezed,
    Object? value = null,
  }) {
    return _then(
      _$SubkeyContentImpl(
        subkey: null == subkey
            ? _value.subkey
            : subkey // ignore: cast_nullable_to_non_nullable
                  as String,
        sizeBytes: null == sizeBytes
            ? _value.sizeBytes
            : sizeBytes // ignore: cast_nullable_to_non_nullable
                  as int,
        version: null == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as int,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedBy: freezed == updatedBy
            ? _value.updatedBy
            : updatedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        value: null == value
            ? _value._value
            : value // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SubkeyContentImpl implements _SubkeyContent {
  const _$SubkeyContentImpl({
    required this.subkey,
    @JsonKey(name: 'size_bytes') required this.sizeBytes,
    required this.version,
    @JsonKey(name: 'updated_at') required this.updatedAt,
    @JsonKey(name: 'updated_by') this.updatedBy,
    required final Map<String, dynamic> value,
  }) : _value = value;

  factory _$SubkeyContentImpl.fromJson(Map<String, dynamic> json) =>
      _$$SubkeyContentImplFromJson(json);

  @override
  final String subkey;
  @override
  @JsonKey(name: 'size_bytes')
  final int sizeBytes;
  @override
  final int version;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @override
  @JsonKey(name: 'updated_by')
  final String? updatedBy;
  final Map<String, dynamic> _value;
  @override
  Map<String, dynamic> get value {
    if (_value is EqualUnmodifiableMapView) return _value;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_value);
  }

  @override
  String toString() {
    return 'SubkeyContent(subkey: $subkey, sizeBytes: $sizeBytes, version: $version, updatedAt: $updatedAt, updatedBy: $updatedBy, value: $value)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SubkeyContentImpl &&
            (identical(other.subkey, subkey) || other.subkey == subkey) &&
            (identical(other.sizeBytes, sizeBytes) ||
                other.sizeBytes == sizeBytes) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.updatedBy, updatedBy) ||
                other.updatedBy == updatedBy) &&
            const DeepCollectionEquality().equals(other._value, _value));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    subkey,
    sizeBytes,
    version,
    updatedAt,
    updatedBy,
    const DeepCollectionEquality().hash(_value),
  );

  /// Create a copy of SubkeyContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SubkeyContentImplCopyWith<_$SubkeyContentImpl> get copyWith =>
      __$$SubkeyContentImplCopyWithImpl<_$SubkeyContentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SubkeyContentImplToJson(this);
  }
}

abstract class _SubkeyContent implements SubkeyContent {
  const factory _SubkeyContent({
    required final String subkey,
    @JsonKey(name: 'size_bytes') required final int sizeBytes,
    required final int version,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
    @JsonKey(name: 'updated_by') final String? updatedBy,
    required final Map<String, dynamic> value,
  }) = _$SubkeyContentImpl;

  factory _SubkeyContent.fromJson(Map<String, dynamic> json) =
      _$SubkeyContentImpl.fromJson;

  @override
  String get subkey;
  @override
  @JsonKey(name: 'size_bytes')
  int get sizeBytes;
  @override
  int get version;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;
  @override
  @JsonKey(name: 'updated_by')
  String? get updatedBy;
  @override
  Map<String, dynamic> get value;

  /// Create a copy of SubkeyContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SubkeyContentImplCopyWith<_$SubkeyContentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NoteDetail _$NoteDetailFromJson(Map<String, dynamic> json) {
  return _NoteDetail.fromJson(json);
}

/// @nodoc
mixin _$NoteDetail {
  @JsonKey(name: 'note_id')
  String get noteId => throw _privateConstructorUsedError;
  Map<String, SubkeyContent> get subkeys => throw _privateConstructorUsedError;

  /// Serializes this NoteDetail to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NoteDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NoteDetailCopyWith<NoteDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NoteDetailCopyWith<$Res> {
  factory $NoteDetailCopyWith(
    NoteDetail value,
    $Res Function(NoteDetail) then,
  ) = _$NoteDetailCopyWithImpl<$Res, NoteDetail>;
  @useResult
  $Res call({
    @JsonKey(name: 'note_id') String noteId,
    Map<String, SubkeyContent> subkeys,
  });
}

/// @nodoc
class _$NoteDetailCopyWithImpl<$Res, $Val extends NoteDetail>
    implements $NoteDetailCopyWith<$Res> {
  _$NoteDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NoteDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? noteId = null, Object? subkeys = null}) {
    return _then(
      _value.copyWith(
            noteId: null == noteId
                ? _value.noteId
                : noteId // ignore: cast_nullable_to_non_nullable
                      as String,
            subkeys: null == subkeys
                ? _value.subkeys
                : subkeys // ignore: cast_nullable_to_non_nullable
                      as Map<String, SubkeyContent>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NoteDetailImplCopyWith<$Res>
    implements $NoteDetailCopyWith<$Res> {
  factory _$$NoteDetailImplCopyWith(
    _$NoteDetailImpl value,
    $Res Function(_$NoteDetailImpl) then,
  ) = __$$NoteDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'note_id') String noteId,
    Map<String, SubkeyContent> subkeys,
  });
}

/// @nodoc
class __$$NoteDetailImplCopyWithImpl<$Res>
    extends _$NoteDetailCopyWithImpl<$Res, _$NoteDetailImpl>
    implements _$$NoteDetailImplCopyWith<$Res> {
  __$$NoteDetailImplCopyWithImpl(
    _$NoteDetailImpl _value,
    $Res Function(_$NoteDetailImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NoteDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? noteId = null, Object? subkeys = null}) {
    return _then(
      _$NoteDetailImpl(
        noteId: null == noteId
            ? _value.noteId
            : noteId // ignore: cast_nullable_to_non_nullable
                  as String,
        subkeys: null == subkeys
            ? _value._subkeys
            : subkeys // ignore: cast_nullable_to_non_nullable
                  as Map<String, SubkeyContent>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NoteDetailImpl implements _NoteDetail {
  const _$NoteDetailImpl({
    @JsonKey(name: 'note_id') required this.noteId,
    required final Map<String, SubkeyContent> subkeys,
  }) : _subkeys = subkeys;

  factory _$NoteDetailImpl.fromJson(Map<String, dynamic> json) =>
      _$$NoteDetailImplFromJson(json);

  @override
  @JsonKey(name: 'note_id')
  final String noteId;
  final Map<String, SubkeyContent> _subkeys;
  @override
  Map<String, SubkeyContent> get subkeys {
    if (_subkeys is EqualUnmodifiableMapView) return _subkeys;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_subkeys);
  }

  @override
  String toString() {
    return 'NoteDetail(noteId: $noteId, subkeys: $subkeys)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NoteDetailImpl &&
            (identical(other.noteId, noteId) || other.noteId == noteId) &&
            const DeepCollectionEquality().equals(other._subkeys, _subkeys));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    noteId,
    const DeepCollectionEquality().hash(_subkeys),
  );

  /// Create a copy of NoteDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NoteDetailImplCopyWith<_$NoteDetailImpl> get copyWith =>
      __$$NoteDetailImplCopyWithImpl<_$NoteDetailImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NoteDetailImplToJson(this);
  }
}

abstract class _NoteDetail implements NoteDetail {
  const factory _NoteDetail({
    @JsonKey(name: 'note_id') required final String noteId,
    required final Map<String, SubkeyContent> subkeys,
  }) = _$NoteDetailImpl;

  factory _NoteDetail.fromJson(Map<String, dynamic> json) =
      _$NoteDetailImpl.fromJson;

  @override
  @JsonKey(name: 'note_id')
  String get noteId;
  @override
  Map<String, SubkeyContent> get subkeys;

  /// Create a copy of NoteDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NoteDetailImplCopyWith<_$NoteDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WorkspaceQuota _$WorkspaceQuotaFromJson(Map<String, dynamic> json) {
  return _WorkspaceQuota.fromJson(json);
}

/// @nodoc
mixin _$WorkspaceQuota {
  String get tier => throw _privateConstructorUsedError;
  @JsonKey(name: 'quota_bytes')
  int get quotaBytes => throw _privateConstructorUsedError;
  @JsonKey(name: 'used_bytes')
  int get usedBytes => throw _privateConstructorUsedError;
  @JsonKey(name: 'remaining_bytes')
  int get remainingBytes => throw _privateConstructorUsedError;
  @JsonKey(name: 'note_ttl_days')
  int get noteTtlDays => throw _privateConstructorUsedError;

  /// Serializes this WorkspaceQuota to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WorkspaceQuota
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WorkspaceQuotaCopyWith<WorkspaceQuota> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkspaceQuotaCopyWith<$Res> {
  factory $WorkspaceQuotaCopyWith(
    WorkspaceQuota value,
    $Res Function(WorkspaceQuota) then,
  ) = _$WorkspaceQuotaCopyWithImpl<$Res, WorkspaceQuota>;
  @useResult
  $Res call({
    String tier,
    @JsonKey(name: 'quota_bytes') int quotaBytes,
    @JsonKey(name: 'used_bytes') int usedBytes,
    @JsonKey(name: 'remaining_bytes') int remainingBytes,
    @JsonKey(name: 'note_ttl_days') int noteTtlDays,
  });
}

/// @nodoc
class _$WorkspaceQuotaCopyWithImpl<$Res, $Val extends WorkspaceQuota>
    implements $WorkspaceQuotaCopyWith<$Res> {
  _$WorkspaceQuotaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WorkspaceQuota
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tier = null,
    Object? quotaBytes = null,
    Object? usedBytes = null,
    Object? remainingBytes = null,
    Object? noteTtlDays = null,
  }) {
    return _then(
      _value.copyWith(
            tier: null == tier
                ? _value.tier
                : tier // ignore: cast_nullable_to_non_nullable
                      as String,
            quotaBytes: null == quotaBytes
                ? _value.quotaBytes
                : quotaBytes // ignore: cast_nullable_to_non_nullable
                      as int,
            usedBytes: null == usedBytes
                ? _value.usedBytes
                : usedBytes // ignore: cast_nullable_to_non_nullable
                      as int,
            remainingBytes: null == remainingBytes
                ? _value.remainingBytes
                : remainingBytes // ignore: cast_nullable_to_non_nullable
                      as int,
            noteTtlDays: null == noteTtlDays
                ? _value.noteTtlDays
                : noteTtlDays // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WorkspaceQuotaImplCopyWith<$Res>
    implements $WorkspaceQuotaCopyWith<$Res> {
  factory _$$WorkspaceQuotaImplCopyWith(
    _$WorkspaceQuotaImpl value,
    $Res Function(_$WorkspaceQuotaImpl) then,
  ) = __$$WorkspaceQuotaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String tier,
    @JsonKey(name: 'quota_bytes') int quotaBytes,
    @JsonKey(name: 'used_bytes') int usedBytes,
    @JsonKey(name: 'remaining_bytes') int remainingBytes,
    @JsonKey(name: 'note_ttl_days') int noteTtlDays,
  });
}

/// @nodoc
class __$$WorkspaceQuotaImplCopyWithImpl<$Res>
    extends _$WorkspaceQuotaCopyWithImpl<$Res, _$WorkspaceQuotaImpl>
    implements _$$WorkspaceQuotaImplCopyWith<$Res> {
  __$$WorkspaceQuotaImplCopyWithImpl(
    _$WorkspaceQuotaImpl _value,
    $Res Function(_$WorkspaceQuotaImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WorkspaceQuota
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tier = null,
    Object? quotaBytes = null,
    Object? usedBytes = null,
    Object? remainingBytes = null,
    Object? noteTtlDays = null,
  }) {
    return _then(
      _$WorkspaceQuotaImpl(
        tier: null == tier
            ? _value.tier
            : tier // ignore: cast_nullable_to_non_nullable
                  as String,
        quotaBytes: null == quotaBytes
            ? _value.quotaBytes
            : quotaBytes // ignore: cast_nullable_to_non_nullable
                  as int,
        usedBytes: null == usedBytes
            ? _value.usedBytes
            : usedBytes // ignore: cast_nullable_to_non_nullable
                  as int,
        remainingBytes: null == remainingBytes
            ? _value.remainingBytes
            : remainingBytes // ignore: cast_nullable_to_non_nullable
                  as int,
        noteTtlDays: null == noteTtlDays
            ? _value.noteTtlDays
            : noteTtlDays // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkspaceQuotaImpl implements _WorkspaceQuota {
  const _$WorkspaceQuotaImpl({
    required this.tier,
    @JsonKey(name: 'quota_bytes') required this.quotaBytes,
    @JsonKey(name: 'used_bytes') required this.usedBytes,
    @JsonKey(name: 'remaining_bytes') required this.remainingBytes,
    @JsonKey(name: 'note_ttl_days') required this.noteTtlDays,
  });

  factory _$WorkspaceQuotaImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkspaceQuotaImplFromJson(json);

  @override
  final String tier;
  @override
  @JsonKey(name: 'quota_bytes')
  final int quotaBytes;
  @override
  @JsonKey(name: 'used_bytes')
  final int usedBytes;
  @override
  @JsonKey(name: 'remaining_bytes')
  final int remainingBytes;
  @override
  @JsonKey(name: 'note_ttl_days')
  final int noteTtlDays;

  @override
  String toString() {
    return 'WorkspaceQuota(tier: $tier, quotaBytes: $quotaBytes, usedBytes: $usedBytes, remainingBytes: $remainingBytes, noteTtlDays: $noteTtlDays)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkspaceQuotaImpl &&
            (identical(other.tier, tier) || other.tier == tier) &&
            (identical(other.quotaBytes, quotaBytes) ||
                other.quotaBytes == quotaBytes) &&
            (identical(other.usedBytes, usedBytes) ||
                other.usedBytes == usedBytes) &&
            (identical(other.remainingBytes, remainingBytes) ||
                other.remainingBytes == remainingBytes) &&
            (identical(other.noteTtlDays, noteTtlDays) ||
                other.noteTtlDays == noteTtlDays));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    tier,
    quotaBytes,
    usedBytes,
    remainingBytes,
    noteTtlDays,
  );

  /// Create a copy of WorkspaceQuota
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkspaceQuotaImplCopyWith<_$WorkspaceQuotaImpl> get copyWith =>
      __$$WorkspaceQuotaImplCopyWithImpl<_$WorkspaceQuotaImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkspaceQuotaImplToJson(this);
  }
}

abstract class _WorkspaceQuota implements WorkspaceQuota {
  const factory _WorkspaceQuota({
    required final String tier,
    @JsonKey(name: 'quota_bytes') required final int quotaBytes,
    @JsonKey(name: 'used_bytes') required final int usedBytes,
    @JsonKey(name: 'remaining_bytes') required final int remainingBytes,
    @JsonKey(name: 'note_ttl_days') required final int noteTtlDays,
  }) = _$WorkspaceQuotaImpl;

  factory _WorkspaceQuota.fromJson(Map<String, dynamic> json) =
      _$WorkspaceQuotaImpl.fromJson;

  @override
  String get tier;
  @override
  @JsonKey(name: 'quota_bytes')
  int get quotaBytes;
  @override
  @JsonKey(name: 'used_bytes')
  int get usedBytes;
  @override
  @JsonKey(name: 'remaining_bytes')
  int get remainingBytes;
  @override
  @JsonKey(name: 'note_ttl_days')
  int get noteTtlDays;

  /// Create a copy of WorkspaceQuota
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkspaceQuotaImplCopyWith<_$WorkspaceQuotaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WorkspaceEvent _$WorkspaceEventFromJson(Map<String, dynamic> json) {
  return _WorkspaceEvent.fromJson(json);
}

/// @nodoc
mixin _$WorkspaceEvent {
  @JsonKey(name: 'event_id')
  int get eventId => throw _privateConstructorUsedError;
  @JsonKey(name: 'note_id')
  String get noteId => throw _privateConstructorUsedError;
  String get subkey => throw _privateConstructorUsedError;
  @JsonKey(name: 'event_kind')
  String get eventKind => throw _privateConstructorUsedError;
  int? get version => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_by')
  String? get updatedBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'emitted_at')
  DateTime get emittedAt => throw _privateConstructorUsedError;

  /// Serializes this WorkspaceEvent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WorkspaceEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WorkspaceEventCopyWith<WorkspaceEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkspaceEventCopyWith<$Res> {
  factory $WorkspaceEventCopyWith(
    WorkspaceEvent value,
    $Res Function(WorkspaceEvent) then,
  ) = _$WorkspaceEventCopyWithImpl<$Res, WorkspaceEvent>;
  @useResult
  $Res call({
    @JsonKey(name: 'event_id') int eventId,
    @JsonKey(name: 'note_id') String noteId,
    String subkey,
    @JsonKey(name: 'event_kind') String eventKind,
    int? version,
    @JsonKey(name: 'updated_by') String? updatedBy,
    @JsonKey(name: 'emitted_at') DateTime emittedAt,
  });
}

/// @nodoc
class _$WorkspaceEventCopyWithImpl<$Res, $Val extends WorkspaceEvent>
    implements $WorkspaceEventCopyWith<$Res> {
  _$WorkspaceEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WorkspaceEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? eventId = null,
    Object? noteId = null,
    Object? subkey = null,
    Object? eventKind = null,
    Object? version = freezed,
    Object? updatedBy = freezed,
    Object? emittedAt = null,
  }) {
    return _then(
      _value.copyWith(
            eventId: null == eventId
                ? _value.eventId
                : eventId // ignore: cast_nullable_to_non_nullable
                      as int,
            noteId: null == noteId
                ? _value.noteId
                : noteId // ignore: cast_nullable_to_non_nullable
                      as String,
            subkey: null == subkey
                ? _value.subkey
                : subkey // ignore: cast_nullable_to_non_nullable
                      as String,
            eventKind: null == eventKind
                ? _value.eventKind
                : eventKind // ignore: cast_nullable_to_non_nullable
                      as String,
            version: freezed == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as int?,
            updatedBy: freezed == updatedBy
                ? _value.updatedBy
                : updatedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            emittedAt: null == emittedAt
                ? _value.emittedAt
                : emittedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WorkspaceEventImplCopyWith<$Res>
    implements $WorkspaceEventCopyWith<$Res> {
  factory _$$WorkspaceEventImplCopyWith(
    _$WorkspaceEventImpl value,
    $Res Function(_$WorkspaceEventImpl) then,
  ) = __$$WorkspaceEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'event_id') int eventId,
    @JsonKey(name: 'note_id') String noteId,
    String subkey,
    @JsonKey(name: 'event_kind') String eventKind,
    int? version,
    @JsonKey(name: 'updated_by') String? updatedBy,
    @JsonKey(name: 'emitted_at') DateTime emittedAt,
  });
}

/// @nodoc
class __$$WorkspaceEventImplCopyWithImpl<$Res>
    extends _$WorkspaceEventCopyWithImpl<$Res, _$WorkspaceEventImpl>
    implements _$$WorkspaceEventImplCopyWith<$Res> {
  __$$WorkspaceEventImplCopyWithImpl(
    _$WorkspaceEventImpl _value,
    $Res Function(_$WorkspaceEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WorkspaceEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? eventId = null,
    Object? noteId = null,
    Object? subkey = null,
    Object? eventKind = null,
    Object? version = freezed,
    Object? updatedBy = freezed,
    Object? emittedAt = null,
  }) {
    return _then(
      _$WorkspaceEventImpl(
        eventId: null == eventId
            ? _value.eventId
            : eventId // ignore: cast_nullable_to_non_nullable
                  as int,
        noteId: null == noteId
            ? _value.noteId
            : noteId // ignore: cast_nullable_to_non_nullable
                  as String,
        subkey: null == subkey
            ? _value.subkey
            : subkey // ignore: cast_nullable_to_non_nullable
                  as String,
        eventKind: null == eventKind
            ? _value.eventKind
            : eventKind // ignore: cast_nullable_to_non_nullable
                  as String,
        version: freezed == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as int?,
        updatedBy: freezed == updatedBy
            ? _value.updatedBy
            : updatedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        emittedAt: null == emittedAt
            ? _value.emittedAt
            : emittedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkspaceEventImpl implements _WorkspaceEvent {
  const _$WorkspaceEventImpl({
    @JsonKey(name: 'event_id') required this.eventId,
    @JsonKey(name: 'note_id') required this.noteId,
    required this.subkey,
    @JsonKey(name: 'event_kind') required this.eventKind,
    this.version,
    @JsonKey(name: 'updated_by') this.updatedBy,
    @JsonKey(name: 'emitted_at') required this.emittedAt,
  });

  factory _$WorkspaceEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkspaceEventImplFromJson(json);

  @override
  @JsonKey(name: 'event_id')
  final int eventId;
  @override
  @JsonKey(name: 'note_id')
  final String noteId;
  @override
  final String subkey;
  @override
  @JsonKey(name: 'event_kind')
  final String eventKind;
  @override
  final int? version;
  @override
  @JsonKey(name: 'updated_by')
  final String? updatedBy;
  @override
  @JsonKey(name: 'emitted_at')
  final DateTime emittedAt;

  @override
  String toString() {
    return 'WorkspaceEvent(eventId: $eventId, noteId: $noteId, subkey: $subkey, eventKind: $eventKind, version: $version, updatedBy: $updatedBy, emittedAt: $emittedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkspaceEventImpl &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.noteId, noteId) || other.noteId == noteId) &&
            (identical(other.subkey, subkey) || other.subkey == subkey) &&
            (identical(other.eventKind, eventKind) ||
                other.eventKind == eventKind) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.updatedBy, updatedBy) ||
                other.updatedBy == updatedBy) &&
            (identical(other.emittedAt, emittedAt) ||
                other.emittedAt == emittedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    eventId,
    noteId,
    subkey,
    eventKind,
    version,
    updatedBy,
    emittedAt,
  );

  /// Create a copy of WorkspaceEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkspaceEventImplCopyWith<_$WorkspaceEventImpl> get copyWith =>
      __$$WorkspaceEventImplCopyWithImpl<_$WorkspaceEventImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkspaceEventImplToJson(this);
  }
}

abstract class _WorkspaceEvent implements WorkspaceEvent {
  const factory _WorkspaceEvent({
    @JsonKey(name: 'event_id') required final int eventId,
    @JsonKey(name: 'note_id') required final String noteId,
    required final String subkey,
    @JsonKey(name: 'event_kind') required final String eventKind,
    final int? version,
    @JsonKey(name: 'updated_by') final String? updatedBy,
    @JsonKey(name: 'emitted_at') required final DateTime emittedAt,
  }) = _$WorkspaceEventImpl;

  factory _WorkspaceEvent.fromJson(Map<String, dynamic> json) =
      _$WorkspaceEventImpl.fromJson;

  @override
  @JsonKey(name: 'event_id')
  int get eventId;
  @override
  @JsonKey(name: 'note_id')
  String get noteId;
  @override
  String get subkey;
  @override
  @JsonKey(name: 'event_kind')
  String get eventKind;
  @override
  int? get version;
  @override
  @JsonKey(name: 'updated_by')
  String? get updatedBy;
  @override
  @JsonKey(name: 'emitted_at')
  DateTime get emittedAt;

  /// Create a copy of WorkspaceEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkspaceEventImplCopyWith<_$WorkspaceEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WriteAck _$WriteAckFromJson(Map<String, dynamic> json) {
  return _WriteAck.fromJson(json);
}

/// @nodoc
mixin _$WriteAck {
  @JsonKey(name: 'note_id')
  String get noteId => throw _privateConstructorUsedError;
  String get subkey => throw _privateConstructorUsedError;
  @JsonKey(name: 'size_bytes')
  int get sizeBytes => throw _privateConstructorUsedError;
  int get version => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this WriteAck to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WriteAck
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WriteAckCopyWith<WriteAck> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WriteAckCopyWith<$Res> {
  factory $WriteAckCopyWith(WriteAck value, $Res Function(WriteAck) then) =
      _$WriteAckCopyWithImpl<$Res, WriteAck>;
  @useResult
  $Res call({
    @JsonKey(name: 'note_id') String noteId,
    String subkey,
    @JsonKey(name: 'size_bytes') int sizeBytes,
    int version,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
  });
}

/// @nodoc
class _$WriteAckCopyWithImpl<$Res, $Val extends WriteAck>
    implements $WriteAckCopyWith<$Res> {
  _$WriteAckCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WriteAck
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? noteId = null,
    Object? subkey = null,
    Object? sizeBytes = null,
    Object? version = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            noteId: null == noteId
                ? _value.noteId
                : noteId // ignore: cast_nullable_to_non_nullable
                      as String,
            subkey: null == subkey
                ? _value.subkey
                : subkey // ignore: cast_nullable_to_non_nullable
                      as String,
            sizeBytes: null == sizeBytes
                ? _value.sizeBytes
                : sizeBytes // ignore: cast_nullable_to_non_nullable
                      as int,
            version: null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as int,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WriteAckImplCopyWith<$Res>
    implements $WriteAckCopyWith<$Res> {
  factory _$$WriteAckImplCopyWith(
    _$WriteAckImpl value,
    $Res Function(_$WriteAckImpl) then,
  ) = __$$WriteAckImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'note_id') String noteId,
    String subkey,
    @JsonKey(name: 'size_bytes') int sizeBytes,
    int version,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
  });
}

/// @nodoc
class __$$WriteAckImplCopyWithImpl<$Res>
    extends _$WriteAckCopyWithImpl<$Res, _$WriteAckImpl>
    implements _$$WriteAckImplCopyWith<$Res> {
  __$$WriteAckImplCopyWithImpl(
    _$WriteAckImpl _value,
    $Res Function(_$WriteAckImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WriteAck
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? noteId = null,
    Object? subkey = null,
    Object? sizeBytes = null,
    Object? version = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$WriteAckImpl(
        noteId: null == noteId
            ? _value.noteId
            : noteId // ignore: cast_nullable_to_non_nullable
                  as String,
        subkey: null == subkey
            ? _value.subkey
            : subkey // ignore: cast_nullable_to_non_nullable
                  as String,
        sizeBytes: null == sizeBytes
            ? _value.sizeBytes
            : sizeBytes // ignore: cast_nullable_to_non_nullable
                  as int,
        version: null == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as int,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WriteAckImpl implements _WriteAck {
  const _$WriteAckImpl({
    @JsonKey(name: 'note_id') required this.noteId,
    required this.subkey,
    @JsonKey(name: 'size_bytes') required this.sizeBytes,
    required this.version,
    @JsonKey(name: 'updated_at') required this.updatedAt,
  });

  factory _$WriteAckImpl.fromJson(Map<String, dynamic> json) =>
      _$$WriteAckImplFromJson(json);

  @override
  @JsonKey(name: 'note_id')
  final String noteId;
  @override
  final String subkey;
  @override
  @JsonKey(name: 'size_bytes')
  final int sizeBytes;
  @override
  final int version;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @override
  String toString() {
    return 'WriteAck(noteId: $noteId, subkey: $subkey, sizeBytes: $sizeBytes, version: $version, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WriteAckImpl &&
            (identical(other.noteId, noteId) || other.noteId == noteId) &&
            (identical(other.subkey, subkey) || other.subkey == subkey) &&
            (identical(other.sizeBytes, sizeBytes) ||
                other.sizeBytes == sizeBytes) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, noteId, subkey, sizeBytes, version, updatedAt);

  /// Create a copy of WriteAck
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WriteAckImplCopyWith<_$WriteAckImpl> get copyWith =>
      __$$WriteAckImplCopyWithImpl<_$WriteAckImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WriteAckImplToJson(this);
  }
}

abstract class _WriteAck implements WriteAck {
  const factory _WriteAck({
    @JsonKey(name: 'note_id') required final String noteId,
    required final String subkey,
    @JsonKey(name: 'size_bytes') required final int sizeBytes,
    required final int version,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
  }) = _$WriteAckImpl;

  factory _WriteAck.fromJson(Map<String, dynamic> json) =
      _$WriteAckImpl.fromJson;

  @override
  @JsonKey(name: 'note_id')
  String get noteId;
  @override
  String get subkey;
  @override
  @JsonKey(name: 'size_bytes')
  int get sizeBytes;
  @override
  int get version;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;

  /// Create a copy of WriteAck
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WriteAckImplCopyWith<_$WriteAckImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
