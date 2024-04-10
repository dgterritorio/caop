-- Scrips para transformar os trocos e centroides em poligonos aos seus varios niveis

-- Todos os comandos devem ser corridos dentro de funcoes o mais genericas possiveis que permitam
   -- Escolher o schema base a usar (base_continente, base_madeira, base_acores_ocidental, base_acores_oriental ),
   -- Talvez nao fique separado por schema, apenas diferentes tabelas para trocos e centroides com EPSGs diferentes
   -- Escolher o schema de output,
   -- Escolher a data ou versão a usar (usando o versioning)

CREATE OR REPLACE FUNCTION public.gerar_poligonos_caop(output_schema text DEFAULT 'master'::regnamespace, prefixo TEXT DEFAULT 'cont', data_hora timestamp DEFAULT now()::timestamp )
-- Função para gerar os poligonos de output da CAOP com base nos trocos e centroides existentes no schema base
-- ATENÇÃO: NECESSITA DE PERMISSÕES DE ADMINISTRADOR PARA CORRER POIS CRIA SCHEMAS e DÁ PERMISSÕES.
-- parametros:
-- - output_schema (TEXT) - nome do schema onde guardar os resultados, default 'master'
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

	-- Se necessário, cria o schema para guardar os outputs
	EXECUTE format('
		CREATE SCHEMA IF NOT EXISTS %1$I;
		GRANT ALL ON SCHEMA %1$I TO administrador;
		GRANT USAGE ON SCHEMA %1$I TO editor, visualizador;'
		, output_schema);

	-- query para transformar os trocos em poligonos
	-- e guardar numa tabela temporária
	EXECUTE format('
		CREATE TABLE IF NOT EXISTS %1$I.%2$s_poligonos_temp(
			id serial PRIMARY KEY,
			geometria geometry(polygon, %3$s)
			);
		DROP INDEX IF EXISTS %2$s_poligonos_temp_geometria_idx;
		TRUNCATE TABLE %1$I.%2$s_poligonos_temp RESTART IDENTITY;'
		, output_schema, prefixo, epsg);

	EXECUTE format('
		INSERT INTO %1$I.%2$s_poligonos_temp (geometria)
		SELECT (st_dump(st_polygonize(geometria))).geom AS geom
		FROM vsr_table_at_time (NULL::base.%2$s_troco, %3$L::timestamp);

		CREATE INDEX IF NOT EXISTS %2$s_poligonos_temp_geometria_idx ON %1$I.%2$s_poligonos_temp USING gist(geometria);'
		, output_schema, prefixo, data_hora);

	-- Spatial Join entre os poligonos gerados temporariamente e os centroides para criar as
	-- areas_administrativas
	EXECUTE format('
		CREATE MATERIALIZED VIEW IF NOT EXISTS %1$I.%2$s_areas_administrativas as
			WITH atributos_freguesias AS (
				SELECT
					ea.codigo AS dicofre,
					ea.nome AS freguesia,
					m.nome AS municipio,
					di.nome AS distrito_ilha,
					n3.nome AS nuts3,
					n2.nome AS nuts2,
					n1.nome AS nuts1
				FROM base.entidade_administrativa AS ea
					JOIN vsr_table_at_time (NULL::base.municipio, %3$L::timestamp) AS m ON ea.municipio_cod = m.codigo
					JOIN vsr_table_at_time (NULL::base.distrito_ilha, %3$L::timestamp) AS di ON m.distrito_cod = di.codigo
					JOIN vsr_table_at_time (NULL::base.nuts3, %3$L::timestamp) AS n3 ON m.nuts3_cod = n3.codigo
					JOIN vsr_table_at_time (NULL::base.nuts2, %3$L::timestamp) AS n2 ON n3.nuts2_cod = n2.codigo
					JOIN vsr_table_at_time (NULL::base.nuts1, %3$L::timestamp) AS n1 ON n2.nuts1_cod = n1.codigo
			)
			SELECT
				ROW_NUMBER() OVER () AS id,
				a.dicofre,
				a.freguesia,
				taa.nome AS tipo_area_administrativa,
				a.municipio,
				a.distrito_ilha,
				a.nuts3,
				a.nuts2,
				a.nuts1,
				p.geometria::geometry(polygon, %4$s) AS geometria,
				(st_area(p.geometria) / 10000)::numeric(15,2) AS area_ha,
				(st_perimeter(p.geometria) / 1000)::integer AS perimetro_km
			FROM %1$I.%2$s_poligonos_temp AS p
				JOIN vsr_table_at_time (NULL::base.%2$s_centroide_ea, %3$L::timestamp) AS ce ON st_intersects(p.geometria, ce.geometria) -- FALTA COLOCAR O PREFIXO
				JOIN atributos_freguesias AS a ON a.dicofre = ce.entidade_administrativa
				JOIN vsr_table_at_time (NULL::dominios.tipo_area_administrativa, %3$L::timestamp) AS taa ON ce.tipo_area_administrativa_id = taa.identificador
		WITH NO DATA;

		REFRESH MATERIALIZED VIEW %1$I.%2$s_areas_administrativas;

		CREATE INDEX IF NOT EXISTS %2$s_areas_administrativas_geometria_idx ON %1$I.%2$s_areas_administrativas USING gist(geometria);'
		, output_schema, prefixo, data_hora, epsg);

	-- Agrega das areas administrativas por entidade administrativa (dicofre)
	-- Para obtenção da tabela das freguesias
	EXECUTE format('
		CREATE MATERIALIZED VIEW IF NOT EXISTS %1$I.%2$s_freguesias AS
			SELECT
				dicofre,
				freguesia,
				municipio,
				distrito_ilha,
				nuts3,
				nuts2,
				nuts1,
				(st_collect(geometria))::geometry(multipolygon, %3$s) AS geometria,
				(sum(st_area(geometria)) / 10000)::numeric(15,2) AS area_ha,
				(sum(st_perimeter(geometria)) / 1000)::integer AS perimetro_km,
				REPLACE(freguesia,''União das freguesias de '','''') as designacao_simplificada
			FROM %1$I.%2$s_areas_administrativas
			GROUP BY dicofre, freguesia, municipio, distrito_ilha, nuts3, nuts2, nuts1
		WITH NO DATA;
		
		REFRESH MATERIALIZED VIEW %1$I.%2$s_freguesias;

		CREATE INDEX IF NOT EXISTS %2$s_freguesias_geometria_idx ON %1$I.%2$s_freguesias USING gist(geometria);'
		, output_schema, prefixo, epsg);

	-- Agrega as freguesias em municípios pelo (dico) futuro dtmn
	EXECUTE format('
		CREATE MATERIALIZED VIEW IF NOT EXISTS %1$I.%2$s_municipios AS
			SELECT
				LEFT(dicofre,4) AS dico,
				municipio,
				distrito_ilha,
				nuts3,
				nuts2,
				nuts1,
				st_multi((st_union(geometria)))::geometry(multipolygon, %3$s) AS geometria,
				(sum(st_area(geometria)) / 10000)::numeric(15,2) AS area_ha,
				(st_perimeter((st_union(geometria))) / 1000)::integer AS perimetro_km,
				count(*) AS n_freguesias
			FROM %1$I.%2$s_freguesias
			GROUP BY dico, municipio, distrito_ilha, nuts3, nuts2, nuts1
		WITH NO DATA;

		REFRESH MATERIALIZED VIEW %1$I.%2$s_municipios;

		CREATE INDEX IF NOT EXISTS %2$s_municipios_geometria_idx ON %1$I.%2$s_municipios USING gist(geometria);'
	, output_schema, prefixo, epsg);

	-- agrega os concelhos em distritos
	EXECUTE format('
		CREATE MATERIALIZED VIEW IF NOT EXISTS %1$I.%2$s_distritos AS
			SELECT
				LEFT(dico,2) AS di,
				distrito_ilha AS distrito,
				nuts1,
				st_multi((st_union(geometria)))::geometry(multipolygon, %3$s) AS geometria,
				(sum(st_area(geometria)) / 10000)::numeric(15,2) AS area_ha,
				(st_perimeter((st_union(geometria))) / 1000)::integer AS perimetro_km,
				count(*) AS n_municipios,
				sum(n_freguesias) AS n_freguesias
			FROM %1$I.%2$s_municipios
			GROUP BY di, distrito, nuts1
		WITH NO DATA;

		REFRESH MATERIALIZED VIEW %1$I.%2$s_distritos;

		CREATE INDEX IF NOT EXISTS %2$s_distritos_geometria_idx ON %1$I.%2$s_distritos USING gist(geometria);'
	, output_schema, prefixo, epsg);

	-- agrega os municípios em nuts3
	EXECUTE format('
		CREATE MATERIALIZED VIEW IF NOT EXISTS %1$I.%2$s_nuts3 AS
			SELECT
				ROW_NUMBER() OVER () AS id,
				n3.codigo,
				nuts3,
				nuts2,
				nuts1,
				st_multi((st_union(geometria)))::geometry(multipolygon, %3$s) AS geometria,
				(sum(st_area(geometria)) / 10000)::numeric(15,2) AS area_ha,
				(st_perimeter((st_union(geometria))) / 1000)::integer AS perimetro_km,
				count(*) AS n_municipios,
				sum(n_freguesias) AS n_freguesias
			FROM %1$I.%2$s_municipios AS m
				JOIN base.nuts3 AS n3 ON m.nuts3 = n3.nome
			GROUP BY codigo, nuts3, nuts2, nuts1
		WITH NO DATA;

		REFRESH MATERIALIZED VIEW %1$I.%2$s_nuts3;

		CREATE INDEX IF NOT EXISTS	%2$s_nuts3_geometria_idx ON %1$I.%2$s_nuts3 USING gist(geometria);'
	, output_schema, prefixo, epsg);

	-- agreda as nuts3 em nuts2
	EXECUTE format('
		CREATE MATERIALIZED VIEW IF NOT EXISTS %1$I.%2$s_nuts2 AS
			SELECT
				n2.codigo,
				nuts2,
				nuts1,
				st_multi((st_union(geometria)))::geometry(multipolygon, %3$s) AS geometria,
				(sum(st_area(geometria)) / 10000)::numeric(15,2) AS area_ha,
				(st_perimeter((st_union(geometria))) / 1000)::integer AS perimetro_km,
				sum(n_municipios) AS n_municipios,
				sum(n_freguesias) AS n_freguesias
			FROM %1$I.%2$s_nuts3 AS m
				JOIN base.nuts2 AS n2 ON m.nuts2 = n2.nome
			GROUP BY n2.codigo, nuts2, nuts1
		WITH NO DATA;
		
		REFRESH MATERIALIZED VIEW %1$I.%2$s_nuts2;

		CREATE INDEX IF NOT EXISTS	%2$s_nuts2_geometria_idx ON %1$I.%2$s_nuts2 USING gist(geometria);'
	, output_schema, prefixo, epsg);

	-- agreda as nuts2 em nuts1
	EXECUTE format('
		CREATE MATERIALIZED VIEW IF NOT EXISTS %1$I.%2$s_nuts1 AS
			SELECT
				n1.codigo,
				nuts1,
				st_multi((st_union(geometria)))::geometry(multipolygon, %3$s) AS geometria,
				(sum(st_area(geometria)) / 10000)::numeric(15,2) AS area_ha,
				(st_perimeter((st_union(geometria))) / 1000)::integer AS perimetro_km,
				sum(n_municipios) AS n_municipios,
				sum(n_freguesias) AS n_freguesias
			FROM %1$I.%2$s_nuts2 AS m
				JOIN base.nuts1 AS n1 ON m.nuts1 = n1.nome
			GROUP BY n1.codigo, nuts1
		WITH NO DATA;

		REFRESH MATERIALIZED VIEW %1$I.%2$s_nuts1;

		CREATE INDEX IF NOT EXISTS	%2$s_nuts1_geometria_idx ON %1$I.%2$s_nuts1 USING gist(geometria);'
		, output_schema, prefixo, epsg);
	
-- actualiza permissões do schema

	EXECUTE format('
		GRANT ALL ON ALL TABLES IN SCHEMA %1$I TO administrador;
		GRANT SELECT ON ALL TABLES IN SCHEMA %1$I TO editor, visualizador;'
		, output_schema);

	RETURN TRUE;
END;
$body$
LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION public.gerar_poligonos_caop(output_schema text DEFAULT 'master'::regnamespace, prefixo TEXT DEFAULT 'cont', output_versao TEXT DEFAULT '')
-- Função alternativa, baseada na anterior mas tem como input o numero de versão, em vez de um data e hora
-- ATENÇÃO: NECESSITA DE PERMISSÕES DE ADMINISTRADOR PARA CORRER POIS CRIA SCHEMAS e DÁ PERMISSÕES.
-- parametros:
-- - output_schema (TEXT) - nome do schema onde guardar os resultados, default 'master'
-- - prefixo (TEXT) - prefixo que permite separar entre o continente e as ilhas, valores possiveis são ('cont', 'ram','raa_oci','raa_cen_ori'), default 'cont'
-- - output_versao (TIMESTAMP) , número de uma versão existente na tabela versioning.versao
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
		EXECUTE format('select public.gerar_poligonos_caop(%L, %L, %L::timestamp);',output_schema, prefixo, data_hora);	
		RETURN TRUE;
	END CASE;

END;
$body$
LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION public.actualizar_poligonos_caop(output_schema text DEFAULT 'master'::regnamespace, prefixo TEXT DEFAULT 'cont', data_hora timestamp DEFAULT now()::timestamp )
-- Função para actualizar os poligonos de output da CAOP com base no schema e em vistas materializadas já existentes.
-- Para correr em schemas de output inexistentes, há que correr primeiro a funcao gerar public.gerar_poligonos_caop
-- ATENÇÃO: NECESSITA DE PERMISSÕES DE EDITOR PARA CORRER POIS CRIA SCHEMAS e DÁ PERMISSÕES.
-- parametros:
-- - output_schema (TEXT) - nome do schema onde guardar os resultados, default 'master'
-- - prefixo (TEXT) - prefixo que permite separar entre o continente e as ilhas, valores possiveis são ('cont', 'ram','raa_oci','raa_cen_ori'), default 'cont'
-- - data_hora (TIMESTAMP) , permite definir um dia e hora para criar um output baseado em dados passados, default hora actual
RETURNS Boolean 
SECURITY DEFINER AS
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

	-- Limpa a tabela poligonos_temp existente
	-- e preenche com novos dados
	EXECUTE format('
		TRUNCATE TABLE %1$I.%2$s_poligonos_temp RESTART IDENTITY;'
		, output_schema, prefixo, epsg);

	EXECUTE format('
		INSERT INTO %1$I.%2$s_poligonos_temp (geometria)
		SELECT (st_dump(st_polygonize(geometria))).geom AS geom
		FROM vsr_table_at_time (NULL::base.%2$s_troco, %3$L::timestamp);'
		, output_schema, prefixo, data_hora);

	-- Actualizar as vista materializadas dos polígonos de output
	EXECUTE format('
		REFRESH MATERIALIZED VIEW %1$I.%2$s_areas_administrativas;
		REFRESH MATERIALIZED VIEW %1$I.%2$s_freguesias;
		REFRESH MATERIALIZED VIEW %1$I.%2$s_municipios;
		REFRESH MATERIALIZED VIEW %1$I.%2$s_distritos;
		REFRESH MATERIALIZED VIEW %1$I.%2$s_nuts3;
		REFRESH MATERIALIZED VIEW %1$I.%2$s_nuts2;
		REFRESH MATERIALIZED VIEW %1$I.%2$s_nuts1;'
		, output_schema, prefixo, epsg);

	RETURN TRUE;
END;
$body$
LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION public.gerar_trocos_caop(output_schema text DEFAULT 'master'::regnamespace, prefixo TEXT DEFAULT 'cont', data_hora timestamp DEFAULT now()::timestamp )
-- Função para exportar os trocos de output da CAOP com base nos trocos no schema base
-- parametros:
-- - output_schema (TEXT) - nome do schema onde guardar os resultados, default 'master'
-- - prefixo (TEXT) - prefixo que permite separar entre o continente e as ilhas, valores possiveis são ('cont', 'ram','raa_oci','raa_cen_ori'), default 'cont'
-- - data_hora (TIMESTAMP) , permite definir um dia e hora para criar um output baseado em dados passados, default hora actual
RETURNS Boolean 
SECURITY DEFINER AS
$body$
DECLARE
	epsg TEXT;
BEGIN
	CASE
		WHEN prefixo = 'cont' THEN	epsg := '3763';
		WHEN prefixo = 'ram' THEN	epsg := '5016';
		WHEN prefixo = 'raa_oci' THEN	epsg := '5014';
		WHEN prefixo = 'raa_cen_ori' THEN	epsg := '5015';
		ELSE
			RAISE EXCEPTION 'Prefixo inválido!';
			RETURN FALSE;
	END CASE;

	EXECUTE format('
		CREATE MATERIALIZED VIEW IF NOT EXISTS %1$I.%2$s_trocos AS
			SELECT
				t.identificador,
				ea_direita,
				ea_esquerda,
				cip.nome AS paises,
				ela.nome AS estado_limite_admin,
				sl.nome AS significado_linha,
				nla.nome AS nivel_limite_admin,
				t.geometria::geometry(linestring, %4$s) AS geometria,
				st_length(t.geometria) / 1000 AS comprimento_km
			FROM vsr_table_at_time (NULL::base.%2$s_troco, %3$L::timestamp) AS t
				LEFT JOIN vsr_table_at_time (NULL::dominios.caracteres_identificadores_pais, %3$L::timestamp) AS cip ON t.pais = cip.identificador
				LEFT JOIN vsr_table_at_time (NULL::dominios.estado_limite_administrativo, %3$L::timestamp) AS ela ON t.estado_limite_admin = ela.identificador
				LEFT JOIN vsr_table_at_time (NULL::dominios.significado_linha, %3$L::timestamp)  AS sl ON t.significado_linha = sl.identificador
				LEFT JOIN vsr_table_at_time (NULL::dominios.nivel_limite_administrativo, %3$L::timestamp)  AS nla ON t.nivel_limite_admin = nla.identificador
		WITH NO DATA;

		REFRESH MATERIALIZED VIEW %1$I.%2$s_trocos;

		CREATE INDEX IF NOT EXISTS %2$s_trocos_geometria_idx ON %1$I.%2$s_trocos USING gist(geometria);'
	, output_schema, prefixo, data_hora, epsg);

	-- cria vista inf_fonte_troco
	EXECUTE format('
		CREATE OR REPLACE VIEW %1$I.inf_fonte_troco AS
		WITH all_lig_fontes AS (
			SELECT * FROM vsr_table_at_time (NULL::"base".lig_cont_troco_fonte, %2$L::timestamp)
			UNION ALL SELECT * FROM vsr_table_at_time (NULL::"base".lig_ram_troco_fonte, %2$L::timestamp)
			UNION ALL SELECT * FROM vsr_table_at_time (NULL::"base".lig_raa_cen_ori_troco_fonte, %2$L::timestamp)
			UNION ALL SELECT * FROM vsr_table_at_time (NULL::"base".lig_raa_oci_troco_fonte, %2$L::timestamp)
		)
		SELECT 
			row_number() OVER () AS id,
			lctf.identificador AS identificador_troco,
		    tf.nome AS tipo_fonte,
		    f.descricao,
		    f.data,
		    f.observacoes,
		    f.diploma
		   FROM all_lig_fontes as lctf
		     JOIN vsr_table_at_time (NULL::"base".fonte, %2$L::timestamp) f ON f.identificador = lctf.fonte_id
		     JOIN vsr_table_at_time (NULL::"dominios".tipo_fonte, %2$L::timestamp) tf ON tf.identificador::text = f.tipo_fonte::TEXT;'
	, output_schema, data_hora);

	-- actualiza permissões do schema

	EXECUTE format('
		GRANT ALL ON ALL TABLES IN SCHEMA %1$I TO administrador;
		GRANT SELECT ON ALL TABLES IN SCHEMA %1$I TO editor, visualizador;'
		, output_schema);

	RETURN TRUE;
END;
$body$
LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION public.gerar_trocos_caop(output_schema text DEFAULT 'master'::regnamespace, prefixo TEXT DEFAULT 'cont', output_versao TEXT DEFAULT '')
-- Função alternativa, baseada na anterior mas tem como input o numero de versão, em vez de um data e hora
-- ATENÇÃO: NECESSITA DE PERMISSÕES DE ADMINISTRADOR PARA CORRER POIS CRIA SCHEMAS e DÁ PERMISSÕES.
-- parametros:
-- - output_schema (TEXT) - nome do schema onde guardar os resultados, default 'master'
-- - prefixo (TEXT) - prefixo que permite separar entre o continente e as ilhas, valores possiveis são ('cont', 'ram','raa_oci','raa_cen_ori'), default 'cont'
-- - output_versao (TIMESTAMP) , número de uma versão existente na tabela versioning.versao
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
		EXECUTE format('select public.gerar_trocos_caop(%L, %L, %L::timestamp);',output_schema, prefixo, data_hora);	
		RETURN TRUE;
	END CASE;

END;
$body$
LANGUAGE 'plpgsql';

-- Criar função que actualiza os campos ea_esquerda e ea_direita da camada troços com base
-- nos polígonos criados pelas últimas alterações


-- preencher campos ea_direita e ea_esquerda da tabela dos trocos
-- A apenas tenta preencher campos vazios para ser mais rápido
-- isso implica que de futuro, qual edição numa linha, deva através de um trigger
-- apagar os campos das entidades administrativas

CREATE OR REPLACE FUNCTION public.actualizar_trocos(prefixo TEXT DEFAULT 'cont')
-- Função para preencher campos ea_direita, ea_esquerda e nivel_limite_admin com base nos outputs gerados
-- parametros:
-- - prefixo (TEXT) - prefixo que permite separar entre o continente e as ilhas, valores possiveis são ('cont', 'ram','raa_oci','raa_cen_ori'), default 'cont'
RETURNS Boolean AS
$body$
DECLARE
	epsg TEXT;
BEGIN
	CASE
		WHEN prefixo = 'cont' THEN	epsg := '3763';
		WHEN prefixo = 'ram' THEN	epsg := '5016';
		WHEN prefixo = 'raa_oci' THEN	epsg := '5014';
		WHEN prefixo = 'raa_cen_ori' THEN	epsg := '5015';
		ELSE
			RAISE EXCEPTION 'Prefixo inválido!';
			RETURN FALSE;
	END CASE;

	-- obter as fronteiras de todas as entidades administrativas
	EXECUTE format('
		DROP TABLE IF EXISTS %1$s_ea_boundaries;
		CREATE TEMPORARY TABLE %1$s_ea_boundaries ON COMMIT DROP AS
		SELECT cea.dicofre, ((st_dump(st_boundary(cea.geometria))).geom)::geometry(linestring,%2$s) AS geometria
		FROM master.%1$s_areas_administrativas AS cea;

		CREATE INDEX ON %1$s_ea_boundaries USING gist(geometria);'
	, prefixo, epsg);

	-- para cada linha com ea_direita ou ea_esquerda vazia, obter os dicofre correspondentes
	EXECUTE format('
		DROP TABLE IF EXISTS %1$s_lados_em_falta;
		CREATE TEMPORARY TABLE %1$s_lados_em_falta ON COMMIT DROP AS
			WITH linhas AS (
			SELECT t.identificador,
				cf.dicofre,
				CASE WHEN
				    st_linelocatepoint(cf.geometria, ST_LineInterpolatePoint(t.geometria,0.01)) <
				    st_linelocatepoint(cf.geometria, ST_LineInterpolatePoint(t.geometria,0.02)) THEN ''direita''
					ELSE ''esquerda''
				END AS lado
			FROM base.%1$s_troco AS t
				JOIN %1$s_ea_boundaries AS cf
				    ON st_contains(cf.geometria, t.geometria)
					--ON t.geometria && cf.geometria AND st_relate(t.geometria, cf.geometria,''1*F**F***'')
			--WHERE t.ea_esquerda IS NULL OR t.ea_direita IS NULL
			)
			SELECT
			    identificador,
			    MAX(CASE WHEN lado = ''direita'' THEN dicofre END) AS ea_direita,
			    MAX(CASE WHEN lado = ''esquerda'' THEN dicofre END) AS ea_esquerda
			FROM linhas
			GROUP BY identificador;

			CREATE INDEX ON %1$s_lados_em_falta(identificador);'
	, prefixo);

		-- preencher os dicofre na ea_direita e ea_esquerda
	EXECUTE format('
		UPDATE base.%1$s_troco AS t SET
			ea_direita = lef.ea_direita,
			ea_esquerda = lef.ea_esquerda
		FROM %1$s_lados_em_falta AS lef
		WHERE t.identificador = lef.identificador;'
	, prefixo);

	-- Nos que não for possivel determinar um poligono (freguesia) adjacente
	-- determinar se pertence a outras entidades com base noutros campos
	EXECUTE format('
		UPDATE base.%1$s_troco AS t SET
			ea_direita = (CASE WHEN pais = ''PT#ES'' THEN ''98'' -- Espanha
			             WHEN significado_linha = ''1'' THEN ''99'' -- Oceano Atlântico
			             WHEN significado_linha = ''9'' THEN ''97'' -- Rio
			             ELSE NULL
			             END)
		WHERE ea_direita IS NULL;

		UPDATE base.%1$s_troco AS t SET
			ea_esquerda = (CASE WHEN pais = ''PT#ES'' THEN ''98'' -- Espanha
			             WHEN significado_linha = ''1'' THEN ''99'' -- Oceano Atlântico
			             WHEN significado_linha = ''9'' THEN ''97'' -- Rio
			             ELSE NULL
			             END)
		WHERE ea_esquerda IS NULL;'
	, prefixo);

	-- Classificar troço de acordo com os limites administrativos (nivel_limite_administrativo)
	-- Apenas preenche os campos vazios. Temos de perceber se queremos manter isto automático
	-- Nesse caso, sempre que houver uma edição o campo terá de ser tornado NULO
	EXECUTE format('
		UPDATE base.%1$s_troco SET
			nivel_limite_admin = CASE WHEN pais = ''PT#ES'' THEN ''1''
									WHEN significado_linha = ''1'' THEN ''2''
									ELSE NULL
									END
		WHERE nivel_limite_admin IS NULL;

		UPDATE base.%1$s_troco SET
			nivel_limite_admin = NULL
		WHERE significado_linha IN (''1'',''9'');

		UPDATE base.%1$s_troco AS t SET
			nivel_limite_admin = 3
		FROM master.%1$s_distritos AS d
		WHERE nivel_limite_admin IS NULL AND t.geometria && d.geometria AND st_relate(t.geometria, d.geometria,''F*FF*F***'');

		UPDATE base.%1$s_troco AS t SET
			nivel_limite_admin = 4
		FROM master.%1$s_municipios AS m
		WHERE nivel_limite_admin IS NULL AND t.geometria && m.geometria AND st_relate(t.geometria, m.geometria,''F*FF*F***'');

		UPDATE base.%1$s_troco AS t SET
			nivel_limite_admin = 5
		FROM master.%1$s_freguesias AS f
		WHERE nivel_limite_admin IS NULL AND t.geometria && f.geometria AND st_relate(t.geometria, f.geometria,''F*FF*F***'');'
	, prefixo);

	RETURN TRUE;
END;
$body$
LANGUAGE 'plpgsql';


-- Por definição todas as funções têm permissão de execute
-- Por isso retiramos todas as permissões e apenas damos a editores e administradores
REVOKE ALL ON FUNCTION public.gerar_poligonos_caop(text, text, timestamp) FROM public;
GRANT EXECUTE ON FUNCTION public.gerar_poligonos_caop(text, text, timestamp) TO administrador, editor;
REVOKE ALL ON FUNCTION public.actualizar_poligonos_caop(text, text, timestamp) FROM public;
GRANT EXECUTE ON FUNCTION public.actualizar_poligonos_caop(text, text, timestamp) TO administrador, editor;
REVOKE ALL ON FUNCTION public.actualizar_poligonos_caop(text, text, timestamp) FROM public;
GRANT EXECUTE ON FUNCTION public.actualizar_poligonos_caop(text, text, timestamp) TO administrador, editor;
REVOKE ALL ON FUNCTION public.gerar_trocos_caop(text, text, timestamp) FROM public;
GRANT EXECUTE ON FUNCTION public.gerar_trocos_caop(text, text, timestamp) TO administrador, editor;
REVOKE ALL ON FUNCTION public.actualizar_trocos(text) FROM public;
GRANT EXECUTE ON FUNCTION public.actualizar_trocos(text) TO administrador, editor;

-- TESTES

SELECT gerar_poligonos_caop('master3','cont','2024-02-14 15:42:26');
SELECT gerar_poligonos_caop('master','cont');
SELECT gerar_poligonos_caop('master3');
SELECT public.actualizar_trocos('cont');
SELECT gerar_trocos_caop('master','cont'),now()::timestamp);
SELECT gerar_trocos_caop('master3','cont','2023-12-19 18:26:57');
SELECT public.gerar_trocos_caop();

SELECT gerar_poligonos_caop('master','ram');
SELECT public.actualizar_trocos('ram');
SELECT public.gerar_trocos_caop('master','ram');

-- TESTES com numeros de versoes
SELECT public.gerar_poligonos_caop('master3','cont','v2024.0');
SELECT public.gerar_trocos_caop('master3','cont','v2024.0');

-- TRIGGERS PARA AUTOMATICAMENTE GERAR OS POLIGONOS, PREENCHER TROCOS e ACTUALIZAR VIEWS DE VALIDACAO
-- NAO ESTÃO ACTIVOS POIS ERAM DEMASIADO LENTOS
CREATE OR REPLACE FUNCTION public.tr_gerar_outputs()
 RETURNS trigger
 LANGUAGE plpgsql
AS $body$
BEGIN
	BEGIN
		PERFORM actualizar_poligonos_caop('master',TG_ARGV[0]);
	END;
	BEGIN
		PERFORM actualizar_trocos(TG_ARGV[0]);
	END;
	BEGIN
		PERFORM gerar_trocos_caop('master',TG_ARGV[0]);
	END;
	BEGIN
		PERFORM	tr_actualizar_validacao(TG_ARGV[0]); 
	END;
	RETURN NULL;
END;
$body$
;


SELECT actualizar_poligonos_caop('master','cont'); --35 seg
SELECT actualizar_trocos('cont'); -- 35 seg
SELECT gerar_trocos_caop('master','cont'); -- imediato
SELECT tr_actualizar_validacao('cont'); --20 segundos


CREATE OR REPLACE TRIGGER tr_base_cont_trocos_ai AFTER
DELETE OR INSERT OR UPDATE OF pais, estado_limite_admin, significado_linha, geometria  ON base.cont_troco
FOR EACH STATEMENT
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION tr_gerar_outputs('cont');

CREATE OR REPLACE TRIGGER tr_base_cont_centroides_ai AFTER
DELETE OR INSERT OR UPDATE ON base.cont_centroide_ea
FOR EACH STATEMENT
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION tr_gerar_outputs('cont');

CREATE OR REPLACE TRIGGER tr_base_ram_trocos_ai AFTER
DELETE OR INSERT OR UPDATE OF pais, estado_limite_admin, significado_linha, geometria ON base.ram_troco
FOR EACH STATEMENT
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION tr_gerar_outputs('ram');

CREATE OR REPLACE TRIGGER tr_base_ram_centroides_ai AFTER
DELETE OR INSERT OR UPDATE ON base.ram_centroide_ea
FOR EACH STATEMENT
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION tr_gerar_outputs('ram');

CREATE OR REPLACE TRIGGER tr_base_raa_oci_trocos_ai AFTER
DELETE OR INSERT OR UPDATE OF pais, estado_limite_admin, significado_linha, geometria ON base.raa_oci_troco
FOR EACH STATEMENT
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION tr_gerar_outputs('raa_oci');

CREATE OR REPLACE TRIGGER tr_base_raa_oci_centroides_ai AFTER
DELETE OR INSERT OR UPDATE ON base.raa_oci_centroide_ea
FOR EACH STATEMENT
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION tr_gerar_outputs('raa_oci');

CREATE OR REPLACE TRIGGER tr_base_raa_cen_ori_trocos_ai AFTER
DELETE OR INSERT OR UPDATE OF pais, estado_limite_admin, significado_linha, geometria ON base.raa_cen_ori_troco
FOR EACH STATEMENT
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION tr_gerar_outputs('raa_cen_ori');

CREATE OR REPLACE TRIGGER tr_base_raa_cen_ori_centroides_ai AFTER
DELETE OR INSERT OR UPDATE ON base.raa_cen_ori_centroide_ea
FOR EACH STATEMENT
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION tr_gerar_outputs('raa_cen_ori');

-- TRIGGER PARA LIMPAR CAMPOS QUE NECESSITAM DE SER ACTAULIZADOS APOS EDICAO DOS TROCOS
-- Função para Limpar os campos que devem ser preenchidos automaticamente
-- Pela função actualizar actualizar_trocos()

CREATE OR REPLACE FUNCTION public.tr_limpar_campos_trocos()
 RETURNS trigger
 LANGUAGE plpgsql
AS $body$
BEGIN
	NEW.ea_direita := NULL;
	NEW.ea_esquerda := NULL;
	IF NEW.nivel_limite_admin != '998' THEN
		NEW.nivel_limite_admin := NULL;
	END IF;
	RETURN NEW;
END;
$body$
;

CREATE OR REPLACE TRIGGER tr_limpar_campos_trocos_bi BEFORE
INSERT OR UPDATE ON base.cont_troco
FOR EACH ROW
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION public.tr_limpar_campos_trocos();

CREATE OR REPLACE TRIGGER tr_limpar_campos_trocos_bi BEFORE
INSERT OR UPDATE ON base.ram_troco
FOR EACH ROW
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION public.tr_limpar_campos_trocos();

CREATE OR REPLACE TRIGGER tr_limpar_campos_trocos_bi BEFORE
INSERT OR UPDATE ON base.raa_oci_troco
FOR EACH ROW
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION public.tr_limpar_campos_trocos();

CREATE OR REPLACE TRIGGER tr_limpar_campos_trocos_bi BEFORE
INSERT OR UPDATE ON base.raa_cen_ori_troco
FOR EACH ROW
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION public.tr_limpar_campos_trocos();

-- TRIGGER PARA LIMPAR CAMPOS QUE NECESSITAM DE SER ACTAULIZADOS APOS EDICAO DOS CENTROIDES
-- Função para Limpar os campos que devem ser preenchidos automaticamente
-- Pela função actualizar actualizar_trocos()

CREATE OR REPLACE FUNCTION public.tr_limpar_campos_centroides()
 RETURNS trigger
 LANGUAGE plpgsql
AS $body$
DECLARE 
	ea VARCHAR(8);
BEGIN
	IF TG_OP IN ('DELETE', 'UPDATE') THEN
		ea := OLD.entidade_administrativa;
	END IF;
	
	UPDATE base.cont_troco SET
		ea_direita = NULL
	WHERE ea_direita = ea;

	UPDATE base.cont_troco SET
		ea_esquerda = NULL
	WHERE ea_esquerda = ea;
	
	UPDATE base.cont_troco SET
		nivel_limite_admin = NULL
	WHERE nivel_limite_admin != '998' AND (ea_esquerda IS NULL OR ea_direita IS NULL);
	
	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$body$
;

CREATE OR REPLACE TRIGGER tr_limpar_campos_centroides_bi BEFORE
DELETE OR UPDATE ON base.cont_centroide_ea
FOR EACH ROW
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION public.tr_limpar_campos_centroides();

CREATE OR REPLACE TRIGGER tr_limpar_campos_centroides_bi BEFORE
DELETE OR UPDATE ON base.ram_centroide_ea
FOR EACH ROW
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION public.tr_limpar_campos_centroides();

CREATE OR REPLACE TRIGGER tr_limpar_campos_centroides_bi BEFORE
DELETE OR UPDATE ON base.raa_oci_centroide_ea
FOR EACH ROW
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION public.tr_limpar_campos_centroides();

CREATE OR REPLACE TRIGGER tr_limpar_campos_centroides_bi BEFORE
DELETE OR UPDATE ON base.raa_cen_ori_centroide_ea
FOR EACH ROW
WHEN ((pg_trigger_depth() < 1))
EXECUTE FUNCTION public.tr_limpar_campos_centroides();


SELECT actualizar_poligonos_caop('master','cont');
SELECT gerar_trocos_caop('master','cont')

--- FIM DO SCRIPT ARQUIVO


-- query para transformar os trocos em poligonos
-- e guardar numa tabela temporária
DROP TABLE IF EXISTS temp.poligonos CASCADE;
CREATE TABLE temp.poligonos (
	id serial PRIMARY KEY,
	geometria geometry(polygon, 3763)
);

INSERT INTO temp.poligonos (geometria)
SELECT (st_dump(st_polygonize(geometria))).geom AS geom
FROM base.troco;

SELECT (st_dump(st_polygonize(geometria))).geom AS geom
FROM vsr_table_at_time (NULL::"base".troco, '2023-12-19 18:26:57');

CREATE INDEX ON temp.poligonos USING gist(geometria);

CREATE SCHEMA master;
GRANT ALL ON SCHEMA master TO administrador;
GRANT USAGE ON SCHEMA master TO editor, visualizador;

-- A cada poligono, tentar atribuir os restantes atributos relacionados com o centroide que nele contido
-- actualmente a query ignora centroides duplicados (com o mesmo dicofre), mas futuramente não o deverá fazer
--DROP MATERIALIZED VIEW master.continente_areas_administrativas CASCADE;
CREATE MATERIALIZED VIEW master.continente_areas_administrativas as
WITH atributos_freguesias AS (
	SELECT
		ea.codigo AS dicofre,
		ea.nome AS freguesia,
		m.nome AS municipio,
		di.nome AS distrito_ilha,
		n3.nome AS nuts3,
		n2.nome AS nuts2,
		n1.nome AS nuts1
	FROM base.entidade_administrativa AS ea
		JOIN base.municipio AS m ON ea.municipio_cod = m.codigo
		JOIN base.distrito_ilha AS di ON m.distrito_cod = di.codigo
		JOIN base.nuts3 AS n3 ON m.nuts3_cod = n3.codigo
		JOIN base.nuts2 AS n2 ON n3.nuts2_cod = n2.codigo
		JOIN base.nuts1 AS n1 ON n2.nuts1_cod = n1.codigo
)
SELECT
	ROW_NUMBER() OVER () AS id,
	a.dicofre,
	a.freguesia,
	taa.nome AS tipo_area_administrativa,
	a.municipio,
	a.distrito_ilha,
	a.nuts3,
	a.nuts2,
	a.nuts1,
	p.geometria::geometry(polygon, 3763) AS geometria,
	(st_area(p.geometria) / 10000)::numeric(15,2) AS area_ha,
	(st_perimeter(p.geometria) / 1000)::integer AS perimetro_km
FROM TEMP.poligonos AS p
	JOIN base.centroide_ea AS ce ON st_intersects(p.geometria, ce.geometria)
	JOIN atributos_freguesias AS a ON a.dicofre = ce.entidade_administrativa
	JOIN dominios.tipo_area_administrativa AS taa ON ce.tipo_area_administrativa_id = taa.identificador;

CREATE INDEX ON master.continente_areas_administrativas USING gist(geometria);

-- agrega as entidades administrativas por dicofre
CREATE MATERIALIZED VIEW master.continente_freguesias AS
SELECT
	dicofre,
	freguesia,
	municipio,
	distrito_ilha,
	nuts3,
	nuts2,
	nuts1,
	(st_collect(geometria))::geometry(multipolygon,3763) AS geometria,
	(sum(st_area(geometria)) / 10000)::numeric(15,2) AS area_ha,
	(sum(st_perimeter(geometria)) / 1000)::integer AS perimetro_km,
	REPLACE(freguesia,'União das freguesias de ','') as designacao_simplificada
FROM master.continente_areas_administrativas
GROUP BY dicofre, freguesia, municipio, distrito_ilha, nuts3, nuts2, nuts1;

CREATE INDEX ON master.continente_freguesias USING gist(geometria);

-- agrega as freguesias em municípios (dico)
CREATE MATERIALIZED VIEW master.continente_municipios AS
SELECT
	LEFT(dicofre,4) AS dico,
	municipio,
	distrito_ilha,
	nuts3,
	nuts2,
	nuts1,
	(st_union(geometria))::geometry(multipolygon,3763) AS geometria,
	(sum(st_area(geometria)) / 10000)::numeric(15,2) AS area_ha,
	(st_perimeter((st_union(geometria))) / 1000)::integer AS perimetro_km,
	count(*) AS n_freguesias
FROM master.continente_freguesias
GROUP BY dico, municipio, distrito_ilha, nuts3, nuts2, nuts1;

CREATE INDEX ON master.continente_municipios USING gist(geometria);

-- agrega os concelhos em distritos
CREATE MATERIALIZED VIEW master.continente_distritos AS
SELECT
	LEFT(dico,2) AS di,
	distrito_ilha AS distrito,
	nuts1,
	(st_union(geometria))::geometry(multipolygon,3763) AS geometria,
	(sum(st_area(geometria)) / 10000)::numeric(15,2) AS area_ha,
	(st_perimeter((st_union(geometria))) / 1000)::integer AS perimetro_km,
	count(*) AS n_municipios,
	sum(n_freguesias) AS n_freguesias
FROM master.continente_municipios
GROUP BY di, distrito, nuts1;

CREATE INDEX ON master.continente_distritos USING gist(geometria);

-- agrega os municípios em nuts3
CREATE MATERIALIZED VIEW master.continente_nuts3 AS
SELECT
	ROW_NUMBER() OVER () AS id,
	n3.codigo,
	nuts3,
	nuts2,
	nuts1,
	(st_union(geometria))::geometry(multipolygon,3763) AS geometria,
	(sum(st_area(geometria)) / 10000)::numeric(15,2) AS area_ha,
	(st_perimeter((st_union(geometria))) / 1000)::integer AS perimetro_km,
	count(*) AS n_municipios,
	sum(n_freguesias) AS n_freguesias
FROM master.continente_municipios AS m
	JOIN base.nuts3 AS n3 ON m.nuts3 = n3.nome
GROUP BY codigo, nuts3, nuts2, nuts1;

CREATE INDEX ON master.continente_nuts3 USING gist(geometria);

-- agreda as nuts3 em nuts2
CREATE MATERIALIZED VIEW master.continente_nuts2 AS
SELECT
	n2.codigo,
	nuts2,
	nuts1,
	(st_union(geometria))::geometry(multipolygon,3763) AS geometria,
	(sum(st_area(geometria)) / 10000)::numeric(15,2) AS area_ha,
	(st_perimeter((st_union(geometria))) / 1000)::integer AS perimetro_km,
	sum(n_municipios) AS n_municipios,
	sum(n_freguesias) AS n_freguesias
FROM master.continente_nuts3 AS m
	JOIN base.nuts2 AS n2 ON m.nuts2 = n2.nome
GROUP BY n2.codigo, nuts2, nuts1;

CREATE INDEX ON master.continente_nuts2 USING gist(geometria);

-- agreda as nuts2 em nuts1
CREATE MATERIALIZED VIEW master.continente_nuts1 AS
SELECT
	n1.codigo,
	nuts1,
	(st_union(geometria))::geometry(multipolygon,3763) AS geometria,
	(sum(st_area(geometria)) / 10000)::numeric(15,2) AS area_ha,
	(st_perimeter((st_union(geometria))) / 1000)::integer AS perimetro_km,
	sum(n_municipios) AS n_municipios,
	sum(n_freguesias) AS n_freguesias
FROM master.continente_nuts2 AS m
	JOIN base.nuts1 AS n1 ON m.nuts1 = n1.nome
GROUP BY n1.codigo, nuts1;

CREATE INDEX ON master.continente_nuts1 USING gist(geometria);


-- preencher campos ea_direita e ea_esquerda da tabela dos trocos
-- A apenas tenta preencher campos vazios para ser mais rápido
-- isso implica que de futuro, qual edição numa linha, deva através de um trigger
-- apagar os campos das entidades administrativas


CREATE MATERIALIZED VIEW TEMP.ea_boundaries AS -- obter AS fronteiras de todas AS ea
SELECT cea.dicofre, ((st_dump(st_boundary(cea.geometria))).geom)::geometry(linestring,3763) AS geometria
FROM master.continente_areas_administrativas AS cea;

CREATE INDEX ON temp.ea_boundaries USING gist(geometria);

-- para cada linha com ea_direita ou ea_esquerda vazia, obter os dicofre correspondentes
CREATE MATERIALIZED VIEW TEMP.lados_em_falta AS
WITH linhas AS (
SELECT t.identificador,
	cf.dicofre,
	CASE WHEN
	    st_linelocatepoint(cf.geometria, ST_LineInterpolatePoint(t.geometria,0.01)) <
	    st_linelocatepoint(cf.geometria, ST_LineInterpolatePoint(t.geometria,0.02)) THEN 'direita'
		ELSE 'esquerda'
	END AS lado
FROM base.troco AS t
	JOIN temp.ea_boundaries AS cf
	    ON st_contains(cf.geometria, t.geometria)
		--ON t.geometria && cf.geometria AND st_relate(t.geometria, cf.geometria,'1*F**F***')
WHERE t.ea_esquerda IS NULL OR t.ea_direita IS NULL
)
SELECT
    identificador,
    MAX(CASE WHEN lado = 'direita' THEN dicofre END) AS ea_direita,
    MAX(CASE WHEN lado = 'esquerda' THEN dicofre END) AS ea_esquerda
FROM linhas
GROUP BY identificador;

CREATE INDEX ON TEMP.lados_em_falta(identificador);

-- preencher os dicofre na ea_direita e ea_esquerda
UPDATE base.troco AS t SET
	ea_direita = lef.ea_direita,
	ea_esquerda = lef.ea_esquerda
FROM TEMP.lados_em_falta AS lef
WHERE t.identificador = lef.identificador;

-- Nos que não for possivel determinar um poligono (freguesia) adjacente
-- determinar se pertence a outras entidades com base noutros campos
UPDATE base.troco AS t SET
	ea_direita = (CASE WHEN pais = 'PT#ES' THEN '98' -- Espanha
	             WHEN significado_linha = '1' THEN '99' -- Oceano Atlântico
	             WHEN significado_linha = '9' THEN '97' -- Rio
	             ELSE NULL
	             END)
WHERE ea_direita IS NULL;

UPDATE base.troco AS t SET
	ea_esquerda = (CASE WHEN pais = 'PT#ES' THEN '98' -- Espanha
	             WHEN significado_linha = '1' THEN '99' -- Oceano Atlântico
	             WHEN significado_linha = '9' THEN '97' -- Rio
	             ELSE NULL
	             END)
WHERE ea_esquerda IS NULL;

-- Preparar trocos para output
DROP MATERIALIZED VIEW master.continente_trocos;
CREATE MATERIALIZED VIEW master.continente_trocos AS
	SELECT
		row_number() OVER () AS id,
		ea_direita,
		ea_esquerda,
		cip.nome AS paises,
		ela.nome AS estado_limite_admin,
		sl.nome AS significado_linha,
		nla.nome AS nivel_limite_admin,
		t.geometria::geometry(linestring,3763) AS geometria,
		st_length(t.geometria) / 1000 AS comprimento_km
	FROM base.troco AS t
		JOIN dominios.caracteres_identificadores_pais AS cip ON t.pais = cip.identificador
		JOIN dominios.estado_limite_administrativo AS ela ON t.estado_limite_admin = ela.identificador
		JOIN dominios.significado_linha AS sl ON t.significado_linha = sl.identificador
		JOIN dominios.nivel_limite_administrativo AS nla ON t.nivel_limite_admin = nla.identificador;

CREATE INDEX ON master.continente_trocos USING gist(geometria);

GRANT ALL ON ALL TABLES IN SCHEMA master TO administrador;
GRANT SELECT ON ALL TABLES IN SCHEMA master TO editor, visualizador;

-- Classificar troço de acordo com os limites administrativos (nivel_limite_administrativo)
-- Apenas preenche os campos vazios. Temos de perceber se queremos manter isto automático
-- Nesse caso, sempre que houver uma edição o campo terá de ser tornado NULO

UPDATE base.troco SET
	nivel_limite_admin = CASE WHEN pais = 'PT#ES' THEN '1'
							WHEN significado_linha = '1' THEN '2'
							ELSE NULL
							END
WHERE nivel_limite_admin IS NULL;

UPDATE base.troco SET
	nivel_limite_admin = NULL
WHERE significado_linha IN ('1','9');


UPDATE base.troco AS t SET
	nivel_limite_admin = 3
FROM master.continente_distritos AS d
WHERE nivel_limite_admin IS NULL AND t.geometria && d.geometria AND st_relate(t.geometria, d.geometria,'F*FF*F***');

UPDATE base.troco AS t SET
	nivel_limite_admin = 4
FROM master.continente_municipios AS m
WHERE nivel_limite_admin IS NULL AND t.geometria && m.geometria AND st_relate(t.geometria, m.geometria,'F*FF*F***');

UPDATE base.troco AS t SET
	nivel_limite_admin = 5
FROM master.continente_freguesias AS f
WHERE nivel_limite_admin IS NULL AND t.geometria && f.geometria AND st_relate(t.geometria, f.geometria,'F*FF*F***');

SELECT t.identificador, t.geometria
FROM base.troco AS t JOIN master.continente_distritos AS d ON t.geometria && d.geometria AND st_relate(t.geometria, d.geometria,'F*FF*F***')
WHERE nivel_limite_admin IS NULL
ORDER BY t.identificador
LIMIT 1;

