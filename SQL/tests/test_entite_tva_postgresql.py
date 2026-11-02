"""Recette TVA réelle sur une base privée AVANT migration 20261102_01.

La recette y crée des fixtures fictives, applique la migration, compare toutes
les anciennes lignes et exerce les triggers, calculs et restitutions. Aucun
repli vers DATABASE_URL ni écriture sur SauverNdeko n'est permis.
"""
import hashlib
import json
import os
import uuid
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg import sql
from psycopg.rows import dict_row

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
target = urlsplit(DSN)
if target.hostname not in {'127.0.0.1', 'localhost'} or not target.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Une base PostgreSQL locale privée sauverndeko_test_* est obligatoire.')
checks = []


def check(value, name):
    assert value, name
    checks.append(name)


with psycopg.connect(DSN, autocommit=True, row_factory=dict_row, options='-c timezone=Africa/Kinshasa') as c:
    if not c.execute('SELECT current_database() n').fetchone()['n'].startswith('sauverndeko_test_'):
        raise RuntimeError('Base privée obligatoire.')
    if c.execute("SELECT FROM information_schema.columns WHERE table_schema='systeme' AND table_name='T_Entite' AND column_name='TauxTVAEntite'").fetchone():
        raise RuntimeError('Cette recette exige une copie privée avant la migration TVA ; ne pas rejouer la migration.')

    def q(statement, params=()):
        return c.execute(statement, params if params else None)

    def one(statement, params=()):
        return q(statement, params).fetchone()

    def insert(schema, table, data):
        return q(sql.SQL('INSERT INTO {}.{} ({}) VALUES ({}) RETURNING *').format(
            sql.Identifier(schema), sql.Identifier(table),
            sql.SQL(',').join(map(sql.Identifier, data)),
            sql.SQL(',').join(sql.Placeholder() for _ in data)), list(data.values())).fetchone()

    def rejected(callback, label):
        try:
            with c.transaction():
                callback()
                q('SET CONSTRAINTS ALL IMMEDIATE')
        except psycopg.Error as error:
            assert error.sqlstate not in {'42601', '42703', '42P01', '42883'}, (label, str(error))
            check(True, label)
        else:
            raise AssertionError(label + ' accepté')

    def ref(category, abbreviation=None):
        return one('SELECT g."ID_Generique" id FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c '
                   'ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE c."NomCategorieGenerique"=%s '
                   'AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE '
                   + ('AND g."AbrGenerique"=%s ' if abbreviation else '') + 'ORDER BY g."ID_Generique" LIMIT 1',
                   [category, *([abbreviation] if abbreviation else [])])['id']

    unit, category, kind, currency, entry, outgoing = (
        ref('Unités', 'pcs'), ref('Catégorie produit'), ref('Type produit'),
        ref('Devise', 'USD'), ref('Type de commande', 'Entrée'), ref('Type de commande', 'Sortie'))
    entity = insert('systeme', 'T_Entite', {'NomEntite': 'Entreprise TVA fictive', 'EmailEntite': uuid.uuid4().hex + '@example.invalid'})['IdEntite']
    other = insert('systeme', 'T_Entite', {'NomEntite': 'Autre entreprise fictive', 'EmailEntite': uuid.uuid4().hex + '@example.invalid'})['IdEntite']
    uid = insert('systeme', 'T_Utilisateurs', {'NomUser': 'Fictif', 'PrenomUser': 'TVA', 'EmailUser': uuid.uuid4().hex + '@example.invalid',
                 'MotdepasseUser': 'compte-recette-inutilisable', 'SexeUser': 'M', 'ValideUser': True, 'IdEntiteFk': entity})['IdUser']

    def article(owner=entity, price='10.00', measure=unit):
        row = insert('logistique', 'T_Article', {'NomArticle': 'Article TVA fictif ' + uuid.uuid4().hex[:8], 'IdEntiteFk': owner,
                     'ID_UserFK': uid, 'ID_UniteFk': measure, 'ID_TypeArticleFk': kind, 'ID_CategorieArticleFk': category,
                     'ID_DeviseFk': currency, 'QteArticle': 20, 'PUArticle': price, 'PVArticle': price})
        row['_unit_label'] = one('SELECT coalesce(nullif(btrim("AbrGenerique"),\'\'),"NomGenerique") label FROM referentiel."T_Generique" WHERE "ID_Generique"=%s', [measure])['label']
        return row

    def command(rows, owner=entity):
        with c.transaction():
            parent = insert('logistique', 'T_Commande', {'ID_TypeCmdFk': outgoing, 'IdEntiteFk': owner, 'ID_UserFk': uid, 'ID_DeviseFk': currency})
            for a, quantity, price in rows:
                insert('logistique', 'T_CommandeDetail', {'ID_CmdFk': parent['ID_Commande'], 'ID_ArticleFk': a['ID_Article'], 'QteCmdDetail': quantity, 'PUCmdDetail': price})
        return parent

    def invoice(parent, rows, *, supplied='0.01'):
        stamp = one('SELECT clock_timestamp() stamp')['stamp']
        with c.transaction():
            invoice = insert('logistique', 'T_Facture', {'ID_CommandeFk': parent['ID_Commande'], 'CodeFacture': '', 'ID_UserFk': uid,
                'IdEntiteFk': parent['IdEntiteFk'], 'RequestId': uuid.uuid4(), 'PayloadHash': 'a' * 64, 'DateFacture': stamp,
                'DateEcheancePaiement': stamp, 'ID_DeviseFk': currency, 'DeviseCode': 'USD', 'DeviseLibelle': 'USD',
                'MontantHT': supplied, 'MontantTTC': supplied})
            for a, quantity, price in rows:
                insert('logistique', 'T_FactureLigne', {'ID_FactureFk': invoice['ID_Facture'], 'ID_CmdFk': parent['ID_Commande'],
                    'ID_ArticleFk': a['ID_Article'], 'NomArticle': a['NomArticle'], 'Unite': a['_unit_label'], 'QteSortie': quantity,
                    'QteRetourAvantFacture': 0, 'QteFacturee': quantity, 'PUFacture': price,
                    'MontantLigne': (Decimal(str(quantity)) * Decimal(str(price))).quantize(Decimal('.01'))})
            q('UPDATE logistique."T_Commande" SET "CodeFacture"=%s,"DateFacture"=%s,"DateEcheancePaiement"=%s WHERE "ID_Commande"=%s',
              [invoice['CodeFacture'], stamp, stamp, parent['ID_Commande']])
            q('SET CONSTRAINTS ALL IMMEDIATE')
        return invoice

    def returned(parent, a, quantity, price='10.00'):
        stamp = one('SELECT clock_timestamp() stamp')['stamp']
        with c.transaction():
            child = insert('logistique', 'T_Commande', {'ID_TypeCmdFk': entry, 'IdEntiteFk': parent['IdEntiteFk'], 'ID_UserFk': uid,
                           'ID_DeviseFk': currency, 'DateCmd': stamp, 'RefCmd': 'Retour de recette TVA'})
            insert('logistique', 'T_CommandeDetail', {'ID_CmdFk': child['ID_Commande'], 'ID_ArticleFk': a['ID_Article'],
                   'QteCmdDetail': quantity, 'PUCmdDetail': price})
            insert('logistique', 'T_RetourBon', {'ID_CommandeOrigineFk': parent['ID_Commande'], 'ID_CommandeRetourFk': child['ID_Commande'],
                   'ID_UserFk': uid, 'IdEntiteFk': parent['IdEntiteFk'], 'RequestId': uuid.uuid4(), 'PayloadHash': 'b' * 64,
                   'Motif': 'Retour fictif pour vérification TVA', 'DateRetour': stamp})
            q('SET CONSTRAINTS ALL IMMEDIATE')

    def credit(parent, invoice, rows, taxable=False):
        total = sum((r['MontantTTC'] if taxable else r['MontantLigne'] for r in rows), Decimal(0))
        tax = sum((r['MontantTVA'] for r in rows), Decimal(0)) if taxable else Decimal(0)
        with c.transaction():
            payload = {'ID_FactureFk': invoice['ID_Facture'], 'ID_CommandeFk': parent['ID_Commande'], 'IdEntiteFk': parent['IdEntiteFk'],
                       'ID_UserFk': uid, 'CodeAvoir': '', 'DateAvoir': one('SELECT clock_timestamp() stamp')['stamp'],
                       'Motif': 'Avoir fictif TVA', 'ID_DeviseFk': currency, 'DeviseCode': 'USD', 'MontantTTC': total,
                       'RequestId': uuid.uuid4(), 'PayloadHash': 'c' * 64}
            if taxable:
                payload['MontantTVA'] = tax
            note = insert('logistique', 'T_Avoir', payload)
            for row in rows:
                insert('logistique', 'T_AvoirLigne', {'ID_AvoirFk': note['ID_Avoir'], **{k: row[k] for k in ('ID_ArticleFk', 'NomArticle', 'Unite', 'Quantite', 'PUAvoir', 'MontantLigne')}})
            q('SET CONSTRAINTS ALL IMMEDIATE')
        return note

    old_a = article()
    old_bon = command([(old_a, 3, '10.00')])
    old_invoice = invoice(old_bon, [(old_a, 3, '10.00')], supplied='30.00')
    returned(old_bon, old_a, 1)
    old_credit = credit(old_bon, old_invoice, [{'ID_ArticleFk': old_a['ID_Article'], 'NomArticle': old_a['NomArticle'], 'Unite': 'pcs',
                       'Quantite': Decimal(1), 'PUAvoir': Decimal(10), 'MontantLigne': Decimal(10)}])

    tables = q("SELECT schemaname,tablename FROM pg_tables WHERE schemaname=ANY(%s) ORDER BY 1,2",
               [['analytics', 'communication', 'geolocalisation', 'logistique', 'operations', 'professionnel', 'referentiel', 'support', 'systeme']]).fetchall()
    added = {'systeme.T_Entite': ['TauxTVAEntite'], 'logistique.T_Facture': ['TauxTVA', 'MontantTVA'],
             'logistique.T_FactureLigne': ['MontantTVA', 'MontantTTC'], 'logistique.T_Avoir': ['TauxTVA', 'MontantHT', 'MontantTVA'],
             'logistique.T_AvoirLigne': ['MontantTVA', 'MontantTTC']}

    def rows(table):
        name = table['schemaname'] + '.' + table['tablename']
        return q(sql.SQL('SELECT (to_jsonb(t)-%s::text[])::text row FROM {}.{} t ORDER BY (to_jsonb(t)-%s::text[])::text').format(
                 sql.Identifier(table['schemaname']), sql.Identifier(table['tablename'])), [added.get(name, []), added.get(name, [])]).fetchall()

    before = {r['schemaname'] + '.' + r['tablename']: rows(r) for r in tables}
    migration = ROOT / 'SQL/migrations/20261102_01_entite_tva.sql'
    q(migration.read_text(encoding='utf8'))
    for table in tables:
        name = table['schemaname'] + '.' + table['tablename']
        if name not in {'systeme.T_ModuleApplication', 'referentiel.T_InterfaceTableau'}:
            check(rows(table) == before[name], 'Migration conserve toutes les anciennes colonnes et lignes : ' + name)
    check(one('SELECT "TauxTVAEntite" rate FROM systeme."T_Entite" WHERE "IdEntite"=%s', [entity])['rate'] == 0, 'Entreprise existante au défaut zéro')
    new_entity = insert('systeme', 'T_Entite', {'NomEntite': 'Création fiscale fictive', 'EmailEntite': uuid.uuid4().hex + '@example.invalid'})
    check(new_entity['TauxTVAEntite'] == 0, 'Nouvelle entreprise au défaut zéro')
    preserved = one('SELECT * FROM logistique."T_Facture" WHERE "ID_Facture"=%s', [old_invoice['ID_Facture']])
    check(preserved['TauxTVA'] == preserved['MontantTVA'] == 0 and preserved['MontantHT'] == preserved['MontantTTC'] == Decimal(30), 'Ancienne facture zéro TVA sans modification de montants')
    preserved_credit = one('SELECT * FROM logistique."T_Avoir" WHERE "ID_Avoir"=%s', [old_credit['ID_Avoir']])
    check(preserved_credit['TauxTVA'] == preserved_credit['MontantTVA'] == 0 and preserved_credit['MontantHT'] == preserved_credit['MontantTTC'] == Decimal(10), 'Ancien avoir zéro TVA sans modification de montants')
    for rate in ('-0.0001', '100.0001', 'NaN', None):
        rejected(lambda rate=rate: q('UPDATE systeme."T_Entite" SET "TauxTVAEntite"=%s WHERE "IdEntite"=%s', [rate, entity]), 'Taux hors bornes ou absent refusé : ' + str(rate))
    q('UPDATE systeme."T_Entite" SET "TauxTVAEntite"=16 WHERE "IdEntite"=%s', [entity])
    check(one('SELECT "TauxTVAEntite" FROM systeme."V_IdentiteDocumentaire" WHERE "IdEntite"=%s', [entity])['TauxTVAEntite'] == Decimal(16), 'Profil entreprise réutilise le taux en base')
    check(one('SELECT * FROM logistique."T_Facture" WHERE "ID_Facture"=%s', [old_invoice['ID_Facture']]) == preserved, 'Changer le taux ne réécrit pas une ancienne facture')
    check(one('SELECT * FROM logistique."T_Avoir" WHERE "ID_Avoir"=%s', [old_credit['ID_Avoir']]) == preserved_credit, 'Changer le taux ne réécrit pas un ancien avoir')

    a = article()
    bon = command([(a, 3, '10.00')])
    preview = one('SELECT * FROM logistique.fn_facturation_tva(%s)', [bon['ID_Commande']])
    check(preview == {'TauxTVA': Decimal(16), 'MontantHT': Decimal(30), 'MontantTVA': Decimal('4.80'), 'MontantTTC': Decimal('34.80')}, 'Prévisualisation unique : 30 HT + 4,80 TVA = 34,80 TTC')
    stock = one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s', [a['ID_Article']])['q']
    f = invoice(bon, [(a, 3, '10.00')])
    check(all(f[k] == v for k, v in preview.items()), 'Trigger de facture impose les montants exacts, même si les montants envoyés sont faux')
    check(one('SELECT "MontantTVA","MontantTTC" FROM logistique."T_FactureLigne" WHERE "ID_FactureFk"=%s', [f['ID_Facture']]) == {'MontantTVA': Decimal('4.80'), 'MontantTTC': Decimal('34.80')}, 'Taxe et TTC de ligne figés')
    check(one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s', [a['ID_Article']])['q'] == stock, 'Facturer ne produit aucune variation de stock')
    check(one('SELECT "MontantHT","MontantTTC" FROM logistique."T_Commande" WHERE "ID_Commande"=%s', [bon['ID_Commande']]) == {'MontantHT': Decimal(30), 'MontantTTC': Decimal(30)}, 'La TVA ne change pas les totaux physiques du bon')
    q('UPDATE systeme."T_Entite" SET "TauxTVAEntite"=18 WHERE "IdEntite"=%s', [entity])
    check(one('SELECT * FROM logistique."T_Facture" WHERE "ID_Facture"=%s', [f['ID_Facture']]) == f, 'Facture à 16 % inchangée après réglage à 18 %')
    rejected(lambda: q('UPDATE logistique."T_Facture" SET "TauxTVA"=18 WHERE "ID_Facture"=%s', [f['ID_Facture']]), 'Taux de facture émise non modifiable')
    rejected(lambda: q('UPDATE logistique."T_FactureLigne" SET "MontantTVA"=8 WHERE "ID_FactureFk"=%s', [f['ID_Facture']]), 'Taxe de ligne émise non modifiable')
    b = article(other)
    other_bon = command([(b, 3, '10.00')], other)
    check(one('SELECT * FROM logistique.fn_facturation_tva(%s)', [other_bon['ID_Commande']])['MontantTVA'] == 0, 'Autre entreprise conserve son taux zéro')
    next_bon = command([(a, 1, '10.00')])
    check(one('SELECT * FROM logistique.fn_facturation_tva(%s)', [next_bon['ID_Commande']])['MontantTVA'] == Decimal('1.80'), 'Nouveau document utilise le nouveau taux 18 %')

    returned(bon, a, 1)
    pending = q('SELECT * FROM logistique.fn_lignes_avoir_attente(%s)', [bon['ID_Commande']]).fetchall()
    check(pending[0]['MontantLigne'] == Decimal(10) and pending[0]['MontantTVA'] == Decimal('1.60') and pending[0]['MontantTTC'] == Decimal('11.60'), 'Retour partiel reprend 16 % historique, pas 18 % courant')
    note1 = credit(bon, f, pending, True)
    check(note1['TauxTVA'] == Decimal(16) and note1['MontantHT'] == 10 and note1['MontantTTC'] == Decimal('11.60'), 'Avoir partiel conserve le taux et le total historique')
    check(one('SELECT logistique.fn_montant_avoir_attente(%s) amount', [bon['ID_Commande']])['amount'] == 0, 'Retour déjà crédité non compté une seconde fois')
    returned(bon, a, 2)
    pending = q('SELECT * FROM logistique.fn_lignes_avoir_attente(%s)', [bon['ID_Commande']]).fetchall()
    note2 = credit(bon, f, pending, True)
    check(note1['MontantTTC'] + note2['MontantTTC'] == f['MontantTTC'] and note1['MontantTVA'] + note2['MontantTVA'] == f['MontantTVA'], 'Retour total restitue exactement HT, TVA et TTC initiaux')
    check(one('SELECT "MontantAvoirAEtablir" amount FROM logistique."V_Facture" WHERE "ID_Facture"=%s', [f['ID_Facture']])['amount'] == 0, 'Vue financière sans avoir fantôme après restitution complète')

    q('UPDATE systeme."T_Entite" SET "TauxTVAEntite"=16 WHERE "IdEntite"=%s', [entity])
    tiny = article(price='.03')
    tiny_bon = command([(tiny, 3, '.03')])
    tiny_f = invoice(tiny_bon, [(tiny, 3, '.03')])
    notes = []
    for index in range(3):
        returned(tiny_bon, tiny, 1, '.03')
        pending = q('SELECT * FROM logistique.fn_lignes_avoir_attente(%s)', [tiny_bon['ID_Commande']]).fetchall()
        notes.append(credit(tiny_bon, tiny_f, pending, True))
    check(tiny_f['MontantTVA'] == Decimal('.01'), 'TVA de petite ligne arrondie au centime')
    check([n['MontantTVA'] for n in notes] == [Decimal(0), Decimal('.01'), Decimal(0)], 'Retours fractionnés répartissent les centimes par différence cumulée')
    check(sum(n['MontantTTC'] for n in notes) == tiny_f['MontantTTC'] and sum(n['MontantTVA'] for n in notes) == tiny_f['MontantTVA'], 'Retours fractionnés ne remboursent jamais un centime de trop')
    q('UPDATE systeme."T_Entite" SET "TauxTVAEntite"=16.1234 WHERE "IdEntite"=%s', [entity])
    precise_bon = command([(a, 1, '10.00')])
    precise = invoice(precise_bon, [(a, 1, '10.00')])
    check(precise['TauxTVA'] == Decimal('16.1234') and precise['MontantTVA'] == Decimal('1.61'), 'Taux à quatre décimales conservé et montant arrondi au centime')
    q('UPDATE systeme."T_Entite" SET "TauxTVAEntite"=100 WHERE "IdEntite"=%s', [entity])
    bound_bon = command([(a, 1, '10.00')])
    check(one('SELECT * FROM logistique.fn_facturation_tva(%s)', [bound_bon['ID_Commande']])['MontantTTC'] == Decimal(20), 'Borne de 100 % acceptée sans dépassement de montant')
    q('UPDATE systeme."T_Entite" SET "TauxTVAEntite"=16 WHERE "IdEntite"=%s', [entity])
    micro = [article(price='.03') for _ in range(3)]
    multi_rows = [(r, 1, '.03') for r in micro]
    multi_bon = command(multi_rows)
    multi_invoice = invoice(multi_bon, multi_rows)
    check(multi_invoice['MontantHT'] == Decimal('.09') and multi_invoice['MontantTVA'] == 0, 'Plusieurs petites lignes utilisent bien l’arrondi de chaque ligne avant sommation')
    # Les totaux d’avoir ne sont pas réputés fiables parce qu’ils viennent du
    # serveur HTTP : le contrôle différé les compare aux taxes réelles de ligne.
    returned(precise_bon, a, 1)
    precise_pending = q('SELECT * FROM logistique.fn_lignes_avoir_attente(%s)', [precise_bon['ID_Commande']]).fetchall()

    def falsified_credit():
        note = insert('logistique', 'T_Avoir', {'ID_FactureFk': precise['ID_Facture'], 'ID_CommandeFk': precise_bon['ID_Commande'],
            'IdEntiteFk': entity, 'ID_UserFk': uid, 'CodeAvoir': '', 'DateAvoir': one('SELECT clock_timestamp() stamp')['stamp'],
            'Motif': 'Montant falsifié de recette', 'ID_DeviseFk': currency, 'DeviseCode': 'USD', 'MontantTTC': Decimal('10.00'),
            'MontantTVA': Decimal(0), 'RequestId': uuid.uuid4(), 'PayloadHash': 'd' * 64})
        for row in precise_pending:
            insert('logistique', 'T_AvoirLigne', {'ID_AvoirFk': note['ID_Avoir'], **{k: row[k] for k in ('ID_ArticleFk', 'NomArticle', 'Unite', 'Quantite', 'PUAvoir', 'MontantLigne')}})

    rejected(falsified_credit, 'Avoir falsifié sans TVA refusé par les totaux différés')
    check(one('SELECT logistique.fn_montant_avoir_attente(%s) amount', [precise_bon['ID_Commande']])['amount'] == precise['MontantTTC'], 'Rejet atomique laisse le retour entier disponible à créditer')
    real_credit = credit(precise_bon, precise, precise_pending, True)
    check(real_credit['TauxTVA'] == Decimal('16.1234') and real_credit['MontantTTC'] == precise['MontantTTC'], 'Avoir exact après un rejet et un changement du taux courant')
    rejected(lambda: q('UPDATE logistique."T_Avoir" SET "MontantTVA"=0 WHERE "ID_Avoir"=%s', [real_credit['ID_Avoir']]), 'Taxe d’avoir émis immuable')
    rejected(lambda: q('UPDATE logistique."T_AvoirLigne" SET "MontantTVA"=0 WHERE "ID_AvoirFk"=%s', [real_credit['ID_Avoir']]), 'Taxe de ligne d’avoir émise immuable')
    unit_category = one('SELECT "ID_CategorieGeneriqueFk" id FROM referentiel."T_Generique" WHERE "ID_Generique"=%s', [unit])['id']
    fractional_unit = insert('referentiel', 'T_Generique', {'ID_CategorieGeneriqueFk': unit_category,
        'NomGenerique': 'Unité fractionnaire fictive ' + uuid.uuid4().hex, 'AbrGenerique': 'fraction-' + uuid.uuid4().hex[:6], 'ValideGenerique': True})['ID_Generique']
    insert('logistique', 'T_PrecisionStock', {'ID_UniteFk': fractional_unit, 'DecimalesStock': 3})
    fraction = article(price='.05', measure=fractional_unit)
    fractional_bon = command([(fraction, '.333', '.05')])
    fractional_invoice = invoice(fractional_bon, [(fraction, '.333', '.05')])
    check(fractional_invoice['MontantHT'] == Decimal('.02'), 'Quantité fractionnaire : base HT arrondie une seule fois sur la ligne entière')
    returned(fractional_bon, fraction, '.111', '.05')
    rows1 = q('SELECT * FROM logistique.fn_lignes_avoir_attente(%s)', [fractional_bon['ID_Commande']]).fetchall()
    fraction_note1 = credit(fractional_bon, fractional_invoice, rows1, True)
    returned(fractional_bon, fraction, '.111', '.05')
    zero_pending = one('SELECT * FROM logistique.fn_lignes_avoir_attente(%s)', [fractional_bon['ID_Commande']])
    check(zero_pending['MontantTTC'] == 0, 'Deuxième retour fractionnaire ne recrée pas un centime déjà crédité')
    returned(fractional_bon, fraction, '.111', '.05')
    rows2 = q('SELECT * FROM logistique.fn_lignes_avoir_attente(%s)', [fractional_bon['ID_Commande']]).fetchall()
    fraction_note2 = credit(fractional_bon, fractional_invoice, rows2, True)
    check(rows2[0]['Quantite'] == Decimal('.222'), 'Les quantités non valorisées restent reprises dans le retour valorisé suivant')
    check(fraction_note1['MontantTTC'] + fraction_note2['MontantTTC'] == fractional_invoice['MontantTTC'], 'Fractionnements physiques ne créent ni perte ni excédent financier d’arrondi')
    for view, columns in [('V_Facture', ['TauxTVA', 'MontantTVA']), ('V_Avoir', ['TauxTVA', 'MontantHT', 'MontantTVA']),
                          ('V_SuiviReglements', ['TauxTVA', 'MontantTVA', 'MontantHTFacture']),
                          ('V_Commande', ['TauxTVAFacture', 'MontantTVAFacture', 'MontantHTFacture'])]:
        check(all(column in one('SELECT * FROM logistique.' + sql.Identifier(view).as_string(c) + ' LIMIT 1') for column in columns), 'Projection fiscale disponible : ' + view)
    for key, fields in [('logistique.factures', ['MontantHTFacture', 'TauxTVA', 'MontantTVA']),
                        ('logistique.commandes', ['MontantHTFacture', 'TauxTVAFacture', 'MontantTVAFacture'])]:
        catalogue = one('SELECT "Colonnes" FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=%s', [key])['Colonnes']
        check(all(len([r for r in catalogue if r['id'] == field and not r['defaultVisible'] and not r['defaultExport'] and r['exportable']]) == 1 for field in fields), 'Colonnes fiscales optionnelles sans doublon : ' + key)
    check(one('SELECT "EstSocle","Actif" FROM systeme."T_ModuleApplication" WHERE "CodeModule"=%s', ['parametres']) == {'EstSocle': True, 'Actif': True}, 'Paramètres disponible comme module socle')
    for table, columns in added.items():
        schema, name = table.split('.')
        documented = one('SELECT count(*) n FROM pg_attribute a JOIN pg_class t ON t.oid=a.attrelid JOIN pg_namespace n ON n.oid=t.relnamespace '
                        'WHERE n.nspname=%s AND t.relname=%s AND a.attname=ANY(%s) AND col_description(a.attrelid,a.attnum) IS NOT NULL', [schema, name, columns])['n']
        check(documented == len(columns), 'Tous les nouveaux champs documentés : ' + table)
    proof = {'success': True, 'checks': len(checks), 'details': checks, 'database': target.path[1:],
             'migrationSHA256': hashlib.sha256(migration.read_bytes()).hexdigest(), 'sourceWrites': False,
             'oldRowsPreserved': True, 'invoiceAndCreditTaxSnapshots': True}
    (ROOT / '.runtime/entite-tva-sql-tests.json').write_text(json.dumps(proof, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps({'success': True, 'checks': len(checks), 'database': target.path[1:]}, ensure_ascii=False))
