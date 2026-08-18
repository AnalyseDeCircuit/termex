// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daemon.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$DaemonProbeDto {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String field0) available,
    required TResult Function() notInstalled,
    required TResult Function(String field0) error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? available,
    TResult? Function()? notInstalled,
    TResult? Function(String field0)? error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? available,
    TResult Function()? notInstalled,
    TResult Function(String field0)? error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DaemonProbeDto_Available value) available,
    required TResult Function(DaemonProbeDto_NotInstalled value) notInstalled,
    required TResult Function(DaemonProbeDto_Error value) error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DaemonProbeDto_Available value)? available,
    TResult? Function(DaemonProbeDto_NotInstalled value)? notInstalled,
    TResult? Function(DaemonProbeDto_Error value)? error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DaemonProbeDto_Available value)? available,
    TResult Function(DaemonProbeDto_NotInstalled value)? notInstalled,
    TResult Function(DaemonProbeDto_Error value)? error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DaemonProbeDtoCopyWith<$Res> {
  factory $DaemonProbeDtoCopyWith(
          DaemonProbeDto value, $Res Function(DaemonProbeDto) then) =
      _$DaemonProbeDtoCopyWithImpl<$Res, DaemonProbeDto>;
}

/// @nodoc
class _$DaemonProbeDtoCopyWithImpl<$Res, $Val extends DaemonProbeDto>
    implements $DaemonProbeDtoCopyWith<$Res> {
  _$DaemonProbeDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DaemonProbeDto
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$DaemonProbeDto_AvailableImplCopyWith<$Res> {
  factory _$$DaemonProbeDto_AvailableImplCopyWith(
          _$DaemonProbeDto_AvailableImpl value,
          $Res Function(_$DaemonProbeDto_AvailableImpl) then) =
      __$$DaemonProbeDto_AvailableImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$DaemonProbeDto_AvailableImplCopyWithImpl<$Res>
    extends _$DaemonProbeDtoCopyWithImpl<$Res, _$DaemonProbeDto_AvailableImpl>
    implements _$$DaemonProbeDto_AvailableImplCopyWith<$Res> {
  __$$DaemonProbeDto_AvailableImplCopyWithImpl(
      _$DaemonProbeDto_AvailableImpl _value,
      $Res Function(_$DaemonProbeDto_AvailableImpl) _then)
      : super(_value, _then);

  /// Create a copy of DaemonProbeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? field0 = null,
  }) {
    return _then(_$DaemonProbeDto_AvailableImpl(
      null == field0
          ? _value.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$DaemonProbeDto_AvailableImpl extends DaemonProbeDto_Available {
  const _$DaemonProbeDto_AvailableImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'DaemonProbeDto.available(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DaemonProbeDto_AvailableImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of DaemonProbeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DaemonProbeDto_AvailableImplCopyWith<_$DaemonProbeDto_AvailableImpl>
      get copyWith => __$$DaemonProbeDto_AvailableImplCopyWithImpl<
          _$DaemonProbeDto_AvailableImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String field0) available,
    required TResult Function() notInstalled,
    required TResult Function(String field0) error,
  }) {
    return available(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? available,
    TResult? Function()? notInstalled,
    TResult? Function(String field0)? error,
  }) {
    return available?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? available,
    TResult Function()? notInstalled,
    TResult Function(String field0)? error,
    required TResult orElse(),
  }) {
    if (available != null) {
      return available(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DaemonProbeDto_Available value) available,
    required TResult Function(DaemonProbeDto_NotInstalled value) notInstalled,
    required TResult Function(DaemonProbeDto_Error value) error,
  }) {
    return available(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DaemonProbeDto_Available value)? available,
    TResult? Function(DaemonProbeDto_NotInstalled value)? notInstalled,
    TResult? Function(DaemonProbeDto_Error value)? error,
  }) {
    return available?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DaemonProbeDto_Available value)? available,
    TResult Function(DaemonProbeDto_NotInstalled value)? notInstalled,
    TResult Function(DaemonProbeDto_Error value)? error,
    required TResult orElse(),
  }) {
    if (available != null) {
      return available(this);
    }
    return orElse();
  }
}

abstract class DaemonProbeDto_Available extends DaemonProbeDto {
  const factory DaemonProbeDto_Available(final String field0) =
      _$DaemonProbeDto_AvailableImpl;
  const DaemonProbeDto_Available._() : super._();

  String get field0;

