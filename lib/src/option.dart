/// Option type: explicit optional value without null.
library;

import 'either.dart';

/// Represents an optional value: [Some] with a value, or [None] without.
///
/// ```dart
/// final name = Option.fromNullable(maybeName);
/// final upper = name.map((s) => s.toUpperCase()).getOrElse(() => 'GUEST');
/// ```
sealed class Option<T> {
  const Option();

  /// Create a [Some].
  const factory Option.some(T value) = Some<T>;

  /// Create a [None].
  const factory Option.none() = None<T>;

  /// Lift a nullable into an [Option].
  factory Option.fromNullable(T? value) =>
      value == null ? None<T>() : Some<T>(value);

  /// Run an effectful computation catching thrown errors into [None].
  factory Option.tryCatch(T Function() f, [bool Function(T)? predicate]) {
    try {
      final v = f();
      if (predicate != null && !predicate(v)) return None<T>();
      return Some<T>(v);
    } catch (_) {
      return None<T>();
    }
  }

  /// Pattern-match on the two cases.
  B match<B>(B Function() onNone, B Function(T) onSome);

  /// Alias for [match].
  B fold<B>(B Function() onNone, B Function(T) onSome) =>
      match(onNone, onSome);

  bool get isSome => this is Some<T>;
  bool get isNone => this is None<T>;

  /// Unsafe unwrap. Throws [StateError] on [None].
  T get value => match(() => throw StateError('None has no value'), (v) => v);

  /// Nullable view.
  T? toNullable() => match(() => null, (v) => v);

  /// Convert to [Either] with [left] used for [None].
  Either<L, T> toEither<L>(L Function() leftFn) =>
      match(() => Left<L, T>(leftFn()), (v) => Right<L, T>(v));

  /// Convert to [Either] with a constant left.
  Either<L, T> toEitherLeft<L>(L leftValue) =>
      match(() => Left<L, T>(leftValue), (v) => Right<L, T>(v));

  Option<U> map<U>(U Function(T) f) =>
      match(() => None<U>(), (v) => Some<U>(f(v)));

  Option<U> flatMap<U>(Option<U> Function(T) f) => match(() => None<U>(), f);

  /// Alias for [flatMap].
  Option<U> andThen<U>(Option<U> Function(T) f) => flatMap(f);

  Option<T> filter(bool Function(T) predicate) => match(
        () => None<T>(),
        (v) => predicate(v) ? Some<T>(v) : None<T>(),
      );

  T getOrElse(T Function() orElse) => match(orElse, (v) => v);

  Option<T> orElse(Option<T> Function() orElse) =>
      match(orElse, (v) => Some<T>(v));

  /// Applicative apply: `this` holds the value, [f] holds the function.
  Option<U> ap<U>(Option<U Function(T)> f) =>
      f.match(() => None<U>(), (fn) => map(fn));

  /// Combine two options with [combine], [None] if either is [None].
  Option<C> zipWith<B, C>(Option<B> other, C Function(T, B) combine) =>
      flatMap((a) => other.map((b) => combine(a, b)));

  /// First [Some] wins.
  Option<T> alt(Option<T> Function() other) => isSome ? this : other();

  void forEach(void Function(T) f) {
    final self = this;
    if (self is Some<T>) f(self.value);
  }

  /// Sequence a list of options: [Some] of list iff all are [Some].
  static Option<List<T>> sequence<T>(Iterable<Option<T>> options) {
    final out = <T>[];
    for (final o in options) {
      final self = o;
      if (self is Some<T>) {
        out.add(self.value);
      } else {
        return None<List<T>>();
      }
    }
    return Some<List<T>>(out);
  }

  /// Traverse: map each element to [Option] and collect.
  static Option<List<B>> traverse<A, B>(
      Iterable<A> items, Option<B> Function(A) f) {
    final out = <B>[];
    for (final a in items) {
      final ob = f(a);
      if (ob is Some<B>) {
        out.add(ob.value);
      } else {
        return None<List<B>>();
      }
    }
    return Some<List<B>>(out);
  }
}

/// Present value.
final class Some<T> extends Option<T> {
  @override
  final T value;
  const Some(this.value);

  @override
  B match<B>(B Function() onNone, B Function(T) onSome) => onSome(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Some<T> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Some($value)';
}

/// Absent value.
final class None<T> extends Option<T> {
  const None();

  @override
  B match<B>(B Function() onNone, B Function(T) onSome) => onNone();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is None<T>;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'None()';
}

/// Convenience constructors.
///
/// ```dart
/// some(1); // == Some(1)
/// none<int>(); // == None<int>()
/// ```
Option<T> some<T>(T value) => Some<T>(value);
Option<T> none<T>() => None<T>();
