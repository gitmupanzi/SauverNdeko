# Chargement frontend — 26 octobre 2026

## Modification livrée

Les pages de l’application, vues logistiques et contenus de consultation sont chargés à la demande par `lazyView`. Le contexte d’authentification, l’entreprise active, les dossiers et les fonctions de consultation restent montés. La navigation interne de Logistique conserve `startTransition` pour présenter une vue stable pendant un chargement. Le corps des fiches est désormais dans `ConsultationContent.jsx` ; le contrat public de `ConsultationProvider` (`useRead`, `ResultTable`, `IndicatorDetails` et `useConsultations`) est conservé.

Les états d’attente utilisent un espace réservé sans animation. Un échec de téléchargement ouvre un état accessible et une action explicite « Recharger la page ». Cette reprise a été vérifiée après interruption du téléchargement d’un module ; le navigateur peut mémoriser le rejet d’un import, ce qui rend un simple nouveau rendu insuffisant. Les erreurs de données API conservent leurs mécanismes de reprise locaux habituels.

## Mesures de compilation

Même code métier et configuration Vite, sorties produites hors du dépôt :

| Mesure | Avant | Après |
|---|---:|---:|
| JavaScript initial minifié | 1 044 771 octets | 361 346 octets |
| JavaScript initial gzip (mesure Python gzip) | 300 091 octets | 114 495 octets |
| Plus gros fichier JavaScript | 1 044 771 octets | 361 346 octets |

Réduction de 65,4 % du JavaScript initial et 61,8 % après compression. Le manifeste final comprend 57 fichiers JavaScript, dont Lots de stock chargé séparément (~20 Ko). Le warning de chunk supérieur à 500 kB a disparu sans relever sa limite. Les fonctions métier restent dans leurs fichiers différés : la taille totale de tous les modules n’est pas assimilée à la charge initiale. Le CSS global reste un poste à surveiller ; il n’a pas été réécrit pour obtenir ces chiffres.

## Vérifications réalisées

Sur le build de production servi par un aperçu local et avec toutes les écritures API bloquées : Connexion charge uniquement le JavaScript initial ; Dashboard → Articles → Produit 360 → Bons de stock fonctionne sans erreur JavaScript. Un module Articles volontairement indisponible présente une erreur lisible ; le rechargement reprend la page demandée.

Le formulaire CUMP a été vérifié séparément sur réponses API simulées : coût exact à six décimales, motif et confirmation obligatoires, révision opaque, rejeu du même UUID après réponse réseau perdue, pagination de 35 mouvements et passage aux lignes 26 à 35. Sur téléphone de 390 px, la fiche reste dans la largeur de l’écran ; l’en-tête conserve l’entreprise active sur une seconde ligne. Ces réponses simulées ne remplacent pas la recette du service PostgreSQL réel.

Après installation des migrations 04 à 08, une passe réelle sur `http://localhost:5174/logistique?onglet=lots` a confirmé un lot en vue globale et École Pilote Test, aucun lot dans COUSP ; le journal du lot contient deux écritures et son Excel est un téléchargement XLSX valide. La consultation CUMP du stock repris affiche « À initialiser » et conserve les coûts/valeurs absents comme `NULL` (« — »), sans prix catalogue de substitution ; son Excel se télécharge également. La lecture du même article depuis COUSP est refusée par 404. Zéro erreur JavaScript et aucune mutation durant cette passe.

La fenêtre mobile avait un décalage de 15 px dû à la réserve de barre de défilement : DrawerDialog est maintenant ancré à gauche sur téléphone. La vérification DOM donne x=0, largeur=390 px sur un écran de 390 px, avec fermeture visible et tableau défilant dans son conteneur. Le positionnement desktop et les commandes de largeur restent conservés.

Aucun temps de réponse représentatif de gros volumes métier n’est annoncé par ces mesures de bundling. Les mesures des listes, indicateurs et exports sur deux entreprises et 5 000 mouvements par article sont détaillées dans [la recette de volume](recette-volume-logistique-20261026.md), avec leurs limites de validation différée.
