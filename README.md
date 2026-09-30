# fpkit

Ultimate functional programming toolkit for **Dart 3+ & Flutter**.
A modern successor to `dartz` / `fpdart`, built on `sealed` classes,
pattern matching and records.

## Types

| Type | Description |
|------|-------------|
| `Option<T>` (`Some`/`None`) | Explicit nullable, `map`/`flatMap`/`filter`/`toEither`/`sequence`/`traverse` |
| `Either<L,R>` (`Left`/`Right`) | Short-circuiting success/failure, `tryCatch`, `zipWith`, `sequence` |
| `Result<T,E>` (`Ok`/`Err`), `Try<T>` | Exception-friendly result, `tryCatch` + async |
| `Validation<E,A>` | Applicative error **accumulation** (`zipWith`, `sequence`) |
| `IO<A>` | Lazy sync effect `() => A` |
| `Task<A>` | Lazy async effect `() => Future<A>` |
| `TaskEither<L,R>` | Lazy `Future<Either>` — async fallible workhorse |
| `TaskOption<T>` | Lazy `Future<Option>` |
| `Reader<R,A>` | DI / environment reader |
| `Writer<W,A>` | Value + accumulated log |
| `State<S,A>` | Pure state threading over records `(S, A)` |
| `IList<T>` | Persistent immutable list |
| `Unit` | `void`-as-a-value |

Plus: `function.dart` (`pipe`, `compose`/`then`, `curry2`, `memoize`, `tap`, `also`, `let`),
`predicate.dart` (`and`/`or`/`neg`, `contramap`, `allPass`/`anyPass`),
`extensions.dart` (nullable `toOption`/`toEither`, `Iterable.traverseEither`,
`Future.toTask`, string parsers, ...).

## Quick start

```dart
import 'package:fpkit/fpkit.dart';

// Option
final name = Option.fromNullable(maybeName)
  .map((s) => s.toUpperCase())
  .getOrElse(() => 'GUEST');

// Either
Either<String, int> parseAge(String s) {
  final v = int.tryParse(s);
  return v == null ? left('bad age: $s') : right(v);
}
final age = parseAge('42').map((n) => n + 1).getOrElse((_) => 0);

// Validation accumulates errors (Either short-circuits)
final v = Validation.valid<String, int>(1)
  .zipWith(Validation.invalid<String, int>('boom'), (a, b) => a + b);

// Async fallible
TaskEither<String, int> fetchAge() =>
  TaskEither.tryCatch(() async => 42, (e, _) => e.toString());

// Reader for DI
final greeting = Reader<Map<String, String>, String>(
  (env) => 'Hello ${env['name']}',
);

// State
final counter = State<int, int>((s) => (s + 1, s));

// Pipe
final r = 1.pipe((x) => x + 1).pipe((x) => x * 10); // 20
```

## Why fpkit over dartz/fpdart?

- Dart 3 native: `sealed`, exhaustive `switch`, records `(S, A)`.
- One import, consistent naming (`map`/`flatMap`/`andThen`/`zipWith`/`sequence`/`traverse`).
- Both short-circuit (`Either`) and accumulating (`Validation`) error models.
- Effects covered: `IO` / `Task` / `TaskEither` / `TaskOption` / `Reader` / `Writer` / `State`.
- Flutter-ready: pure Dart, no Flutter SDK dependency, works on all platforms.

## Running tests

```sh
dart test
# or
flutter test
```
