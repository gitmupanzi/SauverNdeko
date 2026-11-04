# Annuaire des structures et territoires — 4 novembre 2026

## Objet et sources vérifiées

Le parcours `/pharmacies` consulte les structures et territoires de niveaux 3,
4 et 5 de `geolocalisation`, avec tous leurs types communs actifs : centres de
santé, hôpitaux, pharmacies, mais aussi districts, secteurs, groupements et autres
unités enregistrées. Une pharmacie est enregistrée au niveau 5. Le nom technique
`V_StructureSanitairePublique` est conservé pour compatibilité ; il ne limite pas
l’annuaire aux établissements médicaux.

Une entreprise ERP `systeme.T_Entite` et un territoire ont des identités distinctes.
Leurs identifiants, logos, offres, professionnels et destinataires de discussion
ne sont jamais rapprochés par égalité numérique. Le contrat précédent du
3 novembre demeure celui des profils d’entreprise et de leurs conversations.

L’audit source du 4 novembre, exécuté exclusivement en lecture seule, a constaté
2 469 lignes N3, 1 011 lignes N4 et 21 949 lignes N5. Ces niveaux contiennent des
structures sanitaires et des géographies. La source présentait 34 collisions
numériques entre N3 et N4. `T_CoordonneesTerritoire` était vide ; aucune adresse,
numéro ou plage horaire n’a été inventé ou copié depuis une entreprise ou un parent.

## Types, choix par niveau et lecture des affectations

La famille de chaque type vient de `referentiel.fn_categories_champ(..., NULL)`,
appliquée aux vrais champs physiques :

| Niveau | Champ de type |
|---|---|
| 3 | `T_Niveau_3.ID_TypeNiveau_2_Fk` |
| 4 | `T_Niveau_4.ID_TypeNiveau_4_Fk` |
| 5 | `T_Niveau_5.ID_TypeNiveau_5_Fk` |

La géographie et ces références sont communes : elles n’adoptent pas l’entreprise
active du lecteur. Aucun numéro de catégorie n’est codé dans les lectures.
L’annuaire exige une valeur centrale commune active, appartenant à la famille
physique actuellement résolue et à une catégorie commune active.

Les champs existants `T_Generique.VisibleNiveau_3`, `VisibleNiveau_4` et
`VisibleNiveau_5` gouvernent les choix proposés à leur niveau. Leurs défauts SQL
sont déjà `true`. L’audit a relevé, parmi les 55 types de la famille territoriale,
21 true/34 false au niveau 3, aucun true/55 false au niveau 4 et 21 true/34 false
au niveau 5. Ces valeurs existantes restent intactes ; aucune migration ne les
remet toutes à true.

Les services proposent les types dont la visibilité du niveau vaut true pour une
nouvelle affectation. Une ancienne FK inchangée reste identifiable et conservée,
même si elle n’est plus proposée. Ces règles de choix ne masquent pas les
territoires déjà affectés : l’annuaire lit leurs types communs actifs sans filtre
sur `VisibleNiveau_*`, sans classement médical supplémentaire et sans second
champ d’inclusion. Les indicateurs provinciaux `VisibleNiveau_1`/`VisibleNiveau_5`
et `SelectNiveau_*` ne sont pas transformés en autorisations de publication.

## Migration et types pharmaceutiques

`20261104_01_annuaire_sanitaire_territorial.sql` conserve le schéma de
`T_Generique`, la vue `V_Generique` et leurs anciens commentaires. Les deux
snapshots Référentiel ont été rétablis exactement aux octets HEAD d’origine.

La migration ajoute les types territoriaux communs `Pharmacie` et
`Dépôt pharmaceutique` uniquement dans l’unique famille N5 commune active résolue,
s’ils n’existent pas déjà par nom normalisé. Leur abréviation initiale est leur
nom complet et `VisibleNiveau_5=true` est explicite ; les autres visibilités
conservent les défauts existants. Un rejeu ne modifie ni nom, abréviation,
validité ou visibilité d’une référence déjà présente. Une ambiguïté de nom commun
arrête la migration. Les homonymes Type produit et Type entité restent inchangés.

Avec les données auditées et sans exclusion médicale, 25 429 identités
territoriales N3/N4/N5 sont attendues avant d’éventuels filtres applicatifs.
Ce nombre doit être vérifié après installation ; il ne représente pas un nombre
d’établissements physiques uniques. Aucune fusion des BCZS, DPS ou autres noms
répétés entre niveaux n’est exécutée.

## Contacts et horaires

La fiche existante `geolocalisation.T_CoordonneesTerritoire` reçoit :

| Colonne | Contrat |
|---|---|
| `PublierCoordonneesAnnuaire` | booléen obligatoire, false par défaut, y compris pour les fiches antérieures |
| `HorairesOuvertureTerritoire` | texte simple facultatif, de 1 à 1 000 caractères, sans contrôles hors CR/LF ni espaces extérieurs |

