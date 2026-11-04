# Fiabilisation de la géographie — SNIS/DHIS2 et GRID3

Audit du 4 novembre 2026 sur **SauverNdeko**, sans assimilation de la décentralisation administrative à la pyramide sanitaire. Les fichiers fournis sont des instantanés : leur comparaison ne certifie pas leur actualité dans le serveur SNIS national.

## État et périmètre

L'adaptation additive a été validée par le propriétaire dans le chat, puis **installée dans SauverNdeko le 4 novembre 2026** après sauvegarde restaurée et recette complète privée. Les migrations `20261104_02_rapprochement_territorial.sql`, `20261104_04_integrite_uid_snis.sql` et `20261104_05_performance_masquage_audit.sql` sont installées. Le plan contrôlé a été appliqué dans une transaction unique par `appliquer_reprise_territoriale`, avec l'administrateur global ID 15 comme acteur. Son rejeu retrouve le résultat sans écriture. Le journal d'application porte l'identifiant 386.

Le SHA-256 du plan appliqué est `733e8b96e099ff5f4cf07f5a0799baa097408d5508f53ef0c3a412046d4279fb`. Les 25 compléments provinciaux font partie de ce lot. La migration autonome `20261104_03_uid_provinces_prouves.sql`, testée séparément, reste disponible pour cette seule reprise ; elle n'a pas été exécutée une seconde fois sur la source.

Les clés physiques, les noms, les parents, les types, les contacts, les géométries et les références des autres modules sont préservés tant qu'une décision de reprise n'a pas été validée. Aucun rapprochement par nom n'est une preuve automatique d'identité.

## Sources examinées

| Source | Contenu lu | Empreinte SHA-256 |
|---|---|---|
| `C:\Users\Benjamin-mupanzi\Downloads\rdc_database_pyramide_code_DHIS2.xlsx` | Deux feuilles : `Decentralisation` et `Zone_code` | `c792b7255e4bc557b300515c83bb2284a6a77639063ec0a16bf2f13e45d17bbd` |
| `C:\Users\Benjamin-mupanzi\Downloads\Pyramide sanitaire\data.grid3\GRID3_COD_health_areas_v9_0_-8091131576578626801.xlsx` | Feuille `GRID3_COD_health_areas_v9_0_0` | `78e04e354e14b9fb8a23c5b452f56371ab32d396d65f50cf66068ec21d8338ac` |
| Schéma `geolocalisation` de SauverNdeko | Tables N0 à N5, types, contraintes, vues, routines et dépendances réelles | Export transactionnel privé en lecture seule |
| Schéma territorial administratif transmis dans le chat | Organisation et niveaux proposés ; document mentionnant une source de 2017 | Image fournie, conservée séparément des observations en base |

La date de modification du classeur DHIS2 est le 22 juin 2026 ; elle ne constitue pas une date de validation de toutes ses lignes. L'Excel GRID3 est un export du 4 novembre 2026 et contient des mentions de source par ligne. Son absence de géométrie exploitable est respectée : `Shape__Area` et `Shape__Length` ne produisent aucune coordonnée ni limite territoriale.

Le référentiel catégoriel reste dans `referentiel.T_Generique`. Ses `ID_Generique` restent les clés enregistrées et `AbrGenerique` le libellé des listes. La seule modification de visibilité du lot est l'activation explicite de `VisibleNiveau_4` pour le vrai type commun AS, résolu dans la famille du champ physique N4 : ID 344, catégorie 32 lors de l'audit. Aucun autre réglage de visibilité ni catégorie n'a été modifié.

## État initial de la base

| Niveau | Lignes | Situation déterminante |
|---|---:|---|
| N0 | 251 | Pays et territoires ; aucun nettoyage de noms dans ce lot |
| N1 | 26 | Tous les `uidSNIS` vides ; les `prov_uid` existent |
| N2 | 315 | Dont 51 antennes PEV, 145 territoires et des lignes de compatibilité |
| N3 | 2 469 | Dont 519 BCZS sous antennes PEV et 519 ZS sous parents administratifs |
| N4 | 1 011 | 163 AS, 796 groupements, 26 Région et 26 DPS |
| N5 | 21 949 | Tous liés à N3 ; **aucun lié à N4** |

