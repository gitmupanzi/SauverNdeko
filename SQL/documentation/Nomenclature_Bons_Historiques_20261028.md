# Reprise de nomenclature des bons — 28 octobre 2026

La migration `20261028_06_nomenclature_bons_historiques.sql` répond à la demande explicite d’harmoniser les anciens bons. Elle complète la conservation initiale des codes lors des migrations01 et05 ; elle ne modifie pas ces fichiers historiques.

## Résultat installé

**17 bons sur 21** sont renommés dans SauverNdeko selon leur nature : `BE-ID`, `BS-ID` ou `CMD-ID`. Par exemple, `cmd-135` devient `BS-135` et `cmd-134` devient `BE-134`. Les quatre codes déjà conformes restent identiques. Les identifiants et types de documents sont conservés.

`logistique.T_BonCodeHistorique` conserve les correspondances exactes, l’entreprise constatée, l’instant réel PostgreSQL, le motif, la migration et l’utilisateur SQL. Il ne prétend pas attribuer la reprise à un utilisateur applicatif inconnu. Le journal est fermé après alimentation et refuse tout CRUD ; il reste consulté par les vues autorisées et la fonction de référence documentaire. L’absence de FK vers un document supprimable conserve la preuve, sans autoriser la réutilisation de l’identité du bon.

Aucune colonne n’est ajoutée à T_Commande. Les vues V_Commande, V_CommandeDetail et V_CommandeOverview exposent AncienCodeCmd et RenumeroteLe. Les recherches retrouvent l’ancien code dans le même périmètre d’entreprise et les clics utilisent l’identifiant courant. La colonne Ancien code est facultative dans Bons de stock ; les deux champs sont exportables sur choix explicite, masqués et non exportés par défaut. L’ordre et les préférences existants sont conservés.

## Conservation des documents et du stock

CodeCmd est la seule valeur modifiée dans les bons. Les 64 autres tables antérieures sont identiques ; seuls les deux catalogues Bons/Lignes reçoivent les options supplémentaires. Les lignes, quantités, prix, devises, factures, règlements, avoirs, retours, inventaires, coûts, lots, mouvements, justificatifs, identités et audits originaux restent conservés. Les références libres telles que « Retour de cmd-130 » ne sont pas remplacées.

La migration verrouille les bons, construit une correspondance exacte puis adapte temporairement sept gardes, uniquement pour remplacer CodeCmd sur ces couples ancien/nouveau. Elle restaure leurs définitions intégrales avant validation et supprime son aide temporaire. Aucun droit, drapeau GUC, contournement permanent, mouvement ou recalcul métier n’est ajouté. Le code reste ensuite immuable dans l’application.

Un bon imprimé aujourd’hui porte son nouveau code et mentionne l’ancien. Les PDF de facture, reçu ou avoir émis avant la reprise gardent la référence du bon à leur émission grâce à fn_code_bon_a_date et à leur date technique de création. Une date technique historique absente conserve l’ancienne référence ; aucune date d’émission n’est inventée. Les documents émis après la reprise utilisent la nouvelle référence. Le service autorise d’abord le parent et son entreprise avant toute résolution temporelle.

## Vérifications

- Sauvegarde DB et médias vérifiée avant application ; correspondances et préconditions contrôlées dans la transaction.
- 52 contrôles SQL privés, préparés avec 112 contrôles de chaîne logistique et 31 d’inventaires : conservation des données, documents protégés, codes courts uniques, journal immuable et restauration exacte des sept gardes.
- 65 contrôles API/PDF privés : recherche et exports des alias, refus hors entreprise, conflits de versions, rejeux de création/édition/réception/facture/paiement/retour/avoir sans doublon et conservation des instantanés.
- 121 contrôles frontend simulés et 246 contrôles de régression, compilation Vite réussie ; ancien code en lecture seule dans le 360 et la traçabilité. Deux PDF fictifs rendus et inspectés (bon courant et facture historique), sans défaut de mise en page. Aucune validation visuelle du navigateur applicatif n’est revendiquée.
- Deux structures canoniques restaurées en bases privées vides : 67 tables globales ou 57 métier, 80 vues et 126 triggers ; définitions et commentaires identiques à la source. Les objets du journal et les six colonnes de vues ajoutées sont commentés.
- Après redémarrage, 219 contrôles GET réussissent sur SauverNdeko en connexion réellement en lecture seule. La recherche du registre par `cmd-135` retourne bien le même identifiant135, code actuel `BS-135`, ancien code `cmd-135` et facture `fac-135`. Tous les bons suivent leur nomenclature et le journal contient les 17 correspondances attendues.

Les preuves détaillées de recette et de sauvegarde restent privées dans .runtime. Les fichiers canoniques décrivent la nouvelle structure, sans données ; une base existante reçoit uniquement la migration nécessaire, jamais un rejeu de la structure.
