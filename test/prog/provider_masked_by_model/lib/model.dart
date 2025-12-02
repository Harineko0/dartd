class User {
  final String name;

  User(this.name);
}

String greet(User user) => 'Hello, ${user.name}';
