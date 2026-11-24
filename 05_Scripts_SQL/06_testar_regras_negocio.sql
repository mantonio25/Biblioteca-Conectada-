-- =====================================================================
--  BIBLIOTECA CONECTADA - Script 06: Testes das regras de negócio
--  SGBD: MySQL 8.0+
--  Executa 12 testes automáticos sobre as regras de negócio e mostra,
--  para cada um, o resultado esperado, o obtido e se PASSOU ou FALHOU.
--  Todos os testes rodam dentro de uma transação que é desfeita no
--  final (ROLLBACK): os dados de teste não são alterados.
--  Pré-requisito: scripts 01 a 05 (ou o 00_script_completo.sql).
-- =====================================================================

USE biblioteca_conectada;

DROP PROCEDURE IF EXISTS sp_testar_regras_negocio;

DELIMITER $$

CREATE PROCEDURE sp_testar_regras_negocio()
BEGIN
  DECLARE v_erro TINYINT DEFAULT 0;
  DECLARE v_msg  VARCHAR(255);
  DECLARE v_txt  VARCHAR(255);
  DECLARE v_num  INT;

  -- Captura qualquer erro sem interromper os testes
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
    SET v_erro = 1;
  END;

  -- Tabela de resultados (MEMORY: não é desfeita pelo ROLLBACK)
  DROP TEMPORARY TABLE IF EXISTS resultado_teste;
  CREATE TEMPORARY TABLE resultado_teste (
    num       INT,
    regra     VARCHAR(20),
    teste     VARCHAR(120),
    esperado  VARCHAR(120),
    obtido    VARCHAR(255),
    situacao  VARCHAR(10)
  ) ENGINE = MEMORY;

  START TRANSACTION;

  -- T01 - RN02: emprestar um exemplar que já está EMPRESTADO
  SET v_erro = 0, v_msg = NULL;
  INSERT INTO emprestimo (data_emprestimo, data_devolucao_prevista, id_leitor, id_exemplar)
  VALUES (CURDATE(), CURDATE() + INTERVAL 14 DAY, 3, 4);
  INSERT INTO resultado_teste VALUES (1, 'RN02', 'Emprestar exemplar já emprestado (BC-0004)',
    'Bloquear com erro', IFNULL(v_msg, 'Empréstimo aceito'), IF(v_erro = 1, 'PASSOU', 'FALHOU'));

  -- T02 - RN06: reservar um livro que tem exemplar disponível
  SET v_erro = 0, v_msg = NULL;
  INSERT INTO reserva (id_leitor, id_livro) VALUES (2, 1);
  INSERT INTO resultado_teste VALUES (2, 'RN06', 'Reservar livro com exemplar disponível (Dom Casmurro)',
    'Bloquear com erro', IFNULL(v_msg, 'Reserva aceita'), IF(v_erro = 1, 'PASSOU', 'FALHOU'));

  -- T03 - RN04: devolução prevista anterior à data do empréstimo
  SET v_erro = 0, v_msg = NULL;
  INSERT INTO emprestimo (data_emprestimo, data_devolucao_prevista, id_leitor, id_exemplar)
  VALUES (CURDATE(), CURDATE() - INTERVAL 1 DAY, 1, 1);
  INSERT INTO resultado_teste VALUES (3, 'RN04', 'Devolução prevista antes da retirada',
    'Bloquear com erro', IFNULL(v_msg, 'Empréstimo aceito'), IF(v_erro = 1, 'PASSOU', 'FALHOU'));

  -- T04 - RN01: empréstimo para leitor não cadastrado
  SET v_erro = 0, v_msg = NULL;
  INSERT INTO emprestimo (data_emprestimo, data_devolucao_prevista, id_leitor, id_exemplar)
  VALUES (CURDATE(), CURDATE() + INTERVAL 14 DAY, 999, 1);
  INSERT INTO resultado_teste VALUES (4, 'RN01', 'Empréstimo para leitor inexistente (id 999)',
    'Bloquear com erro', IFNULL(v_msg, 'Empréstimo aceito'), IF(v_erro = 1, 'PASSOU', 'FALHOU'));

  -- T05 - RNF06: CPF duplicado
  SET v_erro = 0, v_msg = NULL;
  INSERT INTO leitor (nome, cpf) VALUES ('Leitor Duplicado', '12345678901');
  INSERT INTO resultado_teste VALUES (5, 'RNF06', 'Cadastrar leitor com CPF já existente',
    'Bloquear com erro', IFNULL(v_msg, 'Cadastro aceito'), IF(v_erro = 1, 'PASSOU', 'FALHOU'));

  -- T06 - RN08: identificar empréstimos atrasados
  SELECT COUNT(*) INTO v_num FROM vw_emprestimos_atrasados;
  INSERT INTO resultado_teste VALUES (6, 'RN08', 'Empréstimos em atraso na view',
    '1 empréstimo atrasado', CONCAT(v_num, ' empréstimo(s) atrasado(s)'), IF(v_num = 1, 'PASSOU', 'FALHOU'));

  -- T07 - RN05 + RN10: devolução de livro com fila de reserva
  SET v_erro = 0, v_msg = NULL;
  UPDATE emprestimo SET data_devolucao_real = CURDATE() WHERE id_emprestimo = 2;
  SELECT status INTO v_txt FROM exemplar WHERE id_exemplar = 3;
  INSERT INTO resultado_teste VALUES (7, 'RN05/RN10', 'Devolver A Hora da Estrela (há fila de reserva)',
    'Exemplar RESERVADO', CONCAT('Exemplar ', v_txt), IF(v_txt = 'RESERVADO', 'PASSOU', 'FALHOU'));

  -- T08 - RN10: outro leitor tenta pegar o exemplar reservado
  SET v_erro = 0, v_msg = NULL;
  INSERT INTO emprestimo (data_emprestimo, data_devolucao_prevista, id_leitor, id_exemplar)
  VALUES (CURDATE(), CURDATE() + INTERVAL 14 DAY, 1, 3);
  INSERT INTO resultado_teste VALUES (8, 'RN10', 'Leitor fora da fila pega exemplar reservado',
    'Bloquear com erro', IFNULL(v_msg, 'Empréstimo aceito'), IF(v_erro = 1, 'PASSOU', 'FALHOU'));

  -- T09 - RN07 + RN10: o 1º da fila retira o exemplar reservado
  SET v_erro = 0, v_msg = NULL;
  INSERT INTO emprestimo (data_emprestimo, data_devolucao_prevista, id_leitor, id_exemplar)
  VALUES (CURDATE(), CURDATE() + INTERVAL 14 DAY, 3, 3);
  SELECT status INTO v_txt FROM reserva WHERE id_reserva = 1;
  INSERT INTO resultado_teste VALUES (9, 'RN07/RN10', '1º da fila (Carla) retira o exemplar reservado',
    'Empréstimo aceito e reserva ATENDIDA', IF(v_erro = 1, v_msg, CONCAT('Reserva ', v_txt)),
    IF(v_erro = 0 AND v_txt = 'ATENDIDA', 'PASSOU', 'FALHOU'));

  -- T10 - RN05: devolução sem fila deixa o exemplar disponível
  SET v_erro = 0, v_msg = NULL;
  UPDATE emprestimo SET data_devolucao_real = CURDATE() WHERE id_emprestimo = 1;
  SELECT status INTO v_txt FROM exemplar WHERE id_exemplar = 4;
  INSERT INTO resultado_teste VALUES (10, 'RN05', 'Devolver Código Limpo (sem fila)',
    'Exemplar DISPONIVEL', CONCAT('Exemplar ', v_txt), IF(v_txt = 'DISPONIVEL', 'PASSOU', 'FALHOU'));

  -- T11 - RN07: novas reservas entram no fim da fila
  SET v_erro = 0, v_msg = NULL;
  INSERT INTO reserva (id_leitor, id_livro) VALUES (1, 2);
  INSERT INTO reserva (id_leitor, id_livro) VALUES (2, 2);
  SELECT GROUP_CONCAT(posicao_fila ORDER BY data_reserva, id_reserva) INTO v_txt
  FROM reserva WHERE id_livro = 2 AND status = 'AGUARDANDO';
  INSERT INTO resultado_teste VALUES (11, 'RN07', 'Duas novas reservas para A Hora da Estrela',
    'Posições 1 e 2 na fila', IF(v_erro = 1, v_msg, CONCAT('Posições ', REPLACE(v_txt, ',', ' e '))),
    IF(v_erro = 0 AND v_txt = '1,2', 'PASSOU', 'FALHOU'));

  -- T12 - RN09: histórico mantém os empréstimos devolvidos
  SELECT COUNT(*) INTO v_num FROM vw_historico_emprestimos WHERE status = 'DEVOLVIDO';
  INSERT INTO resultado_teste VALUES (12, 'RN09', 'Empréstimos devolvidos continuam no histórico',
    '2 devolvidos no histórico', CONCAT(v_num, ' devolvido(s) no histórico'), IF(v_num = 2, 'PASSOU', 'FALHOU'));

  -- Desfaz todas as alterações feitas pelos testes
  ROLLBACK;

  SELECT num AS `Nº`, regra AS `Regra`, teste AS `Teste`, esperado AS `Esperado`,
         obtido AS `Obtido`, situacao AS `Situação`
  FROM resultado_teste ORDER BY num;

  SELECT CONCAT(SUM(situacao = 'PASSOU'), ' de ', COUNT(*), ' testes passaram') AS `Resumo`
  FROM resultado_teste;
END$$

DELIMITER ;

CALL sp_testar_regras_negocio();

DROP PROCEDURE IF EXISTS sp_testar_regras_negocio;
