SET NAMES utf8mb4;

SET GLOBAL log_bin_trust_function_creators = 1;

DROP DATABASE IF EXISTS academia;
CREATE DATABASE academia CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

DROP USER IF EXISTS 'academia_app'@'localhost';
DROP USER IF EXISTS 'academia_relatorio'@'localhost';
DROP USER IF EXISTS 'academia_dba'@'localhost';
DROP ROLE IF EXISTS 'role_academia_app', 'role_academia_leitura';

CREATE USER 'academia_dba'@'localhost'
    IDENTIFIED BY 'Dba@Academia2026'
    FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1;
GRANT ALL PRIVILEGES ON academia.* TO 'academia_dba'@'localhost';

USE academia;

CREATE TABLE sequencia_id (
    entidade      VARCHAR(30)  NOT NULL PRIMARY KEY,
    prefixo       VARCHAR(5)   NOT NULL,
    ultimo_valor  INT UNSIGNED NOT NULL DEFAULT 0
) ENGINE = InnoDB;

CREATE TABLE grupos_usuarios (
    id_grupo      CHAR(3)      NOT NULL PRIMARY KEY,
    nome          VARCHAR(40)  NOT NULL UNIQUE,
    descricao     VARCHAR(200),
    nivel_acesso  TINYINT      NOT NULL,
    CONSTRAINT ck_grupo_nivel CHECK (nivel_acesso BETWEEN 1 AND 3)
) ENGINE = InnoDB;

CREATE TABLE usuarios (
    id_usuario     VARCHAR(12)  NOT NULL DEFAULT '' PRIMARY KEY,
    nome           VARCHAR(100) NOT NULL,
    login          VARCHAR(30)  NOT NULL UNIQUE,
    email          VARCHAR(100) UNIQUE,
    senha_hash     CHAR(64)     NOT NULL,
    id_grupo       CHAR(3)      NOT NULL,
    ativo          TINYINT(1)   NOT NULL DEFAULT 1,
    criado_em      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultimo_acesso  DATETIME     NULL,
    CONSTRAINT fk_usuarios_grupo FOREIGN KEY (id_grupo)
        REFERENCES grupos_usuarios (id_grupo)
) ENGINE = InnoDB;

CREATE TABLE professor (
    id_professor  VARCHAR(12)  NOT NULL DEFAULT '' PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL,
    telefone      VARCHAR(20),
    cref          VARCHAR(20)  NOT NULL UNIQUE,
    ativo         TINYINT(1)   NOT NULL DEFAULT 1
) ENGINE = InnoDB;

CREATE TABLE aluno (
    id_aluno         VARCHAR(12)  NOT NULL DEFAULT '' PRIMARY KEY,
    id_usuario       VARCHAR(12)  NULL UNIQUE,
    nome             VARCHAR(100) NOT NULL,
    cpf              VARCHAR(14)  NOT NULL UNIQUE,
    telefone         VARCHAR(20),
    email            VARCHAR(100),
    data_nascimento  DATE,
    criado_em        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_aluno_cpf CHECK (cpf REGEXP '^[0-9]{11}$'),
    CONSTRAINT fk_aluno_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios (id_usuario) ON DELETE SET NULL
) ENGINE = InnoDB;

CREATE TABLE modalidade (
    id_modalidade  INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nome           VARCHAR(60)  NOT NULL UNIQUE,
    descricao      VARCHAR(200),
    valor_mensal   DECIMAL(8,2) NOT NULL,
    ativa          TINYINT(1)   NOT NULL DEFAULT 1,
    CONSTRAINT ck_modalidade_valor CHECK (valor_mensal > 0)
) ENGINE = InnoDB;

CREATE TABLE plano (
    id_plano             INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nome                 VARCHAR(60)  NOT NULL UNIQUE,
    duracao_meses        TINYINT      NOT NULL,
    desconto_percentual  DECIMAL(5,2) NOT NULL DEFAULT 0,
    CONSTRAINT ck_plano_duracao  CHECK (duracao_meses > 0),
    CONSTRAINT ck_plano_desconto CHECK (desconto_percentual BETWEEN 0 AND 50)
) ENGINE = InnoDB;

