-- =====================================================================
-- 99_testes_triggers.sql
-- Roteiro de testes: triggers de auditoria e de regras de negócio
-- =====================================================================
-- PRÉ-REQUISITOS (nesta ordem, cada um com Alt+X):
--   1) reset do schema:  DROP SCHEMA public CASCADE; CREATE SCHEMA public;
--   2) 01_schema.sql
--   3) 02_triggers.sql
--
-- COMO EXECUTAR:
--   * O SETUP pode ser executado de uma vez (Alt+X).
--   * Os TESTES devem ser executados UM COMANDO POR VEZ (Ctrl+Enter),
--     porque vários deles devem dar erro de propósito.
--
-- REGRAS EM TESTE (definidas em 02_triggers.sql):
--   - duração máxima da reserva: 2 horas
--   - qtd_pessoas <= capacidade da sala
--   - no máximo 3 reservas ATIVAS FUTURAS por usuário
--   - conflito de horário na mesma sala: constraint EXCLUDE "sem_conflito"
-- =====================================================================


-- =====================================================================
-- SETUP
-- =====================================================================
INSERT INTO usuario (nome, email, tipo) VALUES ('Usuario Um',   'um@email.com',   'ALUNO');
INSERT INTO usuario (nome, email, tipo) VALUES ('Usuario Dois', 'dois@email.com', 'ALUNO');
INSERT INTO sala (nome, tipo, capacidade) VALUES ('Sala 101', 'SALA', 40);
-- Esperado: usuario id 1 e 2, sala id 1 (capacidade 40)


-- =====================================================================
-- TESTE 1: duração acima do limite (3h)
-- Esperado: ERRO [P0001]
--   "A duração máxima de uma reserva é de 2 horas."
-- =====================================================================
INSERT INTO reserva (usuario_id, sala_id, periodo, qtd_pessoas)
VALUES (1, 1, tstzrange('2026-12-10 08:00-03', '2026-12-10 11:00-03', '[)'), 10);


-- =====================================================================
-- TESTE 2: capacidade excedida (50 pessoas em sala de 40)
-- Esperado: ERRO [P0001]
--   "A sala comporta no máximo 40 pessoas (solicitado: 50)."
-- =====================================================================
INSERT INTO reserva (usuario_id, sala_id, periodo, qtd_pessoas)
VALUES (1, 1, tstzrange('2026-12-10 08:00-03', '2026-12-10 10:00-03', '[)'), 50);


-- =====================================================================
-- TESTES 3, 4 e 5: três reservas válidas, em dias diferentes
-- Esperado: SUCESSO (3 linhas inseridas)
-- O log_reserva deve receber 3 linhas com operacao = 'INSERT'
-- =====================================================================
INSERT INTO reserva (usuario_id, sala_id, periodo, qtd_pessoas)
VALUES (1, 1, tstzrange('2026-12-11 08:00-03', '2026-12-11 10:00-03', '[)'), 10);

INSERT INTO reserva (usuario_id, sala_id, periodo, qtd_pessoas)
VALUES (1, 1, tstzrange('2026-12-12 08:00-03', '2026-12-12 10:00-03', '[)'), 10);

INSERT INTO reserva (usuario_id, sala_id, periodo, qtd_pessoas)
VALUES (1, 1, tstzrange('2026-12-13 08:00-03', '2026-12-13 10:00-03', '[)'), 10);


-- =====================================================================
-- TESTE 6: quarta reserva ativa futura do mesmo usuário
-- Esperado: ERRO [P0001]
--   "O usuário já possui 3 reservas ativas futuras (limite: 3)."
-- =====================================================================
INSERT INTO reserva (usuario_id, sala_id, periodo, qtd_pessoas)
VALUES (1, 1, tstzrange('2026-12-14 08:00-03', '2026-12-14 10:00-03', '[)'), 10);


-- =====================================================================
-- TESTE 7: cancelamento (soft delete) da reserva de 11/12
-- A reserva é localizada pelo período, não pelo id.
-- Esperado: SUCESSO (1 linha atualizada)
-- O log_reserva deve receber 1 linha com operacao = 'CANCELAMENTO'
-- =====================================================================
UPDATE reserva
SET status = 'CANCELADA'
WHERE usuario_id = 1
  AND status = 'ATIVA'
  AND lower(periodo) = '2026-12-11 08:00-03'::timestamptz;

SELECT id, reserva_id, operacao, ocorrido_em
FROM log_reserva
ORDER BY id;
-- Esperado: 3 linhas INSERT + 1 linha CANCELAMENTO
-- (os ids podem ter "buracos": o SERIAL consome número mesmo
--  quando o INSERT falha)


-- =====================================================================
-- TESTE 8: cancelamento libera o horário
-- O EXCLUDE só considera reservas com status = 'ATIVA', então o mesmo
-- período da reserva cancelada no teste 7 pode ser reservado de novo.
-- O usuário tem agora 2 ativas futuras, então o limite de 3 não barra.
-- Esperado: SUCESSO
-- =====================================================================
INSERT INTO reserva (usuario_id, sala_id, periodo, qtd_pessoas)
VALUES (1, 1, tstzrange('2026-12-11 08:00-03', '2026-12-11 10:00-03', '[)'), 10);


-- =====================================================================
-- TESTE 9: conflito de horário (EXCLUDE)
-- Usa o usuário 2 para o trigger de limite não barrar antes.
-- O período sobrepõe a reserva ATIVA do dia 12, 08h às 10h, sala 1.
-- Esperado: ERRO [23P01]
--   "conflicting key value violates exclusion constraint "sem_conflito""
--   (o campo Detalhe mostra a reserva existente que conflita)
-- =====================================================================
INSERT INTO reserva (usuario_id, sala_id, periodo, qtd_pessoas)
VALUES (2, 1, tstzrange('2026-12-12 09:00-03', '2026-12-12 11:00-03', '[)'), 10);


-- =====================================================================
-- TESTE 10: reservas adjacentes não conflitam (limites '[)')
-- Começa exatamente quando a reserva de 08h às 10h termina.
-- Esperado: SUCESSO
-- =====================================================================
INSERT INTO reserva (usuario_id, sala_id, periodo, qtd_pessoas)
VALUES (2, 1, tstzrange('2026-12-12 10:00-03', '2026-12-12 12:00-03', '[)'), 10);


-- =====================================================================
-- CONFERÊNCIA FINAL
-- =====================================================================
SELECT id, usuario_id, periodo, status
FROM reserva
ORDER BY id;
-- Esperado: 1 reserva CANCELADA (dia 11, a original) e as demais ATIVAS

SELECT operacao, count(*) AS qtd
FROM log_reserva
GROUP BY operacao
ORDER BY operacao;
-- Esperado: CANCELAMENTO = 1 ; INSERT = 5
-- (INSERTs bem-sucedidos: testes 3, 4, 5, 8 e 10)