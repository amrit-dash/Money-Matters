import 'dart:async';

/// Serializes async work so only one [run] executes at a time.
class AsyncLock {
  Future<void> _chain = Future<void>.value();

  /// Runs [action] after any prior [run] calls complete.
  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _chain = _chain.then((_) async {
      try {
        if (!completer.isCompleted) {
          completer.complete(await action());
        }
      } catch (e, st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      }
    });
    return completer.future;
  }
}
