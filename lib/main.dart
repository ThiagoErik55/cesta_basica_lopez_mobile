import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/navigation/app_routes.dart';
import 'core/navigation/auth_gate.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/showcase_screen.dart';
import 'features/cliente/presentation/cadastro_cliente_screen.dart';
import 'features/cliente/presentation/detalhe_cliente_screen.dart';
import 'features/venda/presentation/nova_venda_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const ProviderScope(child: CestaBasicaApp()));
}

class CestaBasicaApp extends StatelessWidget {
  const CestaBasicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cesta Básica Lopez',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routes: {
        // Vitrine dos componentes do design system (KAN-12), fora da
        // navegação principal — abra com Navigator.pushNamed(context,
        // AppRoutes.showcase).
        AppRoutes.showcase: (context) => const ShowcaseScreen(),
        AppRoutes.novaVenda: (context) => const NovaVendaScreen(),
        AppRoutes.cadastroCliente: (context) => const CadastroClienteScreen(),
        AppRoutes.detalheCliente: (context) => DetalheClienteScreen(
          clienteId: ModalRoute.of(context)!.settings.arguments! as String,
        ),
      },
      // AuthGate decide entre LoginScreen e MainShell conforme o
      // estado de autenticação (KAN-11).
      home: const AuthGate(),
    );
  }
}
