# Administration par entreprise — 30 octobre 2026

## Parcours disponibles

Les boutons Nouvel utilisateur, Nouveau rôle, Nouvelle correspondance et Nouveau paramètre ouvrent chacun un panier utilisable pour une seule ligne ou jusqu’à 100 lignes. On peut ajouter, corriger ou retirer une ligne, coller des cellules Excel, vider le panier et annuler l’ensemble. Le détail d’une ligne réutilise le formulaire complet. L’enregistrement est unique et transactionnel : une erreur conserve le brouillon et aucune ligne du lot n’est sauvegardée partiellement. Une relance après une réponse incertaine reprend le même identifiant et le même contenu.

Chaque panier propose aussi **Télécharger le modèle Excel** et **Importer un fichier Excel**. Remplissez la feuille Utilisateurs, Rôles, Correspondances ou Paramètres selon l’onglet ; les choix autorisés figurent dans Options et les consignes dans Informations. Le fichier `.xlsx` est limité à 4 Mo et 100 lignes, sans formule. L’import prépare les lignes sans les enregistrer : vérifiez les erreurs et doublons, ouvrez les détails si nécessaire, puis enregistrez l’ensemble. Un fichier refusé ne vide pas le panier.

L’entreprise déjà sélectionnée reste fixée et ne se remplace pas par une colonne importée. Les privilèges administrateur ne sont pas importables. Le modèle Utilisateurs ne contient aucun compte ni mot de passe existant ; un mot de passe initial saisi dans votre fichier est confidentiel, masqué dans le panier et conservé uniquement en mémoire par l’interface. Protégez puis retirez le fichier après usage.

Les mots de passe initiaux ne sont jamais stockés dans les préférences du navigateur. Ils sont hachés par le service de compte et exclus des réponses et des audits. Les validations serveur contrôlent notamment les adresses e-mail, les doublons, les références autorisées, les champs sensibles et le périmètre de l’entreprise.

L’entreprise active se choisit dans l’en-tête de l’Administration pour l’administrateur de la plateforme. Le chargement des entreprises ne nécessite plus une licence Logistique. Le compte local reste rattaché à son entreprise. Un changement de contexte invalide les réponses obsolètes et ne réaffecte pas un brouillon ouvert à une autre entreprise.

## Droits et portée

| Données | Gestionnaire d’entreprise autorisé | Administrateur de la plateforme |
|---|---|---|
| Utilisateurs | Consulter son entreprise ; créer, modifier et désactiver ses comptes ordinaires | Gérer les comptes dans le contexte choisi |
| Comptes privilégiés | Consultation autorisée dans son périmètre ; pas de délégation de privilèges | Gestion protégée contre l’auto-désactivation et la disparition du dernier administrateur actif |
| Rôles | Consulter les rôles partagés | Créer et gérer les rôles partagés |
| Entreprises et localisations | Consulter son entreprise selon ses accès | Gérer les fiches et leurs points de localisation |
| Licences | Consulter les licences de son entreprise | Créer et modifier les licences |
| Correspondances et paramètres | Consulter les réglages communs et ceux de son entreprise autorisés | Gérer les réglages structurants et leurs surcharges d’entreprise |
| Audit et connexions de plateforme | Accès réservé à la plateforme | Consultation et export autorisés |

Les permissions du module et le mode lecture seule du serveur restent applicables. Les anciennes routes de mutation reçoivent les mêmes protections que les paniers. Les secrets et paramètres protégés restent masqués ou non modifiables selon leur règle existante. Les rôles de sécurité restent communs ; aucun rôle ni donnée existante n’a été attribué arbitrairement à une entreprise.

## Entreprises et localisations

L’ancien onglet Localisations est retiré de la navigation. Son ancienne adresse renvoie vers Entreprises. La fiche de création et de modification d’une entreprise contient un sous-onglet Localisation : plusieurs points, adresse, références territoriales et coordonnées géographiques.

Les identifiants et révisions des points sont conservés. Le serveur contrôle les coordonnées et la hiérarchie. Un point utilisé par une affectation ne peut pas être supprimé. La fiche, le logo, les localisations et leur audit se sauvegardent dans la même transaction. Les anciennes API de localisation restent disponibles pour compatibilité.

