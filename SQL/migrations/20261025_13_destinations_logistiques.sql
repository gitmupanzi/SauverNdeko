-- Une destination référence un lieu existant ; aucun rapprochement automatique du texte historique.
BEGIN;
SET LOCAL lock_timeout='10s';
ALTER TABLE logistique."T_Commande" ADD COLUMN "ID_DestinationFk" integer REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5") ON UPDATE RESTRICT ON DELETE RESTRICT;
CREATE INDEX ix_commande_destination ON logistique."T_Commande"("ID_DestinationFk") WHERE "ID_DestinationFk" IS NOT NULL;
CREATE VIEW geolocalisation."V_DestinationLogistique" AS
SELECT n5."ID_Niveau_5" AS id,n5."NomNiveau_5",n5."CodeNiveau_5",
 concat_ws(' / ',NULLIF(btrim(n0."NomNiveau_0"),''),NULLIF(btrim(n1."NomNiveau_1"),''),NULLIF(btrim(n2."NomNiveau_2"),''),NULLIF(btrim(n3."NomNiveau_3"),''),NULLIF(btrim(n4."NomNiveau_4"),''),NULLIF(btrim(n5."NomNiveau_5"),'')) AS label,
 n3."ID_Niveau_3" AS "ID_Niveau_3_Fk",n4."ID_Niveau_4" AS "ID_Niveau_4_Fk",
 (NULLIF(btrim(n5."NomNiveau_5"),'') IS NOT NULL AND n3."ID_Niveau_3" IS NOT NULL AND n2."ID_Niveau_2" IS NOT NULL AND n1."ID_Niveau_1" IS NOT NULL AND n0."ID_Niveau_0" IS NOT NULL AND (n5."ID_Niveau_4_Fk" IS NULL OR n4."ID_Niveau_4" IS NOT NULL) AND (n5."ID_Niveau_3_Fk" IS NULL OR n5."ID_Niveau_4_Fk" IS NULL OR n5."ID_Niveau_3_Fk"=n4."ID_Niveau_3_Fk")) AS "EstCoherente"
FROM geolocalisation."T_Niveau_5" n5
LEFT JOIN geolocalisation."T_Niveau_4" n4 ON n4."ID_Niveau_4"=n5."ID_Niveau_4_Fk"
LEFT JOIN geolocalisation."T_Niveau_3" n3 ON n3."ID_Niveau_3"=COALESCE(n5."ID_Niveau_3_Fk",n4."ID_Niveau_3_Fk")
LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n3."ID_Niveau_2_FK"
LEFT JOIN geolocalisation."T_Niveau_1" n1 ON n1."ID_Niveau_1"=n2."ID_Niveau_1_FK"
LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n0."ID_Niveau_0"=n1."ID_Niveau_0_Fk";
CREATE FUNCTION logistique.tr_destination_commande() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 IF NEW."ID_DestinationFk" IS NULL OR (TG_OP='UPDATE' AND NEW."ID_DestinationFk" IS NOT DISTINCT FROM OLD."ID_DestinationFk") THEN RETURN NEW;END IF;
 PERFORM 1 FROM geolocalisation."T_Niveau_5" WHERE "ID_Niveau_5"=NEW."ID_DestinationFk" FOR KEY SHARE;
 IF NOT EXISTS(SELECT 1 FROM geolocalisation."V_DestinationLogistique" d WHERE d.id=NEW."ID_DestinationFk" AND d."EstCoherente") THEN RAISE EXCEPTION 'Destination géographique absente ou hiérarchie incohérente.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER destination_commande BEFORE INSERT OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_destination_commande();
DO $views$ DECLARE name text;definition text;BEGIN
 FOREACH name IN ARRAY ARRAY['V_Commande','V_CommandesSansDetails','V_SuiviReglements'] LOOP
 definition:=rtrim(pg_get_viewdef(format('logistique.%I',name)::regclass,true),';'||chr(10)||' ');
 EXECUTE format('CREATE OR REPLACE VIEW logistique.%I AS SELECT s.*,c."ID_DestinationFk",d.label AS "DestinationLibelle" FROM (%s) s JOIN logistique."T_Commande" c ON c."ID_Commande"=s."ID_Commande" LEFT JOIN geolocalisation."V_DestinationLogistique" d ON d.id=c."ID_DestinationFk"',name,definition);
 END LOOP;
END $views$;
COMMENT ON COLUMN logistique."T_Commande"."ID_DestinationFk" IS 'Destination facultative référencée au dernier niveau géographique existant ; le texte historique geolocalisationCmd reste conservé sans conversion.';
COMMENT ON CONSTRAINT "T_Commande_ID_DestinationFk_fkey" ON logistique."T_Commande" IS 'Référence facultative à un lieu existant de niveau 5, supprimable seulement lorsqu’aucun bon ne le référence.';
COMMENT ON INDEX logistique.ix_commande_destination IS 'Accélère les recherches de bons par destination géographique référencée.';
COMMENT ON VIEW geolocalisation."V_DestinationLogistique" IS 'Catalogue des lieux de niveau 5 avec chemin hiérarchique commun, partagé entre secteurs et contrôle de cohérence des parents.';
COMMENT ON FUNCTION logistique.tr_destination_commande() IS 'Vérifie le lieu choisi et la cohérence de sa hiérarchie ; conserve les anciennes références inchangées.';
COMMENT ON TRIGGER destination_commande ON logistique."T_Commande" IS 'Contrôle les destinations lors de la création ou d’un changement de lieu référencé, sans modifier le stock.';
DO $comments$ DECLARE r record;BEGIN
 FOR r IN SELECT table_schema,table_name,column_name FROM information_schema.columns WHERE (table_schema='geolocalisation' AND table_name='V_DestinationLogistique') OR (table_schema='logistique' AND table_name IN('V_Commande','V_CommandesSansDetails','V_SuiviReglements') AND column_name IN('ID_DestinationFk','DestinationLibelle')) LOOP EXECUTE format('COMMENT ON COLUMN %I.%I.%I IS %L',r.table_schema,r.table_name,r.column_name,'Lieu référencé ou chemin géographique existant : '||r.column_name||'. Aucun identifiant n’est déduit du texte libre.');END LOOP;
END $comments$;
COMMIT;
