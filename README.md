# Sistema de Gestão de Academia — Banco de Dados (MySQL)

Aplicação web para gestão de alunos, matrículas e pagamentos de uma academia.
É a evolução do projeto de Programação Orientada a Objetos (Java Swing) para uma
arquitetura **frontend web + API Java + MySQL**, com os recursos de SGBD pedidos
na disciplina de Banco de Dados.

## Estrutura

```
academia-web/
├── sql/
│   ├── academia.sql            # script completo do banco (tabelas, índices, functions,
│   │                           #   triggers, views, procedures, dados, usuários e GRANTs)
│   └── demo_apresentacao.sql   # comandos para demonstrar cada item na apresentação
│                               #   (até o pagamento: academia_dba; depois: academia_app e academia_relatorio)
├── backend/                    # API em Java 17+ (HttpServer do JDK + JDBC)
│   ├── src/academia/...
│   ├── lib/mysql-connector-j-26.10.0.jar
│   ├── db.properties           # credenciais do usuário academia_app (nunca root)
│   ├── executar.bat            # Windows
│   └── executar.sh             # Linux / macOS
├── frontend/                   # HTML + CSS + JavaScript puro
└── docs/
    ├── der.png / der.svg       # Diagrama Entidade-Relacionamento
    └── roteiro_apresentacao.md # roteiro de 5 minutos
```

## Como executar

**Pré-requisitos:** MySQL 8.0.19 ou superior e JDK 17 ou superior.

1. **Criar o banco** (é o único passo feito pelo administrador do servidor):
   ```
   mysql -u root -p < sql/academia.sql
   ```
   O script cria o banco `academia`, todos os objetos, os dados de exemplo e os
   usuários `academia_dba`, `academia_app` e `academia_relatorio`.

2. **Iniciar a aplicação**: dê dois cliques em `backend/executar.bat` (Windows) ou
   rode `./backend/executar.sh`. A aplicação conecta como **academia_app** — se
   alguém configurar `root` no `db.properties`, ela se recusa a iniciar.

3. Abra **http://localhost:8080**.

| Login | Senha | Grupo |
|---|---|---|
| `admin` | `admin123` | Administradores |
| `recepcao` | `recep123` | Recepção |
| `11122233344` | `aluno123` | Alunos (login = CPF) |

> Se o MySQL estiver em Docker ou em outra máquina, troque `'localhost'` por `'%'`
> nos `CREATE USER` do script e ajuste o `db.url` no `db.properties`.

## Usuários do banco

| Usuário MySQL | Uso | Permissões |
|---|---|---|
| `academia_dba` | manutenção; dono dos objetos | ALL apenas no banco `academia` |
| `academia_app` | API da aplicação | SELECT em tabelas de consulta e views; INSERT/UPDATE em `aluno`; INSERT em `usuarios` e UPDATE só da coluna `ativo`; EXECUTE nas procedures. **Sem DELETE, sem DDL, sem acesso a `senha_hash`.** |
| `academia_relatorio` | relatórios / BI | SELECT apenas nas views |

## Recursos de banco implementados

- **Tabelas (10):** `grupos_usuarios`, `usuarios`, `aluno`, `professor`, `modalidade`, `plano`, `matricula`, `pagamento`, `log_auditoria`, `sequencia_id`
- **IDs próprios:** `fn_gerar_id_usuario`, `fn_gerar_id_aluno`, `fn_gerar_id_professor`, `fn_gerar_id_matricula` e `fn_gerar_id_pagamento` (estes dois com dígito verificador módulo 11). AUTO_INCREMENT só em `modalidade`, `plano` e `log_auditoria`, com justificativa no artigo.
- **Índices (7):** `idx_matricula_aluno_modalidade`, `idx_matricula_situacao_venc`, `idx_matricula_data_inicio`, `idx_pagamento_data`, `idx_aluno_nome`, `idx_log_tabela_data`, `idx_usuarios_grupo_ativo`
- **Triggers (10):** geração de IDs, validação de CPF, bloqueio de matrícula duplicada, cálculo de vencimento e preço, bloqueio de pagamento em matrícula cancelada, proibição de apagar pagamento e auditoria.
- **Views (5):** `vw_matriculas_detalhadas`, `vw_resumo_modalidades`, `vw_inadimplentes`, `vw_receita_mensal`, `vw_usuarios_seguro`
- **Procedures (5):** `sp_autenticar`, `sp_contratar_matricula`, `sp_registrar_pagamento`, `sp_cancelar_matricula`, `sp_relatorio_matriculas`
- **Functions (10):** as 5 de ID + `fn_proximo_numero`, `fn_digito_verificador`, `fn_id_valido`, `fn_situacao_matricula`, `fn_valor_total_plano`
- **Transações (TCL):** `START TRANSACTION / COMMIT / ROLLBACK` nas procedures (com `EXIT HANDLER`) e `setAutoCommit(false) / commit() / rollback()` no cadastro de aluno em Java.
