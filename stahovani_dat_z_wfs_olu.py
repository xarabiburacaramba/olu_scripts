import requests

#ohranicujici obdelnik v souradnicovem systemu EPSG:3857
bbox='2019772,6384876,2040929,6372402'
limit=1000
offset=0

folder='/slozka_stazeni/'

url='http://gis.lesprojekt.cz/cgi-bin/mapserv?map=/home/dima/maps/olu/european_openlandusemap.map&service=WFS&VERSION=1.1.0&REQUEST=GetFeature&TYPENAME=olu_bbox&SRSNAME=EPSG:3857&BBOX=%s&OFFSET=%s&LIMIT=%s&outputformat=geojson' % (bbox, offset, limit)

i=0

r=requests.get(url, stream=True)

while len(r.text)>0 and r.status_code==200:
    with open(folder+str(i)+'.json', 'wb') as f:
        f.write(r.content)
    offset+=limit
    i+=1
    url='http://gis.lesprojekt.cz/cgi-bin/mapserv?map=/home/dima/maps/olu/european_openlandusemap.map&service=WFS&VERSION=1.1.0&REQUEST=GetFeature&TYPENAME=olu_bbox&SRSNAME=EPSG:3857&BBOX=%s&OFFSET=%s&LIMIT=%s&outputformat=geojson' % (bbox, offset, limit)
    r=requests.get(url, stream=True)
    
