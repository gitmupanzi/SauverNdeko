# Contrôle qualité documentaire

## Niveaux de vérification

| Niveau | Preuve attendue | Ce que cela ne prouve pas |
|---|---|---|
| Skill | Liens, configuration, logo, empreintes, exemples | Exporteurs de l’application conformes |
| Génération | Fichier natif lisible, contenu attendu, types/valeurs | Pagination et rendu visuel corrects |
| Rendu | Pages inspectées, tableau/texte lisibles, impression Excel contrôlée | Justesse d’une règle métier non vérifiée |
| Intégration | Périmètre, droits, parité écran/détail/export et erreurs testés | Validation humaine ou conformité non évaluée |

Consigner les niveaux effectivement couverts. Le contrôle du dossier et les tests synthétiques ne remplacent pas les niveaux suivants.

## Contrôles d’un export applicatif

- Identité de l’émetteur et logo du bon contexte ; absence d’identité d’un autre client.
- PDF métier régénéré après modification du profil : identité émettrice courante, tiers et valeurs historiques inchangés ; archive téléchargée identique à son contenu enregistré.
- Quatre combinaisons persistées en-tête/pied : nom d’entreprise toujours visible, pied entièrement retiré lorsqu’il est désactivé et aucun dialogue avant le téléchargement.
- Logo normalisé et autorisé, sans octets dans les JSON/audits/exports ; rendu sans logo, avec transparence et avec identité longue sur plusieurs pages.
- Références, critères, dates et portée conformes à la demande.
- Même résultat autorisé entre formats, sans recalcul métier local.
- Codes texte, zéros initiaux, grands identifiants, montants/quantités numériques et dates natives.
- Absence, zéro, erreur et non-applicable distingués ; devise/unité jamais déduites.
- Totaux à leur grain et sous-totaux sans double compte ; quantités/devises hétérogènes séparées.
- Résultat vide, très long, désignation longue, caractères accentués, montant négatif et donnée manquante correctement présentés.
- Refus d’accès, changement d’organisation et téléchargement obsolète correctement traités.
- Texte importé ressemblant à une formule conservé comme texte ; absence de lien ou macro non demandé.

## Contrôle par format

Excel : ouvrir et lire les cellules/types, filtres, volets, zones d’impression et formules éventuelles. Vérifier absence de ####, coupure et erreur de calcul ; confirmer le moteur de recalcul utilisé lorsqu’il y en a un.

Word : vérifier styles, listes natives, champs, largeurs de tableaux, en-têtes répétés, paragraphes et pagination. Rendre les cas de recette et inspecter toutes leurs pages.

PDF : ouvrir le fichier final, inspecter toutes les pages des cas de recette, comparer les données avec la source, vérifier texte sélectionnable, accents, marges, tableaux et pagination. Une extraction textuelle correcte ne valide pas une mise en page.

## Réparation et bilan

Corriger la source ou le gabarit, régénérer puis refaire les contrôles affectés. Décrire la limite réelle si un moteur de conversion ou une police manque. Ne pas annoncer une compatibilité Office, une certification ou une validation humaine absente.

Utiliser le [modèle de recette](../modeles/recette_documentaire.md) pour un export réellement modifié. Les données de test sont inventées et restent distinctes des données de l’organisation.
