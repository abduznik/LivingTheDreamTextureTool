class EmulatorPath {
  final String emulatorName;
  final String path;
  final String userId;

  EmulatorPath({
    required this.emulatorName,
    required this.path,
    required this.userId,
  });

  @override
  String toString() => '$emulatorName ($userId): $path';
}
