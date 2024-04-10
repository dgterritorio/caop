-- Ferramentas para validação de centroides e troços editados.

CREATE SCHEMA IF NOT EXISTS validacao;

--------------------------------------------------------------------------------------------------------------------------------
--                                                              CONTINENTE
--------------------------------------------------------------------------------------------------------------------------------

-- trocos com geometria inválida
DROP MATERIALIZED VIEW IF EXISTS validacao.cont_trocos_geometria_invalida_pontos;

CREATE MATERIALIZED VIEW validacao.cont_trocos_geometria_invalida_pontos AS
WITH not_simple AS (
SELECT ct.identificador, (ST_DumpSegments(ct.geometria)).PATH[1] AS seg_id, (ST_DumpSegments(ct.geometria)).geom AS geometria
FROM base.cont_troco AS ct
WHERE NOT st_issimple(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, ns1.identificador, st_intersection(ns1.geometria, ns2.geometria)::geometry(point, 3763) AS geometria
FROM not_simple AS ns1 JOIN not_simple AS ns2 ON (NOT st_relate(ns1.geometria, ns2.geometria,'FF*F*****'))
WHERE ns1.identificador = ns2.identificador AND ns1.seg_id > ns2.seg_id AND st_geometrytype(st_intersection(ns1.geometria, ns2.geometria)) = 'ST_Point';

CREATE INDEX ON validacao.cont_trocos_geometria_invalida_pontos USING gist(geometria);

DROP MATERIALIZED VIEW IF EXISTS validacao.cont_trocos_geometria_invalida_linhas;

CREATE MATERIALIZED VIEW validacao.cont_trocos_geometria_invalida_linhas AS
WITH not_simple AS (
SELECT ct.identificador, (ST_DumpSegments(ct.geometria)).PATH[1] AS seg_id, (ST_DumpSegments(ct.geometria)).geom AS geometria
FROM base.cont_troco AS ct
WHERE NOT st_issimple(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, ns1.identificador, st_intersection(ns1.geometria, ns2.geometria)::geometry(linestring,3763) AS geometria
FROM not_simple AS ns1 JOIN not_simple AS ns2 ON (NOT st_relate(ns1.geometria, ns2.geometria,'FF*F*****'))
WHERE ns1.identificador = ns2.identificador AND ns1.seg_id > ns2.seg_id AND st_geometrytype(st_intersection(ns1.geometria, ns2.geometria)) = 'ST_LineString';

CREATE INDEX ON validacao.cont_trocos_geometria_invalida_linhas USING gist(geometria);

-- trocos duplicados
DROP MATERIALIZED VIEW IF EXISTS validacao.cont_trocos_duplicados;

CREATE MATERIALIZED VIEW validacao.cont_trocos_duplicados AS
SELECT ct1.identificador, ct2.identificador AS id_duplicado, ct1.geometria::geometry(linestring, 3763)
FROM base.cont_troco AS ct1, base.cont_troco AS ct2
WHERE ct1.identificador > ct2.identificador AND st_equals(ct1.geometria, ct2.geometria);

CREATE INDEX ON validacao.cont_trocos_duplicados USING gist(geometria);

-- centroides duplicados
DROP MATERIALIZED VIEW IF EXISTS validacao.cont_centroides_duplicados;

CREATE MATERIALIZED VIEW validacao.cont_centroides_duplicados AS
SELECT cce1.identificador, cce2.identificador AS id_duplicado, cce1.geometria::geometry(point, 3763)
FROM base.cont_centroide_ea AS cce1, base.cont_centroide_ea AS cce2
WHERE cce1.identificador > cce2.identificador AND st_equals(cce1.geometria, cce2.geometria);

CREATE INDEX ON validacao.cont_centroides_duplicados USING gist(geometria);

-- troços cruzados (pontos)
DROP MATERIALIZED VIEW IF EXISTS validacao.cont_trocos_cruzados_pontos;

CREATE MATERIALIZED VIEW validacao.cont_trocos_cruzados_pontos AS
WITH cruzamentos AS (
SELECT ct1.identificador AS identificador_1, ct2.identificador AS identificador_2, st_multi(st_intersection(ct1.geometria, ct2.geometria)) AS geometria
FROM base.cont_troco AS ct1, base.cont_troco AS ct2
WHERE ct1.identificador > ct2.identificador 
	AND ct1.geometria && ct2.geometria
	AND NOT st_relate(ct1.geometria, ct2.geometria,'FF*F*****'))
SELECT ROW_NUMBER() OVER () AS id, c.identificador_1, c.identificador_2, c.geometria::geometry(multipoint, 3763)
FROM cruzamentos AS c
WHERE st_geometrytype(geometria) = 'ST_MultiPoint';

CREATE INDEX ON validacao.cont_trocos_cruzados_pontos USING gist(geometria);

-- troços cruzados (linhas)
DROP MATERIALIZED VIEW IF EXISTS validacao.cont_trocos_cruzados_linhas;

CREATE MATERIALIZED VIEW validacao.cont_trocos_cruzados_linhas AS
WITH cruzamentos AS (
SELECT ct1.identificador AS identificador_1, ct2.identificador AS identificador_2, st_multi(st_intersection(ct1.geometria, ct2.geometria)) AS geometria
FROM base.cont_troco AS ct1, base.cont_troco AS ct2
WHERE ct1.identificador > ct2.identificador 
	AND ct1.geometria && ct2.geometria
	AND NOT st_relate(ct1.geometria, ct2.geometria,'FF*F*****'))
SELECT ROW_NUMBER() OVER () AS id, c.identificador_1, c.identificador_2, c.geometria::geometry(multilinestring, 3763)
FROM cruzamentos AS c
WHERE st_geometrytype(geometria) = 'ST_MultiLineString';

CREATE INDEX ON validacao.cont_trocos_cruzados_linhas USING gist(geometria);

-- Start e Endpoints de trocos isolados
DROP MATERIALIZED VIEW IF EXISTS validacao.cont_trocos_dangles;

CREATE MATERIALIZED VIEW validacao.cont_trocos_dangles AS
WITH points AS (
	SELECT ct.identificador, (st_dump(st_collect(st_startpoint(ct.geometria), st_endpoint(ct.geometria)))).geom AS geometria
	FROM base.cont_troco AS ct
	WHERE NOT st_isclosed(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, string_agg(p.identificador::text,'') AS identificador, p.geometria::geometry(point,3763)
FROM points AS p
GROUP BY p.geometria HAVING count(p.identificador) < 2;

CREATE INDEX ON validacao.cont_trocos_dangles USING gist(geometria);

-- Compara o número de centroides dos polígonos com os centroides
-- identificar polígonos sem centroide
-- identificar polígonos com mais que um centroide
DROP MATERIALIZED VIEW IF EXISTS validacao.cont_poligonos_temp_erros;

CREATE MATERIALIZED VIEW validacao.cont_poligonos_temp_erros AS 
WITH inter AS (
	SELECT cpt.id, cpt.geometria, count(cce.identificador) AS n_centroides
	FROM master.cont_poligonos_temp AS cpt
	LEFT JOIN base.cont_centroide_ea AS cce ON st_intersects(cpt.geometria, cce.geometria)
	GROUP BY cpt.id)
SELECT 
	id,
	geometria::geometry(polygon, 3763),
	CASE WHEN n_centroides = 0 THEN 'Falta de centroide'
	ELSE 'Excesso de centroides'
	END AS Erro,
	n_centroides
FROM inter
WHERE n_centroides != 1;

CREATE INDEX ON validacao.cont_poligonos_temp_erros USING gist(geometria);

-- Compara a polígono gerados com a versão publicada anterior
-- ATENÇÃO, necessita de ser revista aquando da publicação da CAOP 2023
DROP MATERIALIZED VIEW IF EXISTS validacao.cont_diferencas_geom_gerado_publicado;

CREATE MATERIALIZED VIEW validacao.cont_diferencas_geom_gerado_publicado as
SELECT 
	ROW_NUMBER() OVER () AS fid,
	caa.id AS id_caa_gerado,
	caa.dicofre,
	caap.dicofre AS dicofre_p,
	caa.freguesia,
	caap.freguesia AS freguesia_p,
	st_multi(ST_SymDifference(caa.geometria, caap.geom))::geometry(multipolygon, 3763) AS geom
FROM master.cont_areas_administrativas AS caa 
	JOIN TEMP.cont_aad_caop2022_publicada as caap ON st_contains(caa.geometria, st_pointonsurface(caap.geom))
WHERE NOT st_equals(caa.geometria, caap.geom) AND NOT ST_IsEmpty(ST_SymDifference(caa.geometria, caap.geom));

CREATE INDEX ON validacao.cont_diferencas_geom_gerado_publicado USING gist(geom);

--------------------------------------------------------------------------------------------------------------------------------
--                                                              MADEIRA
--------------------------------------------------------------------------------------------------------------------------------

-- trocos com geometria inválida
DROP MATERIALIZED VIEW IF EXISTS validacao.ram_trocos_geometria_invalida_pontos;

CREATE MATERIALIZED VIEW validacao.ram_trocos_geometria_invalida_pontos AS
WITH not_simple AS (
SELECT ct.identificador, (ST_DumpSegments(ct.geometria)).PATH[1] AS seg_id, (ST_DumpSegments(ct.geometria)).geom AS geometria
FROM base.ram_troco AS ct
WHERE NOT st_issimple(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, ns1.identificador, st_intersection(ns1.geometria, ns2.geometria)::geometry(point, 5016) AS geometria
FROM not_simple AS ns1 JOIN not_simple AS ns2 ON (NOT st_relate(ns1.geometria, ns2.geometria,'FF*F*****'))
WHERE ns1.identificador = ns2.identificador AND ns1.seg_id > ns2.seg_id AND st_geometrytype(st_intersection(ns1.geometria, ns2.geometria)) = 'ST_Point';

CREATE INDEX ON validacao.ram_trocos_geometria_invalida_pontos USING gist(geometria);

DROP MATERIALIZED VIEW IF EXISTS validacao.ram_trocos_geometria_invalida_linhas;

CREATE MATERIALIZED VIEW validacao.ram_trocos_geometria_invalida_linhas AS
WITH not_simple AS (
SELECT ct.identificador, (ST_DumpSegments(ct.geometria)).PATH[1] AS seg_id, (ST_DumpSegments(ct.geometria)).geom AS geometria
FROM base.ram_troco AS ct
WHERE NOT st_issimple(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, ns1.identificador, st_intersection(ns1.geometria, ns2.geometria)::geometry(linestring,5016) AS geometria
FROM not_simple AS ns1 JOIN not_simple AS ns2 ON (NOT st_relate(ns1.geometria, ns2.geometria,'FF*F*****'))
WHERE ns1.identificador = ns2.identificador AND ns1.seg_id > ns2.seg_id AND st_geometrytype(st_intersection(ns1.geometria, ns2.geometria)) = 'ST_LineString';

CREATE INDEX ON validacao.ram_trocos_geometria_invalida_linhas USING gist(geometria);

-- trocos duplicados
DROP MATERIALIZED VIEW IF EXISTS validacao.ram_trocos_duplicados;

CREATE MATERIALIZED VIEW validacao.ram_trocos_duplicados AS
SELECT ct1.identificador, ct2.identificador AS id_duplicado, ct1.geometria::geometry(linestring, 5016)
FROM base.ram_troco AS ct1, base.ram_troco AS ct2
WHERE ct1.identificador > ct2.identificador AND st_equals(ct1.geometria, ct2.geometria);

CREATE INDEX ON validacao.ram_trocos_duplicados USING gist(geometria);

-- centroides duplicados
DROP MATERIALIZED VIEW IF EXISTS validacao.ram_centroides_duplicados;

CREATE MATERIALIZED VIEW validacao.ram_centroides_duplicados AS
SELECT cce1.identificador, cce2.identificador AS id_duplicado, cce1.geometria::geometry(point, 5016)
FROM base.ram_centroide_ea AS cce1, base.ram_centroide_ea AS cce2
WHERE cce1.identificador > cce2.identificador AND st_equals(cce1.geometria, cce2.geometria);

CREATE INDEX ON validacao.ram_centroides_duplicados USING gist(geometria);

-- troços cruzados (pontos)
DROP MATERIALIZED VIEW IF EXISTS validacao.ram_trocos_cruzados_pontos;

CREATE MATERIALIZED VIEW validacao.ram_trocos_cruzados_pontos AS
WITH cruzamentos AS (
SELECT ct1.identificador AS identificador_1, ct2.identificador AS identificador_2, st_multi(st_intersection(ct1.geometria, ct2.geometria)) AS geometria
FROM base.ram_troco AS ct1, base.ram_troco AS ct2
WHERE ct1.identificador > ct2.identificador 
	AND ct1.geometria && ct2.geometria
	AND NOT st_relate(ct1.geometria, ct2.geometria,'FF*F*****'))
SELECT ROW_NUMBER() OVER () AS id, c.identificador_1, c.identificador_2, c.geometria::geometry(multipoint, 5016)
FROM cruzamentos AS c
WHERE st_geometrytype(geometria) = 'ST_MultiPoint';

CREATE INDEX ON validacao.ram_trocos_cruzados_pontos USING gist(geometria);

-- troços cruzados (linhas)
DROP MATERIALIZED VIEW IF EXISTS validacao.ram_trocos_cruzados_linhas;

CREATE MATERIALIZED VIEW validacao.ram_trocos_cruzados_linhas AS
WITH cruzamentos AS (
SELECT ct1.identificador AS identificador_1, ct2.identificador AS identificador_2, st_multi(st_intersection(ct1.geometria, ct2.geometria)) AS geometria
FROM base.ram_troco AS ct1, base.ram_troco AS ct2
WHERE ct1.identificador > ct2.identificador 
	AND ct1.geometria && ct2.geometria
	AND NOT st_relate(ct1.geometria, ct2.geometria,'FF*F*****'))
SELECT ROW_NUMBER() OVER () AS id, c.identificador_1, c.identificador_2, c.geometria::geometry(multilinestring, 5016)
FROM cruzamentos AS c
WHERE st_geometrytype(geometria) = 'ST_MultiLineString';

CREATE INDEX ON validacao.ram_trocos_cruzados_linhas USING gist(geometria);

-- Start e Endpoints de trocos isolados
DROP MATERIALIZED VIEW IF EXISTS validacao.ram_trocos_dangles;

CREATE MATERIALIZED VIEW validacao.ram_trocos_dangles AS
WITH points AS (
	SELECT ct.identificador, (st_dump(st_collect(st_startpoint(ct.geometria), st_endpoint(ct.geometria)))).geom AS geometria
	FROM base.ram_troco AS ct
	WHERE NOT st_isclosed(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, string_agg(p.identificador::text,'') AS identificador, p.geometria::geometry(point,5016)
FROM points AS p
GROUP BY p.geometria HAVING count(p.identificador) < 2;

CREATE INDEX ON validacao.ram_trocos_dangles USING gist(geometria);

-- Compara o número de centroides dos polígonos com os centroides
-- identificar polígonos sem centroide
-- identificar polígonos com mais que um centroide
DROP MATERIALIZED VIEW IF EXISTS validacao.ram_poligonos_temp_erros;

CREATE MATERIALIZED VIEW validacao.ram_poligonos_temp_erros AS 
WITH inter AS (
	SELECT cpt.id, cpt.geometria, count(cce.identificador) AS n_centroides
	FROM master.ram_poligonos_temp AS cpt
	LEFT JOIN base.ram_centroide_ea AS cce ON st_intersects(cpt.geometria, cce.geometria)
	GROUP BY cpt.id)
SELECT 
	id,
	geometria::geometry(polygon, 5016),
	CASE WHEN n_centroides = 0 THEN 'Falta de centroide'
	ELSE 'Excesso de centroides'
	END AS Erro,
	n_centroides
FROM inter
WHERE n_centroides != 1;

CREATE INDEX ON validacao.ram_poligonos_temp_erros USING gist(geometria);

-- Compara a polígono gerados com a versão publicada anterior
-- ATENÇÃO, necessita de ser revista aquando da publicação da CAOP 2023
DROP MATERIALIZED VIEW IF EXISTS validacao.ram_diferencas_geom_gerado_publicado;

CREATE MATERIALIZED VIEW validacao.ram_diferencas_geom_gerado_publicado as
SELECT 
	ROW_NUMBER() OVER () AS fid,
	caa.id AS id_caa_gerado,
	caa.dicofre,
	caap.dicofre AS dicofre_p,
	caa.freguesia,
	caap.freguesia AS freguesia_p,
	st_multi(ST_SymDifference(caa.geometria, caap.geom))::geometry(multipolygon, 5016) AS geom
FROM master.ram_areas_administrativas AS caa 
	JOIN "temp".arqmadeira_aad_caop2022 as caap ON st_contains(caa.geometria, st_pointonsurface(caap.geom))
WHERE NOT st_equals(caa.geometria, caap.geom) AND NOT ST_IsEmpty(ST_SymDifference(caa.geometria, caap.geom));

CREATE INDEX ON validacao.ram_diferencas_geom_gerado_publicado USING gist(geom);

--------------------------------------------------------------------------------------------------------------------------------
--                                                              AÇORES OCIDENTAL
--------------------------------------------------------------------------------------------------------------------------------
-- trocos com geometria inválida
DROP MATERIALIZED VIEW IF EXISTS validacao.raa_oci_trocos_geometria_invalida_pontos;

CREATE MATERIALIZED VIEW validacao.raa_oci_trocos_geometria_invalida_pontos AS
WITH not_simple AS (
SELECT ct.identificador, (ST_DumpSegments(ct.geometria)).PATH[1] AS seg_id, (ST_DumpSegments(ct.geometria)).geom AS geometria
FROM base.raa_oci_troco AS ct
WHERE NOT st_issimple(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, ns1.identificador, st_intersection(ns1.geometria, ns2.geometria)::geometry(point, 5014) AS geometria
FROM not_simple AS ns1 JOIN not_simple AS ns2 ON (NOT st_relate(ns1.geometria, ns2.geometria,'FF*F*****'))
WHERE ns1.identificador = ns2.identificador AND ns1.seg_id > ns2.seg_id AND st_geometrytype(st_intersection(ns1.geometria, ns2.geometria)) = 'ST_Point';

CREATE INDEX ON validacao.raa_oci_trocos_geometria_invalida_pontos USING gist(geometria);

DROP MATERIALIZED VIEW IF EXISTS validacao.raa_oci_trocos_geometria_invalida_linhas;

CREATE MATERIALIZED VIEW validacao.raa_oci_trocos_geometria_invalida_linhas AS
WITH not_simple AS (
SELECT ct.identificador, (ST_DumpSegments(ct.geometria)).PATH[1] AS seg_id, (ST_DumpSegments(ct.geometria)).geom AS geometria
FROM base.raa_oci_troco AS ct
WHERE NOT st_issimple(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, ns1.identificador, st_intersection(ns1.geometria, ns2.geometria)::geometry(linestring,5014) AS geometria
FROM not_simple AS ns1 JOIN not_simple AS ns2 ON (NOT st_relate(ns1.geometria, ns2.geometria,'FF*F*****'))
WHERE ns1.identificador = ns2.identificador AND ns1.seg_id > ns2.seg_id AND st_geometrytype(st_intersection(ns1.geometria, ns2.geometria)) = 'ST_LineString';

CREATE INDEX ON validacao.raa_oci_trocos_geometria_invalida_linhas USING gist(geometria);

-- trocos duplicados
DROP MATERIALIZED VIEW IF EXISTS validacao.raa_oci_trocos_duplicados;

CREATE MATERIALIZED VIEW validacao.raa_oci_trocos_duplicados AS
SELECT ct1.identificador, ct2.identificador AS id_duplicado, ct1.geometria::geometry(linestring, 5014)
FROM base.raa_oci_troco AS ct1, base.raa_oci_troco AS ct2
WHERE ct1.identificador > ct2.identificador AND st_equals(ct1.geometria, ct2.geometria);

CREATE INDEX ON validacao.raa_oci_trocos_duplicados USING gist(geometria);

-- centroides duplicados
DROP MATERIALIZED VIEW IF EXISTS validacao.raa_oci_centroides_duplicados;

CREATE MATERIALIZED VIEW validacao.raa_oci_centroides_duplicados AS
SELECT cce1.identificador, cce2.identificador AS id_duplicado, cce1.geometria::geometry(point, 5014)
FROM base.raa_oci_centroide_ea AS cce1, base.raa_oci_centroide_ea AS cce2
WHERE cce1.identificador > cce2.identificador AND st_equals(cce1.geometria, cce2.geometria);

CREATE INDEX ON validacao.raa_oci_centroides_duplicados USING gist(geometria);

-- troços cruzados (pontos)
DROP MATERIALIZED VIEW IF EXISTS validacao.raa_oci_trocos_cruzados_pontos;

CREATE MATERIALIZED VIEW validacao.raa_oci_trocos_cruzados_pontos AS
WITH cruzamentos AS (
SELECT ct1.identificador AS identificador_1, ct2.identificador AS identificador_2, st_multi(st_intersection(ct1.geometria, ct2.geometria)) AS geometria
FROM base.raa_oci_troco AS ct1, base.raa_oci_troco AS ct2
WHERE ct1.identificador > ct2.identificador 
	AND ct1.geometria && ct2.geometria
	AND NOT st_relate(ct1.geometria, ct2.geometria,'FF*F*****'))
SELECT ROW_NUMBER() OVER () AS id, c.identificador_1, c.identificador_2, c.geometria::geometry(multipoint, 5014)
FROM cruzamentos AS c
WHERE st_geometrytype(geometria) = 'ST_MultiPoint';

CREATE INDEX ON validacao.raa_oci_trocos_cruzados_pontos USING gist(geometria);

-- troços cruzados (linhas)
DROP MATERIALIZED VIEW IF EXISTS validacao.raa_oci_trocos_cruzados_linhas;

CREATE MATERIALIZED VIEW validacao.raa_oci_trocos_cruzados_linhas AS
WITH cruzamentos AS (
SELECT ct1.identificador AS identificador_1, ct2.identificador AS identificador_2, st_multi(st_intersection(ct1.geometria, ct2.geometria)) AS geometria
FROM base.raa_oci_troco AS ct1, base.raa_oci_troco AS ct2
WHERE ct1.identificador > ct2.identificador 
	AND ct1.geometria && ct2.geometria
	AND NOT st_relate(ct1.geometria, ct2.geometria,'FF*F*****'))
SELECT ROW_NUMBER() OVER () AS id, c.identificador_1, c.identificador_2, c.geometria::geometry(multilinestring, 5014)
FROM cruzamentos AS c
WHERE st_geometrytype(geometria) = 'ST_MultiLineString';

CREATE INDEX ON validacao.raa_oci_trocos_cruzados_linhas USING gist(geometria);

-- Start e Endpoints de trocos isolados
DROP MATERIALIZED VIEW IF EXISTS validacao.raa_oci_trocos_dangles;

CREATE MATERIALIZED VIEW validacao.raa_oci_trocos_dangles AS
WITH points AS (
	SELECT ct.identificador, (st_dump(st_collect(st_startpoint(ct.geometria), st_endpoint(ct.geometria)))).geom AS geometria
	FROM base.raa_oci_troco AS ct
	WHERE NOT st_isclosed(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, string_agg(p.identificador::text,'') AS identificador, p.geometria::geometry(point,5014)
FROM points AS p
GROUP BY p.geometria HAVING count(p.identificador) < 2;

CREATE INDEX ON validacao.raa_oci_trocos_dangles USING gist(geometria);

-- Compara o número de centroides dos polígonos com os centroides
-- identificar polígonos sem centroide
-- identificar polígonos com mais que um centroide
DROP MATERIALIZED VIEW IF EXISTS validacao.raa_oci_poligonos_temp_erros;

CREATE MATERIALIZED VIEW validacao.raa_oci_poligonos_temp_erros AS 
WITH inter AS (
	SELECT cpt.id, cpt.geometria, count(cce.identificador) AS n_centroides
	FROM master.raa_oci_poligonos_temp AS cpt
	LEFT JOIN base.raa_oci_centroide_ea AS cce ON st_intersects(cpt.geometria, cce.geometria)
	GROUP BY cpt.id)
SELECT 
	id,
	geometria::geometry(polygon, 5014),
	CASE WHEN n_centroides = 0 THEN 'Falta de centroide'
	ELSE 'Excesso de centroides'
	END AS Erro,
	n_centroides
FROM inter
WHERE n_centroides != 1;

CREATE INDEX ON validacao.raa_oci_poligonos_temp_erros USING gist(geometria);

-- Compara a polígono gerados com a versão publicada anterior
-- ATENÇÃO, necessita de ser revista aquando da publicação da CAOP 2023
DROP MATERIALIZED VIEW IF EXISTS validacao.raa_oci_diferencas_geom_gerado_publicado;

CREATE MATERIALIZED VIEW validacao.raa_oci_diferencas_geom_gerado_publicado as
SELECT 
	ROW_NUMBER() OVER () AS fid,
	caa.id AS id_caa_gerado,
	caa.dicofre,
	caap.dicofre AS dicofre_p,
	caa.freguesia,
	caap.freguesia AS freguesia_p,
	st_multi(ST_SymDifference(caa.geometria, caap.geom))::geometry(multipolygon, 5014) AS geom
FROM master.raa_oci_areas_administrativas AS caa 
	JOIN "temp".arqmadeira_aad_caop2022 as caap ON st_contains(caa.geometria, st_pointonsurface(caap.geom))
WHERE NOT st_equals(caa.geometria, caap.geom) AND NOT ST_IsEmpty(ST_SymDifference(caa.geometria, caap.geom));

CREATE INDEX ON validacao.raa_oci_diferencas_geom_gerado_publicado USING gist(geom);

--------------------------------------------------------------------------------------------------------------------------------
--                                                              AÇORES CENTRAL E ORIENTAL
--------------------------------------------------------------------------------------------------------------------------------
-- trocos com geometria inválida
DROP MATERIALIZED VIEW IF EXISTS validacao.raa_cen_ori_trocos_geometria_invalida_pontos;

CREATE MATERIALIZED VIEW validacao.raa_cen_ori_trocos_geometria_invalida_pontos AS
WITH not_simple AS (
SELECT ct.identificador, (ST_DumpSegments(ct.geometria)).PATH[1] AS seg_id, (ST_DumpSegments(ct.geometria)).geom AS geometria
FROM base.raa_cen_ori_troco AS ct
WHERE NOT st_issimple(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, ns1.identificador, st_intersection(ns1.geometria, ns2.geometria)::geometry(point, 5015) AS geometria
FROM not_simple AS ns1 JOIN not_simple AS ns2 ON (NOT st_relate(ns1.geometria, ns2.geometria,'FF*F*****'))
WHERE ns1.identificador = ns2.identificador AND ns1.seg_id > ns2.seg_id AND st_geometrytype(st_intersection(ns1.geometria, ns2.geometria)) = 'ST_Point';

CREATE INDEX ON validacao.raa_cen_ori_trocos_geometria_invalida_pontos USING gist(geometria);

DROP MATERIALIZED VIEW IF EXISTS validacao.raa_cen_ori_trocos_geometria_invalida_linhas;

CREATE MATERIALIZED VIEW validacao.raa_cen_ori_trocos_geometria_invalida_linhas AS
WITH not_simple AS (
SELECT ct.identificador, (ST_DumpSegments(ct.geometria)).PATH[1] AS seg_id, (ST_DumpSegments(ct.geometria)).geom AS geometria
FROM base.raa_cen_ori_troco AS ct
WHERE NOT st_issimple(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, ns1.identificador, st_intersection(ns1.geometria, ns2.geometria)::geometry(linestring,5015) AS geometria
FROM not_simple AS ns1 JOIN not_simple AS ns2 ON (NOT st_relate(ns1.geometria, ns2.geometria,'FF*F*****'))
WHERE ns1.identificador = ns2.identificador AND ns1.seg_id > ns2.seg_id AND st_geometrytype(st_intersection(ns1.geometria, ns2.geometria)) = 'ST_LineString';

CREATE INDEX ON validacao.raa_cen_ori_trocos_geometria_invalida_linhas USING gist(geometria);

-- trocos duplicados

DROP MATERIALIZED VIEW IF EXISTS validacao.raa_cen_ori_trocos_duplicados;

CREATE MATERIALIZED VIEW validacao.raa_cen_ori_trocos_duplicados AS
SELECT ct1.identificador, ct2.identificador AS id_duplicado, ct1.geometria::geometry(linestring, 5015)
FROM base.raa_cen_ori_troco AS ct1, base.raa_cen_ori_troco AS ct2
WHERE ct1.identificador > ct2.identificador AND st_equals(ct1.geometria, ct2.geometria);

CREATE INDEX ON validacao.raa_cen_ori_trocos_duplicados USING gist(geometria);

-- centroides duplicados
DROP MATERIALIZED VIEW IF EXISTS validacao.raa_cen_ori_centroides_duplicados;

CREATE MATERIALIZED VIEW validacao.raa_cen_ori_centroides_duplicados AS
SELECT cce1.identificador, cce2.identificador AS id_duplicado, cce1.geometria::geometry(point, 5015)
FROM base.raa_cen_ori_centroide_ea AS cce1, base.raa_cen_ori_centroide_ea AS cce2
WHERE cce1.identificador > cce2.identificador AND st_equals(cce1.geometria, cce2.geometria);

CREATE INDEX ON validacao.raa_cen_ori_centroides_duplicados USING gist(geometria);

-- troços cruzados (pontos)
DROP MATERIALIZED VIEW IF EXISTS validacao.raa_cen_ori_trocos_cruzados_pontos;

CREATE MATERIALIZED VIEW validacao.raa_cen_ori_trocos_cruzados_pontos AS
WITH cruzamentos AS (
SELECT ct1.identificador AS identificador_1, ct2.identificador AS identificador_2, st_multi(st_intersection(ct1.geometria, ct2.geometria)) AS geometria
FROM base.raa_cen_ori_troco AS ct1, base.raa_cen_ori_troco AS ct2
WHERE ct1.identificador > ct2.identificador 
	AND ct1.geometria && ct2.geometria
	AND NOT st_relate(ct1.geometria, ct2.geometria,'FF*F*****'))
SELECT ROW_NUMBER() OVER () AS id, c.identificador_1, c.identificador_2, c.geometria::geometry(multipoint, 5015)
FROM cruzamentos AS c
WHERE st_geometrytype(geometria) = 'ST_MultiPoint';

CREATE INDEX ON validacao.raa_cen_ori_trocos_cruzados_pontos USING gist(geometria);

-- troços cruzados (linhas)
DROP MATERIALIZED VIEW IF EXISTS validacao.raa_cen_ori_trocos_cruzados_linhas;

CREATE MATERIALIZED VIEW validacao.raa_cen_ori_trocos_cruzados_linhas AS
WITH cruzamentos AS (
SELECT ct1.identificador AS identificador_1, ct2.identificador AS identificador_2, st_multi(st_intersection(ct1.geometria, ct2.geometria)) AS geometria
FROM base.raa_cen_ori_troco AS ct1, base.raa_cen_ori_troco AS ct2
WHERE ct1.identificador > ct2.identificador 
	AND ct1.geometria && ct2.geometria
	AND NOT st_relate(ct1.geometria, ct2.geometria,'FF*F*****'))
SELECT ROW_NUMBER() OVER () AS id, c.identificador_1, c.identificador_2, c.geometria::geometry(multilinestring, 5015)
FROM cruzamentos AS c
WHERE st_geometrytype(geometria) = 'ST_MultiLineString';

CREATE INDEX ON validacao.raa_cen_ori_trocos_cruzados_linhas USING gist(geometria);

-- Start e Endpoints de trocos isolados
DROP MATERIALIZED VIEW IF EXISTS validacao.raa_cen_ori_trocos_dangles;

CREATE MATERIALIZED VIEW validacao.raa_cen_ori_trocos_dangles AS
WITH points AS (
	SELECT ct.identificador, (st_dump(st_collect(st_startpoint(ct.geometria), st_endpoint(ct.geometria)))).geom AS geometria
	FROM base.raa_cen_ori_troco AS ct
	WHERE NOT st_isclosed(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, string_agg(p.identificador::text,'') AS identificador, p.geometria::geometry(point,5015)
FROM points AS p
GROUP BY p.geometria HAVING count(p.identificador) < 2;

CREATE INDEX ON validacao.raa_cen_ori_trocos_dangles USING gist(geometria);

-- Compara o número de centroides dos polígonos com os centroides
-- identificar polígonos sem centroide
-- identificar polígonos com mais que um centroide
DROP MATERIALIZED VIEW IF EXISTS validacao.raa_cen_ori_poligonos_temp_erros;

CREATE MATERIALIZED VIEW validacao.raa_cen_ori_poligonos_temp_erros AS 
WITH inter AS (
	SELECT cpt.id, cpt.geometria, count(cce.identificador) AS n_centroides
	FROM master.raa_cen_ori_poligonos_temp AS cpt
	LEFT JOIN base.raa_cen_ori_centroide_ea AS cce ON st_intersects(cpt.geometria, cce.geometria)
	GROUP BY cpt.id)
SELECT 
	id,
	geometria::geometry(polygon, 5015),
	CASE WHEN n_centroides = 0 THEN 'Falta de centroide'
	ELSE 'Excesso de centroides'
	END AS Erro,
	n_centroides
FROM inter
WHERE n_centroides != 1;

CREATE INDEX ON validacao.raa_cen_ori_poligonos_temp_erros USING gist(geometria);

DROP MATERIALIZED VIEW IF EXISTS validacao.raa_cen_ori_diferencas_geom_gerado_publicado;

CREATE MATERIALIZED VIEW validacao.raa_cen_ori_diferencas_geom_gerado_publicado AS
WITH central_oriental_aad_caop2022 AS (
	SELECT * FROM "temp".arqacores_gcentral_aad_caop2022
	UNION ALL
	SELECT * FROM "temp".arqacores_goriental_aad_caop2022)
SELECT 
	ROW_NUMBER() OVER () AS fid,
	caa.id AS id_caa_gerado,
	caa.dicofre,
	caap.dicofre AS dicofre_p,
	caa.freguesia,
	caap.freguesia AS freguesia_p,
	st_multi(ST_SymDifference(caa.geometria, caap.geom))::geometry(multipolygon, 5015) AS geom
FROM master.raa_cen_ori_areas_administrativas AS caa 
	JOIN central_oriental_aad_caop2022 as caap ON st_contains(caa.geometria, st_pointonsurface(caap.geom))
WHERE NOT st_equals(caa.geometria, caap.geom) AND NOT ST_IsEmpty(ST_SymDifference(caa.geometria, caap.geom));

CREATE INDEX ON validacao.raa_ori_diferencas_geom_gerado_publicado USING gist(geom);

--- Permissões ---

GRANT USAGE ON SCHEMA validacao TO editor, visualizador;
GRANT USAGE, CREATE ON SCHEMA validacao TO administrador;
GRANT SELECT ON ALL TABLES IN SCHEMA validacao TO editor, visualizador, administrador;



CREATE OR REPLACE FUNCTION public.actualizar_validacao(prefixo TEXT DEFAULT 'cont')
 RETURNS boolean SECURITY DEFINER
 LANGUAGE plpgsql
AS $body$
BEGIN
	IF prefixo NOT IN ('cont', 'ram', 'raa_oci', 'raa_cen_ori') THEN
			RAISE EXCEPTION 'Prefixo inválido! Opções válidas são cont, ram, raa_oci, raa_cen_ori';
			RETURN FALSE;
	END IF;
	
EXECUTE format('
	REFRESH MATERIALIZED VIEW validacao.%1$s_trocos_geometria_invalida_pontos;
	REFRESH MATERIALIZED VIEW validacao.%1$s_trocos_geometria_invalida_linhas;
	REFRESH MATERIALIZED VIEW validacao.%1$s_trocos_duplicados;
	REFRESH MATERIALIZED VIEW validacao.%1$s_trocos_cruzados_linhas;
	REFRESH MATERIALIZED VIEW validacao.%1$s_trocos_cruzados_pontos;
	REFRESH MATERIALIZED VIEW validacao.%1$s_trocos_dangles;
	REFRESH MATERIALIZED VIEW validacao.%1$s_centroides_duplicados;
	REFRESH MATERIALIZED VIEW validacao.%1$s_poligonos_temp_erros;
	REFRESH MATERIALIZED VIEW validacao.%1$s_diferencas_geom_gerado_publicado;'
	, prefixo);

	RETURN True;
END;
$body$
;

-- Por definição todas as funções têm permissão de execute
-- Por isso retiramos todas as permissões e apenas damos a editores e administradores
REVOKE ALL ON FUNCTION public.tr_actualizar_validacao(text) FROM public;
GRANT EXECUTE ON FUNCTION public.tr_actualizar_validacao(text) TO administrador, editor;

-- Teste função
-- SELECT tr_actualizar_validacao();
-- SELECT tr_actualizar_validacao('cont');
-- SELECT tr_actualizar_validacao('ram');
-- SELECT tr_actualizar_validacao('raa_oci');
-- SELECT tr_actualizar_validacao('raa_cen_ori');
-- SELECT tr_actualizar_validacao('blabla');