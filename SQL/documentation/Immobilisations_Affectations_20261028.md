# Patrimoine et affectations professionnelles

La migration `20261028_08_immobilisations_affectations.sql` est installée dans SauverNdeko après sauvegarde, recette privée et comparaison des 67 tables antérieures. Les anciennes données métier et colonnes utilisateur restent conservées ; les nouvelles données RH restent NULL et aucun bien fictif n’est créé dans l’instance. Elle n’est jamais appliquée pendant le démarrage de l’application ; son rejeu ou un état partiel sont refusés.

## Registre des biens

`logistique.T_Immobilisation` conserve les équipements appartenant à une entreprise. Son identifiant, l’entreprise propriétaire, son code automatique `IMMO-ID` et les informations techniques de création sont immuables. Une fiche individuelle a une quantité de1. Un groupe homogène exige `SuiviIndividuel=false` explicitement et partage caractéristiques, état, responsable, service et localisation. Un numéro de série renseigné impose toujours une seule pièce.

La quantité est un nombre entier exact de 1 à 18 chiffres. Une colonne numeric sans typmod et un CHECK explicite refusent les fractions ; numeric(18,0) les aurait arrondies avant le contrôle. Le prix unitaire d’acquisition est facultatif, non négatif et conservé à deux décimales ; NULL signifie inconnu, tandis que zéro est un coût connu nul. Une devise du référentiel est obligatoire dès qu’un prix est présent. La valeur SQL vaut quantité × prix unitaire, arrondie à deux décimales ; elle reste NULL si le prix est inconnu.

Ce registre ne crée ni article commercial, bon, mouvement, lot, réserve, valorisation CUMP, amortissement ou écriture comptable. La classification comptable et les amortissements restent des sujets distincts. Une fiche se conserve par archivage/restauration ; sa suppression physique est refusée.

| Donnée | Contrat |
|---|---|
| Désignation | Obligatoire, 200 caractères au maximum, sans contrôles ni espaces extérieurs. |
| Référence, numéro de série | Facultatifs, 255 caractères chacun. |
| Caractéristiques, observations | Facultatives, 4000 caractères chacune, LF/CRLF autorisés. |
| Date d’entrée | Date et heure obligatoires, finies ; date serveur proposée par défaut. |
| Date d’acquisition | Date facultative, distincte des dates techniques. |
| État | Facultatif ; aucun bon état supposé à la création. |
| Localisation complémentaire | Salle, bureau ou précision facultative, 255 caractères. |
| Actif | true par défaut ; false conserve la fiche dans les archives. |

`V_Immobilisation` projette le registre, les libellés joints et `ValeurAcquisition`. `_version` est la révision opaque xmin. Les jointures LEFT conservent une fiche dont un champ optionnel est absent. Le service impose le périmètre d’entreprise avant lecture, recherche, historique ou export.

## Références et propriétaires

Le référentiel partagé reçoit la famille **Type de matériel** avec cinq valeurs initiales : Informatique, Mobilier, Équipement, Véhicule et Autre. La famille **Etat** existante est conservée et reçoit **Hors usage** si cette valeur manque. Service, Fonction et Devise sont réutilisés. Aucun identifiant de catégorie du serveur source n’est copié dans le code.

Trois correspondances globales sont ajoutées dans `systeme.T_Fk_Correspondance` :

- `logistique.immobilisations.categories` pour `ID_CategorieFk` ;
- `logistique.immobilisations.etats` pour `ID_EtatFk` ;
- `logistique.immobilisations.services` pour `ID_ServiceFk`.

Pour une nouvelle affectation, la garde SQL résout les correspondances actives de l’entreprise en priorité, puis les globales. La liste et la validation partagent ainsi le réglage. Changer une correspondance ne réécrit pas les références historiques déjà affectées. Une référence nouvellement choisie doit être active ; une ancienne référence désactivée reste consultable.

Le responsable est un utilisateur de la même entreprise, actif et affectable selon ses dates professionnelles. Une ancienne affectation est conservée si ce compte est ensuite désactivé. Le service du bien est explicite : modifier le service professionnel d’un utilisateur ne déplace pas automatiquement son matériel. Le changement d’entreprise d’un responsable est refusé tant qu’un bien, y compris archivé, lui reste lié.

`ID_LocalisationFk` référence exclusivement `systeme.T_Entite_Localisation` de la même entreprise. Le libellé `Localisation` est joint depuis `V_Entite_Localisation_Detail`, avec adresse et niveaux géographiques ; le complément libre précise salle ou bureau. La table des lieux ne possédant aucun état d’archive, aucun drapeau fictif n’est ajouté. Un lieu lié ne peut pas changer de propriétaire et sa suppression est refusée par FK RESTRICT.

## Métadonnées professionnelles minimales

Six colonnes facultatives sont ajoutées à `systeme.T_Utilisateurs` : `MatriculeUser`, `ID_ServiceFk`, `ID_FonctionFk`, `DateEmbauche`, `DateFinEmploi` et `ObservationProfessionnelle`. Elles restent NULL pour les comptes existants.

Le matricule est limité à 50 caractères, nettoyé aux extrémités et unique sans distinction de casse par entreprise hors valeurs NULL. La fin d’emploi ne précède pas le début renseigné. L’observation professionnelle est limitée à 1000 caractères. La fonction professionnelle est distincte du rôle de sécurité et n’accorde aucun droit.

