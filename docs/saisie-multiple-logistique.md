# Création d’une ou de plusieurs fiches en Logistique

## Accès

- **Clients et fournisseurs** : le bouton **Nouveau tiers** ouvre le panier pour une ou plusieurs fiches.
- **Immobilisations** : le bouton **Nouvelle immobilisation** ouvre le même parcours de création groupée.
- **Articles** : **Nouvel article** conserve le formulaire individuel complet. **Ajouter plusieurs articles** ouvre le panier. Cette séparation est le choix explicite du propriétaire pour ce formulaire plus détaillé.

Choisir une entreprise active avant de préparer la saisie. Les permissions habituelles de Logistique s’appliquent. Le compte global conserve le choix de l’entreprise ; il ne crée pas de fiches sans propriétaire dans la vue « Toutes les entreprises ».

## Panier

Préparer les lignes, corriger une fiche et retirer les lignes inutiles avant l’enregistrement. Le collage depuis Excel prépare un brouillon et ne crée rien immédiatement. Les renseignements complémentaires restent accessibles depuis chaque ligne. Une ligne suffit pour une création simple.

Les paniers **Tiers** et **Immobilisations** proposent **Télécharger le modèle Excel** et **Importer un fichier Excel**, en complément du collage. Le modèle contient les colonnes de la fiche et les choix autorisés dans Options. Remplissez sa feuille Tiers ou Immobilisations, puis importez le `.xlsx` (4 Mo et 100 lignes maximum). Les formules sont refusées. Vérifiez et corrigez les lignes dans le panier avant l’enregistrement global ; une erreur de lecture conserve la saisie existante. L’entreprise propriétaire et les codes automatiques ne s’importent pas. Les immobilisations conservent leurs règles d’affectation, de quantité et de motif ; cet import ne crée ni stock ni amortissement.

Les fiches existantes continuent à se consulter et se modifier depuis leur menu de ligne. Leur archivage et leurs historiques restent conservés.

L’enregistrement porte sur l’ensemble du panier, au maximum 100 fiches. Si une ligne est refusée, aucune fiche du lot n’est conservée ; corriger les erreurs indiquées puis soumettre à nouveau. Les lignes non concernées ne sont pas effacées.

Si la réponse réseau n’arrive pas, utiliser la vérification proposée dans le formulaire resté ouvert. Elle reprend la même demande et son contenu pour éviter une seconde création. Attendre sa résolution avant de changer les lignes.

## Règles métier conservées

Les listes de catégories, types, unités, services, affectataires et devises sont celles des formulaires habituels. La saisie groupée ne remplace pas les contrôles de l’entreprise ni le référencement des champs.

Pour un article, les informations, photo, poids, unité, prix et lots initiaux suivent le formulaire individuel. Une photo doit rester une image JPEG, PNG ou WebP valide, de 8 Mo au maximum ; les photos d’un même enregistrement groupé sont limitées à 32 Mo au total.

Un stock initial positif passe par les routines PostgreSQL existantes : bon d’entrée interne, ligne et un seul mouvement. Le panier n’ajoute pas de mouvement directement. Un stock initial nul ne crée pas d’entrée fictive. Les lots sont contrôlés dans la même transaction. Les photos d’une création annulée sont nettoyées.

Les immobilisations restent distinctes des articles commerciaux. Leur création n’affecte ni le stock, ni le CUMP, ni une écriture d’amortissement. L’affectation, le service, le lieu et le motif suivent leurs règles existantes.

## Présentation commune

Les listes, paniers et tableaux de consultation réutilisent le tableau partagé, comme les Bons de stock : en-têtes lisibles, lignes compactes, tri, défilement et actions cohérents, y compris dans les fenêtres latérales. Les thèmes clair, sombre et contraste élevé utilisent les mêmes couleurs centralisées.

Un contrôle technique de ces parcours ne remplace pas la recette visuelle d’un utilisateur dans son navigateur ni les autres vérifications de livraison figurant dans [les travaux restants](reste-a-faire-logistique.md).

## Vérifications du 30 octobre 2026

| Périmètre | Résultat exécuté |
| --- | --- |
| API des trois paniers | 17 tests réussis sur une base PostgreSQL privée : création, limites, erreurs par ligne, transaction sans sauvegarde partielle, rejeu concurrent, droits et entreprise, photos, lots et stock initial. |
| Régressions backend | 15 tests Immobilisations, 34 tests Référentiels et 35 contrôles de stock initial réussis. |
| Panier et éditeurs | 88 contrôles des helpers et handlers de panier, puis 63 contrôles indépendants des vrais éditeurs en brouillon réussis ; transports simulés, sans navigateur. |
| Régressions frontend | 119 contrôles de saisie multiple des Référentiels et 57 contrôles de registres réussis. |
| Tableaux partagés | 1 080 contrôles de cascade CSS et 14 contrôles de mesure des en-têtes réussis ; voir [le bilan des tableaux](verification-tableaux-logistique-20261030.md). |
| Compilation | Build Vite et vérification Django réussis. Les trois skills modifiés passent leur validateur. |
| Application en lecture seule | 245 routes GET vérifiées avec succès, sans écriture de test dans SauverNdeko. |
| Après redémarrage | Santé HTTP 200 ; les trois nouvelles routes sont chargées et répondent 401 sans connexion, en accès direct au backend et depuis le proxy 5174 ; une route inconnue répond 404. |

Aucune migration de schéma n’est nécessaire pour cette évolution. Les écritures métier de test ont été réalisées dans la base privée, avec un répertoire temporaire pour les photos. L’accès navigateur à localhost reste bloqué pour l’agent : la recette visuelle réelle, le défilement et l’affichage mobile n’ont pas été exécutés. Ce bilan atteste le périmètre décrit, pas une certification de livraison de tout le module Logistique.
