-- Ferramentas para validação de centroides e troços editados.

CREATE SCHEMA validacao;

-- trocos com geometria inválida
CREATE MATERIALIZED VIEW validacao.cont_trocos_geometria_invalida_pontos AS
WITH not_simple AS (
SELECT ct.identificador, (ST_DumpSegments(ct.geometria)).PATH[1] AS seg_id, (ST_DumpSegments(ct.geometria)).geom AS geometria
FROM base.cont_troco AS ct
WHERE NOT st_issimple(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, ns1.identificador, st_intersection(ns1.geometria, ns2.geometria)::geometry(point, 3763) AS geometria
FROM not_simple AS ns1 JOIN not_simple AS ns2 ON (NOT st_relate(ns1.geometria, ns2.geometria,'FF*F*****'))
WHERE ns1.identificador = ns2.identificador AND ns1.seg_id > ns2.seg_id AND st_geometrytype(st_intersection(ns1.geometria, ns2.geometria)) = 'ST_Point';

CREATE MATERIALIZED VIEW validacao.cont_trocos_geometria_invalida_linhas AS
WITH not_simple AS (
SELECT ct.identificador, (ST_DumpSegments(ct.geometria)).PATH[1] AS seg_id, (ST_DumpSegments(ct.geometria)).geom AS geometria
FROM base.cont_troco AS ct
WHERE NOT st_issimple(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, ns1.identificador, st_intersection(ns1.geometria, ns2.geometria)::geometry(linestring,3763) AS geometria
FROM not_simple AS ns1 JOIN not_simple AS ns2 ON (NOT st_relate(ns1.geometria, ns2.geometria,'FF*F*****'))
WHERE ns1.identificador = ns2.identificador AND ns1.seg_id > ns2.seg_id AND st_geometrytype(st_intersection(ns1.geometria, ns2.geometria)) = 'ST_LineString';

-- trocos duplicados

CREATE MATERIALIZED VIEW validacao.cont_trocos_duplicados AS
SELECT ct1.identificador, ct2.identificador AS id_duplicado, ct1.geometria::geometry(linestring, 3763)
FROM base.cont_troco AS ct1, base.cont_troco AS ct2
WHERE ct1.identificador > ct2.identificador AND st_equals(ct1.geometria, ct2.geometria);

-- centroides duplicados
CREATE MATERIALIZED VIEW validacao.cont_centroides_duplicados AS
SELECT cce1.identificador, cce2.identificador AS id_duplicado, cce1.geometria::geometry(point, 3763)
FROM base.cont_centroide_ea AS cce1, base.cont_centroide_ea AS cce2
WHERE cce1.identificador > cce2.identificador AND st_equals(cce1.geometria, cce2.geometria);

-- troços cruzados (pontos)
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

-- troços cruzados (linhas)
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

-- Start e Endpoints de trocos isolados
CREATE MATERIALIZED VIEW validacao.cont_trocos_dangles AS
WITH points AS (
	SELECT ct.identificador, (st_dump(st_collect(st_startpoint(ct.geometria), st_endpoint(ct.geometria)))).geom AS geometria
	FROM base.cont_troco AS ct
	WHERE NOT st_isclosed(ct.geometria))
SELECT ROW_NUMBER() OVER () AS id, string_agg(p.identificador::text,'') AS identificador, p.geometria::geometry(point,3763)
FROM points AS p
GROUP BY p.geometria HAVING count(p.identificador) < 2;
	
-- Compara o número de centroides dos polígonos com os centroides
-- identificar polígonos sem centroide
-- identificar polígonos com mais que um centroide

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

GRANT USAGE ON SCHEMA validacao TO editor, visualizador;
GRANT USAGE, CREATE ON SCHEMA validacao TO administrador;
GRANT SELECT ON ALL TABLES IN SCHEMA validacao TO editor, visualizador, administrador;

CREATE OR REPLACE FUNCTION public.tr_actualizar_validacao()
 RETURNS boolean SECURITY DEFINER
 LANGUAGE plpgsql
AS $body$
BEGIN
	REFRESH MATERIALIZED VIEW validacao.cont_trocos_geometria_invalida_pontos;
	REFRESH MATERIALIZED VIEW validacao.cont_trocos_geometria_invalida_linhas;
	REFRESH MATERIALIZED VIEW validacao.cont_trocos_duplicados;
	REFRESH MATERIALIZED VIEW validacao.cont_trocos_cruzados_linhas;
	REFRESH MATERIALIZED VIEW validacao.cont_trocos_cruzados_pontos;
	REFRESH MATERIALIZED VIEW validacao.cont_trocos_dangles;
	REFRESH MATERIALIZED VIEW validacao.cont_centroides_duplicados;
	REFRESH MATERIALIZED VIEW validacao.cont_poligonos_temp_erros;
	RETURN True;
END;
$body$
;

-- Por definição todas as funções têm permissão de execute
-- Por isso retiramos todas as permissões e apenas damos a editores e administradores
REVOKE ALL ON FUNCTION public.tr_actualizar_validacao() FROM public;
GRANT EXECUTE ON FUNCTION public.tr_actualizar_validacao() TO administrador, editor;

-- Teste função
-- SELECT tr_actualizar_validacao();

