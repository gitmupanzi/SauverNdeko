---
name: develop-sauverndeko-backend
description: Maintenir le backend Django et Django REST Framework de SauverNdeko sur PostgreSQL existant, avec vues SQL, droits serveur et transactions métier. Utiliser pour API, comptes, permissions, stock, calculs et performances backend.
---

# Backend SauverNdeko

Lire les [consignes du projet](../../../skills/AGENTS.md) avant une intervention.

## Architecture active

Le propriétaire a autorisé la conversion du dossier backend vers Django le 24/10/2026, puis a limité initialement le travail aux fichiers. Il a ensuite explicitement autorisé les tables natives Django dans le schéma public et demandé une intervention d’administrateur de base de données. Django/DRF est le seul backend. Le propriétaire a ensuite demandé la suppression d’Express/Prisma, de son client généré, de ses dépendances et des lanceurs npm du backend. React et les contrats d’URL restent en place.

- Lire [l’architecture](references/architecture.md) pour les points d’entrée et les responsabilités.
- Lire [le portail d’administration](references/administration-portail.md) pour la synthèse, les registres, leurs exports, la confidentialité des journaux et les paramètres protégés.
- Lire [messagerie et réinitialisation](references/messagerie-reinitialisation.md) pour l’expéditeur, les secrets SMTP locaux et la récupération sécurisée des comptes.
- Pour la propriété durable des documents, T_Client et les opérations du compte global, lire les [décisions Entités, tiers et stock](../../../skills/sauverndeko-erp/references/entites-tiers-et-stock.md).
- Lire [Articles, photos et lots](references/articles-lots-photos.md) pour les écritures avec révision, poids, informations et ventilation des mouvements par lot.
- Lire [la décision d’accès PostgreSQL](references/decision-acces-postgresql.md) pour la décision mise à jour.
- Lire [le bilan métier et technique](../../../SQL/documentation/Audit_Metier_20261024.md) pour les vérifications et limites.
- Lire [vues et commentaires](references/vues-et-commentaires.md) pour les sources SQL ; ses évolutions déjà appliquées sont historiques et ne doivent pas être rejouées pendant une conversion de code.
- Pour Excel/Word/PDF, appliquer le [skill documentaire](../../../skills/document-mise-en-forme/SKILL.md).

## Préserver PostgreSQL existant

Les modèles métier sont managed=False. Les migrations natives admin/auth/contenttypes/sessions sont autorisées uniquement dans public, avec search_path=public, sauvegarde et contrôle préalable du plan. makemigrations, flush, syncdb, fake et retours arrière de migration restent désactivés. Ne modifier aucun schéma métier ni créer de base de recette ou de donnée fictive pour une intervention limitée au backend. SAUVERNDEKO_DB_READ_ONLY=1 est le défaut ; ne pas le désactiver pour faire passer une vérification. Le propriétaire a ensuite explicitement demandé l’audit et l’amélioration de referentiel, systeme, geolocalisation, professionnel, analytics, communication et logistique : la migration 20261024_04 est appliquée. Voir le bilan SQL/documentation/Audit_Metier_20261024.md. Une autre évolution demande son propre périmètre ; cette autorisation ne couvre pas une suppression de données clients.

Le serveur local utilise CONN_MAX_AGE=0 et application_name=SauverNdeko-Django pour fermer les connexions en fin de requête et rendre leur suivi possible. Ne pas résoudre une fuite de connexions par une hausse arbitraire de max_connections.

Utiliser la connexion Django unique ; pas de Prisma ni de deuxième pool dans le code Python. Les valeurs SQL sont paramétrées ; schémas, objets, colonnes et tris proviennent du registre autorisé. Les modèles et registry.json décrivent un catalogue existant : une évolution de ce catalogue nécessite une nouvelle inspection en lecture seule et une adaptation vérifiée.

## Invariants des services

- Priorité aux vues PostgreSQL communes ; droits, filtres, comptages et agrégats côté serveur avant pagination.
- Contrôler utilisateur actif, rôle, organisation, objet et FK sur chaque chemin. Is_staff ne donne pas un périmètre global. Les objets sans règle locale démontrée sont refusés aux gestionnaires locaux.
- Les migrations 09/13 installent une Entité propriétaire durable sur Article/Commande et T_Client. Le contexte global X-Entite-ID est validé par tenancy ; il ne change pas l’auteur réel. Les objets sont partagés dans leur entreprise selon les droits, et les dossiers personnels restent privés. Les anciens ID_ClientFk ne sont pas convertis par égalité numérique ; les nouvelles références utilisent ID_TiersFk.
- Les lignes commande verrouillent le parent puis les articles dans un ordre stable. Les triggers réalisent stock/mouvements/totaux ; ne pas appliquer un deuxième effet en Python. Quantités exactes à trois décimales au maximum selon la précision explicite de l’unité (défaut zéro). La migration 10 harmonise mouvements, lignes, lots et factures ; arrondir les montants par ligne à deux décimales.
- T_Mouvement, les journaux et archives sont en lecture seule. Préserver désactivation et suppression définitive distinctes.
- Les montants sont des Decimal et des chaînes JSON exactes ; les absences restent distinctes de zéro. Ne pas inventer de devise ou additionner des unités incompatibles. Les JSON/JSONB des curseurs bruts sont décodés par db.query avant nettoyage récursif ; les UUID sont pris en charge par ExactEncoder. Ne pas retourner une image JSON comme simple texte qui contournerait le masquage des secrets.
- Écriture métier et audit partagent la transaction. Masquer mots de passe et secrets dans réponses/journaux.
- Ne pas remplacer une erreur de permission ou de source par une collection vide ou un total nul.

