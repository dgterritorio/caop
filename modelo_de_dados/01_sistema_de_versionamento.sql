-- Criar função trigger para actualizar os campos de versionamento e efectuar backup de linhas alteradas ou removidas
CREATE OR REPLACE FUNCTION "vrs_table_update"()
RETURNS trigger AS
$$
BEGIN

    -- actualiza campos de versionamento da tabela original
    IF TG_OP IN ('UPDATE','INSERT') THEN
        NEW."inicio_objecto" = now();
        NEW."utilizador" = user;
    end IF;

    -- copiar linha para a tabela de backup
    IF TG_OP IN ('UPDATE','DELETE') THEN
        EXECUTE 'INSERT INTO versioning.' || quote_ident(TG_TABLE_NAME || '_bk') ||
                ' SELECT ($1).*;'
        USING OLD;
    end IF;

    IF TG_OP IN ('UPDATE','INSERT') THEN
        RETURN NEW;
    ELSE
        RETURN OLD;
    end IF;
end;
$$
LANGUAGE 'plpgsql';

-- Cria funcao trigger para registar o utilizador, a hora e a operaçao que levou ao backup
CREATE OR REPLACE FUNCTION "vsr_bk_table_update"()
RETURNS trigger AS
$$
BEGIN
    -- actualizar os campos de versioningna tabela de backups
        NEW.fim_objeto = now();
        NEW.fim_objecto_utilizador = user;
		NEW.fim_objecto_operacao = user; -- TODO: Falta implementar
        RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

-- Cria função para adicionar os campos de versionamento, criar tabela de backup e activa triggers
CREATE OR REPLACE FUNCTION "vsr_add_versioning_to"(_t regclass)
  RETURNS boolean AS
$body$
DECLARE
	_schema text;
	_table text;
	bk_table_name text;
BEGIN
	-- Prepara nomes a usar em indices e triggers
	IF _t::text LIKE '%.%' THEN
		_schema := regexp_replace (split_part(_t::text, '.', 1),'"','','g');
		_table := regexp_replace (split_part(_t::text, '.', 2),'"','','g');
	ELSE
		_schema := 'public';
		_table := regexp_replace(_t::text,'"','','g');
	END IF;

	-- Adiciona campos de versionamento na tabela original
	EXECUTE 'ALTER TABLE ' || _t ||
		' ADD COLUMN "inicio_objecto" timestamp,
		  ADD COLUMN "utilizador" character varying(40),
          ADD COLUMN "motivo" character varying(255)';

   -- adicionar indice na coluna inicio objeto para optimizar a resposta de queries

	EXECUTE 'CREATE INDEX ' || quote_ident(_table || '_time_idx') ||
		' ON ' || _t || ' (inicio_objecto)';

	-- Preenche colunas de versionamento caso a tabela já contenha dados
	EXECUTE 'UPDATE ' || _t || ' SET inicio_objecto = now(), utilizador = user';

	-- Cria schema e tabela para guardar os backups
	EXECUTE 'CREATE SCHEMA IF NOT EXISTS backup';

	bk_table_name := 'versioning.' || quote_ident(_table || '_bk');

	EXECUTE 'CREATE TABLE ' || bk_table_name ||
		' (like ' || _t || ')';

	EXECUTE	'ALTER TABLE ' || bk_table_name ||
		' ADD COLUMN "bk_id" serial primary key,
		  ADD COLUMN "fim_objeto" timestamp,
		  ADD COLUMN "fim_objecto_utilizador" character varying(40),
		  ADD COLUMN "fim_objecto_operacao" character varying(40)'
		  ; -- confirmar se queremos isto, acho que nao fara sentido

	EXECUTE	'CREATE INDEX ' || quote_ident(_table || '_bk_idx') ||
		' ON ' || bk_table_name || ' (inicio_objecto, fim_objeto)';

	-- cria trigger para actualizar campos de versionamento na tabela original
	EXECUTE 'CREATE TRIGGER ' || quote_ident(_table || '_vrs_trigger') || ' BEFORE INSERT OR DELETE OR UPDATE ON ' || _t ||
		' FOR EACH ROW EXECUTE PROCEDURE "vrs_table_update"()';

	-- cria trigger para actualizar campos de versionamento na tabela backup
	EXECUTE 'CREATE TRIGGER ' || quote_ident(_table || '_bk_trigger') || ' BEFORE INSERT ON ' || bk_table_name ||
		' FOR EACH ROW EXECUTE PROCEDURE "vsr_bk_table_update"()';
	RETURN true;
