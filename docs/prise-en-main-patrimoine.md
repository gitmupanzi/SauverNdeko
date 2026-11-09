# Prise en main — Patrimoine

Ouvrez **Logistique → Patrimoine → Immobilisations**. Le compte de plateforme choisit l’entreprise concernée ; les utilisateurs locaux travaillent dans leur entreprise selon leurs droits. Les biens d’une autre entreprise ne deviennent pas disponibles par un simple changement de filtre.

## Enregistrer un bien

Cliquez sur **Nouvelle immobilisation**. Le même formulaire permet ensuite de modifier la fiche avec ses valeurs déjà renseignées.

1. **Identification** : indiquez le nom, le type et l’état du matériel. L’état est facultatif : le laisser vide signifie qu’il n’est pas renseigné. Choisissez **Bien individuel** pour une pièce, ou **Lot homogène** pour plusieurs biens ayant les mêmes caractéristiques et affectations. Un numéro de série impose une seule pièce. Référence et caractéristiques sont facultatives. Après enregistrement, le code automatique **IMMO-…** reste affiché ici.
2. **Affectation** : choisissez le responsable et le service, puis saisissez librement le lieu du bien, par exemple « Bâtiment B, bureau 12 ». Les anciennes localisations référencées restent visibles.
3. **Acquisition** : vérifiez la date d’entrée, puis ajoutez la date d’acquisition, la date de mise en service et le prix si vous les connaissez. Un prix renseigné exige une devise ; un prix vide reste inconnu, un prix de zéro représente une valeur connue nulle.
4. **Traçabilité** : ajoutez les observations utiles et consultez les dates de création et de modification disponibles, puis enregistrez.

Le registre calcule la valeur d’acquisition à partir de la quantité et du prix. Il ne retire aucune quantité des Articles et ne crée aucun mouvement de stock. Le coût de cette fiche est distinct du coût retenu dans chaque plan de valorisation.

## Consulter et suivre les affectations

Le nom du bien et **Consulter** ouvrent **Immobilisation 360** : Synthèse, Affectation, Acquisition, Cycle de vie, Valorisation et Historique. La colonne **Changements** présente les valeurs avant → après du responsable, du service, de l’état et de la localisation, avec leurs libellés. **Sans affectataire** indique le retrait du responsable ; un simple archivage sans autre changement affiche un tiret. Les valeurs précédentes et leur auteur restent conservés dans l’audit.

Les listes de type, état et service utilisent les référentiels partagés. Une nouvelle valeur autorisée devient disponible sans recopier la liste dans les écrans. Les responsables proposés sont actifs, rattachés à l’entreprise et affectables selon leurs dates d’emploi. Un changement de service professionnel ne déplace pas automatiquement le matériel déjà affecté.

Une ancienne affectation reste consultable après la désactivation du responsable. Son entreprise ou celle d’un lieu lié ne peut pas être changée tant qu’un bien lui reste rattaché.

## Suivre le cycle de vie

- Pour déplacer un bien ou changer sa responsabilité, ouvrez **Affectation**, renseignez le service, le lieu ou la personne et indiquez le motif. Les anciennes valeurs restent visibles dans **Historique**.
- Dans **Cycle de vie**, ajoutez un justificatif (PDF ou image), un entretien ou un comptage. Le comptage conserve la quantité théorique au moment de la saisie et présente l’écart sans corriger la fiche.
- Une cession ou mise au rebut enregistre la sortie de la fiche entière avec une date et un motif. La fiche demeure consultable et exportable. La sortie comptable des plans se constate ensuite dans **Valorisation**.

## Suivre la valeur

Dans **Valorisation**, choisissez un usage **Comptable** ou **Fiscal** et renseignez les paramètres validés avec votre comptable, notamment le coût, la devise, le départ, la durée et la valeur résiduelle. Reportez la référence de cette validation. L’échéancier présente les dotations restant à constater. Enregistrez une dotation pour une date précise afin qu’elle soit prise en compte dans le cumul et dans la valeur nette.

Les événements d’amélioration, de perte de valeur et de sortie restent dans le journal du plan. À la sortie, la valeur nette juste avant l’événement reste consultable. Une clôture protège l’ensemble des plans de l’entreprise pour l’usage choisi jusqu’à la date indiquée. Les dotations et sorties en attente doivent être traitées avant la clôture.

## Rechercher, exporter et archiver

La recherche et les filtres affinent le registre. **Réglages** permet de choisir les colonnes ; les choix du tableau et de l’export sont enregistrés séparément. Les libellés du type, de l’état, du service et du lieu remplacent leurs identifiants techniques à l’écran.

Le menu **⋯** propose les actions disponibles : consulter, modifier, archiver, réactiver et télécharger la fiche PDF. Le PDF reprend l’identité actuelle de l’entreprise selon [ses réglages documentaires](identite-entreprise-pdf.md). Les exports suivent le périmètre, les filtres et les colonnes choisis.

**Archiver** conserve la fiche et son historique. **Réactiver** la remet dans le registre actif. Ces actions ne correspondent ni à une sortie de stock ni à une cession comptable. En cas de conflit de modification, rechargez la fiche et contrôlez ses valeurs avant de reprendre.

## Informations professionnelles des utilisateurs

Dans **Administration → Utilisateurs**, l’onglet **Professionnel** rassemble matricule, service, fonction, début et fin d’emploi ainsi qu’une note professionnelle facultative. Il complète le compte existant ; la fonction professionnelle est distincte du rôle qui détermine les droits.

Le matricule est unique dans l’entreprise sans distinction de casse. Les dates d’emploi servent aux nouvelles affectations de matériel. Le choix d’un responsable peut présenter son nom, son matricule et son service ; les dates et la note professionnelle restent privées dans l’administration autorisée et ne sont pas ajoutées à ces listes ou au profil public.

Les fonctions de cycle de vie et de valorisation nécessitent la livraison décrite dans [le plan de migration et de validation](immobilisations-plan-migration.md).
