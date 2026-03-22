import "package:flutter/material.dart";

class ArkPulseApp extends StatelessWidget {
  const ArkPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "ArkPulse",
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData.dark(useMaterial3: true),
      home: const Scaffold(body: Center(child: Text("ArkPulse"))),
    );
  }
}
