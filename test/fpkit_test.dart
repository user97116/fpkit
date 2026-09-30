import 'package:fpkit/fpkit.dart';
import 'package:test/test.dart';

void main() {
  group('Option', () {
    test('some/none basics', () {
      expect(some(1).isSome, isTrue);
      expect(none<int>().isNone, isTrue);
      expect(Option.fromNullable(null).isNone, isTrue);
      expect(Option.fromNullable(2).value, 2);
      expect(() => none<int>().value, throwsStateError);
    });

    test('map/flatMap/filter/getOrElse', () {
      expect(some(2).map((n) => n * 3), some(6));
      expect(none<int>().map((n) => n * 3), none<int>());
      expect(some(2).flatMap((n) => some(n + 1)), some(3));
      expect(some(2).filter((n) => n.isEven), some(2));
      expect(some(3).filter((n) => n.isEven), none<int>());
      expect(none<int>().getOrElse(() => 7), 7);
    });

    test('toEither/toNullable/zipWith/sequence/traverse', () {
      expect(some(1).toEither(() => 'e'), right<String, int>(1));
      expect(none<int>().toEither(() => 'e'), left<String, int>('e'));
      expect(some(1).toNullable(), 1);
      expect(none<int>().toNullable(), isNull);
      expect(
        some(2).zipWith(some(3), (a, b) => a + b),
        some(5),
      );
      expect(
        Option.sequence([some(1), some(2)]).toNullable(),
        orderedEquals([1, 2]),
      );
      expect(
        Option.sequence<int>([some(1), none()]),
        none<List<int>>(),
      );
      expect(
        Option.traverse([1, 2], (n) => some(n * 2)).toNullable(),
        orderedEquals([2, 4]),
      );
    });

    test('tryCatch', () {
      expect(Option.tryCatch(() => 1), some(1));
      expect(Option<int>.tryCatch(() => throw 'x'), none<int>());
    });
  });

  group('Either', () {
    test('map/flatMap/getOrElse', () {
      Either<String, int> e = right(2);
      expect(e.map((n) => n * 2), right(4));
      expect(e.flatMap((n) => right<String, int>(n + 1)), right(3));
      Either<String, int> l = left('err');
      expect(l.map((n) => n * 2), left('err'));
      expect(e.getOrElse((_) => 0), 2);
      expect(l.getOrElse((_) => 0), 0);
    });

    test('tryCatch/sequence/traverse/swap', () {
      final ok = Either<String, int>.tryCatch(() => 1, (e, _) => '$e');
      expect(ok, right(1));
      final bad =
          Either<String, int>.tryCatch(() => throw 'boom', (e, _) => '$e');
      expect(bad.isLeft, isTrue);
      expect(Either.sequence<String, int>([right(1), right(2)]).toNullable(),
          orderedEquals([1, 2]));
      expect(
        Either.sequence<String, int>([right(1), left('x')]).isLeft,
        isTrue,
      );
      expect(
          Either.traverse([1, 2], (n) => right<String, int>(n)).toNullable(),
          orderedEquals([1, 2]));
      expect(right<String, int>(1).swap(), left<int, String>(1));
    });
  });

  group('Validation', () {
    test('accumulates errors via zipWith', () {
      final a = Validation<String, int>.valid(1);
      final b = Validation<String, int>.invalid('e1');
      final c = Validation<String, int>.invalid('e2');
      expect(a.zipWith(b, (x, y) => x + y).errors, ['e1']);
      expect(b.zipWith(c, (x, y) => x + y).errors, ['e1', 'e2']);
      expect(
        a.zipWith(Validation<String, int>.valid(2), (x, y) => x + y),
        Validation<String, int>.valid(3),
      );
    });

    test('sequence collects all errors', () {
      final r = Validation.sequence([
        Validation<String, int>.valid(1),
        Validation<String, int>.invalid('a'),
        Validation<String, int>.invalid('b'),
      ]);
      expect(r.errors, ['a', 'b']);
    });
  });

  group('Result', () {
    test('ok/err + tryCatch', () {
      expect(Result.tryCatch(() => 1, (e, _) => '$e'), isA<Ok<int, String>>());
      final r = Result<int, String>.tryCatch(
          () => throw 'x', (e, _) => 'caught:$e');
      expect(r, const Err<int, String>('caught:x'));
      expect(const Ok<int, String>(2).map((n) => n + 1), const Ok(3));
    });
  });

  group('effects IO/Task/TaskEither', () {
    test('IO lazy + map', () {
      var ran = false;
      final io = IO(() {
        ran = true;
        return 21;
      }).map((n) => n * 2);
      expect(ran, isFalse);
      expect(io.run(), 42);
      expect(ran, isTrue);
    });

    test('Task map/flatMap', () async {
      final t = Task.pure(2).map((n) => n * 3).flatMap((n) => Task.pure(n + 1));
      expect(await t.run(), 7);
    });

    test('TaskEither map + left short-circuit', () async {
      final ok = TaskEither<String, int>.pure(2).map((n) => n * 2);
      expect(await ok.run(), right(4));
      final bad =
          TaskEither<String, int>.left('nope').map((n) => n * 2);
      expect((await bad.run()).isLeft, isTrue);
      final caught = TaskEither.tryCatch(
        () async => throw 'boom',
        (e, _) => 'caught:$e',
      );
      expect((await caught.run()).isLeft, isTrue);
    });
  });

  group('Reader/Writer/State', () {
    test('Reader', () {
      final r = Reader<Map<String, int>, int>((env) => env['n']! * 2);
      expect(r.run({'n': 21}), 42);
      expect(r.map((n) => n + 1).run({'n': 1}), 3);
    });

    test('Writer', () {
      final w = Writer<List<String>, int>(['a'], 1)
          .map((n) => n + 1)
          .tell(['b'], (x, y) => [...x, ...y]);
      expect(w.value, 2);
      expect(w.log, ['a', 'b']);
    });

    test('State threads', () {
      final inc = State<int, int>((s) => (s + 1, s));
      expect(inc.run(0), (1, 0));
      final p = inc.flatMap((v) => State.pure(v * 10));
      expect(p.run(5), (6, 50));
      expect(State.gets<int>().evalState(9), 9);
    });
  });

  group('function/predicate/extensions/ilist', () {
    test('pipe/compose/memoize', () {
      expect(1.pipe((x) => x + 1).pipe((x) => x * 10), 20);
      final f = compose((int x) => x + 1, (int x) => x * 2);
      expect(f(3), 8);
      var calls = 0;
      final m = memoize((int x) {
        calls++;
        return x * 2;
      });
      expect(m(2), 4);
      expect(m(2), 4);
      expect(calls, 1);
    });

    test('predicates', () {
      bool pEven(int n) => n.isEven;
      bool pPos(int n) => n > 0;
      expect(pEven.and(pPos)(4), isTrue);
      expect(pEven.and(pPos)(-4), isFalse);
      expect(allPass([pEven, pPos])(4), isTrue);
      expect(anyPass([pEven, pPos])(-3), isFalse);
    });

    test('extensions', () {
      expect((null as int?).toOption().isNone, isTrue);
      expect(1.toOption(), some(1));
      expect('42'.parseIntEither(), right<String, int>(42));
      expect('xx'.parseIntEither().isLeft, isTrue);
      expect([1, 2, 3].headOption, some(1));
      expect((<int>[]).headOption.isNone, isTrue);
    });

    test('IList immutable + fp', () {
      final xs = IList([1, 2, 3]);
      final ys = xs.append(4).map((n) => n * 2);
      expect(xs.length, 3); // original untouched
      expect(ys.toList(), [2, 4, 6, 8]);
      expect(xs.headOption, some(1));
      expect(IList<int>.empty().headOption.isNone, isTrue);
      expect(xs.filter((n) => n.isEven).toList(), [2]);
      expect(xs.fold(0, (a, b) => a + b), 6);
    });
  });
}
