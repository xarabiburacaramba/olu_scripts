CREATE OR REPLACE FUNCTION olu_obce_eu(id character varying[])
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
    drop table IF EXISTS vybrany_ua;
    drop table IF EXISTS soucet1;
    drop table IF EXISTS rozdil1;
    drop table IF EXISTS vybrany_clc;

    EXECUTE 'DROP TABLE IF EXISTS eu_vysledek.' || lower(id[i]) || ';';

    EXECUTE 'CREATE TABLE eu_vysledek.' || lower(id[i]) || '()  INHERITS (eu_vysledek.areas_master);';

    EXECUTE 'CREATE TEMP TABLE hranice_obci AS SELECT ST_Union(ST_MakeValid(geom)) As geom FROM european_data.communities_eurostat WHERE comm_id='''||id[i]||''';' ;

    EXECUTE 'CREATE TEMP TABLE vybrany_ua AS WITH UA_REL AS (SELECT ST_MakeValid(a.geom) as geom, a.code as original_value,  
    CASE WHEN a.code=''11100'' THEN 500 WHEN a.code=''11200'' THEN 500 WHEN a.code=''11210'' THEN 500 WHEN a.code=''11220'' THEN 500 WHEN a.code=''11230'' THEN 500 WHEN a.code=''11240'' THEN 500 WHEN a.code=''11300'' THEN 500 WHEN a.code=''12100'' THEN 300 WHEN a.code=''12200'' THEN 410 WHEN a.code=''12210'' THEN 411 WHEN a.code=''12220'' THEN 411 WHEN a.code=''12230'' THEN 412 WHEN a.code=''12300'' THEN 414 WHEN a.code=''12400'' THEN 413 WHEN a.code=''13100'' THEN 130 WHEN a.code=''13300'' THEN 600 WHEN a.code=''13400'' THEN 600 WHEN a.code=''14100'' THEN 344 WHEN a.code=''14200'' THEN 340 WHEN a.code=''20000'' THEN 660 WHEN a.code=''30000'' THEN 120 WHEN a.code=''50000'' THEN 660 END as hilucs_value,
    (''{ "table": "urban atlas - ''||a.luz_or_cit||''", "gid":"''||a.gid||''" }'')::json as geometry_source, (''{ "table": "urban atlas - ''||a.luz_or_cit||''", "gid":"''||a.gid||''" }'')::json as attribute_source, ''' || id[i] || ''' as municipal_code, (a.prod_date||''-01-01'')::date as validfrom, ''existing'' as discr FROM urbanatlas.urban_atlas a, hranice_obci b
    WHERE ST_INTERSECTS(a.geom, b.geom) ) SELECT ST_INTERSECTION(ua_rel.geom, b.geom) as geom, ua_rel.original_value, ua_rel.hilucs_value, ua_rel.geometry_source, ua_rel.attribute_source, ua_rel.municipal_code, ua_rel.validfrom, ua_rel.discr FROM ua_rel,hranice_obci b  ';
  

    EXECUTE 'INSERT INTO eu_vysledek.' || lower(id[i]) || ' (geom,original_value,hilucs_value,geometry_source,attribute_source,municipal_code,validfrom,discr) SELECT geom,original_value,hilucs_value,geometry_source,attribute_source,municipal_code,validfrom,discr FROM vybrany_ua';

    EXECUTE 'CREATE TEMP TABLE soucet1 AS SELECT CASE WHEN ST_UNION(geom) IS NOT NULL THEN ST_MakeValid(ST_BUFFER(ST_UNION(ST_BUFFER(geom,0.1)),-0.1)) ELSE ST_SETSRID(''POINT(0 0)''::geometry,3857) END as geom FROM vybrany_ua;';

    IF ST_Area(a.geom)::bigint!=ST_Area(b.geom)::bigint FROM hranice_obci a, soucet1 b

    THEN

    EXECUTE 'CREATE TEMP TABLE rozdil1 AS SELECT ST_CollectionExtract(ST_MakeValid(ST_DIFFERENCE(ST_MakeValid(ST_Snap(hranice_obci.geom,soucet1.geom,0.1)), soucet1.geom)),3) as geom FROM hranice_obci, soucet1;';

    EXECUTE 'CREATE TEMP TABLE vybrany_clc AS WITH corine_rel AS (SELECT ST_MakeValid(a.geom) as geom, a.code_12 as original_value,
    CASE WHEN a.code_12=''111'' THEN 500 WHEN a.code_12=''112'' THEN 500 WHEN a.code_12=''121'' THEN 660 WHEN a.code_12=''122'' THEN 410 WHEN a.code_12=''123'' THEN 414 WHEN a.code_12=''124'' THEN 413 WHEN a.code_12=''131'' THEN 130 WHEN a.code_12=''132'' THEN 433 WHEN a.code_12=''133'' THEN 660 WHEN a.code_12=''141'' THEN 340 WHEN a.code_12=''142'' THEN 340 WHEN a.code_12=''211'' THEN 111 WHEN a.code_12=''212'' THEN 111 WHEN a.code_12=''213'' THEN 111 WHEN a.code_12=''221'' THEN 111 WHEN a.code_12=''222'' THEN 111 WHEN a.code_12=''223'' THEN 111 WHEN a.code_12=''231'' THEN 111 WHEN a.code_12=''241'' THEN 111 WHEN a.code_12=''242'' THEN 111 WHEN a.code_12=''243'' THEN 111 WHEN a.code_12=''244'' THEN 120 WHEN a.code_12=''311'' THEN 120 WHEN a.code_12=''312'' THEN 120 WHEN a.code_12=''313'' THEN 120 WHEN a.code_12=''321'' THEN 631 WHEN a.code_12=''322'' THEN 631 WHEN a.code_12=''323'' THEN 631 WHEN a.code_12=''324'' THEN 631 WHEN a.code_12=''331'' THEN 631 WHEN a.code_12=''332'' THEN 631 WHEN a.code_12=''333'' THEN 631 WHEN a.code_12=''334'' THEN 620 WHEN a.code_12=''335'' THEN 631 WHEN a.code_12=''411'' THEN 631 WHEN a.code_12=''412'' THEN 631 WHEN a.code_12=''421'' THEN 631 WHEN a.code_12=''422'' THEN 631 WHEN a.code_12=''423'' THEN 631 WHEN a.code_12=''511'' THEN 414 WHEN a.code_12=''512'' THEN 660 WHEN a.code_12=''521'' THEN 660 WHEN a.code_12=''522'' THEN 414 WHEN a.code_12=''523'' THEN 660 END as hilucs_value,
    (''{ "table": "clc_2012", "gid":"''||a.id||''" }'')::json as geometry_source, (''{ "table": "clc_2012", "gid":"''||a.id||''" }'')::json as attribute_source, ''' || id[i] || ''' as municipal_code, ''2012-01-01''::date as validfrom, ''existing'' as discr FROM corine.clc_12 a, rozdil1
    WHERE ST_INTERSECTS(a.geom, rozdil1.geom) ) SELECT ST_INTERSECTION(corine_rel.geom,rozdil1.geom) as geom, corine_rel.original_value, corine_rel.hilucs_value, corine_rel.geometry_source, corine_rel.attribute_source, corine_rel.municipal_code, corine_rel.validfrom, corine_rel.discr FROM corine_rel,rozdil1  ';

    EXECUTE 'INSERT INTO eu_vysledek.' || lower(id[i]) || ' (geom, original_value, hilucs_value, geometry_source, attribute_source, municipal_code, validfrom, discr) SELECT geom, original_value, hilucs_value, geometry_source, attribute_source, municipal_code, validfrom, discr FROM vybrany_clc';

    EXECUTE 'UPDATE eu_vysledek.' || lower(id[i]) || ' SET geom=ST_CollectionExtract(geom,3);';

    EXECUTE 'CREATE INDEX sidx__obec_' || id[i] || '__geom on eu_vysledek.' || id[i] || ' USING gist(geom);';



    END IF;

    drop table IF EXISTS hranice_obci;
    drop table IF EXISTS vybrany_ua;
    drop table IF EXISTS soucet1;
    drop table IF EXISTS rozdil1;
    drop table IF EXISTS vybrany_clc;

    
    i=i+1;  


  END LOOP;

  RETURN id[i-1];
 END;
$BODY$
  LANGUAGE plpgsql VOLATILE STRICT
