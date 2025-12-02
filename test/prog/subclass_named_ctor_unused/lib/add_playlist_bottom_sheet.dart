class Key {
  const Key();
}

class HookWidget {
  final Key? key;
  const HookWidget({this.key});
}

class AddPlaylistBottomSheet extends HookWidget {
  const AddPlaylistBottomSheet({
    super.key,
    required this.onPlaylistSubmitted,
  });

  final void Function(String) onPlaylistSubmitted;
}
