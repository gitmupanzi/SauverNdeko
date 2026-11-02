# Caisse

Le module **Caisse** suit les encaissements, les décaissements et les contrôles physiques de trésorerie. Il utilise le schéma `operations`, accessible depuis `/caisse`. Chaque caisse appartient à une entreprise et possède une devise immuable. Plusieurs caisses peuvent utiliser la même devise dans une entreprise.

## Accès

Le module exige une licence active de l’entreprise et les droits du compte. Son activation se gère dans l’administration des licences ; son installation n’active pas automatiquement une nouvelle souscription pour les entreprises existantes. Le compte d’administration global conserve sa consultation transversale. Pour écrire, il choisit une entreprise active.

Le tableau de bord sépare les montants par devise. Les indicateurs ouvrent la liste concernée dans la page. Les registres **Caisses**, **Écritures** et **Clôtures** disposent de recherche, filtres, tri, pagination, consultation et exports Excel/CSV selon les droits.

## Ouvrir une caisse

Créer la caisse avec son nom, sa devise et, si nécessaire, son type et son responsable. Son code est automatique. Son solde commence à zéro. Pour reprendre une encaisse réellement disponible, enregistrer une entrée justifiée : saisir un solde dans la fiche ne constitue pas une écriture de trésorerie.

La désactivation d’une caisse exige un solde nul et aucun brouillon actif. L’historique et les clôtures restent consultables.

Les types et motifs proposés viennent des références centralisées. Changer un libellé ne change pas le sens financier des écritures déjà enregistrées.

## Préparer et valider une écriture

Choisir la caisse, le sens **Entrée** ou **Sortie**, la date et l’heure, le montant, le libellé et les références utiles. Un brouillon n’affecte pas le solde. Il peut être modifié ou désactivé avant sa validation.

La validation est transactionnelle et actualise le solde une seule fois. Une sortie ne peut rendre le solde négatif. Les montants sont traités exactement, avec deux décimales au maximum. Chaque nouvelle tentative utilise la même demande pour éviter un double encaissement ou décaissement.

Une écriture validée est conservée. Pour corriger une écriture autonome, utiliser **Contrepasser**, avec un motif obligatoire. Une écriture du même montant et de sens inverse est créée ; l’original reste visible avec son lien de compensation. Une écriture déjà compensée ne peut pas être compensée à nouveau.

## Encaisser une facture Logistique

Dans **Logistique → Règlements → Nouveau règlement**, choisir la facture et renseigner le règlement. Lorsque le compte dispose des droits de gestion Caisse, **Enregistrer en caisse** propose les caisses actives de la même entreprise et de la même devise. La sélection est facultative.

Avec une caisse sélectionnée, le règlement et son entrée validée sont enregistrés dans une seule transaction. Si un contrôle échoue, aucun des deux n’est conservé. Une nouvelle tentative ne crée pas de doublon. Sans sélection, le comportement du règlement existant est conservé, sans écriture de caisse implicite.

Un règlement lié au journal de caisse ne peut plus être modifié ou supprimé isolément. Sa contrepassation directe est également refusée : une correction doit traiter ensemble la facture, le règlement et son effet financier. Les règlements historiques ne sont pas automatiquement repris en caisse.

## Clôturer et contrôler

Choisir une caisse, relever l’encaisse physique puis enregistrer la date et l’heure de clôture. Le serveur capture le solde théorique et calcule l’écart avec le montant compté. Un écart exige une justification. La clôture ne corrige pas automatiquement le solde.

Les clôtures restent immuables. Les contrôles refusent les clôtures incohérentes et les validations antidatées dans une période déjà clôturée. Les éventuelles régularisations sont des écritures distinctes, justifiées et validées dans la période ouverte.

## Périmètre

Les vues, contraintes, fonctions, triggers et l’audit PostgreSQL portent les soldes et les invariants du journal. Le backend contrôle les autorisations, l’entreprise, les révisions et les demandes rejouées ; le frontend ne recalcule pas les soldes métier.

Ce périmètre ne réalise ni conversion de devises, ni virement bancaire réel, ni comptabilité générale. Il ne crée aucun règlement, encaissement ou solde fictif lors de l’installation. Les exports et le Guide utilisateur suivent les droits du module.

## Installation et vérifications du 2 novembre 2026

Les migrations `20261102_03_caisse.sql`, `20261102_04_classification_applications.sql` et le complément documentaire `20261102_05_commentaire_catalogue_caisse.sql` ont été appliqués dans **SauverNdeko** après sauvegarde, restauration exacte des 73 tables et épreuve sur copie privée. Les données métier, les licences et leurs activations existantes ont été préservées. Aucune caisse ni écriture d’essai n’a été créée dans la source.

- 12 tests API Caisse : exactitude, droits, deux entreprises, révisions, rejeu, validation, contrepassation, clôture, exports, préférences et identité des devises.
- 9 tests API du lien règlement–caisse : transaction unique, rejeu, permissions, autre entreprise/devise, caisse inactive, clôture et refus des corrections isolées.
- 2 tests API de classification ; 9 scénarios PostgreSQL Caisse, dont sorties concurrentes, et 4 scénarios de classification.
- Régression : 12 tests TVA/facture/avoir/PDF, 19 tests Guide utilisateur et 16 tests Paramètres réussis sur base privée.
- 491 assertions JavaScript et 2 976 contrôles CSS sur les trois thèmes ; compilation Vite réussie. Les handlers de réessai du règlement conservent le montant, la caisse et le même identifiant de demande.
- Diagnostic source : 345 routes GET conformes sous connexion PostgreSQL en lecture seule. Backend et frontend redémarrés sur les ports habituels ; accès anonyme à la caisse refusé.
- Sources SQL complètes et métier restaurées avec définitions et commentaires identiques, sans données. Deux installations neuves réussies : 13 applications et 6 correspondances Caisse, aucun client. Le seed ordonné du catalogue est vérifié par 4 tests et une épreuve avec ordre physique inversé.

Les tests d’interface utilisent des composants réels avec DOM et transport simulés. La recette interactive dans le navigateur reste à effectuer ; ces vérifications techniques ne constituent pas une validation client de l’interface.