CREATE TABLE matricula (
    id_matricula     VARCHAR(16)  NOT NULL DEFAULT '' PRIMARY KEY,
    id_aluno         VARCHAR(12)  NOT NULL,
    id_plano         INT          NOT NULL,
    id_modalidade    INT          NOT NULL,
    id_professor     VARCHAR(12)  NOT NULL,
    data_inicio      DATE         NOT NULL DEFAULT (CURRENT_DATE),
    data_vencimento  DATE         NULL,
    valor_mensal     DECIMAL(8,2) NOT NULL DEFAULT 0,
    situacao         ENUM('Ativa','Suspensa','Cancelada') NOT NULL DEFAULT 'Ativa',
    criado_por       VARCHAR(12)  NULL,
    criado_em        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_matricula_aluno_modalidade (id_aluno, id_modalidade, situacao),
    CONSTRAINT fk_matricula_aluno      FOREIGN KEY (id_aluno)      REFERENCES aluno (id_aluno),
    CONSTRAINT fk_matricula_plano      FOREIGN KEY (id_plano)      REFERENCES plano (id_plano),
    CONSTRAINT fk_matricula_modalidade FOREIGN KEY (id_modalidade) REFERENCES modalidade (id_modalidade),
    CONSTRAINT fk_matricula_professor  FOREIGN KEY (id_professor)  REFERENCES professor (id_professor),
    CONSTRAINT fk_matricula_usuario    FOREIGN KEY (criado_por)    REFERENCES usuarios (id_usuario),
    CONSTRAINT ck_matricula_venc  CHECK (data_vencimento IS NOT NULL),
    CONSTRAINT ck_matricula_datas CHECK (data_vencimento >= data_inicio)
) ENGINE = InnoDB;

CREATE TABLE pagamento (
    id_pagamento    VARCHAR(20)   NOT NULL DEFAULT '' PRIMARY KEY,
    id_matricula    VARCHAR(16)   NOT NULL,
    valor           DECIMAL(10,2) NOT NULL,
    forma           ENUM('Dinheiro','Pix','Cartão de crédito','Cartão de débito') NOT NULL,
    meses_pagos     TINYINT       NOT NULL,
    data_pagamento  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    registrado_por  VARCHAR(12)   NULL,
    CONSTRAINT fk_pagamento_matricula FOREIGN KEY (id_matricula) REFERENCES matricula (id_matricula),
    CONSTRAINT fk_pagamento_usuario   FOREIGN KEY (registrado_por) REFERENCES usuarios (id_usuario),
    CONSTRAINT ck_pagamento_valor CHECK (valor > 0)
) ENGINE = InnoDB;