END
$body$ LANGUAGE plpgsql;

-- função para remover o versioning de uma tabela
-- elimina todos os campos de versionamento, triggers e tabela de backup
CREATE OR REPLACE FUNCTION "vsr_remove_versioning_from"(_t regclass)
  RETURNS boolean AS
$body$
DECLARE
	_schema text;
	_table text;
	_table_bk text;
BEGIN
	-- Prepare names to use in index and trigger names
	IF _t::text LIKE '%.%' THEN
		_schema := regexp_replace (split_part(_t::text, '.', 1),'"','','g');
		_table := regexp_replace (split_part(_t::text, '.', 2),'"','','g');
	ELSE
		_schema := 'public';
		_table := regexp_replace(_t::text,'"','','g');
	END IF;

	-- compose backup table name
	_table_bk := 'versioning.' || quote_ident(_table || '_bk');

	-- Remove versioning fields from table
	EXECUTE 'ALTER TABLE ' || _t ||
		' DROP COLUMN IF EXISTS "inicio_objecto",
		  DROP COLUMN IF EXISTS "utilizador",
		  DROP COLUMN IF EXISTS "motivo"';

	-- Remove versioning trigger from table
	EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident(_table || '_vrs_trigger') || ' ON ' || _t;

	-- create table to store backups
	EXECUTE 'DROP TABLE IF EXISTS ' || _table_bk || ' CASCADE';

	RETURN true;
END
$body$ LANGUAGE plpgsql;

-- Function to visualize tables in prior state in time
CREATE OR REPLACE FUNCTION "vsr_table_at_time"(_t anyelement, _d timestamp)
RETURNS SETOF anyelement AS
$$
DECLARE
	_tfn text;
	_schema text;
	_table text;
	_table_bk text;
	_col text;
BEGIN
	-- Separate schema and table names
	_tfn := pg_typeof(_t)::text;
	IF _tfn LIKE '%.%' THEN
		_schema := regexp_replace (split_part(_tfn, '.', 1),'"','','g');
		_table := regexp_replace (split_part(_tfn, '.', 2),'"','','g');
	ELSE
		_schema := 'public';
		_table := regexp_replace(_tfn,'"','','g');
	END IF;

	-- compose backup table name
	_table_bk := 'versioning.' || quote_ident(_table || '_bk');

	-- getting columns from table
	_col := (SELECT array_to_string(ARRAY(SELECT 'o' || '.' || c.column_name
			FROM information_schema.columns As c
			WHERE table_schema = _schema and table_name = _table), ', '));

	RETURN QUERY EXECUTE format(
	'WITH g as
		(
		SELECT *
		  FROM %s AS f
		  WHERE f.inicio_objecto <= $1
		UNION ALL
		SELECT %s
		  FROM %s AS o
		  WHERE o.inicio_objecto <= $1 AND o.fim_objeto > $1
		)
	SELECT DISTINCT ON (identificador) *
	  FROM g
	  ORDER BY identificador, inicio_objecto DESC', pg_typeof(_t), _col, _table_bk)
	  USING _d;
END
$$
LANGUAGE plpgsql;

-- Aplicar versionamento em todas a tabelas do schema base
SELECT vsr_add_versioning_to('"base".nuts1');
SELECT vsr_add_versioning_to('"base".nuts2');
SELECT vsr_add_versioning_to('"base".nuts3');
SELECT vsr_add_versioning_to('"base".distrito_ilha');
SELECT vsr_add_versioning_to('"base".municipio');
SELECT vsr_add_versioning_to('"base".freguesia');
SELECT vsr_add_versioning_to('"base".outras_entidades');
SELECT vsr_add_versioning_to('"base".trocos');
SELECT vsr_add_versioning_to('"base".fontes');
SELECT vsr_add_versioning_to('"base".centroide_ea');



/*

EXEMPLOS DE USO

-- Adicionar versionamento a uma tabela
-- Isto irá adicionar os campos necessários, criar tabelas de versionamento e
-- Activar o triggers

SELECT vsr_add_versioning_to('"base".nuts1');

-- Remove versioning from table
-- This will remove versioning fields, backup table and related triggers

SELECT vsr_remove_versioning_from('"base".nuts1');

-- See table content at certain time
SELECT * from vsr_table_at_time (NULL::"base".nuts1, '2014-04-19 18:26:57');

-- See specific feature at certain time
SELECT * from vsr_table_at_time (NULL::"base".nuts1, '2014-04-19 18:26:57')
WHERE identificador = 298b0ff8-71a5-11ee-a363-0383b049fe76;

*/
