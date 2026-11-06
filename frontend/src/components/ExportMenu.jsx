import RowActionsMenu from "./RowActionsMenu";
import "./ActionButton.css";

export default function ExportMenu({ exportFile, exportCsv, disabled, exporting, selection = false, title }) {
  const label = selection ? "Exporter la sélection" : "Exporter";
  return (
    <RowActionsMenu
      label={selection ? "Formats d’export de la sélection" : "Formats d’export"}
      triggerText={exporting ? "Préparation…" : label}
      triggerIcon="download"
      triggerClassName="ui-action is-secondary"
      triggerTitle={title || label}
      disabled={disabled || exporting}
      items={[
        { label: "Excel", icon: "download", onSelect: exportFile },
        { label: "CSV", icon: "download", onSelect: exportCsv },
      ]}
    />
  );
}
