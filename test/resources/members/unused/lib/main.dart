import 'profile.dart';

class Credentials {
  final String username;
  final String password;

  Credentials({required this.username, this.password = 'unused'});

  String label() => username;
}

void main() {
  Credentials(username: 'dash').label();
  // Nothing else is referenced.
}
