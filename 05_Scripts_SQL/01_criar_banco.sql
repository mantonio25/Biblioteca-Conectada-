-- =====================================================================
--  BIBLIOTECA CONECTADA - Script 01: Criação do banco de dados
--  SGBD: MySQL 8.0+
--  Cria (ou recria) o schema biblioteca_conectada.
--  Pré-requisito: nenhum. ATENÇÃO: apaga o banco se ele já existir.
-- =====================================================================

-- 1. BANCO DE DADOS
-- ---------------------------------------------------------------------
DROP SCHEMA IF EXISTS biblioteca_conectada;
CREATE SCHEMA biblioteca_conectada
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE biblioteca_conectada;
