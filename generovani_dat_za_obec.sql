-- funkce, co generuje data do tabulky obce dle seznamu s cisly obci
CREATE OR REPLACE FUNCTION elu_obce_cz(id character varying[])
  RETURNS character varying AS
$BODY$

  DECLARE
    e integer;
    i integer;
  BEGIN

  e:=array_length(id,1);
  i:=1;
  -- cyklus, co prochazi vsema obcemi na seznamu 
  WHILE i <= e LOOP
    -- smaz docasnou tabulku hranice_obci, pokud existuje
    drop table IF EXISTS hranice_obci;
    -- smaz docasnou tabulku vybrane_parcely, pokud existuje
    drop table IF EXISTS vybrane_parcely;
    -- smaz docasnou tabulku soucet parcel, pokud existuje
    drop table IF EXISTS soucet1;
    drop table IF EXISTS rozdil1;
    drop table IF EXISTS vybrany_lpis;
    drop table IF EXISTS soucet2;
    drop table IF EXISTS rozdil2;
    drop table IF EXISTS vybrany_ua;
    drop table IF EXISTS soucet3;
    drop table IF EXISTS rozdil3;
    drop table IF EXISTS vybrany_clc;

    drop table if exists vybrane_parcely_adj;
    drop table if exists vybrane_parcely_adj2;
    drop table if exists vybrane_parcely_adj3;

    -- smaz tabulku s vyuzitim krajiny v dane obci pokud existuje
    EXECUTE 'drop table IF EXISTS elu_czechia.' || lower(id[i]) || ';';
    -- vytvor prazdnou tabulku s vyuzitim krajiny v dane obci na zaklade datoveho modelu OLU
    EXECUTE 'create table if not exists elu_czechia.' || lower(id[i]) || ' ( id bigint default nextval(''european_land_use.areas_master_id_seq'') NOT NULL, geom public.geometry NOT NULL, hilucs_value numeric(3,0), original_value text NOT NULL, geometry_source json NOT NULL, attribute_source json, country_code character varying(3) NOT NULL DEFAULT ''CZ'', municipal_code character varying(31) DEFAULT ''' || id[i] || ''', discr character varying(31) DEFAULT ''existing'', validfrom date, validto date );';

    -- vytvor docasnou tabulku hranice_obci, do ktere se nactou hranice obce z tabulky ft_obce(tabulka s hranicemi vsech obci)
    EXECUTE 'CREATE TEMP TABLE hranice_obci AS SELECT ST_MakeValid(geom_3857) As geom FROM ft_obce WHERE kod=' || substring(id[i] from 7 for 6) || ';';

    -- vytvor docasnou tabulku vybrane_parcely, do ktere se nactou parcely, ktere lezeji v dane obci
    EXECUTE 'CREATE TEMP TABLE vybrane_parcely AS
    SELECT ST_MakeValid(a.geom_3857) as geom, a.geometry_source::json as geometry_source, a.attribute_source::json as attribute_source, a.original_value, a.hilucs_value, b.platiod as validfrom, b.platido as validto FROM ft__elu_czechia__cz' || substring(id[i] from 3 for 4) || ' a, ft_parcely b  WHERE (''PA.''||substring((a.geometry_source::json->>''url'') from ''[0-9]+$''))=b.gml_id AND ST_Area(a.geom_3857)>0.1 AND ST_Dimension(a.geom_3857)>1 AND a.municipal_code=''' || id[i] || ''';';

    -- prenes data s docasne tabulky do vysledne tabulky s vyuzitim krajiny v dane obci
    EXECUTE 'INSERT INTO elu_czechia.' || lower(id[i]) || ' (geom,geometry_source,attribute_source,original_value,hilucs_value,validfrom,validto) SELECT geom,geometry_source,attribute_source,original_value,hilucs_value,NULLIF(validfrom,''None'')::date,NULLIF(validto,''None'')::date FROM vybrane_parcely;';

    -- nastav druh geometrie parcel jako jednotlive polygony
    EXECUTE 'UPDATE elu_czechia.' || lower(id[i]) || ' SET geom=ST_CollectionExtract(geom,3);';

    -- vytvor index na zaklade sloupce s geometrii
    EXECUTE 'CREATE INDEX sidx__elu_czechia_' || lower(id[i]) || '__geom on elu_czechia.' || lower(id[i]) || ' USING gist(geom);';

    -- vytvor masku uzemi obce,  jez je pokryta prvky OLU z minuleho kroku
    EXECUTE 'CREATE TEMP TABLE soucet1 AS SELECT CASE WHEN ST_UNION(geom) IS NOT NULL THEN ST_MakeValid(ST_BUFFER(ST_UNION(ST_BUFFER(geom,0.1)),-0.1)) ELSE ST_SETSRID(''POINT(0 0)''::geometry,3857) END as geom FROM vybrane_parcely;';

   -- okomentovany blok kodu, ktery lze pouzit na slouceni sousedicich parcel se stejnym zpusobem vyuziti
    /*EXECUTE 'create table public.vybrane_parcely_adj as SELECT a.id as id, b.id as adj from (select * from elu_czechia.' || lower(id[i]) || ') a,(select * from elu_czechia.' || lower(id[i]) || ') b where a.geom&&b.geom and substring(st_relate(a.geom, b.geom) from 1 for 1)=''2'' and a.id!=b.id;';
    
    EXECUTE 'create table vybrane_parcely_adj2 as select * from graph_cluster_cc(''vybrane_parcely_adj'');';

    EXECUTE 'create table vybrane_parcely_adj3 as (select a.skupina, st_union(b.geom) as geom from vybrane_parcely_adj2 a, elu_czechia.cz0100554782 b where a.id=b.id group by a.skupina union all select 0 as skupina, geom from elu_czechia.' || lower(id[i]) || ' where id not in (select id from vybrane_parcely_adj2) );';

    EXECUTE 'CREATE TEMP TABLE soucet1 AS SELECT CASE WHEN ST_UNION(geom) IS NOT NULL THEN ST_MakeValid(ST_BUFFER(ST_UNION(ST_BUFFER(geom,0.1)),-0.1)) ELSE ST_SETSRID(''POINT(0 0)''::geometry,3857) END as geom FROM vybrane_parcely_adj3;';*/

-- pokud uzemi obce neni zcela pokryte maskou z minuleho kroku
 IF ST_Area(a.geom)::bigint!=ST_Area(b.geom)::bigint FROM hranice_obci a, soucet1 b

    THEN

    -- vymez uzemi obce, ktere neni pokryte datami parcel
    EXECUTE 'CREATE TEMP TABLE rozdil1 AS SELECT ST_CollectionExtract(ST_MakeValid(ST_DIFFERENCE(ST_MakeValid(ST_Snap(hranice_obci.geom,soucet1.geom,0.1)), soucet1.geom)),3) as geom FROM hranice_obci, soucet1;';

    -- vyber prvky lpisu, ktere se krizeji se zbytkem uzemi obce (data  z minuleho kroku)
    EXECUTE 'CREATE TEMP TABLE vybrany_lpis AS WITH LPIS_REL AS (SELECT ST_MakeValid(lpis.geom_3857) as geom, (''{ "table": "lpis", "gid":"''||lpis.fid||''" }'')::json as geometry_source,
    (''{ "table": "lpis", "attribute": "kulturakod", "gid":"''||lpis.fid||''" }'')::json as attribute_source,
    lpis.kulturakod as original_value, lpis.hilucs_value, lpis.kulturaod::date as validfrom FROM lpis.lpis18032017 as lpis, rozdil1
    WHERE ST_INTERSECTS(lpis.geom_3857, rozdil1.geom) ) SELECT ST_INTERSECTION(lpis_rel.geom, rozdil1.geom) as geom, lpis_rel.geometry_source, lpis_rel.attribute_source,lpis_rel.original_value,lpis_rel.hilucs_value,lpis_rel.validfrom FROM lpis_rel,rozdil1;';
  
    -- prenes prvky z minuleho kroku do cilove tabulky
    EXECUTE 'INSERT INTO elu_czechia.' || lower(id[i]) || ' (geom,original_value,hilucs_value,geometry_source,attribute_source,validfrom) SELECT geom,original_value,hilucs_value,geometry_source,attribute_source,validfrom FROM vybrany_lpis;';

    -- vytvor masku uzemi obce, co je jiz pokryta prvky OLU
    EXECUTE 'CREATE TEMP TABLE soucet2 AS SELECT CASE WHEN b.geom IS NOT NULL THEN ST_MakeValid(ST_Buffer(ST_UNION(ST_Buffer(soucet1.geom,0.1),ST_Buffer(b.geom,0.1)),-0.1)) ELSE soucet1.geom END As geom FROM soucet1,(SELECT ST_UNION(geom) As geom FROM vybrany_lpis) b;';

-- pokud ne cele uzemi obce je pokryto daty OLU, pokracuj
 IF ST_Area(a.geom)::bigint!=ST_Area(b.geom)::bigint FROM hranice_obci a, soucet2 b
    THEN

    -- vytvot docasnou tabulku rozdil2, do ktere se nahraje rozdil mezi celkovou plochou obce a plochou obce, pro niz olu jiz existuje
    EXECUTE 'CREATE TEMP TABLE rozdil2 AS SELECT ST_CollectionExtract(ST_MakeValid(ST_DIFFERENCE(ST_MakeValid(ST_Snap(hranice_obci.geom,soucet2.geom,0.1)), soucet2.geom)),3) as geom FROM hranice_obci, soucet2;';

    
    --vyber prvky urban atlasu, ktere se krizeji se zbytkem uzemi obce (data  z minuleho kroku)
    EXECUTE 'CREATE TEMP TABLE vybrany_ua AS WITH ua_rel AS (SELECT ST_MakeValid(a.geom) as geom, a.code as original_value,  
    CASE WHEN a.code=''11100'' THEN 500 WHEN a.code=''11200'' THEN 500 WHEN a.code=''11210'' THEN 500 WHEN a.code=''11220'' THEN 500 WHEN a.code=''11230'' THEN 500 WHEN a.code=''11240'' THEN 500 WHEN a.code=''11300'' THEN 500 WHEN a.code=''12100'' THEN 300 WHEN a.code=''12200'' THEN 410 WHEN a.code=''12210'' THEN 411 WHEN a.code=''12220'' THEN 411 WHEN a.code=''12230'' THEN 412 WHEN a.code=''12300'' THEN 414 WHEN a.code=''12400'' THEN 413 WHEN a.code=''13100'' THEN 130 WHEN a.code=''13300'' THEN 600 WHEN a.code=''13400'' THEN 600 WHEN a.code=''14100'' THEN 344 WHEN a.code=''14200'' THEN 340 WHEN a.code=''20000'' THEN 660 WHEN a.code=''30000'' THEN 120 WHEN a.code=''50000'' THEN 660 END as hilucs_value,
    (''{ "table": "urban atlas - ''||a.luz_or_cit||''", "gid":"''||a.gid||''" }'')::json as geometry_source, (''{ "table": "urban atlas - ''||a.luz_or_cit||''", "gid":"''||a.gid||''" }'')::json as attribute_source, (a.prod_date||''-01-01'')::date as validfrom FROM urbanatlas.urban_atlas a, rozdil2 b
    WHERE ST_INTERSECTS(a.geom, b.geom) ) SELECT ST_INTERSECTION(ua_rel.geom, b.geom) as geom, ua_rel.original_value, ua_rel.hilucs_value, ua_rel.geometry_source, ua_rel.attribute_source, ua_rel.validfrom FROM ua_rel, rozdil2 b;'; 

    --prenes prvky z minuleho kroku do cilove tabulky
    EXECUTE 'INSERT INTO elu_czechia.' || lower(id[i]) || ' (geom,original_value,hilucs_value,geometry_source,attribute_source,validfrom) SELECT geom,original_value,hilucs_value,geometry_source,attribute_source,validfrom FROM vybrany_ua;';

    -- vytvor masku uzemi obce, co je jiz pokryta prvky OLU
    EXECUTE 'CREATE TEMP TABLE soucet3 AS SELECT CASE WHEN b.geom IS NOT NULL THEN ST_MakeValid(ST_Buffer(ST_UNION(ST_Buffer(soucet2.geom,0.1),ST_Buffer(b.geom,0.1)),-0.1)) ELSE soucet2.geom END As geom FROM soucet2, (SELECT ST_UNION(geom) As geom FROM vybrany_ua) b;';

-- pokud ne cele uzemi obce je pokryto daty OLU, pokracuj
 IF ST_Area(a.geom)::bigint!=ST_Area(b.geom)::bigint FROM hranice_obci a, soucet3 b
    THEN
    
    -- vytvot docasnou tabulku rozdil2, do ktere se nahraje rozdil mezi celkovou plochou obce a plochou obce, pro niz olu jiz existuje
    EXECUTE 'CREATE TEMP TABLE rozdil3 AS SELECT ST_CollectionExtract(ST_MakeValid(ST_DIFFERENCE(ST_MakeValid(ST_Snap(hranice_obci.geom,soucet3.geom,0.1)), soucet3.geom)),3) as geom FROM hranice_obci, soucet3;';
    
    --vyber prvky corine land coveru, ktere se krizeji se zbytkem uzemi obce (data  z minuleho kroku)
    EXECUTE 'CREATE TEMP TABLE vybrany_clc AS WITH corine_rel AS (SELECT ST_MakeValid(a.geom) as geom, a.code_12 as original_value,
    CASE WHEN a.code_12=''111'' THEN 500 WHEN a.code_12=''112'' THEN 500 WHEN a.code_12=''121'' THEN 660 WHEN a.code_12=''122'' THEN 410 WHEN a.code_12=''123'' THEN 414 WHEN a.code_12=''124'' THEN 413 WHEN a.code_12=''131'' THEN 130 WHEN a.code_12=''132'' THEN 433 WHEN a.code_12=''133'' THEN 660 WHEN a.code_12=''141'' THEN 340 WHEN a.code_12=''142'' THEN 340 WHEN a.code_12=''211'' THEN 111 WHEN a.code_12=''212'' THEN 111 WHEN a.code_12=''213'' THEN 111 WHEN a.code_12=''221'' THEN 111 WHEN a.code_12=''222'' THEN 111 WHEN a.code_12=''223'' THEN 111 WHEN a.code_12=''231'' THEN 111 WHEN a.code_12=''241'' THEN 111 WHEN a.code_12=''242'' THEN 111 WHEN a.code_12=''243'' THEN 111 WHEN a.code_12=''244'' THEN 120 WHEN a.code_12=''311'' THEN 120 WHEN a.code_12=''312'' THEN 120 WHEN a.code_12=''313'' THEN 120 WHEN a.code_12=''321'' THEN 631 WHEN a.code_12=''322'' THEN 631 WHEN a.code_12=''323'' THEN 631 WHEN a.code_12=''324'' THEN 631 WHEN a.code_12=''331'' THEN 631 WHEN a.code_12=''332'' THEN 631 WHEN a.code_12=''333'' THEN 631 WHEN a.code_12=''334'' THEN 620 WHEN a.code_12=''335'' THEN 631 WHEN a.code_12=''411'' THEN 631 WHEN a.code_12=''412'' THEN 631 WHEN a.code_12=''421'' THEN 631 WHEN a.code_12=''422'' THEN 631 WHEN a.code_12=''423'' THEN 631 WHEN a.code_12=''511'' THEN 414 WHEN a.code_12=''512'' THEN 660 WHEN a.code_12=''521'' THEN 660 WHEN a.code_12=''522'' THEN 414 WHEN a.code_12=''523'' THEN 660 END as hilucs_value,
    (''{ "table": "clc_2012", "gid":"''||a.id||''" }'')::json as geometry_source, (''{ "table": "clc_2012", "gid":"''||a.id||''" }'')::json as attribute_source, ''2012-01-01''::date as validfrom FROM corine.clc_12 a, rozdil3
    WHERE ST_INTERSECTS(a.geom, rozdil3.geom) ) SELECT ST_INTERSECTION(corine_rel.geom,rozdil3.geom) as geom, corine_rel.original_value, corine_rel.hilucs_value, corine_rel.geometry_source, corine_rel.attribute_source, corine_rel.validfrom FROM corine_rel,rozdil3;';

    --prenes prvky z minuleho kroku do cilove tabulky
   EXECUTE 'INSERT INTO elu_czechia.' || lower(id[i]) || ' (geom,hilucs_value,original_value,geometry_source,attribute_source) SELECT geom,hilucs_value,original_value,geometry_source,attribute_source FROM vybrany_clc;';

 END IF;
 END IF;
 END IF;

   EXECUTE 'UPDATE elu_czechia.' || lower(id[i]) || ' SET geom=ST_CollectionExtract(geom,3);';

   EXECUTE 'DELETE from elu_czechia.' || lower(id[i]) || ' where st_area(geom)=0;';

   --EXECUTE 'vacuum full analyze elu_czechia.' || lower(id[i]) || ';';
   
   i=i+1; 

 END LOOP;

 RETURN id[i-1];
 END;
$BODY$
  LANGUAGE plpgsql VOLATILE STRICT
