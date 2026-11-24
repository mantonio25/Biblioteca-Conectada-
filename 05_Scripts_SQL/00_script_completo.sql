-- =====================================================================
--  BIBLIOTECA CONECTADA
--  Sistema de Gerenciamento de Empréstimos e Reservas de Livros
--  Script SQL - Modelo Físico (SGBD: MySQL 8.0+)
--  IFRO Campus Ariquemes - ADS - Gerenciamento de Projetos - 2026
-- =====================================================================
--  Seções do script:
--    1. Criação do banco de dados
--    2. Criação das tabelas (DDL)
--    3. Views de consulta (RF10, RF11, RF12, RF13)
--    4. Triggers de regras de negócio (RN02, RN05, RN07, RN10)
--    5. Dados de teste (opcional)
-- =====================================================================

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;

-- ---------------------------------------------------------------------
-- 1. BANCO DE DADOS
-- ---------------------------------------------------------------------
DROP SCHEMA IF EXISTS biblioteca_conectada;
CREATE SCHEMA biblioteca_conectada
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE biblioteca_conectada;

-- ---------------------------------------------------------------------
-- 2. TABELAS
-- ---------------------------------------------------------------------

-- Tabela: editora --------------------------------------------------------
CREATE TABLE editora (
  id_editora   INT          NOT NULL AUTO_INCREMENT,
  nome         VARCHAR(100) NOT NULL,
  cidade       VARCHAR(80)  NULL,
  PRIMARY KEY (id_editora),
  UNIQUE INDEX uq_editora_nome (nome)
) ENGINE = InnoDB;

-- Tabela: autor ----------------------------------------------------------
CREATE TABLE autor (
  id_autor     INT          NOT NULL AUTO_INCREMENT,
  nome         VARCHAR(120) NOT NULL,
  PRIMARY KEY (id_autor),
  INDEX idx_autor_nome (nome)
) ENGINE = InnoDB;

-- Tabela: livro (título/obra) --------------------------------------------
CREATE TABLE livro (
  id_livro        INT          NOT NULL AUTO_INCREMENT,
  titulo          VARCHAR(200) NOT NULL,
  isbn            VARCHAR(13)  NULL,
  ano_publicacao  SMALLINT     NULL,
  genero          VARCHAR(60)  NULL,
  id_editora      INT          NOT NULL,
  PRIMARY KEY (id_livro),
  UNIQUE INDEX uq_livro_isbn (isbn),
  INDEX idx_livro_titulo (titulo),
  INDEX fk_livro_editora_idx (id_editora),
  CONSTRAINT fk_livro_editora
    FOREIGN KEY (id_editora) REFERENCES editora (id_editora)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_livro_ano CHECK (ano_publicacao IS NULL OR ano_publicacao > 0)
) ENGINE = InnoDB;

