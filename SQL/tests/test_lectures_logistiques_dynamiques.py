"""Correction30_02, sur la base privée produite par la recette SQL30_01.

Cette seconde étape conserve les fixtures privées du premier script pour
contrôler un type réellement utilisé, puis retiré des choix courants.
"""
import hashlib,json,os
from pathlib import Path
from urllib.parse import urlsplit
import psycopg
from psycopg import sql

ROOT=Path(__file__).resolve().parents[2]
DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','')
target=urlsplit(DSN)
if target.hostname not in {'localhost','127.0.0.1'} or not target.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Base privée locale explicitement requise.')
checks=[]
def check(ok,label):
    assert ok,label
    checks.append(label)

with psycopg.connect(DSN,autocommit=True) as c:
    article=c.execute('SELECT a."ID_Article",a."ID_CategorieArticleFk",g."NomGenerique",a."QteArticle",b."ID_Commande",b."ID_TypeCmdFk" FROM logistique."T_Article" a JOIN referentiel."T_Generique" g ON g."ID_Generique"=a."ID_CategorieArticleFk" JOIN logistique."T_Commande" b ON b."ID_ArticleInitialFk"=a."ID_Article" WHERE a."NomArticle" LIKE %s ORDER BY a."ID_Article" DESC LIMIT 1',['Article fictif privé %']).fetchone()
    if article is None:raise RuntimeError('Exécuter d’abord test_referentiels_transversaux_postgresql.py sur ce socle09 privé.')
    # Retirer le type privé du choix courant ne doit pas effacer son effet dans
    # les documents déjà enregistrés. Ne change ni la valeur ni le mouvement.
    field=c.execute('SELECT "ID_ChampReferentiel","ID_CategorieDefautFk" FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=%s AND "TableName"=%s AND "ColumnName"=%s',['logistique','T_Commande','ID_TypeCmdFk']).fetchone()
    c.execute('UPDATE systeme."T_Fk_Correspondance" SET "TargetCategoryIdFk"=%s,"MappingValue"=%s WHERE "IdChampReferentielFk"=%s AND "SettingScope"=%s',[field[1],str(field[1]),field[0],'global'])
    check(c.execute('SELECT logistique.fn_nature_bon(%s)',[article[5]]).fetchone()[0]=='entree','Le type historique retiré des choix reste une entrée reconnue')
    schemas=['analytics','communication','geolocalisation','logistique','operations','professionnel','referentiel','systeme','public']
    tables=c.execute('SELECT schemaname,tablename FROM pg_tables WHERE schemaname=ANY(%s) ORDER BY 1,2',[schemas]).fetchall()
    def data():
        return {s+'.'+t:c.execute(sql.SQL("SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(x)::text),'' ORDER BY md5(to_jsonb(x)::text)),'')) FROM {}.{} x").format(sql.Identifier(s),sql.Identifier(t))).fetchone() for s,t in tables}
    def metadata():
        return {
            'views':dict(c.execute("SELECT schemaname||'.'||viewname,definition FROM pg_views WHERE schemaname=ANY(%s)",[schemas]).fetchall()),
            'functions':dict(c.execute("SELECT n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')',pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname=ANY(%s) AND p.prokind IN('f','p')",[schemas]).fetchall()),
            'constraints':c.execute("SELECT conrelid::regclass::text,conname,pg_get_constraintdef(oid,true) FROM pg_constraint WHERE connamespace IN(SELECT oid FROM pg_namespace WHERE nspname=ANY(%s)) ORDER BY 1,2",[schemas]).fetchall(),
            'triggers':c.execute("SELECT tgrelid::regclass::text,tgname,tgenabled,pg_get_triggerdef(oid) FROM pg_trigger WHERE NOT tgisinternal ORDER BY 1,2").fetchall(),
            'columns':c.execute("SELECT table_schema,table_name,column_name,ordinal_position,data_type FROM information_schema.columns WHERE table_schema=ANY(%s) ORDER BY 1,2,4",[schemas]).fetchall(),
        }
    before,old=data(),metadata()
    path=ROOT/'SQL/migrations/20261030_02_lectures_logistiques_dynamiques.sql'
    c.execute(path.read_text(encoding='utf8'))
    current=metadata()
    check(data()==before,'Toutes les tables et données physiques sont conservées')
    for kind in ['constraints','triggers','columns']:
        check(old[kind]==current[kind],'Métadonnées inchangées : '+kind)
    expected={'logistique.'+v for v in ['V_Article','V_Commande','V_CommandeDetail','V_CommandesSansDetails','V_Mouvement','V_MouvementStock','V_RetourArticle','V_RetourLot']}
    check(old['views'].keys()==current['views'].keys(),'Aucune vue ajoutée ou supprimée')
    check({v for v in old['views'] if old['views'][v]!=current['views'][v]}==expected,'Seules les huit vues autorisées changent')
    changed=[v for v in old['functions'] if old['functions'][v]!=current['functions'][v]]
    check(old['functions'].keys()==current['functions'].keys() and len(changed)==1 and changed[0].startswith('logistique.tr_proteger_facture('),'Seul le filtre de nature de la garde de facture évolue')
    check(c.execute('SELECT "CategorieArticle" FROM logistique."V_Article" WHERE "ID_Article"=%s',[article[0]]).fetchone()[0]==article[2],'Le libellé de catégorie privée de l’article est affiché')
    for view in ['V_Mouvement','V_MouvementStock']:
        row=c.execute(sql.SQL('SELECT "SigneStock","QteMvtSigned" FROM logistique.{} WHERE "ID_cmdFk"=%s').format(sql.Identifier(view)),[article[4]]).fetchone()
        check(row==(1,article[3]),view+' conserve le signe et la quantité de l’entrée historique privée')
    check(c.execute('SELECT "MontantMvtSigned"="QteMvt"*"PUMvt" FROM logistique."V_MouvementStock" WHERE "ID_cmdFk"=%s',[article[4]]).fetchone()[0], 'Le montant signé retrouve le sens physique de l’entrée')
    check(c.execute('SELECT "TypeCmd" FROM logistique."V_Commande" WHERE "ID_Commande"=%s',[article[4]]).fetchone()[0] is not None,'Le libellé du type historique privé du bon reste visible')
    for name in expected:
        check('ID_CategorieGeneriqueFk' not in current['views'][name],name+' ne contient plus de filtre de famille fixe')

output=ROOT/'.runtime/referentiels30-lectures'
output.mkdir(exist_ok=True)
(output/'verification.json').write_text(json.dumps({'passed':True,'checks':len(checks),'details':checks,'database':target.path[1:],'migrationSHA256':hashlib.sha256(path.read_bytes()).hexdigest(),'productionModified':False},ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'passed':True,'checks':len(checks),'database':target.path[1:]}))
