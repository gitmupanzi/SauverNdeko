# Data Science

Le module **Data Science** aide à étudier la demande exprimée dans les annuaires Produits, Professionnels et Structures. Les séries mensuelles, la matrice province–mois et le détail cliquable reprennent des idées de présentation du tableau de bord du ministère.

## Collecte et accès

- Après une recherche sans résultat, un utilisateur habilité peut ouvrir **Exprimer un besoin**, puis indiquer s’il a trouvé une solution dans **Discussions → Demandes**. Après une recherche avec résultats, il peut partager volontairement une catégorie de produits ou un sujet de santé lorsque son entreprise participe.
- Dans **Data Science → Périmètre de l’étude**, un administrateur de la plateforme peut activer ou arrêter la participation d’une entreprise. Le partage pour la recherche est facultatif. L’analyse couvre uniquement les déclarations consenties de la période de participation active. Les demandes adressées directement à une entreprise depuis une fiche restent dans Discussions.
- La province est déclarée et facultative. La collecte structurée enregistre le choix de référentiel et la date. Les termes libres saisis dans les annuaires et la position précise sont absents de ce registre.

## Licences et périmètres

- Un administrateur de la plateforme active Data Science dans **Abonnements → Offre de la licence**. L’accès des utilisateurs dépend ensuite de leur rôle et de leurs permissions individuelles.
- Une entreprise habilitée dispose du **Tableau de bord** et de **Demandes et besoins** pour ses propres données agrégées. Le serveur vérifie le rattachement à chaque requête.
- L’administrateur de la plateforme peut choisir une entreprise ou **Toutes les entreprises**. **Recherches déclarées** et **Périmètre de l’étude** lui sont réservés.

## Lecture des résultats

- Les graphiques et tableaux agrègent les événements par mois de Kinshasa, annuaire, type de déclaration, catégorie ou sujet et province. Une cellule est affichée à partir de cinq contributeurs différents dans une même entreprise. La consolidation additionne les cellules qui passent ce seuil dans chaque entreprise. Les ventilations dont un sous-groupe compte moins de cinq contributeurs sont masquées.
- Les recherches de produits sont analysées par catégorie. **Offre au catalogue** indique l’existence actuelle d’au moins une offre publiée dans cette catégorie. La disponibilité en stock, l’historique et la disponibilité dans la province déclarée nécessitent une source distincte.
- Les sujets de santé traduisent l’intérêt des personnes qui choisissent de partager leur recherche. La mesure de la fréquence des maladies dans la population nécessite d’autres données. Le rapprochement entre maladie et produit nécessite une source clinique validée.
- Le suivi agrège les besoins signalés et leur issue déclarée. Les analyses par compte individuel et les données de l’ancien tableau de bord ministériel sont hors du périmètre de cette collecte.

## Installation

La migration métier `20261114_01_analyse_recherches_annuaire` crée les tables de participation et de déclaration, leurs contrôles et la vue d’analyse. La migration initialise le registre vide. La migration `20261114_02_perimetre_indicateurs_recherche` expose le rattachement à l’entreprise dans la vue. La migration `20261114_03_licence_data_science` enregistre le module dans le catalogue des licences.
