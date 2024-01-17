INSERT INTO dominios.estado_limite_administrativo (identificador, nome, descricao)
SELECT "código", initcap("identificação"), "descrição" FROM bst AS b;

INSERT INTO dominios.nivel_limite_administrativo (identificador, nome, descricao)
SELECT "código", initcap("identificação"), "descrição" FROM use;

INSERT INTO dominios.caracteres_identificadores_pais  (identificador, nome, descricao)
SELECT field2, initcap(field1), field3 FROM icc
WHERE id > 1

INSERT INTO dominios.significado_linha  (identificador, nome, descricao) VALUES
('1',	'Limite E Linha De Costa',	'Linha que define, simultaneamente, parte de um limite e de linha de costa'),
('2',	'Linha De Costa',	'Linha que define exclusivamente a linha de costa'),
('7',	'Limite Em Terra',	'Linha que define um limite que se localiza em terra'),
('9',	'Limite Na Água',	'Linha que define um limite que se localiza apenas em massa de água')

INSERT INTO dominios.tipo_area_administrativa (identificador, nome, descricao)
SELECT "código", initcap("identificação"), "descrição" FROM taa;

INSERT INTO dominios.tipo_fonte (identificador, nome, descricao)
SELECT "código", initcap("identificação"), "descrição" FROM tf;

-- importar centroides de 2019 para a base do continente (2022)

INSERT INTO base.cont_centroide_ea (identificador, entidade_administrativa, tipo_area_administrativa_id, geometria, motivo)
SELECT identificador, entidade_administrativa, tipo_area_administrativa_id, geometria, 'Importacao centroides 2019' AS motivo FROM base.centroide_ea AS ce; 

-- importar trocos continente 2022

SELECT * FROM TEMP.cont_troco_caop2022;

ALTER TABLE temp.cont_troco_caop2022
ADD COLUMN identificador uuid;

-- criar um identificador para manter a relacao entre o troco_id e o novo identificador para historico e mais tarde ligacao com fontes
UPDATE TEMP.cont_troco_caop2022 SET 
identificador = uuid_generate_v1mc();

INSERT INTO base.cont_troco (identificador, pais, estado_limite_admin, significado_linha, geometria)
SELECT t.identificador, icc AS pais, ela.identificador AS estado_limite_admin, sl.identificador AS significado_linha, geom AS geometria
FROM "temp".cont_troco_caop2022 AS t
	LEFT JOIN dominios.estado_limite_administrativo AS ela ON lower(ela.nome) = lower(bst)
	JOIN dominios.significado_linha AS sl ON lower(sl.nome) = lower(mol); 



SELECT *
FROM "temp".cont_troco_caop2022

-- importacao das fontes unicas 2022 para a base de dados
-- conversao das datas num formato standard

UPDATE TEMP.fontes_2022_xlsx SET 
DATA = '01-01-'|| DATA
WHERE length(data) = 4;


UPDATE TEMP.fontes_2022_xlsx SET 
  DATA = REGEXP_REPLACE(data, '(\d{4})/(\d{2})/(\d{2})', '\3-\2-\1')

-- Drop NOT NULL Constraint for now
ALTER TABLE base.fonte ALTER COLUMN "data" DROP NOT NULL;
ALTER TABLE base.fonte ALTER COLUMN "descricao" DROP NOT NULL;

SET datestyle = 'ISO, DMY';

INSERT INTO base.fonte (tipo_fonte, descricao, DATA, observacoes, diploma)
SELECT tf.identificador AS tipo_fonte, des_fonte AS descricao, DATA::date, observacoes, "diploma oficial" AS diploma
FROM TEMP.fontes_2022_xlsx AS f
LEFT JOIN dominios.tipo_fonte AS tf ON lower(f.tipo_fonte) = lower(tf.nome)
;

RESET datestyle;



-- Importacao do inf_troco_caop2022 e correccao dos campos para conseguir fazer join com a tabela das fontes



UPDATE TEMP.inf_fonte_troco_caop2022 SET 
DATA = '01-01-'|| DATA
WHERE length(data) = 4;

UPDATE TEMP.inf_fonte_troco_caop2022 SET 
  DATA = REGEXP_REPLACE(data, '(\d{4})/(\d{2})/(\d{2})', '\3-\2-\1')

SELECT ift.*, tf.identificador 
FROM temp.inf_fonte_troco_caop2022 ift 
	LEFT JOIN dominios.tipo_fonte AS tf ON (lower(ift.tipo_fonte )= lower(tf.nome));

ALTER TABLE temp.inf_fonte_troco_caop2022 
ADD COLUMN tipo_fonte_id varchar;

