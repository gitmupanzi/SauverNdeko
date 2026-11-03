-- Extrait canonique du catalogue vérifié le 02/11/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
--
-- Name: V_Professionnel_Detail; Type: VIEW; Schema: professionnel; Owner: -
--

CREATE VIEW professionnel."V_Professionnel_Detail" AS
 SELECT p."IdProfessionnel",
    p."IdUserFk",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    p."IdTypeProfessionnelFk",
    tp."NomGenerique" AS "TypeProfessionnel",
    p."IdSpecialiteFk",
    sp."NomGenerique" AS "Specialite",
    p."NumeroIdentification",
    p."ExperienceAns",
    p."ValideProfessionnel",
    u."PhoneUser",
    u."SexeUser",
    u."UrlPhoto"
   FROM (((professionnel."T_Professionnel" p
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = p."IdUserFk")))
     LEFT JOIN referentiel."T_Generique" tp ON ((tp."ID_Generique" = p."IdTypeProfessionnelFk")))
     LEFT JOIN referentiel."T_Generique" sp ON ((sp."ID_Generique" = p."IdSpecialiteFk")));

--
-- Name: VIEW "V_Professionnel_Detail"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON VIEW professionnel."V_Professionnel_Detail" IS 'Annuaire administratif au grain professionnel, avec coordonnées personnelles : réservé aux permissions administratives explicites.';

--
-- Name: COLUMN "V_Professionnel_Detail"."IdProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."IdProfessionnel" IS 'Identifiant du profil professionnel.';

--
-- Name: COLUMN "V_Professionnel_Detail"."IdUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "V_Professionnel_Detail"."NomUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."NomUser" IS 'Nom de l’utilisateur.';

--
-- Name: COLUMN "V_Professionnel_Detail"."PrenomUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."PrenomUser" IS 'Prénom de l’utilisateur.';

--
-- Name: COLUMN "V_Professionnel_Detail"."EmailUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion.';

--
-- Name: COLUMN "V_Professionnel_Detail"."IdTypeProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."IdTypeProfessionnelFk" IS 'Type du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "V_Professionnel_Detail"."TypeProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."TypeProfessionnel" IS 'Projection SQL de TypeProfessionnel ; lire le commentaire de la vue pour son grain et son périmètre.';

--
-- Name: COLUMN "V_Professionnel_Detail"."IdSpecialiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."IdSpecialiteFk" IS 'Spécialité du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "V_Professionnel_Detail"."Specialite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."Specialite" IS 'Projection SQL de Specialite ; lire le commentaire de la vue pour son grain et son périmètre.';

--
-- Name: COLUMN "V_Professionnel_Detail"."NumeroIdentification"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."NumeroIdentification" IS 'Numéro d’identification professionnel déclaré ; une chaîne vide est interdite si renseigné.';

--
-- Name: COLUMN "V_Professionnel_Detail"."ExperienceAns"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."ExperienceAns" IS 'Nombre d’années d’expérience déclaré pour le professionnel ; valeur négative interdite.';

--
-- Name: COLUMN "V_Professionnel_Detail"."ValideProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."ValideProfessionnel" IS 'Indique si le profil professionnel est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';

--
-- Name: COLUMN "V_Professionnel_Detail"."PhoneUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."PhoneUser" IS 'Téléphone utilisateur ; le trigger de normalisation conserve les chiffres sans interpréter le pays.';

--
-- Name: COLUMN "V_Professionnel_Detail"."SexeUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."SexeUser" IS 'Code de sexe enregistré pour le compte ; la contrainte actuelle admet M ou F.';

--
-- Name: COLUMN "V_Professionnel_Detail"."UrlPhoto"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."UrlPhoto" IS 'Référence de la photo de l’utilisateur.';

--
-- Name: V_Professionnel_Global; Type: VIEW; Schema: professionnel; Owner: -
--

