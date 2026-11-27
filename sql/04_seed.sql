-- =====================================================================
-- 04_seed.sql — Dados de teste
--
-- PARTE 1 : dados BASE
--   300 usuários, 20 salas (14 salas + 6 laboratórios), 8 recursos e
--   os recursos de cada sala.
-- Rodar:  psql -U postgres -h localhost -d reservas -f sql/04_seed.sql
-- (depois do 01_schema.sql)
-- =====================================================================

SELECT setseed(0.42);

-- ---------------------------------------------------------------------
-- Usuários: 240 alunos, 45 professores, 15 servidores
-- O e-mail usa o número do usuário para garantir que seja único (UNIQUE).
-- ---------------------------------------------------------------------
INSERT INTO usuario (nome, email, tipo)
SELECT
  (ARRAY['Ana','Bruno','Carla','Daniel','Eduarda','Felipe','Gabriela','Hugo',
         'Isabela','João','Larissa','Lucas','Mariana','Nicolas','Olívia','Pedro',
         'Rafaela','Samuel','Tatiane','Vitor'])[1 + floor(random() * 20)::int]
  || ' ' ||
  (ARRAY['Silva','Souza','Oliveira','Santos','Lima','Pereira','Costa','Almeida',
         'Ferreira','Araújo','Barbosa','Cavalcanti','Rocha','Medeiros','Nóbrega'])[1 + floor(random() * 15)::int],
  'usuario' || g || '@ufpb.br',
  (CASE WHEN g <= 240 THEN 'ALUNO'
        WHEN g <= 285 THEN 'PROFESSOR'
        ELSE 'SERVIDOR' END)::tipo_usuario
FROM generate_series(1, 300) AS g;

-- ---------------------------------------------------------------------
-- Salas: Sala 101–107 (bloco A) e 201–207 (bloco B)
-- ---------------------------------------------------------------------
INSERT INTO sala (nome, tipo, capacidade, localizacao)
SELECT
  'Sala ' || (100 * (1 + (g - 1) / 7) + (g - 1) % 7 + 1),
  'SALA'::tipo_sala,
  (ARRAY[30, 40, 45, 50, 60])[1 + floor(random() * 5)::int],
  'Bloco ' || chr(65 + (g - 1) / 7) || ', ' || (1 + (g - 1) % 2) || 'º andar'
FROM generate_series(1, 14) AS g;

-- Laboratórios 01–06
INSERT INTO sala (nome, tipo, capacidade, localizacao)
SELECT
  'Laboratório ' || lpad(g::text, 2, '0'),
  'LABORATORIO'::tipo_sala,
  (ARRAY[20, 25, 30, 40])[1 + floor(random() * 4)::int],
  'Bloco de Informática, ' || (1 + (g - 1) / 3) || 'º andar'
FROM generate_series(1, 6) AS g;

-- ---------------------------------------------------------------------
-- Recursos
-- ---------------------------------------------------------------------
INSERT INTO recurso (nome, descricao) VALUES
  ('Projetor',              'Projetor multimídia com entrada HDMI'),
  ('Computador',            'Desktop com Linux e Windows'),
  ('Ar-condicionado',       'Split 18.000 BTUs'),
  ('Quadro branco',         'Quadro para pincel'),
  ('Lousa digital',         'Tela interativa touch de 75"'),
  ('Caixa de som',          'Som ambiente com microfone sem fio'),
  ('Webcam',                'Câmera para aulas híbridas'),
  ('Bancada de eletrônica', 'Bancada com osciloscópio e fonte');

-- ---------------------------------------------------------------------
-- Recursos de cada sala (tabela associativa sala_recurso)
-- ---------------------------------------------------------------------

-- Toda sala tem projetor, quadro branco e 1 ou 2 aparelhos de ar
INSERT INTO sala_recurso (sala_id, recurso_id, quantidade)
SELECT s.id, r.id,
       CASE WHEN r.nome = 'Ar-condicionado' THEN 1 + floor(random() * 2)::int ELSE 1 END
FROM sala s
JOIN recurso r ON r.nome IN ('Projetor', 'Ar-condicionado', 'Quadro branco');

-- Laboratórios: um computador por lugar
INSERT INTO sala_recurso (sala_id, recurso_id, quantidade)
SELECT s.id, r.id, s.capacidade
FROM sala s
JOIN recurso r ON r.nome = 'Computador'
WHERE s.tipo = 'LABORATORIO';

-- Extras sorteados (~35% das combinações sala × recurso extra)
INSERT INTO sala_recurso (sala_id, recurso_id, quantidade)
SELECT s.id, r.id, 1
FROM sala s
JOIN recurso r ON r.nome IN ('Lousa digital', 'Caixa de som', 'Webcam', 'Bancada de eletrônica')
WHERE random() < 0.35;

-- ---------------------------------------------------------------------
-- PARTE 2 — RESERVAS (a fazer)
-- Aqui entra o INSERT das 10 mil+ reservas com generate_series.
-- ---------------------------------------------------------------------

-- Conferência
SELECT 'usuarios' AS tabela, count(*) FROM usuario
UNION ALL SELECT 'salas', count(*) FROM sala
UNION ALL SELECT 'recursos', count(*) FROM recurso
UNION ALL SELECT 'sala_recurso', count(*) FROM sala_recurso;
