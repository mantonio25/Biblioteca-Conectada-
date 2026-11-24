-- =====================================================================
--  BIBLIOTECA CONECTADA - Script 04: Triggers das regras de negócio
--  SGBD: MySQL 8.0+
--  Cria os 5 triggers (RN02, RN05, RN06, RN07, RN10).
--  Pré-requisito: 02_criar_tabelas.sql
-- =====================================================================

USE biblioteca_conectada;

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