CREATE VIEW professionnel."V_Professionnel_Global" AS
 SELECT p."IdProfessionnel",
    p."IdUserFk",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    u."PhoneUser",
    p."IdTypeProfessionnelFk",
    type_prof."NomGenerique" AS "TypeProfessionnel",
    p."IdSpecialiteFk",
    spec."NomGenerique" AS "Specialite",
    p."NumeroIdentification",
    p."ExperienceAns",
    p."ValideProfessionnel",
    p."ObsProfessionnel",
    pe."IdEntiteFk" AS "IdEntite",
    e."NomEntite",
    e."PhoneEntite",
    e."EmailEntite",
    pe."IdTypeLienFk",
    type_lien."NomGenerique" AS "TypeLien",
    pe."EstPrincipal",
    pe."DateDebut",
    pe."DateFin",
    pe."ObsLien",
    el."IdEntiteLocalisation",
    el."Latitude",
    el."Longitude",
    el."IdNiveau_3_Fk",
    el."IdNiveau_4_Fk",
    el."IdNiveau_5_Fk",
    el."AdresseDetaillee"
   FROM (((((((professionnel."T_Professionnel" p
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = p."IdUserFk")))
     JOIN professionnel."T_Professionnel_Entite" pe ON ((pe."IdProfessionnelFk" = p."IdProfessionnel")))
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = pe."IdEntiteFk")))
     LEFT JOIN systeme."T_Entite_Localisation" el ON ((el."IdEntiteFk" = e."IdEntite")))
     LEFT JOIN referentiel."T_Generique" type_prof ON ((type_prof."ID_Generique" = p."IdTypeProfessionnelFk")))
     LEFT JOIN referentiel."T_Generique" spec ON ((spec."ID_Generique" = p."IdSpecialiteFk")))
     LEFT JOIN referentiel."T_Generique" type_lien ON ((type_lien."ID_Generique" = pe."IdTypeLienFk")));

--
-- Name: VIEW "V_Professionnel_Global"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON VIEW professionnel."V_Professionnel_Global" IS 'Détail administratif au grain professionnel × affiliation × localisation ; plusieurs lignes peuvent correspondre à un professionnel. Ne pas sommer ce registre comme un effectif de professionnels.';

--
-- Name: COLUMN "V_Professionnel_Global"."IdProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdProfessionnel" IS 'Identifiant du profil professionnel.';

--
-- Name: COLUMN "V_Professionnel_Global"."IdUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "V_Professionnel_Global"."NomUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."NomUser" IS 'Nom de l’utilisateur.';

--
-- Name: COLUMN "V_Professionnel_Global"."PrenomUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."PrenomUser" IS 'Prénom de l’utilisateur.';

--
-- Name: COLUMN "V_Professionnel_Global"."EmailUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion.';

--
-- Name: COLUMN "V_Professionnel_Global"."PhoneUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."PhoneUser" IS 'Téléphone utilisateur ; le trigger de normalisation conserve les chiffres sans interpréter le pays.';

--
-- Name: COLUMN "V_Professionnel_Global"."IdTypeProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdTypeProfessionnelFk" IS 'Type du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "V_Professionnel_Global"."TypeProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."TypeProfessionnel" IS 'Projection SQL de TypeProfessionnel ; lire le commentaire de la vue pour son grain et son périmètre.';

--
-- Name: COLUMN "V_Professionnel_Global"."IdSpecialiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdSpecialiteFk" IS 'Spécialité du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "V_Professionnel_Global"."Specialite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."Specialite" IS 'Projection SQL de Specialite ; lire le commentaire de la vue pour son grain et son périmètre.';

--
-- Name: COLUMN "V_Professionnel_Global"."NumeroIdentification"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."NumeroIdentification" IS 'Numéro d’identification professionnel déclaré ; une chaîne vide est interdite si renseigné.';

--
-- Name: COLUMN "V_Professionnel_Global"."ExperienceAns"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."ExperienceAns" IS 'Nombre d’années d’expérience déclaré pour le professionnel ; valeur négative interdite.';

--
-- Name: COLUMN "V_Professionnel_Global"."ValideProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."ValideProfessionnel" IS 'Indique si le profil professionnel est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';

--
-- Name: COLUMN "V_Professionnel_Global"."ObsProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."ObsProfessionnel" IS 'Observations enregistrées sur le profil professionnel.';

--
-- Name: COLUMN "V_Professionnel_Global"."IdEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdEntite" IS 'Identifiant de l’entité.';

--
-- Name: COLUMN "V_Professionnel_Global"."NomEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."NomEntite" IS 'Nom de la structure ou organisation.';

--
-- Name: COLUMN "V_Professionnel_Global"."PhoneEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."PhoneEntite" IS 'Téléphone de contact de l’entité.';

--
-- Name: COLUMN "V_Professionnel_Global"."EmailEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."EmailEntite" IS 'Adresse électronique de contact de l’entité.';

--
-- Name: COLUMN "V_Professionnel_Global"."IdTypeLienFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdTypeLienFk" IS 'Type de relation entre professionnel et entité. Relation imposée : FOREIGN KEY ("IdTypeLienFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "V_Professionnel_Global"."TypeLien"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."TypeLien" IS 'Projection SQL de TypeLien ; lire le commentaire de la vue pour son grain et son périmètre.';

--
-- Name: COLUMN "V_Professionnel_Global"."EstPrincipal"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."EstPrincipal" IS 'Indique si ce rattachement professionnel est marqué comme principal.';

--
-- Name: COLUMN "V_Professionnel_Global"."DateDebut"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."DateDebut" IS 'Début du rattachement professionnel à l’entité.';

