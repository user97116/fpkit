/// Function combinators: identity, compose, curry, memoize, pipe.
library;

/// Identity: returns its argument unchanged.
A identity<A>(A a) => a;

/// Constant: always returns [a] regardless of input.
B Function(A) constant<A, B>(B b) => (_) => b;

/// Forward composition: `compose(f, g)(x) == g(f(x))`.
C Function(A) compose<A, B, C>(B Function(A) f, C Function(B) g) =>
    (a) => g(f(a));

/// Backward composition: `composeBackward(f, g)(x) == f(g(x))`.
A Function(C) composeBackward<A, B, C>(A Function(B) f, B Function(C) g) =>
    (c) => f(g(c));

/// Alias for [compose].
C Function(A) andThen<A, B, C>(B Function(A) f, C Function(B) g) =>
    compose(f, g);

/// Pipe a value through a list of transforms.
A pipeN<A>(A value, List<A Function(A)> fns) =>
    fns.fold(value, (acc, f) => f(acc));

/// Curry a 2-arg function.
B Function(B1) Function(A1) curry2<A1, B1, B>(B Function(A1, B1) f) =>
    (a) => (b) => f(a, b);

/// Curry a 3-arg function.
C Function(B1) Function(A1) Function(A1_2) curry3<A1_2, A1, B1, C>(
        C Function(A1_2, A1, B1) f) =>
    (a) => (b) => (c) => f(a, b, c);

/// Flip arguments of a 2-arg function.
B Function(B1, A1) flip<A1, B1, B>(B Function(A1, B1) f) =>
    (b, a) => f(a, b);

/// Memoize a pure single-arg function (cache by argument).
B Function(A) memoize<A, B>(B Function(A) f) {
  final cache = <A, B>{};
  return (a) => cache.putIfAbsent(a, () => f(a));
}

/// Run [effect] with [value] then return [value] (tap / also).
A tap<A>(A value, void Function(A) effect) {
  effect(value);
  return value;
}

/// Negate a predicate.
bool Function(A) not<A>(bool Function(A) p) => (a) => !p(a);

/// Pipe operator extension: `x.pipe(f).pipe(g)`.
extension PipeExt<T> on T {
  /// Apply [f] to `this` and return the result.
  U pipe<U>(U Function(T) f) => f(this);

  /// Apply [f] for side effects, return `this`.
  T also(void Function(T) f) {
    f(this);
    return this;
  }

  /// Alias for Kotlin-style `let`.
  U let<U>(U Function(T) f) => f(this);
}

/// Function composition extensions.
extension FnCompose<A, B> on B Function(A) {
  /// `f.then(g)` == `g(f(x))`.
  C Function(A) then<C>(C Function(B) g) => (a) => g(this(a));
}

/// Retry helper for sync functions.
T retry<T>(T Function() f, {int attempts = 3}) {
  Object? last;
  for (var i = 0; i < attempts; i++) {
    try {
      return f();
    } catch (e) {
      last = e;
    }
  }
  // ignore: only_throw_errors
  throw last ?? StateError('retry failed');
}