  /// Create a copy of DaemonProbeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DaemonProbeDto_AvailableImplCopyWith<_$DaemonProbeDto_AvailableImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DaemonProbeDto_NotInstalledImplCopyWith<$Res> {
  factory _$$DaemonProbeDto_NotInstalledImplCopyWith(
          _$DaemonProbeDto_NotInstalledImpl value,
          $Res Function(_$DaemonProbeDto_NotInstalledImpl) then) =
      __$$DaemonProbeDto_NotInstalledImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$DaemonProbeDto_NotInstalledImplCopyWithImpl<$Res>
    extends _$DaemonProbeDtoCopyWithImpl<$Res,
        _$DaemonProbeDto_NotInstalledImpl>
    implements _$$DaemonProbeDto_NotInstalledImplCopyWith<$Res> {
  __$$DaemonProbeDto_NotInstalledImplCopyWithImpl(
      _$DaemonProbeDto_NotInstalledImpl _value,
      $Res Function(_$DaemonProbeDto_NotInstalledImpl) _then)
      : super(_value, _then);

  /// Create a copy of DaemonProbeDto
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$DaemonProbeDto_NotInstalledImpl extends DaemonProbeDto_NotInstalled {
  const _$DaemonProbeDto_NotInstalledImpl() : super._();

  @override
  String toString() {
    return 'DaemonProbeDto.notInstalled()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DaemonProbeDto_NotInstalledImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String field0) available,
    required TResult Function() notInstalled,
    required TResult Function(String field0) error,
  }) {
    return notInstalled();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? available,
    TResult? Function()? notInstalled,
    TResult? Function(String field0)? error,
  }) {
    return notInstalled?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? available,
    TResult Function()? notInstalled,
    TResult Function(String field0)? error,
    required TResult orElse(),
  }) {
    if (notInstalled != null) {
      return notInstalled();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DaemonProbeDto_Available value) available,
    required TResult Function(DaemonProbeDto_NotInstalled value) notInstalled,
    required TResult Function(DaemonProbeDto_Error value) error,
  }) {
    return notInstalled(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DaemonProbeDto_Available value)? available,
    TResult? Function(DaemonProbeDto_NotInstalled value)? notInstalled,
    TResult? Function(DaemonProbeDto_Error value)? error,
  }) {
    return notInstalled?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DaemonProbeDto_Available value)? available,
    TResult Function(DaemonProbeDto_NotInstalled value)? notInstalled,
    TResult Function(DaemonProbeDto_Error value)? error,
    required TResult orElse(),
  }) {
    if (notInstalled != null) {
      return notInstalled(this);
    }
    return orElse();
  }
}

abstract class DaemonProbeDto_NotInstalled extends DaemonProbeDto {
  const factory DaemonProbeDto_NotInstalled() =
      _$DaemonProbeDto_NotInstalledImpl;
  const DaemonProbeDto_NotInstalled._() : super._();
}

/// @nodoc
abstract class _$$DaemonProbeDto_ErrorImplCopyWith<$Res> {
  factory _$$DaemonProbeDto_ErrorImplCopyWith(_$DaemonProbeDto_ErrorImpl value,
          $Res Function(_$DaemonProbeDto_ErrorImpl) then) =
      __$$DaemonProbeDto_ErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$DaemonProbeDto_ErrorImplCopyWithImpl<$Res>
    extends _$DaemonProbeDtoCopyWithImpl<$Res, _$DaemonProbeDto_ErrorImpl>
    implements _$$DaemonProbeDto_ErrorImplCopyWith<$Res> {
  __$$DaemonProbeDto_ErrorImplCopyWithImpl(_$DaemonProbeDto_ErrorImpl _value,
      $Res Function(_$DaemonProbeDto_ErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of DaemonProbeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? field0 = null,
  }) {
    return _then(_$DaemonProbeDto_ErrorImpl(
      null == field0
          ? _value.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$DaemonProbeDto_ErrorImpl extends DaemonProbeDto_Error {
  const _$DaemonProbeDto_ErrorImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'DaemonProbeDto.error(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DaemonProbeDto_ErrorImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of DaemonProbeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DaemonProbeDto_ErrorImplCopyWith<_$DaemonProbeDto_ErrorImpl>
      get copyWith =>
          __$$DaemonProbeDto_ErrorImplCopyWithImpl<_$DaemonProbeDto_ErrorImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String field0) available,
    required TResult Function() notInstalled,
    required TResult Function(String field0) error,
  }) {
    return error(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? available,
    TResult? Function()? notInstalled,
    TResult? Function(String field0)? error,
  }) {
    return error?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? available,
    TResult Function()? notInstalled,
    TResult Function(String field0)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DaemonProbeDto_Available value) available,
    required TResult Function(DaemonProbeDto_NotInstalled value) notInstalled,
    required TResult Function(DaemonProbeDto_Error value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DaemonProbeDto_Available value)? available,
    TResult? Function(DaemonProbeDto_NotInstalled value)? notInstalled,
    TResult? Function(DaemonProbeDto_Error value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DaemonProbeDto_Available value)? available,
    TResult Function(DaemonProbeDto_NotInstalled value)? notInstalled,
    TResult Function(DaemonProbeDto_Error value)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class DaemonProbeDto_Error extends DaemonProbeDto {
  const factory DaemonProbeDto_Error(final String field0) =
      _$DaemonProbeDto_ErrorImpl;
  const DaemonProbeDto_Error._() : super._();

  String get field0;

  /// Create a copy of DaemonProbeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DaemonProbeDto_ErrorImplCopyWith<_$DaemonProbeDto_ErrorImpl>
      get copyWith => throw _privateConstructorUsedError;
}
