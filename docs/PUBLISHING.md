# Publishing to pub.dev

1) **Prereqs**
   - Dart SDK authenticated with pub.dev: `dart pub token add https://pub.dev`.
   - `pubspec.yaml` version bumped appropriately.

2) **Verify**
   ```bash
   dart pub get
   dart format .
   dart analyze .
   ```

3) **Dry-run the publish**
   ```bash
   dart pub publish --dry-run
   ```
   Ensure there are no errors or unexpected file inclusions.

4) **Publish**
   ```bash
   dart pub publish
   ```
   Follow the prompts to confirm.

5) **Tag the release**
   ```bash
   git tag v<version>
   git push origin v<version>
   ```

Notes:
- Ensure README, CHANGELOG (if added), and license are present.
- Confirm generated files are excluded or included as intended.
