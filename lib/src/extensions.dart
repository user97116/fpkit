/// Cross-cutting extensions: nullable, Either/Option interop, Iterable, Future.
library;

import 'either.dart';
import 'option.dart';
import 'effects.dart';

/// Nullable -> Option / Either helpers.
extension NullableFpExt<T extends Object> on T? {
  /// Lift into [Option].
  Option<T> toOption() {
    final self = this;
    return self == null ? None<T>() : Some<T>(self);
  }

  /// Require non-null, else compute [Left].
  Either<L, T> toEither<L>(L Function() orLeft) {
    final self = this;
    return self == null ? Left<L, T>(orLeft()) : Right<L, T>(self);
  }

  /// Value or fallback.
  T orElse(T Function() fallback) {
    final self = this;
    return self ?? fallback();
  }
}

/// Non-nullable niceties.
extension ValueFpExt<T extends Object> on T {
  Option<T> toSome() => Some<T>(this);
  Either<L, T> toRight<L>() => Right<L, T>(this);
  Either<T, R> toLeft<R>() => Left<T, R>(this);
}

/// Iterable FP helpers.
extension IterableFpExt<T> on Iterable<T> {
  /// Map + collect into first-failure [Either].
  Either<L, List<B>> traverseEither<L, B>(Either<L, B> Function(T) f) =>
      Either.traverse(this, f);

  /// Map + collect into [Option] (None if any None).
  Option<List<B>> traverseOption<B>(Option<B> Function(T) f) =>
      Option.traverse(this, f);

  /// Partition into (lefts, rights).
  (List<L>, List<R>) partitionEither<L, R>(Either<L, R> Function(T) f) {
    final ls = <L>[];
    final rs = <R>[];
    for (final t in this) {
      f(t).match(ls.add, rs.add);
    }
    return (ls, rs);
  }

  /// Filter with a predicate (alias that reads well in FP pipelines).
  Iterable<T> filter(bool Function(T) p) => where(p);

  /// Head as Option.
  Option<T> get headOption {
    if (isEmpty) return None<T>();
    return Some<T>(first);
  }

  /// Group by key.
  Map<K, List<T>> groupBy<K>(K Function(T) key) {
    final m = <K, List<T>>{};
    for (final v in this) {
      m.putIfAbsent(key(v), () => []).add(v);
    }
    return m;
  }
}

/// Future interop: lift async values into effects.
extension FutureFpExt<T> on Future<T> {
  Task<T> toTask() => Task(() => this);

  TaskEither<L, T> toTaskEither<L>(L Function(Object, StackTrace) onError) =>
      TaskEither.tryCatch(() => this, onError);

  Future<Option<T>> toOption({bool catchError = true}) async {
    if (!catchError) {
      final v = await this;
      if (v == null) return None<T>();
      return Some<T>(v);
    }
    try {
      final v = await this;
      if (v == null) return None<T>();
      return Some<T>(v);
    } catch (_) {
      return None<T>();
    }
  }
}

/// Either on Future.
extension FutureEitherFpExt<L, R> on Future<Either<L, R>> {
  Future<Either<L, R2>> mapFuture<R2>(R2 Function(R) f) async =>
      (await this).map(f);

  Future<Either<L, R2>> flatMapFuture<R2>(
      Future<Either<L, R2>> Function(R) f) async {
    final e = await this;
    if (e is Left<L, R>) return Left<L, R2>(e.value);
    return f((e as Right<L, R>).value);
  }
}

/// String helpers commonly needed in validation pipelines.
extension StringFpExt on String {
  /// Parse int as Either.
  Either<String, int> parseIntEither() {
    final v = int.tryParse(this);
    return v == null ? Left<String, int>('Cannot parse "$this" as int') : Right<String, int>(v);
  }

  /// Parse double as Either.
  Either<String, double> parseDoubleEither() {
    final v = double.tryParse(this);
    return v == null
        ? Left<String, double>('Cannot parse "$this" as double')
        : Right<String, double>(v);
  }

  /// Non-empty check as Option.
  Option<String> get nonEmptyOption =>
      isEmpty ? None<String>() : Some<String>(this);
}
