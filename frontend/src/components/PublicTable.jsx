export default function PublicTable({ columns, rows, emptyMessage = "Aucune donnée publique disponible." }) {
  if (!rows.length) {
    return <div className="table-empty-state">{emptyMessage}</div>;
  }

  return (
    <div className="public-table-wrap">
      <table className="public-table">
        <thead>
          <tr>
            {columns.map((column) => (
              <th key={column.key}>{column.label}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, rowIndex) => (
            <tr key={row.id || rowIndex}>
              {columns.map((column) => (
                <td key={`${row.id || rowIndex}-${column.key}`}>
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
