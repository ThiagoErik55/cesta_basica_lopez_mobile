# ADR 001 — Arquitetura do aplicativo

Data: 10/09/2026
Status: Aceito

## Contexto
App de força de vendas usado em campo, em visitas porta a porta,
com áreas sem sinal de internet (RNF06). Dois vendedores operam
simultaneamente sobre o mesmo estoque.

## Decisões

### Backend: Firebase (Auth + Firestore)
Firestore oferece cache local e fila de escrita nativos, eliminando
a necessidade de implementar sincronização manual. Plano Spark
(gratuito) atende o volume previsto.

### Sem Firebase Storage
O Cloud Storage passou a exigir plano Blaze (pago). Assinaturas
serão gravadas em base64 no documento da venda; PDFs de nota e
comprovante serão gerados no dispositivo e compartilhados via
WhatsApp, sem armazenamento em nuvem.

### Estado: Riverpod 3.x
Menor curva de aprendizado que Bloc para o prazo do projeto,
testável e com boa integração com streams do Firestore.

### Camadas por feature
Cada módulo em lib/features/<nome> com:
- domain/      entidades e interfaces de repositório
- data/        models (toMap/fromMap) e repositório Firestore
- presentation/ telas, widgets e providers

A UI nunca acessa o Firestore diretamente. Sempre via repositório.

### IDs gerados no cliente
Todo documento recebe UUID v4 gerado no dispositivo, nunca ID
automático do Firestore. Permite criar registros offline sem
colisão entre os dois vendedores.

### Estoque derivado de movimentos
O Firestore resolve conflito por last-write-wins. Um campo
estoqueAtual sobrescrito perderia escritas quando dois vendedores
vendessem o mesmo produto offline. Por isso, cada entrada, saída
ou troca é um documento em movimentosEstoque, e o saldo é
calculado a partir deles. O campo estoqueAtual no produto é
apenas cache para exibição rápida.

### Campos obrigatórios em todo documento
- id: UUID v4
- updatedAt: timestamp da última alteração
- deleted: soft delete (hard delete quebra a sincronização)

### Autenticação por e-mail e senha
O protótipo previa login apenas com nome. As Security Rules do
Firebase exigem usuário autenticado, então adotou-se e-mail e
senha com sessão persistida — o vendedor digita uma única vez.

## Consequências
- Não há código de sincronização a manter.
- Consultas do Firestore são limitadas: sem join, sem agregação
  complexa. Relatórios da Sprint 7 serão calculados no app.
- Desnormalização é necessária (ex.: clienteNome duplicado na venda).