La révision de la fiche inclut toute sa collection de localisations. Si une autre personne ajoute, modifie ou supprime un point pendant l’édition, le serveur refuse la sauvegarde obsolète sans effacer les changements récents. La lecture de la fiche utilise un seul instantané SQL et reste possible avec une connexion PostgreSQL réellement en lecture seule.

## Tableau de bord et navigation

Le tableau de bord présente les utilisateurs actifs/inactifs, les rôles, les entreprises, les licences et les réglages. Les graphiques présentent la répartition des comptes par rôle et par état, les créations sur sept jours et, pour la plateforme, les connexions et l’audit. Les indicateurs et barres ouvrent les registres avec leurs filtres correspondants. Les activités globales sont identifiées comme activités de plateforme, même lorsqu’une entreprise est sélectionnée.

La navigation commune couvre Administration, Logistique, Référentiels, Organisation territoriale et le menu du catalogue : groupes repliables, icônes, sélection active, rail compact et ouverture mobile. La référence visuelle est [TailAdmin](https://demo.tailadmin.com/form-elements), avec les couleurs et composants SauverNdeko. Les permissions reçues déterminent les entrées visibles ; le serveur contrôle toujours les accès.

## Conservation du socle

Cette évolution réutilise les tables, vues, portées et clés étrangères existantes. Elle n’exige aucune migration SQL. Aucun changement de structure ni donnée fictive de recette n’a été appliqué à la base SauverNdeko. Les essais d’écriture utilisent exclusivement une base PostgreSQL privée locale dont le nom commence par `sauverndeko_test_`.

## Vérifications

| Vérification | Résultat exécuté |
|---|---|
| API réelles en PostgreSQL privé | 29 tests : lots des quatre types, transactions, erreurs, rejeux et concurrence, droits locaux, anciennes routes, licences, parité des filtres, localisations et lecture seule réelle |
| Administration existante | 18 tests réussis |
| Profil entreprise et logo | 13 tests réussis |
| Paniers Logistique côté API | 17 tests réussis |
| Paniers Administration côté React | 106 contrôles sur les helpers et vrais handlers, avec transport et DOM simulés ; une panne des références bloque les écritures sans perdre le panier |
| Contexte entreprise | 59 contrôles : indépendance de Logistique, droits, changement de contexte et réponses obsolètes |
| Fiche entreprise et tableau de bord | 51 contrôles : sauvegarde des points, erreurs conservées et clics des indicateurs/graphiques |
| Navigation commune | 47 contrôles des handlers : groupes, rail, menu mobile, focus, Échap et nettoyage |
| Régression Référentiels | 57 contrôles réussis |
| Panier Référentiels existant | 119 contrôles réussis |
| Régressions Logistique côté React | 88 et 63 contrôles réussis |
| Thèmes de la navigation | 4 860 contrôles de cascade et de contraste sur les feuilles réelles |
| Diagnostic sur SauverNdeko | 264 routes GET réussies avec connexion SQL protégée en lecture seule ; aucune écriture |
| API du serveur actif et proxy frontend | 16 contrôles réussis après le dernier redémarrage : santé, nouvelles routes protégées et absence de route inconnue ; ports 5000 et 5174 |
| Compilation et vérifications | Build Vite réussi, contrôles Django sans erreur, trois skills valides et contrôle Git des espaces réussi |

Les scripts de recette se trouvent dans `SQL/tests` et `frontend/scripts/tests`. Les preuves locales sont conservées dans `.runtime` et ne font pas partie du dépôt publié. Le dernier redémarrage manuel a chargé un backend démarré après la dernière modification de son code ; le frontend reste sur le port 5174.

## Limites de validation

L’accès au navigateur sur localhost est refusé par la permission enregistrée de l’outil. Aucun contournement n’a été utilisé. Les tests de handlers, d’API et de CSS ne constituent donc pas une recette visuelle réelle sur ordinateur ou téléphone. Il reste à vérifier dans le navigateur la disposition, le défilement des fenêtres, l’ouverture mobile et les parcours utilisateur avec les droits réels.

Les journaux de connexion ne constituent pas un mécanisme de sessions actives. Cette évolution ne change ni l’authentification ni les règles de licence, et ne développe pas de module RH complet.