Les identifiants `uidSNIS` sont vides à tous les niveaux avant reprise. Aucun orphelin de clé étrangère n'a été détecté. Le nombre de contradictions entre la zone directe d'un site et celle de son aire est zéro uniquement parce qu'aucun site n'a d'aire renseignée : ce résultat n'atteste pas une hiérarchie complète.

Les 1 011 lignes N4 ont des copies N5 de même identifiant, nom, type, parent N3 et code. Cette observation locale confirme l'explication historique du propriétaire ; elle ne crée pas une règle générale d'équivalence entre identifiants de tables différentes.

- Les **163 AS N5 existent déjà au N4**. Les recréer serait incorrect.
- Les **796 groupements N5 existent aussi au N4**. Le rapprochement nom/type/parent donne 792 correspondances uniques et quatre cas ambigus : deux couples de doublons N4, BANGALUMA et KYAKA. Les clés égales sont conservées dans le dossier comme indices supplémentaires ; elles n'autorisent pas à supprimer arbitrairement un doublon.
- Les groupements ne sont pas des aires de santé. Leurs parents administratifs et les AS sous BCZS restent distincts.
- Les copies Région/DPS et les bureaux/repères ne deviennent pas automatiquement des établissements de soins.

## Conflits et données manquantes

### Provinces

Vingt-cinq UID sont prouvés par un `prov_uid` déjà présent, après retrait des blancs uniquement pour la comparaison, un nom concordant et le même UID dans les deux fichiers. Le `prov_uid` d'origine, parfois suivi d'un retour à la ligne, reste inchangé.

La province locale **ID 11** porte `Kasai Central`, tout comme ID 10, alors que son UID externe et ses descendants renvoient au Kasaï Oriental. Sa correction et son `uidSNIS` restent exclus du lot automatique. Aucun nom ne sera remplacé silencieusement.

### Zones et aires DHIS2

La feuille principale contient 10 076 lignes, 26 UID provinciaux, 519 UID de zones et 9 802 UID d'aires. Ce sont des effectifs d'identifiants sources, pas des nombres de lignes à insérer.

- L'UID de zone `hdDyVXgN46J` désigne Mulongo/Haut-Lomami et Yakusu/Tshopo dans le même fichier. Les correspondances concernées et leurs descendants ne sont pas validés automatiquement.
- 38 lignes manquent d'UID de zone et 113 d'UID d'aire.
- Trois clés aire + parent normalisés portent plusieurs UID : Makelele, Matonge 2 et Bolafa 2. Elles nécessitent une décision métier, pas une fusion par nom.
- La feuille `Zone_code` est un pivot de codes, sans autorité supplémentaire sur les UID. Elle ne doit pas servir à inventer un UID manquant.

Les BCZS et ZS ne sont pas fusionnés. Même province + nom donne 502 couples locaux possibles, avec 17 BCZS sans couple exact. Après contrôle des deux fichiers et exclusion des conflits, il reste **495 candidats BCZS** et **480 candidats ZS**, distincts des correspondances certaines. Pour les AS existantes, 140 des 163 ont un candidat par nom et parent, 23 restent sans rapprochement. Leur appartenance actuelle aux BCZS impose d'abord un choix explicite concernant la ZS canonique.

### GRID3

Les 9 720 objets ont des `grid3id` distincts. Ils portent 9 665 UID d'aires ; 12 objets n'ont pas d'UID d'aire. **23 aires ont plusieurs objets GRID3**, jusqu'à 14. Une contrainte unique sur l'aire ferait donc perdre des objets légitimes.

La comparaison des sources produit 9 474 UID d'aires avec nom et parent concordants, 119 noms différents, 208 UID seulement dans DHIS2, 71 seulement dans GRID3 et un conflit de parent. L'aire Byangama, UID `e7IVU17xqwM`, n'a pas la même zone dans les deux fichiers. Une égalité d'UID ne suffit pas à ignorer cette contradiction.