--
-- Name: COLUMN "V_Professionnel_Global"."DateFin"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."DateFin" IS 'Fin éventuelle du rattachement ; ne peut précéder DateDebut lorsque les deux dates sont renseignées.';

--
-- Name: COLUMN "V_Professionnel_Global"."ObsLien"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."ObsLien" IS 'Observations enregistrées sur le rattachement professionnel.';

--
-- Name: COLUMN "V_Professionnel_Global"."IdEntiteLocalisation"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdEntiteLocalisation" IS 'Identifiant de la localisation d’entité.';

--
-- Name: COLUMN "V_Professionnel_Global"."Latitude"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."Latitude" IS 'Latitude de la localisation ; coordonnée décimale.';

--
-- Name: COLUMN "V_Professionnel_Global"."Longitude"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."Longitude" IS 'Longitude de la localisation ; coordonnée décimale.';

--
-- Name: COLUMN "V_Professionnel_Global"."IdNiveau_3_Fk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdNiveau_3_Fk" IS 'Unité géographique de rattachement de niveau 3. Relation imposée : FOREIGN KEY ("IdNiveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3").';

--
-- Name: COLUMN "V_Professionnel_Global"."IdNiveau_4_Fk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdNiveau_4_Fk" IS 'Unité géographique de rattachement de niveau 4. Relation imposée : FOREIGN KEY ("IdNiveau_4_Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4").';

--
-- Name: COLUMN "V_Professionnel_Global"."IdNiveau_5_Fk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdNiveau_5_Fk" IS 'Unité géographique de rattachement de niveau 5. Relation imposée : FOREIGN KEY ("IdNiveau_5_Fk") REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5").';

--
-- Name: COLUMN "V_Professionnel_Global"."AdresseDetaillee"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."AdresseDetaillee" IS 'Adresse détaillée de cette localisation.';

--
-- Name: V_Professionnel_Par_Entite; Type: VIEW; Schema: professionnel; Owner: -
--

CREATE VIEW professionnel."V_Professionnel_Par_Entite" AS
 SELECT pe."IdProfessionnelFk",
    p."IdUserFk",
    u."NomUser",
    u."PrenomUser",
    p."IdTypeProfessionnelFk",
    tp."NomGenerique" AS "TypeProfessionnel",
    p."IdSpecialiteFk",
    sp."NomGenerique" AS "Specialite",
    pe."IdEntiteFk",
    e."NomEntite",
    e."PhoneEntite",
    e."EmailEntite",
    e."AdresseEntite",
    e."IdTypeEntiteFk",
    te."NomGenerique" AS "TypeEntite",
    pe."EstPrincipal",
    pe."DateDebut",
    pe."DateFin",
    pe."IdTypeLienFk",
    tl."NomGenerique" AS "TypeLien",
    p."ValideProfessionnel"
   FROM (((((((professionnel."T_Professionnel_Entite" pe
     JOIN professionnel."T_Professionnel" p ON ((p."IdProfessionnel" = pe."IdProfessionnelFk")))
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = p."IdUserFk")))
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = pe."IdEntiteFk")))
     LEFT JOIN referentiel."T_Generique" tp ON ((tp."ID_Generique" = p."IdTypeProfessionnelFk")))
     LEFT JOIN referentiel."T_Generique" sp ON ((sp."ID_Generique" = p."IdSpecialiteFk")))
     LEFT JOIN referentiel."T_Generique" te ON ((te."ID_Generique" = e."IdTypeEntiteFk")))
     LEFT JOIN referentiel."T_Generique" tl ON ((tl."ID_Generique" = pe."IdTypeLienFk")));

