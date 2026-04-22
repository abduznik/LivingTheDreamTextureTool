class UgcTextureEntry {
  final String stem;
  final String ugctexPath;
  final String? thumbPath;
  final String? canvasPath;
  final String directory;

  UgcTextureEntry({
    required this.stem,
    required this.ugctexPath,
    this.thumbPath,
    this.canvasPath,
    required this.directory,
  });

  bool get hasThumb => thumbPath != null;
  bool get hasCanvas => canvasPath != null;
  String get displayName => stem;
}
