# Notes de version

## 1.0.0 — 7 novembre 2026

Première version identifiée par un tag Git `v1.0.0`. Le numéro racine `VERSION`, le paquet frontend et son verrou de dépendances portent `1.0.0`.

### Périmètre

Cette version rassemble les modules et fonctionnalités décrits dans le [README](README.md) : logistique, caisse, annuaires Produits/Structures/Professionnels, discussions, support, organisation territoriale, référentiels et administration par entreprise. Leur visibilité reste soumise aux licences et permissions existantes.

### Nettoyage de la livraison

- Suppression de 16 fichiers frontend sans consommateur actif : anciennes pages d’accueil et d’inscription, données de démonstration, anciens composants de présentation et cinq maquettes PNG, soit environ 6,2 Mo.
- Conservation des illustrations de la vitrine actuelle, des outils de maintenance, des tests utiles, des migrations immuables et des documents de référence.
- README racine et backend actualisés ; liens des skills corrigés ; états historiques SQL distingués du bilan actuel.
- Exclusion des captures SQL, diagrammes de conception et caches du contexte Docker. Ces références restent disponibles dans Git.
- Protections Git complétées pour les caches Vite, fichiers statiques collectés et résultats de couverture.

### Vérifications de ce nettoyage

- Graphe d’imports et recherches des consommateurs avant suppression.
- 941 contrôles frontend réussis : composants communs, catalogue, structures, profils et navigation.
- Compilation Vite réussie : 350 modules transformés.
- 34 tests des outils Render et 11 tests des sauvegardes/commentaires réussis.
- Contrôle système Django réussi.
- Contrôles des migrations métier et natives Django réussis sur la base locale `sauver_ndeko_pro`, dans un processus imposant la lecture seule ; aucune migration en attente et catalogue inchangé.
- Cohérence des trois numéros de version, liens documentaires et exclusions des fichiers privés vérifiés.

Les recettes métier et la mise en ligne du commit applicatif précédent sont documentées séparément dans le [bilan Render du 7 novembre](docs/livraison-render-20261107.md). Ce nettoyage n’ajoute aucune migration et ne modifie aucune donnée ou configuration privée.

Le `.env` présent pendant la vérification désignait l’hôte interne Render, non joignable depuis ce poste. Le contrôle local a utilisé la connexion locale existante dans un processus séparé, sans réécrire ce fichier. Docker n’est pas installé sur le poste : l’image de ce nettoyage n’a pas été construite localement.

### Limites connues

- L’automatisation GitHub Actions reste bloquée par la facturation du compte ; le tag n’atteste pas un nouveau déploiement Render.
- Le parcours d’installation vierge courant conserve un décalage de socle à corriger ; la mise à niveau de l’instance existante a été testée séparément.
- La recette exhaustive des parcours par le client et la délivrance des e-mails Gmail restent à confirmer.
