CREATE OR REPLACE FUNCTION olu_obce_au(id character varying[])
  RETURNS character varying AS
$BODY$

  DECLARE
    e integer;
    i integer;
  BEGIN

  e:=array_length(id,1);
  i:=1;

  WHILE i <= e LOOP

    drop table IF EXISTS hranice_obci;
    drop table IF EXISTS vybrany_lpis;
    drop table IF EXISTS soucet1;
    drop table IF EXISTS rozdil1;
    drop table IF EXISTS vybrany_ua;
    drop table IF EXISTS soucet2;
    drop table IF EXISTS rozdil2;
    drop table IF EXISTS vybrany_clc;

    EXECUTE 'DROP TABLE IF EXISTS austria_vysledek.' || lower(id[i]) || ';';

    EXECUTE 'CREATE TABLE austria_vysledek.' || lower(id[i]) || '()  INHERITS (austria_vysledek.areas_master);';

    EXECUTE 'CREATE TEMP TABLE hranice_obci AS SELECT ST_Union(ST_MakeValid(geom)) As geom FROM austria.municipalities_union WHERE municipality_id='''||id[i]||''';' ;

    EXECUTE 'CREATE TEMP TABLE vybrany_lpis AS
    WITH LPIS_REL AS (SELECT ST_MakeValid(a.geom) as geom, a.sna_level_1 as original_value,
    CASE WHEN a.sna_level_1=''Brache'' THEN 632 WHEN a.sna_level_1=''Brotgetreide'' THEN 110 WHEN a.sna_level_1=''Dauerkulturen'' THEN 110 WHEN a.sna_level_1=''Energieholzflächen/Forstflächen'' THEN 120 WHEN a.sna_level_1=''Extensives Grünland'' THEN 110 WHEN a.sna_level_1=''Feldfutterbau'' THEN 110 WHEN a.sna_level_1=''Forstflächen'' THEN 120 WHEN a.sna_level_1=''Futtergetreide'' THEN 110 WHEN a.sna_level_1=''Hackfrüchte'' THEN 110 WHEN a.sna_level_1=''Intensives Grünland'' THEN 110 WHEN a.sna_level_1=''Körnermais'' THEN 110 WHEN a.sna_level_1=''Leguminosen'' THEN 110 WHEN a.sna_level_1=''Ölfrüchte'' THEN 110 WHEN a.sna_level_1=''Reb- und Baumschulen'' THEN 332 WHEN a.sna_level_1=''Silomais'' THEN 110 WHEN a.sna_level_1=''Sonst. Ackerland/Energiegräser'' THEN 110 WHEN a.sna_level_1=''Sonstiges Ackerland'' THEN 110 WHEN a.sna_level_1=''unproduktive Fläche'' THEN 632 END as hilucs_value,
    (''{ "table": "SCHLAEGE_GIS_OÖ_VIE", "gid":"''||a.id||''" }'')::json as geometry_source, (''{ "table": "SCHLAEGE_GIS_OÖ_VIE", "gid":"''||a.id||''" }'')::json as attribute_source, ''' || id[i] || ''' as municipal_code FROM hranice_obci b, austria.fields_extended a WHERE ST_INTERSECTS(a.geom, b.geom))
    SELECT ST_INTERSECTION(lpis_rel.geom,a.geom) as geom, lpis_rel.original_value, lpis_rel.hilucs_value, lpis_rel.geometry_source, lpis_rel.attribute_source, lpis_rel.municipal_code FROM lpis_rel, hranice_obci a;' ;

    EXECUTE 'INSERT INTO austria_vysledek.' || lower(id[i]) || ' (geom,original_value,hilucs_value,geometry_source,attribute_source,municipal_code) SELECT geom,original_value,hilucs_value,geometry_source,attribute_source,municipal_code FROM vybrany_lpis';

    EXECUTE 'CREATE TEMP TABLE soucet1 AS SELECT CASE WHEN ST_UNION(geom) IS NOT NULL THEN ST_MakeValid(ST_BUFFER(ST_UNION(ST_BUFFER(geom,0.1)),-0.1)) ELSE ST_SETSRID(''POINT(0 0)''::geometry,3857) END as geom FROM vybrany_lpis;';

    IF ST_Area(a.geom)::bigint!=ST_Area(b.geom)::bigint FROM hranice_obci a, soucet1 b

    THEN

    EXECUTE 'CREATE TEMP TABLE rozdil1 AS SELECT ST_CollectionExtract(ST_MakeValid(ST_DIFFERENCE(ST_MakeValid(ST_Snap(hranice_obci.geom,soucet1.geom,0.1)), soucet1.geom)),3) as geom FROM hranice_obci, soucet1;';

    EXECUTE 'CREATE TEMP TABLE vybrany_ua AS WITH UA_REL AS (SELECT ST_MakeValid(a.geom) as geom, a.code as original_value, a.item as original_land_use, 

    CASE WHEN a.code=''11100'' THEN 500 WHEN a.code=''11200'' THEN 500 WHEN a.code=''11210'' THEN 500 WHEN a.code=''11220'' THEN 500 WHEN a.code=''11230'' THEN 500 WHEN a.code=''11240'' THEN 500 WHEN a.code=''11300'' THEN 500 WHEN a.code=''12100'' THEN 300 WHEN a.code=''12200'' THEN 410 WHEN a.code=''12210'' THEN 411 WHEN a.code=''12220'' THEN 411 WHEN a.code=''12230'' THEN 412 WHEN a.code=''12300'' THEN 414 WHEN a.code=''12400'' THEN 413 WHEN a.code=''13100'' THEN 130 WHEN a.code=''13300'' THEN 600 WHEN a.code=''13400'' THEN 600 WHEN a.code=''14100'' THEN 344 WHEN a.code=''14200'' THEN 340 WHEN a.code=''20000'' THEN 660 WHEN a.code=''30000'' THEN 120 WHEN a.code=''50000'' THEN 660 END as hilucs_value,
    (''{ "table": "urban atlas - ''||a.luz_or_cit||''", "gid":"''||a.ogc_fid||''" }'')::json as geometry_source, (''{ "table": "urban atlas - ''||a.luz_or_cit||''", "gid":"''||a.ogc_fid||''" }'')::json as attribute_source, ''' || id[i] || ''' as municipal_code FROM austria.urban_atlas a, rozdil1
    WHERE ST_INTERSECTS(a.geom, rozdil1.geom) ) SELECT ST_INTERSECTION(ua_rel.geom, rozdil1.geom) as geom, ua_rel.original_value, ua_rel.original_land_use, ua_rel.hilucs_value, ua_rel.geometry_source, ua_rel.attribute_source, ua_rel.municipal_code FROM ua_rel,rozdil1  ';

    EXECUTE 'INSERT INTO austria_vysledek.' || lower(id[i]) || ' (geom,original_value,original_land_use,hilucs_value,geometry_source,attribute_source,municipal_code) SELECT geom,original_value,original_land_use,hilucs_value,geometry_source,attribute_source,municipal_code FROM vybrany_ua';

    EXECUTE 'CREATE TEMP TABLE soucet2 AS SELECT CASE WHEN b.geom IS NOT NULL THEN ST_MakeValid(ST_Buffer(ST_UNION(ST_Buffer(soucet1.geom,0.1),ST_Buffer(b.geom,0.1)),-0.1)) ELSE soucet1.geom END As geom FROM soucet1,(SELECT ST_UNION(geom) As geom FROM vybrany_ua) b;';

IF ST_Area(a.geom)::bigint!=ST_Area(b.geom)::bigint FROM hranice_obci a, soucet2 b
THEN
    EXECUTE 'CREATE TEMP TABLE rozdil2 AS SELECT ST_CollectionExtract(ST_MakeValid(ST_DIFFERENCE(ST_MakeValid(ST_Snap(hranice_obci.geom,soucet2.geom,0.1)), soucet2.geom)),3) as geom FROM hranice_obci, soucet2;';

    EXECUTE 'CREATE TEMP TABLE vybrany_clc AS WITH corine_rel AS (SELECT ST_MakeValid(a.geom) as geom, a.code_12 as original_value,
    CASE WHEN a.code_12=''111'' THEN 500 WHEN a.code_12=''112'' THEN 500 WHEN a.code_12=''121'' THEN 660 WHEN a.code_12=''122'' THEN 410 WHEN a.code_12=''123'' THEN 414 WHEN a.code_12=''124'' THEN 413 WHEN a.code_12=''131'' THEN 130 WHEN a.code_12=''132'' THEN 433 WHEN a.code_12=''133'' THEN 660 WHEN a.code_12=''141'' THEN 340 WHEN a.code_12=''142'' THEN 340 WHEN a.code_12=''211'' THEN 111 WHEN a.code_12=''212'' THEN 111 WHEN a.code_12=''213'' THEN 111 WHEN a.code_12=''221'' THEN 111 WHEN a.code_12=''222'' THEN 111 WHEN a.code_12=''223'' THEN 111 WHEN a.code_12=''231'' THEN 111 WHEN a.code_12=''241'' THEN 111 WHEN a.code_12=''242'' THEN 111 WHEN a.code_12=''243'' THEN 111 WHEN a.code_12=''244'' THEN 120 WHEN a.code_12=''311'' THEN 120 WHEN a.code_12=''312'' THEN 120 WHEN a.code_12=''313'' THEN 120 WHEN a.code_12=''321'' THEN 631 WHEN a.code_12=''322'' THEN 631 WHEN a.code_12=''323'' THEN 631 WHEN a.code_12=''324'' THEN 631 WHEN a.code_12=''331'' THEN 631 WHEN a.code_12=''332'' THEN 631 WHEN a.code_12=''333'' THEN 631 WHEN a.code_12=''334'' THEN 620 WHEN a.code_12=''335'' THEN 631 WHEN a.code_12=''411'' THEN 631 WHEN a.code_12=''412'' THEN 631 WHEN a.code_12=''421'' THEN 631 WHEN a.code_12=''422'' THEN 631 WHEN a.code_12=''423'' THEN 631 WHEN a.code_12=''511'' THEN 414 WHEN a.code_12=''512'' THEN 660 WHEN a.code_12=''521'' THEN 660 WHEN a.code_12=''522'' THEN 414 WHEN a.code_12=''523'' THEN 660 END as hilucs_value,
    (''{ "table": "clc_2012", "gid":"''||a.id||''" }'')::json as geometry_source, (''{ "table": "clc_2012", "gid":"''||a.id||''" }'')::json as attribute_source, ''' || id[i] || ''' as municipal_code FROM corine.clc_12 a, rozdil2
    WHERE ST_INTERSECTS(a.geom, rozdil2.geom) ) SELECT ST_INTERSECTION(corine_rel.geom,rozdil2.geom) as geom, corine_rel.original_value, corine_rel.hilucs_value, corine_rel.geometry_source, corine_rel.attribute_source, corine_rel.municipal_code FROM corine_rel,rozdil2  ';

    EXECUTE 'INSERT INTO austria_vysledek.' || lower(id[i]) || ' (geom, original_value, hilucs_value, geometry_source, attribute_source, municipal_code) SELECT geom, original_value, hilucs_value, geometry_source, attribute_source, municipal_code FROM vybrany_clc';

    EXECUTE 'UPDATE austria_vysledek.' || lower(id[i]) || ' SET geom=ST_CollectionExtract(geom,3);';

    EXECUTE 'CREATE INDEX sidx__obec_' || id[i] || '__geom on austria_vysledek.' || id[i] || ' USING gist(geom);';



    END IF;
    END IF;

    drop table IF EXISTS hranice_obci;
    drop table IF EXISTS vybrany_lpis;
    drop table IF EXISTS soucet1;
    drop table IF EXISTS rozdil1;
    drop table IF EXISTS vybrany_ua;
    drop table IF EXISTS soucet2;
    drop table IF EXISTS rozdil2;
    drop table IF EXISTS vybrany_clc;
    
    i=i+1;  


  END LOOP;

  RETURN id[i-1];
 END;
$BODY$
  LANGUAGE plpgsql VOLATILE STRICT
