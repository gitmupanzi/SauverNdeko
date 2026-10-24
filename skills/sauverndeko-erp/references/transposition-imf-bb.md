# Reprendre les principes d’imf_BB

Sources consultées le 24/10/2026 : C:/Users/Benjamin-mupanzi/Documents/imf_BB et [conversation partagée](https://chatgpt.com/s/cx_6adcc15d24fc819182e200a1a02cc358). La page a été lue dans le navigateur après échec de la lecture web directe. Les extraits accessibles confirment les demandes relatives aux vues, indicateurs cliquables et fenêtres 360 ; l’historique n’est pas traité comme une spécification exhaustive de SauverNdeko.

Les chemins de la colonne Source sont relatifs à imf_BB et servent de provenance. Les skills SauverNdeko restent utilisables sans ce projet voisin ; les règles transférées sont écrites dans leurs propres références.

| Principe à reproduire | Source inspectée dans imf_BB | Application SauverNdeko |
|---|---|---|
| Réutiliser la vue commune avant de refaire des jointures | backend/skill/SKILL.md ; references/catalogue-vues.md | Chercher V_Article, V_Commande et les autres vues métier avant une lecture concurrente. Documenter grain, droits, dates et consommateurs. |
| Commentaires PostgreSQL et SQL versionné | backend/skill/references/catalogue-vues.md ; database-and-operations.md | COMMENT ON TABLE/VIEW/COLUMN pour les objets créés ou modifiés, visibles dans pgAdmin ; migration contrôlée, aucune création manuelle isolée. |
| Calculs lourds côté base, orchestration serveur mince | backend/skill/SKILL.md | PostgreSQL porte jointures/agrégats partagés ; services Django portent validations, autorisations et transactions ; React présente les résultats. |
| Rechercher avant pagination et garder le même export | backend/skill/SKILL.md ; frontend/skill/references/interface-contracts.md | Même contexte autorisé pour liste, total, KPI, détail et export ; distinguer page chargée et registre complet. |
| Fenêtre commune de consultation | frontend/src/components/ConsultationDialog.tsx ; Client360Drawer.tsx ; frontend/skill/references/interface-contracts.md | Adapter le comportement à un composant JSX partagé : réduire, élargir, rétablir, fermer, poignée, clavier, mobile et retour du focus. |
| Consultation sur identité et Consulter | Client360Drawer.tsx et contrats d’interface | Code/nom article → Produit 360 ; code commande → Commande 360 ; les aides et actions secondaires n’ouvrent pas la fiche par propagation. |
| KPI actionnable et filtre visible | frontend/skill/references/interface-contracts.md | Valeur et lien ouvrent le même détail ou registre avec critère effaçable, pas un onglet générique. |
| Groupes d’indicateurs et mini-blocs repliables | DashboardMiniBlock.tsx/.css et contrats d’interface du 24/10/2026 | Groupes analytiques repliés par défaut dans les registres ; les autres contenus restent disponibles. Sources et calcul précède le détail. |
| Textes sobres et hiérarchie visuelle | mêmes contrats d’interface | Titres courts, valeurs, dates/unités visibles ; aides repliées. Bandeaux principaux foncés, sous-blocs vert très clair ; adapter à la charte SauverNdeko. |
| Export explicite et état de préparation | ExportButton.tsx et contrats | Garder le périmètre visible et bloquer le double déclenchement ; construire le moteur approprié avant d’annoncer XLSX/Word/PDF serveur. |
| Largeurs et zoom respectés | contrats d’interface et ConsultationDialog | Tableau avec défilement interne, contenu flexible, commandes accessibles à 1920/1000/390 px et au zoom réel. |

## Reprise exacte du comportement, adaptation du contrat métier

La précision doit porter sur l’interaction et la source de vérité. Copier une classe CSS ou un composant TypeScript sans ses dépendances, son API et ses droits ne reproduit pas le comportement. Implémenter les conventions dans les composants partagés de SauverNdeko, avec un vocabulaire produit/commande/facture et les sources SQL de ce projet.

Conserver les technologies actuelles : Django/DRF, PostgreSQL/psycopg, JWT, React JSX et Bootstrap. La session JWT de React reste distincte des comptes et sessions natifs Django. Les permissions codées dans imf_BB, ses noms de schémas mpesa/cbs et ses formules financières ne s’appliquent pas par simple copie. Ne transférer aucune donnée client ou configuration secrète.

## Premiers parcours à reprendre

1. Depuis Articles, le code et Consulter ouvrent la même fiche Produit 360, puis permettent de consulter une commande liée et de revenir au produit.
2. Depuis Commandes, Consulter ouvre synthèse, lignes, mouvements, facture/règlements et contrôles selon les droits.
3. Depuis Ruptures ou Règlements en retard, la valeur ouvre exactement la population retenue par le calcul serveur ; le tableau complet et l’export conservent les mêmes critères.
4. Fermer une fiche restitue focus, filtres, page, sélection et position ; changer d’organisation invalide les données de l’ancien contexte.

Ces parcours sont des critères d’implémentation future. Ils ne sont pas raccordés par la présente livraison documentaire.