Les fichiers fournis décrivent des aires, mais ne donnent pas de table exhaustive **établissement → UID de l'aire**. Une structure et une aire homonymes ne suffisent pas à démontrer leur rattachement. Les 21 949 lignes N5 sans N4 sont exportées dans `n5_sans_aire.csv`, avec leur type ; cette liste comprend aussi des copies territoriales et des bureaux, pas uniquement des établissements de soins.

## Adaptation validée et installée

1. **Conserver les identifiants N1 à N5 et le lien direct N5→N3.** Une FK de bon de stock référence déjà N5 4088 (AKETI, BCZS). Dix-neuf vues et seize FK dépendent de la géographie, dont quatre FK externes. Une suppression de copies ou de parent ferait courir un risque aux annuaires, destinations et historiques.
2. **Conserver deux organisations explicites.** Une zone N3 de type ZS peut garder son parent administratif actuel et recevoir un rattachement sanitaire à une antenne PEV, sans surcharger l'unique parent physique existant.
3. **Distinguer la zone de son bureau.** Proposer les ZS comme identités géographiques canoniques ; un lien « bureau de zone » rattache le BCZS correspondant, sans leur donner automatiquement le même UID SNIS.
4. **Tracer les copies historiques.** Un lien N5→N4 explicite documente les AS/groupements copiés ; il ne transforme pas un groupement en AS et ne supprime aucun identifiant historique.
5. **Conserver les sources et leurs versions.** Le socle proposé comporte `T_SourceRapprochementTerritorial`, `T_CorrespondanceTerritoriale` et `T_LienTerritorial`. De vraies FK contrôlent les cibles ; les lignes sources, empreintes, décisions, motifs et acteurs restent traçables. Plusieurs objets GRID3 peuvent viser la même aire. Ce socle ne modifie pas les parents à son installation.
6. **Appliquer des lots validés et bornés.** Le lot installé ne déplace aucun parent existant. Les noms primaires et parents doivent concorder dans les deux sources ; les alias approximatifs ne produisent aucune confirmation automatique. Les 3 088 photographies de préétat sont revérifiées avant toute création. Les préconditions, verrous, preuves et journal sont couverts par une transaction ; un refus tardif annule l'ensemble.

Les trois tables sont un socle de provenance technique, pas trois nouveaux dictionnaires catégoriels. La migration ne crée aucun type territorial local hors du référentiel commun. Les contraintes de forme et de décision ne valent pas preuve d'une correspondance : les justificatifs du lot et la validation restent nécessaires.

### Résultat appliqué

| Opération | Résultat |
|---|---:|
| UID provinciaux complétés | 25 |
| UID de ZS canoniques complétés | 479 |
| UID d'AS existantes complétés | 127 |
| AS nouvelles, identifiants générés par PostgreSQL | 8 655 |
| Liens AS → ZS confirmés | 8 782 |
| Liens bureau BCZS → ZS confirmés | 476 |
| Rattachements sanitaires ZS → antenne PEV | 443 |
| Copies N5 → N4 tracées | 955 : 163 AS et 792 groupements |
| Objets GRID3 conservés | 8 823 |
| Versions de source | 3 : DHIS2, GRID3 et photographie locale |
| Correspondances externes | 18 109 |
| Liens territoriaux typés | 10 656 |

Les effectifs N0/N1/N2/N3/N5 restent respectivement **251 / 26 / 315 / 2 469 / 21 949**. N4 passe de **1 011 à 9 666** par ajout des 8 655 AS ; aucune ancienne ligne n'est supprimée ou fusionnée. Les données anciennes sont identiques, sauf les UID explicitement complétés et la visibilité AS autorisée. Les noms, codes, GPS, populations, parents et contacts anciens sont conservés. Aucun UID n'a été copié sur un BCZS.

