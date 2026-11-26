-- =====================================================
-- TRIGGER A: AUDITORIA
-- =====================================================
CREATE OR REPLACE FUNCTION fn_auditoria_reserva()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO log_reserva (reserva_id, operacao, dados_antigos, dados_novos)
    VALUES (NEW.id, 'INSERT', NULL, to_jsonb(NEW));

  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO log_reserva (reserva_id, operacao, dados_antigos, dados_novos)
    VALUES (
      NEW.id,
      CASE WHEN OLD.status = 'ATIVA' AND NEW.status = 'CANCELADA'
           THEN 'CANCELAMENTO' ELSE 'UPDATE' END,
      to_jsonb(OLD),
      to_jsonb(NEW)
    );
  END IF;

  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_auditoria_reserva
AFTER INSERT OR UPDATE ON reserva
FOR EACH ROW EXECUTE FUNCTION fn_auditoria_reserva();

-- =====================================================
-- TRIGGER B: REGRAS DE NEGÓCIO
-- =====================================================
CREATE OR REPLACE FUNCTION fn_valida_reserva()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_capacidade INT;
  v_qtd_ativas INT;
BEGIN
  -- Reservas canceladas ou concluídas não precisam de validação
  IF NEW.status <> 'ATIVA' THEN
    RETURN NEW;
  END IF;

  -- Regra 1: duração máxima de 4 horas
  IF upper(NEW.periodo) - lower(NEW.periodo) > INTERVAL '2 hours' THEN
    RAISE EXCEPTION 'A duração máxima de uma reserva é de 2 horas.';
  END IF;

  -- Regra 2: capacidade da sala
  SELECT capacidade INTO v_capacidade
  FROM sala
  WHERE id = NEW.sala_id;

  IF NEW.qtd_pessoas > v_capacidade THEN
    RAISE EXCEPTION 'A sala comporta no máximo % pessoas (solicitado: %).',
      v_capacidade, NEW.qtd_pessoas;
  END IF;

  -- Regra 3: no máximo 3 reservas ativas futuras por usuário
  IF lower(NEW.periodo) > now() THEN
    PERFORM pg_advisory_xact_lock(NEW.usuario_id);

    SELECT count(*) INTO v_qtd_ativas
    FROM reserva
    WHERE usuario_id = NEW.usuario_id
      AND status = 'ATIVA'
      AND lower(periodo) > now()
      AND id IS DISTINCT FROM NEW.id;

    IF v_qtd_ativas >= 3 THEN
      RAISE EXCEPTION 'O usuário já possui % reservas ativas futuras (limite: 3).',
        v_qtd_ativas;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_valida_reserva
BEFORE INSERT OR UPDATE ON reserva
FOR EACH ROW EXECUTE FUNCTION fn_valida_reserva();