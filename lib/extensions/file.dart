import 'dart:io';

import 'package:daily_wallpaper_app/extensions/list.dart';

// Assuming a file in the format wallpaper_yyyy-MM-dd_hsh_resolution
// where hsh is a unique identifier for the image and resolution in format 1920x1080

extension CustomFile on FileSystemEntity {
  String get name => uri.pathSegments.last;

  String get nameWithoutEnding => name.split(".").first;

  String get ending => name.split(".").last;

  String? get stringDate => nameWithoutEnding.split("_").tryGet(1);

  DateTime? get date => DateTime.tryParse(stringDate.toString());

  String? get hsh => nameWithoutEnding.split("_").tryGet(2);

  String? get resolution => nameWithoutEnding.split("_").tryGet(3);
}
