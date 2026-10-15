
CREATE OR REPLACE FUNCTION public.gerar_vistas_wgs84_layouts(input_schema text DEFAULT 'CAOP2024.1')
-- Função para gerar as vistas materializadas em WGS84 (EPSG:4326) para utilização em atlas e serviços web
-- O output é sempre gerado no schema 'layouts'
-- ATENÇÃO: NECESSITA DE PERMISSÕES DE ADMINISTRADOR PARA CORRER POIS CRIA SCHEMAS e DÁ PERMISSÕES.
-- parametros:
-- - input_schema (TEXT) - nome do schema de onde ler os dados de origem, default 'CAOP2024.1'
RETURNS boolean AS
$body$
BEGIN
	EXECUTE format('
		CREATE SCHEMA IF NOT EXISTS layouts;
		GRANT ALL ON SCHEMA layouts TO administrador;
		GRANT USAGE ON SCHEMA layouts TO editor, visualizador, ogc_api, servicos_wms;

		DROP MATERIALIZED VIEW IF EXISTS layouts.all_distritos_wgs84 CASCADE;
		CREATE MATERIALIZED VIEW layouts.all_distritos_wgs84 AS
		WITH todos AS (
			SELECT * FROM %1$I.cont_distritos
			UNION ALL
			SELECT * FROM %1$I.ram_distritos
			UNION ALL
			SELECT * FROM %1$I.raa_cen_ori_distritos
			UNION ALL
			SELECT * FROM %1$I.raa_oci_distritos
		)
		SELECT
			dt,
			distrito,
			nuts1,
			area_ha,
			perimetro_km,
			n_municipios,
			n_freguesias,
			st_transform(geometria, 4326)::geometry(multipolygon, 4326) AS geom
		FROM todos;

		CREATE INDEX ON layouts.all_distritos_wgs84 USING gist(geom);
		ALTER TABLE IF EXISTS layouts.all_distritos_wgs84 OWNER TO administrador;

		DROP MATERIALIZED VIEW IF EXISTS layouts.all_municipios_wgs84 CASCADE;
		CREATE MATERIALIZED VIEW layouts.all_municipios_wgs84 AS
		WITH todos AS (
			SELECT * FROM %1$I.cont_municipios
			UNION ALL
			SELECT * FROM %1$I.ram_municipios
			UNION ALL
			SELECT * FROM %1$I.raa_cen_ori_municipios
			UNION ALL
			SELECT * FROM %1$I.raa_oci_municipios
		),
		distritos_wkt AS (
			SELECT 
				distrito,
				CASE 
					WHEN dt::int < 30 THEN st_transform(geom, 3763)
					WHEN dt::int < 40 THEN st_transform(geom, 5016)
					WHEN dt::int < 48 THEN st_transform(geom, 5015)
					ELSE st_transform(geom, 5014)
				END as geom
			FROM layouts.all_distritos_wgs84
		)
		SELECT
			t.dtmn,
			t.municipio,
			t.distrito_ilha,
			t.nuts3,
			t.nuts2,
			t.nuts1,
			t.area_ha,
			t.perimetro_km,
			t.n_freguesias,
			st_transform(t.geometria, 4326)::geometry(multipolygon, 4326) AS geom,
			st_astext(ST_Envelope(d.geom)) AS distrito_wkt
		FROM todos AS t
			JOIN distritos_wkt AS d ON t.distrito_ilha = d.distrito;

		CREATE INDEX ON layouts.all_municipios_wgs84 USING gist(geom);
		ALTER TABLE IF EXISTS layouts.all_municipios_wgs84 OWNER TO administrador;

		DROP MATERIALIZED VIEW IF EXISTS layouts.all_freguesias_wgs84 CASCADE;
		CREATE MATERIALIZED VIEW layouts.all_freguesias_wgs84 AS
		WITH todos AS (
			SELECT * FROM %1$I.cont_freguesias
			UNION ALL
			SELECT * FROM %1$I.ram_freguesias
			UNION ALL
			SELECT * FROM %1$I.raa_cen_ori_freguesias
			UNION ALL
			SELECT * FROM %1$I.raa_oci_freguesias
		)
		SELECT
			dtmnfr,
			freguesia,
			municipio,
			distrito_ilha,
			nuts3,
			nuts2,
			nuts1,
			area_ha,
			perimetro_km,
			designacao_simplificada,
			st_transform(geometria, 4326)::geometry(multipolygon, 4326) AS geom
		FROM todos;

		CREATE INDEX ON layouts.all_freguesias_wgs84 USING gist(geom);
		ALTER TABLE IF EXISTS layouts.all_freguesias_wgs84 OWNER TO administrador;

		DROP MATERIALIZED VIEW IF EXISTS layouts.all_trocos_wgs84 CASCADE;
		CREATE MATERIALIZED VIEW layouts.all_trocos_wgs84 AS
		WITH todos AS (
			SELECT * FROM %1$I.cont_trocos
			UNION ALL
			SELECT * FROM %1$I.ram_trocos
			UNION ALL
			SELECT * FROM %1$I.raa_cen_ori_trocos
			UNION ALL
			SELECT * FROM %1$I.raa_oci_trocos
		)
		SELECT
			identificador,
			ea_direita,
			ea_esquerda,
			paises,
			estado_limite_admin,
			significado_linha,
			nivel_limite_admin,
			comprimento_km,
			st_transform(geometria, 4326)::geometry(linestring, 4326) AS geom
		FROM todos;

		CREATE INDEX ON layouts.all_trocos_wgs84 USING gist(geom);
		ALTER TABLE IF EXISTS layouts.all_trocos_wgs84 OWNER TO administrador;

		DROP MATERIALIZED VIEW IF EXISTS layouts.all_nuts3_wgs84 CASCADE;
		CREATE MATERIALIZED VIEW layouts.all_nuts3_wgs84 AS
		WITH todos AS (
			SELECT * FROM %1$I.cont_nuts3
			UNION ALL
			SELECT * FROM %1$I.ram_nuts3
			UNION ALL
			SELECT * FROM %1$I.raa_oci_nuts3
			UNION ALL
			SELECT * FROM %1$I.raa_cen_ori_nuts3
		)
		SELECT
			codigo,
			nuts3,
			nuts2,
			nuts1,
			area_ha,
			perimetro_km,
			n_municipios,
			n_freguesias,
			st_transform(geometria, 4326)::geometry(multipolygon, 4326) AS geom
		FROM todos;

		CREATE INDEX ON layouts.all_nuts3_wgs84 USING gist(geom);
		ALTER TABLE IF EXISTS layouts.all_nuts3_wgs84 OWNER TO administrador;

		DROP MATERIALIZED VIEW IF EXISTS layouts.all_nuts2_wgs84 CASCADE;
		CREATE MATERIALIZED VIEW layouts.all_nuts2_wgs84 AS
		WITH todos AS (
			SELECT * FROM %1$I.cont_nuts2
			UNION ALL
			SELECT * FROM %1$I.ram_nuts2
			UNION ALL
			SELECT * FROM %1$I.raa_oci_nuts2
			UNION ALL
			SELECT * FROM %1$I.raa_cen_ori_nuts2
		)
		SELECT
			codigo,
			nuts2,
			nuts1,
			area_ha,
			perimetro_km,
			n_municipios,
			n_freguesias,
			st_transform(geometria, 4326)::geometry(multipolygon, 4326) AS geom
		FROM todos;

		CREATE INDEX ON layouts.all_nuts2_wgs84 USING gist(geom);
		ALTER TABLE IF EXISTS layouts.all_nuts2_wgs84 OWNER TO administrador;

		DROP MATERIALIZED VIEW IF EXISTS layouts.all_nuts1_wgs84 CASCADE;
		CREATE MATERIALIZED VIEW layouts.all_nuts1_wgs84 AS
		WITH todos AS (
			SELECT * FROM %1$I.cont_nuts1
			UNION ALL
			SELECT * FROM %1$I.ram_nuts1
			UNION ALL
			SELECT * FROM %1$I.raa_oci_nuts1
			UNION ALL
			SELECT * FROM %1$I.raa_cen_ori_nuts1
		)
		SELECT
			codigo,
			nuts1,
			area_ha,
			perimetro_km,
			n_municipios,
			n_freguesias,
			st_transform(geometria, 4326)::geometry(multipolygon, 4326) AS geom
		FROM todos;

		CREATE INDEX ON layouts.all_nuts1_wgs84 USING gist(geom);
		ALTER TABLE IF EXISTS layouts.all_nuts1_wgs84 OWNER TO administrador;

		GRANT ALL ON ALL TABLES IN SCHEMA layouts TO administrador;
		GRANT SELECT ON ALL TABLES IN SCHEMA layouts TO editor, visualizador, ogc_api, servicos_wms;'
		, input_schema);

	RETURN TRUE;
END;
$body$
LANGUAGE 'plpgsql';

GRANT EXECUTE ON FUNCTION public.gerar_vistas_wgs84_layouts(text) TO administrador;

-- Exemplos de utilização:
-- SELECT public.gerar_vistas_wgs84_layouts('CAOP2025'); -- schema de origem diferente


