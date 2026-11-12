BEGIN;
SET LOCAL lock_timeout='10s';
CREATE OR REPLACE VIEW geolocalisation."V_DestinationLogistique" AS
SELECT n5."ID_Niveau_5" AS id,n5."NomNiveau_5",n5."CodeNiveau_5",
 concat_ws(' / ',NULLIF(btrim(n0."NomNiveau_0"),''),NULLIF(btrim(n1."NomNiveau_1"),''),CASE WHEN NULLIF(btrim(n2."NomNiveau_2"),'') IS NOT NULL THEN concat(COALESCE(NULLIF(btrim(t2."AbrGenerique"),''),NULLIF(btrim(t2."NomGenerique"),''),'Niveau 2'),' · ',btrim(n2."NomNiveau_2")) END,CASE WHEN NULLIF(btrim(n3."NomNiveau_3"),'') IS NOT NULL THEN concat(COALESCE(NULLIF(btrim(t3."AbrGenerique"),''),NULLIF(btrim(t3."NomGenerique"),''),'Niveau 3'),' · ',btrim(n3."NomNiveau_3")) END,CASE WHEN NULLIF(btrim(n4."NomNiveau_4"),'') IS NOT NULL THEN concat(COALESCE(NULLIF(btrim(t4."AbrGenerique"),''),NULLIF(btrim(t4."NomGenerique"),''),'Niveau 4'),' · ',btrim(n4."NomNiveau_4")) END,CASE WHEN NULLIF(btrim(n5."NomNiveau_5"),'') IS NOT NULL THEN concat(COALESCE(NULLIF(btrim(t5."AbrGenerique"),''),NULLIF(btrim(t5."NomGenerique"),''),'Niveau 5'),' · ',btrim(n5."NomNiveau_5")) END) AS label,
 n3."ID_Niveau_3" AS "ID_Niveau_3_Fk",n4."ID_Niveau_4" AS "ID_Niveau_4_Fk",
 (NULLIF(btrim(n5."NomNiveau_5"),'') IS NOT NULL AND n3."ID_Niveau_3" IS NOT NULL AND n2."ID_Niveau_2" IS NOT NULL AND n1."ID_Niveau_1" IS NOT NULL AND n0."ID_Niveau_0" IS NOT NULL AND (n5."ID_Niveau_4_Fk" IS NULL OR n4."ID_Niveau_4" IS NOT NULL) AND (n5."ID_Niveau_3_Fk" IS NULL OR n5."ID_Niveau_4_Fk" IS NULL OR n5."ID_Niveau_3_Fk"=n4."ID_Niveau_3_Fk")) AS "EstCoherente"
FROM geolocalisation."T_Niveau_5" n5
LEFT JOIN geolocalisation."T_Niveau_4" n4 ON n4."ID_Niveau_4"=n5."ID_Niveau_4_Fk"
LEFT JOIN geolocalisation."T_Niveau_3" n3 ON n3."ID_Niveau_3"=COALESCE(n5."ID_Niveau_3_Fk",n4."ID_Niveau_3_Fk")
LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n3."ID_Niveau_2_FK"
LEFT JOIN geolocalisation."T_Niveau_1" n1 ON n1."ID_Niveau_1"=n2."ID_Niveau_1_FK"
LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n0."ID_Niveau_0"=n1."ID_Niveau_0_Fk"
LEFT JOIN referentiel."T_Generique" t2 ON t2."ID_Generique"=n2."ID_TypeNiveau_2_Fk"
LEFT JOIN referentiel."T_Generique" t3 ON t3."ID_Generique"=n3."ID_TypeNiveau_2_Fk"
LEFT JOIN referentiel."T_Generique" t4 ON t4."ID_Generique"=n4."ID_TypeNiveau_4_Fk"
LEFT JOIN referentiel."T_Generique" t5 ON t5."ID_Generique"=n5."ID_TypeNiveau_5_Fk";
COMMENT ON VIEW geolocalisation."V_DestinationLogistique" IS 'Destinations avec types géographiques et sanitaires issus du référentiel commun ; chemin hiérarchique conservé et cohérence des parents contrôlée.';
COMMENT ON COLUMN geolocalisation."V_DestinationLogistique".label IS 'Chemin hiérarchique : chaque niveau typé porte l’abréviation réelle du référentiel (AS, ZS, etc.), ou son libellé de type ; aucune classification déduite du nom du lieu.';
COMMIT;
