# Parité et traçabilité des exports

## Même résultat autorisé

Pour un même document et la même portée, Excel, Word et PDF conservent références, organisation, critères appliqués, dates, unités/devises, valeurs, réserves et état de validation. Les mises en page diffèrent, pas la signification des montants ou des contrôles.

Les exports ne recalculent pas une logique parallèle. Ils consomment les vues/services communs décrits dans [l’intégration](integration_plateforme.md). Une donnée historique figée reste attachée à sa date ; un stock courant n’est pas présenté comme le stock de fin d’une ancienne période.

## Contexte à tracer

Adapter aux objets réellement disponibles : identifiant du document/export, type, organisation autorisée, génération et fuseau connu, période ou date de situation, filtres appliqués, portée page/synthèse/complet, ordre de tri, nombre de lignes et version de charte. L’identifiant de version source est repris lorsqu’il existe ; ne pas inventer un modèle d’exécution ou un job absent du backend.

Le contexte essentiel figure dans le document. La traçabilité détaillée peut rester dans les métadonnées internes de l’export ; ne pas imposer une feuille Sources ou de longs commentaires à tous les fichiers.

## Exhaustivité

Page affichée, fiche 360, synthèse et Tous les résultats filtrés sont quatre portées distinctes. Le nom du fichier et le contexte doivent rendre la portée compréhensible. Les lignes d’une page limitée ne permettent pas de promettre un export complet.

Pour un jeu complet, appliquer les droits et critères avant agrégation et pagination d’affichage. Sur un export long, figer ou borner la lecture afin qu’une mutation entre pages ne produise ni doublon ni omission silencieuse. Afficher l’échec si l’exhaustivité ne peut pas être assurée, sans télécharger un ancien résultat d’un autre contexte.

## Données et types

Conserver séparément montants source, cumuls de règlements et restes recalculés. Les quantités de plusieurs unités et les montants de plusieurs devises ne forment pas un total commun. Une devise absente reste non renseignée. L’arrondi d’affichage ne réécrit pas la précision source ou les calculs du backend.

## Nommage

Utiliser un nom lisible tel que SauverNdeko_Organisation_Commandes_2026-10-24_Complet.xlsx, en remplaçant seulement les éléments réellement connus. Éviter noms de personnes, secrets, chemins privés et caractères interdits. Une référence de document n’est pas créée par le nom de téléchargement.

## Vérification

Comparer des résultats normalisés des trois formats : mêmes codes, dates, unités, montants et limites. Contrôler aussi type des cellules, nombre de lignes et portée. La comparaison d’un manifeste JSON avant rendu ne prouve pas à elle seule les valeurs contenues dans les fichiers générés ; il faut lire ces fichiers dans la recette applicative.
