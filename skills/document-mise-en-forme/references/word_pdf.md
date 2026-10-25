# Word et PDF SauverNdeko

## Mise en page commune

Suivre la [charte](charte_documentaire.md) et les valeurs de la [configuration](../assets/charte_sauverndeko.json). A4 portrait, marges gauche 2,5 cm et autres 2 cm ; texte Aptos 11 pt, titres 18/14/12/11 pt, interligne 1,15. Utiliser une section paysage pour un tableau large et conserver une taille lisible.

En-tête compact : logo proportionnel à gauche, identité de l’organisation émettrice si fournie, titre/référence à droite ou dessous. SauverNdeko identifie le logiciel ; il ne remplace pas l’émetteur. Le logo local fait 2 cm de large par défaut. Aucun nom, logo, adresse ou compte d’un autre client n’est repris.

Les informations utiles — référence, organisation, période/date de situation, portée et statut réel — restent visibles sans longs commentaires techniques. Une page de garde est utile pour un rapport long, pas obligatoire pour une fiche ou un bon d’une page.

## Word natif

Produire un .docx réel. Utiliser styles Normal, Titre, Sous-titre, Titre 1/2/3, Légende et un style de tableau SauverNdeko cohérent. Associer la numérotation hiérarchique aux styles lorsque le document la requiert ; listes et puces utilisent les mécanismes natifs, pas des numéros ou espaces tapés manuellement.

Les tableaux restent dans la largeur utile. Fixer des largeurs de colonnes explicites, répéter les en-têtes sur les pages suivantes, aligner chiffres à droite et placer l’unité/devise dans l’en-tête ou une colonne. Éviter une coupure de ligne métier courte entre deux pages et un titre isolé en bas de page. Laisser les longues observations se poursuivre proprement au lieu de produire un grand vide.

Pour les rapports multipages, pied compact : organisation, titre court, diffusion si utile, puis Page X sur Y avec champs automatiques. Une table des matières est automatique lorsqu’un document long la justifie. Les champs, numéros et table des matières sont effectivement actualisés avant livraison.

## PDF de diffusion

Produire un vrai fichier PDF, avec texte sélectionnable, accents et nombres lisibles. Le PDF reprend les mêmes données, périmètre, unités et réserves essentielles que le Word ou l’Excel source. Le nombre de pages peut changer selon le format ; les totaux et le sens ne changent pas.

Le moteur peut convertir le document source ou utiliser une mise en page PDF commune. Dans ce second cas, les données et paramètres restent partagés : ne pas réimplémenter les calculs. Une fenêtre d’impression du navigateur ne démontre pas qu’un PDF est généré, téléchargé et conforme.

Vérifier toutes les pages des cas de recette : aucun débordement, texte coupé, tableau hors page, logo déformé, page blanche involontaire ou pied superposé au contenu. Conserver les sauts de section, en-têtes répétés et pagination réelle, y compris après passage en paysage.

## Documents opérationnels

Une commande, un bon de livraison, une facture et un relevé de règlements sont des objets distincts. Les modèles utilisent les identifiants et données existants ; ne pas présenter une quantité commandée comme quantité livrée, ni un montant réglé d’en-tête comme une preuve de règlement. HT/TTC sont repris depuis le backend sans taxe inventée.

Les zones visa/signature restent vides dans un brouillon ; lorsqu’un statut de validation existe, reprendre celui de la source. Ne pas ajouter une approbation ou une mention juridique non fournie.

## Rendu et disponibilité des outils

La génération réussie d’un DOCX ne prouve pas sa pagination. Rendre le document avec le moteur disponible, inspecter les pages obtenues, corriger la source puis rendre de nouveau. Vérifier le PDF final, pas uniquement son texte extrait. Si une police manque, déclarer le repli et inspecter son effet ; ne pas joindre des polices au paquet.

Préserver les informations d’accessibilité réellement produites : titres structurés, ordre de lecture, libellés et descriptions utiles. Ne pas annoncer une certification d’accessibilité, d’archivage ou une compatibilité bureautique qui n’a pas été testée.

## Moteur logistique installé

Le service backend apps/logistique/documents.py produit les bons d’entrée, sortie et livraison, factures, reçus et avoirs. ReportLab utilise Helvetica comme police de repli, A4 et des tableaux à en-têtes répétés avec Page X sur Y. Les identités sont figées à l’émission des documents financiers ; les reprises historiques sont signalées. Les pièces PDF et images restent privées. Les PDF de recette ont été rendus et contrôlés sur une page et sur cinq pages. Une nouvelle modification du gabarit demande une nouvelle vérification de toutes les pages.