--
-- Name: VIEW "V_Professionnel_Par_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON VIEW professionnel."V_Professionnel_Par_Entite" IS 'Affiliations administratives au grain professionnel/entité ; les dates restent visibles, y compris pour les liens historiques.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."IdProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."IdProfessionnelFk" IS 'Professionnel rattaché à la discussion ou à l’entité. Relation imposée : FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE CASCADE.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."IdUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."NomUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."NomUser" IS 'Nom de l’utilisateur.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."PrenomUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."PrenomUser" IS 'Prénom de l’utilisateur.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."IdTypeProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."IdTypeProfessionnelFk" IS 'Type du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."TypeProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."TypeProfessionnel" IS 'Projection SQL de TypeProfessionnel ; lire le commentaire de la vue pour son grain et son périmètre.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."IdSpecialiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."IdSpecialiteFk" IS 'Spécialité du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."Specialite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."Specialite" IS 'Projection SQL de Specialite ; lire le commentaire de la vue pour son grain et son périmètre.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."IdEntiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."NomEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."NomEntite" IS 'Nom de la structure ou organisation.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."PhoneEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."PhoneEntite" IS 'Téléphone de contact de l’entité.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."EmailEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."EmailEntite" IS 'Adresse électronique de contact de l’entité.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."AdresseEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."AdresseEntite" IS 'Adresse générale enregistrée pour l’entité.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."IdTypeEntiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."IdTypeEntiteFk" IS 'Type de structure ou d’organisation dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeEntiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."TypeEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."TypeEntite" IS 'Projection SQL de TypeEntite ; lire le commentaire de la vue pour son grain et son périmètre.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."EstPrincipal"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."EstPrincipal" IS 'Indique si ce rattachement professionnel est marqué comme principal.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."DateDebut"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."DateDebut" IS 'Début du rattachement professionnel à l’entité.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."DateFin"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."DateFin" IS 'Fin éventuelle du rattachement ; ne peut précéder DateDebut lorsque les deux dates sont renseignées.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."IdTypeLienFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."IdTypeLienFk" IS 'Type de relation entre professionnel et entité. Relation imposée : FOREIGN KEY ("IdTypeLienFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."TypeLien"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."TypeLien" IS 'Projection SQL de TypeLien ; lire le commentaire de la vue pour son grain et son périmètre.';

--
-- Name: COLUMN "V_Professionnel_Par_Entite"."ValideProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."ValideProfessionnel" IS 'Indique si le profil professionnel est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';

--
-- Name: V_Professionnel_Public; Type: VIEW; Schema: professionnel; Owner: -
--

