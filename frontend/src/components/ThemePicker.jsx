import { useTheme } from "../contexts/ThemeContext";
const OPTIONS = [["light", "Clair", "bi-sun"], ["dark", "Sombre", "bi-moon-stars"], ["contrast", "Contraste élevé", "bi-circle-half"], ["system", "Système", "bi-display"]];
export default function ThemePicker() {
  const { mode, setMode } = useTheme();
  const selected = OPTIONS.find(([key]) => key === mode) || OPTIONS[0];
  return <label className="theme-picker" title={"Thème : " + selected[1]}><i className={"bi " + selected[2]} aria-hidden="true" /><select aria-label="Thème" value={mode} onChange={(event) => setMode(event.target.value)}>{OPTIONS.map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></label>;
}
