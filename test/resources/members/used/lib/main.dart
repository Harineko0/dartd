import 'profile.dart';

class Credentials {
  final String username;
  final String password;

  Credentials({required this.username, required this.password});

  String label() => '$username:$password';
}

void main() {
  Credentials(username: 'dash', password: 'secret').label();
  Profile('dash@example.com').email;
}
