# Chat Architecture

## Etat actuel

- Le frontend peut ouvrir une discussion ciblee via:
  - `/discussions?type=expert&id=<IdProfessionnel>`
  - `/discussions?type=structure&id=<IdEntite>`
- Le backend expose deja:
  - `GET /api/public/chat/context?type=expert&id=...`
  - `GET /api/public/chat/context?type=structure&id=...`
- Ce point d'entree retourne le contexte public de la cible et un indicateur de capacites.

## Limite actuelle

- Le schema existant contient `communication.T_Chat`, mais pas encore de notion de conversation ciblee,
  de participant, ni de destinataire.
- Le mode actuel est donc un mode `bootstrap`:
  - resolution de la cible
  - pre-ouverture de la conversation
  - pas encore de persistance des messages par thread

## Evolution recommandee

Ajouter des tables Prisma dediees au chat:

1. `communication.T_Conversation`
2. `communication.T_ConversationParticipant`
3. `communication.T_ConversationMessage`

## Champs recommandes

### T_Conversation

- `IdConversation`
- `TargetType`
- `TargetExpertFk` nullable
- `TargetEntiteFk` nullable
- `CreatedAt`
- `UpdatedAt`
- `StatusConversation`

### T_ConversationParticipant

- `IdConversationFk`
- `IdUserFk`
- `RoleParticipant`
- `JoinedAt`

### T_ConversationMessage

- `IdMessage`
- `IdConversationFk`
- `AuthorIdFk`
- `BodyMessage`
- `MessageFile`
- `MessageLink`
- `CreatedAt`
- `ReadAt`

## Endpoints futurs

- `GET /api/chat/conversations`
- `GET /api/chat/conversations/:id`
- `POST /api/chat/conversations/bootstrap`
- `POST /api/chat/conversations/:id/messages`
- `PATCH /api/chat/messages/:id/read`

## Regles de securite

- Ne jamais exposer les messages d'une conversation a un utilisateur non participant.
- Ne jamais exposer les champs sensibles des experts, des structures ou des utilisateurs.
- Journaliser l'ouverture et l'envoi des messages si necessaire.
