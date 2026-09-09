# Cesta Básica Lopez

App mobile Flutter para gestão de vendas porta a porta.
Projeto Integrador III — Faculdade Donaduzzi — Grupo 01

## Stack
Flutter · Firebase (Auth, Firestore, Storage) · Riverpod

## Rodando
1. flutter pub get
2. Solicite os arquivos de configuração do Firebase
3. flutter run

## Estrutura
lib/core      — tema, constantes, widgets compartilhados
lib/features  — módulos, cada um com data/domain/presentation

## Branches
main     — versão estável
develop  — integração; toda feature entra por PR
feature/kan-XX-descricao