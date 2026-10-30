-- Extrait canonique du catalogue installé le 30/10/2026, sans données ni propriétaires imposés.
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
    jsonb_build_object('ID_Generique', s."ID_Generique", 'NomGenerique', s."NomGenerique", 'AbrGenerique', s."AbrGenerique") AS "T_GeneriqueSpecialite",
    jsonb_build_object('ID_Generique', t."ID_Generique", 'NomGenerique', t."NomGenerique", 'AbrGenerique', t."AbrGenerique") AS "T_GeneriqueType",
    jsonb_build_object('IdUser', u."IdUser", 'NomUser', u."NomUser", 'PrenomUser', u."PrenomUser", 'UrlPhoto', u."UrlPhoto") AS "T_Utilisateurs",
    COALESCE(( SELECT jsonb_agg(jsonb_build_object('EstPrincipal', l."EstPrincipal", 'T_Entite', jsonb_build_object('IdEntite', e."IdEntite", 'NomEntite', e."NomEntite", 'PhoneEntite', e."PhoneEntite", 'AdresseEntite', e."AdresseEntite")) ORDER BY l."EstPrincipal" DESC, l."IdEntiteFk") AS jsonb_agg
           FROM (professionnel."T_Professionnel_Entite" l
             JOIN systeme."T_Entite" e ON ((e."IdEntite" = l."IdEntiteFk")))
          WHERE ((l."IdProfessionnelFk" = p."IdProfessionnel") AND (e."ValideEntite" = true) AND ((l."DateDebut" IS NULL) OR (l."DateDebut" <= CURRENT_TIMESTAMP)) AND ((l."DateFin" IS NULL) OR (l."DateFin" > CURRENT_TIMESTAMP)))), '[]'::jsonb) AS "T_Professionnel_Entite"
   FROM (((professionnel."T_Professionnel" p
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = p."IdUserFk")))
     LEFT JOIN referentiel."T_Generique" s ON ((s."ID_Generique" = p."IdSpecialiteFk")))
     LEFT JOIN referentiel."T_Generique" t ON ((t."ID_Generique" = p."IdTypeProfessionnelFk")))
  WHERE ((p."ValideProfessionnel" = true) AND (u."ValideUser" = true));

--
-- Name: VIEW "V_Professionnel_Public"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON VIEW professionnel."V_Professionnel_Public" IS 'Annuaire public au grain professionnel actif et utilisateur actif. Identité, spécialité et affiliations valables à la date de lecture ; aucun email, téléphone personnel, numéro professionnel ou mot de passe. Les affiliations sont agrégées pour éviter de dupliquer les professionnels.';

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
