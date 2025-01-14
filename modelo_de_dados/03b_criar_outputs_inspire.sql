-- Outputs para Inspire baseado em CAOP
-- Manter toda a definição da CAOP
-- actualização dos atributos

-- query para transformar os trocos em poligonos
-- e guardar numa tabela temporária
DROP MATERIALIZED VIEW IF EXISTS master.inspire_admin_boundaries_cont;

CREATE MATERIALIZED VIEW master.inspire_admin_boundaries_cont AS
SELECT 
	row_number() over (order by t.inicio_objecto) as id,
	'http://id.igeo.pt/so/AU/AdministrativeBoundaries/' || t.identificador || '/' || to_char(t.inicio_objecto, 'YYYYMMDD') AS "inspireId",
	'PT' AS country,
	nla.nome_en AS "nationalLevel",
	t.inicio_objecto::timestamp AS "beginLifespanVersion",
	NULL::timestamp AS "endLifespanVersion", -- A definir
	'agreed' AS "legalStatus",
	'notEdgeMatched' AS "technicalStatus",
	ARRAY[CASE WHEN char_length(t.ea_esquerda) > 5 THEN 'PT1' || t.ea_esquerda END,
		  CASE WHEN char_length(t.ea_direita) > 5 THEN 'PT1' || t.ea_direita END] AS "admUnit",
	t.geometria::geometry(linestring, 3763) AS geometry
FROM vsr_table_at_time (NULL::base.cont_troco, now()::timestamp) AS t -- substituir now por uma data ou uma versão
	JOIN dominios.nivel_limite_administrativo AS nla ON t.nivel_limite_admin = nla.identificador;

CREATE UNIQUE INDEX ON master.inspire_admin_boundaries_cont(id);
CREATE INDEX ON master.inspire_admin_boundaries_cont USING gist(geometry);

DROP MATERIALIZED VIEW IF EXISTS master.inspire_admin_units_5thorder_cont;
CREATE MATERIALIZED VIEW master.inspire_admin_units_5thorder_cont AS
SELECT DISTINCT ON (dtmnfr)
row_number() over (order by dtmnfr, t.inicio_objecto) as id,
'http://id.igeo.pt/so/AU/AdministrativeUnits/' || 'PT1' || dtmnfr || '/' || to_char(t.inicio_objecto, 'YYYYMMDD') AS "inspireId",
'PT' AS country,
t.inicio_objecto::timestamp AS "beginLifespanVersion", -- A definir
NULL::timestamp AS "endLifespanVersion", -- A definir
freguesia AS name,
'PT1' || dtmnfr AS "nationalCode",
'5thOrder' AS "nationalLevel",
'Freguesia' AS "nationalLevelName",
sa.nome AS "residenceOfAutorithy",
'PT1' || LEFT(dtmnfr,4) AS "upperLevelUnit",
f.geometria::geometry(multipolygon,3763) AS geometry
FROM master.cont_freguesias AS f
	LEFT JOIN vsr_table_at_time (NULL::base.cont_troco, now()::timestamp) AS t ON f.dtmnfr IN (t.ea_direita, t.ea_esquerda)
	LEFT JOIN base.sede_administrativa AS sa ON st_intersects(f.geometria, st_transform(sa.geometria, 3763)) AND sa.tipo_sede_administrativa = '5'
ORDER BY dtmnfr, t.inicio_objecto DESC;

CREATE UNIQUE INDEX ON master.inspire_admin_units_5thorder_cont(id);
CREATE INDEX ON master.inspire_admin_units_5thorder_cont USING gist(geometry);

DROP MATERIALIZED VIEW IF EXISTS master.inspire_admin_units_4thorder_cont;
CREATE MATERIALIZED VIEW master.inspire_admin_units_4thorder_cont AS
SELECT DISTINCT ON (dtmn)
row_number() over (order by dtmn, t.inicio_objecto) as id,
'http://id.igeo.pt/so/AU/AdministrativeUnits/' || 'PT1' || dtmn || '/' || to_char(t.inicio_objecto, 'YYYYMMDD') AS "inspireId",
'PT' AS country,
t.inicio_objecto::timestamp AS "beginLifespanVersion", -- A definir
NULL::timestamp AS "endLifespanVersion", -- A definir
municipio AS name,
'PT1' || dtmn AS "nationalCode",
'4thOrder' AS "nationalLevel",
'Município' AS "nationalLevelName",
sa.nome AS "residenceOfAutorithy",
'PT1' || LEFT(dtmn,2) AS "upperLevelUnit",
m.geometria::geometry(multipolygon, 3763) AS geometry
FROM master.cont_municipios AS m
	LEFT JOIN vsr_table_at_time (NULL::base.cont_troco, now()::timestamp) as t ON m.dtmn IN (LEFT(t.ea_direita,4), LEFT(t.ea_esquerda,4))
	LEFT JOIN base.sede_administrativa AS sa ON st_intersects(m.geometria, st_transform(sa.geometria, 3763)) AND sa.tipo_sede_administrativa = '4'
