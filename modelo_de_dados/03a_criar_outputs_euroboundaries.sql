-- Outputs para EuroBoundaries

CREATE SCHEMA IF NOT EXISTS euroboundaries;

-- Foram importados manualmente os troços do Euroboundaries 2024 para usar como referência
-- Estes troços terão de ser substituídos pelas versões seguintes (e.g. ebm_boundaries_2025)
-- Caso haja alterações na CAOP que alterem este limites "fixos" as edições terão de ser transpostas
-- Para a seguinte tabela

-- NOTA: A pedido do EuroGeographics foram alterados os limites ficos de 2024, na zona de Tavira.
-- Por essa razão o proóximo código encontra-se comentado.
-- Após publicação do Euroboundaries 2026, pode-se importar a emb_boundaries_2026, adaptar o código
-- comentado e voltar a activar o código.
/*
-- Criar uma nova tabela para agregar todos os trocos que vão gerar o Euroboundaries
CREATE TABLE IF NOT EXISTS euroboundaries.ebm_trocos_fixos (LIKE euroboundaries.ebm_boundaries_2024 INCLUDING ALL);
TRUNCATE TABLE euroboundaries.ebm_trocos_fixos;

-- Inserir os troços fixos do Euroboundaries (linhas de costa e fronteira com espanha e as linhas tecnicas).
INSERT INTO euroboundaries.ebm_trocos_fixos
SELECT * FROM euroboundaries.ebm_boundaries_2024
WHERE  icc  =  'ES#PT' or mol in ( '1', '2' );

CREATE INDEX ON euroboundaries.ebm_trocos_fixos USING gist(geom);
*/

-- Poligono EBM total para cortar troços e identificar polígonos gerados que ficam fora do EBM
DROP TABLE IF EXISTS euroboundaries.ebm_temp_poligono_clip;
CREATE TABLE euroboundaries.ebm_temp_poligono_clip AS
SELECT ST_CollectionExtract(ST_polygonize(geom),3)::geometry(multipolygon, 4258) AS geom
FROM euroboundaries.ebm_trocos_fixos;

-- Agrupar numa outra tabela, todos os limites interiores vindos da CAOP no mesmo sistema de coordenadas
-- e após processo de simplificação
DROP TABLE IF EXISTS euroboundaries.ebm_trocos_caop_generalizados;
CREATE TABLE IF NOT EXISTS euroboundaries.ebm_trocos_caop_generalizados (LIKE euroboundaries.ebm_boundaries_2024 INCLUDING ALL);

-- CONTINENTE
INSERT INTO euroboundaries.ebm_trocos_caop_generalizados (geom)
WITH trocos_simplificados AS (
	SELECT 
		--pais AS icc,
		--nivel_limite_admin AS use,
		--estado_limite_admin AS bst,
		--significado_linha AS mol,
		st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
	FROM base.cont_troco as t 
	WHERE pais = 'PT' AND significado_linha in ('7','9')),
clipped as(
	SELECT
		CASE WHEN st_within(ts.geom, c.geom) THEN
			ts.geom
		ELSE
			st_intersection(ts.geom, c.geom)
		END AS geom
	FROM trocos_simplificados AS ts
		JOIN euroboundaries.ebm_temp_poligono_clip AS c 
		ON st_intersects(ts.geom, c.geom))
SELECT (st_dump(geom)).geom FROM clipped;

-- MADEIRA
INSERT INTO euroboundaries.ebm_trocos_caop_generalizados (geom)
WITH trocos_simplificados AS (
	SELECT 
		--pais AS icc,
		--nivel_limite_admin AS use,
		--estado_limite_admin AS bst,
		--significado_linha AS mol,
		st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
	FROM base.ram_troco as t
	WHERE pais = 'PT' AND significado_linha in ('7','9')),
clipped as(
	SELECT
		CASE WHEN st_within(ts.geom, c.geom) THEN
			ts.geom
		ELSE
			st_intersection(ts.geom, c.geom)
		END AS geom
	FROM trocos_simplificados AS ts
		JOIN euroboundaries.ebm_temp_poligono_clip AS c 
		ON st_intersects(ts.geom, c.geom))
SELECT (st_dump(geom)).geom FROM clipped;

-- AÇORES OCIDENTAL
INSERT INTO euroboundaries.ebm_trocos_caop_generalizados (geom)
WITH trocos_simplificados AS (
	SELECT 
		--pais AS icc,
		--nivel_limite_admin AS use,
		--estado_limite_admin AS bst,
		--significado_linha AS mol,
		st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
	FROM base.raa_oci_troco as t
	WHERE pais = 'PT' AND significado_linha in ('7','9')),
clipped as(
	SELECT
		CASE WHEN st_within(ts.geom, c.geom) THEN
			ts.geom
		ELSE
			st_intersection(ts.geom, c.geom)
		END AS geom
	FROM trocos_simplificados AS ts
		JOIN euroboundaries.ebm_temp_poligono_clip AS c 
		ON st_intersects(ts.geom, c.geom))
SELECT (st_dump(geom)).geom FROM clipped;

--AÇORES CENTRAL E ORIENTAL
INSERT INTO euroboundaries.ebm_trocos_caop_generalizados (geom)
WITH trocos_simplificados AS (
	SELECT 
		--pais AS icc,
		--nivel_limite_admin AS use,
		--estado_limite_admin AS bst,
		--significado_linha AS mol,
		st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
	FROM base.raa_cen_ori_troco as t
	WHERE pais = 'PT' AND significado_linha in ('7','9')),
clipped as(
	SELECT
		CASE WHEN st_within(ts.geom, c.geom) THEN
			ts.geom
		ELSE
			st_intersection(ts.geom, c.geom)
		END AS geom
	FROM trocos_simplificados AS ts
		JOIN euroboundaries.ebm_temp_poligono_clip AS c 
		ON st_intersects(ts.geom, c.geom))
SELECT (st_dump(geom)).geom FROM clipped;

CREATE INDEX ON euroboundaries.ebm_trocos_caop_generalizados USING gist(geom);

-- EXISTEM ALGUNS TROCOS QUE SÃO COINCIDENTES COM O LIMITE DO EUROBOUNDARIES e que DEVEM ser eliminados antes de se tentar fazer qualquer tipo de 
-- ajuste dos endpoints para baterem certo com o euroboundaries.

DELETE FROM  euroboundaries.ebm_trocos_caop_generalizados AS tcg
USING euroboundaries.ebm_trocos_fixos AS etf 
WHERE st_within(tcg.geom, st_buffer(etf.geom,0.0001));

-- Os limites vindos da CAOP não coincidem com os limites fixos vindos da EBM 2024, o que impediria que muitos poligonos 
-- fossem criados. Assim, é preciso adaptá-los para que passem a coincidir 

-- Criar tabela com todos os endpoints dos limites fixos, que serão mais tarde usados como referência
DROP TABLE IF EXISTS euroboundaries.ebm_pontos_referencia;
CREATE TABLE euroboundaries.ebm_pontos_referencia AS
WITH endpoints AS (
    SELECT ST_StartPoint(geom) AS geom FROM euroboundaries.ebm_trocos_fixos
    UNION
    SELECT ST_EndPoint(geom) AS geom FROM euroboundaries.ebm_trocos_fixos
)
SELECT DISTINCT ON (geom) ROW_NUMBER() OVER () AS id, geom::geometry(point, 4258) FROM endpoints;

CREATE INDEX ON euroboundaries.ebm_pontos_referencia USING gist(geom);

-- Criar tabela com pontos dos limites interiores que não toquem em nenhuma outra geometria ou
-- nem nos limites externos
-- Primeiro recolhemos todos os startpoints e end points, depois tiramos aqueles que não estão
-- desconectados de outros troços e não tocam nos limites exteriores.
-- São excluidos deste processo geometrias fechadas.

DROP TABLE IF EXISTS euroboundaries.ebm_temp_limites_exteriores;

CREATE TABLE euroboundaries.ebm_temp_limites_exteriores AS
SELECT
	st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
FROM base.cont_troco as t
WHERE NOT (pais = 'PT' AND significado_linha in ('7','9'))
UNION ALL
SELECT
	st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
FROM base.raa_oci_troco as t
WHERE NOT (pais = 'PT' AND significado_linha in ('7','9'))
UNION ALL
SELECT
	st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
FROM base.raa_cen_ori_troco as t
WHERE NOT (pais = 'PT' AND significado_linha in ('7','9'))
UNION ALL
SELECT
	st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
FROM base.ram_troco as t
WHERE NOT (pais = 'PT' AND significado_linha in ('7','9'));

CREATE INDEX ON euroboundaries.ebm_temp_limites_exteriores USING gist(geom);

DROP TABLE IF EXISTS euroboundaries.ebm_limites_interiores_dangles;
CREATE TABLE euroboundaries.ebm_limites_interiores_dangles AS
WITH endpoints AS (
    SELECT id, 'start' AS edge, ST_StartPoint(geom) AS geom FROM euroboundaries.ebm_trocos_caop_generalizados
    WHERE NOT st_isclosed(geom)
    UNION
    SELECT id, 'end' AS edge, ST_EndPoint(geom) AS geom FROM euroboundaries.ebm_trocos_caop_generalizados
    WHERE NOT st_isclosed(geom)
)
SELECT DISTINCT ON (ep.id, ep.geom) ep.id, ep.edge, ep.geom::geometry(point, 4258) 
FROM endpoints AS ep ;
 

CREATE INDEX ON euroboundaries.ebm_limites_interiores_dangles USING gist(geom);

DELETE 
FROM euroboundaries.ebm_limites_interiores_dangles
	WHERE 
	NOT EXISTS (SELECT 1 FROM euroboundaries.ebm_temp_limites_exteriores AS le
	            WHERE st_intersects(ebm_limites_interiores_dangles.geom, le.geom)) AND 
    EXISTS (
		SELECT 1 FROM euroboundaries.ebm_trocos_caop_generalizados AS e
		WHERE ebm_limites_interiores_dangles.id <> e.id AND ST_intersects(ebm_limites_interiores_dangles.geom, e.geom)
	);

-- Para cada dangle, identificar o no de referencia mais proximo e usá-lo para
-- alterar os nós inicial e/ou finais dos troços 

UPDATE euroboundaries.ebm_trocos_caop_generalizados AS e
SET geom = (SELECT st_setpoint(e.geom, 0, d.geom) AS geom
				FROM euroboundaries.ebm_pontos_referencia AS d
				ORDER BY lid.geom <-> d.geom
				LIMIT 1)
FROM euroboundaries.ebm_limites_interiores_dangles AS lid
WHERE e.id = lid.id AND lid.edge = 'start';

