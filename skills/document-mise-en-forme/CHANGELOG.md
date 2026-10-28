# Historique du skill

## 3.2 — 28 octobre 2026 — Identité de présentation des PDF

- Demande explicite : les PDF métier générés ou régénérés utilisent le profil courant de l’entreprise, avec son logo et ses coordonnées réels.
- Les identités historiques, tiers et montants restent conservés ; les fichiers archivés gardent leurs octets.
- Options d’en-tête/pied persistées, activées par défaut et appliquées directement au téléchargement ; nom d’entreprise toujours visible. Le pied désactivé est entièrement retiré.
- Règles de confidentialité du logo et recette des quatre combinaisons, des identités longues et des documents multipages.
- Moteur PDF logistique : Vera et Vera Bold fournies par ReportLab et embarquées dans les fichiers, sans dépendance à une police du système hôte.
- Profil documentaire avec téléphone principal et secondaire facultatif ; pied limité au nom, identifiants, mentions et pagination.

## 3.1 — 25 octobre 2026 — Tableaux Excel

- Préférence explicite du propriétaire : en-têtes en première ligne, données dès la deuxième, sans logo ou bandeau ; gris clair et texte sombre au lieu du bleu.
- Contexte conservé dans Informations ; présentation de la feuille principale limitée au tableau.
- Contrat HTTP XLSX/erreurs JSON, tri stable partagé et recette de téléchargement des exports applicatifs.

## 3.0 — 24 octobre 2026 — SauverNdeko

- Adaptation de la copie initiale du skill d’imf_BB à l’ERP SauverNdeko.
- Remplacement de l’identité et du logo hérités par la marque du projet, avec émetteur configurable selon l’organisation autorisée.
- Retrait des parcours et dépendances propres à la microfinance, des anciens chemins Django et des promesses d’exporteurs non présents.
- Charte commune JSON, règles natives Excel/Word/PDF, contrats de stock/commande/règlement, modèles opérationnels et routage dans le dépôt.
- Exemples et tests repris sur des données ERP fictives ; distinction entre validation du skill et conformité d’exporteurs applicatifs.

La version 2.0 provenait du skill documentaire du projet d’origine ; ses validations n’attestaient pas les exports de SauverNdeko. La provenance de l’adaptation est conservée dans references/sources_et_migrations.json.
