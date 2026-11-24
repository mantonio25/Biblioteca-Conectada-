-- =====================================================================
--  BIBLIOTECA CONECTADA - Script 02: Criação das tabelas
--  SGBD: MySQL 8.0+
--  Cria as 9 tabelas com chaves, índices e restrições.
--  Pré-requisito: 01_criar_banco.sql
-- =====================================================================

USE biblioteca_conectada;

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;

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
