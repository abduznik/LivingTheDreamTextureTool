import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../views/crop_editor_page.dart';

/// Opens the crop editor page and returns the edited bytes.
///
/// Returns `null` if the editor is closed without saving.
Future<Uint8List?> openCropEditor(
  BuildContext context,
  Uint8List imageBytes,
) async {
  return await Navigator.push<Uint8List?>(
    context,
    MaterialPageRoute(
      builder: (context) => CropEditorPage(imageBytes: imageBytes),
    ),
  );
}
