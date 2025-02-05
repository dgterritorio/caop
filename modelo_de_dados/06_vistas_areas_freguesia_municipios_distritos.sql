set search_path=master;

CREATE OR REPLACE VIEW areas_freguesias as
with todos as (
	SELECT * FROM cont_freguesias
	UNION ALL
	SELECT * FROM ram_freguesias
	UNION ALL
	SELECT * FROM raa_oci_freguesias
	UNION ALL
	SELECT * FROM raa_cen_ori_freguesias
)
SELECT 
	dtmnfr,	
	nuts1 as nuts1_dsg,
	n1.codigo as nuts1_cod,
	nuts2 as NUTS2_DSG,
	n2.codigo as NUTS2_COD,
	nuts3 as NUTS3_DSG,
	n3.codigo as NUTS3_COD,
	distrito_ilha as DISTRITO_ILHA_DSG,
	municipio as MUNICIPIO_DSG,
	freguesia as FREGUESIA_DSG,
	area_ha as AREA_ha,
	(area_ha / 100)::numeric(10,2) as AREA_km2
 from todos as t
	join base.nuts1 as n1 on n1.nome = t.nuts1
	join base.nuts2 as n2 on n2.nome = t.nuts2
	join base.nuts3 as n3 on n3.nome = t.nuts3
order by dtmnfr;

CREATE OR REPLACE VIEW areas_municipios as
with todos as (
	SELECT * FROM cont_municipios
	UNION ALL
	SELECT * FROM ram_municipios
	UNION ALL
	SELECT * FROM raa_oci_municipios
	UNION ALL
	SELECT * FROM raa_cen_ori_municipios
	)
SELECT 
	dtmn,	
	nuts1 as nuts1_dsg,
	n1.codigo as nuts1_cod,
	nuts2 as NUTS2_DSG,
	n2.codigo as NUTS2_COD,
	nuts3 as NUTS3_DSG,
	n3.codigo as NUTS3_COD,
	distrito_ilha as DISTRITO_ILHA_DSG,
	municipio as MUNICIPIO_DSG,
	area_ha as AREA_ha,
	(area_ha / 100)::numeric(10,2) as AREA_km2,
	perimetro_km as perim_km,
	altitude_max_m,
	altitude_min_m
 from todos as t
	join base.nuts1 as n1 on n1.nome = t.nuts1
	join base.nuts2 as n2 on n2.nome = t.nuts2
	join base.nuts3 as n3 on n3.nome = t.nuts3
	join base.altitudes_municipios on dico = dtmn
order by dtmn;

CREATE OR REPLACE VIEW areas_distritos as
with todos as (
	SELECT * FROM cont_distritos
	UNION ALL
	SELECT * FROM ram_distritos
	UNION ALL
	SELECT * FROM raa_oci_distritos
	UNION ALL
	SELECT * FROM raa_cen_ori_distritos
	),
altitudes_distritos as (
	SELECT 
		left(dico,2) as di, 
		max(altitude_max_m) as altitude_max_m,
		min(altitude_min_m) as altitude_min_m
	FROM base.altitudes_municipios
	GROUP BY di
)
SELECT 
	dt,	
	nuts1 as nuts1_dsg,
	n1.codigo as nuts1_cod,
	distrito as DISTRITO_ILHA_DSG,
	area_ha as AREA_ha,
	(area_ha / 100)::numeric(10,2) as AREA_km2,
	perimetro_km as perim_km,
	altitude_max_m,
	altitude_min_m
 from todos as t
	join base.nuts1 as n1 on n1.nome = t.nuts1
	join altitudes_distritos on di = dt
order by dt;

CREATE OR REPLACE VIEW areas_pais as
with todos as (
	SELECT * FROM cont_distritos
	UNION ALL
	SELECT * FROM ram_distritos
	UNION ALL
	SELECT * FROM raa_oci_distritos
	UNION ALL
	SELECT * FROM raa_cen_ori_distritos
)
SELECT 'País' as dsgn, (sum(area_ha)/100)::numeric(10,2) as area_km2 from todos
UNION ALL
SELECT nuts1 as dsgn, (sum(area_ha)/100)::numeric(10,2) as area_km2 from todos
group by nuts1;

CREATE OR REPLACE VIEW numero_divisoes_pais as
with todas_freguesias as (
	SELECT count(*) FROM cont_freguesias
	UNION ALL
	SELECT count(*) FROM ram_freguesias
	UNION ALL
	SELECT count(*) FROM raa_oci_freguesias
	UNION ALL
	SELECT count(*) FROM raa_cen_ori_freguesias
),
todos_municipios as (
	SELECT count(*) FROM cont_municipios
	UNION ALL
	SELECT count(*) FROM ram_municipios
	UNION ALL
	SELECT count(*) FROM raa_oci_municipios
	UNION ALL
	SELECT count(*) FROM raa_cen_ori_municipios
),
todos_distritos as (
	SELECT count(*) FROM cont_distritos
	UNION ALL
	SELECT count(*) FROM ram_distritos
	UNION ALL
	SELECT count(*) FROM raa_oci_distritos
	UNION ALL
	SELECT count(*) FROM raa_cen_ori_distritos
)
SELECT 'Freguesias' as div, sum(count) as numero from todas_freguesias
UNION ALL
SELECT 'Municípios' as div, sum(count) as numero from todos_municipios
UNION ALL
SELECT 'Distritos/Ilhas' as div, sum(count) as numero from todos_distritos;

GRANT SELECT ON areas_freguesias, areas_municipios, areas_distritos, areas_pais, numero_divisoes_pais TO editor, visualizador;