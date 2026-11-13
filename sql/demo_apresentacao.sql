USE academia;

SELECT CURRENT_USER();
SHOW FULL TABLES;
DESCRIBE matricula;

SHOW INDEX FROM matricula;

EXPLAIN SELECT id_matricula, data_vencimento
          FROM matricula
         WHERE situacao = 'Ativa' AND data_vencimento < CURDATE();

EXPLAIN SELECT id_matricula, data_vencimento
          FROM matricula IGNORE INDEX (idx_matricula_situacao_venc)
         WHERE situacao = 'Ativa' AND data_vencimento < CURDATE();

EXPLAIN SELECT * FROM aluno WHERE nome LIKE 'Ana%';

SELECT * FROM vw_matriculas_detalhadas;
SELECT * FROM vw_resumo_modalidades;
SELECT * FROM vw_inadimplentes;
SELECT * FROM vw_receita_mensal;
SELECT * FROM vw_usuarios_seguro;

SELECT fn_valor_total_plano(1, 3) AS musculacao_semestral;
SELECT fn_situacao_matricula('Ativa', CURDATE() - INTERVAL 1 DAY) AS situacao;
SELECT id_matricula, fn_id_valido(id_matricula) AS dv_ok FROM matricula;
SELECT fn_id_valido('MAT2026000001-3') AS id_correto,
       fn_id_valido('MAT2026000001-5') AS id_digitado_errado;

SELECT * FROM sequencia_id;
START TRANSACTION;
    SELECT fn_gerar_id_usuario(), fn_gerar_id_matricula(), fn_gerar_id_pagamento();
    SELECT * FROM sequencia_id;
ROLLBACK;
SELECT * FROM sequencia_id;

SHOW TRIGGERS;

INSERT INTO matricula (id_aluno, id_plano, id_modalidade, id_professor)
VALUES ('ALU000001', 1, 1, 'PRF000001');

INSERT INTO aluno (nome, cpf) VALUES ('Teste', '123');

DELETE FROM pagamento LIMIT 1;

SELECT * FROM log_auditoria ORDER BY id_log DESC LIMIT 10;

SELECT nome, valor_mensal FROM modalidade;
START TRANSACTION;
    UPDATE modalidade SET valor_mensal = valor_mensal * 10;
    SELECT nome, valor_mensal FROM modalidade;
ROLLBACK;
SELECT nome, valor_mensal FROM modalidade;

START TRANSACTION;
    UPDATE modalidade SET valor_mensal = ROUND(valor_mensal * 1.05, 2) WHERE nome = 'Musculação';
    SAVEPOINT depois_musculacao;
    UPDATE modalidade SET valor_mensal = 1.00 WHERE nome = 'Pilates';
    ROLLBACK TO SAVEPOINT depois_musculacao;
COMMIT;
SELECT nome, valor_mensal FROM modalidade;

SELECT COUNT(*) AS pagamentos_antes FROM pagamento;
SET @cancelada = (SELECT id_matricula FROM matricula WHERE situacao = 'Cancelada' LIMIT 1);
CALL sp_registrar_pagamento(@cancelada, 'Pix', 'USR000002', @pag);

SELECT COUNT(*) AS pagamentos_depois FROM pagamento;

SET @atrasada = (SELECT id_matricula FROM vw_inadimplentes LIMIT 1);
SELECT id_matricula, data_vencimento, situacao_atual FROM vw_matriculas_detalhadas WHERE id_matricula = @atrasada;
CALL sp_registrar_pagamento(@atrasada, 'Pix', 'USR000002', @pag);
SELECT @pag AS pagamento_gerado;
SELECT id_matricula, data_vencimento, situacao_atual FROM vw_matriculas_detalhadas WHERE id_matricula = @atrasada;

USE academia;
SELECT CURRENT_USER(), CURRENT_ROLE();
SHOW GRANTS;
SHOW GRANTS FOR CURRENT_USER() USING 'role_academia_app';

SELECT * FROM vw_usuarios_seguro;
SELECT id_usuario, login, ativo FROM usuarios;
SELECT senha_hash FROM usuarios;
DELETE FROM aluno WHERE id_aluno = 'ALU000004';
INSERT INTO pagamento (id_matricula, valor, forma, meses_pagos)
VALUES ('X', 1, 'Pix', 1);
DROP TABLE log_auditoria;
CALL sp_relatorio_matriculas(NULL, NULL, 'Ativa');

USE academia;
SELECT * FROM vw_resumo_modalidades;
SELECT * FROM aluno;
CALL sp_cancelar_matricula('X', '', 'X');
