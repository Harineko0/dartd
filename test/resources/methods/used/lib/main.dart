import 'secondary.dart';

class Lifecycle {
  void init() {}

  void dispose() {}
}

void main() {
  final lifecycle = Lifecycle();
  lifecycle.init();
  lifecycle.dispose();

  final secondary = SecondaryLifecycle();
  secondary.synchronize();
}
