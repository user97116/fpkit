/// IO, Task, TaskEither, TaskOption — lazy (effect) wrappers.
library;

import 'either.dart';
import 'option.dart';

/// Unit value — used where `void` cannot be a type argument.
final class Unit {
  const Unit._();
  static const unit = Unit._();
  @override
  String toString() => 'unit';
}

const unit = Unit.unit;

/// Lazy synchronous effect: `() => A`.
///
/// ```dart
/// final io = IO(() => DateTime.now()).map((t) => t.year);
/// final year = io.run();
/// ```
final class IO<A> {
  final A Function() run;
  const IO(this.run);

  /// Pure value.
  factory IO.pure(A value) => IO(() => value);

  /// Delay a thunk.
  factory IO.delay(A Function() thunk) => IO(thunk);

  /// Capture exceptions into [Either].
  Either<Object, A> attempt() {
    try {
      return Right<Object, A>(run());
    } catch (e) {
      return Left<Object, A>(e);
    }
  }

  IO<B> map<B>(B Function(A) f) => IO(() => f(run()));

  IO<B> flatMap<B>(IO<B> Function(A) f) => IO(() => f(run()).run());

  IO<B> andThen<B>(IO<B> Function(A) f) => flatMap(f);

  /// Sequence: run this, then [next], keep [next]'s value.
  IO<B> zipRight<B>(IO<B> next) => flatMap((_) => next);

  /// Run both, combine results.
  IO<C> zipWith<B, C>(IO<B> other, C Function(A, B) combine) =>
      IO(() => combine(run(), other.run()));

  /// Fallback on throw.
  IO<A> orElse(IO<A> Function(Object, StackTrace) fallback) => IO(() {
        try {
          return run();
        } catch (e, s) {
          return fallback(e, s).run();
        }
      });

  void unsafeRun() => run();
}

/// Lazy async effect: `() => Future<A>`.
///
/// ```dart
/// final t = Task(() async => fetchUser());
/// final names = await t.map((u) => u.name).run();
/// ```
final class Task<A> {
  final Future<A> Function() run;
  const Task(this.run);

  factory Task.pure(A value) => Task(() async => value);
  factory Task.delay(Future<A> Function() thunk) => Task(thunk);
  factory Task.fromFuture(Future<A> future) => Task(() => future);

  Task<B> map<B>(B Function(A) f) => Task(() async => f(await run()));

  Task<B> flatMap<B>(Task<B> Function(A) f) =>
      Task(() async => f(await run()).run());

  Task<B> andThen<B>(Task<B> Function(A) f) => flatMap(f);

  Task<A> orElse(Task<A> Function(Object, StackTrace) fallback) =>
      Task(() async {
        try {
          return await run();
        } catch (e, s) {
          return fallback(e, s).run();
        }
      });

  /// Run all tasks in parallel, collect results.
  static Task<List<A>> sequence<A>(Iterable<Task<A>> tasks) =>
      Task(() => Future.wait(tasks.map((t) => t.run())));

  /// Traverse.
  static Task<List<B>> traverse<A, B>(
          Iterable<A> items, Task<B> Function(A) f) =>
      sequence(items.map(f));

  Future<A> unsafeRun() => run();
}

/// Lazy async effect returning [Either]: `() => Future<Either<L, R>>`.
/// The workhorse for async fallible code (network, IO).
///
/// ```dart
/// TaskEither<String, int> fetchAge() => TaskEither.tryCatch(
///   () async => 42, (e, _) => e.toString(),
/// );
/// ```
final class TaskEither<L, R> {
  final Future<Either<L, R>> Function() run;
  const TaskEither(this.run);

  factory TaskEither.pure(R value) =>
      TaskEither(() async => Right<L, R>(value));
  factory TaskEither.left(L error) =>
      TaskEither(() async => Left<L, R>(error));
  factory TaskEither.fromEither(Either<L, R> e) => TaskEither(() async => e);

  factory TaskEither.tryCatch(
    Future<R> Function() f,
    L Function(Object error, StackTrace stack) onError,
  ) =>
      TaskEither(() async {
        try {
          return Right<L, R>(await f());
        } catch (e, s) {
          return Left<L, R>(onError(e, s));
        }
      });

  TaskEither<L, R2> map<R2>(R2 Function(R) f) => TaskEither(() async {
        final e = await run();
        if (e is Left<L, R>) return Left<L, R2>(e.value);
        final r = e as Right<L, R>;
        return Right<L, R2>(f(r.value));
      });

  TaskEither<L2, R> mapLeft<L2>(L2 Function(L) f) => TaskEither(() async {
        final e = await run();
        if (e is Left<L, R>) return Left<L2, R>(f(e.value));
        final r = e as Right<L, R>;
        return Right<L2, R>(r.value);
      });

  TaskEither<L, R2> flatMap<R2>(TaskEither<L, R2> Function(R) f) =>
      TaskEither(() async {
        final e = await run();
        if (e is Left<L, R>) return Left<L, R2>(e.value);
        final r = e as Right<L, R>;
        return f(r.value).run();
      });

  TaskEither<L, R2> andThen<R2>(TaskEither<L, R2> Function(R) f) =>
      flatMap(f);

  TaskEither<L, R> orElse(TaskEither<L, R> Function(L) fallback) =>
      TaskEither(() async {
        final e = await run();
        if (e is Left<L, R>) return fallback(e.value).run();
        return e;
      });

  /// Fallback value on Left.
  Task<R> getOrElse(R Function(L) orElse) => Task(() async {
        final e = await run();
        if (e is Left<L, R>) return orElse(e.value);
        return (e as Right<L, R>).value;
      });

  /// First Right wins.
  TaskEither<L, R> alt(TaskEither<L, R> Function() other) =>
      TaskEither(() async {
        final e = await run();
        if (e.isRight) return e;
        return other().run();
      });

  static TaskEither<L, List<R>> sequence<L, R>(
      Iterable<TaskEither<L, R>> tasks) {
    return TaskEither(() async {
      final out = <R>[];
      for (final t in tasks) {
        final e = await t.run();
        if (e is Left<L, R>) return Left<L, List<R>>(e.value);
        out.add((e as Right<L, R>).value);
      }
      return Right<L, List<R>>(out);
    });
  }

  Future<Either<L, R>> unsafeRun() => run();
}

/// Lazy async effect returning [Option].
final class TaskOption<T> {
  final Future<Option<T>> Function() run;
  const TaskOption(this.run);

  factory TaskOption.pure(T value) =>
      TaskOption(() async => Some<T>(value));
  factory TaskOption.none() => TaskOption(() async => None<T>());
  factory TaskOption.fromOption(Option<T> o) => TaskOption(() async => o);

  TaskOption<U> map<U>(U Function(T) f) => TaskOption(() async {
        final o = await run();
        if (o is Some<T>) return Some<U>(f(o.value));
        return None<U>();
      });

  TaskOption<U> flatMap<U>(TaskOption<U> Function(T) f) =>
      TaskOption(() async {
        final o = await run();
        if (o is Some<T>) return f(o.value).run();
        return None<U>();
      });

  Future<Option<T>> unsafeRun() => run();
}
