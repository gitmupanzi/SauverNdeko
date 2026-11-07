# SauverNdeko — 1.0.0

Plateforme modulaire de gestion et de mise en relation, construite avec **Django / Django REST Framework, PostgreSQL et React / Vite**.

Le numéro de livraison est conservé dans [VERSION](VERSION). La mise à niveau en ligne du 7 novembre 2026 et ses contrôles sont décrits dans le [bilan Render](docs/livraison-render-20261107.md). La version des sources et la version effectivement déployée sont deux informations distinctes.

## Démarrer en local

Prérequis : Windows/PowerShell, Python 3.12, Node.js 22 et PostgreSQL 18. La base locale existante est `sauver_ndeko_pro`.

Depuis la racine du projet :

```powershell
# À la première installation des dépendances frontend.
Push-Location frontend
npm ci
Pop-Location

.\demarrer.bat
```

Le lanceur démarre Django et Vite, puis ouvre **http://localhost:5174/catalogue**. L’espace connecté est `/espace`. Les liens vers les modules exigent la connexion, la licence et les permissions correspondantes.

Les autres lanceurs sont `arreter.bat`, `redemarrer.bat` et `adresse-reseau.bat`. Le [guide de lancement](docs/lancement-local.md) décrit les ports, le réseau local et les diagnostics. Le démarrage ne recrée pas la base et n’applique pas automatiquement de migration.

`backend/.env` reste privé. Conserver ses valeurs existantes ; les secrets de production et le compte PostgreSQL propriétaire ne doivent pas être publiés dans Git. `SAUVERNDEKO_DB_READ_ONLY=0` autorise les écritures déjà permises par les rôles ; sa valeur par défaut dans une nouvelle configuration reste `1`.

## Modules et fonctionnalités

- **Produits, Structures et Professionnels** : offres et annuaires, fiches publiées et mise en relation selon les droits.
- **Logistique** : tiers, articles, lots, BE/BS et commandes, inventaires, factures, règlements, avoirs et immobilisations.
- **Caisse** : caisses par entreprise et devise, écritures, contrepassations et clôtures.
- **Discussions et Support** : échanges privés, annonces internes et suivi des demandes.
- **Organisation territoriale** : niveaux, coordonnées, analyses et rapprochements territoriaux, sous les habilitations de plateforme.
- **Référentiels, Paramètres, Administration et Guide utilisateur** : nomenclatures partagées ou d’entreprise, configuration, accès et aide intégrée.

Le catalogue commercial et les accès effectifs sont décrits dans [Modules et fonctionnalités](docs/modules-et-fonctionnalites.md). Masquer un onglet ou changer son intitulé ne modifie jamais une permission.

## Organisation du dépôt

| Dossier | Rôle |
|---|---|
| `frontend/` | Interfaces React, composants communs, tests d’interface et dépendances npm verrouillées. |
| `backend/` | API Django, services métier, modèles non gérés par l’ORM et dépendances Python verrouillées. |
| `SQL/` | Sources canoniques, migrations immuables, manifeste de versions, contrôles et recettes PostgreSQL. |
| `deploy/` | Construction Docker, configuration Render, maintenance et droits du compte web. |
| `scripts/` | Lanceurs Windows, démarrage Render et contrôles techniques. |
| `skills/` | Conventions du projet et charte documentaire. |
| `docs/` | Guides, décisions, résultats de tests et limites connues. |

Les données, médias privés, sauvegardes et preuves locales restent dans les emplacements exclus de Git. Les captures SQL historiques sont conservées comme références de conception et exclues de l’image Docker.

## Principes techniques

PostgreSQL porte les vues, contraintes, fonctions et triggers métier commentés. Les effets sur le stock sont réalisés une seule fois par les routines existantes. Les champs catégoriels enregistrent `ID_Generique` et affichent `AbrGenerique`.

Les données métier sont rattachées durablement à leur entreprise. Le backend contrôle les licences, permissions et périmètres ; une sélection dans le navigateur ne suffit pas à autoriser un accès. L’administrateur global dispose du périmètre prévu par son rôle.

Les modèles métier Django restent `managed=False`. Les tables natives Django sont dans `public`. Les mises à jour métier suivent [le manifeste et le journal de migrations](docs/mises-a-jour-base.md), sans suppression ni recréation des données clientes.

## Vérifications et déploiement

```powershell
.\backend\.venv\Scripts\python.exe .\backend\manage.py check

Push-Location frontend
npm run test:ux
npm run build
Pop-Location
```

Les tests PostgreSQL de `SQL/tests` exigent une base de recette distincte. Ne pas les exécuter sur les données clientes. Le [guide backend](backend/README.md) décrit les diagnostics en lecture seule.

La livraison Render utilise `deploy/render/Dockerfile`, un compte web restreint et un disque média persistant. Les mises à jour nécessitent une sauvegarde restaurée sur copie, une maintenance séparée et la vérification du commit réellement en ligne. Un push ne transfère pas les fichiers `.env` et ne prouve pas un déploiement.

- [Notes de version 1.0.0](CHANGELOG.md).
- [Déploiement Render](docs/deploiement-render.md) et [maintenance depuis le poste](docs/maintenance-render-depuis-poste.md).
- [Guide Logistique](docs/prise-en-main-logistique.md), [Patrimoine](docs/prise-en-main-patrimoine.md), [Caisse](docs/module-caisse.md), [Référentiels](docs/guide-referentiels.md) et [Territoires](docs/module-organisation-territoriale.md).
- [Vision scientifique et feuille de route](docs/vision-et-feuille-de-route-scientifique.md).

## Limites à conserver à l’esprit

La version 1.0.0 identifie un état livré du code ; elle ne remplace pas l’acceptation des parcours par le client. Le [bilan du 7 novembre](docs/livraison-render-20261107.md) distingue les contrôles réussis des points ouverts : automatisation GitHub Actions bloquée par la facturation, installation vierge courante à fiabiliser et délivrance Gmail à vérifier. La restauration et la mise à niveau de l’instance de production ont, elles, été vérifiées.
