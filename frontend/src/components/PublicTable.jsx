import ListState from "./ListState";

export default function PublicTable({ columns, rows, emptyMessage = "Aucune donnée publique disponible.",tableLabel="Liste des résultats" }) {
  if (!rows.length) {
    return <div className="table-empty-state"><ListState title={emptyMessage}/></div>;
  }

  return (
    <div className="public-table-wrap" role="region" tabIndex={0} aria-label={tableLabel + " · tableau défilant"}>
      <table className="public-table" aria-label={tableLabel}>
        <thead>
          <tr>
            {columns.map((column) => (
              <th scope="col" key={column.key}>{column.label}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, rowIndex) => (
            <tr key={row.id ?? rowIndex}>
              {columns.map((column) => (
                <td key={`${row.id ?? rowIndex}-${column.key}`}>
                  {typeof column.render === "function" ? column.render(row[column.key], row) : row[column.key]}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
