import 'package:daily_wallpaper_app/services/config_service.dart';
import 'package:daily_wallpaper_app/views/open_log_file_dialog.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../util/util.dart';

class AboutView extends StatefulWidget {
  const AboutView({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _AboutView();
}

class _AboutView extends State<AboutView> {
  final TextStyle highlightStyle =
      const TextStyle(color: Colors.deepPurpleAccent);
  int versionTabs = 0;
  late String versionText;

  @override
  void initState() {
    super.initState();

    versionTabs = 0;
    versionText = ConfigService.packageInfo.version;
  }

  Widget _buildItem(
      {required Widget title, Widget? subtitle, VoidCallback? onTap}) {
    return ListTile(
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  void _handleVersionTab() {
    versionTabs++;

    if (versionTabs >= 3) {
      Navigator.of(context).pop();
      showDialog(
          context: context, builder: (context) => const OpenLogFileDialog());
      setState(() {
        versionTabs = 0;
        versionText = ConfigService.packageInfo.version;
      });
    } else if (versionTabs >= 2) {
      setState(() {
        versionText = "Tab again to open the log file";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        "About",
        textAlign: TextAlign.center,
      ),
      content: Wrap(
        children: [
          _buildItem(
            title: const Text("A wallpaper app."),
            subtitle: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.grey[400]),
                children: [
                  const TextSpan(text: "Made by "),
                  TextSpan(
                    text: "Matthias Harzer",
                    style: highlightStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        Util.openUrl("https://matthiasharzer.de/");
                      },
                  ),
                  const TextSpan(text: " with "),
                  TextSpan(
                    text: "Flutter",
                    style: highlightStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        Util.openUrl("https://flutter.dev/");
                      },
                  ),
                ],
              ),
            ),
          ),
          _buildItem(
            title: const Text("Version"),
            subtitle: Text(versionText),
            onTap: _handleVersionTab,
          ),
          _buildItem(
            title: const Text("GitHub"),
            subtitle:
                const Text("github.com/MatthiasHarzer/DailyWallpaperApp"),
            onTap: () => Util.openUrl(
                "https://github.com/MatthiasHarzer/DailyWallpaperApp"),
          ),
        ],
      ),
    );
  }
}
