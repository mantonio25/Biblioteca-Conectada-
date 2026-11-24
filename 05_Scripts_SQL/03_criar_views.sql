-- =====================================================================
--  BIBLIOTECA CONECTADA - Script 03: Views de consulta
--  SGBD: MySQL 8.0+
--  Cria as 5 views (RF09, RF10, RF11, RF12, RF13).
--  Pré-requisito: 02_criar_tabelas.sql
-- =====================================================================

USE biblioteca_conectada;

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
