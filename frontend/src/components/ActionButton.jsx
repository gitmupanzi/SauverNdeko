import AppIcon from "./AppIcon";
import "./ActionButton.css";
export default function ActionButton({icon,variant="secondary",className="",children,type="button",...props}) {
  return <button {...props} type={type} className={"ui-action is-"+variant+" "+className} data-action={icon || undefined}>{icon ? <AppIcon name={icon} /> : null}{children}</button>;
}
