from sentinelsat import SentinelAPI
import datetime

wkt_point='POINT (16.96081213 49.23467097)'
time_period=(datetime.date(2018, 3, 1),datetime.date(2018,5,1))
cloudcover_range=(0, 25)

user_name='uzivatelske_jmeno'
password='heslo'
folder='slozka_stazeni'

api = SentinelAPI(user_name, password, 'https://scihub.copernicus.eu/dhus')
products = api.query(wkt_point, date=time_period, platformname='Sentinel-2', cloudcoverpercentage=cloudcover_range)
api.download_all(products, folder)
