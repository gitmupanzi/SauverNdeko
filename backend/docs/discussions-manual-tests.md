# Discussions - tests manuels

Pre requis:

- Le backend doit etre lance.
- Prisma doit etre valide.
- Il doit exister au moins une cible reelle:
  - un `T_Professionnel` pour `type=expert`
  - ou une `T_Entite` pour `type=structure`

Le module peut creer automatiquement un utilisateur technique de fallback si
l'authentification n'est pas encore branchee.

## Demarrer ou reutiliser une discussion expert

```bash
curl -X POST http://localhost:3000/api/discussions/start \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"expert\",\"targetId\":1}"
```

## Demarrer ou reutiliser une discussion structure

```bash
curl -X POST http://localhost:3000/api/discussions/start \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"structure\",\"targetId\":1}"
```

## Lister les discussions

```bash
curl http://localhost:3000/api/discussions
```

## Lister les messages d'une discussion

```bash
curl http://localhost:3000/api/discussions/1/messages
```

## Envoyer un message

```bash
curl -X POST http://localhost:3000/api/discussions/1/messages \
  -H "Content-Type: application/json" \
  -d "{\"message\":\"Bonjour, j'ai besoin d'une orientation.\"}"
```

## Simuler un utilisateur explicite

```bash
curl http://localhost:3000/api/discussions \
  -H "x-user-id: 1"
```

## Avec token Bearer

```bash
curl http://localhost:3000/api/discussions \
  -H "Authorization: Bearer <access_token>"
```
