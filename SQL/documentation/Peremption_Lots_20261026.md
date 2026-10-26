# Conservation du stock et péremption par lot

## Sources et règles

La migration `20261026_05_peremption_lots.sql` conserve les quantités et mouvements existants. `V_LotArticleStock` et `V_LotDisponibilite` portent la date du lot, son stock restant, son état et le délai d’alerte. Le délai explicite `T_Article.NbreJoursAlerteArticle` prime sur le défaut `T_Entite.AlertePeremptionJours` (30 jours à la création).

`V_ArticlePeremption` agrège uniquement les quantités encore présentes. Un lot épuisé ne déclenche plus une alerte Article. Un lot archivé qui conserve du stock reste compté. La date générale de l’article ne s’applique qu’à la quantité réellement sans lot. Les quantités de lots sans date restent identifiées. Les flags communs de `V_Article` alimentent indicateurs, dossiers automatiques, filtres, listes et exports. Une référence peut relever simultanément de Péremption proche et Articles périmés lorsque des lots différents sont concernés.

FEFO reste une proposition explicite. Les lots archivés et épuisés sont exclus ; les lots périmés sont exclus par défaut. Ni le clic FEFO ni la lecture des alertes ne créent un mouvement.

## Politique de sortie

Articles → Conservation règle la politique de l’entreprise active. Le mode initial reste « Signaler et autoriser ». L’administrateur de plateforme peut choisir « Bloquer, sauf dérogation autorisée » et modifier le délai. Le serveur contrôle entreprise cible, droits et révision ; le changement est audité. Une politique d’entreprise ne modifie pas les autres entreprises.

En mode bloquant, le trigger `controler_sortie_lot_perime` refuse un nouveau prélèvement sur un lot périmé. La date du contrôle est le jour métier Africa/Kinshasa, calculé explicitement dans PostgreSQL ; ni le fuseau de la connexion ni l’antidatage du bon ne contournent le blocage. Le compte global peut saisir un motif de 10 à 1 000 caractères dans la ventilation du lot. La ventilation conserve le motif, l’auteur réel et un horodatage serveur. La dérogation n’ajoute aucun mouvement. La règle concerne les lots identifiés : une date générale sans lot reste un signal de conservation, pas un blocage SQL implicite de toute la référence.

Le comptage peut enregistrer un motif de dérogation ; seul le compte global peut le valider si cette dérogation est nécessaire. Pour annuler une entrée correctrice d’inventaire devenue périmée, le motif d’annulation sert aussi de justification de la sortie compensatrice ; un administrateur global est requis. Un refus est atomique et le rejeu conserve le même mouvement compensateur.

## Vérification

Recette portable : `SQL/tests/test_peremption_lots.py`. Fournir explicitement `SAUVERNDEKO_TEST_DATABASE_URL` vers une base `sauverndeko_test_*` migrée jusqu’à 05. Aucune connexion de repli vers la base applicative.

49 contrôles ont passé sur une copie privée après 03+05 : stock périmé/proche/mixte, lots épuisés et archivés, stock sans lot, seuil entreprise/article, FEFO, défense SQL directe, motif et auteur, refus des dérogations locales, contexte d’entreprise, validation/annulation d’inventaire et rejeu sans double mouvement. Cette recette n’autorise pas de données fictives dans SauverNdeko.

L’état d’installation en environnement applicatif et la sauvegarde préalable sont consignés par la livraison coordonnée ; ce document seul n’atteste pas l’exécution sur la base réelle.
