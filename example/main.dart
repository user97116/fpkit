import 'package:fpkit/fpkit.dart';

Either<String, int> parseAge(String s) {
  final v = int.tryParse(s);
  return v == null ? left('bad age: $s') : right(v);
}

Future<void> main() async {
  // Option
  final name = Option<String>.fromNullable(null).getOrElse(() => 'guest');
  print('name=$name');

  // Either pipeline
  final age = parseAge('42').map((n) => n + 1).getOrElse((_) => 0);
  print('age=$age');

  // Validation accumulates
  final validated = Validation<String, int>.valid(20).zipWith(
    Validation<String, int>.invalid('must be even'),
    (a, b) => a + b,
  );
  print('validated=$validated');

  // TaskEither
  final task = TaskEither<String, int>.tryCatch(
    () async => 42,
    (e, _) => e.toString(),
  ).map((n) => n * 2);
  print('task=${await task.run()}');

  // Reader
  final greeting = Reader<Map<String, String>, String>(
    (env) => 'Hello ${env['name']}',
  );
  print(greeting.run({'name': 'Ada'}));

  // State
  final counter = State<int, int>((s) => (s + 1, s));
  print('state=${counter.run(0)}');

  // IList + pipe
  final total = IList([1, 2, 3, 4])
      .filter((n) => n.isEven)
      .map((n) => n * 10)
      .fold(0, (a, b) => a + b)
      .pipe((n) => 'total=$n');
  print(total);
}