La vue privée `geolocalisation.V_PyramideSanitaireRapprochee` donne une ligne par AS, plus les ZS sans aire rapprochée : **8 858 lignes**, **8 818 AS distinctes**, **519 ZS distinctes**, **36 AS sans ZS rapprochée** et **40 ZS sans aire rapprochée**. Les anciens parents administratifs ou BCZS restent lisibles séparément. Les vues et compteurs historiques continuent à décrire leurs FK physiques ; ils ne sont pas rebaptisés « pyramide rapprochée » et aucun effectif n'est artificiellement multiplié par les objets GRID3.

## Sauvegarde et retour arrière

Une sauvegarde cohérente avec empreintes a été produite dans `.runtime/georeconciliation-20261104/backup`. Elle a été restaurée dans une base neuve locale `sauverndeko_test_georeconcile_20261104` : **78 tables et six médias identiques**.

- La migration additive 02 est rejouable sans réécrire les décisions. Son retrait n'est autorisé que si ses trois tables restent vides ; aucune suppression en cascade des preuves.
- La reprise provinciale 03 verrouille les lignes, refuse un nom, pays, UID ou `prov_uid` différent des préconditions, ne remplace pas d'UID renseigné et journalise les états avant/après avec les empreintes des sources. Un rejeu identique ne crée aucune écriture.
- Le retour du lot provincial ne doit toucher que les valeurs encore identiques au lot appliqué. Aucun retour aveugle de toute la base après reprise d'activité.
- Les cas incertains, les anciennes copies et les données contradictoires restent inchangés.

L'importeur conserve les valeurs modifiées, les identifiants créés et les empreintes d'état dans son audit. `--prepare-return` vérifie que ces lignes et preuves sont toujours identiques, puis produit un **diagnostic de compensation en lecture seule** : cette option n'annule pas la reprise. Après utilisation des nouvelles AS par d'autres modules, un retour doit constituer une nouvelle décision versionnée et tenir compte de ses dépendances ; il ne doit pas supprimer les preuves finales. Une restauration complète de la sauvegarde n'est envisageable qu'avant reprise d'activité, en maintenance et après vérification de l'absence de nouvelles écritures. Aucun retour aveugle après reprise d'activité n'est autorisé.

`20261104_04` ajoute le format DHIS2 pour les nouvelles valeurs et un index unique par niveau N1/N3/N4. Les corrections explicites restent possibles ; les UID non rapprochés restent `NULL`. L'unicité entre niveaux est contrôlée par l'import, sans prétendre que ces index locaux garantissent une unicité mondiale concurrente.

## Outil reproductible et listes de travail

`scripts/auditer_pyramide_sanitaire.py` lit les deux XLSX par ZIP/XML standard et prend un instantané Django `REPEATABLE READ READ ONLY` de la géographie. Il ne contient aucun chemin de source imposé, secret ni commande de modification SQL. L'option `--snapshot` permet un rejeu hors connexion. Un rapport différent ne peut pas écraser un rapport existant.

Depuis la racine du dépôt, en PowerShell :

```powershell
.\backend\.venv\Scripts\python.exe scripts\auditer_pyramide_sanitaire.py `
  --dhis2 'C:\Users\Benjamin-mupanzi\Downloads\rdc_database_pyramide_code_DHIS2.xlsx' `
  --grid3 'C:\Users\Benjamin-mupanzi\Downloads\Pyramide sanitaire\data.grid3\GRID3_COD_health_areas_v9_0_-8091131576578626801.xlsx' `
  --destination '.runtime\georeconciliation-20261104\nouvel-audit'
```

Le dossier privé `reproducible-report` contient le rapport JSON, les propositions, les rapprochements de sources, les copies AS/Grp, les objets GRID3 et la liste exhaustive N5 sans aire. Les CSV sont UTF-8 avec BOM et séparateur point-virgule ; les valeurs pouvant être interprétées comme des formules Excel sont neutralisées, tandis que le JSON préserve les valeurs brutes.

Les données sources complètes et les sauvegardes ne sont pas versionnées dans Git. Les empreintes, scripts, migrations et règles sont versionnables.

Le contrôle du lot appliqué utilise le plan privé conservé et son empreinte, sans écriture par défaut :

```powershell
.\backend\.venv\Scripts\python.exe backend\manage.py appliquer_reprise_territoriale `
  --plan '.runtime\georeconciliation-20261104\import-plan.json' `
  --plan-sha256 '733e8b96e099ff5f4cf07f5a0799baa097408d5508f53ef0c3a412046d4279fb' `
  --actor 'benjaminmupanzi@gmail.com'
```

