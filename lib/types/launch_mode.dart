// What the boot gate decided on a previous run.
//
// `firstBoot` is the persisted absence of any prior decision: the next
// launch must consult the verdict endpoint. `web` and `local` are
// terminal — once a user lands on one side, they remain on that side
// across cold starts (the back end is the only place that can flip a
// user from `local` back to `web`, by design).

enum LaunchMode {
  web,
  local,
  firstBoot;

  static LaunchMode parse(String? raw) {
    switch (raw) {
      case 'web':
        return LaunchMode.web;
      case 'local':
        return LaunchMode.local;
      default:
        return LaunchMode.firstBoot;
    }
  }

  String get persistKey {
    switch (this) {
      case LaunchMode.web:
        return 'web';
      case LaunchMode.local:
        return 'local';
      case LaunchMode.firstBoot:
        return 'first';
    }
  }
}
