/// Re-runs [loader] whenever [changes] emits, including once up front.
Stream<T> watchLocalData<T>(
  Stream<void> changes,
  Future<T> Function() loader,
) async* {
  yield await loader();
  await for (final _ in changes) {
    yield await loader();
  }
}
