import { compareDecimal, withCurrencyColumn, formatConsumptionMoney } from "../../utils/money";
export { formatCurrency } from "../../utils/money";
import CategoricalSelect from "../../components/CategoricalSelect";
import TablePagination from "../../components/TablePagination";
import ColumnPicker from "../../components/ColumnPicker";
import TableSettings from "../../components/TableSettings";
import AppIcon from "../../components/AppIcon";
import ActionButton from "../../components/ActionButton";
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";

const DEFAULT_ROWS_PER_PAGE = 25;
const MIN_COLUMN_WIDTH = 120;
const MAX_COLUMN_WIDTH = 10000;
const SELECTION_COLUMN_WIDTH = 64;

export function formatNumber(value) {
  if (value == null || value === "") return "—";
  const text = String(value);
  if (/^-?\d+(\.\d+)?$/.test(text)) {
    const negative = text.startsWith("-");
    const parts = (negative ? text.slice(1) : text).split(".");
    const integer = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, "\u202f");
    const fraction = parts[1]?.replace(/0+$/, "");
    return (negative ? "−" : "") + integer + (fraction ? "," + fraction : "");
  }
  const numeric = Number(value);
  return Number.isFinite(numeric) ? new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 6 }).format(numeric) : "—";
}


export function formatDate(value, options = {}) {
  if (value == null || value === "") return "-";
  const withTime = options.withTime !== false;
  const formatInstant = parsed => new Intl.DateTimeFormat("fr-FR", {
    day:"2-digit", month:"2-digit", year:"numeric", timeZone:"Africa/Kinshasa",
    ...(withTime ? { hour:"2-digit", minute:"2-digit", hourCycle:"h23", ...(options.withSeconds ? {second:"2-digit"} : {}) } : {}),
  }).format(parsed);
  if (value instanceof Date || typeof value === "number") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? String(value) : formatInstant(parsed);
  }
  const text = String(value).trim();
  if (!text) return "-";
  const parts = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(\.\d+)?)?(Z|[+-]\d{2}(?::?\d{2})?)?)?$/i.exec(text);
  if (!parts) return text;
  const [,year,month,day,hour,minute,second,fraction,zone] = parts;
  const y=Number(year),m=Number(month),d=Number(day);
  const leap=y%4===0 && (y%100!==0 || y%400===0);
  const days=[31,leap?29:28,31,30,31,30,31,31,30,31,30,31];
  if (y<1 || m<1 || m>12 || d<1 || d>days[m-1]) return text;
  const date = day+"/"+month+"/"+year;
  if (hour === undefined) return date;
  if (Number(hour)>23 || Number(minute)>59 || Number(second || 0)>59) return text;
  // Un timestamp SQL sans fuseau conserve son heure civile, sans conversion du navigateur.
  if (!zone) return date+(withTime ? " "+hour+":"+minute+(options.withSeconds ? ":"+(second || "00") : "") : "");
  const offset = zone.toUpperCase()==="Z" ? "Z" : zone.length===3 ? zone+":00" : zone.length===5 ? zone.slice(0,3)+":"+zone.slice(3) : zone;
  if (offset!=="Z" && (Number(offset.slice(1,3))>23 || Number(offset.slice(4,6))>59)) return text;
  const milliseconds = fraction ? "."+fraction.slice(1,4).padEnd(3,"0") : "";
  const parsed = new Date(year+"-"+month+"-"+day+"T"+hour+":"+minute+":"+(second || "00")+milliseconds+offset);
  return Number.isNaN(parsed.getTime()) ? text : formatInstant(parsed);
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

  const exact = compareDecimal(leftValue, rightValue);
  if (exact !== null) return exact;
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

  if (column.key === "MontantsParDevise" || (column.key === "ValeurConsoMensuelle" && row.MontantsParDevise)) return formatConsumptionMoney(row);
  if (/^(PU|PV|Montant|TotalRegle|Reste|Valeur|Marge)/.test(column.key) && column.key in row) return row[column.key] ?? "";

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
  columns = withCurrencyColumn(columns, rows);
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
  columns = withCurrencyColumn(columns, rows);
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
  columns = withCurrencyColumn(columns, rows);
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