-- Tabela associativa: livro_autor (N:N entre livro e autor) --------------
CREATE TABLE livro_autor (
  id_livro  INT NOT NULL,
  id_autor  INT NOT NULL,
  PRIMARY KEY (id_livro, id_autor),
  INDEX fk_livro_autor_autor_idx (id_autor),
  CONSTRAINT fk_livro_autor_livro
    FOREIGN KEY (id_livro) REFERENCES livro (id_livro)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_livro_autor_autor
    FOREIGN KEY (id_autor) REFERENCES autor (id_autor)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB;

-- Tabela: exemplar (cópia física de um livro) -----------------------------
CREATE TABLE exemplar (
  id_exemplar     INT         NOT NULL AUTO_INCREMENT,
  cod_patrimonio  VARCHAR(30) NOT NULL,
  status          ENUM('DISPONIVEL','EMPRESTADO','RESERVADO','INDISPONIVEL')
                              NOT NULL DEFAULT 'DISPONIVEL',
  localizacao     VARCHAR(50) NULL,
  id_livro        INT         NOT NULL,
  PRIMARY KEY (id_exemplar),
  UNIQUE INDEX uq_exemplar_patrimonio (cod_patrimonio),
  INDEX fk_exemplar_livro_idx (id_livro),
  INDEX idx_exemplar_status (status),
  CONSTRAINT fk_exemplar_livro
    FOREIGN KEY (id_livro) REFERENCES livro (id_livro)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB;

-- Tabela: leitor ---------------------------------------------------------
CREATE TABLE leitor (
  id_leitor      INT          NOT NULL AUTO_INCREMENT,
  nome           VARCHAR(120) NOT NULL,
  cpf            CHAR(11)     NOT NULL,   -- só números, sem pontos e traço
  email          VARCHAR(120) NULL,
  telefone       VARCHAR(15)  NULL,
  data_cadastro  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_leitor),
  UNIQUE INDEX uq_leitor_cpf (cpf),
  UNIQUE INDEX uq_leitor_email (email),
  INDEX idx_leitor_nome (nome)
) ENGINE = InnoDB;

-- Tabela: usuario (login e perfil de acesso - RNF02 e RNF03) --------------
CREATE TABLE usuario (
  id_usuario   INT          NOT NULL AUTO_INCREMENT,
  login        VARCHAR(50)  NOT NULL,
  senha_hash   VARCHAR(255) NOT NULL,   -- nunca guardar senha em texto puro
  perfil       ENUM('ADMINISTRADOR','LEITOR') NOT NULL DEFAULT 'LEITOR',
  ativo        TINYINT(1)   NOT NULL DEFAULT 1,
  id_leitor    INT          NULL,       -- preenchido quando perfil = LEITOR
  PRIMARY KEY (id_usuario),
  UNIQUE INDEX uq_usuario_login (login),
  UNIQUE INDEX uq_usuario_leitor (id_leitor),
  CONSTRAINT fk_usuario_leitor
    FOREIGN KEY (id_leitor) REFERENCES leitor (id_leitor)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB;

-- Tabela: emprestimo -----------------------------------------------------
CREATE TABLE emprestimo (
  id_emprestimo            INT   NOT NULL AUTO_INCREMENT,
  data_emprestimo          DATE  NOT NULL,
  data_devolucao_prevista  DATE  NOT NULL,
  data_devolucao_real      DATE  NULL,
  status                   ENUM('ATIVO','DEVOLVIDO') NOT NULL DEFAULT 'ATIVO',
  id_leitor                INT   NOT NULL,
  id_exemplar              INT   NOT NULL,
  PRIMARY KEY (id_emprestimo),
  INDEX fk_emprestimo_leitor_idx (id_leitor),
  INDEX fk_emprestimo_exemplar_idx (id_exemplar),
  INDEX idx_emprestimo_status_prev (status, data_devolucao_prevista),
  CONSTRAINT fk_emprestimo_leitor
    FOREIGN KEY (id_leitor) REFERENCES leitor (id_leitor)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_emprestimo_exemplar
    FOREIGN KEY (id_exemplar) REFERENCES exemplar (id_exemplar)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_emprestimo_prazo
    CHECK (data_devolucao_prevista >= data_emprestimo),
  CONSTRAINT ck_emprestimo_devolucao
    CHECK (data_devolucao_real IS NULL OR data_devolucao_real >= data_emprestimo)
) ENGINE = InnoDB;

-- Tabela: reserva --------------------------------------------------------
CREATE TABLE reserva (
  id_reserva    INT       NOT NULL AUTO_INCREMENT,
  data_reserva  DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  posicao_fila  INT       NULL,
  status        ENUM('AGUARDANDO','DISPONIVEL','ATENDIDA','CANCELADA')
                          NOT NULL DEFAULT 'AGUARDANDO',
  id_leitor     INT       NOT NULL,
  id_livro      INT       NOT NULL,
  PRIMARY KEY (id_reserva),
  INDEX fk_reserva_leitor_idx (id_leitor),
  INDEX fk_reserva_livro_idx (id_livro),
  INDEX idx_reserva_fila (id_livro, status, data_reserva),
  CONSTRAINT fk_reserva_leitor
    FOREIGN KEY (id_leitor) REFERENCES leitor (id_leitor)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_reserva_livro
    FOREIGN KEY (id_livro) REFERENCES livro (id_livro)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB;

SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

-- ---------------------------------------------------------------------
-- 3. VIEWS
-- ---------------------------------------------------------------------

-- RF13 - Disponibilidade por livro
CREATE OR REPLACE VIEW vw_disponibilidade_livro AS
SELECT l.id_livro,
       l.titulo,
       COUNT(e.id_exemplar)                         AS total_exemplares,
       SUM(e.status = 'DISPONIVEL')                 AS disponiveis,
       SUM(e.status = 'EMPRESTADO')                 AS emprestados,
       SUM(e.status = 'RESERVADO')                  AS reservados
FROM livro l
LEFT JOIN exemplar e ON e.id_livro = l.id_livro
GROUP BY l.id_livro, l.titulo;

-- RF10 - Empréstimos ativos com prazo
CREATE OR REPLACE VIEW vw_emprestimos_ativos AS
SELECT em.id_emprestimo,
       le.nome   AS leitor,
       li.titulo AS livro,
       ex.cod_patrimonio,
       em.data_emprestimo,
       em.data_devolucao_prevista,
       DATEDIFF(em.data_devolucao_prevista, CURDATE()) AS dias_restantes
FROM emprestimo em
JOIN leitor   le ON le.id_leitor   = em.id_leitor
JOIN exemplar ex ON ex.id_exemplar = em.id_exemplar
JOIN livro    li ON li.id_livro    = ex.id_livro
WHERE em.status = 'ATIVO';

-- RF11 / RN08 - Empréstimos em atraso (prazo vencido e sem devolução)
CREATE OR REPLACE VIEW vw_emprestimos_atrasados AS
SELECT em.id_emprestimo,
       le.nome   AS leitor,
       le.telefone,
       li.titulo AS livro,
       em.data_devolucao_prevista,
       DATEDIFF(CURDATE(), em.data_devolucao_prevista) AS dias_atraso
FROM emprestimo em
JOIN leitor   le ON le.id_leitor   = em.id_leitor
JOIN exemplar ex ON ex.id_exemplar = em.id_exemplar
JOIN livro    li ON li.id_livro    = ex.id_livro
WHERE em.data_devolucao_real IS NULL
  AND em.data_devolucao_prevista < CURDATE();

-- RF12 / RN09 - Histórico de empréstimos e devoluções
CREATE OR REPLACE VIEW vw_historico_emprestimos AS
SELECT em.id_emprestimo,
       le.id_leitor, le.nome AS leitor,
       li.id_livro,  li.titulo AS livro,
       ex.cod_patrimonio,
       em.data_emprestimo,
       em.data_devolucao_prevista,
       em.data_devolucao_real,
       em.status
FROM emprestimo em
JOIN leitor   le ON le.id_leitor   = em.id_leitor
JOIN exemplar ex ON ex.id_exemplar = em.id_exemplar
JOIN livro    li ON li.id_livro    = ex.id_livro;

-- RF09 / RN07 - Fila de reservas por livro (ordem de solicitação)
CREATE OR REPLACE VIEW vw_fila_reservas AS
SELECT r.id_reserva,
       li.titulo AS livro,
       le.nome   AS leitor,
       r.data_reserva,
       r.posicao_fila,
       r.status
FROM reserva r
JOIN livro  li ON li.id_livro  = r.id_livro
JOIN leitor le ON le.id_leitor = r.id_leitor
WHERE r.status IN ('AGUARDANDO','DISPONIVEL')
ORDER BY li.titulo, r.data_reserva;

-- ---------------------------------------------------------------------
-- 4. TRIGGERS (regras de negócio garantidas pelo banco - RNF05/RNF06)
-- ---------------------------------------------------------------------
DELIMITER $$

-- RN02 - Só empresta exemplar DISPONIVEL
--        (ou RESERVADO, se for para o 1º leitor da fila daquele livro - RN10)
CREATE TRIGGER trg_emprestimo_bi
BEFORE INSERT ON emprestimo
FOR EACH ROW
BEGIN
  DECLARE v_status   VARCHAR(20);
  DECLARE v_id_livro INT;
  DECLARE v_reserva  INT;

  SELECT status, id_livro INTO v_status, v_id_livro
  FROM exemplar WHERE id_exemplar = NEW.id_exemplar;

  IF v_status = 'RESERVADO' THEN
    SELECT id_reserva INTO v_reserva
    FROM reserva
    WHERE id_livro = v_id_livro AND status = 'DISPONIVEL'
      AND id_leitor = NEW.id_leitor
    ORDER BY data_reserva LIMIT 1;

    IF v_reserva IS NULL THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Exemplar reservado para outro leitor da fila.';
    END IF;
  ELSEIF v_status IS NULL OR v_status <> 'DISPONIVEL' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Exemplar indisponivel para emprestimo.';
  END IF;
END$$

-- Após registrar o empréstimo: exemplar vira EMPRESTADO
-- e, se veio de uma reserva, ela é marcada como ATENDIDA
CREATE TRIGGER trg_emprestimo_ai
AFTER INSERT ON emprestimo
FOR EACH ROW
BEGIN
  DECLARE v_id_livro INT;
  SELECT id_livro INTO v_id_livro FROM exemplar WHERE id_exemplar = NEW.id_exemplar;

  UPDATE exemplar SET status = 'EMPRESTADO' WHERE id_exemplar = NEW.id_exemplar;

  UPDATE reserva SET status = 'ATENDIDA', posicao_fila = NULL
  WHERE id_livro = v_id_livro AND id_leitor = NEW.id_leitor
    AND status IN ('DISPONIVEL','AGUARDANDO');
END$$

-- Ao informar a data de devolução, o status muda para DEVOLVIDO
CREATE TRIGGER trg_emprestimo_bu
BEFORE UPDATE ON emprestimo
FOR EACH ROW
BEGIN
  IF NEW.data_devolucao_real IS NOT NULL AND OLD.data_devolucao_real IS NULL THEN
    SET NEW.status = 'DEVOLVIDO';
  END IF;
END$$

-- RN05 + RN10 - Na devolução, atualiza o exemplar considerando a fila
CREATE TRIGGER trg_emprestimo_au
AFTER UPDATE ON emprestimo
FOR EACH ROW
BEGIN
  DECLARE v_id_livro INT;
  DECLARE v_reserva  INT;

  IF NEW.data_devolucao_real IS NOT NULL AND OLD.data_devolucao_real IS NULL THEN
    SELECT id_livro INTO v_id_livro FROM exemplar WHERE id_exemplar = NEW.id_exemplar;

    SELECT id_reserva INTO v_reserva
    FROM reserva
    WHERE id_livro = v_id_livro AND status = 'AGUARDANDO'
    ORDER BY data_reserva LIMIT 1;

    IF v_reserva IS NOT NULL THEN
      UPDATE exemplar SET status = 'RESERVADO'  WHERE id_exemplar = NEW.id_exemplar;
      UPDATE reserva  SET status = 'DISPONIVEL' WHERE id_reserva  = v_reserva;
    ELSE
      UPDATE exemplar SET status = 'DISPONIVEL' WHERE id_exemplar = NEW.id_exemplar;
    END IF;
  END IF;
END$$

-- RN06 + RN07 - Reserva só quando não há exemplar disponível
--               e entra no fim da fila do livro
CREATE TRIGGER trg_reserva_bi
BEFORE INSERT ON reserva
FOR EACH ROW
BEGIN
  IF EXISTS (SELECT 1 FROM exemplar
             WHERE id_livro = NEW.id_livro AND status = 'DISPONIVEL') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Ha exemplar disponivel: realize o emprestimo.';
  END IF;

  SET NEW.posicao_fila = (
    SELECT COUNT(*) + 1 FROM reserva
    WHERE id_livro = NEW.id_livro AND status IN ('AGUARDANDO','DISPONIVEL')
  );
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- 5. DADOS DE TESTE (opcional - pode remover para a entrega)
-- ---------------------------------------------------------------------
INSERT INTO editora (nome, cidade) VALUES
  ('Companhia das Letras', 'São Paulo'),
  ('Rocco',                'Rio de Janeiro'),
  ('Novatec',              'São Paulo');

INSERT INTO autor (nome) VALUES
  ('Machado de Assis'), ('Clarice Lispector'),
  ('Robert C. Martin'), ('Jorge Amado');

INSERT INTO livro (titulo, isbn, ano_publicacao, genero, id_editora) VALUES
  ('Dom Casmurro',          '9788535910667', 1899, 'Romance',    1),
  ('A Hora da Estrela',     '9788532508126', 1977, 'Romance',    2),
  ('Código Limpo',          '9788576082675', 2008, 'Tecnologia', 3),
  ('Capitães da Areia',     '9788535914061', 1937, 'Romance',    1);

INSERT INTO livro_autor (id_livro, id_autor) VALUES (1,1), (2,2), (3,3), (4,4);

INSERT INTO exemplar (cod_patrimonio, localizacao, id_livro) VALUES
  ('BC-0001', 'Estante A1', 1),
  ('BC-0002', 'Estante A1', 1),
  ('BC-0003', 'Estante A2', 2),
  ('BC-0004', 'Estante T1', 3),
  ('BC-0005', 'Estante A3', 4);

INSERT INTO leitor (nome, cpf, email, telefone) VALUES
  ('Ana Souza',      '12345678901', 'ana@email.com',    '69999990001'),
  ('Bruno Lima',     '23456789012', 'bruno@email.com',  '69999990002'),
  ('Carla Mendes',   '34567890123', 'carla@email.com',  '69999990003');

-- senha_hash de exemplo (na aplicação real, gerar com bcrypt/argon2)
INSERT INTO usuario (login, senha_hash, perfil, id_leitor) VALUES
  ('admin', '$2y$10$exemploHashAdmin', 'ADMINISTRADOR', NULL),
  ('ana',   '$2y$10$exemploHashAna',   'LEITOR',        1);

-- Empréstimo em dia e empréstimo atrasado
INSERT INTO emprestimo (data_emprestimo, data_devolucao_prevista, id_leitor, id_exemplar) VALUES
  (CURDATE(),                               CURDATE() + INTERVAL 14 DAY, 1, 4),
  (CURDATE() - INTERVAL 20 DAY, CURDATE() - INTERVAL 6 DAY,             2, 3);

-- 'A Hora da Estrela' está emprestado -> Carla entra na fila de reserva
INSERT INTO reserva (id_leitor, id_livro) VALUES (3, 2);