`NULL` désigne des horaires inconnus. Ces horaires déclarés ne constituent pas
un calcul « ouvert maintenant », une permanence ou une pharmacie de garde.
Le consentement porte sur l’adresse, les téléphones, l’e-mail, le site, l’accueil
et les horaires de cette seule fiche. Son retrait masque immédiatement ces champs
dans l’annuaire et conserve les données du registre territorial privé. Les
contacts N1/N2 restent gérables dans leurs fiches sans créer d’entrées N1/N2.
Aucun contact n’est hérité d’un parent.

Les vues privées `V_Niveau_1` à `V_Niveau_5` conservent leurs colonnes, leur ordre
et leur grain, puis ajoutent les deux champs en suffixe. Leurs catalogues rendent
les champs disponibles dans les tableaux et exports, masqués par défaut, sans
réécrire les préférences personnelles. La révision de fiche combine territoire
et coordonnées ; les sauvegardes individuelles et les paniers restent atomiques.
La migration antérieure des coordonnées vérifie l’ordre de ses sept colonnes
sans imposer qu’elles terminent encore la vue, pour rester rejouable après cette
extension.

## Projection fermée

`geolocalisation.V_StructureSanitairePublique` réutilise `V_Niveau_3/4/5` avec
`UNION ALL`, au grain niveau territorial + identifiant. Ses 23 colonnes sont :

| Colonnes, dans l’ordre | Sens |
|---|---|
| `StructureKey`, `NiveauStructure`, `ID_Structure` | clé `n3:<id>`, `n4:<id>` ou `n5:<id>`, niveau entier et identifiant physique |
| `NomStructure`, `CodeStructure` | nom et code territoriaux, éventuellement absents |
| `ID_TypeStructureFk`, `TypeStructure` | identifiant central et `AbrGenerique` ; repli neutre `Valeur sans abréviation #<id>` |
| `ID_Niveau_1`, `NomNiveau_1`, `ID_Niveau_2`, `NomNiveau_2` | province et subdivision issues des vues communes |
| `ID_Niveau_3`, `NomNiveau_3`, `ID_Niveau_4`, `NomNiveau_4` | propre niveau ou rattachement applicable ; N3 n’a pas de N4 |
| `AdresseTerritoire`, `TelephoneTerritoire`, `TelephoneSecondaireTerritoire`, `EmailTerritoire`, `SiteWebTerritoire`, `InformationsAccueilTerritoire`, `HorairesOuvertureTerritoire` | valeurs de la seule fiche liée avec consentement true, sinon NULL |
| `CoordonneesPubliees` | true si la fiche liée porte le consentement ; ne signifie pas coordonnées complètes ou vérifiées |

La zone effective du N5 reste celle de la vue commune : zone directe du site,
sinon zone de son aire. Un site sans aire reste consultable. La projection exclut
GPS, observations internes, populations, géométries, déploiement, identifiants
SNIS, auteurs, comptes, logos, offres et affiliations professionnelles.

## API authentifiée et interface

Les routes `/api/structures/annuaire-sanitaire`, `/references` et
`/<niveau>/<id>` exigent une session et le module Structures, sans imposer les
licences Territoires ou Logistique à la lecture de l’annuaire. Recherche, total,
filtres et pagination partagent la même population. La recherche accepte les
noms descriptifs des types tandis que le libellé affiché reste `AbrGenerique`.
Le détail recontrôle le type et la publication actuelle des contacts.

La compatibilité `/api/public/pharmacies` et les statistiques Structures utilisent
cette même population territoriale. L’entreprise active et `X-Entite-ID` ne créent
pas un périmètre de propriété de l’annuaire. Une lecture ne crée ni recherche
persistée, ni discussion, ni transaction commerciale.

Cartes et Tableau conservent les mêmes critères. La fiche latérale utilise une
clé URL telle que `structure=n5:7` et conserve filtres et page au retour. Un ancien
identifiant `structure=7` ne choisit aucun niveau ou entreprise supposé.
`canManageTerritories` ouvre la gestion N3/N4/N5 selon les droits réels de cette
destination ; son absence ne ferme pas la lecture Structures. Aucun territoire
n’est transmis comme `companyId`, logo ERP ou destinataire de Discussions.

## Vérification privée et canoniques

La recette utilise `sauverndeko_test_sanitaire_20261104`, copie locale de structure
alimentée uniquement de dictionnaires communs et de fixtures fictives. Aucun
compte, client, stock, document ou contact source n’a été copié. Les trois synonymes
communs Oncologie prévus par la migration Professionnels ont été ajoutés au seed
de cette seule copie. Les tests utilisent les triggers ordinaires actifs.