ORDER BY dtmn, t.inicio_objecto DESC; 

CREATE UNIQUE INDEX ON master.inspire_admin_units_4thorder_cont(id);
CREATE INDEX ON master.inspire_admin_units_4thorder_cont USING gist(geometry);

DROP MATERIALIZED VIEW IF EXISTS master.inspire_admin_units_3rdorder_cont;
CREATE MATERIALIZED VIEW master.inspire_admin_units_3rdorder_cont AS
SELECT DISTINCT ON (dt)
row_number() over (order by dt, t.inicio_objecto) as id,
'http://id.igeo.pt/so/AU/AdministrativeUnits/' || 'PT1' || dt || '/' || to_char(t.inicio_objecto, 'YYYYMMDD') AS "inspireId",
'PT' AS country,
t.inicio_objecto::timestamp AS "beginLifespanVersion", -- A definir
NULL::timestamp AS "endLifespanVersion", -- A definir
distrito AS name,
'PT1' || dt AS "nationalCode",
'3thOrder' AS "nationalLevel",
'Distrito' AS "nationalLevelName",
sa.nome AS "residenceOfAutorithy",
'PT1' AS "upperLevelUnit",
d.geometria AS geometry
FROM master.cont_distritos AS d
	LEFT JOIN base.cont_troco AS t ON d.dt IN (LEFT(t.ea_direita,2), LEFT(t.ea_esquerda,2))
	LEFT JOIN base.sede_administrativa AS sa ON st_intersects(d.geometria, st_transform(sa.geometria, 3763)) AND sa.tipo_sede_administrativa = '3'
ORDER BY dt, t.inicio_objecto DESC;

CREATE UNIQUE INDEX ON master.inspire_admin_units_3rdorder_cont(id);
CREATE INDEX ON master.inspire_admin_units_3rdorder_cont USING gist(geometry);

GRANT ALL ON ALL TABLES IN SCHEMA master TO administrador;
GRANT SELECT ON ALL TABLES IN SCHEMA master TO editor, visualizador;

--  O mesmo código convertido em função que permita criar as camadas inspire para as diferrentes regioes

CREATE OR REPLACE FUNCTION public.gerar_outputs_inspire(output_schema text DEFAULT 'master'::regnamespace, prefixo TEXT DEFAULT 'cont', data_hora timestamp DEFAULT now()::timestamp )
-- Função para gerar camadas inspire baseadas nos outputs da CAOP guardados no schema escolhido
-- ATENÇÃO: NECESSITA DE PERMISSÕES DE ADMINISTRADOR PARA CORRER POIS CRIA SCHEMAS e DÁ PERMISSÕES.
-- parametros:
-- - output_schema (TEXT) - nome do schema com os outputs CAOP, e onde serão guardados as tabelas default 'master'
-- - prefixo (TEXT) - prefixo que permite separar entre o continente e as ilhas, valores possiveis são ('cont', 'ram','raa_oci','raa_cen_ori'), default 'cont'
-- - data_hora (TIMESTAMP) , permite definir um dia e hora para criar um output baseado em dados passados, default hora actual
RETURNS Boolean AS
$body$
DECLARE
	epsg TEXT;
BEGIN
	-- Determinar o código EPGS baseado no prefixo usado ao chamar a função
	CASE
		WHEN prefixo = 'cont' THEN	epsg := '3763';
		WHEN prefixo = 'ram' THEN	epsg := '5016';
		WHEN prefixo = 'raa_oci' THEN	epsg := '5014';
		WHEN prefixo = 'raa_cen_ori' THEN	epsg := '5015';
		ELSE
			RAISE EXCEPTION 'Prefixo inválido!';
			RETURN FALSE;
	END CASE;