## Vérification

Dans backend : python manage.py check puis python manage.py verifier_backend pour les contrôles en lecture seule. Le propriétaire a explicitement demandé de retirer le dossier de tests unitaires et les fichiers de dépendances séparés ; conserver un seul requirements.txt. python manage.py verifier_backend est un contrôle réel en lecture seule, avec identité synthétique réservée au diagnostic interne. Son succès ne valide ni les mots de passe clients ni une écriture/concurrence réelle.

Les recettes SQL/tests/test_metier_postgresql.py et test_api_postgresql.py sont vérifiées sur une copie de structure sans données clients et refusent une base hors sauverndeko_test_*. Les mutations de recette ne doivent jamais viser la base applicative.

## Séparation des schémas et comptes

public contient le socle natif Django ; systeme conserve entités, utilisateurs/profils métier, licences, réglages et journaux. Une fusion des schémas n’a pas été retenue : voir [l’examen DBA](../../../SQL/documentation/Decision_Systeme_Public_20261024.md). auth_user n’a pas été alimentée par copie des comptes métier. Le rapprochement futur des identités demande un lien explicite et une migration vérifiée ; ne pas confondre déplacement de tables et fusion de comptes.

## Entrée ERP fermée

À la demande du propriétaire, les projections du catalogue exigent aussi une session JWT valide, malgré le préfixe /api/public conservé pour compatibilité. L’inscription libre renvoie REGISTRATION_DISABLED ; les comptes sont gérés dans l’administration. /api/workspace/modules retourne uniquement les modules permis par les droits existants, sans accorder de permission supplémentaire. Les réponses API et authentification sont sans cache. /health contrôle PostgreSQL avec SELECT 1, sans exposer de données métier ; le lanceur ne teste plus le catalogue en anonyme. Les nouvelles installations restent en lecture seule par défaut. Le 25/10/2026, après sauvegarde et accord explicite du propriétaire portant sur toute l’application, le réglage local backend/.env passe SAUVERNDEKO_DB_READ_ONLY à 0 pour autoriser le CRUD des comptes déjà habilités. Conserver les droits serveur et périmètres ; cette activation n’accorde aucun rôle supplémentaire. Les diagnostics continuent dans un processus distinct avec SAUVERNDEKO_DB_READ_ONLY=1.

## Lectures logistiques ERP

apps/logistique/reads.py partage les prédicats autorisés entre synthèse, indicateurs, registres et consultations. Conserver les valeurs Decimal et distinguer absence et zéro. populationQ maintient la population du KPI tandis que q affine sa liste ; une recherche de détail ne doit pas retirer le périmètre d’organisation ou le critère d’origine. Une consultation vérifie le parent puis impose ses clés aux rubriques, y compris la facture des règlements. Aucun mouvement supplémentaire n’est créé en Python.

verifier_backend contrôle désormais ces nouvelles routes dans son diagnostic GET en lecture seule. Le frontend distingue canAccessAdmin et canWriteData fourni par le profil : un accès au module n’autorise pas automatiquement l’écriture. Le libellé métier Bon de stock correspond encore aux clés techniques Commande ; ne pas renommer le contrat sans migration explicite.

Les répartitions par catégorie utilisent GROUP BY et leurs détails imposent ID_CategorieArticleFk. Distinguer En attente et En cours ; les sens Entrée/Sortie viennent des indicateurs de la vue. Le bloc Factures exclut les bons sans référence de facture. Les filtres temporels portent sur DateFacture pour la facturation, DateCmd pour les bons et DateMvt pour les mouvements. Ne pas réutiliser implicitement la première date présente dans une vue.

## Relevés historiques conservés