UPDATE temp.inf_fonte_troco_caop2022
SET tipo_fonte_id = tf.identificador
FROM dominios.tipo_fonte AS tf
WHERE (lower(tipo_fonte )= lower(tf.nome));

SET datestyle = 'ISO, DMY';

SELECT DISTINCT ON (ift.diploma) ift.troco, ift."diploma oficial", f.identificador, f.data 
FROM temp.inf_fonte_troco_caop2022 ift 
	LEFT JOIN base.fonte AS f ON (
		--	ift.DATA::date = f.DATA --AND 
		--	ift.tipo_fonte_id = f.tipo_fonte AND 
			ift."diploma oficial" = f.diploma
		)
WHERE ift.data IS NOT null;

CREATE TABLE temp.temp_fonte_2022_distinct AS 
SELECT DISTINCT tipo_fonte_id AS tipo_fonte, des_fonte AS descricao, DATA, observacoes, "diploma oficial" AS diploma 
FROM temp.inf_fonte_troco_caop2022;

SELECT ft.descricao, f.identificador 
FROM temp.temp_fonte_2022_distinct AS ft LEFT join base.fonte AS f
on ft.descricao = f.descricao;



DATA::date = f.DATA AND
								  ift.observacoes = f.observacoes)
	JOIN dominios.tipo_fonte AS tf ON tf.identificador = f.tipo_fonte 
	
END IF
THEN
	
END IF
;

INSERT INTO base.fontes (tipo_fonte, descricao, DATA, observacoes, diploma)
SELECT distinct tf.identificador, field3, field4::date(dd-MM-yyyy), field5, field6 
FROM TEMP.inf_fonte_troco_caop2019 JOIN dominios.tipo_fonte AS tf ON lower(tf.nome) = lower(field2)
WHERE id > 1
ORDER BY tf.identificador

DROP TABLE TEMP.fontes_clean
CREATE TABLE TEMP.fontes_clean AS 
SELECT distinct tipo_fonte, descricao, data, observacoes, diploma
FROM TEMP.inf_fonte_troco_caop2019
WHERE id > 1;

ALTER TABLE TEMP.fontes_clean
ADD COLUMN identificador uuid DEFAULT uuid_generate_v1mc();

UPDATE TEMP.fontes_clean SET 
identificador = uuid_generate_v1mc();

ALTER TABLE TEMP.fontes_clean
ADD COLUMN tipo_fonte_2 varchar(3)

UPDATE TEMP.fontes_clean SET 
tipo_fonte_2 = d.identificador
FROM dominios.tipo_fonte AS d
WHERE lower(tipo_fonte) = lower(d.nome);


UPDATE TEMP.fontes_clean SET 
tipo_fonte_2 = '10'
WHERE tipo_fonte = 'CADASTRO GEOMÉTRICO PROPRIEDADE RÚSTICA';

UPDATE TEMP.fontes_clean SET 
tipo_fonte_2 = '16'
WHERE tipo_fonte = 'DADOS DA DIREÇÃO REGIONAL DO ORDENAMENTO DO TERRITÓRIO E AMBIENTE (R.A. MADEIRA)';

UPDATE TEMP.fontes_clean SET 
tipo_fonte_2 = '17'
WHERE tipo_fonte = 'DADOS DO INSTITUTO HIDROGRÁFICO';

UPDATE TEMP.fontes_clean SET 
tipo_fonte_2 = '9'
WHERE tipo_fonte = 'DADOS EX-INSTITUTO GEOGRÁFICO EXÉRCITO';

UPDATE TEMP.fontes_clean SET 
tipo_fonte_2 = '7'
WHERE tipo_fonte = 'SENTENÇA TRIBUNAL ADMINISTRATIVO';


SELECT * FROM TEMP.inf_fonte_troco_caop2019
SELECT * FROM TEMP.fontes_clean

SELECT iftc.*, ft.*
FROM temp.inf_fonte_troco_caop2019 AS iftc
	JOIN TEMP.fontes_clean ft ON 
		lower(iftc.tipo_fonte) = lower(ft.tipo_fonte)
		AND (iftc.descricao = ft.descricao OR (iftc.descricao IS NULL AND ft.descricao IS null)) 
		AND (iftc.data = ft.data OR (iftc.data IS NULL AND ft.data IS null)) 
		AND (iftc.observacoes  = ft.observacoes OR (iftc.observacoes IS NULL AND ft.observacoes IS null)) 
		AND (iftc.diploma  = ft.diploma OR (iftc.diploma IS NULL AND ft.diploma IS null))