CREATE VIEW professionnel."V_Professionnel_Public" AS
 SELECT p."IdProfessionnel",
    p."ExperienceAns",
    p."ValideProfessionnel",
    jsonb_build_object('ID_Generique', sp."ID_Generique", 'NomGenerique', sp."NomGenerique", 'AbrGenerique', sp."AbrGenerique") AS "T_GeneriqueSpecialite",
    jsonb_build_object('ID_Generique', t."ID_Generique", 'NomGenerique', t."NomGenerique", 'AbrGenerique', t."AbrGenerique") AS "T_GeneriqueType",
    jsonb_build_object('IdUser', u."IdUser", 'NomUser', u."NomUser", 'PrenomUser', u."PrenomUser", 'UrlPhoto', u."UrlPhoto") AS "T_Utilisateurs",
    COALESCE(aff."Affiliations", '[]'::jsonb) AS "T_Professionnel_Entite",
    p."IdEntiteFk",
    e."NomEntite",
    p."IdSecteurFk",
    COALESCE(NULLIF((s."AbrGenerique")::text, ''::text), (s."NomGenerique")::text) AS "Secteur",
    p."TitrePublic",
    p."PresentationPublique",
    p."LocalitePublique",
    p."ContactAutorise",
    COALESCE(sk."Competences", '[]'::jsonb) AS "Competences",
    COALESCE(sv."Prestations", '[]'::jsonb) AS "Prestations",
    search."TexteRecherche",
    to_tsvector('simple'::regconfig, search."TexteRecherche") AS "RechercheVecteur",
    p."IdUserFk",
    p."IdSpecialiteFk",
    p."IdTypeProfessionnelFk",
    btrim(concat_ws(' '::text, u."PrenomUser", u."NomUser")) AS "NomComplet",
    jsonb_build_object('ID_Generique', s."ID_Generique", 'NomGenerique', s."NomGenerique", 'AbrGenerique', s."AbrGenerique") AS "T_GeneriqueSecteur"
   FROM (((((((((professionnel."T_Professionnel" p
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = p."IdUserFk")))
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = p."IdEntiteFk")))
     LEFT JOIN referentiel."T_Generique" s ON (((s."ID_Generique" = p."IdSecteurFk") AND s."ValideGenerique" AND referentiel.fn_reference_visible(s."ID_Generique", p."IdEntiteFk") AND (EXISTS ( SELECT
           FROM referentiel."T_CategorieGenerique" c
          WHERE ((c."ID_CategorieGenerique" = s."ID_CategorieGeneriqueFk") AND c."ValideCategorieGenerique"))))))
     LEFT JOIN referentiel."T_Generique" t ON (((t."ID_Generique" = p."IdTypeProfessionnelFk") AND t."ValideGenerique" AND referentiel.fn_reference_visible(t."ID_Generique", p."IdEntiteFk") AND (EXISTS ( SELECT
           FROM referentiel."T_CategorieGenerique" c
          WHERE ((c."ID_CategorieGenerique" = t."ID_CategorieGeneriqueFk") AND c."ValideCategorieGenerique"))))))
     LEFT JOIN referentiel."T_Generique" sp ON (((sp."ID_Generique" = p."IdSpecialiteFk") AND sp."ValideGenerique" AND referentiel.fn_reference_visible(sp."ID_Generique", p."IdEntiteFk") AND (EXISTS ( SELECT
           FROM referentiel."T_CategorieGenerique" c
          WHERE ((c."ID_CategorieGenerique" = sp."ID_CategorieGeneriqueFk") AND c."ValideCategorieGenerique"))))))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('EstPrincipal', l."EstPrincipal", 'T_Entite', jsonb_build_object('IdEntite', x."IdEntite", 'NomEntite', x."NomEntite", 'PhoneEntite', x."PhoneEntite", 'AdresseEntite', x."AdresseEntite")) ORDER BY l."EstPrincipal" DESC, l."IdEntiteFk") AS "Affiliations",
            string_agg(x."NomEntite", ' '::text) AS words
           FROM (professionnel."T_Professionnel_Entite" l
             JOIN systeme."T_Entite" x ON ((x."IdEntite" = l."IdEntiteFk")))
          WHERE ((l."IdProfessionnelFk" = p."IdProfessionnel") AND x."ValideEntite" AND ((l."DateDebut" IS NULL) OR (l."DateDebut" <= LOCALTIMESTAMP)) AND ((l."DateFin" IS NULL) OR (l."DateFin" > LOCALTIMESTAMP)))) aff ON (true))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('ID_Generique', g."ID_Generique", 'NomGenerique', g."NomGenerique", 'AbrGenerique', g."AbrGenerique") ORDER BY g."NomGenerique", g."ID_Generique") AS "Competences",
            string_agg(concat_ws(' '::text, g."NomGenerique", g."AbrGenerique", syn.words), ' '::text) AS words
           FROM (((professionnel."T_Professionnel_Competence" l
             JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = l."IdCompetenceFk")))
             JOIN referentiel."T_CategorieGenerique" c ON ((c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk")))
             LEFT JOIN LATERAL ( SELECT string_agg(z."Terme", ' '::text) AS words
                   FROM professionnel."T_SynonymeRecherche" z
                  WHERE ((z."IdGeneriqueFk" = g."ID_Generique") AND z."Actif" AND ((z."IdEntiteFk" IS NULL) OR (z."IdEntiteFk" = p."IdEntiteFk")))) syn ON (true))
          WHERE ((l."IdProfessionnelFk" = p."IdProfessionnel") AND g."ValideGenerique" AND c."ValideCategorieGenerique" AND referentiel.fn_reference_visible(g."ID_Generique", p."IdEntiteFk"))) sk ON (true))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('ID_Generique', g."ID_Generique", 'NomGenerique', g."NomGenerique", 'AbrGenerique', g."AbrGenerique") ORDER BY g."NomGenerique", g."ID_Generique") AS "Prestations",
            string_agg(concat_ws(' '::text, g."NomGenerique", g."AbrGenerique", syn.words), ' '::text) AS words
           FROM (((professionnel."T_Professionnel_Prestation" l
             JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = l."IdPrestationFk")))
             JOIN referentiel."T_CategorieGenerique" c ON ((c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk")))
             LEFT JOIN LATERAL ( SELECT string_agg(z."Terme", ' '::text) AS words
                   FROM professionnel."T_SynonymeRecherche" z
                  WHERE ((z."IdGeneriqueFk" = g."ID_Generique") AND z."Actif" AND ((z."IdEntiteFk" IS NULL) OR (z."IdEntiteFk" = p."IdEntiteFk")))) syn ON (true))
          WHERE ((l."IdProfessionnelFk" = p."IdProfessionnel") AND g."ValideGenerique" AND c."ValideCategorieGenerique" AND referentiel.fn_reference_visible(g."ID_Generique", p."IdEntiteFk"))) sv ON (true))
     CROSS JOIN LATERAL ( SELECT referentiel.fn_normaliser_libelle(concat_ws(' '::text, u."NomUser", u."PrenomUser", p."TitrePublic", p."PresentationPublique", p."LocalitePublique", s."NomGenerique", s."AbrGenerique", t."NomGenerique", t."AbrGenerique", sp."NomGenerique", sp."AbrGenerique", sk.words, sv.words, aff.words)) AS "TexteRecherche") search)
  WHERE (p."Publie" AND p."ValideProfessionnel" AND u."ValideUser" AND e."ValideEntite");

--
-- Name: VIEW "V_Professionnel_Public"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON VIEW professionnel."V_Professionnel_Public" IS 'Annuaire transversal publié, actif et lié à un compte/entreprise actifs, une ligne par fiche. Compétences et prestations déclarées, affiliations valables ; sans email/téléphone personnel, numéro professionnel privé, note interne ni donnée RH. Les synonymes appartiennent à la valeur sélectionnée, jamais à un expert supposé.';

