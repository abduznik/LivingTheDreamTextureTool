class VrsTextureEntry {
  final String stem;
  final String vrsPath;
  final String? thumbPath;
  final String? canvasPath;
  final String directory;

  VrsTextureEntry({
    required this.stem,
    required this.vrsPath,
    this.thumbPath,
    this.canvasPath,
    required this.directory,
  });

  bool get hasThumb => thumbPath != null;
  bool get hasCanvas => canvasPath != null;
  String get displayName => stem;
}
