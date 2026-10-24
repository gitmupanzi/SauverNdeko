# Lancement local de SauverNdeko

Ce guide concerne le projet SauverNdeko installé dans C:\Users\Benjamin-mupanzi\Documents\SauverNdeko. Les lanceurs de la racine pilotent le backend Django et le frontend React/Vite à travers scripts/sauverndeko-local.ps1 et scripts/sauverndeko-service.ps1.

## Prérequis

- Windows et PowerShell.
- Python 3.12 et son lanceur py.exe si backend/.venv doit être créé.
- Node.js avec node et npm accessibles dans le PATH.
- PostgreSQL accessible avec la base applicative SauverNdeko et sa structure déjà installée.
- backend/.env configuré : DATABASE_URL vise SauverNdeko ; JWT_SECRET et JWT_REFRESH_SECRET sont renseignés. Conserver ce fichier privé et ne pas écraser ses valeurs.

Le backend utilise uniquement backend/requirements.txt pour ses dépendances Python verrouillées. Si backend/.venv est absent, demarrer.bat le crée avec Python 3.12 et installe ce fichier ; cette installation nécessite un accès au dépôt de paquets configuré. Un environnement existant n’est pas réinstallé automatiquement.

Si frontend/node_modules est absent, installer les dépendances depuis la racine :

~~~powershell
Set-Location 'C:\Users\Benjamin-mupanzi\Documents\SauverNdeko'
Push-Location .\frontend
npm ci
Pop-Location
~~~

Le démarrage utilise la base existante : aucune base, table ou migration SQL n’est créée automatiquement. Une base de test n’est pas nécessaire pour utiliser l’application.

## Démarrer et arrêter

Depuis PowerShell à la racine du projet :

~~~powershell
.\demarrer.bat
.\adresse-reseau.bat
~~~

demarrer.bat contrôle Django, démarre les services en arrière-plan, attend leur disponibilité et ouvre le navigateur. Le contrôle de disponibilité vérifie aussi PostgreSQL, sans lire de données métier en anonyme. Les deux services déjà suivis, sains et lancés dans le même mode sont réutilisés.

| Fichier | Action |
|---|---|
| demarrer.bat | Démarre Django et React/Vite puis ouvre l’application. |
| arreter.bat | Arrête les processus de cette instance suivis par le lanceur et leurs enfants. |
| redemarrer.bat | Arrête puis relance les deux services. |
| adresse-reseau.bat | Affiche l’état et l’adresse locale ; en mode réseau, affiche aussi les adresses du réseau local. |

On peut aussi ouvrir ces fichiers BAT depuis l’Explorateur. Leurs chemins sont calculés à partir du dossier du projet.

Le frontend utilise le port fixe 5174 : http://localhost:5174/. Si ce port est occupé, le démarrage s’arrête avec un message explicite ; aucun autre port frontend n’est choisi. Vite applique aussi ce comportement avec npm run dev. Django utilise le port 5000 par défaut et peut choisir un port libre dans la plage 5000–5029. Le proxy Vite reçoit le port Django choisi.

Utiliser l’adresse affichée par adresse-reseau.bat : le port frontend reste 5174 après un redémarrage. Le navigateur utilise l’adresse du frontend, qui transmet les requêtes API au backend. Fermer le navigateur n’arrête pas les serveurs.

~~~powershell
.\redemarrer.bat
.\arreter.bat
~~~

L’arrêt vérifie le chemin du script, l’identifiant de l’instance et la date de création de chaque processus suivi. Une ancienne instance lancée dans une autre session Windows peut nécessiter sa fermeture depuis cette session.

## Accès depuis le réseau local

Pour démarrer ou redémarrer avec l’accès réseau :

~~~powershell
.\demarrer.bat -Reseau
# Si les services sont déjà démarrés :
.\redemarrer.bat -Reseau
.\adresse-reseau.bat
~~~

Ouvrir sur l’autre poste l’une des adresses réseau affichées. Windows doit autoriser Node.js sur le réseau concerné.

Pour conserver ce choix, définir SAUVERNDEKO_NETWORK_MODE=lan dans backend/.env. La valeur local limite l’écoute à ce PC. SAUVERNDEKO_NETWORK_ALIAS accepte un nom DNS exact facultatif, déjà résolu par le réseau ; le lanceur ne crée ni entrée DNS ni règle de pare-feu.

Seul Vite écoute sur les interfaces réseau en mode LAN. Django reste sur 127.0.0.1 ; le lanceur ne change pas l’exposition de PostgreSQL. Les appels API passent par le proxy de Vite et les hôtes autorisés sont explicites. Ces serveurs sont destinés au développement local ; le déploiement client nécessite une configuration dédiée.

## État, journaux et diagnostic

| Emplacement | Contenu |
|---|---|
| .runtime/services.json | Ports, identifiants des processus suivis et mode de lancement. |
| .runtime/acces-reseau.txt | Dernières adresses affichées par adresse-reseau.bat. |
| .runtime/backend-PORT.out.log et .err.log | Sortie et erreurs du serveur Django. |
| .runtime/frontend-PORT.out.log et .err.log | Sortie et erreurs de Vite. |

PORT représente le port réellement choisi. Les fichiers d’état ne contiennent pas les secrets de connexion.

En cas d’échec, lire le message du lanceur puis le journal du service concerné. Pour contrôler le backend sans modifier PostgreSQL, depuis la racine :

~~~powershell
.\backend\.venv\Scripts\python.exe .\backend\manage.py check
.\backend\.venv\Scripts\python.exe .\backend\manage.py verifier_backend
~~~

Le second contrôle utilise des requêtes GET et une identité synthétique de diagnostic ; il ne valide pas un mot de passe client. La connexion applicative PostgreSQL reste en lecture seule par défaut avec SAUVERNDEKO_DB_READ_ONLY=1. La connexion et les consultations sont disponibles ; les écritures applicatives sont refusées tant que ce mode reste actif.

## Utilisation sans interaction

~~~powershell
.\demarrer.bat -NoPause -NoBrowser
.\adresse-reseau.bat -NoPause
.\redemarrer.bat -NoPause -NoBrowser
.\arreter.bat -NoPause
~~~

Placer -NoPause en premier pour éviter la pause du fichier BAT en cas d’erreur ; -NoBrowser évite l’ouverture du navigateur.

Les contrôles précédents du 24 octobre 2026 ont couvert le démarrage réel, la réutilisation sans duplication, le proxy, le redémarrage et l’arrêt. Le mode réseau a été contrôlé sur sa configuration ; l’accès depuis un second ordinateur reste à vérifier.

Voir aussi le [guide backend](../backend/README.md) et le [guide SQL](../SQL/README.md).

L’ouverture sans session présente la connexion. Après authentification, l’accueil affiche les applications autorisées par Django. La création des comptes est réservée à l’administration.
