import "./RegisterSurface.css";
export default function RegisterSurface({ title, subtitle, actions, tabs, children, className = "" }) {
  return <section className={"erp-register " + className}>
    <header className="erp-register-heading"><div><h1>{title}</h1>{subtitle ? <p>{subtitle}</p> : null}</div><div className="erp-register-actions">{actions}</div></header>
    <div className="erp-register-card">{tabs}{children}</div>
  </section>;
}
