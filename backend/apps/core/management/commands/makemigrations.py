from django.core.management.base import BaseCommand, CommandError
from django.db.migrations.autodetector import MigrationAutodetector


class Command(BaseCommand):
    autodetector = MigrationAutodetector
    requires_system_checks = []
    help = "Désactivé : PostgreSQL existant reste géré par SQL versionné."

    def handle(self, *args, **options):
        raise CommandError(
            "Aucune migration ou réinitialisation de base autorisée par ce backend."
        )
