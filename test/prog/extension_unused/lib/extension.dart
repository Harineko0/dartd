extension FancyString on String {
  String wave() => '~$this~';
}

extension PlacesExtension on Places {
  bool get hasPlaces => placeIds.isNotEmpty;
  int get placeCount => placeIds.length;
}

class Places {
  final List<String> placeIds = const [];
}
