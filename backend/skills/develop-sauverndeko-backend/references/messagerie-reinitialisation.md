# Messagerie et réinitialisation du mot de passe

Le compte reste dans systeme.T_Utilisateurs. La récupération utilise un lien signé Django valable 20 minutes, lié à l’identifiant, au hash actuel et à l’adresse e-mail. Aucun compte n’est copié dans auth_user et aucune table supplémentaire n’est créée.

## Expéditeur et transport

L’expéditeur par défaut est **SauverNdeko — benjaminmupanzi@gmail.com**, conformément au choix du propriétaire. Les administrateurs de plateforme peuvent changer son adresse et son nom via GET/PUT /api/systeme/messagerie, avec les seuls champs senderEmail et senderName. Le réglage est conservé dans la clé JSON messagerie.sender de systeme.T_Admin_UI_Setting, au périmètre global. Un gestionnaire local ne peut pas le modifier.

Le serveur SMTP utilise un compte Google Gmail ou Google Workspace autorisé. L’adresse d’expéditeur doit être ce compte ou un alias autorisé par Google ; modifier l’expéditeur dans l’application ne change pas les identifiants de connexion SMTP. Les secrets restent dans l’environnement du backend ou dans backend/.env local, jamais dans les réglages exposés à l’API.

- SAUVERNDEKO_EMAIL_HOST : smtp.gmail.com par défaut.
- SAUVERNDEKO_EMAIL_PORT : 587 par défaut.
- SAUVERNDEKO_EMAIL_USE_TLS : 1 par défaut ; SAUVERNDEKO_EMAIL_USE_SSL : 0 par défaut.
- SAUVERNDEKO_EMAIL_HOST_USER : benjaminmupanzi@gmail.com par défaut.
- SAUVERNDEKO_EMAIL_HOST_PASSWORD : vide par défaut ; mot de passe d’application Google autorisé pour l’expéditeur. Ce secret est distinct du mot de passe SauverNdeko.
- SAUVERNDEKO_FRONTEND_URL : origine explicite du frontend, http://localhost:5174 par défaut ; une URL HTTPS de déploiement se renseigne ici. Aucun lien ne dépend de l’en-tête Host du navigateur.

Un redémarrage du backend recharge l’environnement. Le backend d’e-mail est SMTP réel ; aucune substitution console/fichier ne simule un envoi. Les réponses available/canSend décrivent une configuration complète et un backend autorisé en écriture ; elles ne constituent pas un test de délivrance Google. Le contrôle de connexion SMTP se fait lors d’une demande réelle.

## Contrat public

- GET /SauverNdeko/auth/password-reset retourne available, minLength=12, maxLength=128, expiresInMinutes=20 et requiresReauthentication=true. available est faux en lecture seule ou si la configuration est incomplète.
- POST sur cette route accepte {email}. La réponse 202 est conditionnelle et identique pour une adresse inconnue, ambiguë ou un compte inactif. Aucun identifiant ni jeton n’est retourné. Une configuration ou connexion SMTP indisponible donne RESET_UNAVAILABLE (503), indépendamment de l’adresse demandée. Un refus de délivrance conserve la réponse conditionnelle et un journal technique sans destinataire ni secret.
- Le lien envoyé utilise /reset-password#uid=...&token=... ; le fragment évite de transmettre le jeton au serveur web dans l’URL. Le frontend le conserve seulement en mémoire et nettoie l’adresse affichée.
- POST /SauverNdeko/auth/password-reset/check accepte {uid,token}. Il valide le lien sans modification de compte ; RESET_LINK_INVALID (400) indique un lien expiré, utilisé ou invalide.
- POST /SauverNdeko/auth/password-reset/confirm accepte {uid,token,newPassword,confirmPassword}. Les validations communes imposent 12 à 128 caractères, confirmation exacte, refus d’un mot de passe courant, entièrement numérique, trop proche de l’identité ou identique à l’ancien. Les espaces et caractères Unicode saisis restent inchangés. RESET_VALIDATION (400) porte les erreurs par champ.

La confirmation verrouille le compte avant la seconde vérification du jeton. La mise à jour du hash et le marqueur PASSWORD_CHANGE partagent une transaction : deux confirmations concurrentes ne peuvent pas consommer deux fois le lien. Le compte et son entité doivent être actifs. Les anciens JWT access/refresh sont ensuite refusés, y compris les jetons historiques sans version grâce au marqueur d’audit. La réponse requiert une reconnexion ; aucune session n’est créée automatiquement.

Les demandes sont limitées par adresse réseau et par empreinte d’adresse e-mail ; vérification et confirmation ont également une limite de fréquence (429). Les mots de passe, liens et jetons ne sont ni journalisés ni inclus dans l’audit.

## Vérification

verifier_backend contrôle uniquement les routes GET, avec une connexion PostgreSQL imposée en lecture seule. Les recettes des demandes SMTP, expirations, validations et confirmations concurrentes utilisent des comptes fictifs, un accès SQL simulé et un transport simulé hors du dépôt. Aucune vérification ne doit réinitialiser un compte réel ni envoyer un e-mail réel sans une demande explicite adaptée.

## Contrôle depuis l’administration

Administration → Messagerie → Tester la connexion utilise POST /api/systeme/messagerie/test avec un objet vide. Seul l’administrateur global peut le lancer, en mode écritures autorisées ; trois demandes par minute. Le test ouvre et authentifie le transport puis le ferme, sans message ni destinataire. Une configuration présente, une authentification réussie et la réception d’un e-mail sont trois preuves distinctes.

Les valeurs par défaut du formulaire suivent EMAIL_HOST_USER valide, avec le nom SauverNdeko ; le réglage global explicitement enregistré reste prioritaire. L’instance locale utilise actuellement sauverndekordc@gmail.com comme compte et expéditeur. Le dernier contrôle TLS Google a réussi, mais AUTH LOGIN a renvoyé535 ; aucun e-mail n’a été envoyé. Le mot de passe d’application doit être corrigé dans le fichier privé avant un nouveau contrôle. La documentation Google décrit [les mots de passe d’application](https://support.google.com/accounts/answer/185833?hl=fr).
