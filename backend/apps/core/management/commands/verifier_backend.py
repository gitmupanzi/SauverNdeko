"""Diagnostic GET uniquement, avec connexion PostgreSQL en lecture seule obligatoire."""

import json
from django.core.management.base import BaseCommand, CommandError
from django.conf import settings
from django.db import connection
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core.views import MODULES
from apps.core.registry import VIEWS
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
                sql.split() and sql.split()[0].upper() in {"SELECT", "SHOW", "EXPLAIN"}
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
            urls.extend(["/api/logistique/synthese", "/api/logistique/registre/articles?take=1", "/api/logistique/registre/commandes?take=1"])
            urls.append("/api/logistique/dossiers-suivi")
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
            results = []
            with override_settings(
                ALLOWED_HOSTS=[*settings.ALLOWED_HOSTS, "testserver"]
            ):
                for url in urls:
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
                    "/api/logistique/registre/commandes?take=1",
                    "/api/logistique/dossiers-suivi",
                    "/api/logistique/articles",
                    "/api/logistique/articles/1/receptions",
                    "/api/logistique/commandes",
                    "/api/logistique/commande-details",
                    "/api/logistique/mouvements",
                    "/api/logistique/reglements",
                    "/api/logistique/reglements/entries",
                    "/api/logistique/stock",
                    "/api/logistique/dashboard",
                    "/api/logistique/references",
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
