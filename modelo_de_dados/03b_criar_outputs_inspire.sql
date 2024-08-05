-- Outputs para Inspire baseado em CAOP
-- Manter toda a definição da CAOP
-- actualização dos atributos

-- query para transformar os trocos em poligonos
-- e guardar numa tabela temporária
DROP MATERIALIZED VIEW IF EXISTS master.inspire_admin_boundaries_cont;

CREATE MATERIALIZED VIEW master.inspire_admin_boundaries_cont AS
SELECT 
	row_number() over () as id,
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
FROM base.cont_troco AS t
	JOIN dominios.nivel_limite_administrativo AS nla ON t.nivel_limite_admin = nla.identificador;

CREATE INDEX ON master.inspire_admin_boundaries_cont USING gist(geometry);

DROP MATERIALIZED VIEW IF EXISTS master.inspire_admin_units_5thorder_cont;
CREATE MATERIALIZED VIEW master.inspire_admin_units_5thorder_cont AS
SELECT DISTINCT ON (dicofre)
row_number() over () as id,
'http://id.igeo.pt/so/AU/AdministrativeUnits/' || 'PT1' || dicofre || '/' || to_char(t.inicio_objecto, 'YYYYMMDD') AS "inspireId",
'PT' AS country,
t.inicio_objecto::timestamp AS "beginLifespanVersion", -- A definir
NULL::timestamp AS "endLifespanVersion", -- A definir
freguesia AS name,
'PT1' || dicofre AS "nationalCode",
'5thOrder' AS "nationalLevel",
'Freguesia' AS "nationalLevelName",
sa.nome AS "residenceOfAutorithy",
'PT1' || LEFT(dicofre,4) AS "upperLevelUnit",
f.geometria::geometry(multipolygon,3763) AS geometry
FROM master.cont_freguesias AS f
	LEFT JOIN base.cont_troco AS t ON f.dicofre IN (t.ea_direita, t.ea_esquerda)
	LEFT JOIN base.sede_administrativa AS sa ON st_intersects(f.geometria, st_transform(sa.geometria, 3763)) AND sa.tipo_sede_administrativa = '5'
ORDER BY dicofre, t.inicio_objecto DESC;

CREATE INDEX ON master.inspire_admin_units_5thorder_cont USING gist(geometry);

DROP MATERIALIZED VIEW IF EXISTS master.inspire_admin_units_4thorder_cont;
CREATE MATERIALIZED VIEW master.inspire_admin_units_4thorder_cont AS
SELECT DISTINCT ON (dico)
row_number() over () as id,
'http://id.igeo.pt/so/AU/AdministrativeUnits/' || 'PT1' || dico || '/' || to_char(t.inicio_objecto, 'YYYYMMDD') AS "inspireId",
'PT' AS country,
t.inicio_objecto::timestamp AS "beginLifespanVersion", -- A definir
NULL::timestamp AS "endLifespanVersion", -- A definir
municipio AS name,
'PT1' || dico AS "nationalCode",
'4thOrder' AS "nationalLevel",
'Município' AS "nationalLevelName",
sa.nome AS "residenceOfAutorithy",
'PT1' || LEFT(dico,2) AS "upperLevelUnit",
m.geometria::geometry(multipolygon, 3763) AS geometry
FROM master.cont_municipios AS m
	LEFT JOIN base.cont_troco AS t ON m.dico IN (LEFT(t.ea_direita,4), LEFT(t.ea_esquerda,4))
	LEFT JOIN base.sede_administrativa AS sa ON st_intersects(m.geometria, st_transform(sa.geometria, 3763)) AND sa.tipo_sede_administrativa = '4'
ORDER BY dico, t.inicio_objecto DESC; 

CREATE INDEX ON master.inspire_admin_units_4thorder_cont USING gist(geometry);

DROP MATERIALIZED VIEW IF EXISTS master.inspire_admin_units_3rdorder_cont;
CREATE MATERIALIZED VIEW master.inspire_admin_units_3rdorder_cont AS
SELECT DISTINCT ON (di)
row_number() over () as id,
'http://id.igeo.pt/so/AU/AdministrativeUnits/' || 'PT1' || di || '/' || to_char(t.inicio_objecto, 'YYYYMMDD') AS "inspireId",
'PT' AS country,
t.inicio_objecto::timestamp AS "beginLifespanVersion", -- A definir
NULL::timestamp AS "endLifespanVersion", -- A definir
distrito AS name,
'PT1' || di AS "nationalCode",
'3thOrder' AS "nationalLevel",
'Distrito' AS "nationalLevelName",
sa.nome AS "residenceOfAutorithy",
'PT1' AS "upperLevelUnit",
d.geometria AS geometry
FROM master.cont_distritos AS d
	LEFT JOIN base.cont_troco AS t ON d.di IN (LEFT(t.ea_direita,2), LEFT(t.ea_esquerda,2))
	LEFT JOIN base.sede_administrativa AS sa ON st_intersects(d.geometria, st_transform(sa.geometria, 3763)) AND sa.tipo_sede_administrativa = '3'
