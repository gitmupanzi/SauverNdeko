# Annuaire professionnel transversal — bilan du 3 novembre 2026

## Résultat

`/experts` utilise le shell ERP commun : annuaire paginé avec recherche par besoin, cartes ou tableau, critères, consultation latérale et messagerie. Les administrateurs autorisés disposent du registre Profils professionnels avec un formulaire commun d’ajout/modification. Compétences, prestations et affiliations sont enregistrées dans la même transaction que la fiche.

Les six familles catégorielles restent centralisées dans `referentiel` : secteur, profession, spécialité, compétence, prestation et type de lien. Les formulaires résolvent la configuration de chaque champ et présentent l’abréviation générique. Les réglages affichent les identifiants et libellés des catégories, leurs défauts et leurs valeurs. Les références historiques devenues incompatibles ne sont pas réattribuées.

## Évolutions SQL appliquées

- `20261102_06_professionnels_transversaux.sql` : propriétaire durable, publication explicite, présentation publique séparée des observations internes, révision et traçabilité ; tables de liaison compétences/prestations et termes de recherche rattachés à `T_Generique` ; vues publique et de gestion, fonctions et triggers commentés.
- `20261102_07_revision_details_professionnels.sql` : toute modification réelle d’un détail fait évoluer la révision du parent, même hors de l’API. Un UPDATE identique ne la modifie pas. Les versions, horodatages et audits sont annulés avec la transaction si l’écriture échoue.

SQL06 a été vérifiée en une seule passe sur une restauration privée de la source. La source a reçu SQL06 après contrôle d’empreintes de 74 tables, puis SQL07 après une nouvelle sauvegarde et restauration exacte de 77 tables. Les migrations ont conservé les données métier, comptes, rôles, licences, valeurs de référence existantes et correspondances personnalisées. Les nouvelles entrées sont uniquement des dictionnaires et métadonnées. Aucun profil fictif n’a été ajouté à SauverNdeko.

Les sources canoniques globales, métier et des domaines concernés ont été mises à jour depuis le catalogue compilé. Leur restauration en bases privées vides a donné des définitions et commentaires identiques. Le paquet neuf, installé réellement depuis `template0`, contient les références communes et trois termes lexicaux communs ; aucun compte, entreprise, profil, affiliation ou terme privé n’y est copié. Les six champs professionnels ont une catégorie par défaut valide et des options utilisables sans surcharge cliente.

## Droits et publication

- La gestion est limitée aux administrateurs d’entreprise disposant du droit de gestion du module. Les administrateurs globaux consultent l’ensemble et choisissent une entreprise active avant d’écrire.
- Une fiche commence en brouillon. Publication, activité et autorisation de contact sont distinctes. La publication exige une fiche suffisamment renseignée et des références valides ; les comptes ou entreprises inactifs sont exclus de l’annuaire.
- La projection publique n’expose ni e-mail ou téléphone personnels, ni numéro de gestion, note interne, mot de passe ou données RH.
- Une discussion avec un expert est limitée au demandeur et au compte professionnel. Les administrateurs de l’entreprise propriétaire ou d’une structure affiliée ne deviennent pas participants. Le destinataire, sa publication et ses autorisations sont contrôlés de nouveau au démarrage de la discussion.
- Les mutations utilisent UUID, empreinte de contenu, révision et motif. Les erreurs conservent le brouillon. Les écritures génériques du schéma sont refusées au profit du service métier.

## Tests réellement exécutés

| Contrôle | Résultat |
|---|---|
| Invariants PostgreSQL professionnels | 28 tests réussis : références, propriété, publication, affiliations, audit, défauts et recherche |
| Révision SQL des détails | 9 tests réussis : ajout, modification, retrait, absence de différence, auteur et annulation après refus tardif |
| API sur PostgreSQL privé | 29 tests réussis : création/modification atomiques, rejeu, concurrence, périmètres, droits, confidentialité, recherche, photos et discussions ; téléversement, remplacement, retrait, refus et compensation des fichiers au COMMIT |
| Référencement dynamique existant | 27 tests réussis après mise à jour des fixtures anciennes, sans relâcher les contrôles de production |
| Guide utilisateur | 19 tests API réussis ; cinq parcours Professionnels intégrés |
| Installation lexicale | Test réel réussi : exclusion des termes privés, apostrophes conservées, restauration exacte et refus d’un second import non vide |
| Droits du rôle PostgreSQL d’exécution | 20 contrôles réussis |
| Frontend | 130 assertions API/DOM, dont 51 sur les réponses JSON réelles du clone ; 72 contrôles avec React réel sur chargement et photos ; 63 assertions de non-régression des éditeurs Logistique ; 1 608 contrôles de contraste/thème |
| Compilation et cohérence | Compilation Vite et `manage.py check` réussies ; différences vérifiées sans erreur de format |
| Diagnostic global de lecture | 351 routes vérifiées avec connexion PostgreSQL réellement en lecture seule et sans écriture métier |
| Serveurs redémarrés | 24 vérifications HTTP réelles réussies : JWT en mémoire, deux contextes d’entreprise, annuaire, registre, références, cinq guides, route photo privée et frontend ; empreintes métier inchangées |

