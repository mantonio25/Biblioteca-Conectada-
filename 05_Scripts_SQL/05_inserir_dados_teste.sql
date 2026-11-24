-- =====================================================================
--  BIBLIOTECA CONECTADA - Script 05: Dados de teste
--  SGBD: MySQL 8.0+
--  Insere editoras, autores, livros, exemplares, leitores, usuários, empréstimos e uma reserva.
--  Pré-requisito: 02, 03 e 04 (os triggers precisam existir para atualizar a situação dos exemplares).
-- =====================================================================

USE biblioteca_conectada;

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
