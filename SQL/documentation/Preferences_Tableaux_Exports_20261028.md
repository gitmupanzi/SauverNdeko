# Préférences de tableaux et exports

Le catalogue de référence est conservé dans `referentiel."T_InterfaceTableau"`.
Les choix personnels sont dans `referentiel."T_PreferenceTableau"`, avec une clé
unique par interface, utilisateur, entreprise et usage. Le contexte « toutes les
entreprises » des administrateurs globaux possède sa propre préférence. Aucun
choix personnel ne modifie la configuration commune.

Les usages `table` et `export` sont indépendants. L'ordre de référence du tableau
et celui de l'export sont également indépendants. Une réinitialisation retire
uniquement la préférence de l'usage demandé ; elle ne modifie ni les documents
ni les préférences d'autres comptes. Les versions empêchent un navigateur
d'écraser silencieusement un choix enregistré ailleurs.

Les identifiants des colonnes sont stables. Une colonne supprimée du catalogue
ne bloque pas une ancienne préférence ; une colonne ajoutée devient disponible
sans être imposée dans les choix déjà enregistrés. `tableAvailable` distingue
les colonnes utilisables à l'écran des champs supplémentaires proposés pour
l'exploitation autonome des exports. `actions` n'est jamais exportable.

L'API dédiée `/api/tableaux/<interface>/preferences` relit les droits du module.
Elle ne reçoit aucun identifiant utilisateur ou entreprise dans le corps de la
requête. L'utilisateur connecté et le contexte d'entreprise validé déterminent
la portée. Les tables de préférences sont refusées par le CRUD générique du
référentiel afin de ne pas exposer les choix personnels d'autres comptes.

Les exports des registres Logistique, Référentiels et Administration utilisent
la préférence `export` lorsque le choix n'est pas explicite. Une liste de
colonnes explicite est vérifiée contre le catalogue fermé du service : une
colonne inconnue, dupliquée, interactive ou non autorisée est refusée. L'ordre
est conservé exactement ; aucune colonne d'unité ou de devise n'est ajoutée
silencieusement. La configuration de référence inclut les unités et devises
utiles, que l'utilisateur peut conserver dans ses exports.

Les exports `.xlsx` et `.csv` reprennent les mêmes prédicats d'accès, filtres et
tri que le registre. `selection` contient les identifiants sélectionnés et
s'ajoute aux critères autorisés. Son absence signifie tous les résultats
filtrés, indépendamment de la pagination. Le plafond de 100 000 lignes produit
un refus explicite s'il est dépassé, jamais un fichier tronqué présenté comme
complet.

La fiche Excel individuelle du menu de ligne est un document distinct de
l'export personnalisé du registre. Elle conserve les champs métier de son
gabarit de référence, même si la préférence d'export de liste ne contient qu'une
seule colonne. `documentScope=record` exige exactement un identifiant sélectionné
et n'accepte aucun remplacement de colonnes ; les mêmes droits et périmètres
restent imposés. Ce signal ne donne aucun accès supplémentaire. Les PDF métier
et le journal d'un lot conservent leurs gabarits dédiés.

Le classeur XLSX possède ses en-têtes sur la première ligne de « Données », les
données dès la deuxième ligne, une présentation gris clair et une feuille
« Informations » distincte. Les quantités et montants restent numériques, les
dates restent natives. Les références et codes textuels, notamment `000123`,
restent du texte exact. Les chaînes ressemblant à des formules sont écrites en
texte et ne sont pas exécutées. Les booléens se lisent « Oui » ou « Non ».

Le CSV est produit en UTF-8 avec BOM, séparateur point-virgule et retours CRLF.
Les accents, guillemets, séparateurs et retours à la ligne sont échappés par un
véritable générateur CSV. Les nombres décimaux utilisent la virgule. Un texte
susceptible d'être interprété comme une formule est préfixé d'une apostrophe.
L'ouverture directe d'un CSV dans Excel peut convertir `000123` en `123` :
cette limite appartient au format sans type. Utiliser le XLSX pour garantir les
zéros initiaux, ou importer explicitement la colonne CSV comme texte dans Excel.

`logistique."V_QuantitesBonUnite"` conserve une ventilation exacte par unité.
Le registre des bons ne fournit une quantité scalaire que pour une seule unité
connue ; un bon mêlant des kilogrammes et des pièces n'affiche pas leur somme.
L'export propose aussi « Quantités par unité ». Les quantités JSON sont des
chaînes décimales pour préserver leur précision.

La recette `SQL/tests/test_preferences_tableaux.py` nécessite une base explicite
`sauverndeko_test_*` et refuse la base applicative. Elle vérifie la persistance,
l'isolation, l'indépendance des usages, la concurrence, les droits, la sélection,
l'exhaustivité filtrée et les formats réels XLSX/CSV. Elle ne modifie aucun compte
ni document client.
