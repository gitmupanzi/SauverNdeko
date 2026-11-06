-- Les lignes existantes conservent la valeur initiale false, même après la modification du défaut.
ALTER TABLE communication."T_Chat"
    ADD COLUMN "SuiviLectureChat" boolean NOT NULL DEFAULT false;
ALTER TABLE communication."T_Chat" ALTER COLUMN "SuiviLectureChat" SET DEFAULT true;

COMMENT ON COLUMN communication."T_Chat"."LuChat" IS 'Indicateur historique conservé pour compatibilité. Les lectures individuelles sont enregistrées dans T_ChatLecture.';
COMMENT ON COLUMN communication."T_Chat"."SuiviLectureChat" IS 'Active le suivi individuel des nouveaux messages. Les messages antérieurs à son installation sont exclus des non-lus.';

CREATE TABLE communication."T_ChatLecture" (
    "IdChatFk" integer NOT NULL,
    "IdUserFk" integer NOT NULL,
    "LuLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT "Pk_ChatLecture" PRIMARY KEY ("IdChatFk", "IdUserFk"),
    CONSTRAINT "Fk_ChatLecture_Chat" FOREIGN KEY ("IdChatFk")
        REFERENCES communication."T_Chat" ("IdChat") ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT "Fk_ChatLecture_Utilisateur" FOREIGN KEY ("IdUserFk")
        REFERENCES systeme."T_Utilisateurs" ("IdUser") ON UPDATE CASCADE ON DELETE CASCADE
);

COMMENT ON TABLE communication."T_ChatLecture" IS 'Première lecture d’un message par un compte participant. Chaque lecteur est suivi séparément, y compris lorsque plusieurs personnes reçoivent les messages d’une structure.';
COMMENT ON COLUMN communication."T_ChatLecture"."IdChatFk" IS 'Identifiant du message suivi.';
COMMENT ON COLUMN communication."T_ChatLecture"."IdUserFk" IS 'Identifiant du compte qui a lu le message.';
COMMENT ON COLUMN communication."T_ChatLecture"."LuLe" IS 'Date et heure de la première lecture enregistrée par PostgreSQL.';
COMMENT ON CONSTRAINT "Pk_ChatLecture" ON communication."T_ChatLecture" IS 'Une seule lecture par message et par compte, y compris en cas de rejeu.';
COMMENT ON CONSTRAINT "Fk_ChatLecture_Chat" ON communication."T_ChatLecture" IS 'La lecture appartient à son message et disparaît si le message est supprimé physiquement.';
COMMENT ON CONSTRAINT "Fk_ChatLecture_Utilisateur" ON communication."T_ChatLecture" IS 'La lecture appartient à son compte et disparaît si le compte est supprimé physiquement.';

CREATE INDEX idx_chat_lecture_utilisateur ON communication."T_ChatLecture" ("IdUserFk", "IdChatFk");
CREATE INDEX idx_chat_suivi_discussion_message ON communication."T_Chat" ("IdDiscussionFk", "IdChat")
    INCLUDE ("AuthorIdFk") WHERE "SuiviLectureChat" IS TRUE;
COMMENT ON INDEX communication.idx_chat_lecture_utilisateur IS 'Accès aux messages lus par un compte et aux lectures concernées par une suppression du compte.';
COMMENT ON INDEX communication.idx_chat_suivi_discussion_message IS 'Recherche des nouveaux messages d’une discussion pour le calcul des non-lus.';

CREATE FUNCTION communication.fn_verifier_chat_lecture() RETURNS trigger
LANGUAGE plpgsql AS $lecture$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW."LuLe" IS DISTINCT FROM OLD."LuLe" THEN
            RAISE EXCEPTION 'La date de première lecture est conservée.'
                USING ERRCODE = '23514', CONSTRAINT = 'ck_chat_lecture_date_immuable';
        END IF;
        RETURN NEW;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM communication."T_Chat" c
        JOIN communication."T_Discussion" d ON d."IdDiscussion" = c."IdDiscussionFk"
        JOIN systeme."T_Utilisateurs" u ON u."IdUser" = NEW."IdUserFk"
        LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = u."IdEntiteFk"
        LEFT JOIN referentiel."T_Generique" r ON r."ID_Generique" = u."IdRoleFk"
        WHERE c."IdChat" = NEW."IdChatFk" AND c."SuiviLectureChat" IS TRUE
          AND c."AuthorIdFk" IS DISTINCT FROM u."IdUser"
          AND d."ValideDiscussion" IS TRUE AND u."ValideUser" IS TRUE
          AND (e."ValideEntite" IS DISTINCT FROM false OR u."Is_Admin" IS TRUE)
          AND (
              (d."TypeDiscussion" = 'user' AND d."IdEntiteFk" = u."IdEntiteFk"
                  AND u."IdUser" IN (d."IdUserClientFk", d."IdUserDestinataireFk"))
              OR (d."TypeDiscussion" IN ('expert', 'structure') AND d."IdUserClientFk" = u."IdUser")
              OR (d."TypeDiscussion" = 'expert' AND EXISTS (
                  SELECT 1 FROM professionnel."T_Professionnel" p
                  WHERE p."IdProfessionnel" = d."IdProfessionnelFk" AND p."IdUserFk" = u."IdUser"))
              OR (d."TypeDiscussion" = 'structure' AND d."IdEntiteFk" = u."IdEntiteFk"
                  AND (u."Is_Admin" IS TRUE OR u."Is_staff" IS TRUE
                       OR lower(r."NomGenerique") IN ('admin', 'administrateur')))
          )
    ) THEN
        RAISE EXCEPTION 'Ce message ne peut pas être marqué comme lu pour ce compte.'
            USING ERRCODE = '23514', CONSTRAINT = 'ck_chat_lecture_participant';
    END IF;

    NEW."LuLe" := clock_timestamp();
    RETURN NEW;
END
$lecture$;

CREATE TRIGGER tr_verifier_chat_lecture
BEFORE INSERT OR UPDATE OF "LuLe" ON communication."T_ChatLecture"
FOR EACH ROW EXECUTE FUNCTION communication.fn_verifier_chat_lecture();

COMMENT ON FUNCTION communication.fn_verifier_chat_lecture() IS 'Contrôle la participation du lecteur et conserve la date de première lecture. Exclut les propres messages et les messages historiques.';
COMMENT ON TRIGGER tr_verifier_chat_lecture ON communication."T_ChatLecture" IS 'Vérifie toute nouvelle lecture et empêche de modifier sa date.';

DO $droits$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sauverndeko_runtime') THEN
        REVOKE UPDATE, DELETE ON communication."T_ChatLecture" FROM sauverndeko_runtime;
    END IF;
END
$droits$;

CREATE OR REPLACE VIEW communication."V_Chat" AS
SELECT c."IdChat", c."TextChat", c."ChatFile", c."ChatLink", c."AuthorIdFk" AS "IdUser",
       c."IdDiscussionFk", c."DateChat", c."LuChat", u."NomUser", u."PrenomUser",
       u."EmailUser", e."IdEntite", e."NomEntite", c."SuiviLectureChat"
FROM communication."T_Chat" c
LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser" = c."AuthorIdFk"
LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = u."IdEntiteFk";

COMMENT ON COLUMN communication."V_Chat"."LuChat" IS 'Indicateur de lecture historique conservé pour compatibilité.';
COMMENT ON COLUMN communication."V_Chat"."SuiviLectureChat" IS 'Indique si le message peut entrer dans le suivi individuel des lectures.';