--
-- Name: COLUMN "V_Professionnel_Public"."IdProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."IdProfessionnel" IS 'Clé du professionnel public actif, une ligne par professionnel.';

--
-- Name: COLUMN "V_Professionnel_Public"."ExperienceAns"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."ExperienceAns" IS 'Expérience en années déclarée par le professionnel.';

--
-- Name: COLUMN "V_Professionnel_Public"."ValideProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."ValideProfessionnel" IS 'Vrai pour chaque professionnel de cette projection publique filtrée.';

--
-- Name: COLUMN "V_Professionnel_Public"."T_GeneriqueSpecialite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."T_GeneriqueSpecialite" IS 'Spécialité publique sous forme JSON : identifiant, nom et abréviation du référentiel.';

--
-- Name: COLUMN "V_Professionnel_Public"."T_GeneriqueType"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."T_GeneriqueType" IS 'Type professionnel public sous forme JSON : identifiant, nom et abréviation.';

--
-- Name: COLUMN "V_Professionnel_Public"."T_Utilisateurs"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."T_Utilisateurs" IS 'Identité publique JSON limitée à IdUser, NomUser, PrenomUser et UrlPhoto ; sans email, téléphone personnel ni mot de passe.';

--
-- Name: COLUMN "V_Professionnel_Public"."T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."T_Professionnel_Entite" IS 'Affiliations vers les structures actives, valables à la date de lecture ; tri principal puis identifiant, tableau JSON vide si aucune.';

--
-- Name: COLUMN "V_Professionnel_Public"."IdEntiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."IdEntiteFk" IS 'Projection publique limitée : IdEntiteFk. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."NomEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."NomEntite" IS 'Projection publique limitée : NomEntite. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."IdSecteurFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."IdSecteurFk" IS 'Projection publique limitée : IdSecteurFk. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."Secteur"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."Secteur" IS 'Projection publique limitée : Secteur. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."TitrePublic"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."TitrePublic" IS 'Projection publique limitée : TitrePublic. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."PresentationPublique"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."PresentationPublique" IS 'Projection publique limitée : PresentationPublique. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."LocalitePublique"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."LocalitePublique" IS 'Projection publique limitée : LocalitePublique. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."ContactAutorise"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."ContactAutorise" IS 'Projection publique limitée : ContactAutorise. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."Competences"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."Competences" IS 'Projection publique limitée : Competences. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."Prestations"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."Prestations" IS 'Projection publique limitée : Prestations. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."TexteRecherche"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."TexteRecherche" IS 'Projection publique limitée : TexteRecherche. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."RechercheVecteur"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."RechercheVecteur" IS 'Projection publique limitée : RechercheVecteur. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."IdUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."IdUserFk" IS 'Projection publique limitée : IdUserFk. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."IdSpecialiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."IdSpecialiteFk" IS 'Projection publique limitée : IdSpecialiteFk. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."IdTypeProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."IdTypeProfessionnelFk" IS 'Projection publique limitée : IdTypeProfessionnelFk. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."NomComplet"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."NomComplet" IS 'Projection publique limitée : NomComplet. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Public"."T_GeneriqueSecteur"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."T_GeneriqueSecteur" IS 'Projection publique limitée : T_GeneriqueSecteur. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: V_Professionnel_Registre; Type: VIEW; Schema: professionnel; Owner: -
--

