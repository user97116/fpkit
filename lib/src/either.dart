/// Either type: disjoint union of Left (failure) and Right (success).
library;

import 'option.dart';
import 'validation.dart';

/// Represents a value of one of two types: [Left] (usually failure)
/// or [Right] (usually success).
///
/// ```dart
/// Either<String, int> parse(String s) {
///   final v = int.tryParse(s);
///   return v == null ? left('not a number') : right(v);
/// }
/// final r = parse('42').map((n) => n * 2).getOrElse((_) => 0);
/// ```
sealed class Either<L, R> {
  const Either();

  const factory Either.left(L value) = Left<L, R>;
  const factory Either.right(R value) = Right<L, R>;

  /// Catch thrown errors into [Left] via [onError].
  factory Either.tryCatch(
      R Function() f, L Function(Object, StackTrace) onError) {
    try {
      return Right<L, R>(f());
    } catch (e, s) {
      return Left<L, R>(onError(e, s));
    }
  }

  /// Pattern match.
  B match<B>(B Function(L) onLeft, B Function(R) onRight);

  /// Alias for [match].
  B fold<B>(B Function(L) onLeft, B Function(R) onRight) =>
      match(onLeft, onRight);

  bool get isLeft => this is Left<L, R>;
  bool get isRight => this is Right<L, R>;

  Either<L2, R> mapLeft<L2>(L2 Function(L) f) =>
      match((l) => Left<L2, R>(f(l)), (r) => Right<L2, R>(r));

  Either<L, R2> map<R2>(R2 Function(R) f) =>
      match((l) => Left<L, R2>(l), (r) => Right<L, R2>(f(r)));

  Either<L, R2> flatMap<R2>(Either<L, R2> Function(R) f) =>
      match((l) => Left<L, R2>(l), f);

  /// Alias for [flatMap].
  Either<L, R2> andThen<R2>(Either<L, R2> Function(R) f) => flatMap(f);

  /// Applicative apply for Either (short-circuits on first Left).
  Either<L, R2> ap<R2>(Either<L, R2 Function(R)> f) =>
      f.flatMap((fn) => map(fn));

  R getOrElse(R Function(L) orElse) => match(orElse, (r) => r);

  Either<L, R> orElse(Either<L, R> Function(L) orElse) =>
      match(orElse, (r) => Right<L, R>(r));

  /// Swap sides.
  Either<R, L> swap() =>
      match((l) => Right<R, L>(l), (r) => Left<R, L>(r));

  /// Convert Right to [Option], dropping Left.
  Option<R> toOption() =>
      match((_) => None<R>(), (r) => Some<R>(r));

  /// Nullable view of Right.
  R? toNullable() => match((_) => null, (r) => r);

  /// Convert to [Validation] (single error).
  Validation<L, R> toValidation() =>
      match((e) => Validation<L, R>.invalid(e), (v) => Validation<L, R>.valid(v));

  /// Combine with [other] using [combine] when both are Right.
  /// Returns first Left encountered.
  Either<L, C> zipWith<C, B>(Either<L, B> other, C Function(R, B) combine) =>
      flatMap((a) => other.map((b) => combine(a, b)));

  /// First Right wins, else [other].
  Either<L, R> alt(Either<L, R> Function() other) =>
      isRight ? this : other();

  /// Tap into Right value without changing it.
  Either<L, R> tap(void Function(R) f) {
    final self = this;
    if (self is Right<L, R>) f(self.value);
    return this;
  }

  /// Tap into Left value without changing it.
  Either<L, R> tapLeft(void Function(L) f) {
    final self = this;
    if (self is Left<L, R>) f(self.value);
    return this;
  }

  /// Sequence: `List<Either>` -> `Either<List>`. Short-circuits on first Left.
  static Either<L, List<R>> sequence<L, R>(Iterable<Either<L, R>> items) {
    final out = <R>[];
    for (final e in items) {
      final self = e;
      if (self is Left<L, R>) return Left<L, List<R>>(self.value);
      if (self is Right<L, R>) out.add(self.value);
    }
    return Right<L, List<R>>(out);
  }

  /// Traverse.
  static Either<L, List<B>> traverse<L, A, B>(
      Iterable<A> items, Either<L, B> Function(A) f) {
    final out = <B>[];
    for (final a in items) {
      final eb = f(a);
      if (eb is Left<L, B>) return Left<L, List<B>>(eb.value);
      if (eb is Right<L, B>) out.add(eb.value);
    }
    return Right<L, List<B>>(out);
  }
}

/// Failure side.
final class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);

  @override
  B match<B>(B Function(L) onLeft, B Function(R) onRight) => onLeft(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Left<L, R> && other.value == value);

  @override
  int get hashCode => value.hashCode ^ 0x3A7;

  @override
  String toString() => 'Left($value)';
}

/// Success side.
final class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);

  @override
  B match<B>(B Function(L) onLeft, B Function(R) onRight) => onRight(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Right<L, R> && other.value == value);

  @override
  int get hashCode => value.hashCode ^ 0x7A9;

  @override
  String toString() => 'Right($value)';
}

/// Convenience constructors.
Either<L, R> left<L, R>(L value) => Left<L, R>(value);
Either<L, R> right<L, R>(R value) => Right<L, R>(value);