ORDER BY di, t.inicio_objecto DESC;

CREATE INDEX ON master.inspire_admin_units_3rdorder_cont USING gist(geometry);

GRANT ALL ON ALL TABLES IN SCHEMA master TO administrador;
GRANT SELECT ON ALL TABLES IN SCHEMA master TO editor, visualizador;


-- MADEIRA

DROP MATERIALIZED VIEW IF EXISTS master.inspire_admin_units_boundaries_ram;
CREATE MATERIALIZED VIEW master.inspire_admin_units_boundaries_ram AS
SELECT 
	row_number() over () as id,
	t.identificador AS "inspireId",
	'PT' AS country,
	nla.nome_en AS "nationalLevel",
	'2023-12-31'::timestamp AS "beginLifespanVersion", -- A definir
	NULL::timestamp AS "endLifespanVersion", -- A definir
	'agreed' AS "legalStatus",
	'notEdgeMatched' AS "technicalStatus",
	ARRAY[CASE WHEN char_length(t.ea_esquerda) > 5 THEN t.ea_esquerda END,
		  CASE WHEN char_length(t.ea_direita) > 5 THEN t.ea_direita END] AS "admUnit",
	t.geometria AS geometry
FROM master.ram_trocos AS t
	JOIN dominios.nivel_limite_administrativo AS nla ON t.nivel_limite_admin = nla.nome;

DROP MATERIALIZED VIEW IF EXISTS master.inspire_admin_units_boundaries_raa_cen_ori;
CREATE MATERIALIZED VIEW master.inspire_admin_units_boundaries_raa_cen_ori AS
SELECT 
row_number() over () as id,
t.identificador AS "inspireId",
'PT' AS country,
nla.nome_en AS "nationalLevel",
'2023-12-31'::timestamp AS "beginLifespanVersion", -- A definir
NULL::timestamp AS "endLifespanVersion", -- A definir
'agreed' AS "legalStatus",
'notEdgeMatched' AS "technicalStatus",
ARRAY[CASE WHEN char_length(t.ea_esquerda) > 5 THEN t.ea_esquerda END,
	  CASE WHEN char_length(t.ea_direita) > 5 THEN t.ea_direita END] AS "admUnit",
t.geometria AS geometry
FROM master.raa_cen_ori_trocos AS t
JOIN dominios.nivel_limite_administrativo AS nla ON t.nivel_limite_admin = nla.nome;

DROP MATERIALIZED VIEW IF EXISTS master.inspire_admin_units_boundaries_raa_oci;
CREATE MATERIALIZED VIEW master.inspire_admin_units_boundaries_raa_oci AS
SELECT
row_number() over () as id,
t.identificador AS "inspireId",
'PT' AS country,
nla.nome_en AS "nationalLevel",
'2023-12-31'::timestamp AS "beginLifespanVersion", -- A definir
NULL::timestamp AS "endLifespanVersion", -- A definir
'agreed' AS "legalStatus",
'notEdgeMatched' AS "technicalStatus",
ARRAY[CASE WHEN char_length(t.ea_esquerda) > 5 THEN t.ea_esquerda END,
	  CASE WHEN char_length(t.ea_direita) > 5 THEN t.ea_direita END] AS "admUnit",
t.geometria AS geometry
FROM master.raa_oci_trocos AS t
JOIN dominios.nivel_limite_administrativo AS nla ON t.nivel_limite_admin = nla.nome;


--

SELECT


DROP TABLE IF EXISTS temp.ebm_cont_trocos;
CREATE TABLE TEMP.ebm_cont_trocos AS
SELECT identificador, st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200) AS geometria
FROM base.cont_troco;

DROP TABLE IF EXISTS temp.ebm_ram_trocos;
CREATE TABLE TEMP.ebm_ram_trocos AS
SELECT identificador, st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200) AS geometria
FROM base.ram_troco;

DROP TABLE IF EXISTS temp.ebm_raa_oci_trocos;
CREATE TABLE TEMP.ebm_raa_oci_trocos AS
SELECT identificador, st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200) AS geometria
FROM base.raa_oci_troco;

