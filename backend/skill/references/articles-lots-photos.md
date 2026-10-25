# Contrat Articles, photos et lots

Évolution autorisée le 25/10/2026 : CRUD Article, poids, lots à réception, capture photo et informations complémentaires. Source : SQL/migrations/20261025_03_articles_poids_lots.sql. Les modèles restent unmanaged.

## Écritures Article

article_rules.py valide identité, références actives et catégorie attendue, prix, quantités, dates et poids. GET /api/logistique/articles/<id> fournit une révision ; PUT/DELETE doivent envoyer _version. Verrou et comparaison partagent la transaction. La révision exclut le stock courant pour distinguer mouvement et modification des caractéristiques.

Une modification ne change ni créateur ni directement stock. Une unité ayant des mouvements/lignes ne change plus. La suppression physique exige un administrateur global, un article inactif à stock nul et aucune référence métier ; sinon proposer la désactivation. L’audit partage la transaction. Ne pas traiter un conflit comme un succès.

InformationArticle est un texte complémentaire (limite applicative 20 000 caractères), distinct de ObsArticle. Le poids numeric(14,6) est indépendant des quantités : poids et unité vides ensemble ou renseignés ensemble. Les unités de masse sont les références mg/g/kg/t de catégorie 34. Les quantités de mouvement restent entières selon le schéma existant.

## Lots

T_LotArticle identifie un numéro par article ; T_MouvementLot ventile un mouvement existant. V_LotArticleStock et V_MouvementLot calculent stock et traçabilité. Les tables, colonnes, vues, fonctions et triggers introduits ont des COMMENT ON.

Une ligne accepte Lots: [{NumeroLot, Quantite, DatePeremptionLot}]. LotsInitiaux est réservé à la création d’un article avec stock positif. Maximum applicatif : 50 lots par ligne. La ventilation fournie totalise exactement la quantité source. Une réception identifie ou crée le lot reçu ; une sortie reprend un lot actif connu. Ne pas corriger une quantité ventilée en supprimant silencieusement ses lots.

Verrouiller parent du bon, article puis lot. Les triggers existants restent seuls responsables du stock global et du mouvement. La ventilation n’applique aucun deuxième effet. Les contrôles différés refusent lot négatif, rattachement à un autre article, somme dépassant le mouvement ou stock ventilé dépassant le stock global. Une annulation ne peut retirer une réception dont les lots sont déjà consommés.

Préserver le stock historique sans numéro de lot. La différence entre stock global et stock identifié représente le stock sans lot ; ne pas attribuer de numéro arbitraire. Les consultations contrôlent le parent puis imposent sa clé aux lots.

## Images privées

photos.py accepte une image multipart et une partie payload JSON exacte. Limites : 8 Mio, JPEG/PNG/WebP, 24 mégapixels. Vérifier le contenu par Pillow, corriger l’orientation, retirer les métadonnées et convertir en JPEG de 1 600 px au plus. Ne pas récupérer une URL fournie par le client.

Stockage : ARTICLE_MEDIA_ROOT/Article/<nom-normalisé>_<suffixe-unique>.jpg, défaut backend/media. Seul un chemin généré est enregistré dans PhotoArticle. Nettoyer le nouveau fichier si la transaction échoue. Les anciens fichiers restent récupérables ; leur purge exige une politique séparée avec sauvegarde et contrôle des références.

L’accès passe par la route logistique avec contrôle d’objet ou la projection catalogue autorisée. Réponses privées sans cache et nosniff. Ne pas servir directement media. Un pg_dump ne contient pas les images : sauvegarder media et vérifier sa restauration séparément.

## Vérification et déploiement

Maintenir les recettes SQL/tests sur une base sauverndeko_test_* indépendante, sans données clients. Tester concurrence, conflits, entrée/sortie multi-lots, correction, annulation, lot épuisé, somme incorrecte, photo invalide et nettoyage sur échec. Les diagnostics manage.py restent en lecture seule sur SauverNdeko.

Avant migration : sauvegarde vérifiée, contrôle que données et quantités existantes restent identiques. Aucun DROP CASCADE pour réordonner les colonnes. La présentation d’InformationArticle avant ObsArticle relève de l’interface ; PostgreSQL ajoute la nouvelle colonne sans reconstruire les tables.
