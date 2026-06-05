import 'dart:async';

/// Re-runs [loader] whenever [changes] emits, including once up front.
///
/// [debounce] coalesces rapid SQLite notifications (e.g. drain batches).
Stream<T> watchLocalData<T>(
  Stream<void> changes,
  Future<T> Function() loader, {
  Duration debounce = const Duration(milliseconds: 200),
}) async* {
  yield await loader();
  await for (final _ in changes.debounce(debounce)) {
    yield await loader();
  }
}

extension _DebounceStream<T> on Stream<T> {
  Stream<T> debounce(Duration duration) {
    Timer? timer;
    late StreamController<T> controller;
    late StreamSubscription<T> subscription;

    controller = StreamController<T>(
      onListen: () {
        subscription = listen(
          (data) {
            timer?.cancel();
            timer = Timer(duration, () {
              if (!controller.isClosed) controller.add(data);
            });
          },
          onError: controller.addError,
          onDone: () {
            timer?.cancel();
            controller.close();
          },
        );
      },
      onCancel: () async {
        timer?.cancel();
        await subscription.cancel();
      },
    );

    return controller.stream;
  }
}
