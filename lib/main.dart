import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/navigation/app_routes.dart';
import 'core/navigation/auth_gate.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/showcase_screen.dart';
import 'features/cliente/data/cliente_model.dart';
import 'features/cliente/presentation/cadastro_cliente_screen.dart';
import 'features/cliente/presentation/detalhes_cliente_screen.dart';
import 'features/estoque/presentation/estoque_screen.dart';
import 'features/financeiro/presentation/despesas_screen.dart'; // NOVO
import 'features/financeiro/presentation/painel_financeiro_screen.dart';
import 'features/financeiro/presentation/relatorio_semanal_screen.dart';
import 'features/produto/data/produto_model.dart';
import 'features/produto/presentation/cadastro_produto_screen.dart';
import 'features/rota/presentation/rotas_screen.dart';
import 'features/venda/presentation/assinatura_screen.dart';
import 'features/venda/presentation/comprovante_pagamento_screen.dart';
import 'features/venda/presentation/comprovante_providers.dart';
import 'features/venda/presentation/detalhes_venda_screen.dart';
import 'features/venda/presentation/nota_provisoria_screen.dart';
import 'features/venda/presentation/nova_venda_screen.dart';
import 'features/venda/presentation/promissorias_screen.dart';
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
        AppRoutes.novaVenda: (context) => NovaVendaScreen(
          clienteIdInicial:
              ModalRoute.of(context)!.settings.arguments as String?,
        ),
        AppRoutes.detalheVenda: (context) => DetalhesVendaScreen(
          vendaId: ModalRoute.of(context)!.settings.arguments! as String,
        ),
        AppRoutes.comprovante: (context) => ComprovantePagamentoScreen(
          args: ModalRoute.of(context)!.settings.arguments! as ComprovanteArgs,
        ),
        AppRoutes.assinatura: (context) => AssinaturaScreen(
          vendaId: ModalRoute.of(context)!.settings.arguments! as String,
        ),
        AppRoutes.notaProvisoria: (context) => NotaProvisoriaScreen(
          vendaId: ModalRoute.of(context)!.settings.arguments! as String,
        ),
        AppRoutes.promissorias: (context) => PromissoriasScreen(
          clienteId: ModalRoute.of(context)!.settings.arguments as String?,
        ),
        AppRoutes.despesas: (context) => const DespesasScreen(), // NOVO
        AppRoutes.painelFinanceiro: (context) => const PainelFinanceiroScreen(),
        AppRoutes.relatorioSemanal: (context) => const RelatorioSemanalScreen(),
        AppRoutes.cadastroCliente: (context) => const CadastroClienteScreen(),
        AppRoutes.detalheCliente: (context) => DetalhesClienteScreen(
          clienteId: ModalRoute.of(context)!.settings.arguments! as String,
        ),
        AppRoutes.editarCliente: (context) => CadastroClienteScreen(
          cliente: ModalRoute.of(context)!.settings.arguments! as ClienteModel,
        ),
        AppRoutes.estoque: EstoqueScreen.daRota,
        AppRoutes.rotas: (context) => const RotasScreen(),
        AppRoutes.cadastroProduto: (context) => const CadastroProdutoScreen(),
        AppRoutes.editarProduto: (context) => CadastroProdutoScreen(
          produto: ModalRoute.of(context)!.settings.arguments! as ProdutoModel,
        ),
      },
      // AuthGate decide entre LoginScreen e MainShell conforme o
      // estado de autenticação (KAN-11).
      home: const AuthGate(),
    );
  }
}
