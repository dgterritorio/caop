-- Outputs para EuroBoundaries

CREATE SCHEMA euroboundaries;

-- Foram importados manualmente os troços do Euroboundaries 2024 para usar como referência

-- Criar uma nova tabela para agregar todos os trocos que vão gerar o Euroboundaries
CREATE TABLE IF NOT EXISTS euroboundaries.ebm_trocos_fixos (LIKE euroboundaries.ebm_boundaries_2024 INCLUDING ALL);
TRUNCATE TABLE euroboundaries.ebm_trocos_fixos;

-- Inserir os troços fixos do Euroboundaries (linhas de costa e fronteira com espanha e as linhas tecnicas).
INSERT INTO euroboundaries.ebm_trocos_fixos
SELECT * FROM euroboundaries.ebm_boundaries_2024
WHERE  icc  =  'ES#PT' or mol in ( '1', '2' );

CREATE INDEX ON euroboundaries.ebm_trocos_fixos USING gist(geom);

-- Poligono EBM total para cortar troços e identificar polígonos gerados que ficam fora do EBM
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
CREATE TABLE euroboundaries.ebm_pontos_referencia AS
WITH endpoints AS (
    SELECT ST_StartPoint(geom) AS geom FROM euroboundaries.ebm_trocos_fixos
    UNION
    SELECT ST_EndPoint(geom) AS geom FROM euroboundaries.ebm_trocos_fixos
)
SELECT DISTINCT ON (geom) ROW_NUMBER() OVER () AS id, geom::geometry(point, 4258) FROM endpoints;

CREATE INDEX ON euroboundaries.ebm_pontos_referencia USING gist(geom);

-- Criar tabela com pontos dos limites interiores que não toquem em nenhuma outra geometria
-- Primeiro recolhetos todos os startpoints e end points, depois tiramos aqueles que não estão
-- desconectados de outros troços.
-- São excluidos deste processo geometrias fechadas.

DROP TABLE IF EXISTS euroboundaries.ebm_limites_interiores_dangles;
CREATE TABLE euroboundaries.ebm_limites_interiores_dangles AS
WITH endpoints AS (
    SELECT id, 'start' AS edge, ST_StartPoint(geom) AS geom FROM euroboundaries.ebm_trocos_caop_generalizados
    WHERE NOT st_isclosed(geom)
    UNION
    SELECT id, 'end' AS edge, ST_EndPoint(geom) AS geom FROM euroboundaries.ebm_trocos_caop_generalizados
    WHERE NOT st_isclosed(geom)
)
SELECT DISTINCT ON (geom) id, edge, geom::geometry(point, 4258) FROM endpoints;

CREATE INDEX ON euroboundaries.ebm_limites_interiores_dangles USING gist(geom);

