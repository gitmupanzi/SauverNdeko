# Patrimoine et affectations

Le parcours Immobilisations appartient au groupe Patrimoine de Logistique. Une fiche représente un équipement individuel ou un groupe explicitement homogène ; le registre des biens n’est pas le catalogue commercial des Articles.

`T_Immobilisation` et `V_Immobilisation` sont le socle partagé des lectures, consultations et exports. Code IMMO-ID, entreprise et création sont immuables. Les quantités sont entières exactes ; le suivi individuel ou un numéro de série impose 1. Prix inconnu et zéro restent distincts. La valeur d’acquisition est calculée en SQL sans mouvement, CUMP, amortissement ou écriture comptable implicite.

Les listes de type, état et service viennent du référentiel et des correspondances persistées : surcharge d’entreprise active avant portée globale. Aucun identifiant de famille ne doit être repris d’une autre installation. Le responsable appartient à la même entreprise. La localisation du bien se saisit en texte libre. Les liens vers les anciens sites référencés restent lisibles et sont conservés tant que le lieu n’est pas modifié. Les anciennes affectations restent dans l’audit ; un bien archivé conserve sa fiche et protège les propriétaires encore liés.

Les six données professionnelles minimales de `T_Utilisateurs` restent séparées dans `V_User_Affectation`. Fonction et service ne remplacent pas le rôle de sécurité. L’interface d’administration rassemble Utilisateurs et les informations professionnelles ; l’ancienne source Profils reste compatible, sans second parcours utilisateur ni extension du profil public.

Les choix de colonnes de tableau et d’export sont indépendants et persistés. Les identifiants sans rendu métier sont exclus des choix du tableau mais peuvent rester exportables explicitement. Le prix affiché peut porter sa devise ; aucune colonne supplémentaire n’est ajoutée contre le choix enregistré de l’export.

Le paquet neuf charge structure, dictionnaire et correspondances fermées dans l’ordre documenté. Il ne copie ni entreprise, compte, bien, historique, préférence personnelle ou configuration privée. Une évolution de code ou une migration présente ne suffit pas à affirmer son installation réelle : consulter les preuves d’application et de recette.

Lire [le contrat SQL](../../../SQL/documentation/Immobilisations_Affectations_20261028.md) et [le guide utilisateur](../../../docs/prise-en-main-patrimoine.md).

Les transferts physiques utilisent la modification motivée de l’affectation. Les comptages, entretiens et sorties définitives sont conservés dans le journal du cycle de vie. Les justificatifs privés réutilisent le stockage documentaire et sont soumis au périmètre du bien. Préserver les états historiques et le droit de consulter les biens sortis.

La valorisation relève de plans validés et distincts par entreprise, bien et usage. Distinguer l’échéancier de la dotation constatée. Les références comptables et les paramètres restent explicites. Les clôtures et écritures constatées doivent être protégées par PostgreSQL. Lire [le plan de migration et de validation](../../../docs/immobilisations-plan-migration.md).
