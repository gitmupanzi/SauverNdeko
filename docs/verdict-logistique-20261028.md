# Vérification du socle logistique — 28 octobre 2026

Les corrections du verdict de test sont installées dans **SauverNdeko** après une sauvegarde vérifiée de la base et des médias. Les essais d’écriture et de concurrence utilisent des bases privées `sauverndeko_test_*`, sans données clients.

Évolution ultérieure demandée le même jour : la migration06 [harmonise les anciens codes des bons](../SQL/documentation/Nomenclature_Bons_Historiques_20261028.md). Les constats ci-dessous décrivent l’installation01–04, qui ne les renumérotait pas encore.

## Données et contrôles PostgreSQL

- Le stock initial positif crée un bon d’entrée, une ligne et un seul mouvement dans la transaction de création de l’article. Un stock nul ne crée aucun mouvement. Les modifications descriptives ne recréent aucune entrée. La demande conserve son UUID et son empreinte pour reconnaître les nouvelles tentatives.
- L’origine est distincte du type de bon : `OrigineBon` et `ID_ArticleInitialFk` identifient la création depuis Articles ou la reprise documentaire. Les nouveaux bons sont numérotés `BE-ID` ou `BS-ID` ; les anciens codes restent inchangés. Le parcours technique actuel conserve le nom interne `T_Commande`, sans fabriquer de commande fournisseur.
- Quatre mouvements historiques sans bon, dont l’entrée de « Téléphone », sont rattachés à quatre bons et lignes de reprise. Aucun stock n’a été ajouté : les 24 mouvements conservent leurs identifiants, quantités, prix, devises et dates. Les anciens documents, lots et arrêtés CUMP restent inchangés. Un auteur historique inconnu reste inconnu.
- Les règlements disposent de `CreeParUserFk`, `ModifieParUserFk`, `CreeLe` et `ModifieLe`. Les gardes SQL contrôlent aussi les modifications, sous verrou du parent : solde, facture, devise, tiers, avoirs et clôture. L’audit de détail est écrit une seule fois par SQL ; les preuves idempotentes applicatives sont conservées séparément.
- Le code interne d’un article est unique par entreprise. L’empreinte SHA-256 d’un justificatif doit correspondre à son contenu binaire conservé en base.

Les données métiers, documents, coûts, lots, dossiers et justificatifs étaient déjà persistés. La correspondance des références ne dépend plus d’un cache navigateur. Les préférences purement visuelles, comme le thème et la largeur d’une fenêtre, restent locales.

## Tableaux et exports

Le catalogue commun et les préférences personnelles sont conservés dans `referentiel.T_InterfaceTableau` et `referentiel.T_PreferenceTableau`. Les droits de lecture et d’export restent vérifiés côté serveur. Les choix sont indépendants entre tableau et export, et isolés par utilisateur, entreprise et interface. Les mises à jour concurrentes sont contrôlées par révision ; réinitialiser ne touche que l’usage choisi.

Le mécanisme couvre les registres Articles, Bons, Lignes, Lots, Mouvements, Factures, Règlements, les deux registres Référentiels et les onze registres de l’administration. Les fiches Excel individuelles gardent leur gabarit métier complet ; les exports de listes suivent les préférences personnelles.

Un seul bouton **Réglages**, placé dans l’en-tête au-dessus du tableau, ouvre les choix personnels de tableau et d’export. Lorsque le registre possède des références catégorielles, le même bouton donne aussi accès à leur configuration commune. Les commandes Réglages et Références ne sont plus affichées en doublon.

Excel et CSV distinguent sélection et résultats filtrés complets. Ils respectent exactement les colonnes et leur ordre, sans colonne Actions ni limitation silencieuse à la page. XLSX conserve nombres, dates et références textuelles. Le CSV utilise UTF-8 avec BOM et le séparateur point-virgule, avec échappement et protection des textes ressemblant à des formules. Pour garantir les zéros initiaux lors d’une ouverture directe dans Excel, utiliser XLSX ; le CSV exige parfois une importation explicite en texte.

Dans les bons, « Lignes » précède « Quantité totale ». Le nombre ouvre le registre des lignes filtré par l’identifiant du bon, avec un filtre visible et effaçable. La quantité affichée ne porte pas de suffixe d’unité, conformément au choix du propriétaire. Des quantités d’unités différentes ne sont jamais additionnées ; elles restent distinctes. Les lignes suivent l’ordre Bon, Type, Date et heure, Article, Quantité, Prix unitaire, Montant, Observation, Actions.

## Vérifications

- Recettes privées dédiées : stock initial et reprise, création idempotente, atomicité, numérotation concurrente, préférences et exports réels, règlements SQL/API et concurrence.
- Recette intégrée sur une structure privée neuve : stock initial, puis traçabilité des règlements, puis préférences et exports, tous réussis.
- Application réelle : 56 autres tables inchangées, lignes historiques conservées, quatre rattachements documentaires, stocks et identifiants de mouvements inchangés. Les treize commentaires de contraintes implicites sont ajoutés sans changement de données.
- Diagnostic Django sur SauverNdeko : **219 contrôles GET réussis**, en connexion PostgreSQL réellement en lecture seule.
- Interface : **246 contrôles SSR et de fonctions réussis**, dont le bouton unique Réglages, les clics sur les quantités et les téléchargements CSV/XLSX ; compilation Vite réussie.
- Les deux structures SQL canoniques sont restaurées en bases privées et comparées au catalogue installé, définitions et commentaires inclus. Le paquet d’installation neuf restaure les 20 définitions de registres, sans préférence personnelle, compte, entreprise ou article.

La recette technique ne remplace pas l’acceptation utilisateur. La vérification visuelle dans le navigateur intégré reste limitée par sa permission enregistrée sur localhost ; aucun contournement n’a été utilisé.

## Références techniques

- [Stock initial et numérotation](../SQL/documentation/Stock_Initial_Documents_20261028.md).
- [Préférences et exports](../SQL/documentation/Preferences_Tableaux_Exports_20261028.md).
- [Traçabilité et contrôles SQL](../SQL/documentation/Tracabilite_Logistique_20261028.md).
- Migrations : `20261028_01` à `20261028_04` dans `backend/database/migrations` ; sources canoniques SQL synchronisées pour les installations neuves. Une base existante reçoit les migrations, jamais un rejeu des fichiers de structure.
