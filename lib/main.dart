import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'services/audio_handler.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

MyAudioHandler audioHandler = MyAudioHandler();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    audioHandler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.zentask.zenfocus.channel.audio',
        androidNotificationChannelName: 'ZenFocus Calm Music',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
      ),
    );
  } catch (e) {
    debugPrint('AudioService init failed, falling back to standalone player: $e');
  }

  runApp(const ZenTaskApp());
}

class ZenTaskApp extends StatelessWidget {
  const ZenTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZenTask',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
