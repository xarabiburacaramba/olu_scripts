import requests

#ohranicujici obdelnik v souradnicovem systemu EPSG:3857
bbox='1637091,6434795,1637092,6434796'

folder='slozka_stazeni'

url='http://gis.lesprojekt.cz/cgi-bin/mapserv?map=/home/dima/maps/olu/european_openlandusemap.map&service=WFS&VERSION=1.1.0&REQUEST=GetFeature&TYPENAME=olu_bbox&SRSNAME=EPSG:3857&BBOX=%s&outputformat=geojson' % bbox

r=requests.get(url, stream=True)

if r.status_code==200:
    with open(folder, 'wb') as f:
        f.write(r.content)
else:
    print(r.status_code)