ORDER BY iftc.id 
		;


-- Precriar identificadores para ter relacao com o troco_id	
ALTER TABLE TEMP.caop2019_caop_troco
ADD COLUMN identificador uuid;

INSERT INTO base.trocos (identificador, pais, estado_limite_admin, significado_linha, nivel_limite_admin, comprimento_m, geometria)
SELECT identificador, icc, bst, mol, '998', st_length(geom), geom
FROM TEMP.caop2019_caop_troco;

SELECT * FROM TEMP.caop2019_caop_troco
WHERE dicofre_di = '090313'

UPDATE TEMP.caop2019_caop_troco SET 
identificador = uuid_generate_v1mc();

ALTER TABLE TEMP.caop2019_caop_troco
ADD COLUMN fonte_id uuid;

ALTER TABLE TEMP.caop_centroide_2019 
ADD COLUMN identificador uuid;

UPDATE TEMP.caop_centroide_2019
SET identificador = uuid_generate_v1mc();

INSERT INTO base.centroide_ea (identificador, entidade_administrativa, tipo_area_administrativa_id, geometria)
SELECT DISTINCT ON (c.identificador) c.identificador, c.txtmemo, t.taa, c.geom
FROM TEMP.caop_centroide_2019 AS c JOIN
TEMP.caop_centroide_taa_continente_2019 AS t ON st_equals(c.geom, t.geom);

INSERT INTO base.centroide_ea (identificador, entidade_administrativa,  geometria)
SELECT c.identificador AS identificador, c.txtmemo AS entidade_administrativa, c.geom
FROM TEMP.caop_centroide_2019  AS c LEFT JOIN base.centroide_ea AS b ON c.identificador = b.identificador
WHERE b.identificador IS null;

CREATE TABLE TEMP.centroide_ea_backup_uniao as
SELECT * FROM base.centroide_ea;

CREATE TABLE TEMP.centroides_unicos_problemas as
SELECT ce.entidade_administrativa, min(ce.tipo_area_administrativa_id), st_pointonsurface(cea.geometria)
FROM base.centroide_ea AS ce
JOIN TEMP.poligonos AS cea ON st_intersects(ce.geometria, cea.geometria)
GROUP BY cea.id, ce.entidade_administrativa 
; 

INSERT INTO base.centroide_ea (entidade_administrativa, tipo_area_administrativa_id, geometria)
SELECT * FROM TEMP.centroides_unicos_problemas;

DELETE FROM base.centroide_ea 
WHERE inicio_objecto < '2023-12-03'

SELECT ce.entidade_administrativa, min(ce.tipo_area_administrativa_id), st_pointonsurface(cea.geometria)
FROM base.centroide_ea AS ce
JOIN TEMP.poligonos AS cea ON st_intersects(ce.geometria, cea.geometria)
GROUP BY cea.id, ce.entidade_administrativa 

------------------------------------------------------------------------------------------------------------------------------------
-- Importar dados publicados 2022 (MADEIRA)
-- Precriar identificadores para ter relacao com o troco_id	
-- importar trocos madeira 2022

ALTER TABLE temp.arqmadeira_troco_caop2022
ADD COLUMN identificador uuid;

-- criar um identificador para manter a relacao entre o troco_id e o novo identificador para historico e mais tarde ligacao com fontes
UPDATE TEMP.arqmadeira_troco_caop2022 SET 
identificador = uuid_generate_v1mc();

INSERT INTO base.ram_troco (identificador, pais, estado_limite_admin, significado_linha, geometria, motivo)
SELECT 
	t.identificador, 
	'PT' AS pais, 
	ela.identificador AS estado_limite_admin, 
	sl.identificador AS significado_linha, 
	(st_dump(geom)).geom AS geometria, 
	'Importação dados publicados caop 2022' AS motivo
FROM "temp".arqmadeira_troco_caop2022 AS t
	LEFT JOIN dominios.estado_limite_administrativo AS ela ON lower(ela.nome) = lower(bst)
	JOIN dominios.significado_linha AS sl ON lower(sl.nome) = lower(mol);

-- criar centroides
INSERT INTO base.ram_centroide_ea (entidade_administrativa, tipo_area_administrativa_id, geometria, motivo)
SELECT 
	dicofre,
	taa.identificador, 
	st_pointonsurface(geom), 
	'Importação dados publicados caop 2022 - centroides gerados das AAD publicadas' AS motivo
FROM "temp".arqmadeira_aad_caop2022 AS aac
	JOIN dominios.tipo_area_administrativa AS taa ON lower(aac.taa) = lower(taa.nome)