function sameTableSelectionValue(left,right) {
  if(Object.is(left,right))return true;
  if(left==null||right==null||typeof left!=="object"||typeof right!=="object")return false;
  if(Array.isArray(left)!==Array.isArray(right))return false;
  if(left instanceof Date||right instanceof Date)return left instanceof Date&&right instanceof Date&&left.getTime()===right.getTime();
  const keys=Object.keys(left);
  return keys.length===Object.keys(right).length&&keys.every(key=>Object.prototype.hasOwnProperty.call(right,key)&&sameTableSelectionValue(left[key],right[key]));
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
  defaultVisibleColumns = null,
  onSelectionChange,
  selectionResetKey = 0,
  defaultSortColumn = "",
  defaultRowsPerPage = DEFAULT_ROWS_PER_PAGE,
  rowsPerPageOptions = [10, 25, 50, 100],
  showControls = true,
  showSearch = true,
  serverMeta = null,
  serverState = {},
  onServerChange,
  onRowConsult,
  consultColumns = [],
  isCellConsultable = () => true,
  loading = false,
  toolbar = null,
  columnsPanelOpen,
  columnsAnchorRef,
  onColumnsPanelClose,
  onVisibleColumnsChange,
  filtersVisible = false,
  columnFilters = {},
  onColumnFilterChange,
  onApplyColumnFilters,
  tablePreferences = null,
}) {
  const tableWrapRef = useRef(null);
  const settledTableHeight = useRef(0);
  const selectPageRef = useRef(null);
  const localColumnsAnchor=useRef(null);
  const columnsTrigger=columnsAnchorRef || localColumnsAnchor;
  function closeColumns(returnFocus=false){
    if(columnsPanelOpen !== undefined) onColumnsPanelClose?.();
    else setControlsOpen(false);
    if(returnFocus) requestAnimationFrame(()=>columnsTrigger.current?.focus({preventScroll:true}));
  }
  const [searchTerm, setSearchTerm] = useState("");
  const [localSortConfig, setSortConfig] = useState({
    column: defaultSortColumn,
    direction: defaultSortColumn ? "asc" : "",
  });
  const [localPage, setLocalPage] = useState(1);
  const [localRowsPerPage, setRowsPerPage] = useState(defaultRowsPerPage);
  const serverMode = typeof onServerChange === "function";
  const rowsPerPage = serverMode ? Number(serverState.take || serverMeta?.take || defaultRowsPerPage) : localRowsPerPage;
  const currentPage = serverMode ? Math.floor(Number(serverState.skip || 0) / rowsPerPage) + 1 : localPage;
  const sortConfig = serverMode ? { column: serverState.sortBy || serverMeta?.sortBy || "", direction: serverState.sortDir || serverMeta?.sortDir || "" } : localSortConfig;
  function setCurrentPage(next) {
    const target = typeof next === "function" ? next(currentPage) : next;
    if (target === currentPage) return;
    if (serverMode) onServerChange({ skip: (target - 1) * rowsPerPage });
    else setLocalPage(target);
  }
  const [localControlsOpen, setControlsOpen] = useState(false);
  const controlsOpen = columnsPanelOpen ?? localControlsOpen;
  const columnKeys = columns.map((column) => column.key).join("|");
  const pinnedDefaultsKey = defaultPinnedColumns.join("|");
  const knownColumnKeys = useRef(columns.map((column) => column.key));
  const [selectedRowIds, setSelectedRowIds] = useState([]);
  const selectionCallback = useRef(onSelectionChange);
  const notifiedSelection = useRef(null);
  selectionCallback.current = onSelectionChange;
  useEffect(() => { setSelectedRowIds([]); },[selectionResetKey]);
  const selectionKey = selectedRowIds.join("|");
  useEffect(() => {
    if(!selectionCallback.current)return;
    const nextSelection=rows.filter((row,index)=>selectedRowIds.includes(String(getRowId(row,index))));
    if(notifiedSelection.current!==null&&sameTableSelectionValue(notifiedSelection.current,nextSelection))return;
    notifiedSelection.current=nextSelection;
    selectionCallback.current(nextSelection);
  },[selectionKey,rows,getRowId,onSelectionChange]);
  const [pinnedColumns, setPinnedColumns] = useState(defaultPinnedColumns);
  const [visibleColumns, setVisibleColumns] = useState(() => defaultVisibleColumns
    ? [...new Set(defaultVisibleColumns)].filter(key => columns.some(column => column.key === key))
    : columns.map(column => column.key));
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
    const previousColumnKeys = knownColumnKeys.current;

    setVisibleColumns((current) => {
      const retained = current.filter((columnKey) => availableColumnKeys.includes(columnKey));
      const appended = availableColumnKeys.filter((columnKey) => !previousColumnKeys.includes(columnKey) && (!defaultVisibleColumns || defaultVisibleColumns.includes(columnKey)));
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
    knownColumnKeys.current = availableColumnKeys;
  }, [columnKeys, pinnedDefaultsKey]);

  useEffect(() => {
    setSelectedRowIds((current) => {
      const availableIds = new Set(rows.map((row, index) => String(getRowId(row, index))));
      const retained=current.filter((rowId)=>availableIds.has(String(rowId)));
      return retained.length===current.length?current:retained;
    });
  }, [getRowId, rows]);

  const effectiveVisibleColumns = useMemo(
    () => tablePreferences?.ready
      ? tablePreferences.tableKeys.map(key => columns.find(column => column.key === key)).filter(Boolean)
      : visibleColumns.map(key => columns.find(column => column.key === key)).filter(Boolean),
    [columns, visibleColumns, tablePreferences?.ready, tablePreferences?.tableKeys.join("|")]
  );

  const visibleKeys = effectiveVisibleColumns.map((column) => column.key).join("|");
  useEffect(() => { onVisibleColumnsChange?.(effectiveVisibleColumns.map((column) => column.key)); }, [visibleKeys, onVisibleColumnsChange]);

  const searchableColumns = useMemo(
    () => effectiveVisibleColumns.filter((column) => column.searchable !== false && column.key !== "actions"),
    [effectiveVisibleColumns]
  );

  const filteredRows = useMemo(() => {
    if (serverMode || !searchTerm.trim()) {
      return rows;
    }

    const normalizedSearch = normalizeSearchText(searchTerm);

    return rows.filter((row, index) =>
      searchableColumns.some((column) => normalizeSearchText(getColumnTextValue(column, row, index)).includes(normalizedSearch))
    );
  }, [rows, searchTerm, searchableColumns, serverMode]);

  const sortedRows = useMemo(() => {
    if (serverMode || !sortConfig.column || !sortConfig.direction) {
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
  }, [columns, filteredRows, sortConfig, serverMode]);

  const totalPages = Math.max(1, Math.ceil((serverMode ? Number(serverMeta?.filteredCount || 0) : sortedRows.length) / rowsPerPage));

  useEffect(() => {
    if (serverMode && !serverMeta) return;
    setCurrentPage((current) => Math.min(current, totalPages));
  }, [totalPages, Boolean(serverMeta)]);

  const paginatedRowEntries = useMemo(() => {
    const startIndex = (currentPage - 1) * rowsPerPage;
    return (serverMode ? sortedRows : sortedRows.slice(startIndex, startIndex + rowsPerPage)).map((row, index) => ({
      row,
      index: startIndex + index,
    }));
  }, [currentPage, rowsPerPage, sortedRows, serverMode]);
  useLayoutEffect(()=>{
    const wrap=tableWrapRef.current;
    if(!wrap)return;
    if(loading){
      const limit=Number.parseFloat(window.getComputedStyle(wrap).maxHeight);
      const height=settledTableHeight.current||wrap.getBoundingClientRect().height;
      wrap.style.minHeight=(Number.isFinite(limit)?Math.min(height,limit):height)+"px";
    }else{
      wrap.style.minHeight="";
      settledTableHeight.current=wrap.getBoundingClientRect().height;
    }
  },[loading,paginatedRowEntries.length,rowsPerPage,filtersVisible]);

  const visiblePageNumbers = useMemo(() => {
    const radius = 2;
    const startPage = Math.max(1, currentPage - radius);
    const endPage = Math.min(totalPages, currentPage + radius);
    const pageNumbers = [];

    for (let pageNumber = startPage; pageNumber <= endPage; pageNumber += 1) {
      pageNumbers.push(pageNumber);
    }

    return pageNumbers;
  }, [currentPage, totalPages]);

  const selectedPageIds = useMemo(
    () => paginatedRowEntries.map((entry) => String(getRowId(entry.row, entry.index))).filter(Boolean),
    [getRowId, paginatedRowEntries]
  );

  useEffect(() => {
    if(selectPageRef.current) { const count = selectedPageIds.filter(id => selectedRowIds.includes(id)).length; selectPageRef.current.indeterminate = count > 0 && count < selectedPageIds.length; }
  },[selectedPageIds,selectionKey]);

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
    if (serverMode) {
      onServerChange({ sortBy: columnKey, sortDir: sortConfig.column === columnKey && sortConfig.direction === "asc" ? "desc" : "asc", skip: 0 });
      return;
    }
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
    if (serverMode) { onServerChange({ take: nextValue, skip: 0 }); return; }
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
        [columnKey]: Math.min(MAX_COLUMN_WIDTH, Math.max(MIN_COLUMN_WIDTH, initialWidth + delta)),
      }));
    };

    const handleMouseUp = () => {
      window.removeEventListener("mousemove", handleMouseMove);
      window.removeEventListener("mouseup", handleMouseUp);
    };

    window.addEventListener("mousemove", handleMouseMove);
    window.addEventListener("mouseup", handleMouseUp);
  }

  function handleResizeKey(columnKey, event) {
    if (!["ArrowLeft", "ArrowRight", "Home"].includes(event.key)) return;
    event.preventDefault();
    if (event.key === "Home") { handleResetColumnWidth(columnKey); return; }
    const step = event.shiftKey ? 40 : 10;
    const delta = event.key === "ArrowRight" ? step : -step;
    setColumnWidths((current) => ({ ...current, [columnKey]: Math.min(MAX_COLUMN_WIDTH, Math.max(MIN_COLUMN_WIDTH, getColumnWidth(columnKey) + delta)) }));
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


  const exportableColumns = tablePreferences?.ready
    ? tablePreferences.exportKeys.map(key => columns.find(column => column.key === key)).filter(column => column && column.key !== "actions")
    : effectiveVisibleColumns.filter((column) => column.key !== "actions");
  const exportBaseFilename = String(exportFilename || "logistique-tableau").replace(/\.(csv|xls|xlsx|pdf)$/i, "");
  const exportRows =
    selectedRowIds.length > 0
      ? sortedRows.filter((row, index) => selectedRowIds.includes(String(getRowId(row, index))))
      : sortedRows;

  return (
    <div className={"logistics-advanced-table" + (toolbar ? " erp-data-grid" : "") + (loading ? " is-loading" : "")} aria-busy={loading}>
      {loading ? <span className="erp-grid-loading" role="status">{rows.length ? "Actualisation des résultats…" : "Chargement des résultats…"}</span> : null}
      {showControls ? (
        <section className="admin-search-card logistics-table-controls logistics-table-toolbar-card">
          {toolbar || <>
          <div className="logistics-table-control-row">
            {showSearch ? <label className="admin-form-field logistics-table-search-field">
              <span>Recherche rapide</span>
              <input
                type="search"
                value={serverMode ? serverState.q || "" : searchTerm}
                onChange={(event) => {
                  if (serverMode) onServerChange({ q: event.target.value, skip: 0 });
                  else { setSearchTerm(event.target.value); setCurrentPage(1); }
                }}
                placeholder={serverMode ? "Rechercher dans le registre" : "Filtrer les lignes chargées"}
              />
            </label> : null}

            <div className="admin-toolbar-actions">
              <label className="admin-form-field logistics-inline-select">
                <span>Lignes</span>
                <select value={rowsPerPage} disabled={loading} onChange={(event) => handleRowsPerPageChange(Number(event.target.value))}>
                  {rowsPerPageOptions.map((value) => (
                    <option key={value} value={value}>
                      {value}
                    </option>
                  ))}
                </select>
              </label>

              <ActionButton ref={columnsTrigger} icon={tablePreferences ? "settings" : "columns"} disabled={loading} aria-expanded={controlsOpen} onClick={()=>setControlsOpen(current=>!current)}>{tablePreferences ? "Réglages" : "Colonnes"}</ActionButton>

              <div ref={exportMenuRef} className="admin-scroll-menu" aria-label="Options d'export logistique">
                <ActionButton icon="download"
                  type="button"

                  onClick={() => {
                    setShowNavigationMenu(false);
                    setShowExportMenu((current) => !current);
                  }}
                  disabled={loading || !exportRows.length}
                  aria-expanded={showExportMenu}
                  aria-haspopup="true"
                >
                  Exporter
                </ActionButton>
                {showExportMenu ? (
                  <div className="admin-scroll-menu-panel">
                    <ActionButton icon="download"
                      type="button"

                      onClick={() => {
                        exportRowsToCsv(`${exportBaseFilename}.csv`, exportableColumns, exportRows);
                        setShowExportMenu(false);
                      }}
                      disabled={loading || !exportRows.length}
                    >
                      CSV · page
                    </ActionButton>
                    <ActionButton icon="download"
                      type="button"

                      onClick={() => {
                        exportRowsToExcel(`${exportBaseFilename}.csv`, exportableColumns, exportRows);
                        setShowExportMenu(false);
                      }}
                      disabled={loading || !exportRows.length}
                    >
                      Tableur HTML · page
                    </ActionButton>
                    <ActionButton icon="print"
                      type="button"

                      onClick={() => {
                        exportRowsToPdf(exportBaseFilename, exportableColumns, exportRows);
                        setShowExportMenu(false);
                      }}
                      disabled={loading || !exportRows.length}
                    >
                      Imprimer · page
                    </ActionButton>
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
                  disabled={loading || !scrollState.overflow}
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
                      disabled={loading || !scrollState.canScrollLeft}
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
                      disabled={loading || !scrollState.canScrollLeft}
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
                      disabled={loading || !scrollState.canScrollRight}
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
                      disabled={loading || !scrollState.canScrollRight}
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
              <span className="status-pill is-muted">{serverMode ? (serverMeta?.filteredCount ?? "—") + " résultat(s)" : `${sortedRows.length}/${rows.length} lignes`}</span>
              <span className="status-pill is-muted">{`${effectiveVisibleColumns.length} colonnes visibles`}</span>
              <span className="status-pill is-muted">{`${pinnedColumns.length} colonnes gelees`}</span>
              {enableSelection ? (
                <span className="status-pill is-muted">{`${selectedRowIds.length} selectionnees`}</span>
              ) : null}
              {scrollState.overflow ? <span className="status-pill is-muted">Defilement horizontal actif</span> : null}
            </div>

          </div>

          </>}
          {tablePreferences ? controlsOpen ? <TableSettings key={tablePreferences.contextKey} preferences={tablePreferences} onClose={()=>closeColumns(true)} pinnedKeys={pinnedColumns} onTogglePinned={handleTogglePinnedColumn} onResetWidths={()=>setColumnWidths(Object.fromEntries(columns.map(column=>[column.key,getColumnDefaultWidth(column)])))}/> : null : <ColumnPicker open={controlsOpen} anchorRef={columnsTrigger} onClose={closeColumns} columns={columns} visibleKeys={visibleColumns} pinnedKeys={pinnedColumns} onToggleVisible={handleToggleVisibleColumn} onTogglePinned={handleTogglePinnedColumn} onShowAll={()=>setVisibleColumns(columns.map(column=>column.key))} onResetWidth={handleResetColumnWidth} onResetWidths={()=>setColumnWidths(Object.fromEntries(columns.map(column=>[column.key,getColumnDefaultWidth(column)])))} />}
        </section>
      ) : null}

      <div
        ref={tableWrapRef}
        inert={loading ? true : undefined}
        className="public-table-wrap logistics-table-wrap admin-table-wrap"
        tabIndex={0}
        aria-label="Tableau logistique avance avec defilement horizontal et vertical"
      >
        <table className="public-table logistics-table admin-table table table-hover align-middle mb-0">
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
                    ref={selectPageRef}
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
                    aria-sort={sortConfig.column === column.key ? (sortConfig.direction === "asc" ? "ascending" : "descending") : "none"}
                    className={`admin-table-head-cell ${isPinned ? "is-pinned" : ""} ${column.align === "right" ? "is-numeric" : ""}`}
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
                              <i className={"bi " + (sortConfig.column === column.key ? sortConfig.direction === "asc" ? "bi-arrow-up" : "bi-arrow-down" : "bi-arrow-down-up")} />
                            </small>
                          ) : null}
                        </button>
                      </div>

                      <div
                        className="admin-resize-handle"
                        onMouseDown={(event) => handleResizeStart(column.key, event)}
                        onKeyDown={(event) => handleResizeKey(column.key, event)}
                        tabIndex={0}
                        role="separator"
                        aria-valuemin={MIN_COLUMN_WIDTH}
                        aria-valuemax={MAX_COLUMN_WIDTH}
                        aria-valuenow={Math.round(getColumnWidth(column.key))}
                        aria-valuetext={Math.round(getColumnWidth(column.key)) + " pixels"}
                        title="Flèches : ajuster · Maj : accélérer · Début : largeur automatique"
                        aria-orientation="vertical"
                        aria-label={`Redimensionner la colonne ${column.label}`}
                      />
                    </div>
                  </th>
                );
              })}
            </tr>
            {filtersVisible ? <tr className="erp-column-filter-row">
              {enableSelection ? <th /> : null}
              {effectiveVisibleColumns.map((column) => <th key={column.key} className={pinnedColumns.includes(column.key) ? "is-pinned" : ""} style={getCellStyle(column)}>
                {column.filterType ? (column.filterType === "boolean" ? <CategoricalSelect aria-label={"Filtrer : " + column.label} value={columnFilters[column.key] || ""} onChange={(event) => onColumnFilterChange?.(column.key,event.target.value)}><option value="">Tous</option><option value="true">Oui</option><option value="false">Non</option></CategoricalSelect> : <input type={column.filterType === "date" ? "date" : "text"} aria-label={"Filtrer : " + column.label} placeholder={column.filterType === "number" ? "=, >=, <=…" : "Filtrer…"} title={column.filterType === "number" ? "Exemples : 50, >= 50, <= 100" : column.label} value={columnFilters[column.key] || ""} onChange={(event) => onColumnFilterChange?.(column.key,event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") { event.preventDefault(); onApplyColumnFilters?.(); } }} />) : null}
              </th>)}
            </tr> : null}
          </thead>

          <tbody>
            {!paginatedRowEntries.length ? <tr className="erp-grid-empty"><td colSpan={Math.max(1,effectiveVisibleColumns.length + Number(enableSelection))}>{loading ? "Chargement…" : emptyMessage || "Aucun résultat pour ces critères."}</td></tr> : null}
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
                          column.align === "right" ? "is-numeric" : column.key === "actions" ? "admin-actions-cell" : ""
                        }`.trim()}
                        style={getCellStyle(column)}
                      >
                        {onRowConsult && consultColumns.includes(column.key) && isCellConsultable(row, column.key) ? <button type="button" className="erp-object-link" onClick={(event) => { event.stopPropagation(); onRowConsult(row, column.key); }}>{column.render ? column.render(row, rowIndex) : (row[column.key] == null || row[column.key] === "" ? "—" : row[column.key])}</button> : column.render ? column.render(row, rowIndex) : row[column.key] ?? "—"}
                      </td>
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <TablePagination total={serverMode ? serverMeta?.filteredCount : sortedRows.length} take={rowsPerPage} page={currentPage} onPage={setCurrentPage} loading={loading} />
    </div>
  );
}

export function ToneBadge({ children, tone = "info" }) {
  return <span className={`logistics-badge is-${tone}`}>{children}</span>;
}

export function SelectField({label,value,onChange,options=[],allowEmpty=true,emptyLabel="Choisir",disabled=false,required=false,helperText=""}) {
  return <label className="admin-form-field"><span>{label}</span>
    <CategoricalSelect aria-label={label} value={value} onChange={onChange} disabled={disabled} required={required}>
      {allowEmpty?<option value="">{emptyLabel}</option>:null}
      {Array.isArray(options)?options.map(option=><option key={option.value} value={option.value} disabled={option.disabled}>{option.label}</option>):null}
    </CategoricalSelect>
    {helperText?<small>{helperText}</small>:null}
  </label>;
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
