# Recette des parcours Logistique — 26 octobre 2026

## Isolation

Les sauvegardes UI ont été exécutées uniquement sur le serveur local de recette 5192, connecté à `sauverndeko_test_ui_20261026`, clone de l’installation finale. Les appels API et d’authentification du navigateur ont été redirigés vers ce serveur ; aucun ajout fictif dans SauverNdeko. Le banc et ses médias sont hors du dépôt. La consultation réelle de COUSP a bloqué toutes les mutations ; aucune connexion SMTP réelle n’a été tentée.

## Parcours vérifiés

- Les onze onglets logistiques s’ouvrent sans erreur JavaScript : tableau de bord, dossiers, tiers, articles, lots, bons, lignes, mouvements, inventaires, factures et règlements.
- Articles : création et modification par le même formulaire, reprise des informations complémentaires, toutes les rubriques Produit 360, navigation des sous-onglets au clavier.
- Tiers : création et fiche 360 ; Bons : ajout depuis le catalogue, quantité/prix, sauvegarde et réouverture du formulaire avec ses valeurs.
- Inventaire : comptage enregistré, modification, validation, puis annulation avec motif obligatoire. Les services métier produisent les écritures ; aucun mouvement ajouté directement par le frontend.
- Finance : facture créée depuis le menu du bon, PDF de facture téléchargé ; règlement créé depuis Factures, reçu PDF téléchargé. Les téléchargements ont une signature PDF valide. Le menu du bon facturé contient aussi entrée/sortie/livraison selon son type, facture et Excel.
- CUMP : confirmation motivée d’un coût à six décimales et affichage exact après sauvegarde.
- Identité documentaire : sauvegarde réelle privée, perte simulée de la réponse après commit, champs figés puis rejeu de la même demande ; profil confirmé. Le renommage de l’entreprise actualise le sélecteur sans rechargement de page. La consultation réelle de COUSP affiche les coordonnées manquantes sans données inventées et tient sur un écran de 390 px.
- Messagerie : défauts fournis par le serveur, échec de connexion simulé puis reprise réussie, mention explicite d’absence d’envoi. Les deux réponses de test sont simulées, sans contact SMTP.
- Permissions : compte fictif avec `canWriteData=true` mais module en consultation, sans gestion ni export. Ajout/modification/lignes et exports restent désactivés ; POST direct refusé avec 403. Le profil documentaire reste consultatif. Le passage vers la seconde entreprise vide efface les anciens résultats.

## Corrections issues de la recette

Le registre Bons ne fournissait pas le drapeau activant la création de facture dans son menu ; le backend expose maintenant ses capacités canoniques et le parcours Finance passe. Les listes Articles/Bons/Lignes, documents de ligne et documents métier utilisent désormais aussi le droit d’export du rôle. Les lignes de bon réutilisent le droit d’écriture de l’entreprise active. Les champs multilignes du profil documentaire ont un libellé accessible stable.

Les premières attentes échouées du harnais (choix d’entreprise perdu par rechargement complet, libellé de fermeture distinct, date de début de licence fictive interprétée dans un autre fuseau) ont été corrigées dans le banc ; elles ne sont pas présentées comme des défauts métier. Les preuves finales ciblées remplacent ces tentatives.

## Limites

Cette recette couvre les parcours ci-dessus avec un petit jeu cohérent ; elle ne remplace pas les tests SQL des restitutions, avoirs, lots, concurrence et droits. Les coordonnées légales réelles et les coûts d’ouverture historiques doivent être confirmés par l’entreprise ; aucune valeur comptable ou identité légale n’est inventée. Les mesures de charge et leur limite de validation différée sont décrites dans `recette-volume-logistique-20261026.md`.

## Vérification finale

Compilation Vite de clôture réussie : 307 modules transformés, sans erreur. Le backend répond200 sur5000 et le frontend200 sur5174 après redémarrage avec la correction de facturation. Le serveur de recette privé5192 a été identifié par son chemin et arrêté ; les services réels restent actifs. Aucun test d’écriture n’a visé SauverNdeko.
