# Roteiro da apresentação (5 minutos)

**Antes de começar:** banco criado, aplicação rodando em http://localhost:8080,
MySQL Workbench aberto com duas conexões salvas (`academia_dba` e `academia_app`)
e o arquivo `sql/demo_apresentacao.sql` aberto. Nesse arquivo, rode tudo até o segundo `CALL sp_registrar_pagamento` como `academia_dba`; do `SELECT CURRENT_USER(), CURRENT_ROLE()` até `CALL sp_relatorio_matriculas` como `academia_app`; e as três últimas linhas como `academia_relatorio`. Ensaiar com cronômetro.

| Tempo | Tópico | O que mostrar | O que falar |
|---|---|---|---|
| 0:00–0:30 | **Abertura** | Tela de login | Sistema de academia: alunos, matrículas e pagamentos. Frontend HTML/JS, API em Java e MySQL. |
| 0:30–1:30 | **Aplicação funcionando** | Entrar como `recepcao`. Painel (3 views). Matrículas: contratar uma nova e mostrar o valor calculado. Registrar um pagamento de uma atrasada. Alunos: lista da tabela `aluno`. | Cada tela mostra de onde vem o dado: view, tabela ou procedure. |
| 1:30–2:00 | **Acesso sem root** | Rodapé da aplicação (`academia_app@localhost`, roles). Console Java: "Conectado como academia_app". `db.properties`. | A aplicação recusa iniciar com root. As credenciais ficam fora do código. |
| 2:00–2:40 | **Modelagem** | `docs/der.png` | 10 tabelas. `usuarios` e `grupos_usuarios` controlam o login e o nível de acesso. `matricula` é a tabela central (N:1 com aluno, plano, modalidade e professor) e tem N pagamentos. Preço "congelado" na matrícula. IDs próprios com dígito verificador para os dados críticos; AUTO_INCREMENT só em catálogos e log. |
| 2:40–3:10 | **Índices** | Os dois `EXPLAIN` da consulta de inadimplentes (com e sem `IGNORE INDEX`) | Com índice: `type=range` e poucas linhas lidas; sem índice: `type=ALL` (varre tudo). Os índices seguem os filtros reais das telas. |
| 3:10–3:30 | **Views** | `SELECT * FROM` cada view | `vw_matriculas_detalhadas` tira o JOIN de 5 tabelas do Java; `vw_usuarios_seguro` esconde a senha. |
| 3:30–4:05 | **Triggers, procedures e functions** | `INSERT` da matrícula duplicada (erro) e `DELETE FROM pagamento` (erro). Tela **Auditoria** (como `admin`). `SELECT fn_valor_total_plano(1, 3)`. | Regras ficam no banco: valem para qualquer sistema que acesse os dados. A auditoria registra o usuário MySQL e o usuário da aplicação. |
| 4:05–4:35 | **Transações (TCL)** | ROLLBACK do reajuste de preço errado e o pagamento de matrícula cancelada (contagem de pagamentos igual antes e depois). | Matrícula + pagamento e pagamento + renovação são operações que precisam acontecer juntas ou nada; o EXIT HANDLER faz ROLLBACK automático. No Java, o cadastro de aluno usa commit/rollback. |
| 4:35–5:00 | **Controle de acesso** | Conectado como `academia_app`: `SHOW GRANTS`, `SELECT senha_hash` (erro 1143), `DELETE` (erro 1142). | Menor privilégio: 3 usuários e 2 roles. A aplicação não apaga nada, não altera estrutura e não lê senhas. |

## Perguntas prováveis

- **Por que não AUTO_INCREMENT em tudo?** IDs sequenciais simples expõem quantos registros existem e não detectam erro de digitação. Para matrícula e pagamento usamos ano/data + sequência + dígito verificador. A sequência fica numa tabela travada com `FOR UPDATE`, então não repete e, se houver ROLLBACK, o número volta.
- **E se duas recepcionistas renovarem a mesma matrícula ao mesmo tempo?** `sp_registrar_pagamento` faz `SELECT ... FOR UPDATE`: a segunda espera a primeira terminar.
- **Por que a lógica está no banco e não só no Java?** Porque vale para qualquer cliente (Workbench, outro sistema, relatório), e o usuário da aplicação nem tem permissão para gravar em `matricula`/`pagamento` diretamente.
- **Os objetos rodam como root?** Não. O DEFINER de todos é `academia_dba`, que só tem acesso ao banco `academia`.