CREATE TABLE log_auditoria (
    id_log         BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    tabela         VARCHAR(30)  NOT NULL,
    operacao       ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    id_registro    VARCHAR(20)  NOT NULL,
    detalhes       VARCHAR(500),
    usuario_banco  VARCHAR(100) NOT NULL,
    usuario_app    VARCHAR(12)  NULL,
    data_hora      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

CREATE INDEX idx_matricula_situacao_venc ON matricula (situacao, data_vencimento);

CREATE INDEX idx_matricula_data_inicio ON matricula (data_inicio);

CREATE INDEX idx_pagamento_data ON pagamento (data_pagamento);

CREATE INDEX idx_aluno_nome ON aluno (nome);

CREATE INDEX idx_log_tabela_data ON log_auditoria (tabela, data_hora);

CREATE INDEX idx_usuarios_grupo_ativo ON usuarios (id_grupo, ativo);

DELIMITER $$

CREATE DEFINER = 'academia_dba'@'localhost'
FUNCTION fn_proximo_numero(p_entidade VARCHAR(30))
RETURNS INT UNSIGNED
NOT DETERMINISTIC MODIFIES SQL DATA
BEGIN
    DECLARE v_valor INT UNSIGNED;

    SELECT ultimo_valor + 1 INTO v_valor
      FROM sequencia_id
     WHERE entidade = p_entidade
       FOR UPDATE;

    IF v_valor IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sequência de ID não cadastrada.';
    END IF;

    UPDATE sequencia_id SET ultimo_valor = v_valor WHERE entidade = p_entidade;
    RETURN v_valor;
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
FUNCTION fn_digito_verificador(p_numero VARCHAR(30))
RETURNS CHAR(1)
DETERMINISTIC NO SQL
BEGIN
    DECLARE v_soma  INT DEFAULT 0;
    DECLARE v_peso  INT DEFAULT 2;
    DECLARE v_pos   INT;
    DECLARE v_dv    INT;

    SET v_pos = CHAR_LENGTH(p_numero);
    WHILE v_pos > 0 DO
        SET v_soma = v_soma + CAST(SUBSTRING(p_numero, v_pos, 1) AS UNSIGNED) * v_peso;
        SET v_peso = IF(v_peso = 9, 2, v_peso + 1);
        SET v_pos  = v_pos - 1;
    END WHILE;

    SET v_dv = 11 - (v_soma MOD 11);
    IF v_dv >= 10 THEN SET v_dv = 0; END IF;
    RETURN CAST(v_dv AS CHAR);
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
FUNCTION fn_gerar_id_usuario() RETURNS VARCHAR(12)
NOT DETERMINISTIC MODIFIES SQL DATA
BEGIN
    RETURN CONCAT('USR', LPAD(fn_proximo_numero('usuarios'), 6, '0'));
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
FUNCTION fn_gerar_id_aluno() RETURNS VARCHAR(12)
NOT DETERMINISTIC MODIFIES SQL DATA
BEGIN
    RETURN CONCAT('ALU', LPAD(fn_proximo_numero('aluno'), 6, '0'));
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
FUNCTION fn_gerar_id_professor() RETURNS VARCHAR(12)
NOT DETERMINISTIC MODIFIES SQL DATA
BEGIN
    RETURN CONCAT('PRF', LPAD(fn_proximo_numero('professor'), 6, '0'));
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
FUNCTION fn_gerar_id_matricula() RETURNS VARCHAR(16)
NOT DETERMINISTIC MODIFIES SQL DATA
BEGIN
    DECLARE v_base VARCHAR(20);
    SET v_base = CONCAT(YEAR(CURDATE()), LPAD(fn_proximo_numero('matricula'), 6, '0'));
    RETURN CONCAT('MAT', v_base, '-', fn_digito_verificador(v_base));
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
FUNCTION fn_gerar_id_pagamento() RETURNS VARCHAR(20)
NOT DETERMINISTIC MODIFIES SQL DATA
BEGIN
    DECLARE v_base VARCHAR(20);
    SET v_base = CONCAT(DATE_FORMAT(CURDATE(), '%Y%m%d'),
                        LPAD(fn_proximo_numero('pagamento'), 6, '0'));
    RETURN CONCAT('PAG', v_base, '-', fn_digito_verificador(v_base));
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
FUNCTION fn_id_valido(p_id VARCHAR(20)) RETURNS TINYINT
DETERMINISTIC NO SQL
BEGIN
    DECLARE v_base VARCHAR(20);
    IF p_id NOT REGEXP '^(MAT|PAG)[0-9]+-[0-9]$' THEN
        RETURN 0;
    END IF;
    SET v_base = SUBSTRING(p_id, 4, CHAR_LENGTH(p_id) - 5);
    RETURN fn_digito_verificador(v_base) = RIGHT(p_id, 1);
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
FUNCTION fn_situacao_matricula(p_situacao VARCHAR(10), p_vencimento DATE)
RETURNS VARCHAR(10)
NOT DETERMINISTIC NO SQL
BEGIN
    IF p_situacao IS NULL THEN
        RETURN NULL;
    ELSEIF p_situacao <> 'Ativa' THEN
        RETURN p_situacao;
    ELSEIF p_vencimento < CURDATE() THEN
        RETURN 'Atrasada';
    END IF;
    RETURN 'Ativa';
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
FUNCTION fn_valor_total_plano(p_id_modalidade INT, p_id_plano INT)
RETURNS DECIMAL(10,2)
NOT DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(10,2);
    SELECT ROUND(mo.valor_mensal * p.duracao_meses * (1 - p.desconto_percentual / 100), 2)
      INTO v_total
      FROM modalidade mo, plano p
     WHERE mo.id_modalidade = p_id_modalidade
       AND p.id_plano = p_id_plano;
    RETURN v_total;
END$$

DELIMITER ;

DELIMITER $$

CREATE DEFINER = 'academia_dba'@'localhost'
TRIGGER trg_usuarios_bi BEFORE INSERT ON usuarios
FOR EACH ROW
BEGIN
    IF NEW.id_usuario IS NULL OR NEW.id_usuario = '' THEN
        SET NEW.id_usuario = fn_gerar_id_usuario();
    END IF;
    SET NEW.login = LOWER(TRIM(NEW.login));
    SET NEW.email = LOWER(TRIM(NEW.email));
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
TRIGGER trg_usuarios_au AFTER UPDATE ON usuarios
FOR EACH ROW
BEGIN
    IF OLD.id_grupo <> NEW.id_grupo THEN
        INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhes, usuario_banco, usuario_app)
        VALUES ('usuarios', 'UPDATE', NEW.id_usuario,
                CONCAT('Grupo alterado: ', OLD.id_grupo, ' -> ', NEW.id_grupo),
                USER(), @usuario_app);
    END IF;
    IF OLD.ativo <> NEW.ativo THEN
        INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhes, usuario_banco, usuario_app)
        VALUES ('usuarios', 'UPDATE', NEW.id_usuario,
                IF(NEW.ativo = 1, 'Usuário reativado', 'Usuário desativado'),
                USER(), @usuario_app);
    END IF;
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
TRIGGER trg_aluno_bi BEFORE INSERT ON aluno
FOR EACH ROW
BEGIN
    SET NEW.cpf = REGEXP_REPLACE(NEW.cpf, '[^0-9]', '');
    IF CHAR_LENGTH(NEW.cpf) <> 11 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF deve conter 11 dígitos.';
    END IF;
    IF NEW.id_aluno IS NULL OR NEW.id_aluno = '' THEN
        SET NEW.id_aluno = fn_gerar_id_aluno();
    END IF;
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
TRIGGER trg_professor_bi BEFORE INSERT ON professor
FOR EACH ROW
BEGIN
    IF NEW.id_professor IS NULL OR NEW.id_professor = '' THEN
        SET NEW.id_professor = fn_gerar_id_professor();
    END IF;
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
TRIGGER trg_matricula_bi BEFORE INSERT ON matricula
FOR EACH ROW
BEGIN
    DECLARE v_abertas INT;
    DECLARE v_meses   INT;

    SELECT COUNT(*) INTO v_abertas
      FROM matricula
     WHERE id_aluno = NEW.id_aluno
       AND id_modalidade = NEW.id_modalidade
       AND situacao <> 'Cancelada';
    IF v_abertas > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Aluno já possui matrícula ativa ou suspensa nesta modalidade.';
    END IF;

    IF NEW.data_inicio IS NULL THEN
        SET NEW.data_inicio = CURDATE();
    END IF;

    IF NEW.valor_mensal IS NULL OR NEW.valor_mensal = 0 THEN
        SET NEW.valor_mensal = (SELECT valor_mensal FROM modalidade
                                 WHERE id_modalidade = NEW.id_modalidade);
    END IF;

    IF NEW.data_vencimento IS NULL THEN
        SELECT duracao_meses INTO v_meses FROM plano WHERE id_plano = NEW.id_plano;
        SET NEW.data_vencimento = DATE_ADD(NEW.data_inicio, INTERVAL v_meses MONTH);
    END IF;

    IF NEW.id_matricula IS NULL OR NEW.id_matricula = '' THEN
        SET NEW.id_matricula = fn_gerar_id_matricula();
    END IF;
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
TRIGGER trg_matricula_ai AFTER INSERT ON matricula
FOR EACH ROW
BEGIN
    INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhes, usuario_banco, usuario_app)
    VALUES ('matricula', 'INSERT', NEW.id_matricula,
            CONCAT('Nova matrícula do aluno ', NEW.id_aluno,
                   ' | vence em ', DATE_FORMAT(NEW.data_vencimento, '%d/%m/%Y')),
            USER(), @usuario_app);
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
TRIGGER trg_matricula_au AFTER UPDATE ON matricula
FOR EACH ROW
BEGIN
    IF OLD.situacao <> NEW.situacao THEN
        INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhes, usuario_banco, usuario_app)
        VALUES ('matricula', 'UPDATE', NEW.id_matricula,
                CONCAT('Situação: ', OLD.situacao, ' -> ', NEW.situacao,
                       IFNULL(CONCAT(' | Motivo: ', @motivo_alteracao), '')),
                USER(), @usuario_app);
    END IF;
    IF OLD.data_vencimento <> NEW.data_vencimento THEN
        INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhes, usuario_banco, usuario_app)
        VALUES ('matricula', 'UPDATE', NEW.id_matricula,
                CONCAT('Vencimento: ', DATE_FORMAT(OLD.data_vencimento, '%d/%m/%Y'),
                       ' -> ', DATE_FORMAT(NEW.data_vencimento, '%d/%m/%Y')),
                USER(), @usuario_app);
    END IF;
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
TRIGGER trg_pagamento_bi BEFORE INSERT ON pagamento
FOR EACH ROW
BEGIN
    IF (SELECT situacao FROM matricula WHERE id_matricula = NEW.id_matricula) = 'Cancelada' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Matrícula cancelada não pode receber pagamento.';
    END IF;
    IF NEW.id_pagamento IS NULL OR NEW.id_pagamento = '' THEN
        SET NEW.id_pagamento = fn_gerar_id_pagamento();
    END IF;
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
TRIGGER trg_pagamento_ai AFTER INSERT ON pagamento
FOR EACH ROW
BEGIN
    INSERT INTO log_auditoria (tabela, operacao, id_registro, detalhes, usuario_banco, usuario_app)
    VALUES ('pagamento', 'INSERT', NEW.id_pagamento,
            CONCAT('R$ ', FORMAT(NEW.valor, 2, 'pt_BR'), ' via ', NEW.forma,
                   ' | matrícula ', NEW.id_matricula),
            USER(), @usuario_app);
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
TRIGGER trg_pagamento_bd BEFORE DELETE ON pagamento
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Pagamentos não podem ser excluídos (integridade financeira).';
END$$

