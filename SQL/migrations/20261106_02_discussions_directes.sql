ALTER TABLE communication."T_Discussion"
    ADD COLUMN "IdUserDestinataireFk" integer
        REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL,
    DROP CONSTRAINT "Ck_Discussion_Target",
    DROP CONSTRAINT "Ck_Discussion_Type",
    ADD CONSTRAINT "Ck_Discussion_Type" CHECK ("TypeDiscussion" IN ('expert', 'structure', 'user')),
    ADD CONSTRAINT "Ck_Discussion_Target" CHECK (
        ("TypeDiscussion" = 'expert' AND "IdProfessionnelFk" IS NOT NULL
            AND "IdEntiteFk" IS NULL AND "IdUserDestinataireFk" IS NULL)
        OR ("TypeDiscussion" = 'structure' AND "IdEntiteFk" IS NOT NULL
            AND "IdProfessionnelFk" IS NULL AND "IdUserDestinataireFk" IS NULL)
        OR ("TypeDiscussion" = 'user' AND "IdProfessionnelFk" IS NULL
            AND ("IdUserClientFk" IS NULL OR "IdUserDestinataireFk" IS NULL
                 OR "IdUserClientFk" <> "IdUserDestinataireFk"))
    );

COMMENT ON TABLE communication."T_Discussion" IS 'Un fil privé par échange avec un compte, un professionnel ou une structure. Les deux comptes d’un fil direct sont ses seuls participants.';
COMMENT ON COLUMN communication."T_Discussion"."IdUserDestinataireFk" IS 'Second compte participant à un fil direct. Absent pour les fils professionnels et structures ou si le compte a été supprimé.';
COMMENT ON COLUMN communication."T_Discussion"."IdEntiteFk" IS 'Structure destinataire pour un fil structure. Entreprise commune à la création pour un fil direct.';
COMMENT ON COLUMN communication."T_Discussion"."TypeDiscussion" IS 'Canal privé : expert, structure ou user. Le canal détermine les clés de rattachement.';
COMMENT ON CONSTRAINT "Ck_Discussion_Type" ON communication."T_Discussion" IS 'Limite les fils privés aux trois canaux gérés.';
COMMENT ON CONSTRAINT "Ck_Discussion_Target" ON communication."T_Discussion" IS 'Contrôle la forme du destinataire et interdit de s’écrire à soi-même. Un compte supprimé ne fait pas disparaître l’historique.';

CREATE UNIQUE INDEX uq_discussion_directe_entreprise ON communication."T_Discussion" (
    "IdEntiteFk", LEAST("IdUserClientFk", "IdUserDestinataireFk"),
    GREATEST("IdUserClientFk", "IdUserDestinataireFk")
)
WHERE "TypeDiscussion" = 'user' AND "ValideDiscussion"
    AND "IdUserClientFk" IS NOT NULL AND "IdUserDestinataireFk" IS NOT NULL;

CREATE INDEX idx_discussion_user_destinataire ON communication."T_Discussion" ("IdUserDestinataireFk")
WHERE "IdUserDestinataireFk" IS NOT NULL;

COMMENT ON INDEX communication.uq_discussion_directe_entreprise IS 'Un seul fil direct actif par paire de comptes et entreprise, dans les deux sens.';
COMMENT ON INDEX communication.idx_discussion_user_destinataire IS 'Accès aux fils directs du second participant.';

CREATE FUNCTION communication.fn_verifier_creation_discussion_directe() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    membres integer;
BEGIN
    SELECT count(*) INTO membres FROM (
        SELECT u."IdUser"
        FROM systeme."T_Utilisateurs" u
        JOIN systeme."T_Entite" e ON e."IdEntite" = u."IdEntiteFk"
        WHERE u."IdUser" IN (NEW."IdUserClientFk", NEW."IdUserDestinataireFk")
            AND u."IdEntiteFk" = NEW."IdEntiteFk"
            AND u."ValideUser" IS TRUE AND e."ValideEntite" IS TRUE
        ORDER BY u."IdUser" FOR SHARE OF u, e
    ) actifs;
    IF membres <> 2 THEN
        RAISE EXCEPTION 'Les deux participants doivent appartenir à la même entreprise active.'
            USING ERRCODE = '23514', CONSTRAINT = 'ck_discussion_directe_membres';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER tr_verifier_creation_discussion_directe
BEFORE INSERT ON communication."T_Discussion"
FOR EACH ROW WHEN (NEW."TypeDiscussion" = 'user')
EXECUTE FUNCTION communication.fn_verifier_creation_discussion_directe();