DROP TABLE IF EXISTS temp.ebm_raa_cen_ori_trocos;
CREATE TABLE TEMP.ebm_raa_cen_ori_trocos AS
SELECT identificador, st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200) AS geometria
FROM base.raa_cen_ori_troco;

CREATE INDEX ON TEMP.ebm_cont_trocos USING gist(geometria);
CREATE INDEX ON TEMP.ebm_ram_trocos USING gist(geometria);
CREATE INDEX ON TEMP.ebm_raa_oci_trocos USING gist(geometria);
CREATE INDEX ON TEMP.ebm_raa_cen_ori_trocos USING gist(geometria);

DROP TABLE IF EXISTS temp.ebm_poligonos CASCADE;
CREATE TABLE temp.ebm_poligonos (
	id serial PRIMARY KEY,
	geometria geometry(polygon, 4258)
);

INSERT INTO temp.ebm_poligonos (geometria)
WITH poly AS (
	SELECT (st_dump(st_polygonize(geometria))).geom AS geom
	FROM temp.ebm_cont_trocos
)
SELECT st_transform(geom, 4258)
FROM poly 
WHERE st_area(geom) >= 2500;

INSERT INTO temp.ebm_poligonos (geometria)
WITH poly AS (
	SELECT (st_dump(st_polygonize(geometria))).geom AS geom
	FROM temp.ebm_ram_trocos
)
SELECT st_transform(geom, 4258)
FROM poly 
WHERE st_area(geom) >= 2500;

INSERT INTO temp.ebm_poligonos (geometria)
WITH poly AS (
	SELECT (st_dump(st_polygonize(geometria))).geom AS geom
	FROM temp.ebm_raa_oci_trocos
)
SELECT st_transform(geom, 4258)
FROM poly 
WHERE st_area(geom) >= 2500;

INSERT INTO temp.ebm_poligonos (geometria)
WITH poly AS (
	SELECT (st_dump(st_polygonize(geometria))).geom AS geom
	FROM temp.ebm_raa_cen_ori_trocos
)
SELECT st_transform(geom, 4258)
FROM poly 
WHERE st_area(geom) >= 2500;

CREATE INDEX ON temp.ebm_poligonos USING gist(geometria);

DROP TABLE IF EXISTS temp.ebm_centroides CASCADE;
CREATE TABLE temp.ebm_centroides AS
SELECT 
	entidade_administrativa,
	tipo_area_administrativa_id,
	'1' AS shn_prefix,
	st_transform(geometria,4258)::geometry(point,4258) AS geometria
FROM base.cont_centroide_ea AS ce 
UNION ALL
SELECT 
	entidade_administrativa,
	tipo_area_administrativa_id,
	'3' AS shn_prefix,
	st_transform(geometria,4258)::geometry(point,4258) AS geometria
FROM base.ram_centroide_ea AS ce
UNION ALL
SELECT 
	entidade_administrativa,
	tipo_area_administrativa_id,
	'2' AS shn_prefix,
	st_transform(geometria,4258)::geometry(point,4258) AS geometria
FROM base.raa_oci_centroide_ea AS ce
UNION ALL
SELECT 
	entidade_administrativa,
	tipo_area_administrativa_id,
	'3' AS shn_prefix,
	st_transform(geometria,4258)::geometry(point,4258) AS geometria
FROM base.raa_cen_ori_centroide_ea AS ce;

DROP MATERIALIZED VIEW master.ebm_a CASCADE;
CREATE MATERIALIZED VIEW master.ebm_a as
SELECT
	concat('_EG.EBM:AA.','PT', ce.shn_prefix, ce.entidade_administrativa) AS "InspireId",
	NULL AS "beginLifeSpanVersion",
	'PT' AS "ICC",
	concat('PT',ce.shn_prefix, ce.entidade_administrativa) AS "SHN", -- falta separar se OR continente ou ilhas PT1, PT2 ou PT3
	ce.tipo_area_administrativa_id AS "TAA",
	p.geometria::geometry(multipolygon, 4258) AS geometria
FROM TEMP.ebm_poligonos AS p
	JOIN temp.ebm_centroides AS ce ON st_intersects(p.geometria, ce.geometria);

CREATE INDEX ON master.ebm_a USING gist(geometria);

