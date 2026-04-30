import { useEffect, useMemo, useRef, useState } from "react";

const numberFormatter = new Intl.NumberFormat("fr-FR");
const currencyFormatter = new Intl.NumberFormat("fr-FR", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 2,
});

const DEFAULT_ROWS_PER_PAGE = 25;
const MIN_COLUMN_WIDTH = 120;
const SELECTION_COLUMN_WIDTH = 64;

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

function normalizeSearchText(value) {
  return String(value || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function compareSortableValues(leftValue, rightValue) {
  if (leftValue == null && rightValue == null) {
    return 0;
  }

  if (leftValue == null) {
    return 1;
  }

  if (rightValue == null) {
    return -1;
  }

  const leftNumber = Number(leftValue);
  const rightNumber = Number(rightValue);
  const leftIsNumber = String(leftValue).trim() !== "" && Number.isFinite(leftNumber);
  const rightIsNumber = String(rightValue).trim() !== "" && Number.isFinite(rightNumber);

  if (leftIsNumber && rightIsNumber) {
    return leftNumber - rightNumber;
  }

  const leftDate = Date.parse(leftValue);
  const rightDate = Date.parse(rightValue);
  const leftIsDate = Number.isFinite(leftDate);
  const rightIsDate = Number.isFinite(rightDate);

  if (leftIsDate && rightIsDate) {
    return leftDate - rightDate;
  }

  return normalizeSearchText(leftValue).localeCompare(normalizeSearchText(rightValue), "fr");
}

function getColumnExportValue(column, row, index) {
  if (typeof column.exportValue === "function") {
    return column.exportValue(row, index);
  }

  if (typeof column.renderText === "function") {
    return column.renderText(row, index);
  }

  if (typeof column.sortValue === "function") {
    return column.sortValue(row, index);
  }

  return row[column.key] ?? "";
}

function getColumnSortValue(column, row, index) {
  if (typeof column.sortValue === "function") {
    return column.sortValue(row, index);
  }

  if (column.key in row) {
    return row[column.key];
  }

  return getColumnExportValue(column, row, index);
}

function getColumnTextValue(column, row, index) {
  const value = getColumnExportValue(column, row, index);

  if (value == null) {
    return "";
  }

  if (typeof value === "object") {
    return "";
  }

  return String(value);
}

function getColumnDefaultWidth(column) {
  return Math.max(MIN_COLUMN_WIDTH, Number(column.width || 0) || MIN_COLUMN_WIDTH);
}

export function exportRowsToCsv(filename, columns, rows) {
  const csvLines = [
    columns.map((column) => escapeCsvValue(column.label)).join(";"),
    ...rows.map((row, index) =>
      columns
        .map((column) => escapeCsvValue(getColumnExportValue(column, row, index)))
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

export function exportRowsToExcel(filename, columns, rows) {
  const headerHtml = columns.map((column) => `<th>${column.label}</th>`).join("");
  const rowsHtml = rows
    .map(
      (row, index) =>
        `<tr>${columns
          .map((column) =>
            `<td>${String(getColumnExportValue(column, row, index)).replace(/</g, "&lt;").replace(/>/g, "&gt;")}</td>`
          )
          .join("")}</tr>`
    )
    .join("");

  const html = `
    <html>
      <head><meta charset="utf-8" /></head>
      <body>
        <table border="1">
          <thead><tr>${headerHtml}</tr></thead>
          <tbody>${rowsHtml}</tbody>
        </table>
      </body>
    </html>
  `;

  const blob = new Blob([html], { type: "application/vnd.ms-excel;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename.replace(/\.csv$/i, ".xls");
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

export function exportRowsToPdf(filename, columns, rows) {
  const headerHtml = columns.map((column) => `<th>${column.label}</th>`).join("");
  const rowsHtml = rows
    .map(
      (row, index) =>
        `<tr>${columns
          .map((column) =>
            `<td>${String(getColumnExportValue(column, row, index)).replace(/</g, "&lt;").replace(/>/g, "&gt;")}</td>`
          )
          .join("")}</tr>`
    )
    .join("");

  const printWindow = window.open("", "_blank", "noopener,noreferrer,width=1200,height=800");

  if (!printWindow) {
    return;
  }

  printWindow.document.write(`
    <html>
      <head>
        <meta charset="utf-8" />
        <title>${filename}</title>
        <style>
          body { font-family: Arial, sans-serif; padding: 24px; }
          table { width: 100%; border-collapse: collapse; }
          th, td { border: 1px solid #cfd7e4; padding: 8px; text-align: left; vertical-align: top; }
          th { background: #eef4ff; }
        </style>
      </head>
      <body>
        <h1>${filename}</h1>
        <table>
          <thead><tr>${headerHtml}</tr></thead>
          <tbody>${rowsHtml}</tbody>
        </table>
      </body>
    </html>
  `);
  printWindow.document.close();
  printWindow.focus();
  printWindow.print();
}

export function TableToolbar({ title = "Tableau", rows = [] }) {
  return (
    <div className="logistics-table-toolbar">
      <div className="logistics-table-toolbar-copy">
        <strong>{title}</strong>
        <span>{`${rows.length} ligne${rows.length > 1 ? "s" : ""} visible${rows.length > 1 ? "s" : ""}`}</span>
      </div>
    </div>
  );
}

export function SelectionStrip({
  selectedRow,
  label,
  description,
  actions,
  actionLabel = "Actions de la ligne selectionnee",
  actionDescription = "Selectionnez une seule ligne pour voir ses actions metier.",
}) {
  const hasSelection = Boolean(selectedRow);

  return (
    <div className={`logistics-selection-grid ${hasSelection ? "is-active" : "is-idle"}`}>
      <section className={`logistics-selection-strip ${hasSelection ? "" : "is-idle"}`.trim()}>
        <div className="logistics-selection-copy">
          <strong>{label}</strong>
          <span>{description}</span>
        </div>
      </section>
      {hasSelection && actions ? (
        <section className="logistics-selection-strip logistics-selection-strip-actions">
          <div className="logistics-selection-copy">
            <strong>{actionLabel}</strong>
            <span>{actionDescription}</span>
          </div>
          <div className="logistics-selection-actions">{actions}</div>
        </section>
      ) : null}
    </div>
  );
}

export function FkMappingCard({ title = "Correspondances FK", mappings = [] }) {
  const [isOpen, setIsOpen] = useState(false);

  if (!Array.isArray(mappings) || mappings.length === 0) {
    return null;
  }

  return (
    <SectionCard
      title={title}
      subtitle="Sources de reference utilisees pour les listes et les libelles FK."
      actions={
        <button type="button" className="secondary-action" onClick={() => setIsOpen((current) => !current)}>
          {isOpen ? "Masquer correspondances FK" : "Correspondances FK"}
        </button>
      }
    >
      {isOpen ? (
        <div className="logistics-fk-grid">
          {mappings.map((mapping) => (
            <article key={mapping.field} className="logistics-fk-item">
              <strong>{mapping.field}</strong>
              <p>{mapping.label}</p>
              {mapping.source ? <small>{mapping.source}</small> : null}
            </article>
          ))}
        </div>
      ) : (
        <section className="table-empty-state logistics-collapsed-state">
          Ouvrez le panneau pour afficher les correspondances FK et les sources de reference.
        </section>
      )}
    </SectionCard>
  );
}

export function SimpleTable({
  columns,
  rows,
  rowClassName,
  emptyMessage,
  exportFilename = "logistique-tableau",
  selectedRowId = null,
  onRowSelect,
  getRowId = resolveTableRowId,
  enableSelection = Boolean(onRowSelect),
  defaultPinnedColumns = [],
  defaultSortColumn = "",
  defaultRowsPerPage = DEFAULT_ROWS_PER_PAGE,
  rowsPerPageOptions = [10, 25, 50, 100],
  showControls = true,
}) {
  const tableWrapRef = useRef(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [sortConfig, setSortConfig] = useState({
    column: defaultSortColumn,
    direction: defaultSortColumn ? "asc" : "",
  });
  const [currentPage, setCurrentPage] = useState(1);
  const [rowsPerPage, setRowsPerPage] = useState(defaultRowsPerPage);
  const [controlsOpen, setControlsOpen] = useState(false);
  const [selectedRowIds, setSelectedRowIds] = useState([]);
  const [pinnedColumns, setPinnedColumns] = useState(defaultPinnedColumns);
  const [visibleColumns, setVisibleColumns] = useState(() => columns.map((column) => column.key));
  const [columnWidths, setColumnWidths] = useState(() =>
    Object.fromEntries(columns.map((column) => [column.key, getColumnDefaultWidth(column)]))
  );
  const [scrollState, setScrollState] = useState({
    overflow: false,
    canScrollLeft: false,
    canScrollRight: false,
  });
  const navigationMenuRef = useRef(null);
  const [showNavigationMenu, setShowNavigationMenu] = useState(false);
  const exportMenuRef = useRef(null);
  const [showExportMenu, setShowExportMenu] = useState(false);

  useEffect(() => {
    const availableColumnKeys = columns.map((column) => column.key);

    setVisibleColumns((current) => {
      const retained = current.filter((columnKey) => availableColumnKeys.includes(columnKey));
      const appended = availableColumnKeys.filter((columnKey) => !retained.includes(columnKey));
      return [...retained, ...appended];
    });

    setPinnedColumns((current) => {
      const validPinnedColumns = current.filter((columnKey) => availableColumnKeys.includes(columnKey));

      if (validPinnedColumns.length > 0) {
        return validPinnedColumns;
      }

      return defaultPinnedColumns.filter((columnKey) => availableColumnKeys.includes(columnKey));
    });

    setColumnWidths((current) => {
      const nextWidths = { ...current };

      columns.forEach((column) => {
        if (!nextWidths[column.key]) {
          nextWidths[column.key] = getColumnDefaultWidth(column);
        }
      });

      Object.keys(nextWidths).forEach((columnKey) => {
        if (!availableColumnKeys.includes(columnKey)) {
          delete nextWidths[columnKey];
        }
      });

      return nextWidths;
    });
  }, [columns, defaultPinnedColumns]);

  useEffect(() => {
    setSelectedRowIds((current) => {
      const availableIds = new Set(rows.map((row, index) => String(getRowId(row, index))));
      return current.filter((rowId) => availableIds.has(String(rowId)));
    });
  }, [getRowId, rows]);

  const effectiveVisibleColumns = useMemo(
    () => columns.filter((column) => visibleColumns.includes(column.key)),
    [columns, visibleColumns]
  );

  const searchableColumns = useMemo(
    () => effectiveVisibleColumns.filter((column) => column.searchable !== false && column.key !== "actions"),
    [effectiveVisibleColumns]
  );

  const filteredRows = useMemo(() => {
    if (!searchTerm.trim()) {
      return rows;
    }

    const normalizedSearch = normalizeSearchText(searchTerm);

    return rows.filter((row, index) =>
      searchableColumns.some((column) => normalizeSearchText(getColumnTextValue(column, row, index)).includes(normalizedSearch))
    );
  }, [rows, searchTerm, searchableColumns]);

  const sortedRows = useMemo(() => {
    if (!sortConfig.column || !sortConfig.direction) {
      return filteredRows;
    }

    const targetColumn = columns.find((column) => column.key === sortConfig.column);

    if (!targetColumn) {
      return filteredRows;
    }

    const sorted = [...filteredRows].sort((leftRow, rightRow) => {
      const leftValue = getColumnSortValue(targetColumn, leftRow, 0);
      const rightValue = getColumnSortValue(targetColumn, rightRow, 0);
      return compareSortableValues(leftValue, rightValue);
    });

    return sortConfig.direction === "desc" ? sorted.reverse() : sorted;
  }, [columns, filteredRows, sortConfig]);

  const totalPages = Math.max(1, Math.ceil(sortedRows.length / rowsPerPage));

  useEffect(() => {
    setCurrentPage((current) => Math.min(current, totalPages));
  }, [totalPages]);

  const paginatedRowEntries = useMemo(() => {
    const startIndex = (currentPage - 1) * rowsPerPage;
    return sortedRows.slice(startIndex, startIndex + rowsPerPage).map((row, index) => ({
      row,
      index: startIndex + index,
    }));
  }, [currentPage, rowsPerPage, sortedRows]);

  const selectedPageIds = useMemo(
    () => paginatedRowEntries.map((entry) => String(getRowId(entry.row, entry.index))).filter(Boolean),
    [getRowId, paginatedRowEntries]
  );

  useEffect(() => {
    const wrapElement = tableWrapRef.current;

    if (!wrapElement) {
      return undefined;
    }

    const updateScrollState = () => {
      const maxScrollLeft = wrapElement.scrollWidth - wrapElement.clientWidth;
      setScrollState({
        overflow: wrapElement.scrollWidth > wrapElement.clientWidth + 2,
        canScrollLeft: wrapElement.scrollLeft > 8,
        canScrollRight: wrapElement.scrollLeft < maxScrollLeft - 8,
      });
    };

    updateScrollState();
    wrapElement.addEventListener("scroll", updateScrollState);
    window.addEventListener("resize", updateScrollState);

    return () => {
      wrapElement.removeEventListener("scroll", updateScrollState);
      window.removeEventListener("resize", updateScrollState);
    };
  }, [effectiveVisibleColumns, paginatedRowEntries.length, rowsPerPage]);

  useEffect(() => {
    function handleDocumentPointerDown(event) {
      if (!navigationMenuRef.current?.contains(event.target)) {
        setShowNavigationMenu(false);
      }

      if (!exportMenuRef.current?.contains(event.target)) {
        setShowExportMenu(false);
      }
    }

    document.addEventListener("mousedown", handleDocumentPointerDown);

    return () => {
      document.removeEventListener("mousedown", handleDocumentPointerDown);
    };
  }, []);

  function handleSortColumn(columnKey) {
    setSortConfig((current) => {
      if (current.column !== columnKey) {
        return { column: columnKey, direction: "asc" };
      }

      if (current.direction === "asc") {
        return { column: columnKey, direction: "desc" };
      }

      if (current.direction === "desc") {
        return { column: "", direction: "" };
      }

      return { column: columnKey, direction: "asc" };
    });
  }

  function handleToggleVisibleColumn(columnKey) {
    setVisibleColumns((current) => {
      if (current.includes(columnKey)) {
        return current.length === 1 ? current : current.filter((value) => value !== columnKey);
      }

      const next = [...current, columnKey];
      return columns.filter((column) => next.includes(column.key)).map((column) => column.key);
    });
  }

  function handleTogglePinnedColumn(columnKey) {
    setPinnedColumns((current) =>
      current.includes(columnKey) ? current.filter((value) => value !== columnKey) : [...current, columnKey]
    );
  }

  function handleToggleRowSelection(row, index) {
    const rowId = String(getRowId(row, index));

    setSelectedRowIds((current) =>
      current.includes(rowId) ? current.filter((value) => value !== rowId) : [...current, rowId]
    );
  }

  function handleTogglePageSelection() {
    setSelectedRowIds((current) => {
      const everyRowSelected =
        selectedPageIds.length > 0 && selectedPageIds.every((rowId) => current.includes(String(rowId)));

      if (everyRowSelected) {
        return current.filter((rowId) => !selectedPageIds.includes(String(rowId)));
      }

      return Array.from(new Set([...current, ...selectedPageIds]));
    });
  }

  function handleRowsPerPageChange(nextValue) {
    setRowsPerPage(nextValue);
    setCurrentPage(1);
  }

  function handleResizeStart(columnKey, event) {
    event.preventDefault();
    const startX = event.clientX;
    const initialWidth = columnWidths[columnKey] || getColumnDefaultWidth(columns.find((column) => column.key === columnKey) || {});

    const handleMouseMove = (moveEvent) => {
      const delta = moveEvent.clientX - startX;
      setColumnWidths((current) => ({
        ...current,
        [columnKey]: Math.max(MIN_COLUMN_WIDTH, initialWidth + delta),
      }));
    };

    const handleMouseUp = () => {
      window.removeEventListener("mousemove", handleMouseMove);
      window.removeEventListener("mouseup", handleMouseUp);
    };

    window.addEventListener("mousemove", handleMouseMove);
    window.addEventListener("mouseup", handleMouseUp);
  }

  function handleResetColumnWidth(columnKey) {
    const column = columns.find((item) => item.key === columnKey);

    setColumnWidths((current) => ({
      ...current,
      [columnKey]: getColumnDefaultWidth(column || {}),
    }));
  }

  function handleTableScroll(direction) {
    const wrapElement = tableWrapRef.current;

    if (!wrapElement) {
      return;
    }

    const scrollStep = Math.max(240, Math.round(wrapElement.clientWidth * 0.6));

    if (direction === "start") {
      wrapElement.scrollTo({ left: 0, behavior: "smooth" });
      return;
    }

    if (direction === "end") {
      wrapElement.scrollTo({ left: wrapElement.scrollWidth, behavior: "smooth" });
      return;
    }

    wrapElement.scrollBy({
      left: direction === "left" ? -scrollStep : scrollStep,
      behavior: "smooth",
    });
  }

  function getColumnWidth(columnKey) {
    return columnWidths[columnKey] || getColumnDefaultWidth(columns.find((column) => column.key === columnKey) || {});
  }

  function getPinnedOffset(columnKey) {
    let offset = enableSelection ? SELECTION_COLUMN_WIDTH : 0;

    for (const column of effectiveVisibleColumns) {
      if (!pinnedColumns.includes(column.key)) {
        continue;
      }

      if (column.key === columnKey) {
        break;
      }

      offset += getColumnWidth(column.key);
    }

    return offset;
  }

  function getCellStyle(column) {
    const width = getColumnWidth(column.key);
    const isPinned = pinnedColumns.includes(column.key);

    return {
      width,
      minWidth: width,
      maxWidth: Math.max(width, MIN_COLUMN_WIDTH),
      ...(isPinned
        ? {
            left: getPinnedOffset(column.key),
          }
        : {}),
    };
  }

  if (!Array.isArray(rows) || rows.length === 0) {
    return <section className="table-empty-state">{emptyMessage || "Aucune donnee disponible."}</section>;
  }

  const exportableColumns = effectiveVisibleColumns.filter((column) => column.key !== "actions");
  const exportBaseFilename = String(exportFilename || "logistique-tableau").replace(/\.(csv|xls|xlsx|pdf)$/i, "");
  const exportRows =
    selectedRowIds.length > 0
      ? sortedRows.filter((row, index) => selectedRowIds.includes(String(getRowId(row, index))))
      : sortedRows;

  return (
    <div className="logistics-advanced-table">
      {showControls ? (
        <section className="admin-search-card logistics-table-controls logistics-table-toolbar-card">
          <div className="logistics-table-control-row">
            <label className="admin-form-field logistics-table-search-field">
              <span>Recherche rapide</span>
              <input
                type="search"
                value={searchTerm}
                onChange={(event) => {
                  setSearchTerm(event.target.value);
                  setCurrentPage(1);
                }}
                placeholder="Filtrer toutes les colonnes visibles"
              />
            </label>

            <div className="admin-toolbar-actions">
              <label className="admin-form-field logistics-inline-select">
                <span>Lignes</span>
                <select value={rowsPerPage} onChange={(event) => handleRowsPerPageChange(Number(event.target.value))}>
                  {rowsPerPageOptions.map((value) => (
                    <option key={value} value={value}>
                      {value}
                    </option>
                  ))}
                </select>
              </label>

              <button
                type="button"
                className="secondary-action"
                onClick={() => setControlsOpen((current) => !current)}
              >
                {controlsOpen ? "Masquer colonnes" : "Colonnes"}
              </button>

              <div ref={exportMenuRef} className="admin-scroll-menu" aria-label="Options d'export logistique">
                <button
                  type="button"
                  className={`secondary-action admin-scroll-trigger ${showExportMenu ? "is-active" : ""}`}
                  onClick={() => {
                    setShowNavigationMenu(false);
                    setShowExportMenu((current) => !current);
                  }}
                  disabled={!exportRows.length}
                  aria-expanded={showExportMenu}
                  aria-haspopup="true"
                >
                  Exporter
                </button>
                {showExportMenu ? (
                  <div className="admin-scroll-menu-panel">
                    <button
                      type="button"
                      className="secondary-action"
                      onClick={() => {
                        exportRowsToCsv(`${exportBaseFilename}.csv`, exportableColumns, exportRows);
                        setShowExportMenu(false);
                      }}
                      disabled={!exportRows.length}
                    >
                      Export CSV
                    </button>
                    <button
                      type="button"
                      className="secondary-action"
                      onClick={() => {
                        exportRowsToExcel(`${exportBaseFilename}.csv`, exportableColumns, exportRows);
                        setShowExportMenu(false);
                      }}
                      disabled={!exportRows.length}
                    >
                      Export Excel
                    </button>
                    <button
                      type="button"
                      className="secondary-action"
                      onClick={() => {
                        exportRowsToPdf(exportBaseFilename, exportableColumns, exportRows);
                        setShowExportMenu(false);
                      }}
                      disabled={!exportRows.length}
                    >
                      Export PDF
                    </button>
                  </div>
                ) : null}
              </div>

              <div ref={navigationMenuRef} className="admin-scroll-menu" aria-label="Controles de defilement horizontal">
                <button
                  type="button"
                  className={`secondary-action admin-scroll-trigger ${showNavigationMenu ? "is-active" : ""}`}
                  onClick={() => {
                    setShowExportMenu(false);
                    setShowNavigationMenu((current) => !current);
                  }}
                  disabled={!scrollState.overflow}
                  aria-expanded={showNavigationMenu}
                  aria-haspopup="true"
                >
                  Navigation
                </button>
                {showNavigationMenu ? (
                  <div className="admin-scroll-menu-panel">
                    <button
                      type="button"
                      className="secondary-action"
                      onClick={() => {
                        handleTableScroll("start");
                        setShowNavigationMenu(false);
                      }}
                      disabled={!scrollState.canScrollLeft}
                    >
                      Debut
                    </button>
                    <button
                      type="button"
                      className="secondary-action"
                      onClick={() => {
                        handleTableScroll("left");
                        setShowNavigationMenu(false);
                      }}
                      disabled={!scrollState.canScrollLeft}
                    >
                      Gauche
                    </button>
                    <button
                      type="button"
                      className="secondary-action"
                      onClick={() => {
                        handleTableScroll("right");
                        setShowNavigationMenu(false);
                      }}
                      disabled={!scrollState.canScrollRight}
                    >
                      Droite
                    </button>
                    <button
                      type="button"
                      className="secondary-action"
                      onClick={() => {
                        handleTableScroll("end");
                        setShowNavigationMenu(false);
                      }}
                      disabled={!scrollState.canScrollRight}
                    >
                      Fin
                    </button>
                  </div>
                ) : null}
              </div>
            </div>
          </div>

          <div className="logistics-table-meta-row">
            <div className="logistics-table-pills">
              <span className="status-pill is-muted">{`${sortedRows.length}/${rows.length} lignes`}</span>
              <span className="status-pill is-muted">{`${effectiveVisibleColumns.length} colonnes visibles`}</span>
              <span className="status-pill is-muted">{`${pinnedColumns.length} colonnes gelees`}</span>
              {enableSelection ? (
                <span className="status-pill is-muted">{`${selectedRowIds.length} selectionnees`}</span>
              ) : null}
              {scrollState.overflow ? <span className="status-pill is-muted">Defilement horizontal actif</span> : null}
            </div>
            {controlsOpen ? (
              <span className="logistics-table-meta-hint">
                Cochez, gelez ou reinitialisez les colonnes sans surcharger la zone de lecture.
              </span>
            ) : null}
          </div>

          {controlsOpen ? (
            <div className="admin-search-grid">
              <div className="admin-visibility-card admin-form-field-wide logistics-visibility-card">
                <div className="admin-visibility-head">
                  <span>Colonnes visibles, gelees et largeur</span>
                  <div className="admin-visibility-actions">
                    <button
                      type="button"
                      className="secondary-action"
                      onClick={() => setVisibleColumns(columns.map((column) => column.key))}
                    >
                      Tout afficher
                    </button>
                    <button
                      type="button"
                      className="secondary-action"
                      onClick={() =>
                        setColumnWidths(Object.fromEntries(columns.map((column) => [column.key, getColumnDefaultWidth(column)])))
                      }
                    >
                      Largeurs auto
                    </button>
                  </div>
                </div>

                <div className="admin-visibility-grid">
                  {columns.map((column) => {
                    const isPinned = pinnedColumns.includes(column.key);

                    return (
                      <div key={`visible-${column.key}`} className="admin-column-option">
                        <label className="admin-multiselect-option">
                          <input
                            type="checkbox"
                            checked={visibleColumns.includes(column.key)}
                            onChange={() => handleToggleVisibleColumn(column.key)}
                          />
                          <span>{column.label}</span>
                        </label>
                        <div className="admin-column-option-actions">
                          <button
                            type="button"
                            className={`secondary-action ${isPinned ? "is-active" : ""}`}
                            onClick={() => handleTogglePinnedColumn(column.key)}
                          >
                            {isPinned ? "Degeler" : "Geler"}
                          </button>
                          <button
                            type="button"
                            className="secondary-action"
                            onClick={() => handleResetColumnWidth(column.key)}
                          >
                            Largeur auto
                          </button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          ) : null}
        </section>
      ) : null}

      <div
        ref={tableWrapRef}
        className="public-table-wrap logistics-table-wrap admin-table-wrap"
        tabIndex={0}
        aria-label="Tableau logistique avance avec defilement horizontal et vertical"
      >
        <table className="public-table logistics-table admin-table">
          <colgroup>
            {enableSelection ? <col style={{ width: SELECTION_COLUMN_WIDTH }} /> : null}
            {effectiveVisibleColumns.map((column) => (
              <col key={`col-${column.key}`} style={{ width: getColumnWidth(column.key) }} />
            ))}
          </colgroup>
          <thead>
            <tr>
              {enableSelection ? (
                <th className="admin-select-column">
                  <input
                    type="checkbox"
                    checked={selectedPageIds.length > 0 && selectedPageIds.every((rowId) => selectedRowIds.includes(String(rowId)))}
                    onChange={handleTogglePageSelection}
                    aria-label="Selectionner la page"
                  />
                </th>
              ) : null}

              {effectiveVisibleColumns.map((column) => {
                const isPinned = pinnedColumns.includes(column.key);
                const isSortable = column.sortable !== false && column.key !== "actions";

                return (
                  <th
                    key={column.key}
                    className={`admin-table-head-cell ${isPinned ? "is-pinned" : ""}`}
                    style={getCellStyle(column)}
                  >
                    <div className="admin-header-cell">
                      <div className="admin-header-content">
                        <button
                          type="button"
                          className={`admin-header-trigger ${isSortable ? "is-sortable" : ""} ${
                            sortConfig.column === column.key ? "is-active" : ""
                          } ${isPinned ? "is-pinned" : ""}`.trim()}
                          onClick={isSortable ? () => handleSortColumn(column.key) : undefined}
                          disabled={!isSortable}
                          title={isSortable ? `Trier par ${column.label}` : column.label}
                        >
                          <div className="admin-header-label" title={column.label}>
                            {column.label}
                          </div>
                          {isSortable ? (
                            <small className="admin-header-indicator" aria-hidden="true">
                              {sortConfig.column === column.key
                                ? sortConfig.direction === "asc"
                                  ? "^"
                                  : sortConfig.direction === "desc"
                                    ? "v"
                                    : "<>"
                                : "<>"}
                            </small>
                          ) : null}
                        </button>
                      </div>

                      <div
                        className="admin-resize-handle"
                        onMouseDown={(event) => handleResizeStart(column.key, event)}
                        role="separator"
                        aria-orientation="vertical"
                        aria-label={`Redimensionner la colonne ${column.label}`}
                      />
                    </div>
                  </th>
                );
              })}
            </tr>
          </thead>

          <tbody>
            {paginatedRowEntries.map((entry) => {
              const row = entry.row;
              const rowIndex = entry.index;
              const rowId = String(getRowId(row, rowIndex));
              const isFocused = selectedRowId != null && String(selectedRowId) === rowId;
              const isChecked = selectedRowIds.includes(rowId);

              return (
                <tr
                  key={rowId}
                  className={`${rowClassName ? rowClassName(row) : ""} ${
                    isFocused ? "logistics-row-selected" : ""
                  } ${isChecked ? "admin-table-row is-selected" : "admin-table-row"} ${
                    onRowSelect ? "logistics-row-clickable" : ""
                  }`.trim()}
                  onClick={onRowSelect ? () => onRowSelect(row) : undefined}
                >
                  {enableSelection ? (
                    <td className="admin-select-column" onClick={(event) => event.stopPropagation()}>
                      <input
                        type="checkbox"
                        checked={isChecked}
                        onChange={() => handleToggleRowSelection(row, rowIndex)}
                        aria-label="Selectionner la ligne"
                      />
                    </td>
                  ) : null}

                  {effectiveVisibleColumns.map((column) => {
                    const isPinned = pinnedColumns.includes(column.key);

                    return (
                      <td
                        key={`${rowId}-${column.key}`}
                        className={`${isPinned ? "admin-table-cell is-pinned" : "admin-table-cell"} ${
                          column.key === "actions" ? "admin-actions-cell" : ""
                        }`.trim()}
                        style={getCellStyle(column)}
                      >
                        {column.render ? column.render(row, rowIndex) : row[column.key] ?? "-"}
                      </td>
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {filteredRows.length === 0 ? (
        <section className="table-empty-state">Aucun resultat ne correspond a la recherche dans ce tableau.</section>
      ) : (
        <section className="admin-table-footer logistics-table-footer">
          <div className="admin-table-footer-meta">
            <span>{`Page ${currentPage} sur ${totalPages}`}</span>
            <span>{`${paginatedRowEntries.length} lignes affichees sur ${sortedRows.length}`}</span>
          </div>

          <div className="admin-table-footer-actions">
            <div className="admin-pagination">
              <button type="button" className="secondary-action" onClick={() => setCurrentPage(1)} disabled={currentPage === 1}>
                1ere
              </button>
              <button
                type="button"
                className="secondary-action"
                onClick={() => setCurrentPage((current) => Math.max(1, current - 1))}
                disabled={currentPage === 1}
              >
                Prec
              </button>
              <button
                type="button"
                className="secondary-action"
                onClick={() => setCurrentPage((current) => Math.min(totalPages, current + 1))}
                disabled={currentPage === totalPages}
              >
                Suiv
              </button>
              <button
                type="button"
                className="secondary-action"
                onClick={() => setCurrentPage(totalPages)}
                disabled={currentPage === totalPages}
              >
                Dern
              </button>
            </div>
          </div>
        </section>
      )}
    </div>
  );
}

export function ToneBadge({ children, tone = "info" }) {
  return <span className={`logistics-badge is-${tone}`}>{children}</span>;
}

export function SelectField({
  label,
  value,
  onChange,
  options,
  allowEmpty = true,
  emptyLabel = "Choisir",
  disabled = false,
  required = false,
  helperText = "",
  searchable = true,
  searchPlaceholder = "Rechercher une valeur",
}) {
  const containerRef = useRef(null);
  const searchInputRef = useRef(null);
  const optionRefs = useRef([]);
  const [isOpen, setIsOpen] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");
  const [highlightedIndex, setHighlightedIndex] = useState(-1);
  const normalizedSearch = normalizeSearchText(searchTerm).trim();
  const hasManyOptions = Array.isArray(options) && options.length > 6;
  const selectedOption = useMemo(
    () => (Array.isArray(options) ? options.find((option) => String(option.value) === String(value ?? "")) || null : null),
    [options, value]
  );
  const filteredOptions = useMemo(() => {
    if (!Array.isArray(options)) {
      return [];
    }

    if (!normalizedSearch) {
      return options;
    }

    const nextOptions = options.filter((option) =>
      normalizeSearchText(option.label).includes(normalizedSearch)
    );

    if (
      selectedOption &&
      !nextOptions.some((option) => String(option.value) === String(selectedOption.value))
    ) {
      return [selectedOption, ...nextOptions];
    }

    return nextOptions;
  }, [normalizedSearch, options, selectedOption]);
  const visibleOptions = useMemo(() => {
    const nextOptions = filteredOptions.map((option) => ({
      value: option.value,
      label: option.label,
    }));

    if (allowEmpty) {
      return [{ value: "", label: emptyLabel }, ...nextOptions];
    }

    return nextOptions;
  }, [allowEmpty, emptyLabel, filteredOptions]);

  useEffect(() => {
    if (disabled) {
      setSearchTerm("");
      setIsOpen(false);
      setHighlightedIndex(-1);
    }
  }, [disabled]);

  useEffect(() => {
    if (!isOpen || !searchable || !hasManyOptions) {
      return;
    }

    searchInputRef.current?.focus();
  }, [hasManyOptions, isOpen, searchable]);

  useEffect(() => {
    if (!isOpen) {
      setHighlightedIndex(-1);
      return;
    }

    const selectedIndex = visibleOptions.findIndex((option) => String(option.value) === String(value ?? ""));
    setHighlightedIndex(selectedIndex >= 0 ? selectedIndex : visibleOptions.length > 0 ? 0 : -1);
  }, [isOpen, value, visibleOptions]);

  useEffect(() => {
    if (!isOpen || highlightedIndex < 0) {
      return;
    }

    optionRefs.current[highlightedIndex]?.scrollIntoView({
      block: "nearest",
    });
  }, [highlightedIndex, isOpen]);

  useEffect(() => {
    function handlePointerDown(event) {
      if (!containerRef.current?.contains(event.target)) {
        setIsOpen(false);
      }
    }

    document.addEventListener("mousedown", handlePointerDown);

    return () => {
      document.removeEventListener("mousedown", handlePointerDown);
    };
  }, []);

  const currentLabel = selectedOption?.label || (allowEmpty ? emptyLabel : "Selectionner");

  function emitValue(nextValue) {
    onChange?.({
      target: {
        value: nextValue,
      },
    });
  }

  function handleSelectOption(nextValue) {
    emitValue(nextValue);
    setIsOpen(false);
    setSearchTerm("");
  }

  function moveHighlight(direction) {
    if (visibleOptions.length === 0) {
      return;
    }

    setHighlightedIndex((current) => {
      if (current < 0) {
        return 0;
      }

      if (direction === "down") {
        return current >= visibleOptions.length - 1 ? 0 : current + 1;
      }

      return current <= 0 ? visibleOptions.length - 1 : current - 1;
    });
  }

  function handleComboboxKeyDown(event) {
    if (disabled) {
      return;
    }

    if (!isOpen && (event.key === "ArrowDown" || event.key === "ArrowUp" || event.key === "Enter")) {
      event.preventDefault();
      setIsOpen(true);
      return;
    }

    if (event.key === "Escape") {
      event.preventDefault();
      setIsOpen(false);
      setSearchTerm("");
      return;
    }

    if (!isOpen) {
      return;
    }

    if (event.key === "ArrowDown") {
      event.preventDefault();
      moveHighlight("down");
      return;
    }

    if (event.key === "ArrowUp") {
      event.preventDefault();
      moveHighlight("up");
      return;
    }

    if (event.key === "Enter") {
      event.preventDefault();

      if (highlightedIndex >= 0 && visibleOptions[highlightedIndex]) {
        handleSelectOption(visibleOptions[highlightedIndex].value);
      }
    }
  }

  if (searchable && !disabled) {
    return (
      <div className="admin-form-field">
        <span>{label}</span>
        <div ref={containerRef} className="admin-multiselect admin-single-select">
          <button
            type="button"
            className={`admin-multiselect-trigger ${isOpen ? "is-open" : ""}`}
            onClick={() => setIsOpen((current) => !current)}
            onKeyDown={handleComboboxKeyDown}
            aria-expanded={isOpen}
            aria-haspopup="listbox"
          >
            <strong>{currentLabel || emptyLabel}</strong>
            <small>{isOpen ? "Fermer" : "Choisir"}</small>
          </button>

          {isOpen ? (
            <div className="admin-multiselect-panel" role="listbox" aria-label={label}>
              {hasManyOptions ? (
                <input
                  ref={searchInputRef}
                  className="admin-multiselect-search"
                  type="search"
                  value={searchTerm}
                  onChange={(event) => setSearchTerm(event.target.value)}
                  onKeyDown={handleComboboxKeyDown}
                  placeholder={searchPlaceholder}
                />
              ) : null}

              <div className="admin-multiselect-options admin-single-select-options">
                {filteredOptions.length > 0 ? (
                  visibleOptions.map((option, index) => (
                    <button
                      key={option.value}
                      ref={(element) => {
                        optionRefs.current[index] = element;
                      }}
                      type="button"
                      className={`admin-multiselect-option admin-single-select-option ${
                        String(option.value) === String(value ?? "") ? "is-selected" : ""
                      } ${index === highlightedIndex ? "is-highlighted" : ""}`}
                      onMouseEnter={() => setHighlightedIndex(index)}
                      onKeyDown={handleComboboxKeyDown}
                      onClick={() => handleSelectOption(option.value)}
                    >
                      <span>{option.label}</span>
                    </button>
                  ))
                ) : allowEmpty ? (
                  <button
                    ref={(element) => {
                      optionRefs.current[0] = element;
                    }}
                    type="button"
                    className={`admin-multiselect-option admin-single-select-option ${
                      String(value ?? "") === "" ? "is-selected" : ""
                    } ${highlightedIndex === 0 ? "is-highlighted" : ""}`}
                    onMouseEnter={() => setHighlightedIndex(0)}
                    onKeyDown={handleComboboxKeyDown}
                    onClick={() => handleSelectOption("")}
                  >
                    <span>{emptyLabel}</span>
                  </button>
                ) : (
                  <div className="admin-multiselect-empty">Aucune valeur ne correspond a la recherche.</div>
                )}
              </div>
            </div>
          ) : null}
        </div>
        {normalizedSearch && isOpen ? <small>{`${filteredOptions.length} option(s) correspond(ent) a la recherche.`}</small> : null}
        {helperText ? <small>{helperText}</small> : null}
      </div>
    );
  }

  return (
    <label className="admin-form-field">
      <span>{label}</span>
      <select value={value} onChange={onChange} disabled={disabled} required={required}>
        {allowEmpty ? <option value="">{emptyLabel}</option> : null}
        {Array.isArray(options) ? options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        )) : null}
      </select>
      {helperText ? <small>{helperText}</small> : null}
    </label>
  );
}

export function buildReferenceOptions(items, fallbackPrefix = "Option") {
  if (!Array.isArray(items)) {
    return [];
  }

  const uniqueOptions = new Map();

  items.forEach((item) => {
    const rawValue = item?.id ?? item?.code ?? "";
    const value = String(rawValue);

    if (!value) {
      return;
    }

    const label =
      item.label ||
      [item.code, item.abbr, item.id != null ? `${fallbackPrefix} #${item.id}` : ""].filter(Boolean).join(" - ");

    if (!uniqueOptions.has(value)) {
      uniqueOptions.set(value, {
        value,
        label: String(label || `${fallbackPrefix} ${value}`),
      });
    }
  });

  return Array.from(uniqueOptions.values()).sort((leftOption, rightOption) =>
    leftOption.label.localeCompare(rightOption.label, "fr")
  );
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