UPDATE euroboundaries.ebm_trocos_caop_generalizados AS e
SET geom = (SELECT st_setpoint(e.geom, -1, d.geom) AS geom
				FROM euroboundaries.ebm_pontos_referencia AS d
				ORDER BY lid.geom <-> d.geom
				LIMIT 1)
FROM euroboundaries.ebm_limites_interiores_dangles AS lid
WHERE e.id = lid.id AND lid.edge = 'end';

-- Procedimento para criar trocos finais juntandos os trocos fixos vindos do euroboundaries
-- e os trocos generalizados e adaptados vindos da CAOP. No mesmo processo, todos os troços
-- são cortados em intersecções para permitir mais tarde a correcta criação de polígonos 
DROP TABLE IF EXISTS euroboundaries.ebm_trocos_finais;
CREATE TABLE euroboundaries.ebm_trocos_finais AS 
WITH todos_trocos AS (
	SELECT geom FROM euroboundaries.ebm_trocos_fixos AS etf 
	UNION ALL
	SELECT geom FROM euroboundaries.ebm_trocos_caop_generalizados AS etcg)
SELECT (st_dump(st_node(st_collect(geom)))).geom AS geom
FROM todos_trocos;

-- Criação de uma tabela de poligonos para guardar o resultado de um processo de polygonização
-- Apenas são considerados polígonos cujo centroide fique dentro do limite do euroboundaries
DROP TABLE IF EXISTS euroboundaries.ebm_poligonos_finais CASCADE;
CREATE TABLE euroboundaries.ebm_poligonos_finais (
	id serial PRIMARY KEY,
	geometria geometry(multipolygon, 4258)
);

INSERT INTO euroboundaries.ebm_poligonos_finais (geometria)
WITH poly AS (
	SELECT (st_dump(st_polygonize(geom))).geom AS geom
	FROM euroboundaries.ebm_trocos_finais
)
SELECT p.geom
FROM poly AS p, euroboundaries.ebm_temp_poligono_clip AS c
WHERE st_intersects(st_pointonsurface(p.geom), c.geom);

CREATE INDEX ON euroboundaries.ebm_poligonos_finais USING gist(geometria);

-- Encontrar polígonos com àrea inferiores a 2500 m2 para os dissolver no polígono adjacente 
-- com maior fronteira partilhada

WITH to_merge AS (
	SELECT DISTINCT ON (pf1.id) pf1.id AS merge_id, pf2.id AS target_id, pf1.geometria AS merge_geom, st_length(st_intersection(pf1.geometria, pf2.geometria)) AS share_boundary
	FROM euroboundaries.ebm_poligonos_finais AS pf1 
		JOIN euroboundaries.ebm_poligonos_finais AS pf2 ON st_intersects(pf1.geometria, pf2.geometria)
	WHERE st_area(pf1.geometria::geography) < 2500 AND st_area(pf2.geometria::geography) >= 2500 AND pf2.id != pf1.id
	ORDER BY pf1.id, st_length(st_intersection(pf1.geometria, pf2.geometria))
)
UPDATE euroboundaries.ebm_poligonos_finais
SET geometria = st_union(geometria, cm.merge_geom)
FROM to_merge AS cm
WHERE id = cm.target_id;

DELETE FROM euroboundaries.ebm_poligonos_finais
WHERE st_area(geometria::geography) < 2500;


-- Obter atributos para os polígonos EBM gerados
-- Colocar numa unica tabela todos os poligonos da CAOP nos sistema de coordenadas da EBM
-- E com os atributos adaptados ao Euroboundaries
DROP TABLE IF EXISTS euroboundaries.caop_areas_administrativas;
CREATE TABLE euroboundaries.caop_areas_administrativas AS
SELECT 
	dtmnfr AS entidade_administrativa,
	'1' AS shn_prefix,
	st_transform(geometria, 4258)::geometry(polygon, 4258) AS geometria
FROM master.cont_areas_administrativas
UNION ALL
SELECT 
	dtmnfr AS entidade_administrativa,
	'3' AS shn_prefix,
	st_transform(geometria, 4258)::geometry(polygon, 4258) AS geometria
FROM master.ram_areas_administrativas
UNION ALL
SELECT 
	dtmnfr AS entidade_administrativa,
	'2' AS shn_prefix,
	st_transform(geometria, 4258)::geometry(polygon, 4258) AS geometria
FROM master.raa_cen_ori_areas_administrativas
UNION ALL
SELECT 
	dtmnfr AS entidade_administrativa,
	'2' AS shn_prefix,
	st_transform(geometria, 4258)::geometry(polygon, 4258) AS geometria
FROM master.raa_oci_areas_administrativas;

CREATE INDEX ON euroboundaries.caop_areas_administrativas USING gist(geometria);

-- Colocar numa unica tabela todos os centroides da CAOP no sistema de coordenadas
-- do Euroboundaries e adaptar os atributos do eurobaoundaries

DROP TABLE IF EXISTS euroboundaries.ebm_centroides CASCADE;
CREATE TABLE euroboundaries.ebm_centroides AS
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
	'2' AS shn_prefix,
	st_transform(geometria,4258)::geometry(point,4258) AS geometria
FROM base.raa_cen_ori_centroide_ea AS ce;

-- Cruzar poligonos criados para o EBM com os da CAOP e os respectivos centroides
-- para obtenção dos atributos necessários

DROP TABLE IF EXISTS master.ebm_a CASCADE;
CREATE TABLE master.ebm_a as
SELECT DISTINCT ON ("InspireId", geometry)
	concat('_EG.EBM:AA.','PT', caa.shn_prefix, caa.entidade_administrativa) AS "InspireId",
	'2024-12-31'::timestamp AS "beginLifeSpanVersion",
	'PT' AS "ICC",
	concat('PT',caa.shn_prefix, caa.entidade_administrativa) AS "SHN",
	ce.tipo_area_administrativa_id AS "TAA",
	st_multi(p.geometria)::geometry(multipolygon, 4258) AS geometry
FROM euroboundaries.ebm_poligonos_finais AS p
	LEFT JOIN euroboundaries.caop_areas_administrativas AS caa ON (st_intersects(st_pointonsurface(p.geometria),caa.geometria))
	LEFT JOIN euroboundaries.ebm_centroides AS ce ON st_intersects(p.geometria, ce.geometria)
ORDER BY "InspireId",geometry, "TAA";

CREATE INDEX ON master.ebm_a USING gist(geometry);

-- Algumas ilhas criadas no EBM não obtêm TAA pois na CAOP estão agregadas à area administrativa
-- Preencher como area secundaria

UPDATE master.ebm_a SET 
"TAA" = '3'
WHERE "TAA" IS NULL;


-- Isolar os troços necessários para gerar as COASTAL WATER, usando as boundaries on water e as coastal lines
-- Correr o ST_nodes para quebrar as linhas nas intersecções
DROP TABLE IF EXISTS TEMP.ebm_trocos_finais_para_coastal_water;
CREATE TABLE TEMP.ebm_trocos_finais_para_coastal_water AS
WITH trocos_temp as (
	SELECT geom FROM euroboundaries.ebm_boundaries_2024
	WHERE  mol in ('9')
	UNION ALL 
	SELECT geom FROM euroboundaries.ebm_trocos_fixos
	WHERE  mol in ('1','2')
)
SELECT (st_dump(st_node(st_collect(geom)))).geom AS geom 
FROM trocos_temp;

-- Criação de uma tabela de poligonos para guardar o resultado de um processo de polygonização
-- Apenas são considerados polígonos cujo centroide fique FORA dos limites em terra do euroboundaries
DROP TABLE IF EXISTS temp.ebm_poligonos_finais_coastal_water;
CREATE TABLE temp.ebm_poligonos_finais_coastal_water (
	id serial PRIMARY KEY,
	geometria geometry(polygon, 4258)
);

INSERT INTO temp.ebm_poligonos_finais_coastal_water (geometria)
WITH poly AS (
	SELECT (st_dump(st_polygonize(geom))).geom AS geom
	FROM TEMP.ebm_trocos_finais_para_coastal_water
)
SELECT p.geom
FROM poly AS p, euroboundaries.ebm_temp_poligono_clip AS c
WHERE st_disjoint(st_pointonsurface(p.geom), c.geom);

CREATE INDEX ON temp.ebm_poligonos_finais_coastal_water USING gist(geometria);

-- Inserir os polígonos gerados na tabela já existente com os polígonos em terra
INSERT INTO master.ebm_a
SELECT DISTINCT ON ("InspireId", geometry)
	CASE WHEN caa.entidade_administrativa IS NULL THEN '_EG.EBM:AA.PT0000000'
		ELSE concat('_EG.EBM:AA.','PT', caa.shn_prefix, caa.entidade_administrativa) END AS "InspireId",
	'2024-12-31'::timestamp AS "beginLifeSpanVersion",
	'PT' AS "ICC",
	CASE WHEN caa.entidade_administrativa IS NULL THEN 'PT0000000'
		ELSE concat('PT',caa.shn_prefix, caa.entidade_administrativa) END AS "SHN",
	'5' AS "TAA",
	st_multi(p.geometria)::geometry(multipolygon, 4258) AS geometry
FROM temp.ebm_poligonos_finais_coastal_water AS p
LEFT JOIN euroboundaries.caop_areas_administrativas AS caa ON (st_intersects(st_pointonsurface(p.geometria),caa.geometria));

-- ADICIONAR SUFIXOS PARA OS CASOS DAS Entidades Administrativas com compostas por várias partes

WITH get_suffix AS (
	SELECT 
	    "InspireId",
	    "TAA",
	    geometry,
	    '.' || (CASE WHEN COUNT(*) OVER (PARTITION BY "InspireId") > 1 THEN
	    	ROW_NUMBER() OVER (PARTITION BY "InspireId" ORDER BY "TAA", st_area(geometry) DESC)
	    ELSE NULL END)::text AS suffix
	FROM 
	    master.ebm_a
)
UPDATE master.ebm_a
SET "InspireId" = concat(master.ebm_a."InspireId", suffix)
FROM get_suffix AS gf 
WHERE master.ebm_a."InspireId" = gf."InspireId" AND master.ebm_a.geometry = gf.geometry;

