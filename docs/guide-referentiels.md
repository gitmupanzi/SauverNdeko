# Référentiels

Le module réunit quatre onglets pour cinq tables du schéma `referentiel`. Les deux tables de présentation sont regroupées dans **Tableaux et exports** afin de réutiliser les réglages déjà présents dans chaque registre.

## Catégories et valeurs

**Nouvelle catégorie** et **Nouvelle valeur** ouvrent directement le panier de saisie. Une seule ligne suffit pour un ajout individuel ; plusieurs lignes peuvent être préparées, modifiées et retirées avant un enregistrement unique. Pour les valeurs, choisir d’abord leur catégorie dans l’en-tête. Il n’y a pas de bouton de saisie multiple séparé.

Pour reprendre une liste Excel, choisir la portée et, pour les valeurs, la catégorie dans l’en-tête. **Télécharger le modèle Excel** fournit un fichier `.xlsx` vierge adapté à l’onglet. Remplir sa feuille **Catégories** ou **Valeurs**, puis utiliser **Importer un fichier Excel**. Chaque fichier peut contenir 100 lignes au maximum et peser 4 Mo ; le panier peut contenir 200 lignes. La portée et la catégorie du formulaire s’appliquent à toutes les lignes et ne sont pas importées depuis les cellules.

L’import ajoute les lignes au panier déjà préparé, sans enregistrer de données. Vérifier les libellés, codes et états, puis ouvrir les **Détails** d’une valeur pour corriger ses informations et chaque option de visibilité. Les choix acceptent **Oui** et **Non** ; une visibilité peut aussi rester **Non renseigné**. Une cellule d’état ou de visibilité vide reprend **Oui**. Les valeurs incorrectes restent visibles dans le panier pour correction. Le collage de cellules reste disponible avec les mêmes contrôles. Les formules et liens de classeur sont refusés.

**Enregistrer l’ensemble** enregistre ensuite le lot en une seule transaction. Une erreur ou un doublon laisse le panier ouvert avec les corrections nécessaires. Aucune ligne du lot n’est conservée si une autre ligne échoue. Un fichier refusé ne retire aucune ligne déjà saisie.

Les références **communes** restent disponibles pour les entreprises autorisées. Les références **d’entreprise** ne sont proposées que dans leur entreprise. Les données antérieures restent communes ; leur rattachement n’est pas modifié par cette évolution. Un gestionnaire local ne peut modifier que les références propres à son entreprise, selon ses droits. La propriété d’une référence créée est conservée.

Une catégorie commune peut recevoir des valeurs propres à une entreprise. Une catégorie privée ne reçoit que des valeurs de cette même entreprise. Les identifiants existants restent les clés utilisées par les articles, bons et autres données métier.

Les doublons historiques ne sont pas fusionnés automatiquement. Pour une nouvelle saisie, le contrôle tient compte des libellés et des codes, des espaces et de la casse, ainsi que des références communes et de l’entreprise concernée. Les accents ne sont pas supprimés arbitrairement.

Si la connexion est interrompue pendant l’enregistrement, utiliser **Vérifier l’enregistrement** dans le formulaire resté ouvert. La même demande est vérifiée sans créer une seconde fois les lignes. Un changement explicite d’entreprise ferme les formulaires ouverts ; leur saisie n’est jamais transférée vers la nouvelle entreprise.

## Référencement des champs

Cet onglet, réservé à l’administration de plateforme, associe un champ physique à une catégorie. **Modifier** change les choix proposés ; **Rétablir la valeur par défaut** reprend le défaut prévu pour ce champ. La portée est explicite et les champs partagés restent communs.

Changer une association ne réécrit aucune valeur métier. Une ancienne référence devenue incompatible reste affichée avec un avertissement. Une nouvelle sélection doit appartenir à la catégorie et à l’entreprise autorisées. Les réglages **Références** de Logistique présentent également les identifiants et noms des catégories utilisées.

## Tableaux et exports

Le registre présente les tableaux accessibles et indique si leur affichage ou leur export est personnalisé dans l’espace courant. **Consulter les colonnes** montre le catalogue commun ; **Mes réglages** réutilise la fenêtre de configuration habituelle.

Les colonnes du tableau et celles des exports ont des réglages indépendants. Les choix sont personnels et liés à l’espace de travail ; ils ne modifient pas les préférences d’un autre utilisateur. **Rétablir la référence** supprime la personnalisation concernée et reprend le catalogue commun. Les définitions techniques des tableaux restent protégées.