Les anciennes références [backend-architecture.md](references/backend-architecture.md), [api-contracts.md](references/api-contracts.md), [validation.md](references/validation.md) et [inspect_backend.py](scripts/inspect_backend.py) décrivent Express/Prisma avant la conversion. Elles sont conservées comme archives ; ne pas exécuter leurs anciennes commandes ni les utiliser pour décrire le backend actuel. Les références précédentes portent les consignes maintenues.

## Documents et avoirs logistiques

Les migrations 11/12 et les services documents.py/credit_notes.py assurent les PDF métier, pièces privées, avoirs après retour facturé, imputations et remboursements enregistrés. Les avoirs ne recréent jamais un mouvement de stock. V_Facture fournit le solde net commun ; ne pas déduire une seconde fois les imputations dans les vues aval. Conserver les identités émises, les lignes facturées et les écritures financières ; corriger par un document traçable. Les fichiers sont téléchargés après contrôle du parent et de son entreprise, jamais par une URL publique. Le PDF/les images utilisent des réponses binaires et les erreurs restent JSON. Les mutations portent une révision et un identifiant idempotent, avec verrouillage du parent puis des objets dans un ordre stable.

## Maintenance et livraison

Lire [le guide de livraison](../../../docs/livraison-logistique.md) pour provisionner une Entité, sauvegarder DB et médias privés, restaurer dans une base isolée, préparer une installation vierge et servir le backend en production. Les commandes de maintenance ne font jamais partie du démarrage normal et ne migrent pas automatiquement une base cliente. Le provisionnement conserve les dates lors d’un rejeu ; une licence appartient à l’Entité et ne remplace pas les droits des rôles.

Une restauration n’est attestée qu’après comparaison des tables et fichiers restaurés. Le paquet neuf contient une liste fermée de données de dictionnaire, sans compte ni document client. `initialiser_admin` refuse un système possédant déjà des utilisateurs. Les extensions de dépôts, achats/ventes et comptabilité générale suivent le [cadrage ERP](../../../docs/cadrage-extensions-erp.md), avec contrats SQL et critères métier avant livraison.

La recette `SQL/tests/test_recuperation_acces.py` utilise uniquement une base privée explicitement configurée et un transport mémoire. Elle ne prouve pas une délivrance Gmail réelle. Le service WSGI de production s’appuie sur Waitress derrière le seul proxy de confiance déclaré ; les médias restent privés et le réglage `config.production` refuse des hôtes ou secrets incomplets.

## Bons internes d’inventaire

Les corrections et compensations d’inventaire ne sont pas des ventes ni des retours clients. `V_BonInventaire` et `fn_bon_inventaire` classent les bons par leurs FK de comptage, jamais par le texte de RefCmd. Conserver les gardes SQL dans les deux sens, leurs verrous communs et leur contrôle différé : un bon facturé ou lié à une restitution ne peut pas devenir une correction ; une correction ou son annulation ne peut pas recevoir de facture ou de restitution commerciale. Le parcours correct est un nouveau comptage ou une annulation de validation avec motif et compensation. Les contextes et menus API reprennent cette classification.

## Valorisation CUMP et lectures de lots

Lire [la règle CUMP](../../../SQL/documentation/Valorisation_CUMP_20261026.md) avant toute modification des coûts. Réutiliser V_ValorisationStock, V_CoutMouvement et enregistrer_cout_ouverture : calcul exact PostgreSQL, devise/entreprise explicites, coût inconnu distinct de zéro et révision de source vérifiée dans la même transaction. Ne pas fabriquer un coût à partir du prix de vente ou d’un prix indicatif d’inventaire. Les arrêtés/réévaluations ne créent pas de mouvement physique.

Le registre Lots et son journal utilisent V_RegistreLots/V_RegistreMouvementLot ; fiche et export contrôlent d’abord le parent puis le filtre de lot. La pagination, le compteur et l’export partagent le même périmètre. Le diagnostic verifier_backend doit rester en connexion réellement lecture seule et inclure les nouvelles routes.

## Clôture et identité documentaire

SQL09 fournit V_IdentiteDocumentaire et fn_identite_documentaire sur T_Entite. entity_documents impose entreprise active, gestionnaire autorisé, motif, révision et UUID lié à acteur/contenu ; aucune identité émise n’est réécrite. Les identifiants déclaratifs restent facultatifs et leur structure est contrôlée en SQL. Les nouveaux documents les figent avec la mention.

Utiliser verifier_livraison pour un diagnostic agrégé en transaction READ ONLY ; un état configuré ne prouve ni délivrance SMTP ni restauration ni mise en production. Le POST messagerie/test authentifie le transport sans envoyer de message, limité à trois demandes/minute et aux administrateurs globaux, refusé en lecture seule. Les secrets et réponses brutes du serveur SMTP restent hors API/journaux. Lire le [diagnostic](../../../docs/diagnostic-livraison.md) et le [guide utilisateur](../../../docs/prise-en-main-logistique.md).
