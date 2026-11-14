import ActionButton from "./ActionButton";

export default function RegisterSettingsButton({ buttonRef, expanded = false, onTableSettings }) {
  return <ActionButton ref={buttonRef} icon="settings" aria-haspopup="dialog" aria-expanded={expanded}
    onClick={onTableSettings}>Réglages</ActionButton>;
}
