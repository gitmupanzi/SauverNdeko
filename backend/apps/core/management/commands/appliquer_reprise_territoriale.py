"""Application explicite d'un plan privé de rapprochement territorial contrôlé."""
import json
from django.core.management.base import BaseCommand, CommandError
from apps.core.territorial_reconciliation_apply import run_plan
from apps.core.responses import APIError, ExactEncoder


class Command(BaseCommand):
    help = 'Prévol sans écriture par défaut ; application explicite d’un plan territorial épinglé par SHA-256.'

    def add_arguments(self, parser):
        parser.add_argument('--plan', required=True)
        parser.add_argument('--plan-sha256', required=True)
        parser.add_argument('--actor', required=True, help='Adresse du compte administrateur global actif responsable.')
        modes = parser.add_mutually_exclusive_group()
        modes.add_argument('--apply', action='store_true', help='Appliquer dans une transaction unique avec audit.')
        modes.add_argument('--simulate', action='store_true', help='Exécuter puis annuler uniquement dans une copie locale sauverndeko_test_*.')
        modes.add_argument('--prepare-return', action='store_true', help='Contrôler le journal avant de préparer une compensation, sans écriture.')

    def handle(self, *args, **options):
        mode = 'apply' if options['apply'] else 'simulate' if options['simulate'] else 'prepare_return' if options['prepare_return'] else 'preflight'
        try:
            result = run_plan(options['plan'], options['plan_sha256'], options['actor'], mode)
        except APIError as exc:
            raise CommandError(str(exc.detail)) from exc
        self.stdout.write(json.dumps(result, cls=ExactEncoder, ensure_ascii=False, sort_keys=True))
