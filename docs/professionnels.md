# Professionnels — annuaire transversal

Le module `/experts` présente des professionnels selon leurs compétences et leurs prestations déclarées. Santé, immobilier et construction utilisent le même modèle ; un autre secteur se configure dans le référentiel sans créer une nouvelle table de métiers.

## Parcours

- **Annuaire** : recherche par besoin, nom ou métier, critères, pagination et choix Cartes/Tableau. Une seule représentation de la liste est affichée à la fois.
- **Profil professionnel** : présentation, compétences et services, structures et contact. Le lien depuis la recherche globale ouvre la fiche du même identifiant.
- **Profils professionnels** : registre de gestion réservé aux administrateurs autorisés. Le formulaire commun sert à créer et à modifier la fiche, avec ses compétences, prestations et affiliations sauvegardées ensemble.
- **Publication** : une création est un brouillon. Publier, retirer, archiver et réactiver sont des actions distinctes et tracées. Les comptes, entreprises et profils inactifs ne figurent pas dans l’annuaire.
- **Contact** : la discussion existante est réutilisée. Un profil doit être publié, actif et accepter les contacts ; les droits de messagerie restent applicables. Le contact avec soi-même est refusé.

Les discussions avec un professionnel sont privées entre le demandeur et le compte professionnel. Une affiliation ou le rôle d’administrateur de son entreprise ne rend pas automatiquement participant à cet échange.

Le guide intégré contient cinq parcours pour ce module. Les exemples y sont fictifs. Aucune personne ni qualification de démonstration n’est ajoutée à la base applicative.

### Un profil enregistré n’apparaît pas dans la recherche

Vérifier son statut dans **Profils professionnels** : le bouton **Enregistrer le brouillon** ne publie pas la fiche. Sélectionner l’entreprise propriétaire, compléter la présentation et ouvrir l’action de publication du profil. Les informations requises sont indiquées dans la fiche. Une fois publié et actif, le profil peut être retrouvé par son nom ou ses compétences déclarées dans l’annuaire.

### Importer des profils depuis Excel

Dans **Profils professionnels**, sélectionner l’entreprise puis télécharger le **modèle Excel**. La feuille **Profils** contient les en-têtes à la première ligne ; la feuille **Options** fournit les comptes et références autorisés pour l’entreprise, et **Informations** précise les consignes. Un fichier `.xlsx` de 4 Mo maximum peut contenir 100 profils. Utilisateur, secteur, profession et titre professionnel sont obligatoires. Chaque utilisateur ne peut posséder qu’un profil.

**Importer un fichier Excel** prépare un panier modifiable, sans créer de fiche. Vérifier et corriger chaque ligne, ses compétences, ses services et ses structures, puis enregistrer l’ensemble. Les compétences et services multiples se séparent par un point-virgule dans le fichier, avec leurs identifiants ou les abréviations exactes proposées. Une valeur inconnue ou ambiguë reste à corriger ; elle ne crée pas de référence. Les structures se complètent dans les détails du panier ; les photos se gèrent ensuite dans la fiche individuelle.

L’entreprise propriétaire provient uniquement du contexte autorisé. L’import ne crée aucun compte et ne publie pas de profil. Toutes les fiches sont enregistrées en **brouillon** dans une transaction unique ; une erreur annule aussi les autres créations et leurs audits tout en conservant la saisie dans le panier. Après une réponse réseau incertaine, vérifier la même demande avant de la modifier ou d’en créer une autre. Le formulaire individuel reste disponible pour les fiches détaillées.

Les routes dédiées sont `GET /api/professionnels/profils/modele-excel`, `POST /api/professionnels/profils/import-excel` (multipart `fichier`, lecture seule) et `POST /api/professionnels/profils/batch`. Ce dernier reçoit `{requestId, rows:[{clientRowId, data, competenceIds, prestationIds, affiliations}]}` ; `data` reprend les champs du formulaire individuel. Le service individuel recontrôle comptes, références dynamiques, entreprise et affiliations lors de la confirmation. La demande du lot entier est liée à chaque preuve de rejeu. Aucune table ni migration supplémentaire n’est nécessaire.

