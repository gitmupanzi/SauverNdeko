"""Concurrence de précision : base privée locale uniquement, aucun document métier.
Les unités fictives de cette recette restent dans la base dédiée afin de conserver
les protections de non-suppression. Aucune migration ni base n’est créée ici.
"""
import os,time,uuid,threading
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlsplit
import psycopg

dsn=os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL","");url=urlsplit(dsn)
if url.scheme not in {"postgres","postgresql"} or url.hostname not in {"localhost","127.0.0.1","::1"} or not url.path[1:].startswith("sauverndeko_test_"):
 raise RuntimeError("Base privée locale sauverndeko_test_* explicitement requise.")
checks=[]
def check(value,label):
 if not value:raise AssertionError(label)
 checks.append(label)
def waiting(observer,pid):
 deadline=time.monotonic()+3
 while time.monotonic()<deadline:
  row=observer.execute("SELECT wait_event_type FROM pg_stat_activity WHERE pid=%s",[pid]).fetchone()
  if row and row[0]=="Lock":return True
  time.sleep(.04)
 return False

with psycopg.connect(dsn,autocommit=True) as observer:
 check(observer.execute("SELECT current_database()").fetchone()[0].startswith("sauverndeko_test_"),"base privée vérifiée")
 unit=observer.execute('''INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique")
 VALUES(34,%s,'recette',true) RETURNING "ID_Generique"''',["Précision concurrence "+uuid.uuid4().hex]).fetchone()[0]
 observer.execute('INSERT INTO logistique."T_PrecisionStock"("ID_UniteFk","DecimalesStock") VALUES(%s,3)',[unit])
 with ThreadPoolExecutor(max_workers=1) as pool:
  started=threading.Event();worker_pid=[]
  def reduce():
   with psycopg.connect(dsn) as writer:
    writer.execute("SET LOCAL lock_timeout='8s'")
    worker_pid.append(writer.info.backend_pid);started.set()
    writer.execute('UPDATE logistique."T_PrecisionStock" SET "DecimalesStock"=0 WHERE "ID_UniteFk"=%s',[unit])
   return True
  with psycopg.connect(dsn) as reader:
   reader.execute("SELECT logistique.fn_verifier_quantite(%s,1.125)",[unit])
   future=pool.submit(reduce);check(started.wait(3),"mise à jour concurrente démarrée")
   check(waiting(observer,worker_pid[0]),"la réduction attend la validation de quantité en cours")
   reader.commit()
   check(future.result(timeout=8),"réduction terminée après libération du verrou")
  check(observer.execute('SELECT "DecimalesStock" FROM logistique."T_PrecisionStock" WHERE "ID_UniteFk"=%s',[unit]).fetchone()[0]==0,"nouvelle politique visible")
  observer.execute('UPDATE logistique."T_PrecisionStock" SET "DecimalesStock"=3 WHERE "ID_UniteFk"=%s',[unit])
  started=threading.Event();worker_pid=[]
  def fractional():
   try:
    with psycopg.connect(dsn) as reader:
     reader.execute("SET LOCAL lock_timeout='8s'")
     worker_pid.append(reader.info.backend_pid);started.set()
     reader.execute("SELECT logistique.fn_verifier_quantite(%s,1.125)",[unit])
    return "accepted"
   except psycopg.Error as error:return error.sqlstate
  with psycopg.connect(dsn) as writer:
   writer.execute('UPDATE logistique."T_PrecisionStock" SET "DecimalesStock"=0 WHERE "ID_UniteFk"=%s',[unit])
   future=pool.submit(fractional);check(started.wait(3),"validation concurrente démarrée")
   check(waiting(observer,worker_pid[0]),"la validation attend la configuration de précision en cours")
   writer.commit()
   check(future.result(timeout=8)=="23514","la quantité est revérifiée avec la précision validée")
print("PASS",len(checks),checks)