`V_User_Affectation` expose ces données et `EstAffectable`, sans mot de passe, photo, e-mail ou téléphone. Cette vue privée n’élargit ni `V_User_profil` ni les réponses publiques. L’administration les rassemble dans l’onglet Utilisateurs selon les droits et l’entreprise ; l’ancienne source Profils reste compatible. Les deux catalogues gagnent neuf possibilités et une version : Utilisateurs affiche par défaut Nom, Matricule, Entreprise, Service, Fonction, Rôle, État, Administrateur global et Actions. Les préférences personnelles et les anciennes politiques d’export sont conservées ; les nouvelles données RH ne sont pas exportées par défaut. La sélection d’un responsable peut fournir nom, matricule et service, mais pas les dates et la note professionnelles.

## Audit et concurrence

Le trigger de patrimoine impose auteur actif prouvé, dates techniques et propriétaire. Le contexte `systeme.actor_user_id` identifie l’auteur ; il ne remplace ni les droits applicatifs ni l’authentification. Un compte global doit choisir explicitement l’entreprise cible et ne contourne pas la cohérence des responsables ou lieux.

Chaque écriture produit une seule image SQL avant/après dans `T_Audit_Log` : CREATE, UPDATE, ARCHIVE ou RESTORE. Les anciennes affectations restent dans OldData et l’auteur est conservé dans NewData._actor. Le service peut fournir `logistique.immobilisation_request` avec UUID, empreinte, opération et motif ; une preuve invalide est refusée. L’index unique partiel sur entreprise, auteur et UUID empêche un second enregistrement concurrent. Le service sérialise les demandes, compare contenu/contexte et restitue la réponse gagnante lors d’un rejeu. Une écriture SQL directe sans clé de requête n’invente pas de preuve idempotente.

Les verrous partagés sur le responsable et le lieu empêchent une affectation concurrente à leur transfert de propriétaire. Les clés étrangères et gardes SQL restent applicables à un futur backend.

## Installation et recette

Une installation neuve charge structure, dictionnaire/catalogues, puis correspondances fermées. `preparer_installation` produit le manifeste de format 2 avec les SHA des quatre fichiers, le fichier de lecture et l’ordre explicite des trois SQL. `installer_instance` vérifie cet ordre, les empreintes et une destination entièrement vide, applique les correspondances puis les migrations Django natives dans public. Le format 1 historique reste supporté. Aucune configuration privée de l’instance source n’est copiée.

Le script `SQL/1. Schema systeme/Systeme_FK_Correspondance_Seed_Defaults.sql`, copié en `correspondances.sql`, résout les catégories par famille lorsqu’il trouve le socle patrimoine. Il reste un reset explicite des réglages globaux : ne pas le rejouer sur une configuration cliente personnalisée sans examen. L’enregistrement d’anciens réglages d’interface préserve désormais les SourceKey inconnus, afin de ne pas effacer les nouvelles correspondances du patrimoine.

`SQL/tests/test_immobilisations_postgresql.py` exige une URL locale explicite `SAUVERNDEKO_TEST_DATABASE_URL` vers `sauverndeko_test_*`, avec socle 07 fictif avant application 08. La recette finale compte **159 contrôles réussis**, dont préservation des anciennes lignes métier, références dynamiques, champs RH et confidentialité du profil, propriétaires et archivage, deux courses concurrentes, commentaires, installation des correspondances et absence complète d’effet sur le stock, la finance ou le CUMP.

Preuves locales :

- `.runtime/immobilisations08/verification.json` : 159 contrôles SQL privés, SHA final `1d54b5976f8feda508ceb1eceb844f5a1d819e88c188de509b16078c5869fedd`.
- `.runtime/immobilisations08-applique.json` : application réelle contrôlée et absence d’effet sur le stock ou la finance.
- `.runtime/immobilisations08-canonical-20261028-60c5c6949d/verification.json` : huit sources sans données ; deux restaurations vides identiques au catalogue, contraintes, fonctions, triggers et commentaires.
- `.runtime/immobilisations08-package-753ea16f/verification.json` : paquet fermé de format 2 réellement installé par la commande, 18 migrations natives publiques, trois correspondances fonctionnelles, aucune entreprise, compte, bien ou préférence personnelle.
- `.runtime/installateur-formats08-c5829352/verification.json` : compatibilité du format 1, six paquets incorrects refusés sans écriture et destination non vide protégée, soit neuf contrôles.

Les structures complète et métier restaurées contiennent 68 et 58 tables, 82 vues et 130 triggers. Les essais métier et d’installation ne visent jamais SauverNdeko. Le [guide Patrimoine](../../docs/prise-en-main-patrimoine.md) décrit le parcours utilisateur, y compris la fusion des informations professionnelles dans Utilisateurs.

Les contrôles techniques API, rendu et build, ainsi que l’inspection des PDF, ne constituent pas une acceptation client. La permission d’accès du navigateur intégré à localhost:5174 a empêché la dernière recette interactive des écrans ; elle reste à effectuer avec les utilisateurs concernés. Les essais PDF dédiés ont compris 42 pages rendues inspectées.
