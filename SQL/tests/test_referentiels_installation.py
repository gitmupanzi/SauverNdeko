"""Recette réelle du paquet30 : source ET destination privées locales.

Ne crée aucune donnée dans SauverNdeko. Préparer une base de recette à jour,
contenant éventuellement des catégories, valeurs et précisions privées, puis
définir SAUVERNDEKO_TEST_DATABASE_URL. Le paquet exporté ne les reprend pas.
"""
import hashlib
import json
import os
import subprocess
import uuid
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

import psycopg
from psycopg import sql

ROOT=Path(__file__).resolve().parents[2]
DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','')
target=urlsplit(DSN)
if target.hostname not in {'localhost','127.0.0.1'} or not target.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Source privée locale sauverndeko_test_* explicitement requise.')
BIN=Path(os.environ.get('SAUVERNDEKO_TEST_PG_BIN','C:/Program Files/PostgreSQL/18/bin'))
directory=ROOT/('.runtime/referentiels30-installation-'+uuid.uuid4().hex[:8])
directory.mkdir(parents=True)
package=directory/'paquet'

with psycopg.connect(DSN) as c:
    c.execute('SET TRANSACTION READ ONLY')
    expected={}
    private={}
    for table,key in [('T_CategorieGenerique','ID_CategorieGenerique'),('T_Generique','ID_Generique')]:
        expected[table]=dict(c.execute(sql.SQL('SELECT {},to_jsonb(t) FROM referentiel.{} t WHERE "IdEntiteFk" IS NULL ORDER BY {}').format(sql.Identifier(key),sql.Identifier(table),sql.Identifier(key))).fetchall())
        private[table]=[r[0] for r in c.execute(sql.SQL('SELECT {} FROM referentiel.{} WHERE "IdEntiteFk" IS NOT NULL').format(sql.Identifier(key),sql.Identifier(table)))]
    expected_precision=dict(c.execute('SELECT "ID_PrecisionStock",to_jsonb(p)-\'ModifieLe\' FROM logistique."T_PrecisionStock" p WHERE referentiel.fn_reference_visible(p."ID_UniteFk",NULL)').fetchall())

env={**os.environ,'DATABASE_URL':DSN,'SAUVERNDEKO_DB_READ_ONLY':'0','PYTHONIOENCODING':'utf-8'}
python=str(ROOT/'backend/.venv/Scripts/python.exe')
manage=str(ROOT/'backend/manage.py')

def manage_run(arguments,environment):
    result=subprocess.run([python,manage,*arguments],env=environment,cwd=ROOT,capture_output=True,timeout=180)
    if result.returncode:
        # Les sorties sont privées sur disque ; ne pas afficher de DSN/secret.
        (directory/'diagnostic.log').write_bytes(result.stdout+b'\n'+result.stderr)
        raise RuntimeError('Commande d’installation refusée ; diagnostic privé disponible.')
    return result

manage_run(['preparer_installation','--destination',str(package),'--pg-bin',str(BIN)],env)
manifest=json.loads((package/'manifest.json').read_text(encoding='utf8'))
assert manifest['format']==2 and manifest['installationOrder']==['structure.sql','references.sql','correspondances.sql']
assert manifest['dictionaryScope']['mode']=='common-only'
assert manifest['dictionaryScope']['privateEnterpriseRowsCopied'] is False
assert manifest['sanitizedDataTables']['referentiel.T_ChampReferentiel']['currentMappingsCopied'] is False
for name,digest in manifest['files'].items():
    assert hashlib.sha256((package/name).read_bytes()).hexdigest()==digest
assert (package/'correspondances.sql').read_bytes()==(ROOT/'SQL/1. Schema systeme/Systeme_FK_Correspondance_Seed_Defaults.sql').read_bytes()

name='sauverndeko_test_referentiels30_install_'+uuid.uuid4().hex[:8]
admin_dsn=urlunsplit(target._replace(path='/postgres'))
with psycopg.connect(admin_dsn,autocommit=True) as c:
    c.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(name)))
