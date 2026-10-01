import 'package:flutter/material.dart';

import '../../features/cliente/data/cliente_model.dart';
import '../../features/produto/data/produto_model.dart';
import '../domain/enums.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'client_card.dart';
import 'connection_badge.dart';
import 'empty_state.dart';
import 'filter_chip_bar.dart';
import 'primary_button.dart';
import 'product_card.dart';
import 'score_badge.dart';
import 'section_header.dart';
import 'status_badge.dart';

/// Vitrine de todos os componentes do design system, com dados de
/// exemplo (KAN-12).
///
/// Não faz parte da navegação principal do app. Para abrir, use a rota
/// nomeada `/showcase` registrada em main.dart
/// (`Navigator.pushNamed(context, '/showcase')`) — útil na validação
/// visual dos componentes e na Pré-Banca.
///
/// Dados de exemplo usam nomes de pessoa física e CPF (o protótipo da
/// Sprint 1 usava CNPJ e nomes de estabelecimento — corrigido conforme
/// modelo lógico v1.2, CLIENTE.cpf).
class ShowcaseScreen extends StatelessWidget {
  const ShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();

    final clientes = [
      ClienteModel(
        id: '1',
        codigo: 'C001',
        nome: 'Maria Aparecida Souza',
        cpf: '123.456.789-00',
        telefone: '(45) 99999-0001',
        endereco: 'Rua das Palmeiras, 120 — Toledo/PR',
        score: ScoreCliente.a,
        updatedAt: agora,
      ),
      ClienteModel(
        id: '2',
        codigo: 'C002',
        nome: 'João Batista Ferreira',
        cpf: '987.654.321-00',
        telefone: '(45) 99999-0002',
        endereco: 'Av. Parigot de Souza, 850 — Toledo/PR',
        score: ScoreCliente.c,
        valorEmAberto: 180,
        proximoVencimento: agora.subtract(const Duration(days: 3)),
        updatedAt: agora,
      ),
      ClienteModel(
        id: '3',
        codigo: 'C003',
        nome: 'Antônio Carlos Lima',
        cpf: '111.222.333-44',
        telefone: '(45) 99999-0003',
        endereco: 'Rua Rio de Janeiro, 45 — Toledo/PR',
        score: ScoreCliente.b,
        valorEmAberto: 90,
        proximoVencimento: agora.add(const Duration(days: 5)),
        updatedAt: agora,
      ),
    ];

    final produtos = [
      ProdutoModel(
        id: '1',
        codigo: 'P001',
        nome: 'Arroz Branco 5kg',
        marca: 'Tio João',
        categoria: 'Grãos',
        preco: 24.9,
        custoAtual: 18.5,
        estoqueAtual: 40,
        updatedAt: agora,
      ),
      ProdutoModel(
        id: '2',
        codigo: 'P002',
        nome: 'Óleo de Soja 900ml',
        marca: 'Liza',
        categoria: 'Óleos',
        preco: 8.5,
        custoAtual: 6.2,
        estoqueAtual: 3,
        estoqueMinimo: 10,
        updatedAt: agora,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Design System')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SectionHeader(titulo: 'Conectividade'),
          const SizedBox(height: AppSpacing.sm),
          const ConnectionBadge(),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(
            titulo: 'Clientes a Visitar',
            acao: TextButton(onPressed: () {}, child: const Text('VER TODOS')),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final cliente in clientes) ...[
            ClientCard(cliente: cliente),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),

          const SectionHeader(titulo: 'Scores'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: ScoreCliente.values.map(ScoreBadge.new).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),

          const SectionHeader(titulo: 'Status financeiro'),
          const SizedBox(height: AppSpacing.sm),
          const Wrap(
            spacing: AppSpacing.sm,
            children: [
              StatusBadge.emDia(),
              StatusBadge.atencao(),
              StatusBadge.inadimplente(),
              StatusBadge.vencido(),
              StatusBadge.emAtraso(),
              StatusBadge.bloqueado(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          const SectionHeader(titulo: 'Filtro'),
          const SizedBox(height: AppSpacing.sm),
          FilterChipBar<String>(
            opcoes: const [
              OpcaoFiltro('Todos', null),
              OpcaoFiltro('Em dia', 'emDia'),
              OpcaoFiltro('Em atraso', 'emAtraso'),
            ],
            selecionado: 'emDia',
            onSelecionar: (_) {},
          ),
          const SizedBox(height: AppSpacing.lg),

          const SectionHeader(titulo: 'Produtos'),
          const SizedBox(height: AppSpacing.sm),
          for (final produto in produtos) ...[
            ProductCard(produto: produto),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),

          const SectionHeader(titulo: 'Financeiro do dia'),
          const SizedBox(height: AppSpacing.sm),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saldo do dia', style: AppTextStyles.cardSubtitle),
                  SizedBox(height: AppSpacing.xs),
                  Text('R\$ 14.520,00', style: AppTextStyles.moneyLarge),
                  SizedBox(height: AppSpacing.xs),
                  Text('Nota provisória 45892', style: AppTextStyles.caption),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          const SectionHeader(titulo: 'Botões'),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(texto: 'Iniciar Visita', onPressed: () {}),
          const SizedBox(height: AppSpacing.sm),
          const PrimaryButton(
            texto: 'Carregando',
            onPressed: null,
            carregando: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(texto: 'Cancelar', onPressed: () {}),
          const SizedBox(height: AppSpacing.lg),

          const SectionHeader(titulo: 'Estado vazio'),
          const SizedBox(height: AppSpacing.sm),
          const EmptyState(
            icone: Icons.people_outline,
            titulo: 'Nenhum cliente cadastrado',
            descricao: 'Cadastre o primeiro cliente para começar a rota.',
          ),
        ],
      ),
    );
  }
}