COMMENT ON FUNCTION communication.fn_verifier_creation_discussion_directe() IS 'Vérifie les deux comptes et leur entreprise à la création du fil direct, même pour un autre producteur SQL.';
COMMENT ON TRIGGER tr_verifier_creation_discussion_directe ON communication."T_Discussion" IS 'Refuse la création d’un fil direct hors de l’entreprise des deux comptes actifs.';

ALTER TABLE communication."T_Chat" ADD COLUMN "CleRequeteChat" uuid;

CREATE UNIQUE INDEX uq_chat_requete_auteur_discussion ON communication."T_Chat"
    ("IdDiscussionFk", "AuthorIdFk", "CleRequeteChat") WHERE "CleRequeteChat" IS NOT NULL;

COMMENT ON COLUMN communication."T_Chat"."CleRequeteChat" IS 'Clé de rejeu facultative d’un envoi, propre au fil et à son auteur. Les anciens messages n’en ont pas.';
COMMENT ON INDEX communication.uq_chat_requete_auteur_discussion IS 'Empêche de dupliquer un envoi après une réponse réseau incertaine.';

CREATE VIEW communication."V_DiscussionBoite" AS
SELECT d.*,
    btrim(concat_ws(' ', initiateur."PrenomUser", initiateur."NomUser")) AS "NomInitiateur",
    btrim(concat_ws(' ', cible."PrenomUser", cible."NomUser")) AS "NomDestinataire",
    p."IdUserFk" AS "IdCompteProfessionnel",
    btrim(concat_ws(' ', expert."PrenomUser", expert."NomUser")) AS "NomProfessionnel",
    NULLIF(btrim(s."AbrGenerique"), '') AS "SpecialiteProfessionnel",
    e."NomEntite" AS "NomStructure",
    m."DernierMessage"
FROM communication."T_Discussion" d
LEFT JOIN systeme."T_Utilisateurs" initiateur ON initiateur."IdUser" = d."IdUserClientFk"
LEFT JOIN systeme."T_Utilisateurs" cible ON cible."IdUser" = d."IdUserDestinataireFk"
LEFT JOIN professionnel."T_Professionnel" p ON p."IdProfessionnel" = d."IdProfessionnelFk"
LEFT JOIN systeme."T_Utilisateurs" expert ON expert."IdUser" = p."IdUserFk"
LEFT JOIN referentiel."T_Generique" s ON s."ID_Generique" = p."IdSpecialiteFk"
LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = d."IdEntiteFk"
LEFT JOIN LATERAL (
    SELECT jsonb_build_object(
        'IdChat', c."IdChat", 'TextChat', c."TextChat", 'DateChat', c."DateChat",
        'ChatFile', c."ChatFile", 'ChatLink', c."ChatLink", 'LuChat', c."LuChat",
        'author', jsonb_build_object('IdUser', c."IdUser", 'NomUser', c."NomUser", 'PrenomUser', c."PrenomUser")
    ) AS "DernierMessage"
    FROM communication."V_Chat" c
    WHERE c."IdDiscussionFk" = d."IdDiscussion"
    ORDER BY c."DateChat" DESC, c."IdChat" DESC LIMIT 1
) m ON true;

COMMENT ON VIEW communication."V_DiscussionBoite" IS 'Une ligne par fil privé, avec identités minimales et dernier message. Réservée aux lectures serveur après contrôle du participant.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."IdDiscussion" IS 'Identifiant du fil privé.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."IdUserClientFk" IS 'Compte qui a initié le fil.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."IdProfessionnelFk" IS 'Profil visé par le fil professionnel.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."IdEntiteFk" IS 'Structure destinataire ou entreprise de création du fil direct.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."TypeDiscussion" IS 'Canal du fil privé.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."SujetDiscussion" IS 'Sujet historique du fil.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."DateCreation" IS 'Date de création du fil.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."DernierMessageAt" IS 'Date du dernier message, tenue par le trigger existant.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."ValideDiscussion" IS 'Fil actif et consultable par ses participants.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."IdUserDestinataireFk" IS 'Compte destinataire d’un fil direct.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."NomInitiateur" IS 'Nom d’affichage du compte initiateur.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."NomDestinataire" IS 'Nom d’affichage du second participant d’un fil direct.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."IdCompteProfessionnel" IS 'Compte qui porte le profil professionnel ciblé.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."NomProfessionnel" IS 'Nom du correspondant professionnel, sans coordonnées privées.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."SpecialiteProfessionnel" IS 'Abréviation de la spécialité du professionnel dans le référentiel.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."NomStructure" IS 'Nom de la structure rattachée au fil.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."DernierMessage" IS 'Aperçu du dernier message et identité minimale de son auteur.';
