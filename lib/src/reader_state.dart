/// Reader, Writer, State — classic FP environment / log / state monads.
library;

import 'either.dart';
import 'option.dart';

/// `Reader<R, A>`: a computation that reads from an environment `R`.
///
/// Great for dependency injection without globals.
///
/// ```dart
/// final greeting = Reader<Map<String, String>, String>(
///   (env) => 'Hello ${env['name']}',
/// );
/// greeting.run({'name': 'Ada'}); // Hello Ada
/// ```
final class Reader<R, A> {
  final A Function(R) run;
  const Reader(this.run);

  factory Reader.pure(A value) => Reader((_) => value);
  factory Reader.ask() => throw UnsupportedError('Use Reader((r) => r)');

  /// Read the environment itself.
  static Reader<R, R> asks<R>() => Reader((r) => r);

  /// Project part of the environment.
  static Reader<R, A> asksWith<R, A>(A Function(R) f) => Reader(f);

  Reader<R, B> map<B>(B Function(A) f) => Reader((r) => f(run(r)));

  Reader<R, B> flatMap<B>(Reader<R, B> Function(A) f) =>
      Reader((r) => f(run(r)).run(r));

  Reader<R, B> andThen<B>(Reader<R, B> Function(A) f) => flatMap(f);

  /// Change the environment before running.
  Reader<R2, A> local<R2>(R Function(R2) f) => Reader((r2) => run(f(r2)));

  A runWith(R env) => run(env);
}

/// `Writer<W, A>`: a value `A` alongside an accumulated log `W`.
///
/// ```dart
/// final w = Writer<List<String>, int>(['start'], 1)
///   .map((n) => n + 1)
///   .tell(['bumped']);
/// ```
final class Writer<W, A> {
  final W log;
  final A value;
  const Writer(this.log, this.value);

  factory Writer.pure(W empty, A value) => Writer(empty, value);

  Writer<W, B> map<B>(B Function(A) f) => Writer(log, f(value));

  Writer<W, B> flatMap<B>(
    Writer<W, B> Function(A) f,
    W Function(W, W) combine,
  ) {
    final next = f(value);
    return Writer(combine(log, next.log), next.value);
  }

  /// Append to log using [combine].
  Writer<W, A> tell(W entry, W Function(W, W) combine) =>
      Writer(combine(log, entry), value);

  /// Apply [f] to the log.
  Writer<W2, A> mapLog<W2>(W2 Function(W) f) => Writer(f(log), value);

  (W, A) run() => (log, value);
}

/// `State<S, A>`: a computation threading mutable-like state `S` purely.
///
/// Uses Dart 3 records `(S, A)`.
///
/// ```dart
/// final counter = State<int, int>((s) => (s + 1, s));
/// final (s1, v1) = counter.run(0); // (1, 0)
/// ```
final class State<S, A> {
  final (S, A) Function(S) run;
  const State(this.run);

  factory State.pure(A value) => State((s) => (s, value));

  /// Canonical getters (typed helpers to avoid casts).
  static State<S, S> gets<S>() => State((s) => (s, s));
  static State<S, void> puts<S>(S next) => State((_) => (next, null));

  static State<S, A> inspect<S, A>(A Function(S) f) =>
      State((s) => (s, f(s)));
  static State<S, void> modify<S>(S Function(S) f) =>
      State((s) => (f(s), null));

  State<S, B> map<B>(B Function(A) f) =>
      State((s) { final (ns, a) = run(s); return (ns, f(a)); });

  State<S, B> flatMap<B>(State<S, B> Function(A) f) => State((s) {
        final (ns, a) = run(s);
        return f(a).run(ns);
      });

  State<S, B> andThen<B>(State<S, B> Function(A) f) => flatMap(f);

  /// Run and keep final state.
  S execState(S initial) => run(initial).$1;

  /// Run and keep produced value.
  A evalState(S initial) => run(initial).$2;
}

/// Either conveniences shared by Reader/State users.
extension ReaderEitherOps<R, L, A> on Reader<R, Either<L, A>> {
  Reader<R, Either<L, B>> mapE<B>(B Function(A) f) =>
      Reader((r) => run(r).map(f));
}

/// Option conveniences.
extension ReaderOptionOps<R, A> on Reader<R, Option<A>> {
  Reader<R, Option<B>> mapO<B>(B Function(A) f) =>
      Reader((r) => run(r).map(f));
}
