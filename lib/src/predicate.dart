/// Predicate, ordering and comparison combinators.
library;

/// A boolean-valued function.
typedef Predicate<T> = bool Function(T);

/// Predicate combinators.
extension PredicateOps<T> on Predicate<T> {
  Predicate<T> and(Predicate<T> other) => (v) => this(v) && other(v);
  Predicate<T> or(Predicate<T> other) => (v) => this(v) || other(v);
  Predicate<T> neg() => (v) => !this(v);

  /// Contravariant mapping: test `B` by first mapping to `T`.
  Predicate<B> contramap<B>(T Function(B) f) => (b) => this(f(b));
}

/// Always-true / always-false predicates.
Predicate<T> always<T>(bool value) => (_) => value;

/// Equality predicate.
Predicate<T> eq<T>(T target) => (v) => v == target;

/// Greater-than / less-than helpers for Comparables.
Predicate<T> greaterThan<T extends Comparable<T>>(T target) =>
    (v) => v.compareTo(target) > 0;
Predicate<T> lessThan<T extends Comparable<T>>(T target) =>
    (v) => v.compareTo(target) < 0;

/// Combine a list of predicates with AND.
Predicate<T> allPass<T>(Iterable<Predicate<T>> ps) =>
    (v) => ps.every((p) => p(v));

/// Combine a list of predicates with OR.
Predicate<T> anyPass<T>(Iterable<Predicate<T>> ps) =>
    (v) => ps.any((p) => p(v));

/// Ordering comparator helpers.
int Function(T, T) contramapCompare<S, T>(
        int Function(S, S) cmp, S Function(T) f) =>
    (a, b) => cmp(f(a), f(b));
