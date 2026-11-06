import AppIcon from "../../components/AppIcon";

export function conversationName(row) {
  return row?.recipient?.fullName || row?.recipient?.name || row?.SujetDiscussion || "Conversation";
}

export function conversationSubtitle(row) {
  const recipient = row?.recipient;
  if (recipient?.type === "expert") return recipient.specialty || recipient.professionalType || "Professionnel";
  if (recipient?.type === "structure") return recipient.structureType || "Entreprise";
  return "Discussion privée";
}

export function ConversationAvatar({ row }) {
  const initials = conversationName(row).trim().split(/\s+/).slice(0, 2).map(word => word[0]).join("").toLocaleUpperCase("fr");
  return <span className="communication-avatar" aria-hidden="true">{initials || <AppIcon name="user" />}</span>;
}
