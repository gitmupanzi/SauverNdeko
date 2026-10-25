# Contrôle de livraison — adaptation SauverNdeko

24 octobre 2026, version documentaire 3.0.

## Périmètre livré

Skill, références, modèles Markdown, charte JSON, copie exacte du logo du projet et contrôles synthétiques. Les principes documentaires sont raccordés aux consignes ERP, backend et frontend. L’identité d’un autre projet n’est plus utilisée dans les règles actives ou les modèles.

## Vérifications

- Validation du frontmatter et du nom par le validateur du skill-creator.
- Contrôle local strict : liens, références réelles du projet, charte, logo et manifeste SHA-256.
- Tests d’affichage/parité sur fixtures ERP fictives : identifiants, décimaux, devises explicites/absentes, dates, inconnus, portées, organisations et résultats entre formats.
- Comparaison de la copie du logo avec frontend/public/sauverndeko-logo.jpg.

Résultat du contrôle local : 32 fichiers, 44 liens internes, trois dépendances du dépôt présentes et aucune rupture. Les 20 tests synthétiques passent ; le validateur skill-creator accepte le skill.

## Limites exactes

Aucun document Word, classeur Excel ou PDF réel n’est généré par cette adaptation ; aucun rendu visuel de fichier Office/PDF n’est donc déclaré validé. Les helpers de l’application ne sont pas modifiés : l’export HTML/.xls et l’impression navigateur restent à raccorder à un moteur natif.

Les tests synthétiques ne vérifient ni l’exhaustivité des requêtes serveur, ni les droits API, ni la pagination des exporteurs réels. Pour chaque export implémenté, suivre le modèle de recette et inspecter les fichiers effectivement produits. Aucune donnée métier réelle, police distribuée ou publication externe n’est incluse.

## Mise à jour du 25 octobre 2026 — Excel 3.1

Le propriétaire demande désormais un tableau direct : en-têtes en première ligne, données dès la deuxième, gris clair et texte sombre. Aucun logo, titre ou bloc de présentation ne précède les listes. Le contexte et le décompte restent dans Informations. La charte JSON et les règles du skill reprennent cette préférence.

Le moteur XLSX serveur existant est raccordé aux trois familles d’exports logistiques : registres, détails d’indicateurs et dossiers de suivi. La négociation HTTP accepte le type Excel envoyé par le navigateur ; les refus restent en JSON. Le tri ajoute des clés stables pour conserver la parité avec la liste.

Vérifications : six tests de régression HTTP/présentation sans base, vingt tests documentaires synthétiques, contrôle strict du skill et dix lectures API sur SauverNdeko sans écriture. Les quatre fichiers réels contrôlés contiennent respectivement 1 article, 4 bons, 1 article périmé et 0 résultat ; valeurs, ordre, types natifs, absence de formules injectées, filtres, volets et couleurs sont vérifiés avec openpyxl. Les feuilles Données Articles/Bons sont rendues et inspectées avec le moteur artifact-tool. Ceci ne constitue pas une validation de l’impression dans Microsoft Excel ni une validation des formats Word/PDF.
