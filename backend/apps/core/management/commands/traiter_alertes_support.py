"""Distribuer les échéances des parcours Support dans les notifications privées."""
import json

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import DatabaseError, transaction
from rest_framework.exceptions import AuthenticationFailed

from apps.accounts.authentication import actor_by_id
from apps.core import db
from apps.core.module_access import can_read_tab


DUE_ALERTS = '''
    SELECT p."ID_SupportFk" AS ticket, p."IdEntiteFk" AS company,
           COALESCE(p."ID_ResponsableFk", s."ID_ResponsableFk") AS recipient,
           d.kind, d.step, d.deadline, COALESCE(last_alert."Occurrence" + 1, 0) AS occurrence
    FROM support."V_ParcoursSupport" p
    JOIN support."T_Support" s ON s."ID_Support" = p."ID_SupportFk"
    JOIN support."T_VersionProcessus" v ON v."ID_Version" = p."ID_VersionFk"
    CROSS JOIN LATERAL (VALUES
        ('global', NULL::bigint, p."EcheanceGlobale"),
        ('stage', p."ID_EtapeCourante", p."EcheanceEtape")
    ) d(kind, step, deadline)
    LEFT JOIN LATERAL (
        SELECT a."Occurrence", a."CreeLe"
        FROM support."T_AlerteParcours" a
        WHERE a."ID_SupportFk" = p."ID_SupportFk" AND a."Type" = d.kind
          AND a."ID_EtapeFk" IS NOT DISTINCT FROM d.step
        ORDER BY a."Occurrence" DESC
        LIMIT 1
    ) last_alert ON true
    WHERE p."TermineLe" IS NULL AND NOT s."Archive"
      AND support.fn_etat_support(s."CircuitSnapshot", s."ID_StatutFk") <> 'closed'
      AND d.deadline <= statement_timestamp()
      AND (
        last_alert."Occurrence" IS NULL
        OR last_alert."CreeLe" + make_interval(
            mins => NULLIF((v."Definition"->>'reminderMinutes')::integer, 0)
        ) <= statement_timestamp()
      )
'''


def eligible_recipient(alert):
    user_id = alert['recipient']
    if user_id is None:
        return None
    user = db.one(
        'SELECT "IdUser" FROM systeme."T_Utilisateurs" '
        'WHERE "IdUser" = %s AND "IdEntiteFk" = %s AND "ValideUser" FOR SHARE',
        [user_id, alert['company']],
    )
    if not user:
        return None
    try:
        actor = actor_by_id(user_id)
    except AuthenticationFailed:
        return None
    if can_read_tab(actor, 'support', 'tickets') and can_read_tab(actor, 'support', 'processus'):
        return user_id
    return None


def send_notification(alert, recipient):
    description = {
        'global': 'Un dossier Support dont vous avez la charge a dépassé son échéance.',
        'stage': 'Une étape Support dont vous avez la charge a dépassé son échéance.',
    }
    row = db.one('''
        INSERT INTO communication."T_Communication"
            ("IdUserFk", "IdEntiteFk", "ContenuCommunication")
        VALUES (%s, %s, %s)
        RETURNING "IdCommunication"
    ''', [recipient, alert['company'], description[alert['kind']]])
    return row['IdCommunication']


@transaction.atomic
def dispatch(candidate):
    # Même point de sérialisation que les actions sur le dossier.
    locked = db.one(
        'SELECT "ID_Support" FROM support."T_Support" WHERE "ID_Support"=%s FOR UPDATE SKIP LOCKED',
        [candidate['ticket']],
    )
    if not locked:
        return 'skipped'
    alert = db.one(
        DUE_ALERTS + ' AND p."ID_SupportFk"=%s AND d.kind=%s AND d.step IS NOT DISTINCT FROM %s::bigint',
        [candidate['ticket'], candidate['kind'], candidate['step']],
    )
    if not alert:
        return 'skipped'
    recipient = eligible_recipient(alert)
    communication = None
    error = None
    if recipient is None:
        error = 'Aucun responsable actif et habilité dans l’entreprise.'
    else:
        try:
            with transaction.atomic():
                communication = send_notification(alert, recipient)
        except DatabaseError:
            error = 'La notification n’a pas pu être enregistrée.'
    status = 'failed' if error else 'sent'
    db.query('''
        INSERT INTO support."T_AlerteParcours"
            ("ID_SupportFk", "ID_EtapeFk", "Type", "Occurrence", "Statut",
             "DestinataireFk", "ID_CommunicationFk", "Erreur", "TraiteLe")
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, clock_timestamp())
    ''', [alert['ticket'], alert['step'], alert['kind'], alert['occurrence'], status,
          recipient, communication, error])
    return status


class Command(BaseCommand):
    help = 'Traiter un lot d’échéances dépassées des parcours Support.'

    def add_arguments(self, parser):
        parser.add_argument('--limit', type=int, default=200)
        parser.add_argument('--dry-run', action='store_true', help='Compter le prochain lot en lecture seule.')

    def handle(self, *args, **options):
        if not 1 <= options['limit'] <= 1000:
            raise CommandError('La limite doit être comprise entre 1 et 1 000.')
        if settings.DB_READ_ONLY and not options['dry_run']:
            raise CommandError('Le traitement des alertes exige un environnement autorisé en écriture.')
        if not db.one("SELECT to_regclass('support.\"V_ParcoursSupport\"') IS NOT NULL AS present")['present']:
            raise CommandError('La migration des parcours Support doit être installée.')
        candidates = db.query(
            DUE_ALERTS + ' ORDER BY d.deadline, p."ID_SupportFk", d.kind LIMIT %s', [options['limit']],
        )
        report = {'candidates': len(candidates), 'sent': 0, 'failed': 0, 'skipped': 0}
        if not options['dry_run']:
            for candidate in candidates:
                report[dispatch(candidate)] += 1
        self.stdout.write(json.dumps(report))
