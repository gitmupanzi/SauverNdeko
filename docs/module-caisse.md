# Caisse

Le module **Caisse** suit les encaissements, les décaissements et les contrôles physiques de trésorerie. Il utilise le schéma `operations`, accessible depuis `/caisse`. Chaque caisse appartient à une entreprise et possède une devise immuable. Plusieurs caisses peuvent utiliser la même devise dans une entreprise.

## Accès

Le module exige une licence active de l’entreprise et les droits du compte. Son activation se gère dans l’administration des licences ; son installation n’active pas automatiquement une nouvelle souscription pour les entreprises existantes. Le compte d’administration global conserve sa consultation transversale. Pour écrire, il choisit une entreprise active.

Le tableau de bord sépare les montants par devise. Les indicateurs ouvrent la liste concernée dans la page. Les registres **Caisses**, **Écritures** et **Clôtures** disposent de recherche, filtres, tri, pagination, consultation et exports Excel/CSV selon les droits.

Le menu **Réglages → Références** indique la catégorie et son identifiant pour chaque liste. Ouvrez **Voir les valeurs** pour rechercher une abréviation ou un identifiant.

## Saisir une ou plusieurs lignes

Depuis **Nouvelle caisse**, **Nouvelle écriture** ou **Nouvelle clôture**, complétez la première ligne puis utilisez **Ajouter une ligne** ou **Coller depuis Excel**. Pour le collage, copiez les en-têtes et les données. Les listes reconnaissent leur libellé ou leur identifiant. Le panier accepte jusqu’à 100 lignes et indique les corrections à apporter avant l’enregistrement. Si une ligne échoue, toute la demande est annulée.

Dans **Nouvelle caisse**, **Télécharger le modèle Excel** fournit une feuille **Caisses**, avec les en-têtes dès la première ligne, ainsi que les choix autorisés pour l’entreprise dans **Options**. Complétez le nom, la devise et les informations facultatives, puis utilisez **Importer un fichier Excel** pour ajouter les lignes au panier. Le fichier `.xlsx` doit contenir au maximum 100 lignes et peser au plus 4 Mo. Les formules ne sont pas acceptées : collez leurs valeurs dans le classeur avant de l’importer.

L’import prépare la saisie sans créer de caisse. Vérifiez et corrigez les lignes signalées, puis cliquez sur **Enregistrer l’ensemble**. Une erreur de lecture conserve le panier existant. Chaque caisse créée commence avec un solde nul ; le modèle ne permet pas d’importer un solde ou des écritures financières.

Les paniers **Écritures** et **Clôtures** proposent également leur modèle Excel et l’import de fichiers .xlsx vers le panier (100 lignes, 4 Mo). Les références de caisse, de devise, de type et de mode sont celles de l’entreprise active. Vérifiez et corrigez les valeurs avant l’enregistrement. Le mode de validation s’applique lorsque vous enregistrez le panier. Le solde théorique et la révision de clôture viennent du serveur.

## Choisir le mode de validation

Les paramètres de validation s’appliquent à l’entreprise sélectionnée. Leur modification exige une habilitation dédiée et figure dans le journal d’audit.

- **Validation manuelle.** Enregistrez l’écriture en brouillon, puis utilisez **Valider** ou **Valider la sélection** avec un compte habilité.
- **Validation par un autre agent.** Un agent désigné et actuellement habilité valide le brouillon d’un autre auteur. Chaque agent désigné peut valider seul. Dans **Agents habilités**, recherchez puis choisissez chaque personne. Retirez au besoin un agent de la sélection, renseignez le motif et enregistrez. Si la liste est vide, vérifiez la licence Caisse de l’entreprise et les droits de ses agents actifs, puis cliquez sur **Actualiser les agents**.
- **Validation automatique à l’enregistrement.** L’enregistrement applique les mêmes contrôles de caisse et valide les écritures conformes dans la transaction de saisie.

Les nouvelles entreprises commencent en mode manuel. La migration conserve le fonctionnement des entreprises existantes. Une modification du mode s’applique aux prochaines écritures. Les brouillons conservent le mode fixé lors de leur création, et la validation tient compte des habilitations en vigueur.

## Ouvrir une caisse

Créer la caisse avec son nom, sa devise et, si nécessaire, son type et son responsable. Son code est automatique. Son solde commence à zéro. Pour reprendre une encaisse réellement disponible, enregistrer une entrée justifiée : saisir un solde dans la fiche ne constitue pas une écriture de trésorerie.

La désactivation d’une caisse exige un solde nul et aucun brouillon actif. L’historique et les clôtures restent consultables.

Les types et motifs proposés viennent des références centralisées. Changer un libellé ne change pas le sens financier des écritures déjà enregistrées.

## Préparer et valider une écriture

Choisir la caisse, le sens **Entrée** ou **Sortie**, la date et l’heure, le montant, le libellé et les références utiles. Un brouillon n’affecte pas le solde. Il peut être modifié ou désactivé avant sa validation.

La validation est transactionnelle et actualise le solde une seule fois. Une sortie ne peut rendre le solde négatif. Les montants sont traités exactement, avec deux décimales au maximum. Chaque nouvelle tentative utilise la même demande pour éviter un double encaissement ou décaissement.

Une écriture validée est conservée. Pour corriger une écriture autonome, utiliser **Contrepasser**, avec un motif obligatoire. Une écriture du même montant et de sens inverse est créée ; l’original reste visible avec son lien de compensation. Une écriture déjà compensée ne peut pas être compensée à nouveau.

## Encaisser une facture Logistique

Dans **Logistique → Règlements → Nouveau règlement**, choisir la facture et renseigner le règlement. Lorsque le compte dispose des droits de saisie et de validation, **Enregistrer en caisse** propose les caisses actives de la même entreprise et de la même devise, si la politique permet à ce compte de valider immédiatement. En mode **Validation par un autre agent**, saisissez le règlement dans Logistique, puis faites valider l’encaissement dans le journal Caisse par un agent désigné. La sélection est facultative.

Avec une caisse sélectionnée, le règlement et son entrée validée sont enregistrés dans une seule transaction. Si un contrôle échoue, aucun des deux n’est conservé. Une nouvelle tentative ne crée pas de doublon. Sans sélection, le comportement du règlement existant est conservé, sans écriture de caisse implicite.

Un règlement lié au journal de caisse ne peut plus être modifié ou supprimé isolément. Sa contrepassation directe est également refusée : une correction doit traiter ensemble la facture, le règlement et son effet financier. Les règlements historiques ne sont pas automatiquement repris en caisse.

## Contrôler et clôturer

Pour contrôler l’encaisse, ouvrez le journal, filtrez par caisse et par période, puis comparez le montant physique compté au solde validé et aux mouvements encore en brouillon. Le solde prévisionnel comprend les brouillons actifs. Les montants sont présentés dans la devise de la caisse.

La prévisualisation d’une validation de sélection indique le nombre d’écritures, les entrées et sorties par devise ainsi que les motifs de blocage. Vérifiez les lignes choisies avant de confirmer. Si une ligne est bloquée ou a changé, rechargez la liste et corrigez la sélection avant de relancer la validation.

Dans **Clôtures**, choisissez la caisse, renseignez l’heure et le montant compté, puis confirmez. Le serveur capture le solde théorique et calcule l’écart avec le montant compté. Un écart exige un motif. La validation de fin de journée reste une action volontaire, distincte de la clôture.

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