DELIMITER ;

CREATE DEFINER = 'academia_dba'@'localhost' SQL SECURITY DEFINER
VIEW vw_matriculas_detalhadas AS
SELECT m.id_matricula,
       m.id_aluno,
       a.nome                                              AS aluno,
       a.cpf,
       a.telefone,
       mo.id_modalidade,
       mo.nome                                             AS modalidade,
       p.id_plano,
       p.nome                                              AS plano,
       p.duracao_meses,
       pr.id_professor,
       pr.nome                                             AS professor,
       m.data_inicio,
       m.data_vencimento,
       m.valor_mensal,
       m.situacao,
       fn_situacao_matricula(m.situacao, m.data_vencimento) AS situacao_atual,
       DATEDIFF(m.data_vencimento, CURDATE())               AS dias_para_vencer
  FROM matricula m
  JOIN aluno      a  ON a.id_aluno       = m.id_aluno
  JOIN plano      p  ON p.id_plano       = m.id_plano
  JOIN modalidade mo ON mo.id_modalidade = m.id_modalidade
  JOIN professor  pr ON pr.id_professor  = m.id_professor;

CREATE DEFINER = 'academia_dba'@'localhost' SQL SECURITY DEFINER
VIEW vw_resumo_modalidades AS
SELECT mo.id_modalidade,
       mo.nome         AS modalidade,
       mo.valor_mensal AS preco_atual,
       SUM(CASE WHEN fn_situacao_matricula(m.situacao, m.data_vencimento) = 'Ativa'    THEN 1 ELSE 0 END) AS em_dia,
       SUM(CASE WHEN fn_situacao_matricula(m.situacao, m.data_vencimento) = 'Atrasada' THEN 1 ELSE 0 END) AS atrasadas,
       SUM(CASE WHEN m.situacao = 'Suspensa' THEN 1 ELSE 0 END)                                         AS suspensas,
       COALESCE(SUM(CASE WHEN m.situacao = 'Ativa'
                         THEN m.valor_mensal * (1 - p.desconto_percentual / 100) END), 0)               AS receita_mensal_prevista
  FROM modalidade mo
  LEFT JOIN matricula m ON m.id_modalidade = mo.id_modalidade
  LEFT JOIN plano     p ON p.id_plano      = m.id_plano
 GROUP BY mo.id_modalidade, mo.nome, mo.valor_mensal;