La recette des référencements utilisait auparavant des nombres fixes de champs, supposait la présence d’un défaut NULL dans le catalogue livré et créait une subdivision sans parent. Les fixtures ont été isolées et adaptées aux contrats actuels. Deux de ces échecs existaient déjà sur la restauration avant SQL06. Le contrôle de préservation du stock reste inchangé et passe en exécution isolée.

Les journaux privés sont conservés dans `.runtime` : sauvegardes/restaurations `experts06` et `experts07`, preuves d’application source, suites API/SQL, contrôles des structures et paquets neufs. Ils ne font pas partie des fichiers livrés au client et ne sont pas ajoutés à Git.

## Brouillon, attente et photo — correction du 3 novembre

Le profil signalé par l’utilisateur était enregistré mais non publié, avec une présentation vide. Les GET réels renvoyaient correctement une liste publique vide ; aucune boucle de recherche n’a été reproduite. La création indique maintenant **Enregistrer le brouillon**, le message de sauvegarde propose de consulter la fiche, l’annuaire vide explique la publication, et la fiche de gestion présente directement les informations manquantes et l’action de publication. Le contexte global indique de sélectionner l’entreprise propriétaire. Aucun profil réel n’a été publié automatiquement.

Une recherche non résolue est bornée à quinze secondes, avec fin de l’état de chargement et relance. Les tests React contrôlent aussi les réponses vides, rejets, changements d’entreprise et réponses tardives.

La photo se choisit ou se capture dans le formulaire commun d’ajout/modification, avec aperçu, retrait et rétablissement local. Elle partage `T_Utilisateurs.UrlPhoto` avec le compte associé. Le backend écrit uniquement cette photo et sa date technique après contrôle du profil et du compte ; ni identité d’acteur usurpée ni changement des droits. JPEG, PNG et WebP sont réellement décodés, normalisés en JPEG, limités à 8 Mio et 24 Mpx, puis stockés dans le répertoire privé `Profils`. Une demande UUID couvre la fiche, ses détails et la photo ; le fichier créé est effacé si la transaction ou son COMMIT échoue et l’ancien est supprimé après validation seulement.

La route de gestion autorise l’image d’un brouillon, tandis que celle de l’annuaire exige toujours une publication active. Les URLs sont versionnées pour rafraîchir l’avatar, et le compte connecté est rechargé lorsque sa propre photo change. La négociation `Accept: image/jpeg` est commune aux photos du compte et du professionnel. Le flux JSON Professionnels est borné avant décodage à 12 Mio ; Waitress partage la même limite pour accepter une image binaire de 8 Mio en base64. Aucune migration supplémentaire ni photo de test sur la base source.

Les preuves complémentaires sont `.runtime/professionnels-photo-api-tests.log`, `.runtime/experts-photo-live-verification.json` et les suites frontend `experts-react.cjs`, `experts.cjs` et `experts_theme.py`. Les tests React utilisent un renderer temporaire correspondant à React, sans dépendance applicative ajoutée. La caméra physique n’a pas été utilisée en recette.

## Limites explicites

Les tests de composants, de contraste et de contrat JSON ne remplacent pas une recette visuelle interactive. Celle-ci n’a pas été effectuée, l’accès automatisé au navigateur local ayant été précédemment refusé. Les accès HTTP de lecture après redémarrage sont vérifiés séparément.

La recherche utilise le plein texte et des critères paramétrés dans une vue SQL agrégée ; aucun index global matérialisé de cette agrégation n’est revendiqué. Un dimensionnement sur un grand annuaire réel reste à mesurer si le volume le nécessite.

Les compétences sont déclaratives. Le module ne certifie pas les diplômes, ne confirme pas de rendez-vous et ne facture pas de prestation. La base examinée était vide de profils professionnels : les premiers profils réels restent à renseigner puis à publier par les gestionnaires autorisés.

Voir [le guide du module](../../docs/professionnels.md) et le Guide utilisateur intégré pour les parcours.
