import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Combines several [AsyncValue]s: error if any errored, data once all have
/// data, loading otherwise.
AsyncValue<R> combineAsync<R>(List<AsyncValue<Object?>> values, R Function() build) {
  for (final v in values) {
    if (v.hasError) {
      return AsyncValue<R>.error(v.error!, v.stackTrace ?? StackTrace.current);
    }
  }
  if (values.every((v) => v.hasValue)) return AsyncValue<R>.data(build());
  return AsyncValue<R>.loading();
}
