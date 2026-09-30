/// Result / Try: exception-friendly Either alias with helpers.
library;

import 'either.dart';
import 'option.dart';

/// A computation result that is either [Ok] or [Err].
///
/// ```dart
/// Result<int, String> r = Result.tryCatch(
///   () => int.parse('42'), (e, s) => e.toString());
/// final v = r.getOrElse((_) => 0);
/// ```
sealed class Result<T, E> {
  const Result();

  const factory Result.ok(T value) = Ok<T, E>;
  const factory Result.err(E error) = Err<T, E>;

  factory Result.tryCatch(
    T Function() f,
    E Function(Object error, StackTrace stack) onError,
  ) {
    try {
      return Ok<T, E>(f());
    } catch (e, s) {
      return Err<T, E>(onError(e, s));
    }
  }

  /// Async version.
  static Future<Result<T, E>> tryCatchAsync<T, E>(
    Future<T> Function() f,
    E Function(Object error, StackTrace stack) onError,
  ) async {
    try {
      return Ok<T, E>(await f());
    } catch (e, s) {
      return Err<T, E>(onError(e, s));
    }
  }

  B match<B>(B Function(E) onErr, B Function(T) onOk);

  B fold<B>(B Function(E) onErr, B Function(T) onOk) => match(onErr, onOk);

  bool get isOk => this is Ok<T, E>;
  bool get isErr => this is Err<T, E>;

  Result<U, E> map<U>(U Function(T) f) =>
      match((e) => Err<U, E>(e), (v) => Ok<U, E>(f(v)));

  Result<U, E> flatMap<U>(Result<U, E> Function(T) f) =>
      match((e) => Err<U, E>(e), f);

  Result<T, F> mapErr<F>(F Function(E) f) =>
      match((e) => Err<T, F>(f(e)), (v) => Ok<T, F>(v));

  T getOrElse(T Function(E) orElse) => match(orElse, (v) => v);

  T? toNullable() => match((_) => null, (v) => v);

  Option<T> toOption() =>
      match((_) => None<T>(), (v) => Some<T>(v));

  Either<E, T> toEither() =>
      match((e) => Either<E, T>.left(e), (v) => Either<E, T>.right(v));

  static Result<List<T>, E> sequence<T, E>(Iterable<Result<T, E>> items) {
    final out = <T>[];
    for (final r in items) {
      final self = r;
      if (self is Err<T, E>) return Err<List<T>, E>(self.error);
      if (self is Ok<T, E>) out.add(self.value);
    }
    return Ok<List<T>, E>(out);
  }
}

final class Ok<T, E> extends Result<T, E> {
  final T value;
  const Ok(this.value);

  @override
  B match<B>(B Function(E) onErr, B Function(T) onOk) => onOk(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Ok<T, E> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Ok($value)';
}

final class Err<T, E> extends Result<T, E> {
  final E error;
  const Err(this.error);

  @override
  B match<B>(B Function(E) onErr, B Function(T) onOk) => onErr(error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Err<T, E> && other.error == error);

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Err($error)';
}

/// Try that captures [Object] errors.
typedef Try<T> = Result<T, Object>;

Try<T> tryCatch<T>(T Function() f) =>
    Result<T, Object>.tryCatch(f, (e, _) => e);

Future<Try<T>> tryCatchAsync<T>(Future<T> Function() f) =>
    Result.tryCatchAsync<T, Object>(f, (e, _) => e);
