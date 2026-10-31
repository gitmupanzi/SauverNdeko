"""Diagnostic GET uniquement, avec connexion PostgreSQL en lecture seule obligatoire."""

import json
import re
from django.core.management.base import BaseCommand, CommandError
from django.conf import settings
from django.db import connection
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core.views import MODULES
from apps.core.registry import VIEWS
from apps.core.admin_portal import SOURCES as ADMIN_REGISTERS
from apps.core.territorial_portal import SOURCES as TERRITORIAL_REGISTERS, INTERFACE_KEYS as TERRITORIAL_INTERFACES
from apps.logistique.reads import INDICATORS
from apps.logistique.followup_folders import AUTOMATIC


class Command(BaseCommand):
    help = (
        "Vérifie structure et routes GET sans migration, compte ou écriture PostgreSQL."
    )

    def handle(self, *args, **options):
        if not settings.DB_READ_ONLY:
            raise CommandError("SAUVERNDEKO_DB_READ_ONLY doit être activé.")

        def guard(execute, sql, params, many, context):
            if not (
                sql.split() and sql.split()[0].upper() in {"SELECT", "WITH", "SHOW", "EXPLAIN"}
            ):
                raise CommandError("Instruction non autorisée pendant la vérification.")
            return execute(sql, params, many, context)

        with connection.execute_wrapper(guard):
            with connection.cursor() as cursor:
                cursor.execute("SHOW transaction_read_only")
                if cursor.fetchone()[0] != "on":
                    raise CommandError("Connexion non protégée en lecture seule.")
            client = APIClient()
            actor = Actor(
                {
                    "IdUser": 2147483600,
                    "Is_Admin": True,
                    "Is_staff": False,
                    "IdEntiteFk": None,
                    "ValideUser": True,
                }
            )
            # Identité synthétique injectée uniquement dans ce diagnostic interne ; aucun JWT émis.
            client.force_authenticate(actor)
            urls = [
                "/health",
                "/SauverNdeko/auth/me/password",
                "/api/systeme/messagerie",
                "/api/workspace/modules",
                "/api/workspace/catalogue",
                "/api/workspace/organisations",
                "/api/public/stats",
                "/api/public/articles",
                "/api/public/pharmacies",
                "/api/public/experts",
                "/api/public/maladies",
                "/api/logistique/dashboard",
                "/api/logistique/references",
                "/api/logistique/commande-details",
                "/api/logistique/stock",
                "/api/logistique/reglements/entries",
                "/api/views",
                "/api/models",
                "/api/recherches",
                "/api/geolocalisation/hierarchie",
            ]
            urls.append("/api/systeme/administration/synthese")
            urls.append("/api/systeme/administration/entreprises")
            urls.extend("/api/systeme/administration/references/" + kind for kind in
                        ("utilisateurs", "roles", "correspondances", "parametres"))
            urls.append("/api/geolocalisation/territoires/synthese")
            with connection.cursor() as support_cursor:
                support_cursor.execute('SELECT to_regclass(%s)', ['support."T_Support"'])
                support_installed=bool(support_cursor.fetchone()[0])
            if support_installed:
                urls.extend(['/api/support/contexte','/api/support/entreprises',
                    '/api/support/tableau-de-bord','/api/support/kanban',
                    '/api/support/tickets?take=1','/api/tableaux/support.tickets/preferences',
                    '/api/referentiel/champs-references/valeurs?schema=support&table=T_Support&column=ID_TypeSupportFk'])
                with connection.cursor() as support_cursor:
                    support_cursor.execute('SELECT "ID_Support" FROM support."T_Support" ORDER BY "ID_Support" LIMIT 1')
                    support_record=support_cursor.fetchone()
                if support_record:urls.append('/api/support/tickets/'+str(support_record[0]))
            for kind, (_, name, primary_key, _) in TERRITORIAL_REGISTERS.items():
                root = "/api/geolocalisation/territoires/"
                urls.extend([root + "registres/" + kind + "?take=1", root + "references/" + kind,
                             "/api/tableaux/" + TERRITORIAL_INTERFACES[kind] + "/preferences"])
                if primary_key != "_rowId":
                    # Noms fermés du catalogue, jamais des identifiants reçus du navigateur.
                    with connection.cursor() as territorial_cursor:
                        territorial_cursor.execute('SELECT "' + primary_key + '" FROM geolocalisation."'
                            + name.replace("V_", "T_", 1) + '" ORDER BY "' + primary_key + '" LIMIT 1')
                        territorial_record = territorial_cursor.fetchone()
                    if territorial_record:
                        urls.append(root + "registres/" + kind + "/" + str(territorial_record[0]))
            urls.extend(["/api/systeme/personnel/references", "/api/logistique/immobilisations?take=1",
                "/api/logistique/immobilisations/references", "/api/logistique/registre/immobilisations?take=1",
                "/api/tableaux/logistique.immobilisations/preferences"])
            urls.extend(["/api/referentiel/champs-references?take=1",
                "/api/tableaux/referentiels.champs/preferences",
                "/api/referentiel/tableaux?take=1",
                "/api/referentiel/tableaux/referentiels.categories",
                "/api/tableaux/referentiels.tableaux/preferences",
                "/api/referentiel/champs-references/valeurs?schema=logistique&table=T_Article&column=ID_CategorieArticleFk"])
            with connection.cursor() as reference_cursor:
                reference_cursor.execute('SELECT "ID_ChampReferentiel" FROM referentiel."T_ChampReferentiel" '
                    'WHERE "SchemaName"=\'logistique\' AND "TableName"=\'T_Article\' AND "ColumnName"=\'ID_CategorieArticleFk\'')
                reference_field=reference_cursor.fetchone()
            if reference_field:
                reference_path='/api/referentiel/champs-references/'+str(reference_field[0])
                urls.extend([reference_path,reference_path+'/historique?scope=global',reference_path+'/valeurs'])
            urls.extend("/api/systeme/administration/registres/" + kind + "?take=1" for kind in ADMIN_REGISTERS)
            urls.extend("/api/tableaux/"+key+"/preferences" for key in (
                *["logistique."+kind for kind in ("articles","commandes","lignes","lots","mouvements","factures","reglements")],
                "referentiels.categories","referentiels.valeurs",*["admin."+kind for kind in ADMIN_REGISTERS]))
            urls.extend(["/api/logistique/synthese", "/api/logistique/registre/articles?take=1", "/api/logistique/registre/commandes?take=1", "/api/logistique/registre/lignes?take=1"])
            urls.extend("/api/logistique/registre/"+kind+"?take=1" for kind in ("lots","mouvements","factures","reglements"))
            urls.append("/api/logistique/registre/articles?contexte=composition&take=1")
            urls.append("/api/logistique/dossiers-suivi")
            urls.append("/api/logistique/peremption/politique")
            urls.append("/api/logistique/entreprise/identite")
            urls.extend("/api/logistique/dossiers-suivi/"+folder["key"]+"?take=1" for folder in AUTOMATIC)
            urls.extend("/api/logistique/indicateurs/" + key + "?take=1" for key in INDICATORS)
            urls.extend("/api/" + name + "?take=1" for name in MODULES)
            urls.extend(
                "/api/views/" + obj["schema"] + "/" + obj["name"] + "?take=1"
                for obj in VIEWS.values()
            )
            # Préparation d’une réception en GET uniquement, sans créer de bon.
            with connection.cursor() as cursor:
                cursor.execute('SELECT a."ID_Article" FROM logistique."T_Article" a JOIN systeme."T_Utilisateurs" u ON u."IdUser"=a."ID_UserFK" WHERE a."ValideArticle" IS TRUE AND u."IdEntiteFk" IS NULL ORDER BY a."ID_Article" LIMIT 1')
                receipt_article = cursor.fetchone()
            if receipt_article:
                urls.append("/api/logistique/articles/"+str(receipt_article[0])+"/receptions")
                urls.append("/api/logistique/articles/"+str(receipt_article[0])+"/valorisation")
            with connection.cursor() as cursor:
                cursor.execute('SELECT "ID_Commande" FROM logistique."T_Commande" ORDER BY "ID_Commande" LIMIT 1')
                sample_order = cursor.fetchone()
                cursor.execute('SELECT c."ID_Commande" FROM logistique."T_Commande" c JOIN systeme."T_Utilisateurs" u ON u."IdUser"=c."ID_UserFk" WHERE u."IdEntiteFk" IS NULL ORDER BY c."ID_Commande" LIMIT 1')
                platform_order = cursor.fetchone()
                cursor.execute('SELECT "ID_CmdFk","ID_ArticleFk" FROM logistique."T_CommandeDetail" ORDER BY "ID_CmdFk","ID_ArticleFk" LIMIT 1')
                sample_line = cursor.fetchone()
                cursor.execute('SELECT "ID_Commande" FROM logistique."T_Commande" WHERE NULLIF(btrim("CodeFacture"),\'\') IS NOT NULL ORDER BY "ID_Commande" LIMIT 1')
                sample_invoice=cursor.fetchone()
                cursor.execute('SELECT "ID_Reglement" FROM logistique."T_Reglements" ORDER BY "ID_Reglement" LIMIT 1')
                sample_payment=cursor.fetchone()
            with connection.cursor() as cursor:
                cursor.execute('SELECT "ID_LotArticle" FROM logistique."T_LotArticle" ORDER BY "ID_LotArticle" LIMIT 1')
                sample_lot = cursor.fetchone()
            if sample_lot:
                urls.extend("/api/logistique/lots/"+str(sample_lot[0])+suffix for suffix in ("", "/mouvements"))
            if sample_order:urls.append("/api/logistique/commandes/"+str(sample_order[0]))
            if platform_order:
                for suffix in ("composition","retours","facture"):
                    urls.append("/api/logistique/commandes/"+str(platform_order[0])+"/"+suffix)
            if sample_invoice:urls.append("/api/logistique/reglements/preparation?commandeId="+str(sample_invoice[0]))
            if sample_payment:urls.append("/api/logistique/reglements/"+str(sample_payment[0]))
            if sample_line:urls.append("/api/logistique/commande-details/"+str(sample_line[0])+"/"+str(sample_line[1]))
            results = []
            with override_settings(
                ALLOWED_HOSTS=[*settings.ALLOWED_HOSTS, "testserver"]
            ):
                for url in urls:
                    # Les préparations nécessitent un contexte explicite, même pour le compte global.
                    actor._context_entity = None
                    required = 'contexte=composition' in url or '/receptions' in url or '/retours' in url or '/peremption/politique' in url or '/entreprise/identite' in url
                    if required:
                        match = re.search(r'/articles/([0-9]+)/', url)
                        command = re.search(r'/commandes/([0-9]+)/', url)
                        with connection.cursor() as owner_cursor:
                            if match:
                                owner_cursor.execute('SELECT "IdEntiteFk" FROM logistique."T_Article" WHERE "ID_Article"=%s', [int(match.group(1))])
                            elif command:
                                owner_cursor.execute('SELECT "IdEntiteFk" FROM logistique."T_Commande" WHERE "ID_Commande"=%s', [int(command.group(1))])
                            else:
                                owner_cursor.execute('SELECT "IdEntite" FROM systeme."T_Entite" ORDER BY "IdEntite" LIMIT 1')
                            owner = owner_cursor.fetchone()
                        if owner and owner[0] is not None:
                            refusal = client.get(url)
                            results.append({"url": "sans-entreprise:"+url, "status": refusal.status_code, "attendu": 409})
                            if refusal.status_code != 409:
                                raise CommandError("Une préparation exige une entreprise active.")
                            actor._context_entity = int(owner[0])
                    response = client.get(url)
                    results.append({"url": url, "status": response.status_code})
                    if response.status_code != 200:
                        self.stderr.write(
                            json.dumps(
                                {
                                    "url": url,
                                    "status": response.status_code,
                                    "error": response.data.get("error", {}).get("code"),
                                },
                                ensure_ascii=False,
                            )
                        )
                with connection.cursor() as sample_cursor:
                    sample_cursor.execute('SELECT "ID_Immobilisation" FROM logistique."T_Immobilisation" ORDER BY "ID_Immobilisation" LIMIT 1')
                    sample_asset=sample_cursor.fetchone()
                asset_id=sample_asset[0] if sample_asset else 2147483600
                expected=200 if sample_asset else 404
                for suffix in ('','/historique'):
                    url='/api/logistique/immobilisations/'+str(asset_id)+suffix
                    response=client.get(url)
                    results.append({'url':url,'status':response.status_code,'attendu':expected})
                    if response.status_code!=expected:
                        raise CommandError('Lecture du patrimoine inattendue : '+url)
                # Même API et mêmes vues dans chaque entreprise : ne pas se
                # limiter à la vue globale qui masquerait une fuite de portée.
                with connection.cursor() as entity_cursor:
                    entity_cursor.execute('SELECT "IdEntite" FROM systeme."T_Entite" '
                                          'WHERE "ValideEntite" IS NOT FALSE ORDER BY "IdEntite" LIMIT 2')
                    entities = [item[0] for item in entity_cursor.fetchall()]
                for entity in entities:
                    actor._context_entity = entity
                    for kind in ("utilisateurs", "entites", "licences", "correspondances", "parametres", "roles"):
                        url = '/api/systeme/administration/registres/' + kind + '?take=2'
                        response = client.get(url)
                        results.append({'url': 'entreprise:' + str(entity) + ':' + url,
                                        'status': response.status_code, 'attendu': 200})
                        if response.status_code != 200:
                            raise CommandError('Lecture administration par entreprise refusée : ' + kind)
                        for row in response.data['data']:
                            owner = row.get('IdEntiteFk', row.get('IdEntite'))
                            if owner is not None and owner != entity:
                                raise CommandError('Une lecture administration contient une autre entreprise : ' + kind)
                    url = '/api/systeme/administration/synthese'
                    response = client.get(url)
                    results.append({'url': 'entreprise:' + str(entity) + ':' + url,
                                    'status': response.status_code, 'attendu': 200})
                    if response.status_code != 200 or response.data['data']['scope'] != {'kind': 'entity', 'id': entity}:
                        raise CommandError('La synthèse administration ne conserve pas son entreprise.')
                actor._context_entity = None
            # La politique publique de récupération reste contrôlée en anonyme, sans envoi.
            anonymous = APIClient()
            with override_settings(ALLOWED_HOSTS=[*settings.ALLOWED_HOSTS, "testserver"]):
                response = anonymous.get("/SauverNdeko/auth/password-reset")
            results.append({"url":"/SauverNdeko/auth/password-reset","status":response.status_code})
            if response.status_code != 200 or response.data.get("data",{}).get("available") is not False:
                raise CommandError("La récupération publique doit rester indisponible pendant le diagnostic en lecture seule.")
            # Une organisation fictive sans offre doit être refusée avant toute lecture métier.
            client.force_authenticate(
                Actor(
                    {
                        "IdUser": 2147483600,
                        "IdEntiteFk": 2147483600,
                        "Is_Admin": False,
                        "Is_staff": True,
                    }
                )
            )
            with override_settings(
                ALLOWED_HOSTS=[*settings.ALLOWED_HOSTS, "testserver"]
            ):
                for url in [
                    "/api/logistique/synthese",
                    "/api/logistique/registre/articles?take=1",
                    "/api/logistique/registre/commandes?take=1", "/api/logistique/registre/lignes?take=1",
                    "/api/logistique/registre/mouvements?take=1",
                    "/api/logistique/registre/factures?take=1",
                    "/api/logistique/registre/reglements?take=1",
                    "/api/logistique/reglements/preparation?commandeId=1",
                    "/api/logistique/dossiers-suivi",
                    "/api/logistique/articles",
                    "/api/logistique/articles/1/receptions",
                    "/api/logistique/commandes",
                    "/api/logistique/commandes/1/composition",
                    "/api/logistique/commandes/1/retours",
                    "/api/logistique/commandes/1/facture",
                    "/api/logistique/commande-details",
                    "/api/logistique/mouvements",
                    "/api/logistique/reglements",
                    "/api/logistique/reglements/entries",
                    "/api/logistique/stock",
                    "/api/logistique/dashboard",
                    "/api/logistique/references",
                    "/api/logistique/immobilisations",
                    "/api/logistique/immobilisations/references",
                    "/api/logistique/registre/immobilisations",
                    "/api/tableaux/logistique.immobilisations/preferences",
                    "/api/systeme/personnel/references",
                    "/api/systeme/utilisateurs",
                    "/api/systeme/entites",
                    "/api/systeme/licences",
                ]:
                    response = client.get(url)
                    results.append({"url":"organisation-sans-offre:"+url,"status":response.status_code,"attendu":403})
                    if response.status_code != 403 or response.data.get("data"):
                        raise CommandError("Accès inattendu pour une organisation sans offre : "+url)
            report = {
                "routesGET": len(results),
                "reussies": sum(r["status"] == r.get("attendu",200) for r in results),
                "ecritureBase": False,
                "connexionLectureSeule": True,
                "details": results,
            }
            self.stdout.write(json.dumps(report, ensure_ascii=False))
            if report["reussies"] != report["routesGET"]:
                raise CommandError("Certaines routes GET nécessitent une correction.")
