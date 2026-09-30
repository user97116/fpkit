/// Immutable list with structural sharing semantics and FP helpers.
library;

import 'either.dart';
import 'option.dart';

/// Persistent immutable list.
///
/// ```dart
/// final xs = IList([1, 2, 3]);
/// final ys = xs.append(4).map((n) => n * 2);
/// ```
final class IList<T> extends Iterable<T> {
  final List<T> _inner;

  const IList._(this._inner);

  /// Create from an iterable (snapshots).
  factory IList(Iterable<T> items) => IList._(List.unmodifiable(items));

  /// Empty list.
  factory IList.empty() => IList._(const []);

  /// Single element.
  factory IList.single(T value) => IList._([value]);

  /// Number of elements.
  @override
  int get length => _inner.length;

  @override
  Iterator<T> get iterator => _inner.iterator;

  /// Index access.
  T operator [](int index) => _inner[index];

  /// Append one element.
  IList<T> append(T value) => IList._([..._inner, value]);

  /// Prepend one element.
  IList<T> prepend(T value) => IList._([value, ..._inner]);

  /// Concat.
  IList<T> concat(IList<T> other) => IList._([..._inner, ...other._inner]);

  /// Alias for [concat].
  IList<T> operator +(IList<T> other) => concat(other);

  @override
  IList<U> map<U>(U Function(T) toElement) =>
      IList._(_inner.map(toElement).toList(growable: false));

  /// Map with index.
  IList<U> mapWithIndex<U>(U Function(int index, T value) f) =>
      IList._([for (var i = 0; i < _inner.length; i++) f(i, _inner[i])]);

  @override
  IList<T> where(bool Function(T) test) =>
      IList._(_inner.where(test).toList(growable: false));

  /// Alias for [where].
  IList<T> filter(bool Function(T) test) => where(test);

  @override
  IList<U> expand<U>(Iterable<U> Function(T) toElements) =>
      IList._(_inner.expand(toElements).toList(growable: false));

  IList<U> flatMap<U>(IList<U> Function(T) f) {
    final out = <U>[];
    for (final t in _inner) {
      out.addAll(f(t)._inner);
    }
    return IList._(out);
  }

  /// Fold (left).
  @override
  S fold<S>(S initial, S Function(S acc, T value) combine) =>
      _inner.fold(initial, combine);

  /// Reduce to [Either]: Left on empty.
  Either<String, T> reduceEither(T Function(T, T) combine) {
    if (_inner.isEmpty) return Left<String, T>('Empty list');
    return Right<String, T>(_inner.reduce(combine));
  }

  /// Safe head.
  Option<T> get headOption {
    if (_inner.isEmpty) return None<T>();
    return Some<T>(_inner.first);
  }

  /// Safe last.
  Option<T> get lastOption {
    if (_inner.isEmpty) return None<T>();
    return Some<T>(_inner.last);
  }

  /// Safe index.
  Option<T> getOption(int index) {
    if (index < 0 || index >= _inner.length) return None<T>();
    return Some<T>(_inner[index]);
  }

  /// Take / drop (return new IList).
  IList<T> takeN(int n) => IList._(_inner.take(n).toList(growable: false));
  IList<T> dropN(int n) => IList._(_inner.skip(n).toList(growable: false));

  /// Reverse.
  IList<T> get reversedList =>
      IList._(_inner.reversed.toList(growable: false));

  /// Sort by comparator.
  IList<T> sorted([int Function(T, T)? compare]) {
    final copy = [..._inner];
    copy.sort(compare);
    return IList._(copy);
  }

  /// Distinct values.
  IList<T> distinct() => IList._(_inner.toSet().toList(growable: false));

  /// Zip with another list.
  IList<(T, U)> zip<U>(IList<U> other) {
    final n =
        _inner.length < other._inner.length ? _inner.length : other._inner.length;
    return IList._(
        [for (var i = 0; i < n; i++) (_inner[i], other._inner[i])]);
  }

  /// Materialize as mutable list.
  List<T> toMutableList() => [..._inner];

  @override
  List<T> toList({bool growable = true}) => List.of(_inner, growable: growable);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IList<T> &&
          other._inner.length == _inner.length &&
          () {
            for (var i = 0; i < _inner.length; i++) {
              if (other._inner[i] != _inner[i]) return false;
            }
            return true;
          }());

  @override
  int get hashCode => Object.hashAll(_inner);

  @override
  String toString() => 'IList($_inner)';
}

/// Constructors mirroring fpdart/dartz naming.
IList<T> ilist<T>(Iterable<T> items) => IList(items);
IList<T> ilistEmpty<T>() => IList.empty();