CREATE DEFINER = 'academia_dba'@'localhost' SQL SECURITY DEFINER
VIEW vw_inadimplentes AS
SELECT id_matricula,
       id_aluno,
       aluno,
       telefone,
       modalidade,
       plano,
       data_vencimento,
       DATEDIFF(CURDATE(), data_vencimento) AS dias_em_atraso,
       valor_mensal
  FROM vw_matriculas_detalhadas
 WHERE situacao_atual = 'Atrasada';

CREATE DEFINER = 'academia_dba'@'localhost' SQL SECURITY DEFINER
VIEW vw_receita_mensal AS
SELECT DATE_FORMAT(data_pagamento, '%Y-%m') AS mes,
       COUNT(*)                              AS qtd_pagamentos,
       SUM(valor)                            AS total_recebido
  FROM pagamento
 GROUP BY DATE_FORMAT(data_pagamento, '%Y-%m');

CREATE DEFINER = 'academia_dba'@'localhost' SQL SECURITY DEFINER
VIEW vw_usuarios_seguro AS
SELECT u.id_usuario,
       u.nome,
       u.login,
       u.email,
       u.id_grupo,
       g.nome AS grupo,
       g.nivel_acesso,
       u.ativo,
       u.criado_em,
       u.ultimo_acesso
  FROM usuarios u
  JOIN grupos_usuarios g ON g.id_grupo = u.id_grupo;

DELIMITER $$

