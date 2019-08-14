import psycopg2

dbname='olu'
user='jmeno_uzivatele'
password='heslo_uzivatele'
host='10.0.0.26'
port=5432

conn=psycopg2.connect("dbname='%s' user='%s' host='%s' port=%s password='%s'" % (dbname,user,host,port,password) )

cursor=conn.cursor()

#vybrat vsechny prvky OLU z ceske obci s kodem nuts5: cz0209538493
cursor.execute("select * from elu_czechia.cz0209538493")
results=cursor.fetchall()

#vybrat kod nuts5 obce s nazvem Liberec
cursor.execute("select eurostat_code from european_data.elu_vsechny_celky where name='Liberec' and hierarchy_level=5")

cursor.close()
conn.close()
