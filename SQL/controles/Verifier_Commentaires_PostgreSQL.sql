-- Audit de couverture des commentaires : uniquement les catalogues PostgreSQL.
-- Aucun accès aux lignes des tables métier. Les objets internes et d'extension sont exclus.
BEGIN READ ONLY;
WITH scope AS (
  SELECT oid, nspname FROM pg_namespace
  WHERE nspname IN ('analytics','communication','geolocalisation','logistique',
    'operations','professionnel','referentiel','systeme','public')
), objects AS (
  SELECT 'SCHEMA'::text AS type, format('%I', nspname) AS object_name,
         obj_description(oid, 'pg_namespace') AS comment FROM scope
  UNION ALL
  SELECT CASE c.relkind WHEN 'r' THEN 'TABLE' WHEN 'p' THEN 'TABLE'
           WHEN 'v' THEN 'VIEW' WHEN 'm' THEN 'MATERIALIZED VIEW'
           WHEN 'f' THEN 'FOREIGN TABLE' WHEN 'S' THEN 'SEQUENCE' END,
         format('%I.%I', n.nspname, c.relname), obj_description(c.oid, 'pg_class')
  FROM pg_class c JOIN scope n ON n.oid = c.relnamespace
  WHERE c.relkind IN ('r','p','v','m','f','S')
  UNION ALL
  SELECT 'COLUMN', format('%I.%I.%I', n.nspname, c.relname, a.attname),
         col_description(c.oid, a.attnum)
  FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid
  JOIN scope n ON n.oid = c.relnamespace
  WHERE c.relkind IN ('r','p','v','m','f') AND a.attnum > 0 AND NOT a.attisdropped
  UNION ALL
  SELECT CASE p.prokind WHEN 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END,
         format('%I.%I(%s)', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid)),
         obj_description(p.oid, 'pg_proc')
  FROM pg_proc p JOIN scope n ON n.oid = p.pronamespace
  WHERE p.prokind IN ('f','p') AND NOT EXISTS (
    SELECT 1 FROM pg_depend d WHERE d.classid = 'pg_proc'::regclass
      AND d.objid = p.oid AND d.deptype = 'e'
  )
  UNION ALL
  SELECT 'TRIGGER', format('%I ON %I.%I', t.tgname, n.nspname, c.relname),
         obj_description(t.oid, 'pg_trigger')
  FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
  JOIN scope n ON n.oid = c.relnamespace WHERE NOT t.tgisinternal
  UNION ALL
  SELECT 'CONSTRAINT', format('%I ON %I.%I', k.conname, n.nspname, c.relname),
         obj_description(k.oid, 'pg_constraint')
  FROM pg_constraint k JOIN pg_class c ON c.oid = k.conrelid
  JOIN scope n ON n.oid = c.relnamespace
  UNION ALL
  SELECT 'INDEX', format('%I.%I', n.nspname, i.relname), obj_description(i.oid, 'pg_class')
  FROM pg_index x JOIN pg_class i ON i.oid = x.indexrelid
  JOIN pg_class c ON c.oid = x.indrelid JOIN scope n ON n.oid = c.relnamespace
  UNION ALL
  SELECT CASE t.typtype WHEN 'd' THEN 'DOMAIN' ELSE 'TYPE' END,
         format('%I.%I', n.nspname, t.typname), obj_description(t.oid, 'pg_type')
  FROM pg_type t JOIN scope n ON n.oid = t.typnamespace WHERE t.typtype IN ('d','e')
)
SELECT type,
       count(*) AS objets,
       count(*) FILTER (WHERE NULLIF(btrim(comment), '') IS NOT NULL) AS documentes,
       count(*) FILTER (WHERE NULLIF(btrim(comment), '') IS NULL) AS sans_commentaire,
       string_agg(object_name, E'\n' ORDER BY object_name)
         FILTER (WHERE NULLIF(btrim(comment), '') IS NULL) AS objets_a_documenter
FROM objects GROUP BY type ORDER BY type;
ROLLBACK;