CREATE MATERIALIZED VIEW master.ebm_nam as
WITH all_areas AS (
SELECT sum(area_ha) AS area_ha FROM master.cont_distritos
UNION ALL
SELECT sum(area_ha) AS area_ha FROM master.ram_distritos
UNION ALL
SELECT sum(area_ha) AS area_ha FROM master.raa_oci_distritos
UNION ALL
SELECT sum(area_ha) AS area_ha FROM master.raa_cen_ori_distritos)
SELECT -- Portugal
	'PT' AS "ICC",
	'PT0000000'AS "SHN",
	2 AS "USE", -- continente
	2512 AS "ISN", -- continente
	'Portugal'  AS "NAMN",
	'Portugal' AS NAMA,
	'por' AS "NLN",
	'UNK' AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(sum(area_ha)/100)::numeric(15,2) AS "ARA", -- Aqui vamos ter de adicionar a area das ilhas com uma subquery
	NULL AS "effectiveDate"
FROM all_areas
UNION ALL
SELECT -- Continente
	'PT' AS "ICC",
	'PT1000000'AS "SHN",
	2 AS "USE", -- continente
	2512 AS "ISN", -- continente
	'Continente'  AS "NAMN",
	'Continente' AS NAMA,
	'por' AS "NLN",
	'PT0000000' AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(sum(area_ha)/100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM master.cont_distritos
UNION ALL
SELECT -- Distritos continente
	'PT' AS "ICC",
	concat('PT1', di, '0000') AS "SHN",
	3 AS "USE", -- distritos
	2514 AS "ISN", -- distritos
	distrito  AS "NAMN",
	TRANSLATE(distrito ,'àáãâçéêèìíóòõôúù','aaaaceeeiioooouu') AS NAMA,
	'por' AS "NLN",
	'PT1000000' AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(area_ha / 100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM
	master.cont_distritos AS cd
UNION ALL
SELECT -- Municipios Continente
	'PT1' AS "ICC",
	concat('PT1', dico, '00') AS "SHN",
	4 AS "USE", -- municipios
	2516 AS "ISN", -- municipios
	municipio  AS "NAMN",
	TRANSLATE(municipio ,'àáãâçéêèìíóòõôúù','aaaaceeeiioooouu') AS NAMA,
	'por' AS "NLN",
	concat('PT1', LEFT(dico,2),'0000') AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(area_ha / 100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM
	master.cont_municipios AS cf
UNION ALL
SELECT -- Freguesias continente
	'PT1' AS "ICC",
	concat('PT1', dicofre) AS "SHN",
	5 AS "USE", -- freguesias
	2517 AS "ISN", -- freguesia
	designacao_simplificada AS "NAMN",
	TRANSLATE(designacao_simplificada,'àáãâçéêèìíóòõôúù','aaaaceeeiioooouu') AS NAMA,
	'por' AS "NLN",
	concat('PT1', LEFT(dicofre,4),'00') AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(area_ha / 100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM
	master.cont_freguesias AS cf
UNION ALL
SELECT -- MADEIRA
	'PT' AS "ICC",
	'PT3000000'AS "SHN",
	2 AS "USE", -- regiao autonoma da madeira
	2513 AS "ISN", -- Ilhas
	'Região Autónoma da Madeira'  AS "NAMN",
	'Regiao Autonoma da Madeira' AS NAMA,
	'por' AS "NLN",
	'PT0000000' AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(sum(area_ha)/100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM master.ram_distritos
UNION ALL
SELECT -- Ilhas
	'PT' AS "ICC",
	concat('PT3', di, '0000') AS "SHN",
	3 AS "USE", -- distritos ou ilhas
	2515 AS "ISN", -- distritos
	distrito  AS "NAMN",
	TRANSLATE(distrito ,'àáãâçéêèìíóòõôúù','aaaaceeeiioooouu') AS NAMA,
	'por' AS "NLN",
	'PT3000000' AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(area_ha / 100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM
	master.ram_distritos AS cd
UNION ALL
SELECT -- Municipios Madeira
	'PT3' AS "ICC",
	concat('PT3', dico, '00') AS "SHN",
	4 AS "USE", -- municipios
	2516 AS "ISN", -- municipios
	municipio  AS "NAMN",
	TRANSLATE(municipio ,'àáãâçéêèìíóòõôúù','aaaaceeeiioooouu') AS NAMA,
	'por' AS "NLN",
	concat('PT3', LEFT(dico,2),'0000') AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(area_ha / 100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM
	master.ram_municipios AS cf
UNION ALL
SELECT -- Freguesias Madeira
	'PT3' AS "ICC",
	concat('PT3', dicofre) AS "SHN",
	5 AS "USE", -- freguesias
	2517 AS "ISN", -- freguesia
	designacao_simplificada AS "NAMN",
	TRANSLATE(designacao_simplificada,'àáãâçéêèìíóòõôúù','aaaaceeeiioooouu') AS NAMA,
	'por' AS "NLN",
	concat('PT3', LEFT(dicofre,4),'00') AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(area_ha / 100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM
	master.ram_freguesias AS cf; 
