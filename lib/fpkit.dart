/// fpkit — ultimate functional programming toolkit for Dart 3+ & Flutter.
///
/// Import one file and get `Option`, `Either`, `Result`, `Validation`,
/// `IO`, `Task`, `TaskEither`, `TaskOption`, `Reader`, `Writer`, `State`,
/// `IList`, function combinators, predicates and extensions.
///
/// ```dart
/// import 'package:fpkit/fpkit.dart';
///
/// Either<String, int> parseAge(String s) =>
///   int.tryParse(s)?.toRight('bad age') ?? left('bad age');
/// ```
library;

export 'src/option.dart';
export 'src/either.dart';
export 'src/result.dart';
export 'src/validation.dart';
export 'src/effects.dart';
export 'src/reader_state.dart';
export 'src/function.dart';
export 'src/predicate.dart';
export 'src/extensions.dart';
export 'src/ilist.dart';