CREATE DEFINER = 'academia_dba'@'localhost'
PROCEDURE sp_autenticar(IN p_login VARCHAR(30), IN p_senha_hash CHAR(64))
BEGIN
    UPDATE usuarios
       SET ultimo_acesso = NOW()
     WHERE login = LOWER(TRIM(p_login))
       AND senha_hash = p_senha_hash
       AND ativo = 1;

    SELECT u.id_usuario, u.nome, u.login, u.id_grupo,
           g.nome AS grupo, g.nivel_acesso, a.id_aluno
      FROM usuarios u
      JOIN grupos_usuarios g ON g.id_grupo = u.id_grupo
      LEFT JOIN aluno a      ON a.id_usuario = u.id_usuario
     WHERE u.login = LOWER(TRIM(p_login))
       AND u.senha_hash = p_senha_hash
       AND u.ativo = 1;
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
PROCEDURE sp_contratar_matricula(
    IN  p_id_aluno       VARCHAR(12),
    IN  p_id_modalidade  INT,
    IN  p_id_plano       INT,
    IN  p_id_professor   VARCHAR(12),
    IN  p_forma          VARCHAR(20),
    IN  p_id_usuario     VARCHAR(12),
    OUT p_id_matricula   VARCHAR(16),
    OUT p_id_pagamento   VARCHAR(20))
BEGIN
    DECLARE v_meses TINYINT;
    DECLARE v_valor DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET @usuario_app = p_id_usuario;

    START TRANSACTION;

        SET p_id_matricula = fn_gerar_id_matricula();

        INSERT INTO matricula (id_matricula, id_aluno, id_plano, id_modalidade,
                               id_professor, data_inicio, criado_por)
        VALUES (p_id_matricula, p_id_aluno, p_id_plano, p_id_modalidade,
                p_id_professor, CURDATE(), p_id_usuario);

        SELECT duracao_meses INTO v_meses FROM plano WHERE id_plano = p_id_plano;
        SET v_valor = fn_valor_total_plano(p_id_modalidade, p_id_plano);

        SET p_id_pagamento = fn_gerar_id_pagamento();
        INSERT INTO pagamento (id_pagamento, id_matricula, valor, forma, meses_pagos, registrado_por)
        VALUES (p_id_pagamento, p_id_matricula, v_valor, p_forma, v_meses, p_id_usuario);

    COMMIT;
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
PROCEDURE sp_registrar_pagamento(
    IN  p_id_matricula  VARCHAR(16),
    IN  p_forma         VARCHAR(20),
    IN  p_id_usuario    VARCHAR(12),
    OUT p_id_pagamento  VARCHAR(20))
BEGIN
    DECLARE v_situacao  VARCHAR(10);
    DECLARE v_mensal    DECIMAL(8,2);
    DECLARE v_meses     TINYINT;
    DECLARE v_desconto  DECIMAL(5,2);
    DECLARE v_valor     DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET @usuario_app = p_id_usuario;

    START TRANSACTION;

        SELECT m.situacao, m.valor_mensal, p.duracao_meses, p.desconto_percentual
          INTO v_situacao, v_mensal, v_meses, v_desconto
          FROM matricula m
          JOIN plano p ON p.id_plano = m.id_plano
         WHERE m.id_matricula = p_id_matricula
           FOR UPDATE;

        IF v_situacao IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Matrícula não encontrada.';
        END IF;

        SET v_valor = ROUND(v_mensal * v_meses * (1 - v_desconto / 100), 2);

        SET p_id_pagamento = fn_gerar_id_pagamento();
        INSERT INTO pagamento (id_pagamento, id_matricula, valor, forma, meses_pagos, registrado_por)
        VALUES (p_id_pagamento, p_id_matricula, v_valor, p_forma, v_meses, p_id_usuario);

        UPDATE matricula
           SET data_vencimento = DATE_ADD(data_vencimento, INTERVAL v_meses MONTH),
               situacao = 'Ativa'
         WHERE id_matricula = p_id_matricula;

    COMMIT;
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
PROCEDURE sp_cancelar_matricula(
    IN p_id_matricula VARCHAR(16),
    IN p_motivo       VARCHAR(200),
    IN p_id_usuario   VARCHAR(12))
