import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/nearby_service.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const OfflineChatApp());
}

class OfflineChatApp extends StatelessWidget {
  const OfflineChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NearbyService(),
      child: MaterialApp(
        title: 'Offline Chat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF2E7D5B),
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF2E7D5B),
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
