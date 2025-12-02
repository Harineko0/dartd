abstract interface class PartialUpdaterReceiver<T> {
  void partialUpdaterReceiver(void Function<T>([T param])? updater);
}