CREATE VIEW professionnel."V_Professionnel_Registre" AS
 SELECT p."IdProfessionnel",
    p."IdUserFk",
    p."IdTypeProfessionnelFk",
    p."IdSpecialiteFk",
    p."NumeroIdentification",
    p."ExperienceAns",
    p."ObsProfessionnel",
    p."ValideProfessionnel",
    p."IdEntiteFk",
    p."IdSecteurFk",
    p."TitrePublic",
    p."PresentationPublique",
    p."LocalitePublique",
    p."ContactAutorise",
    p."Publie",
    p."Revision",
    p."CreeLe",
    p."ModifieLe",
    p."CreeParUserFk",
    p."ModifieParUserFk",
    p."CreationRequestId",
    p."CreationPayloadHash",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    u."UrlPhoto",
    u."ValideUser",
    btrim(concat_ws(' '::text, u."PrenomUser", u."NomUser")) AS "NomComplet",
    e."NomEntite",
    COALESCE(NULLIF((s."AbrGenerique")::text, ''::text), (s."NomGenerique")::text) AS "Secteur",
    COALESCE(NULLIF((t."AbrGenerique")::text, ''::text), (t."NomGenerique")::text) AS "TypeProfessionnel",
    COALESCE(NULLIF((sp."AbrGenerique")::text, ''::text), (sp."NomGenerique")::text) AS "Specialite",
    COALESCE(c."Competences", '[]'::jsonb) AS "Competences",
    COALESCE(pr."Prestations", '[]'::jsonb) AS "Prestations",
    COALESCE(a."Affiliations", '[]'::jsonb) AS "Affiliations",
    COALESCE(c."NbCompetences", (0)::bigint) AS "NbCompetences",
    COALESCE(pr."NbPrestations", (0)::bigint) AS "NbPrestations",
        CASE
            WHEN (NOT COALESCE(p."ValideProfessionnel", false)) THEN 'archive'::text
            WHEN p."Publie" THEN 'publie'::text
            ELSE 'brouillon'::text
        END AS "EtatProfil",
    jsonb_build_object('ID_Generique', s."ID_Generique", 'NomGenerique', s."NomGenerique", 'AbrGenerique', s."AbrGenerique") AS "T_GeneriqueSecteur",
    jsonb_build_object('ID_Generique', sp."ID_Generique", 'NomGenerique', sp."NomGenerique", 'AbrGenerique', sp."AbrGenerique") AS "T_GeneriqueSpecialite",
    jsonb_build_object('ID_Generique', t."ID_Generique", 'NomGenerique', t."NomGenerique", 'AbrGenerique', t."AbrGenerique") AS "T_GeneriqueType",
    jsonb_build_object('IdUser', u."IdUser", 'NomUser', u."NomUser", 'PrenomUser', u."PrenomUser", 'UrlPhoto', u."UrlPhoto") AS "T_Utilisateurs",
    search."TexteRecherche",
    to_tsvector('simple'::regconfig, search."TexteRecherche") AS "RechercheVecteur"
   FROM (((((((((professionnel."T_Professionnel" p
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = p."IdUserFk")))
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = p."IdEntiteFk")))
     LEFT JOIN referentiel."T_Generique" s ON ((s."ID_Generique" = p."IdSecteurFk")))
     LEFT JOIN referentiel."T_Generique" t ON ((t."ID_Generique" = p."IdTypeProfessionnelFk")))
     LEFT JOIN referentiel."T_Generique" sp ON ((sp."ID_Generique" = p."IdSpecialiteFk")))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('ID_Generique', g."ID_Generique", 'NomGenerique', g."NomGenerique", 'AbrGenerique', g."AbrGenerique") ORDER BY g."NomGenerique", g."ID_Generique") AS "Competences",
            count(*) AS "NbCompetences"
           FROM (professionnel."T_Professionnel_Competence" l
             JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = l."IdCompetenceFk")))
          WHERE (l."IdProfessionnelFk" = p."IdProfessionnel")) c ON (true))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('ID_Generique', g."ID_Generique", 'NomGenerique', g."NomGenerique", 'AbrGenerique', g."AbrGenerique") ORDER BY g."NomGenerique", g."ID_Generique") AS "Prestations",
            count(*) AS "NbPrestations"
           FROM (professionnel."T_Professionnel_Prestation" l
             JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = l."IdPrestationFk")))
          WHERE (l."IdProfessionnelFk" = p."IdProfessionnel")) pr ON (true))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('IdEntiteFk', l."IdEntiteFk", 'NomEntite', x."NomEntite", 'IdTypeLienFk', l."IdTypeLienFk", 'EstPrincipal', l."EstPrincipal", 'DateDebut', l."DateDebut", 'DateFin', l."DateFin", 'ObsLien', l."ObsLien") ORDER BY l."EstPrincipal" DESC, l."IdEntiteFk") AS "Affiliations"
           FROM (professionnel."T_Professionnel_Entite" l
             JOIN systeme."T_Entite" x ON ((x."IdEntite" = l."IdEntiteFk")))
          WHERE (l."IdProfessionnelFk" = p."IdProfessionnel")) a ON (true))
     CROSS JOIN LATERAL ( SELECT referentiel.fn_normaliser_libelle(concat_ws(' '::text, u."NomUser", u."PrenomUser", p."TitrePublic", p."PresentationPublique", p."LocalitePublique", s."NomGenerique", t."NomGenerique", sp."NomGenerique", (c."Competences")::text, (pr."Prestations")::text, (a."Affiliations")::text)) AS "TexteRecherche") search);

--
-- Name: VIEW "V_Professionnel_Registre"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON VIEW professionnel."V_Professionnel_Registre" IS 'Registre privé, une ligne par fiche propriétaire ; informations compte minimales, références et détails agrégés. Réservé aux services autorisés, jamais SELECT * dans une réponse publique.';

