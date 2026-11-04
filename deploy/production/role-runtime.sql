-- À exécuter par le compte d'administration des migrations, après installation des schémas.
-- Un rôle neuf est NOLOGIN : attribuer son mot de passe avec \password sauverndeko_runtime,
-- puis ALTER ROLE sauverndeko_runtime LOGIN. Ne jamais inscrire le secret dans ce fichier.
BEGIN;
DO $role$
DECLARE marker text; owned boolean;
BEGIN
 SELECT shobj_description(oid,'pg_authid') INTO marker FROM pg_roles WHERE rolname='sauverndeko_runtime';
 IF FOUND AND marker IS DISTINCT FROM 'SauverNdeko : service applicatif restreint, migrations exclues.' THEN
  RAISE EXCEPTION 'Rôle existant non identifié ; examen administratif requis.';
 END IF;
 IF NOT FOUND THEN
  CREATE ROLE sauverndeko_runtime NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS;
  COMMENT ON ROLE sauverndeko_runtime IS 'SauverNdeko : service applicatif restreint, migrations exclues.';
 END IF;
 SELECT EXISTS(SELECT FROM pg_class WHERE relowner=(SELECT oid FROM pg_roles WHERE rolname='sauverndeko_runtime'))
  OR EXISTS(SELECT FROM pg_namespace WHERE nspowner=(SELECT oid FROM pg_roles WHERE rolname='sauverndeko_runtime'))
  OR EXISTS(SELECT FROM pg_proc WHERE proowner=(SELECT oid FROM pg_roles WHERE rolname='sauverndeko_runtime'))
  OR EXISTS(SELECT FROM pg_database WHERE datdba=(SELECT oid FROM pg_roles WHERE rolname='sauverndeko_runtime')) INTO owned;
 IF owned THEN RAISE EXCEPTION 'Le rôle applicatif possède des objets ; séparer leur propriétaire avant application.';END IF;
END $role$;
ALTER ROLE sauverndeko_runtime NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS;
ALTER ROLE sauverndeko_runtime SET search_path=public;
ALTER ROLE sauverndeko_runtime SET statement_timeout='15s';
ALTER ROLE sauverndeko_runtime SET lock_timeout='3s';
DO $grants$
DECLARE s text;r record;
BEGIN
 FOR r IN SELECT parent.rolname FROM pg_auth_members m JOIN pg_roles child ON child.oid=m.member JOIN pg_roles parent ON parent.oid=m.roleid WHERE child.rolname='sauverndeko_runtime' LOOP
  EXECUTE format('REVOKE %I FROM sauverndeko_runtime',r.rolname);
 END LOOP;
 EXECUTE format('REVOKE ALL PRIVILEGES ON DATABASE %I FROM sauverndeko_runtime',current_database());
 EXECUTE format('REVOKE CREATE,TEMPORARY ON DATABASE %I FROM PUBLIC',current_database());
 EXECUTE format('GRANT CONNECT ON DATABASE %I TO sauverndeko_runtime',current_database());
 REVOKE CREATE ON SCHEMA public FROM PUBLIC;
 REVOKE ALL ON SCHEMA public FROM sauverndeko_runtime;
 GRANT USAGE ON SCHEMA public TO sauverndeko_runtime;
 FOREACH s IN ARRAY ARRAY['analytics','communication','geolocalisation','logistique','operations','professionnel','referentiel','support','systeme'] LOOP
  IF NOT EXISTS(SELECT FROM pg_namespace WHERE nspname=s) THEN RAISE EXCEPTION 'Schéma requis manquant : %',s;END IF;
  EXECUTE format('REVOKE ALL ON SCHEMA %I FROM sauverndeko_runtime',s);
  EXECUTE format('GRANT USAGE ON SCHEMA %I TO sauverndeko_runtime',s);
  EXECUTE format('REVOKE ALL ON ALL TABLES IN SCHEMA %I FROM sauverndeko_runtime',s);
  EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA %I TO sauverndeko_runtime',s);
  EXECUTE format('REVOKE ALL ON ALL SEQUENCES IN SCHEMA %I FROM sauverndeko_runtime',s);
  EXECUTE format('GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA %I TO sauverndeko_runtime',s);
  EXECUTE format('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA %I TO sauverndeko_runtime',s);
  EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO sauverndeko_runtime',s);
  EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT USAGE,SELECT ON SEQUENCES TO sauverndeko_runtime',s);
 END LOOP;
 -- Tables natives nécessaires aux sessions/admin Django ; aucun droit de migration.
 FOR r IN SELECT tablename FROM pg_tables WHERE schemaname='public' AND (tablename LIKE 'auth_%' OR tablename IN ('django_session','django_admin_log','django_content_type')) LOOP
  EXECUTE format('REVOKE ALL ON public.%I FROM sauverndeko_runtime',r.tablename);
  EXECUTE format('GRANT SELECT ON public.%I TO sauverndeko_runtime',r.tablename);
  IF r.tablename='django_session' THEN GRANT INSERT,UPDATE,DELETE ON public.django_session TO sauverndeko_runtime;END IF;
  IF r.tablename='django_admin_log' THEN GRANT INSERT ON public.django_admin_log TO sauverndeko_runtime;END IF;
 END LOOP;
 REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM sauverndeko_runtime;
 FOR r IN SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema='public' AND sequence_name='django_admin_log_id_seq' LOOP
  EXECUTE format('GRANT USAGE,SELECT ON SEQUENCE public.%I TO sauverndeko_runtime',r.sequence_name);
 END LOOP;
 IF to_regclass('public.django_migrations') IS NOT NULL THEN GRANT SELECT ON public.django_migrations TO sauverndeko_runtime;END IF;
 -- Les journaux sont append-only au niveau de ce compte ; les triggers écrivent en INSERT.
 REVOKE UPDATE,DELETE ON systeme."T_Audit_Log",systeme."T_Login",operations."T_Paiement_Archive" FROM sauverndeko_runtime;
 -- Les déploiements sont attestés par la maintenance, jamais par le serveur HTTP.
 -- Cette exception vient après les droits métier communs et doit être conservée
 -- lors de toute réapplication de ce script ou des privilèges par défaut.
 IF to_regclass('systeme."T_MigrationSchema"') IS NOT NULL THEN
  REVOKE ALL ON systeme."T_MigrationSchema" FROM PUBLIC,sauverndeko_runtime;
  GRANT SELECT ON systeme."T_MigrationSchema" TO sauverndeko_runtime;
 END IF;
END $grants$;
COMMIT;
