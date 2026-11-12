"""Recette SQL réelle du Support, sur PostgreSQL privé local uniquement.

Applique la migration06 si absente, puis annule toute donnée fictive créée par
les scénarios. Aucun repli de connexion vers SauverNdeko n'est permis.
"""
import hashlib
import json
import os
import uuid
from datetime import timedelta
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg import sql
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
target = urlsplit(DSN)
if target.hostname not in {'localhost', '127.0.0.1'} or not target.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Recette réservée au PostgreSQL privé local sauverndeko_test_*.')
checks = []
installation_seed = {'existingConfigurationPreserved': False}
tag = uuid.uuid4().hex


def check(value, label):
    assert value, label
    checks.append(label)


with psycopg.connect(DSN, autocommit=True, row_factory=dict_row) as c:
    def q(query, params=None):
        return c.execute(query, params)

    def one(query, params=None):
        return q(query, params).fetchone()

    def insert(schema, table, body):
        return one(sql.SQL('INSERT INTO {}.{}({}) VALUES({}) RETURNING *').format(
            sql.Identifier(schema), sql.Identifier(table),
            sql.SQL(',').join(map(sql.Identifier, body)),
            sql.SQL(',').join(sql.Placeholder() for _ in body)), list(body.values()))

    def update(table, pkname, pk, body):
        return one(sql.SQL('UPDATE support.{} SET {} WHERE {}=%s RETURNING *').format(
            sql.Identifier(table),
            sql.SQL(',').join(sql.SQL('{}=%s').format(sql.Identifier(k)) for k in body),
            sql.Identifier(pkname)), [*body.values(), pk])

    def rejected(callback, label):
        try:
            with c.transaction():
                callback()
        except psycopg.Error as error:
            assert error.sqlstate not in {'42601', '42703', '42883', '42P01', '42804'}, (label, str(error))
            check(True, label)
            return error
        else:
            raise AssertionError('Accepté à tort : ' + label)

    check(one('SELECT current_database() db')['db'] == target.path[1:], 'Base effectivement privée')
    if one("SELECT to_regclass('support.\"T_Support\"') t")['t'] is None:
        q((ROOT / 'backend/database/migrations/20261030_06_support.sql').read_text(encoding='utf8'))
        check(one('SELECT count(*) n FROM support."T_Support"')['n'] == 0, 'Migration sans création de dossiers fictifs')
    count_before = one('SELECT count(*) n FROM support."T_Support"')['n']
    tables = q("SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='support' AND c.relkind='r'").fetchall()
    table_names = {r['relname'] for r in tables}
    check({'T_Support', 'T_CommentaireSupport', 'T_ResolutionSupport', 'T_PieceSupport'} <= table_names, 'Tables historiques du Support conservées')
    for row in q("SELECT c.relname,a.attname,col_description(c.oid,a.attnum) comment FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid WHERE n.nspname='support' AND c.relkind IN('r','v') AND a.attnum>0 AND NOT a.attisdropped"):
        check(bool(row['comment']), 'Colonne documentée : ' + row['relname'] + '.' + row['attname'])
    for row in q("SELECT p.proname,obj_description(p.oid,'pg_proc') comment FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='support'"):
        check(bool(row['comment']), 'Fonction documentée : ' + row['proname'])
    for row in q("SELECT t.tgname,obj_description(t.oid,'pg_trigger') comment FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE NOT t.tgisinternal AND (n.nspname='support' OR t.tgname LIKE 'support_%')"):
        check(bool(row['comment']), 'Trigger documenté : ' + row['tgname'])
    with c.transaction(force_rollback=True):
        def entity(label):
            return insert('systeme', 'T_Entite', {'NomEntite': label + tag, 'EmailEntite': uuid.uuid4().hex + '@example.invalid'})['IdEntite']

        ea, eb = entity('Support fictif A '), entity('Support fictif B ')

        def user(entity_id, label='Compte', **extra):
            return insert('systeme', 'T_Utilisateurs', {
                'NomUser': label, 'PrenomUser': 'Fictif', 'EmailUser': uuid.uuid4().hex + '@example.invalid',
                'MotdepasseUser': 'inutilisable', 'SexeUser': 'M', 'IdEntiteFk': entity_id, **extra})['IdUser']

        actor = user(ea, 'Gestionnaire', Is_staff=True)
        verifier = user(ea, 'Vérificateur', Is_staff=True)
        other = user(eb, 'Autre entreprise', Is_staff=True)
        platform = user(None, 'Plateforme', Is_Admin=True)
        inactive = user(ea, 'Inactif', ValideUser=False)

        def context(user_id=actor, operation='update', reason=None, request=None):
            q("SELECT set_config('systeme.actor_user_id',%s,true)", [str(user_id) if user_id else ''])
            body = {'requestId': request or str(uuid.uuid4()), 'payloadHash': 'a' * 64, 'operation': operation}
            if reason is not None:
                body['motif'] = reason
            q("SELECT set_config('support.mutation',%s,true)", [json.dumps(body)])
            return body

        def ref(field, table='T_Support', company=ea):
            return one('SELECT g."ID_Generique" id FROM referentiel."T_Generique" g WHERE g."ValideGenerique" AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ(%s,%s,%s,%s)) AND referentiel.fn_reference_visible(g."ID_Generique",%s) ORDER BY g."ID_Generique" LIMIT 1', ['support', table, field, company, company])['id']

        base = {field: ref(field) for field in ['ID_TypeSupportFk', 'ID_PrioriteFk', 'ID_CanalOrigineFk']}

        def create(**extra):
            return insert('support', 'T_Support', {'IdEntiteFk': ea, 'Objet': 'Incident fictif', 'Description': 'Description de recette sans données clients.', **base, **extra})

        def change(record, **values):
            return update('T_Support', 'ID_Support', record['ID_Support'], values)

        def transition(record, state, reason=None, user_id=actor):
            context(user_id, state, reason)
            return change(record, ID_StatutFk=record['CircuitSnapshot']['states'][state])

        def solution(record, user_id=actor):
            context(user_id, 'resolve')
            return insert('support', 'T_ResolutionSupport', {'ID_SupportFk': record['ID_Support'], 'CauseIdentifiee': 'Cause documentée.', 'SolutionAppliquee': 'Solution exécutée et preuve conservée.'})

        context(operation='create')
        ticket = create()
        check(ticket['NumeroSupport'] == 'SUP-' + str(ticket['ID_Support']), 'Numéro court attribué une fois par PostgreSQL')
        check(ticket['VersionEnregistrement'] == 1 and ticket['ID_CreateurFk'] == actor, 'Auteur réel et version initiale attribués en SQL')
        check(ticket['ID_StatutFk'] == ticket['CircuitSnapshot']['states']['new'], 'Statut initial issu du circuit système')
        check(ticket['DateResolution'] is None and ticket['DateCloture'] is None, 'Résolution et clôture inconnues à la création')
        check(ticket['ID_DemandeurFk'] is None, 'Demandeur facultatif sans utilisateur factice')
        initial_snapshot = ticket['CircuitSnapshot']
        rejected(lambda: transition(ticket, 'active'), 'Prise en charge sans responsable refusée')
        context(); rejected(lambda: change(ticket, ID_ResponsableFk=other), 'Affectataire d’une autre entreprise refusé')
        context(); rejected(lambda: change(ticket, ID_ResponsableFk=inactive), 'Nouvel affectataire inactif refusé')
        context(); ticket = change(ticket, ID_ResponsableFk=actor)
        check(ticket['VersionEnregistrement'] == 2, 'Révision atomique augmente après affectation')
        ticket = transition(ticket, 'active')
        check(one('SELECT "StatutCode","Ouvert","EnRetard" FROM support."V_Support" WHERE "ID_Support"=%s', [ticket['ID_Support']])['StatutCode'] == 'active', 'Vue commune suit le circuit du dossier')
        rejected(lambda: transition(ticket, 'pending'), 'Motif obligatoire pour mise en attente')
        ticket = transition(ticket, 'pending', 'Attente du fournisseur')
        check(ticket['ID_StatutFk'] == initial_snapshot['states']['pending'], 'Mise en attente conserve la référence initiale')
        ticket = transition(ticket, 'active')
        rejected(lambda: transition(ticket, 'closed'), 'Clôture directe depuis En cours refusée')
        rejected(lambda: transition(ticket, 'resolved'), 'Résolution sans nouvelle solution documentée refusée')
        attempt = solution(ticket)
        # La résolution et la mise à jour de son parent sont deux tables auditées dans une transaction.
        ticket = change(ticket, ID_StatutFk=initial_snapshot['states']['resolved'])
        check(ticket['DateResolution'] is not None and ticket['DateCloture'] is None, 'Résolution datée distincte de la clôture')
        rejected(lambda: transition(ticket, 'closed'), 'Clôture sans vérification refusée')
        context(actor, 'verify')
        rejected(lambda: update('T_ResolutionSupport', 'ID_ResolutionSupport', attempt['ID_ResolutionSupport'], {'ID_ResultatVerificationFk': initial_snapshot['verification']['accepted'], 'CommentaireVerification': 'Contrôle'}), 'Auto-vérification de la solution refusée')
        context(verifier, 'verify')
        rejected(lambda: update('T_ResolutionSupport', 'ID_ResolutionSupport', attempt['ID_ResolutionSupport'], {'ID_ResultatVerificationFk': initial_snapshot['verification']['accepted']}), 'Commentaire de vérification obligatoire')
        verified = update('T_ResolutionSupport', 'ID_ResolutionSupport', attempt['ID_ResolutionSupport'], {'ID_ResultatVerificationFk': initial_snapshot['verification']['accepted'], 'CommentaireVerification': 'Solution contrôlée conforme.'})
        check(verified['ID_VerifieParFk'] == verifier and verified['DateVerification'] is not None, 'Vérificateur distinct et date imposés')
        ticket = transition(ticket, 'closed', user_id=verifier)
        check(ticket['DateCloture'] is not None, 'Clôture après résolution vérifiée conforme')
        context(); rejected(lambda: change(ticket, Objet='Altération'), 'Dossier clôturé protégé des modifications descriptives')
        rejected(lambda: transition(ticket, 'active'), 'Motif obligatoire pour réouverture')
        ticket = transition(ticket, 'active', 'Le problème a réapparu')
        check(ticket['DateResolution'] is None and ticket['DateCloture'] is None, 'Réouverture retire les dates courantes sans effacer les audits')
        rejected(lambda: transition(ticket, 'resolved'), 'Ancienne solution vérifiée ne peut résoudre une reprise')
        second = solution(ticket)
        ticket = change(ticket, ID_StatutFk=initial_snapshot['states']['resolved'])
        context(verifier, 'verify')
        update('T_ResolutionSupport', 'ID_ResolutionSupport', second['ID_ResolutionSupport'], {'ID_ResultatVerificationFk': initial_snapshot['verification']['rejected'], 'CommentaireVerification': 'Le test échoue encore.'})
        rejected(lambda: transition(ticket, 'closed', user_id=verifier), 'Vérification négative ne permet pas clôture')
        ticket = transition(ticket, 'active', 'Reprendre la solution')
        check(one('SELECT count(*) n FROM support."V_ResolutionSupport" WHERE "ID_SupportFk"=%s', [ticket['ID_Support']])['n'] == 2, 'Tentatives antérieures positives et négatives conservées')
        context(); rejected(lambda: update('T_ResolutionSupport', 'ID_ResolutionSupport', attempt['ID_ResolutionSupport'], {'SolutionAppliquee': 'Réécrite'}), 'Réécriture de la solution historique refusée')
        for body in [{'IdEntiteFk': eb}, {'NumeroSupport': 'SUP-FAUX'}, {'ID_CreateurFk': platform}, {'CircuitSnapshot': Jsonb({})}, {'VersionEnregistrement': 55}]:
            context(); rejected(lambda body=body: change(ticket, **body), 'Identité ou version conservée : ' + next(iter(body)))
        context(other); rejected(lambda: change(ticket, Objet='Hors périmètre'), 'Auteur interentreprise refusé même avec PK connue')
        context(None); rejected(lambda: create(), 'Auteur absent refusé')
        context(inactive); rejected(lambda: create(), 'Auteur inactif refusé')
        context(actor); rejected(lambda: create(IdEntiteFk=eb), 'Création locale interentreprise refusée')
        context(platform); global_ticket = create(IdEntiteFk=eb, ID_ResponsableFk=platform)
        check(global_ticket['IdEntiteFk'] == eb, 'Compte global crée dans une entreprise explicite sans mélanger les données')
        context(actor)
        client_type = one('SELECT g."ID_Generique" id FROM referentiel."T_Generique" g WHERE g."ValideGenerique" AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ(%s,%s,%s,%s)) ORDER BY g."ID_Generique" LIMIT 1', ['logistique', 'T_Client', 'ID_TypeClientFk', ea])['id']
        def contact(company):
            return insert('logistique', 'T_Client', {'IdEntiteFk': company, 'ID_TypeClientFk': client_type, 'Nom': 'Demandeur externe fictif ' + tag, 'CreeParUserFk': actor, 'ModifieParUserFk': actor})
        requester = contact(ea)
        context(); ticket = change(ticket, ID_DemandeurFk=requester['ID_Client'])
        check(one('SELECT "Demandeur" FROM support."V_Support" WHERE "ID_Support"=%s', [ticket['ID_Support']])['Demandeur'].startswith('Demandeur externe'), 'Tiers existant sans compte utilisable comme demandeur')
        rejected(lambda: q('UPDATE logistique."T_Client" SET "IdEntiteFk"=%s WHERE "ID_Client"=%s', [eb, requester['ID_Client']]), 'Déplacement du demandeur lié vers autre entreprise refusé')
        context(operation='comment')
        comment = insert('support', 'T_CommentaireSupport', {'ID_SupportFk': ticket['ID_Support'], 'Contenu': 'Échange public', 'Visibilite': 'public'})
        check(comment['ID_AuteurFk'] == actor, 'Auteur du commentaire imposé par SQL')
        context(operation='comment'); internal = insert('support', 'T_CommentaireSupport', {'ID_SupportFk': ticket['ID_Support'], 'Contenu': 'Note interne', 'Visibilite': 'interne'})
        check(one('SELECT count(*) n FROM support."V_CommentaireSupport" WHERE "ID_SupportFk"=%s', [ticket['ID_Support']])['n'] == 2, 'Échanges publics et internes conservés séparément')
        rejected(lambda: update('T_CommentaireSupport', 'ID_CommentaireSupport', comment['ID_CommentaireSupport'], {'Contenu': 'Réécriture'}), 'Commentaire historique immuable')
        content = b'%PDF-1.7\nSupport fictif\n%%EOF'
        context(operation='document')
        piece = insert('logistique', 'T_PieceJustificative', {'TypeObjet': 'support', 'ID_Objet': ticket['ID_Support'], 'IdEntiteFk': ea, 'ID_UserFk': actor, 'NomFichier': 'preuve.pdf', 'MimeType': 'application/pdf', 'TailleOctets': len(content), 'Sha256': hashlib.sha256(content).hexdigest(), 'Contenu': content})
        rejected(lambda: insert('support', 'T_PieceSupport', {'ID_PieceFk': piece['ID_Piece'], 'ID_SupportFk': global_ticket['ID_Support']}), 'Preuve du mauvais dossier refusée')
        rejected(lambda: insert('support', 'T_PieceSupport', {'ID_PieceFk': piece['ID_Piece'], 'ID_SupportFk': ticket['ID_Support'], 'ID_CommentaireSupportFk': internal['ID_CommentaireSupport'], 'Visibilite': 'public'}), 'Preuve d’un commentaire interne ne devient pas publique')
        insert('support', 'T_PieceSupport', {'ID_PieceFk': piece['ID_Piece'], 'ID_SupportFk': ticket['ID_Support'], 'ID_CommentaireSupportFk': comment['ID_CommentaireSupport'], 'Visibilite': 'public'})
        q('SET CONSTRAINTS logistique.support_piece_liaison IMMEDIATE')
        check(one('SELECT "NomFichier" FROM support."V_PieceSupport" WHERE "ID_PieceFk"=%s', [piece['ID_Piece']])['NomFichier'] == 'preuve.pdf', 'Vue documentaire sans duplication du binaire')
        check('Contenu' not in one('SELECT to_jsonb(v) image FROM support."V_PieceSupport" v WHERE "ID_PieceFk"=%s', [piece['ID_Piece']])['image'], 'Octets privés absents de la vue')
        context(operation='document')
        rejected(lambda: insert('logistique', 'T_PieceJustificative', {'TypeObjet': 'support', 'ID_Objet': ticket['ID_Support'], 'IdEntiteFk': eb, 'ID_UserFk': actor, 'NomFichier': 'preuve.pdf', 'MimeType': 'application/pdf', 'TailleOctets': len(content), 'Sha256': hashlib.sha256(content).hexdigest(), 'Contenu': content}), 'Stockage commun refuse propriétaire incorrect')
        proof_id = str(uuid.uuid4()); context(operation='create', request=proof_id); replay = create()
        context(operation='create', request=proof_id); rejected(lambda: create(), 'Même preuve UUID acteur entreprise ne crée pas deux dossiers')
        check(one('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "TableName"=%s AND "NewData"->>\'requestId\'=%s', ['support.T_Support', proof_id])['n'] == 1, 'Preuve de rejeu unique transactionnelle dans audit existant')
        context(reason='Fin prématurée'); rejected(lambda: change(ticket, Archive=True), 'Archivage d’un dossier non clôturé refusé')
        third = solution(ticket)
        ticket = change(ticket, ID_StatutFk=initial_snapshot['states']['resolved'])
        context(verifier, 'verify')
        update('T_ResolutionSupport', 'ID_ResolutionSupport', third['ID_ResolutionSupport'], {'ID_ResultatVerificationFk': initial_snapshot['verification']['accepted'], 'CommentaireVerification': 'Cette solution est conforme.'})
        ticket = transition(ticket, 'closed', user_id=verifier)
        context(reason='Fin de suivi'); archived = change(ticket, Archive=True)
        check(archived['Archive'] and archived['ID_DemandeurFk'] == requester['ID_Client'], 'Archivage conserve dossier, demandeur et historique')
        context(); rejected(lambda: change(archived, Objet='Réécrit'), 'Dossier archivé protégé')
        context(reason='Reprise du suivi'); ticket = change(archived, Archive=False)
        check(not ticket['Archive'], 'Restauration motivée sans perte de dossier')
        ticket = transition(ticket, 'active', 'Vérification complémentaire')
        context(); rejected(lambda: q('DELETE FROM support."T_Support" WHERE "ID_Support"=%s', [ticket['ID_Support']]), 'Suppression physique refusée')
        for table, pkname, pk in [('T_CommentaireSupport', 'ID_CommentaireSupport', comment['ID_CommentaireSupport']), ('T_ResolutionSupport', 'ID_ResolutionSupport', attempt['ID_ResolutionSupport']), ('T_PieceSupport', 'ID_PieceFk', piece['ID_Piece'])]:
            rejected(lambda table=table, pkname=pkname, pk=pk: q(sql.SQL('DELETE FROM support.{} WHERE {}=%s').format(sql.Identifier(table), sql.Identifier(pkname)), [pk]), 'Historique enfant conservé : ' + table)
        # Configuration dans le système, copie du circuit stable sur les dossiers en cours.
        context(platform)
        setting = one('SELECT * FROM systeme."T_Admin_UI_Setting" WHERE "SettingKey"=%s AND "SettingScope"=%s', ['support.workflow', 'global'])
        cfg = setting['SettingValueJson']; cfg['version'] = 2
        q('UPDATE systeme."T_Admin_UI_Setting" SET "SettingValueJson"=%s WHERE "IdAdminUISetting"=%s', [Jsonb(cfg), setting['IdAdminUISetting']])
        check(one('SELECT "CircuitSnapshot" FROM support."T_Support" WHERE "ID_Support"=%s', [ticket['ID_Support']])['CircuitSnapshot'] == initial_snapshot, 'Modifier la configuration ne modifie pas les dossiers existants')
        context(operation='create'); newer = create()
        check(newer['CircuitSnapshot']['version'] == 2, 'Nouveaux dossiers prennent le circuit système courant')
        invalid_cfg = {**cfg, 'states': {**cfg['states'], 'active': cfg['states']['new']}}
        rejected(lambda: q('UPDATE systeme."T_Admin_UI_Setting" SET "SettingValueJson"=%s WHERE "IdAdminUISetting"=%s', [Jsonb(invalid_cfg), setting['IdAdminUISetting']]), 'Circuit avec statuts répétés refusé')
        # Référencement dynamique : famille courante modifiable sans réécrire les dossiers.
        field = one('SELECT * FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=%s AND "TableName"=%s AND "ColumnName"=%s', ['support', 'T_Support', 'ID_CategorieSupportFk'])
        family = insert('referentiel', 'T_CategorieGenerique', {'NomCategorieGenerique': 'Famille privée Support ' + tag, 'IdEntiteFk': ea})['ID_CategorieGenerique']
        value = insert('referentiel', 'T_Generique', {'ID_CategorieGeneriqueFk': family, 'NomGenerique': 'Valeur privée ' + tag, 'AbrGenerique': 'Privée', 'IdEntiteFk': ea})['ID_Generique']
        insert('systeme', 'T_Fk_Correspondance', {'ModuleName': 'support', 'SchemaName': 'support', 'SourceKey': 'champ.' + str(field['ID_ChampReferentiel']), 'FieldName': 'ID_CategorieSupportFk', 'FieldLabel': 'Catégorie', 'MappingType': 'generic_category', 'ReferenceSchemaName': 'referentiel', 'ReferenceObjectName': 'T_Generique', 'ReferenceFieldName': 'ID_Generique', 'TargetCategoryIdFk': family, 'MappingValue': str(family), 'IdChampReferentielFk': field['ID_ChampReferentiel'], 'SettingScope': 'entity', 'ScopeValue': str(ea), 'IsDefaultMapping': False})
        context(actor, 'create'); custom = create(ID_CategorieSupportFk=value)
        check(custom['ID_CategorieSupportFk'] == value, 'Famille d’entreprise dynamique appliquée aux nouvelles valeurs')
        context(platform, 'create'); rejected(lambda: create(IdEntiteFk=eb, ID_CategorieSupportFk=value), 'Valeur privée d’une entreprise refusée à une autre')
        context(actor); change(ticket, Description='Modification descriptive après configuration')
        check(one('SELECT "ID_CategorieSupportFk" FROM support."T_Support" WHERE "ID_Support"=%s', [ticket['ID_Support']])['ID_CategorieSupportFk'] is None, 'Référence historique non réécrite après configuration')
        invalid_action = {**cfg, 'transitions': [{'from': 'new', 'to': 'closed', 'action': 'start'}]}
        rejected(lambda: q('UPDATE systeme."T_Admin_UI_Setting" SET "SettingValueJson"=%s WHERE "IdAdminUISetting"=%s', [Jsonb(invalid_action), setting['IdAdminUISetting']]), 'Action de circuit ne peut contourner le parcours de clôture')
        # Un dictionnaire déployé peut contenir des abréviations modifiées. Le
        # circuit installé continue à utiliser ses identifiants. L’ancien
        # résolveur est vérifié séparément si ses codes techniques manquent.
        expected_codes = {
            'ID_StatutFk': {f'support.status.{state}' for state in ('new', 'active', 'pending', 'resolved', 'closed')},
            'ID_ResultatVerificationFk': {'support.verify.ok', 'support.verify.ko'},
        }
        dictionary = q('''
            SELECT c."ColumnName" field, g."AbrGenerique" code
            FROM referentiel."T_ChampReferentiel" c
            JOIN referentiel."T_Generique" g ON g."ID_CategorieGeneriqueFk"=c."ID_CategorieDefautFk"
            WHERE c."SchemaName"='support' AND c."ColumnName"=ANY(%s)
              AND g."IdEntiteFk" IS NULL AND g."ValideGenerique"
        ''', [list(expected_codes)]).fetchall()
        missing_codes = sorted(code for field, codes in expected_codes.items() for code in codes
                               if {'field': field, 'code': code} not in dictionary)
        if missing_codes:
            error = rejected(lambda: q('SELECT systeme.fn_support_circuit_defaut()'), 'La fonction historique refuse les codes techniques absents')
            assert error.sqlstate == '23514' and 'Dictionnaire de circuit Support incomplet' in str(error)
            installation_seed['historicalFunctionMissingCodes'] = missing_codes
        else:
            check(one('SELECT systeme.fn_support_circuit_defaut() v')['v']['version'] == 1, 'Fonction historique résout les codes techniques')
        # Le paquet psql porte sa propre transaction. Ici, sa commande DO
        # tourne seule dans une sous-transaction de recette annulée.
        support_seed = (ROOT / 'backend/database/seeds/support_defaults.sql').read_text(encoding='utf8')
        seed_body = support_seed.partition('BEGIN;\n')[2].rpartition('\nCOMMIT;')[0]
        check(bool(seed_body.strip()), 'Script de circuit initial présent dans les données d’installation')
        q(seed_body)
        configured_query = 'SELECT "SettingValueJson" v FROM systeme."T_Admin_UI_Setting" WHERE "SettingKey"=%s AND "SettingScope"=%s'
        check(one(configured_query, ['support.workflow', 'global'])['v']['version'] == 2, 'Le seed conserve une configuration existante')
        installation_seed['existingConfigurationPreserved'] = True
        audit = one('SELECT "NewData","OldData","IdEntiteFk" FROM systeme."T_Audit_Log" WHERE "TableName"=%s AND "NewData"->>\'ID_Support\'=%s ORDER BY "IdLog" DESC LIMIT 1', ['support.T_Support', str(ticket['ID_Support'])])
        check(audit['IdEntiteFk'] == ea and audit['NewData']['_actor']['IdUser'] == actor, 'Audit existant contient propriétaire et acteur réels')
        check(audit['OldData'] is not None and audit['NewData']['requestId'], 'Audit conserve avant/après et preuve de requête')

        if 'T_ModeleProcessus' in table_names:
            check({
                'T_ModeleProcessus', 'T_VersionProcessus', 'T_ParcoursSupport',
                'T_EtapeParcours', 'T_EvenementParcours', 'T_AlerteParcours',
            } <= table_names, 'Schéma des parcours complet')
            rights = {
                'IdEntiteFk': ea, 'IdUserFk': actor, 'CodeModule': 'support', 'CodeOnglet': 'processus',
                'PeutConsulter': False, 'PeutGerer': False, 'PeutExporter': False,
            }
            restriction = insert('systeme', 'T_UtilisateurModule', rights)
            check(restriction['CodeOnglet'] == 'processus' and not restriction['PeutConsulter'], 'Restriction individuelle sur les processus enregistrée')
            error = rejected(lambda: insert('systeme', 'T_UtilisateurModule', {**rights, 'CodeOnglet': 'inexistant'}), 'Onglet sans droits contrôlés refusé')
            check(error.diag.constraint_name == 'utilisateur_module_onglet_check', 'Catalogue des permissions conservé')
            check(one('SELECT "ID_SupportFk" FROM support."V_ParcoursSupport" WHERE "ID_SupportFk"=%s', [ticket['ID_Support']]) is None, 'Dossier historique sans parcours automatique')
            check(one('SELECT referentiel.fn_categories_champ(%s,%s,%s,%s) ids', ['support', 'T_EtapeParcours', 'ID_MotifBlocageFk', ea])['ids'], 'Motif rattaché au catalogue de références')
            model_values = {'IdEntiteFk': ea, 'Nom': 'Parcours ' + tag, 'ID_TypeSupportFk': base['ID_TypeSupportFk'], 'CreePar': actor}
            rejected(lambda: insert('support', 'T_ModeleProcessus', {**model_values, 'CreePar': other}), 'Auteur interentreprise refusé pour un modèle')
            model = insert('support', 'T_ModeleProcessus', model_values)
            definition = {'stages': [{'name': 'Instruction'}, {'name': 'Validation'}]}
            version_values = {'ID_ModeleFk': model['ID_Modele'], 'Numero': 1, 'Definition': Jsonb(definition), 'CreePar': actor}
            version = insert('support', 'T_VersionProcessus', version_values)
            rejected(lambda: update('T_VersionProcessus', 'ID_Version', version['ID_Version'], {'Definition': Jsonb({'stages': [{'name': 'Réécriture'}]})}), 'Version publiée immuable')
            context(actor, 'create')
            tracked = create()
            current_time = one('SELECT statement_timestamp() t')['t']
            started = current_time - timedelta(hours=2)
            due = current_time - timedelta(hours=1)
            path_values = {
                'ID_SupportFk': tracked['ID_Support'], 'IdEntiteFk': ea,
                'ID_VersionFk': version['ID_Version'], 'DemarreLe': started, 'EcheanceGlobale': due,
            }
            rejected(lambda: insert('support', 'T_ParcoursSupport', {**path_values, 'ID_SupportFk': global_ticket['ID_Support'], 'IdEntiteFk': eb}), 'Parcours refuse une autre entreprise')
            insert('support', 'T_ParcoursSupport', path_values)
            newer_version = insert('support', 'T_VersionProcessus', {**version_values, 'Numero': 2, 'Definition': Jsonb({'stages': [{'name': 'Autre instruction'}]})})
            rejected(lambda: insert('support', 'T_ParcoursSupport', {**path_values, 'ID_SupportFk': newer['ID_Support']}), 'Démarrage avec une ancienne version refusé')
            rejected(lambda: update('T_ParcoursSupport', 'ID_SupportFk', tracked['ID_Support'], {'ID_VersionFk': newer_version['ID_Version']}), 'Version d’un dossier déjà démarré conservée')
            stage_values = {
                'ID_SupportFk': tracked['ID_Support'], 'Position': 1, 'EntreeLe': started, 'Echeance': due,
                'ID_ResponsableFk': actor,
            }
            rejected(lambda: insert('support', 'T_EtapeParcours', {**stage_values, 'ID_ResponsableFk': other}), 'Responsable d’étape interentreprise refusé')
            stage = insert('support', 'T_EtapeParcours', stage_values)
            rejected(lambda: insert('support', 'T_EtapeParcours', {**stage_values, 'Position': 2}), 'Deux étapes ouvertes simultanément refusées')
            rejected(lambda: update('T_ParcoursSupport', 'ID_SupportFk', tracked['ID_Support'], {'TermineLe': current_time}), 'Clôture d’un parcours avec une étape ouverte refusée')
            view = one('SELECT * FROM support."V_ParcoursSupport" WHERE "ID_SupportFk"=%s', [tracked['ID_Support']])
            check(view['NomEtape'] == 'Instruction' and view['EnRetardGlobal'] and view['EnRetardEtape'], 'Synthèse fondée sur la version figée et les échéances')
            event_values = {
                'ID_SupportFk': tracked['ID_Support'], 'ID_EtapeFk': stage['ID_Etape'], 'Action': 'approve',
                'AuteurFk': actor, 'RequestId': uuid.uuid4(), 'PayloadHash': 'c' * 64,
            }
            event = insert('support', 'T_EvenementParcours', event_values)
            rejected(lambda: insert('support', 'T_EvenementParcours', {**event_values, 'RequestId': uuid.uuid4()}), 'Validation répétée sur la même étape refusée')
            rejected(lambda: insert('support', 'T_EvenementParcours', {**event_values, 'Action': 'receive'}), 'Rejeu de requête sur un parcours refusé')
            rejected(lambda: update('T_EvenementParcours', 'ID_Evenement', event['ID_Evenement'], {'Motif': 'Réécriture'}), 'Historique du parcours immuable')
            alert_values = {'ID_SupportFk': tracked['ID_Support'], 'Type': 'global', 'Occurrence': 0}
            alert = insert('support', 'T_AlerteParcours', alert_values)
            rejected(lambda: insert('support', 'T_AlerteParcours', alert_values), 'Alerte globale répétée refusée même sans identifiant d’étape')
            rejected(lambda: update('T_AlerteParcours', 'ID_Alerte', alert['ID_Alerte'], {'DestinataireFk': other}), 'Destinataire d’une autre entreprise refusé')
            rejected(lambda: update('T_AlerteParcours', 'ID_Alerte', alert['ID_Alerte'], {'Statut': 'sent', 'TraiteLe': current_time}), 'Envoi sans preuve de notification refusé')
            notification = insert('communication', 'T_Communication', {'IdUserFk': actor, 'IdEntiteFk': ea, 'ContenuCommunication': 'Notification de recette.'})
            update('T_AlerteParcours', 'ID_Alerte', alert['ID_Alerte'], {
                'Statut': 'sent', 'DestinataireFk': actor, 'TraiteLe': current_time, 'ID_CommunicationFk': notification['IdCommunication'],
            })
            rejected(lambda: update('T_AlerteParcours', 'ID_Alerte', alert['ID_Alerte'], {'Statut': 'pending'}), 'Envoi validé conservé sans modification')
            update('T_EtapeParcours', 'ID_Etape', stage['ID_Etape'], {'SortieLe': current_time})
            update('T_ParcoursSupport', 'ID_SupportFk', tracked['ID_Support'], {'TermineLe': current_time})
            view = one('SELECT * FROM support."V_ParcoursSupport" WHERE "ID_SupportFk"=%s', [tracked['ID_Support']])
            check(view['ID_EtapeCourante'] is None and not view['EnRetardGlobal'] and not view['EnRetardEtape'], 'Parcours terminé retiré des retards courants')

    check(one('SELECT count(*) n FROM support."T_Support"')['n'] == count_before, 'Aucun dossier fictif conservé après la recette')

print(json.dumps({'passed': True, 'assertions': len(checks), 'database': target.path[1:],
                  'installationSeed': installation_seed}))