## Photo du professionnel

La fiche utilise la photo du compte associé. Le formulaire d’ajout ou de modification permet de choisir une image JPEG, PNG ou WebP, d’en voir l’aperçu, de la remplacer ou de la retirer. Sans photo, les initiales servent d’avatar. La sélection reste locale tant que le formulaire n’est pas enregistré.

L’enregistrement du profil et de sa photo partage les mêmes permissions, révision et demande rejouable. Les images sont validées, normalisées puis conservées dans le stockage privé ; aucun chemin de fichier ne se saisit dans le formulaire. Les fichiers créés sont compensés si la transaction échoue, et l’ancien fichier n’est retiré qu’après validation. L’annuaire ne donne accès à la photo que si le profil est publié et actif ; la gestion d’un brouillon utilise une route autorisée distincte.

## Référentiels

Les secteurs, professions, spécialités, compétences, prestations et types de rattachement sont des valeurs de `referentiel."T_Generique"`, regroupées dans `T_CategorieGenerique`. `T_ChampReferentiel` et les correspondances actives déterminent la catégorie de chaque champ, avec le contexte de l’entreprise. Les champs métier enregistrent les identifiants génériques, pas les libellés.

Les deux tables de liaison `T_Professionnel_Competence` et `T_Professionnel_Prestation` décrivent les choix d’un profil ; elles ne dupliquent pas le dictionnaire. Les synonymes de `T_SynonymeRecherche` se rattachent eux aussi à une valeur générique. Ainsi, le terme « cancer » peut retrouver une compétence « Oncologie » explicitement déclarée dans une fiche. La recherche ne déduit ni diplôme ni expertise d’une personne.

Un changement de catégorie conserve les sélections déjà enregistrées. Les valeurs devenues incompatibles sont signalées dans la gestion ; les nouvelles sélections sont validées par la configuration centrale et les gardes PostgreSQL.

## Propriété et confidentialité

Une fiche est unique par compte utilisateur et possède une entreprise propriétaire durable, distincte de ses structures d’exercice. Les gestionnaires interviennent dans leur entreprise autorisée ; un administrateur global peut consulter l’ensemble et doit choisir une entreprise active avant d’écrire. Aucun déplacement de compte ou changement de droits n’est réalisé à la création du profil.

L’annuaire est transversal entre entreprises mais ne lit que la projection publiée. La présentation publique est séparée des observations internes et du numéro d’identification de gestion. Les e-mails, téléphones personnels, mots de passe et données RH du compte restent absents de cette projection. Les coordonnées des structures proviennent de leurs fiches actives et des affiliations en cours.

La publication n’est pas une certification de qualification. Le module ne gère pas la validation de diplômes, les rendez-vous, les paiements de prestations ou des avis clients.

## Socle et maintenance

La migration `SQL/migrations/20261102_06_professionnels_transversaux.sql` enrichit le schéma existant, ajoute les relations et leurs commentaires, la projection publique, le registre privé, la recherche SQL et les triggers de cohérence/audit. Elle refuse une base contenant déjà des profils : une reprise explicite de leur entreprise et publication serait alors nécessaire. La source examinée n’en contenait aucun. La migration `20261102_07_revision_details_professionnels.sql` fait évoluer la révision du profil après une modification réelle d’une compétence, prestation ou affiliation, même par un autre écrivain SQL ; les écritures sans différence ne changent pas la version.

Les écritures métier passent par `/api/professionnels`, avec révision, motif pour les modifications sensibles et UUID de demande. Les écritures génériques du schéma professionnel sont refusées. Les anciens consommateurs `/api/public/experts`, la recherche globale et les discussions conservent un adaptateur compatible.

Le paquet neuf contient le dictionnaire commun et ses synonymes communs ; il exclut profils, entreprises, comptes, affiliations et termes privés. Les métadonnées de la base, leurs sauvegardes et preuves de restauration se contrôlent séparément des tests d’interface.

## Validation

Les tests et résultats de cette évolution sont consignés dans `SQL/documentation/Professionnels_20261102.md`. Une recette technique ou des fixtures DOM ne constituent pas une visite interactive de l’application dans le navigateur.
