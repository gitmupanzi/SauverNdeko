"""Contrôle du compte web en lecture seule : aucun propriétaire/DDL autorisé."""
import os
import sys
from pathlib import Path
from environment import configure


CHECK_SQL = """
SELECT r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolreplication OR r.rolbypassrls
 OR has_database_privilege(current_user,current_database(),'CREATE')
 OR has_database_privilege(current_user,current_database(),'TEMPORARY')
 OR EXISTS(SELECT FROM pg_auth_members WHERE member=r.oid)
 OR EXISTS(SELECT FROM pg_namespace WHERE nspowner=r.oid)
 OR EXISTS(SELECT FROM pg_class WHERE relowner=r.oid)
 OR EXISTS(SELECT FROM pg_proc WHERE proowner=r.oid)
 OR EXISTS(SELECT FROM pg_database WHERE datdba=r.oid)
 OR COALESCE(has_table_privilege(current_user,to_regclass('systeme."T_MigrationSchema"'),
   'INSERT,UPDATE,DELETE,TRUNCATE'),false)
 OR COALESCE(has_any_column_privilege(current_user,to_regclass('systeme."T_MigrationSchema"'),
   'INSERT,UPDATE'),false)
 OR EXISTS(SELECT FROM pg_namespace WHERE nspname IN
   ('public','analytics','communication','geolocalisation','logistique','operations',
    'professionnel','referentiel','support','systeme')
   AND has_schema_privilege(current_user,oid,'CREATE')) AS excessive
FROM pg_roles r WHERE r.rolname=current_user
"""


def main():
    try:
        configure()
        os.environ["SAUVERNDEKO_DB_READ_ONLY"] = "1"
        sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "backend"))
        import django
        django.setup()
        from django.db import connection
        with connection.cursor() as cursor:
            cursor.execute(CHECK_SQL)
            row = cursor.fetchone()
            if not row or row[0]:
                raise RuntimeError("La connexion du service web possède des droits de maintenance.")
        print("Compte PostgreSQL du service web : droits de maintenance exclus.")
        return 0
    except Exception:
        # Une erreur de connexion ne doit pas exposer l'URL ou être prise pour un succès.
        print("Contrôle du rôle runtime refusé ; vérifier sa connexion et ses privilèges.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
