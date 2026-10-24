# Intégration dans SauverNdeko

## État vérifié le 24/10/2026

SauverNdeko utilise Django/DRF/PostgreSQL et React JSX/Vite/Bootstrap. Les règles métier sont portées par les services et vues SQL ; le dossier de mise en forme fournit des règles et exemples, sans moteur Office intégré.

| Élément actuel | Fichier | Conséquence pour l’export |
|---|---|---|
| Requêtes privées et vues | frontend/src/services/api.js | Réutiliser la session et les erreurs ; ne pas transformer un refus en fichier vide |
| API logistique | frontend/src/services/logistique.js | Conserver les critères effectivement appliqués |
| Configuration des vues | frontend/src/pages/logistique/views.js | Mapping des champs et des domaines, à vérifier dans le code |
| Helpers actuels | frontend/src/pages/logistique/logistiqueShared.jsx | CSV sur lignes reçues, HTML avec extension .xls, impression navigateur pour PDF |
| Lectures et écritures logistiques | backend/apps/logistique/services.py et backend/apps/core/repository.py | Contrats des vues, limites de page et données métier |
| Objets SQL | SQL/ et migrations 20261024_01/02 | Commentaires et règles stock/totaux ; lire les définitions avant de choisir une colonne |

Aucun moteur Word ou export exhaustif XLSX/PDF serveur commun n’a été identifié dans les parcours inspectés. Aucun modèle de job d’export n’est présumé disponible. La présence de ce skill ne modifie pas les helpers actuels.

## Source unique et périmètre

Lire [le backend](../../../backend/skill/SKILL.md), [le frontend](../../../frontend/skill/SKILL.md) et [le skill ERP](../../sauverndeko-erp/SKILL.md) selon la tâche. Utiliser les mêmes services, vues, autorisations et filtres pour écran, détail et export. Un paramètre d’organisation envoyé par le navigateur ne constitue pas une autorisation.

Pour un registre complet, lire l’ensemble filtré côté serveur avant la pagination d’affichage. Ne pas assembler un faux total depuis les 200 premières lignes. Pour un export long, assurer la cohérence temporelle du jeu exporté ; n’ajouter un mécanisme de jobs que si le coût réel le justifie, avec statut, erreur et téléchargement autorisé.

## Mapping logistique

| Document | Source à privilégier | Points à conserver |
|---|---|---|
| Articles / Produit 360 | V_Article | Identité, unité, stock courant, seuil, prix, péremption ; devise non déduite |
| Commandes / Commande 360 | V_Commande et V_CommandeDetail | Références, dates métier, lignes, montants, statuts et contrôles |
| Livraison | Données de livraison réellement disponibles et lignes liées | Quantité commandée distincte de quantité effectivement livrée ; ne pas inventer la seconde |
| Règlements / facture | V_SuiviReglements et écritures autorisées | Grain facture distinct du grain écriture, cumul et reste identifiés |
| Mouvements / audit | V_Mouvement, V_MouvementStock, V_AuditStock | Type historique, signe, prix source, écart et unité ; lecture seule |
| Consommation / couverture | V_ConsoMensuelle, V_CouvertureStock | Période réelle, moyenne/ratio fournis, inconnus et jours futurs exclus selon la définition |

Le stock avant ligne théorique ne constitue pas un instantané historique. Le total de quantités de plusieurs articles peut réunir plusieurs unités. Les montants d’en-tête, le total réel des règlements et le reste recalculé restent distincts. Les routines actuelles imposent des mouvements entiers et fixent HT/TTC au même total de lignes ; la présentation n’ajoute ni taux de taxe ni nouvelle règle de valorisation.

## Mise en œuvre d’un export

Identifier un document pilote, définir son contrat autorisé et sa portée, puis produire de vrais formats natifs à partir du même jeu de résultats. Séparer données, charte et moteur de format. Raccorder téléchargement et états de traitement sans dupliquer les calculs dans React. Tester parité, types, droits, résultat vide et erreurs ; rendre les vrais fichiers puis inspecter les pages et l’impression.

Conserver les libellés courts Excel, Word, PDF et afficher près des commandes Page affichée ou Tous les résultats filtrés. Un détail 360 et un registre sont deux portées différentes. La conformité de l’exporteur n’est annoncée qu’après cette recette, pas après la seule adaptation du skill.
