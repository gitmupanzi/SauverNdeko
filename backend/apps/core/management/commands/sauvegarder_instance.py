from django.core.management.base import BaseCommand,CommandError
from apps.core.maintenance import verified_backup

class Command(BaseCommand):
    help='Sauvegarde privée PostgreSQL et médias, empreintes et décodage contrôlés.'
    def add_arguments(self,parser):
        parser.add_argument('--destination',required=True)
        parser.add_argument('--pg-bin')
    def handle(self,*args,**options):
        try:path,manifest=verified_backup(options['destination'],options['pg_bin'])
        except RuntimeError as error:raise CommandError(str(error))
        self.stdout.write(f'Sauvegarde vérifiée : {path} ; {len(manifest["tables"])} tables et {len(manifest["mediaFiles"])} médias. Restauration à tester séparément.')