-- gerar polygonos e preencher trocos
	SELECT gerar_poligonos_caop('master','ram');
	SELECT actualizar_trocos('ram');
	SELECT gerar_trocos_caop('master','ram');

-- Comparar dados publicados 2022 (continente) com o output gerado
-- criar uma coluna com o centroide do poligono
ALTER TABLE "temp".arqmadeira_aad_caop2022
ADD COLUMN centroide geometry(point, 5016);

UPDATE "temp".arqmadeira_aad_caop2022 SET 
centroide = st_pointOnSurface(geom);

CREATE INDEX ON "temp".arqmadeira_aad_caop2022 USING gist(centroide);

SELECT 'publicado', count(*) FROM "temp".arqmadeira_aad_caop2022
UNION ALL
SELECT 'gerado', count(*) FROM master.ram_areas_administrativas;

---------------------------------------------------------------------------------------------------------------------------------------------
-- Importar dados publicados 2022 (Açores OCIDENTAL)
-- Precriar identificadores para ter relacao com o troco_id	
-- importar trocos 2022

ALTER TABLE temp.arqacores_gocidental_troco_caop2022
ADD COLUMN identificador uuid;

-- criar um identificador para manter a relacao entre o troco_id e o novo identificador para historico e mais tarde ligacao com fontes
UPDATE TEMP.arqacores_gocidental_troco_caop2022 SET 
identificador = uuid_generate_v1mc();

INSERT INTO base.raa_oci_troco (identificador, pais, estado_limite_admin, significado_linha, geometria, motivo)
SELECT 
	t.identificador, 
	'PT' AS pais, 
	ela.identificador AS estado_limite_admin, 
	sl.identificador AS significado_linha, 
	(st_dump(geom)).geom AS geometria, 
	'Importação dados publicados caop 2022' AS motivo
FROM "temp".arqacores_gocidental_troco_caop2022 AS t
	LEFT JOIN dominios.estado_limite_administrativo AS ela ON lower(ela.nome) = lower(bst)
	JOIN dominios.significado_linha AS sl ON lower(sl.nome) = lower(mol);

-- criar centroides
INSERT INTO base.raa_oci_centroide_ea (entidade_administrativa, tipo_area_administrativa_id, geometria, motivo)
SELECT 
	dicofre,
	taa.identificador, 
	st_pointonsurface(geom), 
	'Importação dados publicados caop 2022 - centroides gerados das AAD publicadas' AS motivo
FROM "temp".arqacores_gocidental_aad_caop2022 AS aac
	JOIN dominios.tipo_area_administrativa AS taa ON lower(aac.taa) = lower(taa.nome)

-- gerar polygonos e preencher trocos
	SELECT gerar_poligonos_caop('master','raa_oci');
	SELECT actualizar_trocos('raa_oci');
	SELECT gerar_trocos_caop('master','raa_oci');

-- Comparar dados publicados 2022 (continente) com o output gerado
-- criar uma coluna com o centroide do poligono
ALTER TABLE "temp".arqacores_gocidental_aad_caop2022
ADD COLUMN centroide geometry(point, 5014);

UPDATE "temp".arqacores_gocidental_aad_caop2022 SET 
centroide = st_pointOnSurface(geom);

CREATE INDEX ON "temp".arqacores_gocidental_aad_caop2022 USING gist(centroide);

SELECT 'publicado', count(*) FROM "temp".arqacores_gocidental_aad_caop2022
UNION ALL
SELECT 'gerado', count(*) FROM master.raa_oci_areas_administrativas;

---------------------------------------------------------------------------------------------------------------------------------------------
-- Importar dados publicados 2022 (Açores CENTRAL)
-- Precriar identificadores para ter relacao com o troco_id	
-- importar trocos 2022

ALTER TABLE temp.arqacores_gcentral_troco_caop2022
ADD COLUMN identificador uuid;

-- criar um identificador para manter a relacao entre o troco_id e o novo identificador para historico e mais tarde ligacao com fontes
UPDATE TEMP.arqacores_gcentral_troco_caop2022 SET 
identificador = uuid_generate_v1mc();

INSERT INTO base.raa_cen_ori_troco (identificador, pais, estado_limite_admin, significado_linha, geometria, motivo)
SELECT 
	t.identificador, 
	'PT' AS pais, 
	ela.identificador AS estado_limite_admin, 
	sl.identificador AS significado_linha, 
	(st_dump(geom)).geom AS geometria, 
	'Importação dados publicados caop 2022' AS motivo
FROM "temp".arqacores_gcentral_troco_caop2022 AS t
	LEFT JOIN dominios.estado_limite_administrativo AS ela ON lower(ela.nome) = lower(bst)
	JOIN dominios.significado_linha AS sl ON lower(sl.nome) = lower(mol);