`--apply` est une action explicite, avec connexion autorisant les écritures ; il a déjà été exécuté sur ce plan. Une évolution ultérieure des lignes peut légitimement faire refuser son rejeu. Un nouveau fichier source ou une décision différente exige un nouveau plan contrôlé, sans réécrire les décisions finales existantes. Ne jamais utiliser `--simulate` contre SauverNdeko : cette option est réservée aux copies privées locales et refusée par le programme sur la source.

Le dossier privé `.runtime/georeconciliation-20261104/final-report` contient les résultats réels :

- `actions-appliquees.csv` : opérations du plan, identifiants locaux et preuves ;
- `cas-a-valider.csv` : **1 177 dossiers de décision**, pas 1 177 territoires nécessairement distincts ;
- `n5-sans-aire.csv` : **21 949 lignes N5 sans lien N4**, avec leurs types et parents actuels ;
- `bilan.json` : compteurs, identifiant d'audit et empreinte du plan appliqué.

Les cas exclus comprennent une province, 40 ZS, 43 bureaux, 33 rattachements d'antenne, 36 AS existantes, quatre copies de groupements ambiguës et 1 020 décisions d'aires sources. Ces ensembles n'ont pas le même grain et ne doivent pas être additionnés pour annoncer un nombre de territoires manquants. Les conflits de source sont aussi conservés dans les rapports initiaux, même lorsqu'aucune mutation ne peut en être proposée.

## Références documentaires

