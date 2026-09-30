/// Validation: applicative error accumulation (vs Either short-circuit).
library;

import 'either.dart';
import 'option.dart';

/// Represents a validated value: [Valid] with a success, or [Invalid]
/// with a single error, or [InvalidAll] with accumulated errors.
///
/// Unlike [Either], [Validation.ap] and [zipWith] accumulate errors
/// from both sides.
///
/// ```dart
/// final v = Validation<String, int>.valid(1).zipWith(
///   Validation<String, int>.invalid('bad'),
///   (a, b) => a + b,
/// );
/// ```
sealed class Validation<E, A> {
  const Validation();

  const factory Validation.valid(A value) = Valid<E, A>;
  const factory Validation.invalid(E error) = Invalid<E, A>;
  const factory Validation.invalidAll(List<E> errors) = InvalidAll<E, A>;

  /// All errors (empty for Valid).
  List<E> get errors;

  bool get isValid => this is Valid<E, A>;
  bool get isInvalid => !isValid;

  B match<B>(B Function(List<E>) onInvalid, B Function(A) onValid);

  B fold<B>(B Function(List<E>) onInvalid, B Function(A) onValid) =>
      match(onInvalid, onValid);

  Validation<E, B> map<B>(B Function(A) f) => match(
        (e) => InvalidAll<E, B>(e),
        (a) => Valid<E, B>(f(a)),
      );

  Validation<E, B> flatMap<B>(Validation<E, B> Function(A) f) => match(
        (e) => InvalidAll<E, B>(e),
        f,
      );

  /// Applicative apply accumulating errors.
  /// `this` holds the value, [f] holds the function.
  Validation<E, B> ap<B>(Validation<E, B Function(A)> f) {
    final self = this;
    if (f is Valid<E, B Function(A)> && self is Valid<E, A>) {
      return Valid<E, B>(f.value(self.value));
    }
    final errs = <E>[...f.errors, ...self.errors];
    return InvalidAll<E, B>(errs);
  }

  /// Combine two validations, accumulating errors.
  Validation<E, C> zipWith<B, C>(
      Validation<E, B> other, C Function(A, B) combine) {
    final self = this;
    if (self is Valid<E, A> && other is Valid<E, B>) {
      return Valid<E, C>(combine(self.value, other.value));
    }
    return InvalidAll<E, C>([...self.errors, ...other.errors]);
  }

  Either<List<E>, A> toEither() =>
      match((e) => Either<List<E>, A>.left(e), (a) => Either<List<E>, A>.right(a));

  Option<A> toOption() =>
      match((_) => None<A>(), (a) => Some<A>(a));

  A getOrElse(A Function(List<E>) orElse) => match(orElse, (a) => a);

  static Validation<E, List<A>> sequence<E, A>(
      Iterable<Validation<E, A>> items) {
    final out = <A>[];
    final errs = <E>[];
    for (final v in items) {
      v.match(errs.addAll, out.add);
    }
    if (errs.isNotEmpty) return InvalidAll<E, List<A>>(errs);
    return Valid<E, List<A>>(out);
  }

  static Validation<E, List<B>> traverse<E, A, B>(
      Iterable<A> items, Validation<E, B> Function(A) f) {
    return sequence(items.map(f));
  }
}

final class Valid<E, A> extends Validation<E, A> {
  final A value;
  const Valid(this.value);

  @override
  List<E> get errors => const [];

  @override
  B match<B>(B Function(List<E>) onInvalid, B Function(A) onValid) =>
      onValid(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Valid<E, A> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Valid($value)';
}

final class Invalid<E, A> extends Validation<E, A> {
  final E error;
  const Invalid(this.error);

  @override
  List<E> get errors => [error];

  @override
  B match<B>(B Function(List<E>) onInvalid, B Function(A) onValid) =>
      onInvalid([error]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Invalid<E, A> && other.error == error);

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Invalid($error)';
}

final class InvalidAll<E, A> extends Validation<E, A> {
  final List<E> errorList;
  const InvalidAll(this.errorList);

  @override
  List<E> get errors => List.unmodifiable(errorList);

  @override
  B match<B>(B Function(List<E>) onInvalid, B Function(A) onValid) =>
      onInvalid(List.unmodifiable(errorList));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvalidAll<E, A> && _listEq(other.errorList, errorList));

  @override
  int get hashCode => Object.hashAll(errorList);

  @override
  String toString() => 'Invalid($errorList)';
}

bool _listEq<E>(List<E> a, List<E> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
