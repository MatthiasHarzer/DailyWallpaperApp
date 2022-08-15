import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:bing_wallpaper_setter/services/wallpaper_service.dart';
import 'package:bing_wallpaper_setter/util/util.dart';
import 'package:bing_wallpaper_setter/views/about_view.dart';
import 'package:bing_wallpaper_setter/views/settings_view.dart';
import 'package:bing_wallpaper_setter/views/wallpaper_info_view.dart';
import 'package:bing_wallpaper_setter/views/wallpaper_view.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:optimize_battery/optimize_battery.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';

import 'consts.dart' as consts;
import 'drawer.dart';

Future<void> updateWallpaper() async{
  var logger = getLogger();

  WallpaperInfo? todaysWallpaper = await WallpaperService.getTodaysWallpaperOffline();
  var connectivity = await Connectivity().checkConnectivity();

  if(![ConnectivityResult.mobile, ConnectivityResult.wifi, ConnectivityResult.ethernet].contains(connectivity)){
    if(todaysWallpaper != null){
      await WallpaperService.setWallpaper(todaysWallpaper, ConfigService.wallpaperScreen);
      logger.d("Set wallpaper from download cache");
    }else{
      logger.d("No internet connection. Skipping...");
    }
    return;
  }

  WallpaperInfo wallpaper = await WallpaperService.getWallpaper(local: ConfigService.region);

  await WallpaperService.ensureDownloaded(wallpaper);

  await WallpaperService.setWallpaper(wallpaper, ConfigService.wallpaperScreen);

  logger.d("Wallpaper updated!");
}

/// The callback dispatcher for the workmanager background isolate
void workManagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    var logger = getLogger();
    logger.d("Running background task");
    try {
      await ConfigService.ensureInitialized();

      switch (task) {
        case consts.BG_WALLPAPER_TASK_ID:
          if(!ConfigService.dailyModeEnabled) break;

          await updateWallpaper();

          ConfigService.bgWallpaperTaskLastRun =
              DateTime.now().millisecondsSinceEpoch;


      }
    } catch (error) {
      logger.e(error.toString());
    }

    return true;
  });
}

Future<void> widgetBackgroundCallback(Uri? uri)async{
  await ConfigService.ensureInitialized();

  var logger = getLogger();
  logger.d("Running background intent from widget");
  if(uri?.host == "updatewallpaper"){
    var now = Util.normalizeDate(DateTime.now());
    String nowString = Util.formatDay(now);
    String currentWallpaperDayString = ConfigService.currentWallpaperDay;
    String newestWallpaperDayString = ConfigService.newestWallpaperDay;
    var currentWallpaperDay = DateTime.tryParse(currentWallpaperDayString) ?? DateTime(1800);
    var newestWallpaperDay = DateTime.tryParse(newestWallpaperDayString) ?? DateTime(1800);


    if(now.millisecondsSinceEpoch > newestWallpaperDay.millisecondsSinceEpoch){
      // The newest wallpaper was never applied yet -> update
      logger.d("Updating to newest wallpaper");
      await updateWallpaper();
    }else{
      var theDayBeforeCurrent = currentWallpaperDay.subtract(const Duration(days: 1));
      await WallpaperService.setWallpaperOfDay(theDayBeforeCurrent);

      logger.d("Set wallpaper for day $theDayBeforeCurrent");
    }

  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ConfigService.ensureInitialized();
  await WallpaperService.ensureMaxCacheWallpapers();

  await Workmanager()
      .initialize(workManagerCallbackDispatcher, isInDebugMode: true);
  await WallpaperService.checkAndSetBackgroundTaskState();

  HomeWidget.registerBackgroundCallback(widgetBackgroundCallback);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bing Daily Wallpaper',
      theme: ThemeData(
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.selected)
                  ? Colors.deepPurpleAccent
                  : null),
          trackColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.selected)
                  ? Colors.deepPurple[500]
                  : null),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey.shade900,
          contentTextStyle: const TextStyle(color: Colors.white),
          actionTextColor: Colors.deepPurpleAccent,
        ),
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
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
    bool ignoreBatteryOptimizationGranted =
        await _requestIgnoreBatteryOptimization();

    if (!mounted) return;

    if (!storagePermissionGranted) {
      Util.showSnackBar(
        context,
        seconds: 30,
        content: const Text(
            "Storage permission denied. The app might not work correctly."),
        action: SnackBarAction(
          label: "OPEN APP SETTINGS",
          onPressed: () => openAppSettings(),
        ),
      );
    }

    if (!ignoreBatteryOptimizationGranted) {
      Util.showSnackBar(
        context,
        seconds: 30,
        content: const Text(
            "Battery optimization might negatively influence the behavior of the app."),
        action: SnackBarAction(
          label: "OPEN SETTINGS",
          onPressed: () => OptimizeBattery.openBatteryOptimizationSettings(),
        ),
      );
    }
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

  Future<bool> _requestIgnoreBatteryOptimization() async {
    final PermissionStatus status =
        await Permission.ignoreBatteryOptimizations.status;

    if (status != PermissionStatus.granted) {
      if (await Permission.ignoreBatteryOptimizations.request() !=
          PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  /// Checks for wallpaper updates and sets the wallpaper variable. Returns true if updated or false if now update is present
  Future<bool> _updateWallpaper() async {
    WallpaperInfo newWallpaper = await WallpaperService.getWallpaper(local: ConfigService.region);
    await WallpaperService.ensureDownloaded(newWallpaper);

    bool update = newWallpaper.mobileUrl != wallpaper?.mobileUrl;

    setState((){
      wallpaper = newWallpaper;
    });

    if(update){
      logger.d("Updated wallpaper: $wallpaper");
    }

    return update;
  }

  /// Opens the info view of the current wallpaper
  void _openWallpaperInformationDialog() {
    Navigator.pop(context);
    if (wallpaper == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          "Wallpaper not loaded yet! Please wait...",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey.shade900,
        duration: const Duration(seconds: 3),
      ));
    }

    showDialog(
      context: context,
      builder: (context) => WallpaperInfoView(wallpaper: wallpaper!),
    );
  }

  Route _createSettingsViewRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const SettingsView(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Opens the settings window
  void _openSettingsView() {
    Navigator.pop(context);
    Navigator.push(
      context,
      _createSettingsViewRoute(),
    );
  }

  void _openAboutView() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => const AboutView(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WallpaperView(
      wallpaper: wallpaper,
      onUpdateWallpaper: _updateWallpaper,
      drawer: MainPageDrawer(
        header: wallpaper?.copyright ?? "A Bing Image",
        onInformationTap: _openWallpaperInformationDialog,
        onSettingsTap: _openSettingsView,
        onAboutTap: _openAboutView,
      ),
    );
  }
}
