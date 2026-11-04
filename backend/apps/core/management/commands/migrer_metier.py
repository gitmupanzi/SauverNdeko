"""Plan et application des migrations SQL métier d'une livraison vérifiée."""
import json
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import connection

from apps.core.schema_migrations import MigrationError, run_migrations


class Command(BaseCommand):
    help = 'Vérifier les versions métier ; appliquer seulement les migrations manquantes avec --apply.'
    requires_system_checks = []

    def add_arguments(self, parser):
        parser.add_argument('--manifest', default=str(Path(settings.BASE_DIR).parent / 'SQL/releases/manifest.json'))
        parser.add_argument('--baseline', help='Socle existant à vérifier intégralement avant sa première attestation.')
        parser.add_argument('--apply', action='store_true')
        parser.add_argument('--check', action='store_true', help='Refuser un socle absent, une migration en attente ou une dérive.')
        parser.add_argument('--release', help='Version applicative enregistrée pour cette exécution.')
        parser.add_argument('--lock-timeout-ms', type=int, default=10000)
        parser.add_argument('--statement-timeout-ms', type=int, default=120000)

    def handle(self, *args, **options):
        if options['apply'] and settings.DB_READ_ONLY:
            raise CommandError('La maintenance exige SAUVERNDEKO_DB_READ_ONLY=0 dans son environnement séparé.')
        try:
            result = run_migrations(connection, options['manifest'], apply=options['apply'],
                baseline_path=options['baseline'], check=options['check'], release=options['release'],
                lock_timeout_ms=options['lock_timeout_ms'], statement_timeout_ms=options['statement_timeout_ms'])
        except MigrationError as error:
            raise CommandError(str(error)) from None
        self.stdout.write(json.dumps(result, ensure_ascii=False))
