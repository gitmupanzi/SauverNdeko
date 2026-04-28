const numberFormatter = new Intl.NumberFormat("fr-FR");
const currencyFormatter = new Intl.NumberFormat("fr-FR", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 2,
});

export function formatNumber(value) {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? numberFormatter.format(parsed) : "0";
}

export function formatCurrency(value) {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? currencyFormatter.format(parsed) : currencyFormatter.format(0);
}

export function formatDate(value, options = {}) {
  if (!value) {
    return "-";
  }

  const parsed = new Date(value);

  if (Number.isNaN(parsed.getTime())) {
    return String(value);
  }

  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    ...(options.withTime
      ? {
          hour: "2-digit",
          minute: "2-digit",
        }
      : {}),
  }).format(parsed);
}

export function toInputDateValue(value) {
  if (!value) {
    return "";
  }

  const parsed = new Date(value);

  if (Number.isNaN(parsed.getTime())) {
    return "";
  }

  return parsed.toISOString().slice(0, 10);
}

export function toInputDateTimeValue(value) {
  if (!value) {
    return "";
  }

  const parsed = new Date(value);

  if (Number.isNaN(parsed.getTime())) {
    return "";
  }

  const year = parsed.getFullYear();
  const month = `${parsed.getMonth() + 1}`.padStart(2, "0");
  const day = `${parsed.getDate()}`.padStart(2, "0");
  const hours = `${parsed.getHours()}`.padStart(2, "0");
  const minutes = `${parsed.getMinutes()}`.padStart(2, "0");
  return `${year}-${month}-${day}T${hours}:${minutes}`;
}

export function getApiMessage(response, fallbackMessage) {
  if (!response) {
    return "Impossible de contacter le serveur.";
  }

  return response.message || fallbackMessage;
}

export function asArrayPayload(response) {
  return Array.isArray(response?.data) ? response.data : [];
}

export function SectionCard({ title, subtitle, actions, children, className = "" }) {
  return (
    <section className={`logistics-card ${className}`.trim()}>
      <div className="logistics-card-head">
        <div className="section-head">
          <h3>{title}</h3>
          {subtitle ? <p>{subtitle}</p> : null}
        </div>
        {actions ? <div className="logistics-card-actions">{actions}</div> : null}
      </div>
      {children}
    </section>
  );
}

export function SummaryCard({ title, value, tone = "default", caption }) {
  return (
    <article className={`logistics-summary-card is-${tone}`}>
      <span>{title}</span>
      <strong>{value}</strong>
      {caption ? <small>{caption}</small> : null}
    </article>
  );
}

export function StatusBanner({ feedback }) {
  if (!feedback?.message) {
    return null;
  }

  return (
    <section className={`profile-feedback ${feedback.type === "success" ? "is-success" : "is-error"}`}>
      {feedback.message}
    </section>
  );
}

export function LoadingErrorEmpty({ loading, error, rows, emptyMessage = "Aucune donnee disponible." }) {
  if (loading) {
    return <section className="table-empty-state">Chargement des donnees...</section>;
  }

  if (error) {
    return <section className="table-empty-state">{error}</section>;
  }

  if (Array.isArray(rows) && rows.length === 0) {
    return <section className="table-empty-state">{emptyMessage}</section>;
  }

  return null;
}

