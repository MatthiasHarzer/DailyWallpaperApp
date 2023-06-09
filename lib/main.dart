import 'package:daily_wallpaper_app/services/background_service.dart';
import 'package:daily_wallpaper_app/services/config_service.dart';
import 'package:daily_wallpaper_app/services/wallpaper_info.dart';
import 'package:daily_wallpaper_app/services/wallpaper_service.dart';
import 'package:daily_wallpaper_app/theme.dart';
import 'package:daily_wallpaper_app/util/log.dart';
import 'package:daily_wallpaper_app/util/util.dart';
import 'package:daily_wallpaper_app/views/about_view.dart';
import 'package:daily_wallpaper_app/views/settings_view.dart';
import 'package:daily_wallpaper_app/views/wallpaper_history_view.dart';
import 'package:daily_wallpaper_app/views/wallpaper_view.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'drawer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ConfigService.ensureInitialized();
  WallpaperService.ensureMaxCacheWallpapers();

  BackgroundService.ensureInitialized();
  await BackgroundService.checkAndScheduleTask();

  await checkLogFileSize();

  // var r = await getExternalStorageDirectories(type: StorageDirectory.pictures) ?? [];
  // for(var rr in r){
  //   print(rr.path);
  // }
  // var r = await get();
  // print(r?.path);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Wallpaper App',
      theme: appTheme,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  WallpaperInfo? wallpaper;
  var logger = getLogger();

  @override
  void initState() {
    super.initState();

    _updateWallpaper();
    _checkPermission();
  }

  /// Checks for required permission
  void _checkPermission() async {
    bool storagePermissionGranted = await _requestStoragePermission();
    // bool s = await _requestExternalStoragePermission();
    // print(s);

    if (!mounted) return;

    if (!storagePermissionGranted) {
      Util.showSnackBar(
        context,
        seconds: 30,
        content: const Text(
            "Storage permission denied. The app might not work correctly."),
        action: SnackBarAction(
          label: "OPEN SETTINGS",
          onPressed: () => openAppSettings(),
        ),
      );
    }
  }

  // ignore: unused_element
  Future<bool> _requestExternalStoragePermission() async {
    final PermissionStatus permission =
        await Permission.manageExternalStorage.status;
    if (permission != PermissionStatus.granted) {
      if (await Permission.manageExternalStorage.request() !=
          PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  /// Requests storage permission. Returns whether permission is granted or not
  Future<bool> _requestStoragePermission() async {
    final PermissionStatus permission = await Permission.storage.status;
    if (permission != PermissionStatus.granted) {
      if (await Permission.storage.request() != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  /// Checks for wallpaper updates and sets the wallpaper variable. Returns true if updated or false if now update is present
  Future<bool> _updateWallpaper() async {
    WallpaperInfo newWallpaper =
        await WallpaperService.getLatestWallpaper(local: ConfigService.region);
    await newWallpaper.ensureDownloaded();

    bool update = newWallpaper.id != wallpaper?.id;

    setState(() {
      wallpaper = newWallpaper;
    });

    if (update) {
      logger.d("Updated wallpaper: $wallpaper");
    }

    return update;
  }

  /// Opens the settings window
  void _openSettingsView() {
    Navigator.pop(context);
    Navigator.push(
      context,
      Util.createScaffoldRoute(view: const SettingsView()),
    );
  }

  void _openAboutView() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => const AboutView(),
    );
  }

  void _openWallpaperHistoryView() {
    Navigator.pop(context);
    Navigator.push(
      context,
      Util.createScaffoldRoute(view: const WallpaperHistoryView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WallpaperView(
      wallpaper: wallpaper,
      onUpdateWallpaper: _updateWallpaper,
      drawer: MainPageDrawer(
        header: wallpaper?.copyright ?? "A Bing Image",
        onSettingsTap: _openSettingsView,
        onAboutTap: _openAboutView,
        onWallpaperHistoryTab: _openWallpaperHistoryView,
      ),
    );
  }
}
