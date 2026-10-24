"""Migrations natives autorisées dans public, sans syncdb métier ni faux état."""

from django.conf import settings
from django.core.management.commands.migrate import Command as DjangoMigrateCommand
from django.core.management.base import CommandError
from django.db import connections, transaction
from django.db.migrations.executor import MigrationExecutor

NATIVE_APPS = {"admin", "auth", "contenttypes", "sessions"}


class Command(DjangoMigrateCommand):
    def handle(self, *args, **options):
        alias = options.get("database", "default")
        if alias != "default":
            raise CommandError(
                "Seule la connexion PostgreSQL configurée est autorisée."
            )
        app = options.get("app_label")
        if app and app not in NATIVE_APPS:
            raise CommandError(
                "Les schémas métier sont gérés par SQL, pas par migrate."
            )
        if (
            options.get("migration_name") is not None
            or options.get("prune")
            or any(options.get(key) for key in ["run_syncdb", "fake", "fake_initial"])
        ):
            raise CommandError(
                "Réinitialisation, syncdb et fausses migrations désactivés."
            )
        conn = connections[alias]
        with conn.cursor() as cursor:
            cursor.execute("SELECT current_schema(),current_schemas(false)")
            schema, schemas = cursor.fetchone()
            if schema != "public" or schemas != ["public"]:
                raise CommandError(
                    "Le search_path de migration doit être exactement public."
                )
        executor = MigrationExecutor(conn)
        targets = executor.loader.graph.leaf_nodes()
        for migration, backwards in executor.migration_plan(targets):
            if migration.app_label not in NATIVE_APPS or backwards:
                raise CommandError(
                    "Le plan contient une opération hors des migrations natives autorisées."
                )
        if (
            not options.get("plan")
            and not options.get("check_unapplied")
            and settings.DB_READ_ONLY
        ):
            raise CommandError(
                "Définir SAUVERNDEKO_DB_READ_ONLY=0 uniquement pour appliquer les migrations natives validées."
            )
        if options.get("plan") or options.get("check_unapplied"):
            return super().handle(*args, **options)
        # PostgreSQL permet une transaction couvrant tout le lot et les post_migrate.
        with transaction.atomic(using=alias):
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT pg_advisory_xact_lock(hashtext(%s))",
                    ["sauverndeko:django:public"],
                )
            return super().handle(*args, **options)