EXECUTE FORMAT (
	'DROP MATERIALIZED VIEW IF EXISTS %1$I.inspire_admin_boundaries_%2$s;
	
	CREATE MATERIALIZED VIEW  %1$I.inspire_admin_boundaries_%2$s AS
	SELECT 
		row_number() over (order by t.inicio_objecto) as id,
		''http://id.igeo.pt/so/AU/AdministrativeBoundaries/'' || t.identificador || ''/'' || to_char(t.inicio_objecto, ''YYYYMMDD'') AS "inspireId",
		''PT'' AS country,
		nla.nome_en AS "nationalLevel",
		t.inicio_objecto::timestamp AS "beginLifespanVersion",
		NULL::timestamp AS "endLifespanVersion", -- A definir
		''agreed'' AS "legalStatus",
		''notEdgeMatched'' AS "technicalStatus",
		ARRAY[CASE WHEN char_length(t.ea_esquerda) > 5 THEN ''PT1'' || t.ea_esquerda END,
			  CASE WHEN char_length(t.ea_direita) > 5 THEN ''PT1'' || t.ea_direita END] AS "admUnit",
		t.geometria::geometry(linestring, %4$s) AS geometry
	FROM vsr_table_at_time (NULL::base.%2$s_troco,  %3$L::timestamp) AS t
		JOIN dominios.nivel_limite_administrativo AS nla ON t.nivel_limite_admin = nla.identificador;
	
	CREATE UNIQUE INDEX ON %1$I.inspire_admin_boundaries_%2$s(id);
	CREATE INDEX ON %1$I.inspire_admin_boundaries_%2$s USING gist(geometry);
	
	DROP MATERIALIZED VIEW IF EXISTS %1$I.inspire_admin_units_5thorder_%2$s;
	CREATE MATERIALIZED VIEW %1$I.inspire_admin_units_5thorder_%2$s AS
	SELECT DISTINCT ON (dtmnfr)
	row_number() over (order by dtmnfr, t.inicio_objecto) as id,
	''http://id.igeo.pt/so/AU/AdministrativeUnits/'' || ''PT1'' || dtmnfr || ''/'' || to_char(t.inicio_objecto, ''YYYYMMDD'') AS "inspireId",
	''PT'' AS country,
	t.inicio_objecto::timestamp AS "beginLifespanVersion", -- A definir
	NULL::timestamp AS "endLifespanVersion", -- A definir
	freguesia AS name,
	''PT1'' || dtmnfr AS "nationalCode",
	''5thOrder'' AS "nationalLevel",
	''Freguesia'' AS "nationalLevelName",
	sa.nome AS "residenceOfAutorithy",
	''PT1'' || LEFT(dtmnfr,4) AS "upperLevelUnit",
	f.geometria::geometry(multipolygon,%4$s) AS geometry
	FROM %1$I.%2$s_freguesias AS f
		LEFT JOIN vsr_table_at_time (NULL::base.%2$s_troco,  %3$L::timestamp) AS t ON f.dtmnfr IN (t.ea_direita, t.ea_esquerda)
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(f.geometria, st_transform(sa.geometria, %4$s)) AND sa.tipo_sede_administrativa = ''5''
	ORDER BY dtmnfr, t.inicio_objecto DESC;
	
	CREATE UNIQUE INDEX ON %1$I.inspire_admin_units_5thorder_%2$s(id);
	CREATE INDEX ON %1$I.inspire_admin_units_5thorder_%2$s USING gist(geometry);
	
	DROP MATERIALIZED VIEW IF EXISTS %1$I.inspire_admin_units_4thorder_%2$s;
	CREATE MATERIALIZED VIEW %1$I.inspire_admin_units_4thorder_%2$s AS
	SELECT DISTINCT ON (dtmn)
	row_number() over (order by dtmn, t.inicio_objecto) as id,
	''http://id.igeo.pt/so/AU/AdministrativeUnits/'' || ''PT1'' || dtmn || ''/'' || to_char(t.inicio_objecto, ''YYYYMMDD'') AS "inspireId",
	''PT'' AS country,
	t.inicio_objecto::timestamp AS "beginLifespanVersion", -- A definir
	NULL::timestamp AS "endLifespanVersion", -- A definir
	municipio AS name,
	''PT1'' || dtmn AS "nationalCode",
	''4thOrder'' AS "nationalLevel",
	''Município'' AS "nationalLevelName",
	sa.nome AS "residenceOfAutorithy",
	''PT1'' || LEFT(dtmn,2) AS "upperLevelUnit",
	m.geometria::geometry(multipolygon, %4$s) AS geometry
	FROM %1$I.%2$s_municipios AS m
		LEFT JOIN vsr_table_at_time (NULL::base.%2$s_troco,  %3$L::timestamp) as t ON m.dtmn IN (LEFT(t.ea_direita,4), LEFT(t.ea_esquerda,4))
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(m.geometria, st_transform(sa.geometria, %4$s)) AND sa.tipo_sede_administrativa = ''4''
	ORDER BY dtmn, t.inicio_objecto DESC; 
	
	CREATE UNIQUE INDEX ON %1$I.inspire_admin_units_4thorder_%2$s(id);
	CREATE INDEX ON %1$I.inspire_admin_units_4thorder_%2$s USING gist(geometry);
	
	DROP MATERIALIZED VIEW IF EXISTS %1$I.inspire_admin_units_3rdorder_%2$s;
	CREATE MATERIALIZED VIEW %1$I.inspire_admin_units_3rdorder_%2$s AS
	SELECT DISTINCT ON (dt)
	row_number() over (order by dt, t.inicio_objecto) as id,
	''http://id.igeo.pt/so/AU/AdministrativeUnits/'' || ''PT1'' || dt || ''/'' || to_char(t.inicio_objecto, ''YYYYMMDD'') AS "inspireId",
	''PT'' AS country,
	t.inicio_objecto::timestamp AS "beginLifespanVersion", -- A definir
	NULL::timestamp AS "endLifespanVersion", -- A definir
	distrito AS name,
	''PT1'' || dt AS "nationalCode",
	''3thOrder'' AS "nationalLevel",
	''Distrito'' AS "nationalLevelName",
	sa.nome AS "residenceOfAutorithy",
	''PT1'' AS "upperLevelUnit",
	d.geometria AS geometry
	FROM %1$I.%2$s_distritos AS d
		LEFT JOIN base.%2$s_troco AS t ON d.dt IN (LEFT(t.ea_direita,2), LEFT(t.ea_esquerda,2))
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(d.geometria, st_transform(sa.geometria, %4$s)) AND sa.tipo_sede_administrativa = ''3''
	ORDER BY dt, t.inicio_objecto DESC;
	
	CREATE UNIQUE INDEX ON %1$I.inspire_admin_units_3rdorder_%2$s(id);
	CREATE INDEX ON %1$I.inspire_admin_units_3rdorder_%2$s USING gist(geometry);
	
	GRANT ALL ON ALL TABLES IN SCHEMA %1$I TO administrador;
	GRANT SELECT ON ALL TABLES IN SCHEMA %1$I TO editor, visualizador;'
, output_schema, prefixo, data_hora, epsg);

	RETURN TRUE;
