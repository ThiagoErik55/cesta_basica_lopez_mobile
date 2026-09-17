import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// Cabeçalho de seção: título à esquerda, ação opcional à direita (ex.
/// um botão textual). Genérico de propósito — o protótipo usava "VER
/// MAPA" nesse lugar, mas o app não implementa mapa (seção 7.4 do
/// modelo lógico), então nenhum texto de ação é fixado aqui.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.titulo, this.acao, super.key});

  final String titulo;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(titulo, style: AppTextStyles.sectionTitle),
        ?acao,
      ],
    );
  }
}
