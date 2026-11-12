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
    catalogue_count, entity_fields = c.execute('SELECT count(*), count(*) FILTER (WHERE "SupportsEntityScope") FROM referentiel."T_ChampReferentiel"').fetchone()
    private_mappings = set(c.execute('''
        SELECT "ModuleName", "SchemaName", "SourceKey", "FieldName", "MappingType", "MappingValue", "SettingScope", "ScopeValue"
        FROM systeme."T_Fk_Correspondance"
        WHERE "SettingScope" IS DISTINCT FROM 'global' OR "ScopeValue" IS NOT NULL
    ''').fetchall())
    support_present, processes_present = c.execute('''
        SELECT to_regclass('support."T_Support"') IS NOT NULL,
               to_regclass('support."T_ModeleProcessus"') IS NOT NULL
    ''').fetchone()

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
expected_order = ['structure.sql', 'references.sql', 'correspondances.sql']
if support_present:
    expected_order.append('support.sql')
    assert manifest['supportSeed'] == 'closed-code-defaults'
    assert (package/'support.sql').read_bytes() == (ROOT/'backend/database/seeds/support_defaults.sql').read_bytes()
assert manifest['format'] == (3 if support_present else 2)
assert manifest['installationOrder'] == expected_order
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
    if processes_present:
        for table in ('T_ModeleProcessus', 'T_VersionProcessus', 'T_ParcoursSupport', 'T_EtapeParcours', 'T_EvenementParcours', 'T_AlerteParcours'):
            empty[f'support.{table}'] = c.execute(sql.SQL('SELECT count(*) FROM support.{}').format(sql.Identifier(table))).fetchone()[0]
    assert not any(empty.values()),empty
    assert c.execute('SELECT count(*), count(*) FILTER (WHERE "SupportsEntityScope") FROM referentiel."T_ChampReferentiel"').fetchone() == (catalogue_count, entity_fields)
    if support_present:
        circuit = c.execute('''
            SELECT "SettingValueJson" FROM systeme."T_Admin_UI_Setting"
            WHERE "SettingKey" = 'support.workflow' AND "SettingScope" = 'global' AND "ScopeValue" IS NULL
        ''').fetchone()[0]
        assert circuit['version'] == 1 and len(circuit['transitions']) == 8
        assert set(circuit['states']) == {'new', 'active', 'pending', 'resolved', 'closed'}
        assert set(circuit['verification']) == {'accepted', 'rejected'}
        assert len(set(circuit['states'].values()) | set(circuit['verification'].values())) == 7
    # Le catalogue démarre à 1 ; le seed fermé incrémente ensuite les champs
    # effectivement initialisés par ses correspondances. Ce sont des révisions
    # locales, sans reprendre les compteurs ou auteurs de l'instance source.
    assert c.execute('SELECT count(*) FROM referentiel."T_ChampReferentiel" WHERE "Revision" NOT IN(1,2) OR "ModifieParUserFk" IS NOT NULL').fetchone()[0]==0
    installed_mappings = set(c.execute('''
        SELECT "ModuleName", "SchemaName", "SourceKey", "FieldName", "MappingType", "MappingValue", "SettingScope", "ScopeValue"
        FROM systeme."T_Fk_Correspondance"
    ''').fetchall())
    assert installed_mappings
    assert all(scope == 'global' and scope_value is None for *_, scope, scope_value in installed_mappings)
    assert private_mappings.isdisjoint(installed_mappings), 'Une correspondance privée a été copiée'
    assert c.execute('''
        SELECT count(*) FROM systeme."T_Fk_Correspondance" m
        LEFT JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique" = m."TargetCategoryIdFk"
        LEFT JOIN referentiel."T_ChampReferentiel" f ON f."ID_ChampReferentiel" = m."IdChampReferentielFk"
        WHERE m."UpdatedByUserFk" IS NOT NULL OR c."IdEntiteFk" IS NOT NULL
           OR (m."IdChampReferentielFk" IS NOT NULL AND (
               f."ID_ChampReferentiel" IS NULL
               OR m."TargetCategoryIdFk" IS DISTINCT FROM f."ID_CategorieDefautFk"
           ))
    ''').fetchone()[0] == 0, 'Les correspondances livrées doivent reprendre les défauts du catalogue commun'
    assert c.execute("SELECT count(*) FROM pg_trigger WHERE tgrelid IN ('referentiel.\"T_CategorieGenerique\"'::regclass,'referentiel.\"T_Generique\"'::regclass) AND tgname IN ('ab_categorie_portee_doublon','ab_generique_portee_doublon') AND tgenabled='O'").fetchone()[0]==2
    assert c.execute('SELECT count(*) FROM referentiel."V_InterfaceTableau" WHERE "CleInterface"=%s',['referentiels.tableaux']).fetchone()[0]==1
    native=c.execute('SELECT count(*) FROM public.django_migrations').fetchone()[0]
    assert native>0

report={'passed':True,'sourceDatabase':target.path[1:],'restoredDatabase':name,'realInstallerPlanAndApply':True,'fileHashesVerified':len(manifest['files']),'nativeMigrationsApplied':native,'clientRows':empty,'commonDictionaryExactlyPreserved':True,'privateCategoriesExcluded':len(private['T_CategorieGenerique']),'privateValuesExcluded':len(private['T_Generique']),'commonPrecisionExactlyPreserved':True,'initialIdentityGuardsReenabled':True,'customerMappingsCopied':False,'privateMappingsExcluded':len(private_mappings),'personalPreferencesCopied':False,'sanitizedCatalogueRows':catalogue_count,'entityScopeFields':entity_fields,'supportDefaultInstalled':support_present}
(directory/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'passed':True,'sourceDatabase':target.path[1:],'restoredDatabase':name,'nativeMigrationsApplied':native}))
