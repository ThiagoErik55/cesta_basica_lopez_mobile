import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: CestaBasicaApp()));
}

class CestaBasicaApp extends StatelessWidget {
  const CestaBasicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cesta Básica Lopez',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: Center(child: Text('Cesta Básica Lopez')),
      ),
    );
  }
}