--
-- Name: COLUMN "V_Professionnel_Registre"."IdProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."IdProfessionnel" IS 'Projection privée du registre autorisé : IdProfessionnel. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."IdUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."IdUserFk" IS 'Projection privée du registre autorisé : IdUserFk. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."IdTypeProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."IdTypeProfessionnelFk" IS 'Projection privée du registre autorisé : IdTypeProfessionnelFk. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."IdSpecialiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."IdSpecialiteFk" IS 'Projection privée du registre autorisé : IdSpecialiteFk. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."NumeroIdentification"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."NumeroIdentification" IS 'Projection privée du registre autorisé : NumeroIdentification. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."ExperienceAns"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."ExperienceAns" IS 'Projection privée du registre autorisé : ExperienceAns. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."ObsProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."ObsProfessionnel" IS 'Projection privée du registre autorisé : ObsProfessionnel. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."ValideProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."ValideProfessionnel" IS 'Projection privée du registre autorisé : ValideProfessionnel. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."IdEntiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."IdEntiteFk" IS 'Projection privée du registre autorisé : IdEntiteFk. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."IdSecteurFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."IdSecteurFk" IS 'Projection privée du registre autorisé : IdSecteurFk. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."TitrePublic"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."TitrePublic" IS 'Projection privée du registre autorisé : TitrePublic. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."PresentationPublique"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."PresentationPublique" IS 'Projection privée du registre autorisé : PresentationPublique. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."LocalitePublique"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."LocalitePublique" IS 'Projection privée du registre autorisé : LocalitePublique. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."ContactAutorise"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."ContactAutorise" IS 'Projection privée du registre autorisé : ContactAutorise. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."Publie"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."Publie" IS 'Projection privée du registre autorisé : Publie. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."Revision"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."Revision" IS 'Projection privée du registre autorisé : Revision. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."CreeLe"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."CreeLe" IS 'Projection privée du registre autorisé : CreeLe. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."ModifieLe"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."ModifieLe" IS 'Projection privée du registre autorisé : ModifieLe. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."CreeParUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."CreeParUserFk" IS 'Projection privée du registre autorisé : CreeParUserFk. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."ModifieParUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."ModifieParUserFk" IS 'Projection privée du registre autorisé : ModifieParUserFk. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."CreationRequestId"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."CreationRequestId" IS 'Projection privée du registre autorisé : CreationRequestId. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."CreationPayloadHash"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."CreationPayloadHash" IS 'Projection privée du registre autorisé : CreationPayloadHash. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."NomUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."NomUser" IS 'Projection privée du registre autorisé : NomUser. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."PrenomUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."PrenomUser" IS 'Projection privée du registre autorisé : PrenomUser. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."EmailUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."EmailUser" IS 'Projection privée du registre autorisé : EmailUser. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."UrlPhoto"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."UrlPhoto" IS 'Projection privée du registre autorisé : UrlPhoto. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."ValideUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."ValideUser" IS 'Projection privée du registre autorisé : ValideUser. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."NomComplet"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."NomComplet" IS 'Projection privée du registre autorisé : NomComplet. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."NomEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."NomEntite" IS 'Projection privée du registre autorisé : NomEntite. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."Secteur"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."Secteur" IS 'Projection privée du registre autorisé : Secteur. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."TypeProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."TypeProfessionnel" IS 'Projection privée du registre autorisé : TypeProfessionnel. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."Specialite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."Specialite" IS 'Projection privée du registre autorisé : Specialite. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."Competences"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."Competences" IS 'Projection privée du registre autorisé : Competences. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."Prestations"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."Prestations" IS 'Projection privée du registre autorisé : Prestations. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."Affiliations"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."Affiliations" IS 'Projection privée du registre autorisé : Affiliations. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."NbCompetences"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."NbCompetences" IS 'Projection privée du registre autorisé : NbCompetences. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."NbPrestations"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."NbPrestations" IS 'Projection privée du registre autorisé : NbPrestations. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."EtatProfil"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."EtatProfil" IS 'Projection privée du registre autorisé : EtatProfil. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."T_GeneriqueSecteur"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."T_GeneriqueSecteur" IS 'Projection privée du registre autorisé : T_GeneriqueSecteur. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."T_GeneriqueSpecialite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."T_GeneriqueSpecialite" IS 'Projection privée du registre autorisé : T_GeneriqueSpecialite. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."T_GeneriqueType"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."T_GeneriqueType" IS 'Projection privée du registre autorisé : T_GeneriqueType. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."T_Utilisateurs"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."T_Utilisateurs" IS 'Projection privée du registre autorisé : T_Utilisateurs. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."TexteRecherche"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."TexteRecherche" IS 'Projection privée du registre autorisé : TexteRecherche. Issue de la fiche et de ses références centrales, sans effet sur les droits.';

--
-- Name: COLUMN "V_Professionnel_Registre"."RechercheVecteur"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Registre"."RechercheVecteur" IS 'Projection privée du registre autorisé : RechercheVecteur. Issue de la fiche et de ses références centrales, sans effet sur les droits.';
