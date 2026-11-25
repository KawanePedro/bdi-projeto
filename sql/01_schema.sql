CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TYPE status_reserva AS ENUM ('ATIVA', 'CANCELADA', 'CONCLUIDA');
CREATE TYPE tipo_usuario AS ENUM ('ALUNO', 'PROFESSOR', 'SERVIDOR');
CREATE TYPE tipo_sala AS ENUM ('SALA', 'LABORATORIO');

CREATE TABLE usuario (
  id SERIAL PRIMARY KEY,
  nome TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  tipo tipo_usuario NOT NULL
);

CREATE TABLE sala (
  id SERIAL PRIMARY KEY,
  nome TEXT NOT NULL UNIQUE,
  tipo tipo_sala NOT NULL,
  capacidade INT NOT NULL CHECK (capacidade > 0),
  localizacao TEXT
);

CREATE TABLE recurso (
  id SERIAL PRIMARY KEY,
  nome TEXT NOT NULL UNIQUE,
  descricao TEXT
);

CREATE TABLE sala_recurso (
  sala_id INT REFERENCES sala(id) ON DELETE CASCADE,
  recurso_id INT REFERENCES recurso(id) ON DELETE RESTRICT,
  quantidade INT NOT NULL DEFAULT 1 CHECK (quantidade > 0),
  PRIMARY KEY (sala_id, recurso_id)
);

CREATE TABLE reserva (
  id SERIAL PRIMARY KEY,
  usuario_id INT NOT NULL REFERENCES usuario(id) ON DELETE RESTRICT,
  sala_id INT NOT NULL REFERENCES sala(id) ON DELETE RESTRICT,
  periodo TSTZRANGE NOT NULL,
  qtd_pessoas INT NOT NULL CHECK (qtd_pessoas > 0),
  status status_reserva NOT NULL DEFAULT 'ATIVA',
  criada_em TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (NOT isempty(periodo) AND lower_inf(periodo) = false AND upper_inf(periodo) = false),
  CONSTRAINT sem_conflito EXCLUDE USING gist
    (sala_id WITH =, periodo WITH &&) WHERE (status = 'ATIVA')
);

CREATE TABLE log_reserva (
  id BIGSERIAL PRIMARY KEY,
  reserva_id INT NOT NULL, -- sem FK pois o log sobrevive a delete
  operacao TEXT NOT NULL,
  dados_antigos JSONB,
  dados_novos JSONB,
  usuario_db TEXT NOT NULL DEFAULT current_user,
  ocorrido_em TIMESTAMPTZ NOT NULL DEFAULT now()
);