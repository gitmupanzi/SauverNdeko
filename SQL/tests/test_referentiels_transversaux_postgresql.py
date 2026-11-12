"""Référentiels30 : données fictives exclusivement, socle09 avant application.

La source applicative n'est jamais une cible de cette recette. Les écritures de
lots restent atomiques via les mêmes gardes que la saisie individuelle.
"""
import hashlib
import json
import os
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg import sql
from psycopg.rows import dict_row

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
target = urlsplit(DSN)
if target.hostname not in {'localhost', '127.0.0.1'} or not target.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Base privée locale sauverndeko_test_* explicitement requise.')
checks = []
tag = uuid.uuid4().hex[:10]


def check(ok, label):
    assert ok, label
    checks.append(label)


with psycopg.connect(DSN, autocommit=True, row_factory=dict_row) as c:
    def q(statement, params=None):
        return c.execute(statement, params)

    def one(statement, params=None):
        return q(statement, params).fetchone()

    def reject(callback, label):
        try:
            with c.transaction():
                callback()
        except psycopg.Error as error:
            assert error.sqlstate not in {'42601', '42703', '42P01', '42883'}, (label, str(error))
            check(True, label)
        else:
            raise AssertionError(label)

    def rows(schema, table):
        return [r['data'] for r in q(sql.SQL('SELECT to_jsonb(t) data FROM {}.{} t ORDER BY to_jsonb(t)::text').format(sql.Identifier(schema), sql.Identifier(table)))]

    if one("SELECT EXISTS(SELECT FROM information_schema.columns WHERE table_schema='referentiel' AND table_name='T_Generique' AND column_name='IdEntiteFk') found")['found']:
        raise RuntimeError('Socle09 avant migration requis.')
    check(one('SELECT current_database() name')['name'] == target.path[1:], 'Connexion privée réellement vérifiée')
    entities = [one('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") VALUES(%s,%s,true) RETURNING "IdEntite" id', [f'Entreprise fictive {n} {tag}', f'{tag}.{n}@example.invalid'])['id'] for n in range(2)]
    legacy_category = one('INSERT INTO referentiel."T_CategorieGenerique"("NomCategorieGenerique") VALUES(%s) RETURNING "ID_CategorieGenerique" id', ['Famille historique fictive '+tag])['id']
    legacy_values = [one('INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique") VALUES(%s,%s,%s) RETURNING "ID_Generique" id', [legacy_category, 'Doublon hérité '+tag, 'LEGACY-'+tag])['id'] for _ in range(2)]
    schemas = ['analytics', 'communication', 'geolocalisation', 'logistique', 'operations', 'professionnel', 'referentiel', 'systeme']
    tables = q("SELECT schemaname s,tablename t FROM pg_tables WHERE schemaname=ANY(%s) ORDER BY 1,2", [schemas]).fetchall()
    before = {(r['s'], r['t']): rows(r['s'], r['t']) for r in tables}
    fks = q("SELECT conrelid::regclass::text t,conname,pg_get_constraintdef(oid,true) def FROM pg_constraint WHERE contype='f' AND confrelid='referentiel.\"T_Generique\"'::regclass ORDER BY 1,2").fetchall()
    path = ROOT/'backend/database/migrations/20261030_01_referentiels_transversaux.sql'
    q(path.read_text(encoding='utf8'))
    for (schema, table), old in before.items():
        current = rows(schema, table)
        if table in {'T_CategorieGenerique', 'T_Generique'}:
            check(all(row['IdEntiteFk'] is None for row in current), table+' : tous les anciens propriétaires restent NULL commun')
            current = [{k: v for k, v in row.items() if k != 'IdEntiteFk'} for row in current]
        elif table == 'T_InterfaceTableau':
            check(len(current) == len(old)+1, 'Un seul catalogue de tableau ajouté')
            actual = {row['CleInterface']: row for row in current}
            for previous in old:
                updated = actual[previous['CleInterface']]
                if previous['CleInterface'] in {'referentiels.categories', 'referentiels.valeurs'}:
                    check(updated['Colonnes'][:len(previous['Colonnes'])] == previous['Colonnes'], 'Les anciennes définitions de colonnes et leur ordre sont conservés : '+previous['CleInterface'])
                    check([col['id'] for col in updated['Colonnes'][len(previous['Colonnes']):]] == ['IdEntiteFk', 'NomEntite'], 'Deux colonnes de portée facultatives sont ajoutées : '+previous['CleInterface'])
                    check(all(col['defaultVisible'] is False and col['defaultExport'] is False for col in updated['Colonnes'][len(previous['Colonnes']):]), 'Aucune préférence personnelle de portée n’est imposée : '+previous['CleInterface'])
                    check(updated['Version'] == previous['Version']+1, 'Le catalogue évolué est versionné : '+previous['CleInterface'])
                else:
                    check(updated == previous, 'Ancien catalogue de tableau inchangé : '+previous['CleInterface'])
            continue
        elif table == 'T_ChampReferentiel':
            keep = lambda row: {k: v for k, v in row.items() if k not in {'SupportsEntityScope', 'Revision', 'ModifieLe'}}
            check(len(current) == len(old) and sum(a != b for a, b in zip(current, old)) == 1, 'Une seule politique de précision évolue dans le catalogue')
            check(sorted(map(keep, current), key=lambda x: x['ID_ChampReferentiel']) == sorted(map(keep, old), key=lambda x: x['ID_ChampReferentiel']), 'Aucun défaut ou identifiant de champ modifié')
            continue
        elif table == 'T_Audit_Log':
            check(len(current) == len(old)+1, 'Une preuve factuelle d’évolution de précision est ajoutée à l’audit')
            current = [row for row in current if row['Operation'] != 'REFERENCE_SCOPE_EVOLUTION']
        check(current == old, 'Anciennes lignes préservées : '+schema+'.'+table)
    check(q("SELECT conrelid::regclass::text t,conname,pg_get_constraintdef(oid,true) def FROM pg_constraint WHERE contype='f' AND confrelid='referentiel.\"T_Generique\"'::regclass ORDER BY 1,2").fetchall() == fks, 'Toutes les FK métier vers T_Generique sont conservées à l’identique')

    def category(name, owner=None):
        return one('INSERT INTO referentiel."T_CategorieGenerique"("NomCategorieGenerique","IdEntiteFk") VALUES(%s,%s) RETURNING "ID_CategorieGenerique" id', [name, owner])['id']

    def value(cat, name, code=None, owner=None):
        return one('INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","IdEntiteFk") VALUES(%s,%s,%s,%s) RETURNING "ID_Generique" id', [cat, name, code, owner])['id']

    common = category('Famille commune '+tag)
    own = [category('Famille privée '+tag, ent) for ent in entities]
    reject(lambda: category('  FAMILLE   COMMUNE '+tag.upper(), entities[0]), 'Doublon de catégorie commun/entreprise refusé après normalisation')
    reject(lambda: category('Famille privée '+tag), 'Nouvelle catégorie commune ne masque pas une catégorie privée existante')
    reject(lambda: q('UPDATE referentiel."T_CategorieGenerique" SET "IdEntiteFk"=%s WHERE "ID_CategorieGenerique"=%s', [entities[0], common]), 'Une ancienne catégorie commune ne peut être réattribuée')
    shared_value = value(common, 'Valeur commune '+tag, 'COMMON-'+tag)
    private = [value(common, 'Valeur privée '+tag, 'PRIVATE-'+tag, ent) for ent in entities]
    reject(lambda: value(common, '  VALEUR   COMMUNE '+tag.upper(), owner=entities[0]), 'Valeur privée ne duplique pas un libellé commun')
    reject(lambda: value(common, 'Autre nom '+tag, ' common-'+tag.upper()+' ', entities[0]), 'Valeur privée ne duplique pas un code commun')
    reject(lambda: value(common, 'Valeur privée '+tag), 'Nouvelle valeur commune ne masque pas un libellé privé')
    reject(lambda: value(common, 'Autre '+tag, 'PRIVATE-'+tag), 'Nouveau code commun ne masque pas un code privé')
    reject(lambda: value(own[0], 'Valeur sans propriétaire '+tag), 'Une catégorie privée ne reçoit pas une valeur commune')
    reject(lambda: value(own[0], 'Valeur étrangère '+tag, owner=entities[1]), 'Une catégorie privée ne reçoit pas une valeur d’une autre entreprise')
    private_family_value = value(own[0], 'Valeur parent privé '+tag, owner=entities[0])
    protected = one('SELECT "ID_CategorieDefautFk" id FROM referentiel."T_ChampReferentiel" WHERE NOT "CanConfigure" AND "ID_CategorieDefautFk" IS NOT NULL LIMIT 1')['id']
    reject(lambda: value(protected, 'Rôle privé fictif '+tag, owner=entities[0]), 'Les familles de sécurité restent communes et ne produisent aucun rôle privé inutilisable')
    reject(lambda: q('UPDATE referentiel."T_Generique" SET "IdEntiteFk"=%s WHERE "ID_Generique"=%s', [entities[1], private[0]]), 'Le propriétaire d’une valeur est immuable')
    q('UPDATE referentiel."T_Generique" SET "ObsGenerique"=%s WHERE "ID_Generique"=%s', ['Ancienne donnée conservée', legacy_values[0]])
    check(one('SELECT count(*) n FROM referentiel."T_Generique" WHERE "ID_Generique"=ANY(%s)', [legacy_values])['n'] == 2, 'Les doublons hérités restent distincts et modifiables descriptivement')
    check(one('SELECT referentiel.fn_normaliser_libelle(%s) result', [' \tA\u00a0 B\n '])['result'] == 'a b', 'La normalisation traite tabulation, insécable et espaces multiples')
    check(one('SELECT referentiel.fn_normaliser_libelle(%s)<>referentiel.fn_normaliser_libelle(%s) ok', ['État', 'Etat'])['ok'], 'Les accents ne sont pas fusionnés arbitrairement')
    for entity, allowed in [(None, [shared_value]), (entities[0], [shared_value, private[0], private_family_value]), (entities[1], [shared_value, private[1]])]:
        actual = [v for v in [shared_value, *private, private_family_value] if one('SELECT referentiel.fn_reference_visible(%s,%s) ok', [v, entity])['ok']]
        check(actual == allowed, 'Visibilité commune/entreprise exacte pour '+str(entity))
    check(not one('SELECT referentiel.fn_categorie_visible(%s,%s) ok', [own[0], entities[1]])['ok'], 'La catégorie privée A n’est pas visible depuis B')

    def configure(table, column, cat, entity=None):
        f = one('SELECT * FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=%s AND "TableName"=%s AND "ColumnName"=%s', ['logistique', table, column])
        return q('INSERT INTO systeme."T_Fk_Correspondance"("IdChampReferentielFk","ModuleName","SchemaName","SourceKey","FieldName","FieldLabel","MappingType","ReferenceSchemaName","ReferenceObjectName","ReferenceFieldName","TargetCategoryIdFk","MappingValue","IsDefaultMapping","SettingScope","ScopeValue","DisplayOrder") VALUES(%s,%s,%s,%s,%s,%s,\'generic_category\',\'referentiel\',\'T_Generique\',\'ID_Generique\',%s,%s,false,%s,%s,0)', [f['ID_ChampReferentiel'], f['ModuleName'], f['SchemaName'], 'champ.'+str(f['ID_ChampReferentiel']), f['ColumnName'], f['ChampLabel'], cat, str(cat), 'entity' if entity else 'global', str(entity) if entity else None])

    reject(lambda: configure('T_Article', 'ID_CategorieArticleFk', own[0]), 'Catégorie privée interdite dans un référencement global')
    reject(lambda: configure('T_Article', 'ID_CategorieArticleFk', own[0], entities[1]), 'Catégorie privée A interdite dans un référencement de B')
    configure('T_Article', 'ID_CategorieArticleFk', common)
    check(one("SELECT referentiel.fn_valider_reference_champ('logistique','T_Article','ID_CategorieArticleFk',%s,%s) ok", [private[0], entities[0]])['ok'], 'Nouvelle valeur privée A acceptée dans son champ métier de A')
    check(not one("SELECT referentiel.fn_valider_reference_champ('logistique','T_Article','ID_CategorieArticleFk',%s,%s) ok", [private[0], entities[1]])['ok'], 'Nouvelle valeur privée A refusée dans un document de B')
    check(not one("SELECT referentiel.fn_valider_reference_champ('logistique','T_Article','ID_CategorieArticleFk',%s,NULL) ok", [private[0]])['ok'], 'Une sélection sans entreprise ne prend aucune valeur privée')
    configure('T_Article', 'ID_CategorieArticleFk', own[0], entities[0])
    check(one("SELECT referentiel.fn_valider_reference_champ('logistique','T_Article','ID_CategorieArticleFk',%s,%s) ok", [private_family_value, entities[0]])['ok'], 'Référencement de famille privée effectif dans son entreprise')
    # Politique de l’unité privée : propriétaire déduit du seul identifiant stable.
    units = one("SELECT referentiel.fn_categories_champ('logistique','T_PrecisionStock','ID_UniteFk',NULL) ids")['ids'][0]
    unit = value(units, 'Unité privée '+tag, 'u-'+tag, entities[0])
    q('INSERT INTO logistique."T_PrecisionStock"("ID_UniteFk","DecimalesStock") VALUES(%s,3)', [unit])
    check(one("SELECT referentiel.fn_entite_reference_champ('logistique','T_PrecisionStock',jsonb_build_object('ID_UniteFk',%s)) id", [unit])['id'] == entities[0], 'La précision privée suit le propriétaire immuable de l’unité')
    check(one('SELECT "DecimalesStock" d FROM logistique."V_PrecisionStock" WHERE "ID_UniteFk"=%s', [unit])['d'] == 3, 'La précision fractionnaire privée est persistée et relue')
    # Une ouverture physique n'utilise pas le premier type privé d'une autre
    # entreprise, même si son code est identique et son ID plus petit.
    entry_family = category('Types physiques fictifs '+tag)
    entry_b = value(entry_family, 'Entrée privée B '+tag, 'Entrée', entities[1])
    entry_a = value(entry_family, 'Entrée privée A '+tag, 'Entrée', entities[0])
    configure('T_Commande', 'ID_TypeCmdFk', entry_family)
    user = one('INSERT INTO systeme."T_Utilisateurs"("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","IdEntiteFk") VALUES(%s,\'Recette\',%s,\'motdepasse-inutilisable\',true,\'M\',%s) RETURNING "IdUser" id', ['Fictif '+tag, tag+'@example.invalid', entities[0]])['id']
    article_type = one("SELECT g.\"ID_Generique\" id FROM referentiel.\"T_Generique\" g WHERE g.\"ID_CategorieGeneriqueFk\"=ANY(referentiel.fn_categories_champ('logistique','T_Article','ID_TypeArticleFk',%s)) AND g.\"ValideGenerique\" ORDER BY g.\"ID_Generique\" LIMIT 1", [entities[0]])['id']
    usd = one('SELECT logistique.fn_devise_usd() id')['id']
    article = one('INSERT INTO logistique."T_Article"("NomArticle","ID_TypeArticleFk","ID_CategorieArticleFk","ID_UniteFk","ID_DeviseFk","PUArticle","PVArticle","QteArticle","ID_UserFK","IdEntiteFk") VALUES(%s,%s,%s,%s,%s,10,15,0.5,%s,%s) RETURNING "ID_Article" id', ['Article fictif privé '+tag, article_type, private_family_value, unit, usd, user, entities[0]])['id']
    document = one('SELECT "ID_Commande","ID_TypeCmdFk","IdEntiteFk" FROM logistique."T_Commande" WHERE "ID_ArticleInitialFk"=%s', [article])
    check(document['ID_TypeCmdFk'] == entry_a and document['ID_TypeCmdFk'] != entry_b, 'Le stock initial choisit le type privé de la bonne entreprise')
    check(document['IdEntiteFk'] == entities[0], 'Le BE généré conserve le propriétaire de l’article')
    check(one('SELECT count(*) n,sum("QteMvt") qty FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s', [article]) == {'n': 1, 'qty': __import__('decimal').Decimal('0.500')}, 'Une seule écriture de stock fractionnaire pour l’ouverture privée')
    # Pas de sauvegarde partielle d’un lot contenant une erreur tardive.
    count = one('SELECT count(*) n FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s', [common])['n']
    reject(lambda: (value(common, 'Première ligne temporaire '+tag), value(common, 'Valeur commune '+tag)), 'Erreur de deuxième ligne annule toute la transaction du lot')
    check(one('SELECT count(*) n FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s', [common])['n'] == count, 'Aucune première ligne partiellement sauvegardée')

    def concurrent(_):
        try:
            with psycopg.connect(DSN) as other:
                other.execute('INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique") VALUES(%s,%s)', [common, 'Concurrence '+tag])
            return 'created'
        except psycopg.errors.UniqueViolation:
            return 'duplicate'
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(concurrent, range(2)))
    check(sorted(results) == ['created', 'duplicate'], 'Deux créations concurrentes identiques produisent une seule valeur')
    check(one('SELECT count(*) n FROM referentiel."V_InterfaceTableau" WHERE "CleInterface"=%s', ['referentiels.tableaux'])['n'] == 1, 'Le nouveau catalogue se lit dans la vue réelle des interfaces')
    comments = q("SELECT a.attname,col_description(a.attrelid,a.attnum) commentaire FROM pg_attribute a WHERE a.attrelid='referentiel.\"V_InterfaceTableau\"'::regclass AND a.attnum>0 AND NOT a.attisdropped").fetchall()
    check(all(row['commentaire'] for row in comments), 'Toutes les colonnes de la vue de catalogue sont commentées')
    for table in ['T_CategorieGenerique', 'T_Generique']:
        check(one("SELECT col_description(c.oid,a.attnum) commentaire FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid WHERE n.nspname='referentiel' AND c.relname=%s AND a.attname='IdEntiteFk'", [table])['commentaire'], table+' : colonne propriétaire documentée')
output = Path(os.environ.get('SAUVERNDEKO_TEST_RESULT_DIR', str(ROOT/'.runtime/referentiels30-sql')))
output.mkdir(parents=True, exist_ok=True)
proof = {'passed': True, 'database': target.path[1:], 'checks': len(checks), 'details': checks,
         'migrationSHA256': hashlib.sha256(path.read_bytes()).hexdigest(), 'productionModified': False}
(output/'verification.json').write_text(json.dumps(proof, ensure_ascii=False, indent=2), encoding='utf8')
print(json.dumps({'passed': True, 'checks': len(checks), 'database': target.path[1:]}, ensure_ascii=False))