function escapeCsvValue(value) {
  const normalized = String(value ?? "");

  if (/[",;\n]/.test(normalized)) {
    return `"${normalized.replace(/"/g, '""')}"`;
  }

  return normalized;
}

function resolveTableRowId(row, index) {
  return (
    row.id ||
    row.ID_Mvt ||
    row.ID_Article ||
    row.ID_Commande ||
    row.ID_Reglement ||
    row.ID_CmdFk ||
    `${index}`
  );
}

export function exportRowsToCsv(filename, columns, rows) {
  const csvLines = [
    columns.map((column) => escapeCsvValue(column.label)).join(";"),
    ...rows.map((row, index) =>
      columns
        .map((column) => {
          const rawValue = column.exportValue
            ? column.exportValue(row, index)
            : column.renderText
              ? column.renderText(row, index)
              : row[column.key] ?? "";

          return escapeCsvValue(rawValue);
        })
        .join(";")
    ),
  ];

  const blob = new Blob([csvLines.join("\n")], { type: "text/csv;charset=utf-8;" });
  const link = document.createElement("a");
  const url = URL.createObjectURL(blob);
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

export function TableToolbar({ title = "Tableau", rows = [], columns = [], exportFilename = "export.csv" }) {
  return (
    <div className="logistics-table-toolbar">
      <div className="logistics-table-toolbar-copy">
        <strong>{title}</strong>
        <span>{`${rows.length} ligne${rows.length > 1 ? "s" : ""} visible${rows.length > 1 ? "s" : ""}`}</span>
      </div>
      <div className="logistics-table-toolbar-actions">
        <button
          type="button"
          className="secondary-action"
          onClick={() => exportRowsToCsv(exportFilename, columns, rows)}
          disabled={!rows.length}
        >
          Export CSV
        </button>
      </div>
    </div>
  );
}

export function SelectionStrip({ selectedRow, label, description, actions }) {
  return (
    <section className="logistics-selection-strip">
      <div className="logistics-selection-copy">
        <strong>{label}</strong>
        <span>{description}</span>
      </div>
      {actions ? <div className="logistics-selection-actions">{actions}</div> : null}
    </section>
  );
}

export function FkMappingCard({ title = "Correspondances FK", mappings = [] }) {
  if (!Array.isArray(mappings) || mappings.length === 0) {
    return null;
  }

  return (
    <SectionCard title={title} subtitle="Sources de reference utilisees pour les listes et les libelles FK.">
      <div className="logistics-fk-grid">
        {mappings.map((mapping) => (
          <article key={mapping.field} className="logistics-fk-item">
            <strong>{mapping.field}</strong>
            <p>{mapping.label}</p>
            {mapping.source ? <small>{mapping.source}</small> : null}
          </article>
        ))}
      </div>
    </SectionCard>
  );
}

export function SimpleTable({
  columns,
  rows,
  rowClassName,
  emptyMessage,
  selectedRowId = null,
  onRowSelect,
  getRowId = resolveTableRowId,
}) {
  if (!Array.isArray(rows) || rows.length === 0) {
    return <section className="table-empty-state">{emptyMessage || "Aucune donnee disponible."}</section>;
  }

  return (
    <div className="public-table-wrap logistics-table-wrap">
      <table className="public-table logistics-table">
        <thead>
          <tr>
            {columns.map((column) => (
              <th key={column.key}>{column.label}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr
              key={getRowId(row, index)}
              className={`${rowClassName ? rowClassName(row) : ""} ${
                selectedRowId != null && String(selectedRowId) === String(getRowId(row, index)) ? "logistics-row-selected" : ""
              } ${onRowSelect ? "logistics-row-clickable" : ""}`.trim()}
              onClick={onRowSelect ? () => onRowSelect(row) : undefined}
            >
              {columns.map((column) => (
                <td key={`${index}-${column.key}`}>{column.render ? column.render(row, index) : row[column.key] ?? "-"}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function ToneBadge({ children, tone = "info" }) {
  return <span className={`logistics-badge is-${tone}`}>{children}</span>;
}

export function SelectField({ label, value, onChange, options, allowEmpty = true, emptyLabel = "Choisir" }) {
  return (
    <label className="admin-form-field">
      <span>{label}</span>
      <select value={value} onChange={onChange}>
        {allowEmpty ? <option value="">{emptyLabel}</option> : null}
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}

export function buildReferenceOptions(items, fallbackPrefix = "Option") {
  return Array.isArray(items)
    ? items.map((item) => ({
        value: String(item.id ?? item.code ?? ""),
        label:
          item.label ||
          [item.code, item.abbr, item.id != null ? `${fallbackPrefix} #${item.id}` : ""].filter(Boolean).join(" - "),
      }))
    : [];
}

export function buildReferenceLabelMap(items) {
  const map = new Map();

  items.forEach((item) => {
    map.set(String(item.value), item.label);
  });

  return map;
}

export function normalizeSearch(value) {
  return String(value || "").trim();
}