BEGIN
    DECLARE v_situacao VARCHAR(10);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @motivo_alteracao = NULL;
        RESIGNAL;
    END;

    SET @usuario_app = p_id_usuario;
    SET @motivo_alteracao = NULLIF(TRIM(p_motivo), '');

    START TRANSACTION;

        SELECT situacao INTO v_situacao
          FROM matricula WHERE id_matricula = p_id_matricula FOR UPDATE;

        IF v_situacao IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Matrícula não encontrada.';
        ELSEIF v_situacao = 'Cancelada' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Esta matrícula já está cancelada.';
        END IF;

        UPDATE matricula SET situacao = 'Cancelada' WHERE id_matricula = p_id_matricula;

    COMMIT;
    SET @motivo_alteracao = NULL;
END$$

CREATE DEFINER = 'academia_dba'@'localhost'
PROCEDURE sp_relatorio_matriculas(
    IN p_inicio    DATE,
    IN p_fim       DATE,
    IN p_situacao  VARCHAR(10))
BEGIN
    SELECT *
      FROM vw_matriculas_detalhadas
     WHERE (p_inicio   IS NULL OR data_inicio >= p_inicio)
       AND (p_fim      IS NULL OR data_inicio <= p_fim)
       AND (p_situacao IS NULL OR situacao_atual = p_situacao)
     ORDER BY data_inicio DESC, id_matricula DESC;
END$$

DELIMITER ;

SET @usuario_app = 'instalacao';

INSERT INTO sequencia_id (entidade, prefixo) VALUES
    ('usuarios',  'USR'),
    ('aluno',     'ALU'),
    ('professor', 'PRF'),
    ('matricula', 'MAT'),
    ('pagamento', 'PAG');

INSERT INTO grupos_usuarios (id_grupo, nome, descricao, nivel_acesso) VALUES
    ('ADM', 'Administradores', 'Acesso total: usuários, auditoria, cadastros e financeiro', 3),
    ('REC', 'Recepção',        'Cadastro de alunos, matrículas e pagamentos',              2),
    ('ALU', 'Alunos',          'Consulta e contratação das próprias matrículas',           1);

INSERT INTO usuarios (nome, login, email, senha_hash, id_grupo) VALUES
    ('Administrador',     'admin',       'admin@academia.com',    SHA2('admin123', 256), 'ADM'),
    ('Juliana Recepção',  'recepcao',    'recepcao@academia.com', SHA2('recep123', 256), 'REC'),
    ('Ana Paula Lima',    '11122233344', 'ana@email.com',         SHA2('aluno123', 256), 'ALU'),
    ('Bruno Martins',     '22233344455', 'bruno@email.com',       SHA2('aluno123', 256), 'ALU'),
    ('Camila Ferreira',   '33344455566', 'camila@email.com',      SHA2('aluno123', 256), 'ALU'),
    ('Diego Santos',      '44455566677', 'diego@email.com',       SHA2('aluno123', 256), 'ALU');

INSERT INTO professor (nome, telefone, cref) VALUES
    ('Carlos Souza',   '(61) 98888-0001', 'CREF-001/DF'),
    ('Fernanda Rocha', '(61) 98888-0002', 'CREF-002/DF'),
    ('Ricardo Alves',  '(61) 98888-0003', 'CREF-003/DF');

INSERT INTO modalidade (nome, descricao, valor_mensal) VALUES
    ('Musculação', 'Treino de força com acompanhamento',   120.00),
    ('Natação',    'Aulas em piscina aquecida',            180.00),
    ('Pilates',    'Pilates de solo e aparelhos',          200.00),
    ('Crossfit',   'Treino funcional de alta intensidade', 160.00);

INSERT INTO plano (nome, duracao_meses, desconto_percentual) VALUES
    ('Mensal',     1,  0),
    ('Trimestral', 3,  5),
    ('Semestral',  6, 10),
    ('Anual',     12, 15);

INSERT INTO aluno (id_usuario, nome, cpf, telefone, email, data_nascimento) VALUES
    ('USR000003', 'Ana Paula Lima',  '111.222.333-44', '(61) 99999-1001', 'ana@email.com',    '1998-04-12'),
    ('USR000004', 'Bruno Martins',   '222.333.444-55', '(61) 99999-1002', 'bruno@email.com',  '2001-09-30'),
    ('USR000005', 'Camila Ferreira', '333.444.555-66', '(61) 99999-1003', 'camila@email.com', '1995-01-22'),
    ('USR000006', 'Diego Santos',    '444.555.666-77', '(61) 99999-1004', 'diego@email.com',  '1990-11-05');