destination=urlunsplit(target._replace(path='/'+name))
install_env={**env,'DATABASE_URL':destination}
args=['installer_instance','--source',str(package),'--pg-bin',str(BIN)]
manage_run(args,install_env)
manage_run([*args,'--apply'],install_env)

with psycopg.connect(destination) as c:
    c.execute('SET TRANSACTION READ ONLY')
    for table,key in [('T_CategorieGenerique','ID_CategorieGenerique'),('T_Generique','ID_Generique')]:
        actual=dict(c.execute(sql.SQL('SELECT {},to_jsonb(t) FROM referentiel.{} t ORDER BY {}').format(sql.Identifier(key),sql.Identifier(table),sql.Identifier(key))).fetchall())
        assert actual==expected[table],table+': les références communes doivent être conservées exactement'
        assert not (set(private[table]) & actual.keys()),table+': référence privée copiée'
    assert dict(c.execute('SELECT "ID_PrecisionStock",to_jsonb(p)-\'ModifieLe\' FROM logistique."T_PrecisionStock" p').fetchall())==expected_precision
    empty={table:c.execute(sql.SQL('SELECT count(*) FROM {}.{}').format(*map(sql.Identifier,table.split('.')))).fetchone()[0] for table in ['systeme.T_Entite','systeme.T_Utilisateurs','systeme.T_Licence','logistique.T_Immobilisation','logistique.T_Article','logistique.T_Commande','logistique.T_Mouvement','logistique.T_DocumentIdentite','referentiel.T_PreferenceTableau']}
    assert not any(empty.values()),empty
    assert c.execute('SELECT count(*) FROM referentiel."T_ChampReferentiel"').fetchone()[0]==60
    assert c.execute('SELECT count(*) FROM referentiel."T_ChampReferentiel" WHERE "SupportsEntityScope"').fetchone()[0]==38
    # Le catalogue démarre à 1 ; le seed fermé incrémente ensuite les champs
    # effectivement initialisés par ses correspondances. Ce sont des révisions
    # locales, sans reprendre les compteurs ou auteurs de l'instance source.
    assert c.execute('SELECT count(*) FROM referentiel."T_ChampReferentiel" WHERE "Revision" NOT IN(1,2) OR "ModifieParUserFk" IS NOT NULL').fetchone()[0]==0
    assert c.execute('SELECT count(*) FROM systeme."T_Fk_Correspondance" WHERE "IdChampReferentielFk" IS NOT NULL OR "SettingScope"<>%s',['global']).fetchone()[0]==0
    assert c.execute("SELECT count(*) FROM pg_trigger WHERE tgrelid IN ('referentiel.\"T_CategorieGenerique\"'::regclass,'referentiel.\"T_Generique\"'::regclass) AND tgname IN ('ab_categorie_portee_doublon','ab_generique_portee_doublon') AND tgenabled='O'").fetchone()[0]==2
    assert c.execute('SELECT count(*) FROM referentiel."V_InterfaceTableau" WHERE "CleInterface"=%s',['referentiels.tableaux']).fetchone()[0]==1
    native=c.execute('SELECT count(*) FROM public.django_migrations').fetchone()[0]
    assert native>0

report={'passed':True,'sourceDatabase':target.path[1:],'restoredDatabase':name,'realInstallerPlanAndApply':True,'fileHashesVerified':len(manifest['files']),'nativeMigrationsApplied':native,'clientRows':empty,'commonDictionaryExactlyPreserved':True,'privateCategoriesExcluded':len(private['T_CategorieGenerique']),'privateValuesExcluded':len(private['T_Generique']),'commonPrecisionExactlyPreserved':True,'initialIdentityGuardsReenabled':True,'customerMappingsCopied':False,'personalPreferencesCopied':False,'sanitizedCatalogueRows':60,'entityScopeFields':38}
(directory/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'passed':True,'sourceDatabase':target.path[1:],'restoredDatabase':name,'nativeMigrationsApplied':native}))
