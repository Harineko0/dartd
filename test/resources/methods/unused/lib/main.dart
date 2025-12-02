import 'secondary.dart';

class Lifecycle {
  void init() {}

  void unusedCallback() {}
}

void main() {
  Lifecycle().init();
  // SecondaryLifecycle is unused.
}
