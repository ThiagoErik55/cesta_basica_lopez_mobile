```markdown
# Cesta Básica Lopez

App mobile Flutter para gestão de vendas porta a porta.
Projeto Integrador III — Faculdade Donaduzzi — Grupo 01

## Stack
Flutter · Firebase (Auth, Firestore, Storage) · Riverpod

## Como rodar

### 1. Clonar
```bash
git clone https://github.com/ThiagoErik55/cesta_basica_lopez_mobile.git
cd cesta_basica_lopez_mobile
```

### 2. Ir para a branch de desenvolvimento
```bash
git checkout develop
```
Nunca trabalhe direto na `main`.

### 3. Instalar dependências
```bash
flutter pub get
```

### 4. Arquivos do Firebase
Não estão no repositório (contêm chaves do projeto).
Peça no grupo e coloque em:

```
lib/firebase_options.dart
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

### 5. Rodar
Com emulador aberto ou celular conectado:
```bash
flutter devices    # confirma que o dispositivo aparece
flutter run
```

## Índices do Firestore

Consultas que combinam filtro e ordenação (ex. a lista de clientes) só
funcionam com índices compostos. Eles ficam versionados em
`firestore.indexes.json` — não crie índice só pelo console sem trazê-lo
para o arquivo.

Publicar os índices no projeto (precisa do Firebase CLI logado):
```bash
firebase deploy --only firestore:indexes
```

Criou um índice pelo link do erro no console? Traga-o para o arquivo:
```bash
firebase firestore:indexes > firestore.indexes.json
```

## Problemas comuns

**"No supported devices connected"**
Nenhum emulador aberto ou celular sem depuração USB ativada.

**Erro de dependência após dar pull**
```bash
flutter clean
flutter pub get
```

**"The query requires an index" no console / "Erro ao carregar clientes"**
Falta um índice no projeto Firebase. Rode o deploy dos índices (seção
Índices do Firestore) ou crie pelo link da mensagem e atualize o
`firestore.indexes.json`.

**Build travado sem motivo aparente**
```bash
flutter clean
flutter pub get
flutter run
```

## Estrutura
```
lib/core      — tema, constantes, widgets compartilhados
lib/features  — módulos, cada um com data/domain/presentation
```
Cada feature tem `data/` (models e repositórios), `domain/` (entidades e interfaces) e `presentation/` (telas e providers).

## Fluxo de trabalho

Branch a partir da `develop`, nomeada pelo card do Jira:
```bash
git checkout develop
git pull
git checkout -b feature/kan-9-modelagem-firestore
```

Ao terminar:
```bash
flutter analyze    # precisa passar sem erros
git push -u origin feature/kan-9-modelagem-firestore
```
Abrir Pull Request para `develop` e pedir revisão de um colega.

## Branches
```
main     — versão estável
develop  — integração
feature/kan-XX-descricao
```
```