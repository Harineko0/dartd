import 'interface.dart';

interface class Service {
  void perform();
}

class ConcreteService implements Service {
  @override
  void perform() {}
}

class RemoteConcreteService implements RemoteService {
  @override
  void perform() {}
}

void main() {
  Service service = ConcreteService();
  service.perform();

  RemoteService remote = RemoteConcreteService();
  remote.perform();
}
