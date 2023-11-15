-- Scrips para transformar os trocos e centroides em poligonos aos seus varios niveis

-- Todos os comandos devem ser corridos dentro de funcoes o mais genericas possiveis que permitam
   -- Escolher o schema base a usar (base_continente, base_madeira, base_acores_ocidental, base_acores_oriental ),
   -- Escolher o schema de output,
   -- Escolher a data ou versão a usar (usando o versioning)

-- query para transformar os trocos em poligonos
-- e guardar numa tabela temporária
CREATE TABLE temp.poligonos (
	id serial PRIMARY KEY,
	geometria geometry(polygon, 3763)
);

INSERT INTO temp.poligonos (geometria)
SELECT (st_dump(st_polygonize(geometria))).geom AS geom
FROM base.troco;

CREATE INDEX ON temp.poligonos USING gist(geometria);

CREATE SCHEMA master;
GRANT ALL ON SCHEMA master TO administrador;
GRANT USAGE ON SCHEMA master TO editor, visualizador;

-- A cada poligono, tentar atribuir os restantes atributos relacionados com o centroide que nele contido
-- actualmente a query ignora centroides duplicados (com o mesmo dicofre), mas futuramente não o deverá fazer
--DROP MATERIALIZED VIEW master.continente_entidades_administrativas CASCADE;
CREATE MATERIALIZED VIEW master.continente_entidades_administrativas as
WITH atributos_freguesias AS (
	SELECT
		ea.cod AS dicofre,
		ea.nome AS freguesia,
		m.nome AS municipio,
		di.nome AS distrito_ilha,
		n3.nome AS nuts3,
		n2.nome AS nuts2,
		n1.nome AS nuts1
	FROM base.entidade_administrativa AS ea 
		JOIN base.municipio AS m ON ea.municipio_dico = m.dico 
		JOIN base.distrito_ilha AS di ON m.distrito_di = di.di
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
	st_area(p.geometria) / 10000 AS area_ha,
	st_perimeter(p.geometria) / 1000 AS perimetro_km
FROM TEMP.poligonos AS p 
	JOIN base.centroide_ea AS ce ON st_intersects(p.geometria, ce.geometria)
	JOIN atributos_freguesias AS a ON a.dicofre = ce.entidade_administrativa
	JOIN dominios.tipo_area_administrativa AS taa ON ce.tipo_area_administrativa_id = taa.identificador;

CREATE INDEX ON master.continente_entidades_administrativas USING gist(geometria);

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
	sum(st_area(geometria)) / 10000 AS area_ha,
	sum(st_perimeter(geometria)) / 1000 AS perimetro_km,
	REPLACE(freguesia,'União das freguesias de ','') as designacao_simplificada
FROM master.continente_entidades_administrativas
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
	sum(st_area(geometria)) / 10000 AS area_ha,
	sum(st_perimeter(geometria)) / 1000 AS perimetro_km
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
	sum(st_area(geometria)) / 10000 AS area_ha,
	sum(st_perimeter(geometria)) / 1000 AS perimetro_km
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
	sum(st_area(geometria)) / 10000 AS area_ha,
	sum(st_perimeter(geometria)) / 1000 AS perimetro_km
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
	sum(st_area(geometria)) / 10000 AS area_ha,
	sum(st_perimeter(geometria)) / 1000 AS perimetro_km
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
	sum(st_area(geometria)) / 10000 AS area_ha,
	sum(st_perimeter(geometria)) / 1000 AS perimetro_km
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
FROM master.continente_entidades_administrativas AS cea;

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




