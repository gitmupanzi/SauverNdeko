# Portail territorial

## Sources et portée

`apps/core/territorial_portal.py` expose les treize vues existantes de `geolocalisation`. Les sept registres modifiables sont Pays, ancien découpage provincial, provinces, subdivisions, zones, aires et sites. Les six rapports restent en lecture seule. `V_DestinationLogistique` conserve son usage propre dans les bons de stock.

La géographie est commune aux entreprises : ne pas lui attribuer le propriétaire de l'utilisateur ou du contexte `X-Entite-ID`. Les lectures exigent les habilitations existantes d'administration et du module `territoires`. Les écritures exigent en plus un administrateur global et une connexion autorisant les écritures. L'autorisation d'export est contrôlée séparément. Les préférences des tableaux restent personnelles dans leur contexte prévu par le service commun.

La migration 05 enrichit les six vues actuelles avec les identifiants/noms de parents, les compteurs d'enfants et les informations contextuelles réellement présentes en base. Ces colonnes restent des projections SQL et ne sont jamais réécrites dans les fiches. Après synchronisation du catalogue, l'API utilise directement ces vues, sans ajouter une seconde fois leurs alias. Une fiche de modification charge toujours la table réelle par sa clé primaire ; ne pas réutiliser la seule projection d'une liste.

## Contrat HTTP

Préfixe : `/api/geolocalisation/territoires`.

- `GET /synthese` : dix effectifs, cibles des indicateurs et distributions des sites par province et par type, composés dans une seule requête SQL.
- `GET /registres/{kind}` : `q`, `filters` JSON, `take`, `skip`, `sortBy`, `sortDir` ; liste, colonnes et compte filtré dans `meta`.
- `GET /registres/{kind}/{id}` : champs physiques et révision `_version` pour les sept registres modifiables.
- `POST /registres/{kind}`, `PATCH` ou `PUT /registres/{kind}/{id}`, `DELETE /registres/{kind}/{id}` : écriture ou suppression contrôlée.
- `POST /registres/{kind}/panier` : création de une à cent lignes des niveaux actuels 0 à 5, avec parent commun. Le découpage historique conserve sa création individuelle.
- `GET /references/{kind}?currentId={id}` : parents hiérarchiques, références par champ physique, familles résolues, valeurs et capacités.
- `GET /registres/{kind}/export.xlsx` ou `.csv` : mêmes filtres et tri, préférences communes de colonnes d'export, sélection facultative, en-tête en première ligne.

Les noms `kind` autorisés sont fermés : `niveaux0`, `niveaux1-historique`, `niveaux1` à `niveaux5`, `as-sans-site`, `zs-sans-as`, `population-sites`, `reseau-as`, `statistiques-provinces`, `statistiques-zones`. Les clés des préférences remplacent les chiffres des niveaux par `zero`, `un`, `deux`, `trois`, `quatre`, `cinq`, conformément à la contrainte SQL des interfaces.

La liste retourne `meta.columns`, `pk`, `filteredCount`, `totalCount`, `take`, `skip`, `sortBy`, `sortDir`, `note` et les capacités serveur. `meta.drilldowns` décrit les destinations des compteurs et leurs filtres par identifiants, `meta.records` les fiches des libellés hiérarchiques. Les six rapports possèdent un `_rowId` stable, composé des clés de leur grain réel, pour l'affichage et l'export de sélection. Ce champ n'est jamais une clé métier ni un champ à écrire.

## Saisie groupée des niveaux actuels

Le bouton de création ouvre le même panier pour une ou plusieurs lignes. La requête contient `{requestId, header, rows: [{rowId, ...champsPhysiques}]}` ; les identifiants sont des UUID et les `rowId` sont distincts. L'en-tête contient le pays pour N1, la province pour N2, la subdivision pour N3, la zone pour N4, la zone et l'aire facultative pour N5. N0 possède un en-tête vide. Les parents communs sont interdits dans les lignes pour éviter des rattachements contradictoires. Tous les champs descriptifs du formulaire individuel restent autorisés selon le catalogue physique ; aucune clé primaire ni révision de fiche existante ne peut être injectée dans une création.

La réponse contient `{requestId, createdCount, rows: [{rowId, record}]}` avec les vraies clés et révisions. Une erreur 422 contient `error.details.header` et `error.details.rows[rowId][champ]`. Le brouillon reste côté client pour correction. Les contrôles individuels, les références dynamiques et les FK s'appliquent à chaque ligne. Toutes les lignes sont prévalidées avant l'insertion ; la transaction couvre ensuite les créations, les audits individuels et la preuve du panier. Même un refus tardif PostgreSQL annule toutes les lignes et leurs journaux.

La même combinaison nom + code + rattachements, normalisée par `referentiel.fn_normaliser_libelle`, est refusée dans le panier et parmi les lignes déjà enregistrées. Les homonymes avec un autre code ou parent restent possibles ; ce contrôle n'invente pas une unicité mondiale et ne nettoie pas les doublons historiques. Le verrou géographique partagé sérialise aussi deux paniers concurrents. Un UUID rejoué par le même acteur avec le même contenu retrouve son résultat ; un contenu ou un niveau différent est refusé. La géographie partagée ne change pas de propriétaire selon l'entreprise active.

## Références et hiérarchie