-- Criar tabela ebm_nam com base da CAOP
-- De notar que a área descrita nesta tabela è a área real tirada da CAOP
-- E não a area dos polígonos gerados para o Euroboundaries
DROP MATERIALIZED VIEW IF EXISTS euroboundaries.ebm_nam_temp CASCADE;
CREATE MATERIALIZED VIEW euroboundaries.ebm_nam_temp as
WITH all_areas AS (
	SELECT sum(area_ha) AS area_ha FROM master.cont_distritos
	UNION ALL
	SELECT sum(area_ha) AS area_ha FROM master.ram_distritos
	UNION ALL
	SELECT sum(area_ha) AS area_ha FROM master.raa_oci_distritos
	UNION ALL
	SELECT sum(area_ha) AS area_ha FROM master.raa_cen_ori_distritos
)
	SELECT -- Portugal
		'PT' AS "ICC",
		'PT0000000'AS "SHN",
		1 AS "USE", -- continente
		2511 AS "ISN", -- Republica
		'Portugal'  AS "NAMN",
		'Portugal' AS "NAMA",
		'por' AS "NLN",
		'UNK' AS "SHNupper",
		min(sa.ebm_roa) AS "ROA",
		NULL AS "PPL",
		(sum(area_ha)/100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM all_areas, base.sede_administrativa AS sa 
	WHERE tipo_sede_administrativa = '1'
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
		min(sa.ebm_roa) AS "ROA",
		NULL AS "PPL",
		(sum(area_ha)/100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM master.cont_distritos
	LEFT JOIN base.sede_administrativa AS sa ON tipo_sede_administrativa = '1'
UNION ALL
	SELECT -- Distritos continente
		'PT' AS "ICC",
		concat('PT1', dt, '0000') AS "SHN",
		3 AS "USE", -- distritos
		2514 AS "ISN", -- distritos
		distrito  AS "NAMN",
		TRANSLATE(distrito ,'àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ','aaaaceeeiioooouuAAAACEEEIIOOOOUUU') AS NAMA,
		'por' AS "NLN",
		'PT1000000' AS "SHNupper",
		sa.ebm_roa AS "ROA",
		NULL AS "PPL",
		(area_ha / 100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM
		master.cont_distritos AS cd
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(cd.geometria, st_transform(sa.geometria, 3763)) AND sa.tipo_sede_administrativa = '3'
UNION ALL
	SELECT -- Municipios Continente
		'PT' AS "ICC",
		concat('PT1', dtmn, '00') AS "SHN",
		4 AS "USE", -- municipios
		2516 AS "ISN", -- municipios
		municipio  AS "NAMN",
		TRANSLATE(municipio ,'àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ','aaaaceeeiioooouuAAAACEEEIIOOOOUUU') AS NAMA,
		'por' AS "NLN",
		concat('PT1', LEFT(dtmn,2),'0000') AS "SHNupper",
		sa.ebm_roa AS "ROA",
		NULL AS "PPL",
		(area_ha / 100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM
		master.cont_municipios AS cm
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(cm.geometria, st_transform(sa.geometria, 3763)) AND sa.tipo_sede_administrativa = '4'
UNION ALL
	SELECT -- Freguesias continente
		'PT' AS "ICC",
		concat('PT1', dtmnfr) AS "SHN",
		5 AS "USE", -- freguesias
		2517 AS "ISN", -- freguesia
		designacao_simplificada AS "NAMN",
		TRANSLATE(designacao_simplificada,'àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ','aaaaceeeiioooouuAAAACEEEIIOOOOUUU') AS NAMA,
		'por' AS "NLN",
		concat('PT1', LEFT(dtmnfr,4),'00') AS "SHNupper",
		sa.ebm_roa AS "ROA",
		NULL AS "PPL",
		(area_ha / 100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM
		master.cont_freguesias AS cf
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(cf.geometria, st_transform(sa.geometria, 3763)) AND sa.tipo_sede_administrativa = '5'
UNION ALL
	SELECT -- MADEIRA
		'PT' AS "ICC",
		'PT3000000'AS "SHN",
		2 AS "USE", -- regiao autonoma da madeira
		2513 AS "ISN", -- regiao autonoma
		'Região Autónoma da Madeira'  AS "NAMN",
		'Regiao Autonoma da Madeira' AS NAMA,
		'por' AS "NLN",
		'PT0000000' AS "SHNupper",
		min(sa.ebm_roa) AS "ROA",
		NULL AS "PPL",
		(sum(area_ha)/100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM master.ram_distritos AS d
	LEFT JOIN base.sede_administrativa AS sa
		ON tipo_sede_administrativa = '2' AND st_intersects(d.geometria, st_transform(sa.geometria, 5016))
UNION ALL
	SELECT -- Ilhas
		'PT' AS "ICC",
		concat('PT3', dt, '0000') AS "SHN",
		3 AS "USE", -- distritos ou ilhas
		2515 AS "ISN", -- ilhas
		distrito  AS "NAMN",
		TRANSLATE(distrito ,'àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ','aaaaceeeiioooouuAAAACEEEIIOOOOUUU') AS NAMA,
		'por' AS "NLN",
		'PT3000000' AS "SHNupper",
		sa.ebm_roa AS "ROA",
		NULL AS "PPL",
		(area_ha / 100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM
		master.ram_distritos AS cd
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(cd.geometria, st_transform(sa.geometria, 5016)) AND sa.tipo_sede_administrativa = '3'
UNION ALL
	SELECT -- Municipios Madeira
		'PT' AS "ICC",
		concat('PT3', dtmn, '00') AS "SHN",
		4 AS "USE", -- municipios
		2516 AS "ISN", -- municipios
		municipio  AS "NAMN",
		TRANSLATE(municipio ,'àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ','aaaaceeeiioooouuAAAACEEEIIOOOOUUU') AS NAMA,
		'por' AS "NLN",
		concat('PT3', LEFT(dtmn,2),'0000') AS "SHNupper",
		sa.ebm_roa AS "ROA",
		NULL AS "PPL",
		(area_ha / 100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM
		master.ram_municipios AS cm
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(cm.geometria, st_transform(sa.geometria, 5016)) AND sa.tipo_sede_administrativa = '4'
UNION ALL
	SELECT -- Freguesias Madeira
		'PT' AS "ICC",
		concat('PT3', dtmnfr) AS "SHN",
		5 AS "USE", -- freguesias
		2517 AS "ISN", -- freguesia
		designacao_simplificada AS "NAMN",
		TRANSLATE(designacao_simplificada,'àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ','aaaaceeeiioooouuAAAACEEEIIOOOOUUU') AS NAMA,
		'por' AS "NLN",
		concat('PT3', LEFT(dtmnfr,4),'00') AS "SHNupper",
		sa.ebm_roa AS "ROA",
		NULL AS "PPL",
		(area_ha / 100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM
		master.ram_freguesias AS cf
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(cf.geometria, st_transform(sa.geometria, 5016)) AND sa.tipo_sede_administrativa = '5'
UNION ALL
	SELECT -- ACORES
		'PT' AS "ICC",
		'PT2000000'AS "SHN",
		2 AS "USE", -- regiao autonoma dos acores
		2513 AS "ISN", -- regiao autonoma
		'Região Autónoma dos Açores'  AS "NAMN",
		'Regiao Autonoma dos Acores' AS NAMA,
		'por' AS "NLN",
		'PT0000000' AS "SHNupper",
		min(sa.ebm_roa) AS "ROA",
		NULL AS "PPL",
		(sum(area_ha)/100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM (SELECT * FROM master.raa_oci_distritos UNION ALL SELECT * FROM master.raa_cen_ori_distritos) AS a
	LEFT JOIN base.sede_administrativa AS sa
		ON tipo_sede_administrativa = '2' AND st_intersects(st_transform(a.geometria,4258), sa.geometria) 
UNION ALL -- ACORES OCIDENTAL
	SELECT -- Ilhas
		'PT' AS "ICC",
		concat('PT2', dt, '0000') AS "SHN",
		3 AS "USE", -- distritos ou ilhas
		2515 AS "ISN", -- ilha
		distrito  AS "NAMN",
		TRANSLATE(distrito ,'àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ','aaaaceeeiioooouuAAAACEEEIIOOOOUUU') AS NAMA,
		'por' AS "NLN",
		'PT2000000' AS "SHNupper",
		sa.ebm_roa AS "ROA",
		NULL AS "PPL",
		(area_ha / 100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM
		master.raa_oci_distritos AS cd
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(cd.geometria, st_transform(sa.geometria, 5014)) AND sa.tipo_sede_administrativa = '3'
UNION ALL
	SELECT -- Municipios acores ocidental
		'PT' AS "ICC",
		concat('PT2', dtmn, '00') AS "SHN",
		4 AS "USE", -- municipios
		2516 AS "ISN", -- municipios
		municipio  AS "NAMN",
		TRANSLATE(municipio ,'àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ','aaaaceeeiioooouuAAAACEEEIIOOOOUUU') AS NAMA,
		'por' AS "NLN",
		concat('PT2', LEFT(dtmn,2),'0000') AS "SHNupper",
		sa.ebm_roa AS "ROA",
		NULL AS "PPL",
		(area_ha / 100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM
		master.raa_oci_municipios AS cm
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(cm.geometria, st_transform(sa.geometria, 5014)) AND sa.tipo_sede_administrativa = '4'
UNION ALL
	SELECT -- Freguesias Acores Ocidental
		'PT' AS "ICC",
		concat('PT2', dtmnfr) AS "SHN",
		5 AS "USE", -- freguesias
		2517 AS "ISN", -- freguesia
		designacao_simplificada AS "NAMN",
		TRANSLATE(designacao_simplificada,'àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ','aaaaceeeiioooouuAAAACEEEIIOOOOUUU') AS NAMA,
		'por' AS "NLN",
		concat('PT2', LEFT(dtmnfr,4),'00') AS "SHNupper",
		sa.ebm_roa AS "ROA",
		NULL AS "PPL",
		(area_ha / 100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM
		master.raa_oci_freguesias AS cf
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(cf.geometria, st_transform(sa.geometria, 5014)) AND sa.tipo_sede_administrativa = '5'
UNION ALL
	SELECT -- Ilhas -- Acores central e oriental
		'PT' AS "ICC",
		concat('PT2', dt, '0000') AS "SHN",
		3 AS "USE", -- distritos ou ilhas
		2515 AS "ISN", -- ilhas
		distrito  AS "NAMN",
		TRANSLATE(distrito ,'àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ','aaaaceeeiioooouuAAAACEEEIIOOOOUUU') AS NAMA,
		'por' AS "NLN",
		'PT2000000' AS "SHNupper",
		sa.ebm_roa AS "ROA",
		NULL AS "PPL",
		(area_ha / 100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM
		master.raa_cen_ori_distritos AS cd
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(cd.geometria, st_transform(sa.geometria, 5015)) AND sa.tipo_sede_administrativa = '3'
UNION ALL
	SELECT -- Municipios acores central e oriental
		'PT' AS "ICC",
		concat('PT2', dtmn, '00') AS "SHN",
		4 AS "USE", -- municipios
		2516 AS "ISN", -- municipios
		municipio  AS "NAMN",
		TRANSLATE(municipio ,'àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ','aaaaceeeiioooouuAAAACEEEIIOOOOUUU') AS NAMA,
		'por' AS "NLN",
		concat('PT2', LEFT(dtmn,2),'0000') AS "SHNupper",
		sa.ebm_roa AS "ROA",
		NULL AS "PPL",
		(area_ha / 100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM
		master.raa_cen_ori_municipios AS cm
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(cm.geometria, st_transform(sa.geometria, 5015)) AND sa.tipo_sede_administrativa = '4'
UNION ALL
	SELECT -- Freguesias Acores central e oriental
		'PT' AS "ICC",
		concat('PT2', dtmnfr) AS "SHN",
		5 AS "USE", -- freguesias
		2517 AS "ISN", -- freguesia
		designacao_simplificada AS "NAMN",
		TRANSLATE(designacao_simplificada,'àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ','aaaaceeeiioooouuAAAACEEEIIOOOOUUU') AS NAMA,
		'por' AS "NLN",
		concat('PT2', LEFT(dtmnfr,4),'00') AS "SHNupper",
		sa.ebm_roa AS "ROA",
		NULL AS "PPL",
		(area_ha / 100)::numeric(15,2) AS "ARA",
		NULL AS "effectiveDate"
	FROM
		master.raa_cen_ori_freguesias AS cf
		LEFT JOIN base.sede_administrativa AS sa ON st_intersects(cf.geometria, st_transform(sa.geometria, 5015)) AND sa.tipo_sede_administrativa = '5'
;

DROP MATERIALIZED VIEW IF EXISTS master.ebm_nam CASCADE;
CREATE MATERIALIZED VIEW master.ebm_nam AS
WITH effective_dates AS (
	(SELECT DISTINCT ON (ce.entidade_administrativa) ce.entidade_administrativa, f.data AS fonte_data
	FROM base.cont_centroide_ea AS ce  
	 JOIN base.cont_troco AS t ON (ce.entidade_administrativa = t.ea_direita OR ce.entidade_administrativa = t.ea_esquerda) 
	 JOIN base.lig_cont_troco_fonte AS ltf ON t.identificador = LTF.troco_id
	 JOIN base.fonte AS f ON f.identificador = ltf.fonte_id
	ORDER BY ce.entidade_administrativa, fonte_data DESC NULLS LAST)
	UNION ALL
	(SELECT DISTINCT ON (ce.entidade_administrativa) ce.entidade_administrativa, f.data AS fonte_data
	FROM base.ram_centroide_ea AS ce  
	 JOIN base.ram_troco AS t ON (ce.entidade_administrativa = t.ea_direita OR ce.entidade_administrativa = t.ea_esquerda) 
	 JOIN base.lig_ram_troco_fonte AS ltf ON t.identificador = LTF.troco_id
	 JOIN base.fonte AS f ON f.identificador = ltf.fonte_id
	ORDER BY ce.entidade_administrativa, fonte_data DESC NULLS LAST)
	UNION ALL
	(SELECT DISTINCT ON (ce.entidade_administrativa) ce.entidade_administrativa, f.data AS fonte_data
	FROM base.raa_oci_centroide_ea AS ce  
	 JOIN base.raa_oci_troco AS t ON (ce.entidade_administrativa = t.ea_direita OR ce.entidade_administrativa = t.ea_esquerda) 
	 JOIN base.lig_raa_oci_troco_fonte AS ltf ON t.identificador = LTF.troco_id
	 JOIN base.fonte AS f ON f.identificador = ltf.fonte_id
	ORDER BY ce.entidade_administrativa, fonte_data DESC NULLS LAST)
	UNION ALL
	(SELECT DISTINCT ON (ce.entidade_administrativa) ce.entidade_administrativa, f.data AS fonte_data
	FROM base.raa_cen_ori_centroide_ea AS ce  
	 JOIN base.raa_cen_ori_troco AS t ON (ce.entidade_administrativa = t.ea_direita OR ce.entidade_administrativa = t.ea_esquerda) 
	 JOIN base.lig_raa_cen_ori_troco_fonte AS ltf ON t.identificador = LTF.troco_id
	 JOIN base.fonte AS f ON f.identificador = ltf.fonte_id
	ORDER BY ce.entidade_administrativa, fonte_data DESC NULLS LAST)
)
SELECT 
	ROW_NUMBER() OVER () AS id,
	"ICC",
	"SHN",
	"USE",
	"ISN",
	"NAMN",
	"NAMA",
	"NLN",
	"SHNupper",
	"ROA",
	nlpc.pop_res AS "PPL",
	"ARA",
	fonte_data AS "effectiveDate"
FROM euroboundaries.ebm_nam_temp AS ent
	LEFT JOIN euroboundaries.nuts_lau_pt_2023_censos2021 AS nlpc ON ent."SHN" = nlpc.shn
	LEFT JOIN effective_dates AS ed ON RIGHT(ent."SHN",6) = ed.entidade_administrativa;

DROP MATERIALIZED VIEW IF EXISTS master.ebm_nuts;
CREATE MATERIALIZED VIEW master.ebm_nuts AS
SELECT
	ROW_NUMBER() OVER () AS id,
	'PT' AS "ICC",
	'PT' || CASE WHEN LEFT(ea.codigo,1) = '4' THEN '2'
			WHEN LEFT(ea.codigo,1) = '3' THEN '3'
			ELSE '1' END || ea.codigo AS "SHN",
	ea.codigo AS "LAU",
	'PT' || n3.codigo AS "NUTS3",
	'PT' || n2.codigo AS "NUTS2",
	'PT' || n1.codigo AS "NUTS1"
FROM
	base.entidade_administrativa AS ea
	JOIN base.municipio AS m ON m.codigo = ea.municipio_cod
	JOIN base.nuts3 AS n3 ON n3.codigo = m.nuts3_cod
	JOIN base.nuts2 AS n2 ON n2.codigo = n3.nuts2_cod
	JOIN base.nuts1 AS n1 ON n1.codigo = n2.nuts1_cod;

GRANT ALL ON ALL TABLES IN SCHEMA master TO administrador;
GRANT SELECT ON ALL TABLES IN SCHEMA master TO editor, visualizador;

-- Função para gerar euroboundaries

-- Função para gerar outputs EuroBoundaries consolidados (todas as regiões)
-- ATENÇÃO: NECESSITA DE PERMISSÕES DE ADMINISTRADOR PARA CORRER POIS CRIA SCHEMAS e DÁ PERMISSÕES.
-- parametros:
-- - output_schema (TEXT) - nome do schema com os outputs CAOP, e onde serão guardados as tabelas default 'master'
-- - data_hora (TIMESTAMP) , permite definir um dia e hora para criar um output baseado em dados passados, default hora actual

CREATE OR REPLACE FUNCTION public.gerar_outputs_euroboundaries(output_schema text DEFAULT 'master'::regnamespace, data_hora timestamp DEFAULT now()::timestamp )
RETURNS Boolean AS
$body$
BEGIN
	-- Criar schema euroboundaries se não existir
	EXECUTE 'CREATE SCHEMA IF NOT EXISTS euroboundaries;';

	-- NOTA: A parte dos troços fixos do Euroboundaries está comentada no código original
	-- e depende de importação manual. Mantemos essa estrutura mas comentada.
	/*
	-- Criar uma nova tabela para agregar todos os trocos que vão gerar o Euroboundaries
	EXECUTE FORMAT('
	CREATE TABLE IF NOT EXISTS euroboundaries.ebm_trocos_fixos (LIKE euroboundaries.ebm_boundaries_2024 INCLUDING ALL);
	TRUNCATE TABLE euroboundaries.ebm_trocos_fixos;

	-- Inserir os troços fixos do Euroboundaries (linhas de costa e fronteira com espanha e as linhas tecnicas).
	INSERT INTO euroboundaries.ebm_trocos_fixos
	SELECT * FROM euroboundaries.ebm_boundaries_2024
	WHERE  icc  =  ''ES#PT'' or mol in ( ''1'', ''2'' );

	CREATE INDEX ON euroboundaries.ebm_trocos_fixos USING gist(geom);
	');
	*/

	-- Criar tabelas temporárias do schema base com os dados a usar para uma data específica
	EXECUTE format('
		DROP TABLE IF EXISTS euroboundaries.cont_troco_temp;
		CREATE TABLE euroboundaries.cont_troco_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.cont_troco,  %1$L::timestamp) as t;
		CREATE INDEX ON euroboundaries.cont_troco_temp USING GIST(geometria);

		DROP TABLE IF EXISTS euroboundaries.ram_troco_temp;
		CREATE TABLE euroboundaries.ram_troco_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.ram_troco,  %1$L::timestamp) as t;
		CREATE INDEX ON euroboundaries.ram_troco_temp USING GIST(geometria);

		DROP TABLE IF EXISTS euroboundaries.raa_oci_troco_temp;
		CREATE TABLE euroboundaries.raa_oci_troco_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.raa_oci_troco,  %1$L::timestamp) as t;
		CREATE INDEX ON euroboundaries.raa_oci_troco_temp USING GIST(geometria);
		
		DROP TABLE IF EXISTS euroboundaries.raa_cen_ori_troco_temp;
		CREATE TABLE euroboundaries.raa_cen_ori_troco_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.raa_cen_ori_troco,  %1$L::timestamp) as t;
		CREATE INDEX ON euroboundaries.raa_cen_ori_troco_temp USING GIST(geometria);
		
		DROP TABLE IF EXISTS euroboundaries.cont_centroide_ea_temp;
		CREATE TABLE euroboundaries.cont_centroide_ea_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.cont_centroide_ea,  %1$L::timestamp);
		CREATE INDEX ON euroboundaries.cont_centroide_ea_temp USING GIST(geometria);

		DROP TABLE IF EXISTS euroboundaries.ram_centroide_ea_temp;
		CREATE TABLE euroboundaries.ram_centroide_ea_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.ram_centroide_ea,  %1$L::timestamp);
		CREATE INDEX ON euroboundaries.ram_centroide_ea_temp USING GIST(geometria);

		DROP TABLE IF EXISTS euroboundaries.raa_oci_centroide_ea_temp;
		CREATE TABLE euroboundaries.raa_oci_centroide_ea_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.raa_oci_centroide_ea,  %1$L::timestamp);
		CREATE INDEX ON euroboundaries.raa_oci_centroide_ea_temp USING GIST(geometria);

		DROP TABLE IF EXISTS euroboundaries.raa_cen_ori_centroide_ea_temp;
		CREATE TABLE euroboundaries.raa_cen_ori_centroide_ea_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.ram_centroide_ea,  %1$L::timestamp);
		CREATE INDEX ON euroboundaries.raa_cen_ori_centroide_ea_temp USING GIST(geometria);

		DROP TABLE IF EXISTS euroboundaries.sede_administrativa_temp;
		CREATE TABLE euroboundaries.sede_administrativa_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.sede_administrativa,  %1$L::timestamp);
		CREATE INDEX ON euroboundaries.sede_administrativa_temp USING GIST(geometria);

		DROP TABLE IF EXISTS euroboundaries.lig_cont_troco_fonte_temp;
		CREATE TABLE euroboundaries.lig_cont_troco_fonte_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.lig_cont_troco_fonte, %1$L::timestamp);

		DROP TABLE IF EXISTS euroboundaries.lig_ram_troco_fonte_temp;
		CREATE TABLE euroboundaries.lig_ram_troco_fonte_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.lig_ram_troco_fonte, %1$L::timestamp);

		DROP TABLE IF EXISTS euroboundaries.lig_raa_oci_troco_fonte_temp;
		CREATE TABLE euroboundaries.lig_raa_oci_troco_fonte_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.lig_raa_oci_troco_fonte, %1$L::timestamp);

		DROP TABLE IF EXISTS euroboundaries.lig_raa_cen_ori_troco_fonte_temp;
		CREATE TABLE euroboundaries.lig_raa_cen_ori_troco_fonte_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.lig_raa_cen_ori_troco_fonte, %1$L::timestamp);

		DROP TABLE IF EXISTS euroboundaries.fonte_temp;
		CREATE TABLE euroboundaries.fonte_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.fonte, %1$L::timestamp);

		DROP TABLE IF EXISTS euroboundaries.municipio_temp;
		CREATE TABLE euroboundaries.municipio_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.municipio, %1$L::timestamp);

		DROP TABLE IF EXISTS euroboundaries.nuts3_temp;
		CREATE TABLE euroboundaries.nuts3_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.nuts3, %1$L::timestamp);

		DROP TABLE IF EXISTS euroboundaries.nuts2_temp;
		CREATE TABLE euroboundaries.nuts2_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.nuts2, %1$L::timestamp);

		DROP TABLE IF EXISTS euroboundaries.nuts1_temp;
		CREATE TABLE euroboundaries.nuts1_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.nuts1, %1$L::timestamp);

		DROP TABLE IF EXISTS euroboundaries.entidade_administrativa_temp;
		CREATE TABLE euroboundaries.entidade_administrativa_temp AS
		SELECT * FROM vsr_table_at_time (NULL::base.entidade_administrativa, %1$L::timestamp);
		',
	data_hora);

	-- Poligono EBM total para cortar troços e identificar polígonos gerados que ficam fora do EBM
	EXECUTE '
		DROP TABLE IF EXISTS euroboundaries.ebm_temp_poligono_clip;
		CREATE TABLE euroboundaries.ebm_temp_poligono_clip AS
		SELECT ST_CollectionExtract(ST_polygonize(geom),3)::geometry(multipolygon, 4258) AS geom
		FROM euroboundaries.ebm_trocos_fixos;
		CREATE INDEX ON euroboundaries.ebm_temp_poligono_clip USING GIST(geom);';

	-- Agrupar numa outra tabela, todos os limites interiores vindos da CAOP no mesmo sistema de coordenadas
	-- e após processo de simplificação
	EXECUTE '
		DROP TABLE IF EXISTS euroboundaries.ebm_trocos_caop_generalizados;
		CREATE TABLE IF NOT EXISTS euroboundaries.ebm_trocos_caop_generalizados (LIKE euroboundaries.ebm_boundaries_2024 INCLUDING ALL);';

	-- CONTINENTE
	EXECUTE '
		INSERT INTO euroboundaries.ebm_trocos_caop_generalizados (geom)
		WITH trocos_simplificados AS (
			SELECT 
				st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
			FROM euroboundaries.cont_troco_temp as t 
			WHERE pais = ''PT'' AND significado_linha in (''7'',''9'')),
		clipped as(
			SELECT
				CASE WHEN st_within(ts.geom, c.geom) THEN
					ts.geom
				ELSE
					st_intersection(ts.geom, c.geom)
				END AS geom
			FROM trocos_simplificados AS ts
				JOIN euroboundaries.ebm_temp_poligono_clip AS c 
				ON st_intersects(ts.geom, c.geom))
		SELECT (st_dump(geom)).geom FROM clipped;';

	-- MADEIRA
	EXECUTE '
		INSERT INTO euroboundaries.ebm_trocos_caop_generalizados (geom)
		WITH trocos_simplificados AS (
			SELECT 
				st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
			FROM euroboundaries.ram_troco_temp as t
			WHERE pais = ''PT'' AND significado_linha in (''7'',''9'')),
		clipped as(
			SELECT
				CASE WHEN st_within(ts.geom, c.geom) THEN
					ts.geom
				ELSE
					st_intersection(ts.geom, c.geom)
				END AS geom
			FROM trocos_simplificados AS ts
				JOIN euroboundaries.ebm_temp_poligono_clip AS c 
				ON st_intersects(ts.geom, c.geom))
		SELECT (st_dump(geom)).geom FROM clipped;';

	-- AÇORES OCIDENTAL
	EXECUTE '
		INSERT INTO euroboundaries.ebm_trocos_caop_generalizados (geom)
		WITH trocos_simplificados AS (
			SELECT 
				st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
			FROM euroboundaries.raa_oci_troco_temp as t
			WHERE pais = ''PT'' AND significado_linha in (''7'',''9'')),
		clipped as(
			SELECT
				CASE WHEN st_within(ts.geom, c.geom) THEN
					ts.geom
				ELSE
					st_intersection(ts.geom, c.geom)
				END AS geom
			FROM trocos_simplificados AS ts
				JOIN euroboundaries.ebm_temp_poligono_clip AS c 
				ON st_intersects(ts.geom, c.geom))
		SELECT (st_dump(geom)).geom FROM clipped;';

	-- AÇORES CENTRAL E ORIENTAL
	EXECUTE '
		INSERT INTO euroboundaries.ebm_trocos_caop_generalizados (geom)
		WITH trocos_simplificados AS (
			SELECT 
				st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
			FROM euroboundaries.raa_cen_ori_troco_temp as t
			WHERE pais = ''PT'' AND significado_linha in (''7'',''9'')),
		clipped as(
			SELECT
				CASE WHEN st_within(ts.geom, c.geom) THEN
					ts.geom
				ELSE
					st_intersection(ts.geom, c.geom)
				END AS geom
			FROM trocos_simplificados AS ts
				JOIN euroboundaries.ebm_temp_poligono_clip AS c 
				ON st_intersects(ts.geom, c.geom))
		SELECT (st_dump(geom)).geom FROM clipped;';

	-- Criar índice
	EXECUTE '
		CREATE INDEX ON euroboundaries.ebm_trocos_caop_generalizados USING gist(geom);';

	-- EXISTEM ALGUNS TROCOS QUE SÃO COINCIDENTES COM O LIMITE DO EUROBOUNDARIES e que DEVEM ser eliminados antes de se tentar fazer qualquer tipo de 
	-- ajuste dos endpoints para baterem certo com o euroboundaries.
	EXECUTE '
		DELETE FROM  euroboundaries.ebm_trocos_caop_generalizados AS tcg
		USING euroboundaries.ebm_trocos_fixos AS etf 
		WHERE st_within(tcg.geom, st_buffer(etf.geom,0.0001));';

	-- Criar tabela com todos os endpoints dos limites fixos, que serão mais tarde usados como referência
	EXECUTE '
		DROP TABLE IF EXISTS euroboundaries.ebm_pontos_referencia;
		CREATE TABLE euroboundaries.ebm_pontos_referencia AS
		WITH endpoints AS (
			SELECT ST_StartPoint(geom) AS geom FROM euroboundaries.ebm_trocos_fixos
			UNION
			SELECT ST_EndPoint(geom) AS geom FROM euroboundaries.ebm_trocos_fixos
		)
		SELECT DISTINCT ON (geom) ROW_NUMBER() OVER () AS id, geom::geometry(point, 4258) FROM endpoints;

		CREATE INDEX ON euroboundaries.ebm_pontos_referencia USING gist(geom);';

	-- Criar tabela com pontos dos limites interiores que não toquem em nenhuma outra geometria ou
	-- nem nos limites externos
	EXECUTE '
		DROP TABLE IF EXISTS euroboundaries.ebm_temp_limites_exteriores;

		CREATE TABLE euroboundaries.ebm_temp_limites_exteriores AS
		SELECT
			st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
		FROM euroboundaries.cont_troco_temp as t
		WHERE NOT (pais = ''PT'' AND significado_linha in (''7'',''9''))
		UNION ALL
		SELECT
			st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
		FROM euroboundaries.raa_oci_troco_temp  as t
		WHERE NOT (pais = ''PT'' AND significado_linha in (''7'',''9''))
		UNION ALL
		SELECT
			st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
		FROM euroboundaries.raa_cen_ori_troco_temp as t
		WHERE NOT (pais = ''PT'' AND significado_linha in (''7'',''9''))
		UNION ALL
		SELECT
			st_TRANSFORM(st_simplifyvw(ST_SimplifyPreserveTopology(geometria,5),200),4258) AS geom
		FROM euroboundaries.ram_troco_temp as t
		WHERE NOT (pais = ''PT'' AND significado_linha in (''7'',''9''));

		CREATE INDEX ON euroboundaries.ebm_temp_limites_exteriores USING gist(geom);';

	-- Identificar dangles
	EXECUTE '
		DROP TABLE IF EXISTS euroboundaries.ebm_limites_interiores_dangles;
		CREATE TABLE euroboundaries.ebm_limites_interiores_dangles AS
		WITH endpoints AS (
			SELECT id, ''start'' AS edge, ST_StartPoint(geom) AS geom FROM euroboundaries.ebm_trocos_caop_generalizados
			WHERE NOT st_isclosed(geom)
			UNION
			SELECT id, ''end'' AS edge, ST_EndPoint(geom) AS geom FROM euroboundaries.ebm_trocos_caop_generalizados
			WHERE NOT st_isclosed(geom)
		)
		SELECT DISTINCT ON (ep.id, ep.geom) ep.id, ep.edge, ep.geom::geometry(point, 4258) 
		FROM endpoints AS ep;
		
		CREATE INDEX ON euroboundaries.ebm_limites_interiores_dangles USING gist(geom);

		DELETE 
		FROM euroboundaries.ebm_limites_interiores_dangles
			WHERE 
			NOT EXISTS (SELECT 1 FROM euroboundaries.ebm_temp_limites_exteriores AS le
						WHERE st_intersects(ebm_limites_interiores_dangles.geom, le.geom)) AND 
			EXISTS (
				SELECT 1 FROM euroboundaries.ebm_trocos_caop_generalizados AS e
				WHERE ebm_limites_interiores_dangles.id <> e.id AND ST_intersects(ebm_limites_interiores_dangles.geom, e.geom)
			);';

	-- Ajustar endpoints dos dangles
	EXECUTE '
		UPDATE euroboundaries.ebm_trocos_caop_generalizados AS e
		SET geom = (SELECT st_setpoint(e.geom, 0, d.geom) AS geom
						FROM euroboundaries.ebm_pontos_referencia AS d
						ORDER BY lid.geom <-> d.geom
						LIMIT 1)
		FROM euroboundaries.ebm_limites_interiores_dangles AS lid
		WHERE e.id = lid.id AND lid.edge = ''start'';

		UPDATE euroboundaries.ebm_trocos_caop_generalizados AS e
		SET geom = (SELECT st_setpoint(e.geom, -1, d.geom) AS geom
						FROM euroboundaries.ebm_pontos_referencia AS d
						ORDER BY lid.geom <-> d.geom
						LIMIT 1)
		FROM euroboundaries.ebm_limites_interiores_dangles AS lid
		WHERE e.id = lid.id AND lid.edge = ''end'';';

	-- Criar troços finais
	EXECUTE '
		DROP TABLE IF EXISTS euroboundaries.ebm_trocos_finais;
		CREATE TABLE euroboundaries.ebm_trocos_finais AS 
		WITH todos_trocos AS (
			SELECT geom FROM euroboundaries.ebm_trocos_fixos AS etf 
			UNION ALL
			SELECT geom FROM euroboundaries.ebm_trocos_caop_generalizados AS etcg)
		SELECT (st_dump(st_node(st_collect(geom)))).geom AS geom
		FROM todos_trocos;';

	-- Criar polígonos finais
	EXECUTE '
		DROP TABLE IF EXISTS euroboundaries.ebm_poligonos_finais CASCADE;
		CREATE TABLE euroboundaries.ebm_poligonos_finais (
			id serial PRIMARY KEY,
			geometria geometry(multipolygon, 4258)
		);

		INSERT INTO euroboundaries.ebm_poligonos_finais (geometria)
		WITH poly AS (
			SELECT (st_dump(st_polygonize(geom))).geom AS geom
			FROM euroboundaries.ebm_trocos_finais
		)
		SELECT p.geom
		FROM poly AS p, euroboundaries.ebm_temp_poligono_clip AS c
		WHERE st_intersects(st_pointonsurface(p.geom), c.geom);

		CREATE INDEX ON euroboundaries.ebm_poligonos_finais USING gist(geometria);';

	-- Remover polígonos pequenos
	EXECUTE '
		WITH to_merge AS (
			SELECT DISTINCT ON (pf1.id) pf1.id AS merge_id, pf2.id AS target_id, pf1.geometria AS merge_geom, st_length(st_intersection(pf1.geometria, pf2.geometria)) AS share_boundary
			FROM euroboundaries.ebm_poligonos_finais AS pf1 
				JOIN euroboundaries.ebm_poligonos_finais AS pf2 ON st_intersects(pf1.geometria, pf2.geometria)
			WHERE st_area(pf1.geometria::geography) < 2500 AND st_area(pf2.geometria::geography) >= 2500 AND pf2.id != pf1.id
			ORDER BY pf1.id, st_length(st_intersection(pf1.geometria, pf2.geometria))
		)
		UPDATE euroboundaries.ebm_poligonos_finais
		SET geometria = st_union(geometria, cm.merge_geom)
		FROM to_merge AS cm
		WHERE id = cm.target_id;

		DELETE FROM euroboundaries.ebm_poligonos_finais
		WHERE st_area(geometria::geography) < 2500;';

	-- Obter atributos para os polígonos EBM
	-- Colocar numa unica tabela todos os poligonos da CAOP nos sistema de coordenadas da EBM
	-- E com os atributos adaptados ao Euroboundaries
	EXECUTE '
		DROP TABLE IF EXISTS euroboundaries.caop_areas_administrativas;
		CREATE TABLE euroboundaries.caop_areas_administrativas AS
		SELECT 
			dtmnfr AS entidade_administrativa,
			''1'' AS shn_prefix,
			st_transform(geometria, 4258)::geometry(polygon, 4258) AS geometria
		FROM master.cont_areas_administrativas
		UNION ALL
		SELECT 
			dtmnfr AS entidade_administrativa,
			''3'' AS shn_prefix,
			st_transform(geometria, 4258)::geometry(polygon, 4258) AS geometria
		FROM master.ram_areas_administrativas
		UNION ALL
		SELECT 
			dtmnfr AS entidade_administrativa,
			''2'' AS shn_prefix,
			st_transform(geometria, 4258)::geometry(polygon, 4258) AS geometria
		FROM master.raa_cen_ori_areas_administrativas
		UNION ALL
		SELECT 
			dtmnfr AS entidade_administrativa,
			''2'' AS shn_prefix,
			st_transform(geometria, 4258)::geometry(polygon, 4258) AS geometria
		FROM master.raa_oci_areas_administrativas;

		CREATE INDEX ON euroboundaries.caop_areas_administrativas USING gist(geometria);';

	-- Centroides
	EXECUTE '
	DROP TABLE IF EXISTS euroboundaries.ebm_centroides CASCADE;
	CREATE TABLE euroboundaries.ebm_centroides AS
	SELECT 
		entidade_administrativa,
		tipo_area_administrativa_id,
		''1'' AS shn_prefix,
		st_transform(geometria,4258)::geometry(point,4258) AS geometria
	FROM euroboundaries.cont_centroide_ea_temp AS ce 
	UNION ALL
	SELECT 
		entidade_administrativa,
		tipo_area_administrativa_id,
		''3'' AS shn_prefix,
		st_transform(geometria,4258)::geometry(point,4258) AS geometria
	FROM euroboundaries.ram_centroide_ea_temp AS ce
	UNION ALL
	SELECT 
		entidade_administrativa,
		tipo_area_administrativa_id,
		''2'' AS shn_prefix,
		st_transform(geometria,4258)::geometry(point,4258) AS geometria
	FROM euroboundaries.raa_oci_centroide_ea_temp AS ce
	UNION ALL
	SELECT 
		entidade_administrativa,
		tipo_area_administrativa_id,
		''2'' AS shn_prefix,
		st_transform(geometria,4258)::geometry(point,4258) AS geometria
	FROM euroboundaries.raa_cen_ori_centroide_ea_temp AS ce;

	CREATE INDEX ON euroboundaries.ebm_centroides USING gist(geometria);';

	-- Cruzar polígonos com CAOP - Criação da tabela ebm_a
	EXECUTE FORMAT('
	DROP TABLE IF EXISTS %1$I.ebm_a CASCADE;
	CREATE TABLE %1$I.ebm_a as
	SELECT DISTINCT ON ("InspireId", geometry)
		concat(''_EG.EBM:AA.'',''PT'', caa.shn_prefix, caa.entidade_administrativa) AS "InspireId",
		%2$L::timestamp AS "beginLifeSpanVersion",
		''PT'' AS "ICC",
		concat(''PT'',caa.shn_prefix, caa.entidade_administrativa) AS "SHN",
		ce.tipo_area_administrativa_id AS "TAA",
		st_multi(p.geometria)::geometry(multipolygon, 4258) AS geometry
	FROM euroboundaries.ebm_poligonos_finais AS p
		LEFT JOIN euroboundaries.caop_areas_administrativas AS caa ON (st_intersects(st_pointonsurface(p.geometria),caa.geometria))
		LEFT JOIN euroboundaries.ebm_centroides AS ce ON st_intersects(p.geometria, ce.geometria)
	ORDER BY "InspireId",geometry, "TAA";

	CREATE INDEX ON %1$I.ebm_a USING gist(geometry);', output_schema, data_hora);

	-- Preencher TAA nulos
	EXECUTE FORMAT('
		UPDATE %1$I.ebm_a SET 
		"TAA" = ''3''
		WHERE "TAA" IS NULL;',
		output_schema);

	-- Isolar os troços necessários para gerar as COASTAL WATER
	EXECUTE '
		DROP TABLE IF EXISTS temp.ebm_trocos_finais_para_coastal_water;
		CREATE TABLE temp.ebm_trocos_finais_para_coastal_water AS
		WITH trocos_temp as (
			SELECT geom FROM euroboundaries.ebm_boundaries_2024
			WHERE  mol in (''9'')
			UNION ALL 
			SELECT geom FROM euroboundaries.ebm_trocos_fixos
			WHERE  mol in (''1'',''2'')
		)
		SELECT (st_dump(st_node(st_collect(geom)))).geom AS geom 
		FROM trocos_temp;';

	-- Criação de uma tabela de poligonos para coastal water
	EXECUTE '
		DROP TABLE IF EXISTS temp.ebm_poligonos_finais_coastal_water;
		CREATE TABLE temp.ebm_poligonos_finais_coastal_water (
			id serial PRIMARY KEY,
			geometria geometry(polygon, 4258)
		);

		INSERT INTO temp.ebm_poligonos_finais_coastal_water (geometria)
		WITH poly AS (
			SELECT (st_dump(st_polygonize(geom))).geom AS geom
			FROM temp.ebm_trocos_finais_para_coastal_water
		)
		SELECT p.geom
		FROM poly AS p, euroboundaries.ebm_temp_poligono_clip AS c
		WHERE st_disjoint(st_pointonsurface(p.geom), c.geom);

		CREATE INDEX ON temp.ebm_poligonos_finais_coastal_water USING gist(geometria);';

	-- Inserir coastal water na tabela ebm_a
	EXECUTE FORMAT('
		INSERT INTO %1$I.ebm_a
		SELECT DISTINCT ON ("InspireId", geometry)
			CASE WHEN caa.entidade_administrativa IS NULL THEN ''_EG.EBM:AA.PT0000000''
				ELSE concat(''_EG.EBM:AA.'',''PT'', caa.shn_prefix, caa.entidade_administrativa) END AS "InspireId",
			%2$L::timestamp AS "beginLifeSpanVersion",
			''PT'' AS "ICC",
			CASE WHEN caa.entidade_administrativa IS NULL THEN ''PT0000000''
				ELSE concat(''PT'',caa.shn_prefix, caa.entidade_administrativa) END AS "SHN",
			''5'' AS "TAA",
			st_multi(p.geometria)::geometry(multipolygon, 4258) AS geometry
		FROM temp.ebm_poligonos_finais_coastal_water AS p
		LEFT JOIN euroboundaries.caop_areas_administrativas AS caa ON (st_intersects(st_pointonsurface(p.geometria),caa.geometria));', 
		output_schema, data_hora);

	-- ADICIONAR SUFIXOS PARA OS CASOS DAS Entidades Administrativas com compostas por várias partes
	EXECUTE FORMAT('
		WITH get_suffix AS (
			SELECT 
				"InspireId",
				"TAA",
				geometry,
				''.'' || (CASE WHEN COUNT(*) OVER (PARTITION BY "InspireId") > 1 THEN
					ROW_NUMBER() OVER (PARTITION BY "InspireId" ORDER BY "TAA", st_area(geometry) DESC)
				ELSE NULL END)::text AS suffix
			FROM 
				%1$I.ebm_a
		)
		UPDATE %1$I.ebm_a
		SET "InspireId" = concat(%1$I.ebm_a."InspireId", suffix)
		FROM get_suffix AS gf 
		WHERE %1$I.ebm_a."InspireId" = gf."InspireId" AND %1$I.ebm_a.geometry = gf.geometry;', 
		output_schema);

	-- Criar tabela ebm_nam_temp
	EXECUTE format('
		DROP TABLE IF EXISTS euroboundaries.ebm_nam_temp CASCADE;
		CREATE TABLE euroboundaries.ebm_nam_temp as
		WITH all_areas AS (
			SELECT sum(area_ha) AS area_ha FROM %1$I.cont_distritos
			UNION ALL
			SELECT sum(area_ha) AS area_ha FROM %1$I.ram_distritos
			UNION ALL
			SELECT sum(area_ha) AS area_ha FROM %1$I.raa_oci_distritos
			UNION ALL
			SELECT sum(area_ha) AS area_ha FROM %1$I.raa_cen_ori_distritos
		)
			SELECT -- Portugal
				''PT'' AS "ICC",
				''PT0000000''AS "SHN",
				1 AS "USE", -- continente
				2511 AS "ISN", -- Republica
				''Portugal''  AS "NAMN",
				''Portugal'' AS "NAMA",
				''por'' AS "NLN",
				''UNK'' AS "SHNupper",
				min(sa.ebm_roa) AS "ROA",
				NULL AS "PPL",
				(sum(area_ha)/100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM all_areas, euroboundaries.sede_administrativa_temp AS sa 
			WHERE tipo_sede_administrativa = ''1''
		UNION ALL
			SELECT -- Continente
				''PT'' AS "ICC",
				''PT1000000''AS "SHN",
				2 AS "USE", -- continente
				2512 AS "ISN", -- continente
				''Continente''  AS "NAMN",
				''Continente'' AS NAMA,
				''por'' AS "NLN",
				''PT0000000'' AS "SHNupper",
				min(sa.ebm_roa) AS "ROA",
				NULL AS "PPL",
				(sum(area_ha)/100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM %1$I.cont_distritos
			LEFT JOIN euroboundaries.sede_administrativa_temp AS sa ON tipo_sede_administrativa = ''1''
		UNION ALL
			SELECT -- Distritos continente
				''PT'' AS "ICC",
				concat(''PT1'', dt, ''0000'') AS "SHN",
				3 AS "USE", -- distritos
				2514 AS "ISN", -- distritos
				distrito  AS "NAMN",
				TRANSLATE(distrito ,''àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ'',''aaaaceeeiioooouuAAAACEEEIIOOOOUUU'') AS NAMA,
				''por'' AS "NLN",
				''PT1000000'' AS "SHNupper",
				sa.ebm_roa AS "ROA",
				NULL AS "PPL",
				(area_ha / 100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM
				%1$I.cont_distritos AS cd
				LEFT JOIN euroboundaries.sede_administrativa_temp AS sa ON st_intersects(cd.geometria, st_transform(sa.geometria, 3763)) AND sa.tipo_sede_administrativa = ''3''
		UNION ALL
			SELECT -- Municipios Continente
				''PT'' AS "ICC",
				concat(''PT1'', dtmn, ''00'') AS "SHN",
				4 AS "USE", -- municipios
				2516 AS "ISN", -- municipios
				municipio  AS "NAMN",
				TRANSLATE(municipio ,''àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ'',''aaaaceeeiioooouuAAAACEEEIIOOOOUUU'') AS NAMA,
				''por'' AS "NLN",
				concat(''PT1'', LEFT(dtmn,2),''0000'') AS "SHNupper",
				sa.ebm_roa AS "ROA",
				NULL AS "PPL",
				(area_ha / 100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM
				%1$I.cont_municipios AS cm
				LEFT JOIN euroboundaries.sede_administrativa_temp AS sa ON st_intersects(cm.geometria, st_transform(sa.geometria, 3763)) AND sa.tipo_sede_administrativa = ''4''
		UNION ALL
			SELECT -- Freguesias continente
				''PT'' AS "ICC",
				concat(''PT1'', dtmnfr) AS "SHN",
				5 AS "USE", -- freguesias
				2517 AS "ISN", -- freguesia
				designacao_simplificada AS "NAMN",
				TRANSLATE(designacao_simplificada,''àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ'',''aaaaceeeiioooouuAAAACEEEIIOOOOUUU'') AS NAMA,
				''por'' AS "NLN",
				concat(''PT1'', LEFT(dtmnfr,4),''00'') AS "SHNupper",
				sa.ebm_roa AS "ROA",
				NULL AS "PPL",
				(area_ha / 100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM
				%1$I.cont_freguesias AS cf
				LEFT JOIN euroboundaries.sede_administrativa_temp AS sa ON st_intersects(cf.geometria, st_transform(sa.geometria, 3763)) AND sa.tipo_sede_administrativa = ''5''
		UNION ALL
			SELECT -- MADEIRA
				''PT'' AS "ICC",
				''PT3000000''AS "SHN",
				2 AS "USE", -- regiao autonoma da madeira
				2513 AS "ISN", -- regiao autonoma
				''Região Autónoma da Madeira''  AS "NAMN",
				''Regiao Autonoma da Madeira'' AS NAMA,
				''por'' AS "NLN",
				''PT0000000'' AS "SHNupper",
				min(sa.ebm_roa) AS "ROA",
				NULL AS "PPL",
				(sum(area_ha)/100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM %1$I.ram_distritos AS d
			LEFT JOIN euroboundaries.sede_administrativa_temp AS sa
				ON tipo_sede_administrativa = ''2'' AND st_intersects(d.geometria, st_transform(sa.geometria, 5016))
		UNION ALL
			SELECT -- Ilhas Madeira
				''PT'' AS "ICC",
				concat(''PT3'', dt, ''0000'') AS "SHN",
				3 AS "USE", -- distritos ou ilhas
				2515 AS "ISN", -- ilhas
				distrito  AS "NAMN",
				TRANSLATE(distrito ,''àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ'',''aaaaceeeiioooouuAAAACEEEIIOOOOUUU'') AS NAMA,
				''por'' AS "NLN",
				''PT3000000'' AS "SHNupper",
				sa.ebm_roa AS "ROA",
				NULL AS "PPL",
				(area_ha / 100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM
				%1$I.ram_distritos AS cd
				LEFT JOIN euroboundaries.sede_administrativa_temp AS sa ON st_intersects(cd.geometria, st_transform(sa.geometria, 5016)) AND sa.tipo_sede_administrativa = ''3''
		UNION ALL
			SELECT -- Municipios Madeira
				''PT'' AS "ICC",
				concat(''PT3'', dtmn, ''00'') AS "SHN",
				4 AS "USE", -- municipios
				2516 AS "ISN", -- municipios
				municipio  AS "NAMN",
				TRANSLATE(municipio ,''àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ'',''aaaaceeeiioooouuAAAACEEEIIOOOOUUU'') AS NAMA,
				''por'' AS "NLN",
				concat(''PT3'', LEFT(dtmn,2),''0000'') AS "SHNupper",
				sa.ebm_roa AS "ROA",
				NULL AS "PPL",
				(area_ha / 100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM
				%1$I.ram_municipios AS cm
				LEFT JOIN euroboundaries.sede_administrativa_temp AS sa ON st_intersects(cm.geometria, st_transform(sa.geometria, 5016)) AND sa.tipo_sede_administrativa = ''4''
		UNION ALL
			SELECT -- Freguesias Madeira
				''PT'' AS "ICC",
				concat(''PT3'', dtmnfr) AS "SHN",
				5 AS "USE", -- freguesias
				2517 AS "ISN", -- freguesia
				designacao_simplificada AS "NAMN",
				TRANSLATE(designacao_simplificada,''àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ'',''aaaaceeeiioooouuAAAACEEEIIOOOOUUU'') AS NAMA,
				''por'' AS "NLN",
				concat(''PT3'', LEFT(dtmnfr,4),''00'') AS "SHNupper",
				sa.ebm_roa AS "ROA",
				NULL AS "PPL",
				(area_ha / 100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM
				%1$I.ram_freguesias AS cf
				LEFT JOIN euroboundaries.sede_administrativa_temp AS sa ON st_intersects(cf.geometria, st_transform(sa.geometria, 5016)) AND sa.tipo_sede_administrativa = ''5''
		UNION ALL
			SELECT -- ACORES
				''PT'' AS "ICC",
				''PT2000000''AS "SHN",
				2 AS "USE", -- regiao autonoma dos acores
				2513 AS "ISN", -- regiao autonoma
				''Região Autónoma dos Açores''  AS "NAMN",
				''Regiao Autonoma dos Acores'' AS NAMA,
				''por'' AS "NLN",
				''PT0000000'' AS "SHNupper",
				min(sa.ebm_roa) AS "ROA",
				NULL AS "PPL",
				(sum(area_ha)/100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM (SELECT * FROM %1$I.raa_oci_distritos UNION ALL SELECT * FROM %1$I.raa_cen_ori_distritos) AS a
			LEFT JOIN euroboundaries.sede_administrativa_temp AS sa
				ON tipo_sede_administrativa = ''2'' AND st_intersects(st_transform(a.geometria,4258), sa.geometria) 
		UNION ALL -- ACORES OCIDENTAL
			SELECT -- Ilhas
				''PT'' AS "ICC",
				concat(''PT2'', dt, ''0000'') AS "SHN",
				3 AS "USE", -- distritos ou ilhas
				2515 AS "ISN", -- ilha
				distrito  AS "NAMN",
				TRANSLATE(distrito ,''àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ'',''aaaaceeeiioooouuAAAACEEEIIOOOOUUU'') AS NAMA,
				''por'' AS "NLN",
				''PT2000000'' AS "SHNupper",
				sa.ebm_roa AS "ROA",
				NULL AS "PPL",
				(area_ha / 100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM
				%1$I.raa_oci_distritos AS cd
				LEFT JOIN euroboundaries.sede_administrativa_temp AS sa ON st_intersects(cd.geometria, st_transform(sa.geometria, 5014)) AND sa.tipo_sede_administrativa = ''3''
		UNION ALL
			SELECT -- Municipios acores ocidental
				''PT'' AS "ICC",
				concat(''PT2'', dtmn, ''00'') AS "SHN",
				4 AS "USE", -- municipios
				2516 AS "ISN", -- municipios
				municipio  AS "NAMN",
				TRANSLATE(municipio ,''àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ'',''aaaaceeeiioooouuAAAACEEEIIOOOOUUU'') AS NAMA,
				''por'' AS "NLN",
				concat(''PT2'', LEFT(dtmn,2),''0000'') AS "SHNupper",
				sa.ebm_roa AS "ROA",
				NULL AS "PPL",
				(area_ha / 100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM
				%1$I.raa_oci_municipios AS cm
				LEFT JOIN euroboundaries.sede_administrativa_temp AS sa ON st_intersects(cm.geometria, st_transform(sa.geometria, 5014)) AND sa.tipo_sede_administrativa = ''4''
		UNION ALL
			SELECT -- Freguesias Acores Ocidental
				''PT'' AS "ICC",
				concat(''PT2'', dtmnfr) AS "SHN",
				5 AS "USE", -- freguesias
				2517 AS "ISN", -- freguesia
				designacao_simplificada AS "NAMN",
				TRANSLATE(designacao_simplificada,''àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ'',''aaaaceeeiioooouuAAAACEEEIIOOOOUUU'') AS NAMA,
				''por'' AS "NLN",
				concat(''PT2'', LEFT(dtmnfr,4),''00'') AS "SHNupper",
				sa.ebm_roa AS "ROA",
				NULL AS "PPL",
				(area_ha / 100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM
				%1$I.raa_oci_freguesias AS cf
				LEFT JOIN euroboundaries.sede_administrativa_temp AS sa ON st_intersects(cf.geometria, st_transform(sa.geometria, 5014)) AND sa.tipo_sede_administrativa = ''5''
		UNION ALL
			SELECT -- Ilhas Acores central e oriental
				''PT'' AS "ICC",
				concat(''PT2'', dt, ''0000'') AS "SHN",
				3 AS "USE", -- distritos ou ilhas
				2515 AS "ISN", -- ilhas
				distrito  AS "NAMN",
				TRANSLATE(distrito ,''àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ'',''aaaaceeeiioooouuAAAACEEEIIOOOOUUU'') AS NAMA,
				''por'' AS "NLN",
				''PT2000000'' AS "SHNupper",
				sa.ebm_roa AS "ROA",
				NULL AS "PPL",
				(area_ha / 100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM
				%1$I.raa_cen_ori_distritos AS cd
				LEFT JOIN euroboundaries.sede_administrativa_temp AS sa ON st_intersects(cd.geometria, st_transform(sa.geometria, 5015)) AND sa.tipo_sede_administrativa = ''3''
		UNION ALL
			SELECT -- Municipios acores central e oriental
				''PT'' AS "ICC",
				concat(''PT2'', dtmn, ''00'') AS "SHN",
				4 AS "USE", -- municipios
				2516 AS "ISN", -- municipios
				municipio  AS "NAMN",
				TRANSLATE(municipio ,''àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ'',''aaaaceeeiioooouuAAAACEEEIIOOOOUUU'') AS NAMA,
				''por'' AS "NLN",
				concat(''PT2'', LEFT(dtmn,2),''0000'') AS "SHNupper",
				sa.ebm_roa AS "ROA",
				NULL AS "PPL",
				(area_ha / 100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM
				%1$I.raa_cen_ori_municipios AS cm
				LEFT JOIN euroboundaries.sede_administrativa_temp AS sa ON st_intersects(cm.geometria, st_transform(sa.geometria, 5015)) AND sa.tipo_sede_administrativa = ''4''
		UNION ALL
			SELECT -- Freguesias Acores central e oriental
				''PT'' AS "ICC",
				concat(''PT2'', dtmnfr) AS "SHN",
				5 AS "USE", -- freguesias
				2517 AS "ISN", -- freguesia
				designacao_simplificada AS "NAMN",
				TRANSLATE(designacao_simplificada,''àáãâçéêèìíóòõôúùÀÁÃÂÇÉÊÈÌÍÓÒÕÔÚÙ'',''aaaaceeeiioooouuAAAACEEEIIOOOOUUU'') AS NAMA,
				''por'' AS "NLN",
				concat(''PT2'', LEFT(dtmnfr,4),''00'') AS "SHNupper",
				sa.ebm_roa AS "ROA",
				NULL AS "PPL",
				(area_ha / 100)::numeric(15,2) AS "ARA",
				NULL AS "effectiveDate"
			FROM
				%1$I.raa_cen_ori_freguesias AS cf
				LEFT JOIN euroboundaries.sede_administrativa_temp AS sa ON st_intersects(cf.geometria, st_transform(sa.geometria, 5015)) AND sa.tipo_sede_administrativa = ''5''
		;',
		output_schema, data_hora);

	-- Criar tabela final master.ebm_nam
	EXECUTE FORMAT('
		DROP TABLE IF EXISTS %1$I.ebm_nam CASCADE;
		CREATE TABLE %1$I.ebm_nam AS
		WITH effective_dates AS (
			(SELECT DISTINCT ON (ce.entidade_administrativa) ce.entidade_administrativa, f.data AS fonte_data
			FROM euroboundaries.cont_centroide_ea_temp AS ce  
			JOIN euroboundaries.cont_troco_temp AS t ON (ce.entidade_administrativa = t.ea_direita OR ce.entidade_administrativa = t.ea_esquerda) 
			JOIN euroboundaries.lig_cont_troco_fonte_temp AS ltf ON t.identificador = LTF.troco_id
			JOIN euroboundaries.fonte_temp AS f ON f.identificador = ltf.fonte_id
			ORDER BY ce.entidade_administrativa, fonte_data DESC NULLS LAST)
			UNION ALL
			(SELECT DISTINCT ON (ce.entidade_administrativa) ce.entidade_administrativa, f.data AS fonte_data
			FROM euroboundaries.ram_centroide_ea_temp AS ce  
			JOIN euroboundaries.ram_troco_temp AS t ON (ce.entidade_administrativa = t.ea_direita OR ce.entidade_administrativa = t.ea_esquerda) 
			JOIN euroboundaries.lig_ram_troco_fonte_temp AS ltf ON t.identificador = LTF.troco_id
			JOIN euroboundaries.fonte_temp AS f ON f.identificador = ltf.fonte_id
			ORDER BY ce.entidade_administrativa, fonte_data DESC NULLS LAST)
			UNION ALL
			(SELECT DISTINCT ON (ce.entidade_administrativa) ce.entidade_administrativa, f.data AS fonte_data
			FROM euroboundaries.raa_oci_centroide_ea_temp AS ce  
			JOIN euroboundaries.raa_oci_troco_temp AS t ON (ce.entidade_administrativa = t.ea_direita OR ce.entidade_administrativa = t.ea_esquerda) 
			JOIN euroboundaries.lig_raa_oci_troco_fonte_temp AS ltf ON t.identificador = LTF.troco_id
			JOIN euroboundaries.fonte_temp AS f ON f.identificador = ltf.fonte_id
			ORDER BY ce.entidade_administrativa, fonte_data DESC NULLS LAST)
			UNION ALL
			(SELECT DISTINCT ON (ce.entidade_administrativa) ce.entidade_administrativa, f.data AS fonte_data
			FROM euroboundaries.raa_cen_ori_centroide_ea_temp AS ce  
			JOIN euroboundaries.raa_cen_ori_troco_temp AS t ON (ce.entidade_administrativa = t.ea_direita OR ce.entidade_administrativa = t.ea_esquerda) 
			JOIN euroboundaries.lig_raa_cen_ori_troco_fonte_temp AS ltf ON t.identificador = LTF.troco_id
			JOIN euroboundaries.fonte_temp AS f ON f.identificador = ltf.fonte_id
			ORDER BY ce.entidade_administrativa, fonte_data DESC NULLS LAST)
		)
		SELECT 
			ROW_NUMBER() OVER () AS id,
			"ICC",
			"SHN",
			"USE",
			"ISN",
			"NAMN",
			"NAMA",
			"NLN",
			"SHNupper",
			"ROA",
			nlpc.pop_res AS "PPL",
			"ARA",
			fonte_data AS "effectiveDate"
		FROM euroboundaries.ebm_nam_temp AS ent
			LEFT JOIN euroboundaries.nuts_lau_pt_2023_censos2021 AS nlpc ON ent."SHN" = nlpc.shn
			LEFT JOIN effective_dates AS ed ON RIGHT(ent."SHN",6) = ed.entidade_administrativa;', 
		output_schema);

	-- Criar tabela master.ebm_nuts
	EXECUTE FORMAT('
	DROP TABLE IF EXISTS %1$I.ebm_nuts;
	CREATE TABLE %1$I.ebm_nuts AS
	SELECT
		ROW_NUMBER() OVER () AS id,
		''PT'' AS "ICC",
		''PT'' || CASE WHEN LEFT(ea.codigo,1) = ''4'' THEN ''2''
				WHEN LEFT(ea.codigo,1) = ''3'' THEN ''3''
				ELSE ''1'' END || ea.codigo AS "SHN",
		ea.codigo AS "LAU",
		''PT'' || n3.codigo AS "NUTS3",
		''PT'' || n2.codigo AS "NUTS2",
		''PT'' || n1.codigo AS "NUTS1"
	FROM
		euroboundaries.entidade_administrativa_temp AS ea
		JOIN euroboundaries.municipio_temp AS m ON m.codigo = ea.municipio_cod
		JOIN euroboundaries.nuts3_temp AS n3 ON n3.codigo = m.nuts3_cod
		JOIN euroboundaries.nuts2_temp AS n2 ON n2.codigo = n3.nuts2_cod
		JOIN euroboundaries.nuts1_temp AS n1 ON n1.codigo = n2.nuts1_cod;', 
	output_schema);

	-- Dar permissões
	EXECUTE FORMAT('
		GRANT ALL ON ALL TABLES IN SCHEMA %1$I TO administrador;
		GRANT SELECT ON ALL TABLES IN SCHEMA %1$I TO editor, visualizador;
		GRANT ALL ON ALL TABLES IN SCHEMA euroboundaries TO administrador;
		GRANT SELECT ON ALL TABLES IN SCHEMA euroboundaries TO editor, visualizador;', 
		output_schema);

	RETURN TRUE;
END;
$body$
LANGUAGE 'plpgsql';

-- Versão alternativa que aceita versão em vez de timestamp
CREATE OR REPLACE FUNCTION public.gerar_outputs_euroboundaries(output_schema text DEFAULT 'master'::regnamespace, output_versao TEXT DEFAULT '')
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
		EXECUTE format('select public.gerar_outputs_euroboundaries(%L, %L::timestamp);',output_schema, data_hora);	
		RETURN TRUE;
	END CASE;

END;
$body$
LANGUAGE 'plpgsql';

-- TESTES

-- Gerar camadas euroboundaries para o schema master (versão atual)
SELECT gerar_outputs_euroboundaries('master', now()::timestamp);

-- Gerar camadas euroboundaries para uma versão específica
SELECT gerar_outputs_euroboundaries('CAOP2024.1', 'v2024.01');