La [loi organique RDC 08/016, articles 4 et 5](https://www.relation-parlement.gouv.cd/uploads/textes/68f8f48941e2d_Loi%20organique%20n%C2%B0%2008-016%20du%2007%20octobre%202008%20portant%20composition%2C%20organisation%20et%20fonctionnement%20des%20Entit%C3%A9s%20Territoriales%20D%C3%A9centralis%C3%A9es%20et%20leurs%20rapports%20avec%20l%27Etat%20et%20les%20Provinces%20VF.pdf) distingue le découpage administratif et les entités décentralisées. Le document transmis ne suffit pas à transformer la pyramide sanitaire en découpage administratif. Les anciens districts/cités restent des données historiques tant que leur statut et leur période ne sont pas établis.

Le [catalogue de l'éditeur GRID3 pour la RDC](https://grid3.org/geospatial-data-drc) et la [documentation DHIS2 sur les métadonnées](https://docs.dhis2.org/en/develop/using-the-api/dhis-core-version-242/metadata.html) servent à interpréter les sources. Les attributs exacts utilisés ici viennent des fichiers effectivement lus. Aucun accès au serveur SNIS national ni validation institutionnelle des corrections n'est revendiqué.

## Vérifications exécutées et limites

- Audit des tables, contraintes, parents, types, doublons, UID et dépendances dans une transaction de lecture seule.
- Lecture des deux classeurs et de toutes leurs feuilles, empreintes, contrôles UID/noms/parents et distinction des relations plusieurs-à-un GRID3.
- Neuf tests de l'outil d'audit réussis ; exécution réelle deux fois avec conservation identique des fichiers au rejeu.
- Sauvegarde/restauration exacte des 78 tables et six médias.
- Répétition privée des 25 compléments UID : application, rejeu sans écriture, inversion conditionnelle exacte et annulation de la transaction.
- 35 tests SQL du rapprochement, 11 tests SQL des UID et sept tests de la reprise provinciale réussis sur la copie privée.
- 15 tests PostgreSQL de l'importeur et un test ciblé supplémentaire de doublon AS sous BCZS réussis : droits, préconditions, refus de conflits, rollback après créations et preuves, conservation des parents, plusieurs objets GRID3 par AS, rejeu et refus après édition ultérieure.
- Simulation complète privée, puis application complète privée du plan et rejeu sans doublon. Le prévol ne consomme aucun numéro ; une simulation avec écritures ou un échec de transaction peut laisser des trous de séquence PostgreSQL après rollback, sans ligne métier partiellement enregistrée.
- Deux restaurations SQL canoniques vides réussies : 81 tables pour le global, 71 pour le métier, 99 vues dans les deux. Les blocs antérieurs hors périmètre restent identiques octet par octet, y compris les 97 CRLF internes des fichiers globaux.
- Installation et application source effectivement exécutées, puis comparaison intégrale des anciennes lignes et des documents dépendants. **28 FK contrôlées, zéro orphelin, zéro doublon d'UID dans chacun des trois niveaux canoniques.** Les bons et localisations d'entreprise sont inchangés.
- Rejeu réel du plan source sans écriture et vérification conditionnelle de retour en lecture seule réussis. Les métadonnées géographiques installées correspondent strictement aux canoniques restaurés.

### Lecture des audits volumineux

Le diagnostic après reprise a identifié deux dépassements de délai dans la synthèse et le registre des audits de l'administration. La fonction `systeme.fn_audit_sans_secrets` reconstruisait les gros objets par concaténations successives. La migration 05 utilise des agrégats JSON structurés, un cast JSONB final et la récursion uniquement pour les objets, tableaux et chaînes JSON encodées. Les contrats API et les règles de masquage restent identiques ; aucune preuve ni ligne d'audit n'est réduite ou réécrite.

Huit tests privés supplémentaires passent : parité avec l'ancienne fonction, secrets, logos, paramètres, JSON encodé, cent cas mixtes, conservation des droits et de l'identité de fonction, rejeu, retour et lecture du gros journal réel. La charge synthétique de 25 000 clés et 25 000 éléments passe en 0,375 s ; le gros audit privé se consulte en 0,656 s. Les API privées de synthèse, registre et détail répondent en moins d'une seconde. L'installation source a vérifié le contenu exact des 312 lignes d'audit avant/après et la conservation des droits de fonction.

Après correction, le diagnostic source `verifier_backend` réussit **362 contrôles GET sur 362**, avec connexion en lecture seule et garde refusant les écritures. Le bilan des suites exécutées est de **86 tests** : neuf pour l'audit des fichiers, 35 pour le socle de rapprochement, 11 pour les UID, sept pour le sous-lot provincial, 15 pour l'importeur, un test ciblé de sa garde des doublons sous BCZS et huit pour le masquage performant. Ces tests et contrôles ne sont pas une recette visuelle au navigateur.

`manage.py check` ne signale aucune anomalie. Le serveur backend `/health` sur le port 5000 et le frontend `/catalogue` sur le port 5174 répondent HTTP 200. Ces contrôles HTTP ne remplacent pas la vérification visuelle des écrans.

Après la migration 05, deux nouvelles restaurations vides des canoniques complets/métier ont réussi. La comparaison source finale vérifie les cinq empreintes SQL, tout le périmètre géographique et la définition/commentaire de la fonction d'audit : ils sont identiques aux restaurations privées. Preuve : `canonicals-audit05/source-install-verification.json` dans le dossier privé de la reprise.

Le contrôle du catalogue entier a également relevé quatre différences antérieures hors périmètre géographique : trois commentaires de contraintes-triggers financiers/caisse absents des anciens canoniques, et une différence équivalente de représentation de casts dans une vue Référentiels. Elles sont consignées dans `canonicals-audit05/source-install-differences.json` ; aucune table métier n'a été modifiée pour les masquer.

Restent à valider : le nom de la province ID 11, les conflits DHIS2/GRID3, les appariements incertains et les liens établissement→aire que les fichiers actuels ne permettent pas de prouver. Aucun rattachement clinique N5→N4 n'a été inventé. Une source identifiant chaque établissement et son aire est nécessaire pour terminer cette partie. Aucune validation institutionnelle SNIS ni recette visuelle complète au navigateur n'est revendiquée.