Les familles viennent de `referentiel.T_ChampReferentiel` et de la résolution commune des correspondances. Ne pas ajouter de numéros de catégories dans les composants ou les API. Les nouvelles valeurs doivent respecter la famille, la validité et les règles de visibilité existantes ; une valeur historique devenue incompatible reste affichée et conservée si elle n'est pas changée. Les rapports reprennent les familles des champs physiques qu'ils projettent.

Un site peut être lié directement à une zone sans aire. Une aire choisie impose sa zone ; les changements contradictoires sont refusés par champ. Déplacer une aire dans une autre zone est refusé tant que ses sites conservent une zone incompatible. Un simple changement descriptif n'impose pas une correction automatique des anciennes incohérences.

Le service dédié et les anciennes routes CRUD partagent le verrou transactionnel `geolocalisation:hierarchy-writes`, acquis avant le verrou de ligne. Les créations et modifications conservent les types et précisions SQL : décimaux exacts, population entière non négative, distances non négatives, bornes GPS, latitude/longitude ensemble, contraintes NOT NULL et longueurs. Ne pas arrondir silencieusement les coordonnées du formulaire.

Les suppressions sont physiques et explicites, avec confirmation UI ; les clés étrangères refusent les parents encore utilisés. Ne pas inventer de drapeau d'archivage absent des tables géographiques. Les contrôles complémentaires de cohérence hiérarchique résident actuellement dans les deux chemins API. Une écriture SQL directe doit donc aussi respecter ces règles : elles ne constituent pas un nouveau trigger hiérarchique global.

## Concurrence et traçabilité

Chaque écriture dédiée porte un `requestId` UUID canonique. La modification et la suppression portent aussi la révision `_version` issue de `xmin`. Une révision périmée retourne 409 ; un rejeu identique retrouve son résultat ; un même UUID avec un contenu différent est refusé. L'écriture métier et les journaux sont dans une même transaction. Les contrôles de doublons et de rattachement conservent les contraintes existantes, sans supprimer ni fusionner les territoires historiques.

## Lecture des indicateurs

Les effectifs comptent les lignes des vues correspondantes, sans jointure multiplicative ni filtre de fusion ajouté implicitement. Les barres de distribution renvoient aux sites avec le même identifiant de province ou de type, y compris l'absence de rattachement. Les compteurs N0→N1, N1→N2, N2→N3, N3→N4/N5 et N4→N5 ouvrent les mêmes lignes enfants. Le compteur des sites d'une zone utilise son rattachement effectif `COALESCE(zone du site, zone de l'aire)` ; les anciennes incohérences ne sont pas réécrites. Les indicateurs « sans aire » et « sans zone » utilisent en revanche les FK directement enregistrées : une zone héritée de l'aire peut exister malgré une FK de zone nulle. L'absence d'aire n'est pas une erreur en elle-même.

Ne pas agréger les populations de sites comme un taux de couverture : leurs périmètres peuvent se recouvrir. Les liens portent explicitement « Voir les sites sources » ou « Voir les subdivisions sources », sans assimiler la population au nombre de lignes. Le rapport des structures possède le grain zone × type d'aire × type de site ; le nombre d'aires peut se répéter entre types de sites. Son détail des aires applique donc aussi la provenance exacte des sites du groupe par `EXISTS`, y compris un type de site NULL et un ancien site affecté à une autre zone que son aire. Les filtres fermés `StructuresZone` et `StructuresTypeSite` s'appliquent ensemble ; `meta.filterGroups` les retire ensemble et `meta.filterSources` fournit les listes de libellés pour leurs chips.

Le rapport réseau conserve les valeurs SQL inconnues, notamment un pourcentage NULL lorsque le dénominateur est nul. Son détail « avec réseau » reprend exactement le prédicat `AbrGenerique IS NOT NULL AND AbrGenerique <> 'Sans reseau'` dans la projection SQL `AvecReseau`, sans coder d'identifiant de référence ; ce classement ne prouve pas une connexion Internet vérifiée.

## Installation et validation

`20261030_03_portail_territorial.sql` étend le catalogue des tableaux et des exports. `20261030_04_type_site_referentiel.sql` corrige une FK physique manquante du type de site, puis inscrit son champ dans le référencement central. L'inspection source a prouvé 21 949 types renseignés, 28 identifiants distincts, une famille unanime et aucun orphelin. Le défaut est dérivé du type d'aire déjà catalogué ; il n'est pas codé en dur. La migration ne réécrit aucun territoire ni réglage existant et son rejeu préserve la configuration.

`20261030_05` enrichit les six vues existantes et leurs catalogues sans changer leur grain ni les tables géographiques. Les compteurs deviennent des colonnes disponibles et visibles par défaut, tout en conservant les personnalisations des utilisateurs. Les projections de contexte n'inventent aucun champ Access absent du modèle actuel.

`SQL/tests/test_territoires_api.py` refuse toute cible hors PostgreSQL privé local `sauverndeko_test_*`. La recette exerce les treize registres, les sept fiches/CRUD, les filtres et exports XLSX/CSV, les droits, la géographie partagée, les références dynamiques, la concurrence et l'idempotence, les précisions numériques, les contraintes de parents et le rejeu de la migration. Les paniers des six niveaux sont également testés : saisie complète, erreurs par ligne, correction, doublons, parents, bornes, droits, références et refus tardif réel par trigger de recette privé, avec vérification d'absence de création ou audit partiel. Elle n'est jamais exécutée contre `SauverNdeko`. Les contrôles GET de `verifier_backend` restent réellement en lecture seule ; ils ne remplacent pas une recette visuelle ni une écriture métier réelle.