-- criar centroides
INSERT INTO base.raa_cen_ori_centroide_ea (entidade_administrativa, tipo_area_administrativa_id, geometria, motivo)
SELECT 
	dicofre,
	taa.identificador, 
	st_pointonsurface(geom), 
	'Importação dados publicados caop 2022 - centroides gerados das AAD publicadas' AS motivo
FROM "temp".arqacores_gcentral_aad_caop2022 AS aac
	JOIN dominios.tipo_area_administrativa AS taa ON lower(aac.taa) = lower(taa.nome)

-- gerar polygonos e preencher trocos
	SELECT gerar_poligonos_caop('master','raa_cen_ori');
	SELECT actualizar_trocos('raa_cen_ori');
	SELECT gerar_trocos_caop('master','raa_cen_ori');

-- Comparar dados publicados 2022 (continente) com o output gerado
-- criar uma coluna com o centroide do poligono
ALTER TABLE "temp".arqacores_gcentral_aad_caop2022
ADD COLUMN centroide geometry(point, 5015);

UPDATE "temp".arqacores_gcentral_aad_caop2022 SET 
centroide = st_pointOnSurface(geom);

CREATE INDEX ON "temp".arqacores_gcentral_aad_caop2022 USING gist(centroide);

SELECT 'publicado', count(*) FROM "temp".arqacores_gcentral_aad_caop2022
UNION ALL
SELECT 'gerado', count(*) FROM master.raa_cen_ori_areas_administrativas
WHERE distrito_ilha NOT IN ('Ilha de Santa Maria', 'Ilha de São Miguel');

---------------------------------------------------------------------------------------------------------------------------------------------
-- Importar dados publicados 2022 (Açores ORIENTAL)
-- Precriar identificadores para ter relacao com o troco_id	
-- importar trocos 2022

ALTER TABLE temp.arqacores_goriental_troco_caop2022
ADD COLUMN identificador uuid;

-- criar um identificador para manter a relacao entre o troco_id e o novo identificador para historico e mais tarde ligacao com fontes
UPDATE TEMP.arqacores_goriental_troco_caop2022 SET 
identificador = uuid_generate_v1mc();

INSERT INTO base.raa_cen_ori_troco (identificador, pais, estado_limite_admin, significado_linha, geometria, motivo)
SELECT 
	t.identificador, 
	'PT' AS pais, 
	ela.identificador AS estado_limite_admin, 
	sl.identificador AS significado_linha, 
	(st_dump(geom)).geom AS geometria, 
	'Importação dados publicados caop 2022' AS motivo
FROM "temp".arqacores_goriental_troco_caop2022 AS t
	LEFT JOIN dominios.estado_limite_administrativo AS ela ON lower(ela.nome) = lower(bst)
	JOIN dominios.significado_linha AS sl ON lower(sl.nome) = lower(mol);

-- criar centroides
INSERT INTO base.raa_cen_ori_centroide_ea (entidade_administrativa, tipo_area_administrativa_id, geometria, motivo)
SELECT 
	dicofre,
	taa.identificador, 
	st_pointonsurface(geom), 
	'Importação dados publicados caop 2022 - centroides gerados das AAD publicadas' AS motivo
FROM "temp".arqacores_goriental_aad_caop2022 AS aac
	JOIN dominios.tipo_area_administrativa AS taa ON lower(aac.taa) = lower(taa.nome)

-- gerar polygonos e preencher trocos
	--SELECT gerar_poligonos_caop('master','raa_cen_ori');
	SELECT actualizar_poligonos_caop('master','raa_cen_ori');
	SELECT actualizar_trocos('raa_cen_ori');
	SELECT gerar_trocos_caop('master','raa_cen_ori');

-- Comparar dados publicados 2022 (continente) com o output gerado
-- criar uma coluna com o centroide do poligono
ALTER TABLE "temp".arqacores_goriental_aad_caop2022
ADD COLUMN centroide geometry(point, 5015);

UPDATE "temp".arqacores_goriental_aad_caop2022 SET 
centroide = st_pointOnSurface(geom);

CREATE INDEX ON "temp".arqacores_gcentral_aad_caop2022 USING gist(centroide);

SELECT 'publicado', count(*) FROM "temp".arqacores_goriental_aad_caop2022
UNION ALL
SELECT 'gerado', count(*) FROM master.raa_cen_ori_areas_administrativas WHERE distrito_ilha IN ('Ilha de Santa Maria', 'Ilha de São Miguel');