END;
$body$
LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION public.gerar_outputs_inspire(output_schema text DEFAULT 'master'::regnamespace, prefixo TEXT DEFAULT 'cont', output_versao TEXT DEFAULT '')
-- Função para gerar camadas inspire baseadas nos outputs da CAOP guardados no schema escolhido
-- ATENÇÃO: NECESSITA DE PERMISSÕES DE ADMINISTRADOR PARA CORRER POIS CRIA SCHEMAS e DÁ PERMISSÕES.
-- parametros:
-- - output_schema (TEXT) - nome do schema com os outputs CAOP, e onde serão guardados as tabelas default 'master'
-- - prefixo (TEXT) - prefixo que permite separar entre o continente e as ilhas, valores possiveis são ('cont', 'ram','raa_oci','raa_cen_ori'), default 'cont'
-- - output_versao (TEXT) , número de uma versão existente na tabela versioning.versao
RETURNS Boolean AS
$body$
DECLARE 
	data_hora timestamp;
BEGIN
	data_hora := (SELECT v.data_hora FROM "versioning".versoes AS v WHERE v.versao ILIKE output_versao );

	CASE WHEN data_hora IS NULL THEN
		RAISE EXCEPTION 'Versão (%) não foi encontrada.', output_versao;
		RETURN FALSE;
	ELSE
		EXECUTE format('select public.gerar_outputs_inspire(%L, %L, %L::timestamp);',output_schema, prefixo, data_hora);	
		RETURN TRUE;
	END CASE;

END;
$body$
LANGUAGE 'plpgsql';

-- TESTEs

-- Gerar camadas inspire para o schema master
SELECT gerar_outputs_inspire('master','cont');
SELECT gerar_outputs_inspire('master','ram');
SELECT gerar_outputs_inspire('master','raa_oci');
SELECT gerar_outputs_inspire('master','raa_cen_ori');

-- gerar camadas inspire usando a versão
SELECT gerar_outputs_inspire('master','cont','v2024');