DELETE FROM euroboundaries.ebm_limites_interiores_dangles
WHERE EXISTS (
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
	geometria geometry(polygon, 4258)
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

-- Obter atributos para os polígonos EBM gerados
-- Colocar numa unica tabela todos os poligonos da CAOP nos sistema de coordenadas da EBM
-- E com os atributos adaptados ao Euroboundaries
DROP TABLE IF EXISTS euroboundaries.caop_areas_administrativas;
CREATE TABLE euroboundaries.caop_areas_administrativas AS
SELECT 
	dicofre AS entidade_administrativa,
	'1' AS shn_prefix,
	st_transform(geometria, 4258)::geometry(polygon, 4258) AS geometria
FROM master.cont_areas_administrativas
UNION ALL
SELECT 
	dicofre AS entidade_administrativa,
	'3' AS shn_prefix,
	st_transform(geometria, 4258)::geometry(polygon, 4258) AS geometria
FROM master.ram_areas_administrativas
UNION ALL
SELECT 
	dicofre AS entidade_administrativa,
	'2' AS shn_prefix,
	st_transform(geometria, 4258)::geometry(polygon, 4258) AS geometria
FROM master.raa_cen_ori_areas_administrativas
UNION ALL
SELECT 
	dicofre AS entidade_administrativa,
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
SELECT
	concat('_EG.EBM:AA.','PT', caa.shn_prefix, caa.entidade_administrativa) AS "InspireId",
	'2022-12-31'::timestamp AS "beginLifeSpanVersion",
	'PT' AS "ICC",
	concat('PT',caa.shn_prefix, caa.entidade_administrativa) AS "SHN",
	ce.tipo_area_administrativa_id AS "TAA",
	p.geometria::geometry(multipolygon, 4258) AS geometria
FROM euroboundaries.ebm_poligonos_finais AS p
	LEFT JOIN euroboundaries.caop_areas_administrativas AS caa ON (st_intersects(st_pointonsurface(p.geometria),caa.geometria))
	LEFT JOIN euroboundaries.ebm_centroides AS ce ON st_intersects(p.geometria, ce.geometria);

CREATE INDEX ON master.ebm_a USING gist(geometria);

-- Algumas ilhas criadas no EBM não obtêm TAA pois na CAOP estão agregadas à area administrativa
-- Preencher como area secundaria

UPDATE master.ebm_a SET 
"TAA" = '3'
WHERE "TAA" IS NULL;


-- Criar tabela ebm_nam com base da CAOP
-- De notar que a área descrita nesta tabela è a área real tirada da CAOP
-- E não a area dos polígonos gerados para o Euroboundaries
DROP MATERIALIZED VIEW euroboundaries.ebm_nam_temp CASCADE;
CREATE MATERIALIZED VIEW euroboundaries.ebm_nam_temp as
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
	1 AS "USE", -- continente
	2511 AS "ISN", -- Republica
	'Portugal'  AS "NAMN",
	'Portugal' AS "NAMA",
	'por' AS "NLN",
	'UNK' AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(sum(area_ha)/100)::numeric(15,2) AS "ARA",
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
	'PT' AS "ICC",
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
	'PT' AS "ICC",
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
	2513 AS "ISN", -- regiao autonoma
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
	2515 AS "ISN", -- ilhas
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
	'PT' AS "ICC",
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
	'PT' AS "ICC",
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
	master.ram_freguesias AS cf
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
	NULL AS "ROA",
	NULL AS "PPL",
	(sum(area_ha)/100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM (SELECT * FROM master.raa_oci_distritos UNION ALL SELECT * FROM master.raa_cen_ori_distritos) AS a
UNION ALL -- ACORES OCIDENTAL
SELECT -- Ilhas
	'PT' AS "ICC",
	concat('PT2', di, '0000') AS "SHN",
	3 AS "USE", -- distritos ou ilhas
	2515 AS "ISN", -- ilha
	distrito  AS "NAMN",
	TRANSLATE(distrito ,'àáãâçéêèìíóòõôúù','aaaaceeeiioooouu') AS NAMA,
	'por' AS "NLN",
	'PT2000000' AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(area_ha / 100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM
	master.raa_oci_distritos AS cd
UNION ALL
SELECT -- Municipios acores ocidental
	'PT' AS "ICC",
	concat('PT2', dico, '00') AS "SHN",
	4 AS "USE", -- municipios
	2516 AS "ISN", -- municipios
	municipio  AS "NAMN",
	TRANSLATE(municipio ,'àáãâçéêèìíóòõôúù','aaaaceeeiioooouu') AS NAMA,
	'por' AS "NLN",
	concat('PT2', LEFT(dico,2),'0000') AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(area_ha / 100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM
	master.raa_oci_municipios AS cf
UNION ALL
SELECT -- Freguesias Acores Ocidental
	'PT' AS "ICC",
	concat('PT2', dicofre) AS "SHN",
	5 AS "USE", -- freguesias
	2517 AS "ISN", -- freguesia
	designacao_simplificada AS "NAMN",
	TRANSLATE(designacao_simplificada,'àáãâçéêèìíóòõôúù','aaaaceeeiioooouu') AS NAMA,
	'por' AS "NLN",
	concat('PT2', LEFT(dicofre,4),'00') AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(area_ha / 100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM
	master.raa_oci_freguesias AS cf
UNION ALL
SELECT -- Ilhas -- Acores central e oriental
	'PT' AS "ICC",
	concat('PT2', di, '0000') AS "SHN",
	3 AS "USE", -- distritos ou ilhas
	2515 AS "ISN", -- ilhas
	distrito  AS "NAMN",
	TRANSLATE(distrito ,'àáãâçéêèìíóòõôúù','aaaaceeeiioooouu') AS NAMA,
	'por' AS "NLN",
	'PT2000000' AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(area_ha / 100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM
	master.raa_cen_ori_distritos AS cd
UNION ALL
SELECT -- Municipios acores central e oriental
	'PT' AS "ICC",
	concat('PT2', dico, '00') AS "SHN",
	4 AS "USE", -- municipios
	2516 AS "ISN", -- municipios
	municipio  AS "NAMN",
	TRANSLATE(municipio ,'àáãâçéêèìíóòõôúù','aaaaceeeiioooouu') AS NAMA,
	'por' AS "NLN",
	concat('PT2', LEFT(dico,2),'0000') AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(area_ha / 100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM
	master.raa_cen_ori_municipios AS cf
UNION ALL
SELECT -- Freguesias Acores central e oriental
	'PT' AS "ICC",
	concat('PT2', dicofre) AS "SHN",
	5 AS "USE", -- freguesias
	2517 AS "ISN", -- freguesia
	designacao_simplificada AS "NAMN",
	TRANSLATE(designacao_simplificada,'àáãâçéêèìíóòõôúù','aaaaceeeiioooouu') AS NAMA,
	'por' AS "NLN",
	concat('PT2', LEFT(dicofre,4),'00') AS "SHNupper",
	NULL AS "ROA",
	NULL AS "PPL",
	(area_ha / 100)::numeric(15,2) AS "ARA",
	NULL AS "effectiveDate"
FROM
	master.raa_cen_ori_freguesias AS cf;

DROP MATERIALIZED VIEW IF EXISTS master.ebm_nam CASCADE;
CREATE MATERIALIZED VIEW master.ebm_nam as
SELECT 
	ROW_NUMBER() OVER () AS id,
	"ICC",
	"SHN",
	"USE",
	"ISN",
	"NAMN",
	"NLN",
	"SHNupper",
	"ROA",
	nlpc.pop_res AS "PPL",
	"ARA",
	"effectiveDate"
FROM euroboundaries.ebm_nam_temp AS ent
	LEFT JOIN euroboundaries.nuts_lau_pt_2023_censos2021 AS nlpc ON ent."SHN" = nlpc.shn;

SELECT * FROM euroboundaries.ebm_nam_temp

GRANT ALL ON ALL TABLES IN SCHEMA master TO administrador;
GRANT SELECT ON ALL TABLES IN SCHEMA master TO editor, visualizador;