`test_annuaire_sanitaire_postgresql.py` valide le contrat fermé, les collisions,
la hiérarchie, le consentement et son retrait, l’absence d’héritage, la validité et
les familles physiques, les abréviations, les types district/secteur/groupement,
les défauts de visibilité inchangés, les horaires, les commentaires, le catalogue
et le rejeu préservant validité et visibilités. La création des deux types
pharmaceutiques est également exercée dans une famille N5 temporaire : le rejeu
conserve ensuite leurs abréviations, validités et drapeaux modifiés.

Les deux instantanés globaux et les extraits Géolocalisation ont été actualisés
par export `--schema-only` ciblé sur 46 blocs. Les autres blocs restent identiques
octet pour octet, dont les 97 séquences CR/LF présentes dans chaque fichier global.
Les commentaires historiques de contraintes régénérés par le test de rejeu SQL04
sont rétablis dans la copie privée depuis leurs blocs canoniques inchangés avant
comparaison. Le champ temporaire de classement a été retiré de tous les candidats.

Les fichiers ont été restaurés avec `ON_ERROR_STOP=1` et une seule transaction
avant leur copie vers les canoniques :

| Instantané | Tables | Vues | Routines | Triggers | Lignes de données |
|---|---:|---:|---:|---:|---:|
| `SauverNdeko_Structure.sql` | 78 | 98 | 206 | 205 | 0 |
| `SauverNdeko_Metier_Structure.sql` | 68 | 98 | 175 | 205 | 0 |

Après les décisions finales, les recettes ont été relancées : **144 tests réussis**.

| Recette | Tests réussis |
|---|---:|
| SQL annuaire territorial | 14 |
| SQL coordonnées territoriales | 15 |
| API annuaire territorial | 11 |
| API coordonnées territoriales | 11 |
| API Territoires | 39 |
| API profils/annuaire ERP historique | 13 |
| API Professionnels | 29 |
| API Produits | 12 |

La recette historique ERP a été rendue rejouable en restaurant dans son `finally`
le libellé commun modifié par son test d’abréviation. Les anciennes exécutions de
la proposition de classement abandonnée ne sont pas comptées dans ce résultat.

Les définitions, commentaires, colonnes, contraintes, index, triggers, routines
et séquences correspondent à la copie privée. Seuls les deux instantanés globaux,
`4. Schema geolocalisation/geolocalisation_Tables.sql` et
`geolocalisation_views.sql` sont modifiés. La preuve locale est
`.runtime/sanitaire01-canonicals/verification.json` ; les résultats des recettes
finales sont dans `private-final-tests.json` et les journaux associés.

L’installation source relève de la sauvegarde et des contrôles du responsable de
livraison ; cette recette n’exécute aucun DDL ou DML sur `SauverNdeko`. Le diagnostic
backend final doit utiliser une connexion réellement en lecture seule.

## Installation locale vérifiée

Le 4 novembre 2026, la migration a été installée dans **SauverNdeko**, après une
sauvegarde cohérente puis sa restauration exacte dans une base privée locale :
78 tables et 6 médias comparés par empreintes. La migration a d’abord été rejouée
deux fois sur cette restauration fraîche. À l’installation source, les anciennes
colonnes et lignes des 78 tables sont conservées, dont les visibilités du
référentiel ; seuls les deux types pharmaceutiques et les suffixes des cinq
catalogues territoriaux sont ajoutés. Les triggers antérieurs restent identiques.
Les six vues concernées correspondent à la copie migrée et une entrée d’audit
identifie l’installation. Preuve privée :
`.runtime/sanitaire-source-applied-20261104.json`.

La vue contient 2 469 entrées N3, 1 011 N4 et 21 949 N5, soit **25 429** clés
territoriales distinctes. Aucune coordonnée ni plage horaire n’a été fabriquée.
Les nouvelles valeurs pharmaceutiques suivent les défauts de visibilité existants,
avec `VisibleNiveau_5=true` explicite ; les anciennes valeurs gardent leurs choix.

Django et Vite ont été redémarrés sur les ports 5000 et 5174. Le diagnostic backend
a réussi ses **362 lectures** avec une connexion SQL réellement en lecture seule.
Un contrôle HTTP supplémentaire a vérifié 17 requêtes GET réelles, directement
sur Django puis par le proxy Vite : annuaire, filtres, détail composite, compatibilité,
recherches « district », « secteur », « hôpital », « centre de santé », références
N4 et refus anonyme attendu. Aucun message ni écriture métier n’est émis par ces
contrôles. Preuve privée : `.runtime/sanitaire-live-http-20261104.json`.

La compilation Vite, les contrôles frontend ciblés et les validations des skills
sont réussis. Les essais frontend utilisent rendu serveur, événements et transports
contrôlés ; **aucune recette visuelle dans le navigateur n’a été réalisée**, son
autorisation localhost n’étant pas disponible dans cette session.