CALL sp_contratar_matricula('ALU000001', 1, 3, 'PRF000001', 'Pix',               'USR000002', @m, @p);
CALL sp_contratar_matricula('ALU000001', 3, 2, 'PRF000002', 'Cartão de crédito', 'USR000002', @m, @p);
CALL sp_contratar_matricula('ALU000002', 4, 4, 'PRF000003', 'Pix',               'USR000002', @m, @p);
CALL sp_contratar_matricula('ALU000003', 2, 1, 'PRF000002', 'Dinheiro',          'USR000002', @m, @p);

INSERT INTO matricula (id_aluno, id_plano, id_modalidade, id_professor, data_inicio, criado_por)
VALUES ('ALU000004', 1, 1, 'PRF000001', DATE_SUB(CURDATE(), INTERVAL 75 DAY), 'USR000002'),
       ('ALU000002', 1, 2, 'PRF000002', DATE_SUB(CURDATE(), INTERVAL 50 DAY), 'USR000002');

INSERT INTO pagamento (id_matricula, valor, forma, meses_pagos, data_pagamento, registrado_por)
SELECT id_matricula, valor_mensal, 'Dinheiro', 1, data_inicio, 'USR000002'
  FROM matricula
 WHERE data_inicio < CURDATE();

CALL sp_contratar_matricula('ALU000003', 4, 1, 'PRF000003', 'Pix', 'USR000002', @m, @p);
CALL sp_cancelar_matricula(@m, 'Aluno mudou de cidade', 'USR000002');

SET @usuario_app = NULL;

CREATE ROLE 'role_academia_app', 'role_academia_leitura';

GRANT SELECT ON academia.vw_matriculas_detalhadas TO 'role_academia_leitura';
GRANT SELECT ON academia.vw_resumo_modalidades    TO 'role_academia_leitura';
GRANT SELECT ON academia.vw_inadimplentes         TO 'role_academia_leitura';
GRANT SELECT ON academia.vw_receita_mensal        TO 'role_academia_leitura';

GRANT SELECT ON academia.aluno           TO 'role_academia_app';
GRANT SELECT ON academia.professor       TO 'role_academia_app';
GRANT SELECT ON academia.modalidade      TO 'role_academia_app';
GRANT SELECT ON academia.plano           TO 'role_academia_app';
GRANT SELECT ON academia.grupos_usuarios TO 'role_academia_app';
GRANT SELECT ON academia.log_auditoria   TO 'role_academia_app';

GRANT SELECT ON academia.vw_matriculas_detalhadas TO 'role_academia_app';
GRANT SELECT ON academia.vw_resumo_modalidades    TO 'role_academia_app';
GRANT SELECT ON academia.vw_inadimplentes         TO 'role_academia_app';
GRANT SELECT ON academia.vw_receita_mensal        TO 'role_academia_app';
GRANT SELECT ON academia.vw_usuarios_seguro       TO 'role_academia_app';

GRANT INSERT, UPDATE ON academia.aluno TO 'role_academia_app';

GRANT INSERT ON academia.usuarios TO 'role_academia_app';
GRANT SELECT (id_usuario, login, ativo), UPDATE (ativo) ON academia.usuarios TO 'role_academia_app';

GRANT EXECUTE ON PROCEDURE academia.sp_autenticar           TO 'role_academia_app';
GRANT EXECUTE ON PROCEDURE academia.sp_contratar_matricula  TO 'role_academia_app';
GRANT EXECUTE ON PROCEDURE academia.sp_registrar_pagamento  TO 'role_academia_app';
GRANT EXECUTE ON PROCEDURE academia.sp_cancelar_matricula   TO 'role_academia_app';
GRANT EXECUTE ON PROCEDURE academia.sp_relatorio_matriculas TO 'role_academia_app';
GRANT EXECUTE ON FUNCTION  academia.fn_gerar_id_usuario     TO 'role_academia_app';
GRANT EXECUTE ON FUNCTION  academia.fn_valor_total_plano    TO 'role_academia_app';
GRANT EXECUTE ON FUNCTION  academia.fn_id_valido            TO 'role_academia_app';

CREATE USER 'academia_app'@'localhost'
    IDENTIFIED BY 'App@Academia2026'
    DEFAULT ROLE 'role_academia_app';
GRANT 'role_academia_app' TO 'academia_app'@'localhost';

CREATE USER 'academia_relatorio'@'localhost'
    IDENTIFIED BY 'Relatorio@2026'
    DEFAULT ROLE 'role_academia_leitura'
    FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1;
GRANT 'role_academia_leitura' TO 'academia_relatorio'@'localhost';

SET GLOBAL log_bin_trust_function_creators = 0;

SHOW GRANTS FOR 'academia_app'@'localhost' USING 'role_academia_app';
