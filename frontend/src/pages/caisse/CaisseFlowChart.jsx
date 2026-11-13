import {useId, useState} from "react";
import {formatCurrency} from "../../utils/money";
import "./CaisseFlowChart.css";

const dayMs = 86_400_000;
const dayFormat = new Intl.DateTimeFormat("fr-CD", {day:"numeric",month:"short",year:"numeric",timeZone:"UTC"});
const axisFormat = new Intl.DateTimeFormat("fr-CD", {day:"numeric",month:"short",timeZone:"UTC"});
const axisNumber = new Intl.NumberFormat("fr-CD", {notation:"compact",maximumFractionDigits:1});
const series = [{key:"Entrees",label:"Encaissements"},{key:"Sorties",label:"Décaissements"}];
const chart = {left:64,right:740,top:20,bottom:170};

export function caisseFlowDays(rows, {dateMin,dateMax} = {}) {
  const dates = new Map();
  for (const row of rows) {
    const date = String(row.DateJour ?? "").slice(0,10);
    const timestamp = Date.parse(date + "T00:00:00Z");
    if (Number.isFinite(timestamp)) dates.set(timestamp, {...row, timestamp});
  }
  if (!dates.size) return [];
  const days = [...dates.keys()].sort((a,b) => a - b);
  const start = Date.parse(dateMin + "T00:00:00Z");
  const end = Date.parse(dateMax + "T00:00:00Z");
  const first = Number.isFinite(start) ? Math.min(start, days[0]) : days[0];
  const last = Number.isFinite(end) ? Math.max(end, days.at(-1)) : days.at(-1);
  // Keep empty days at the edges of gaps without allocating decades of daily points.
  const boundaries = new Set([first, last, ...days]);
  let previous = first;
  for (const timestamp of [...days,last]) {
    if (timestamp - previous > dayMs) {
      boundaries.add(previous + dayMs);
      boundaries.add(timestamp - dayMs);
    }
    previous = timestamp;
  }
  return [...boundaries].sort((a,b) => a - b).map(timestamp =>
    dates.get(timestamp) || {timestamp,Entrees:"0",Sorties:"0"});
}

export default function CaisseFlowChart({rows, currency, filters}) {
  const titleId = useId();
  const [activeTimestamp, setActiveTimestamp] = useState(null);
  const days = caisseFlowDays(rows, filters);
  if (!days.length) return null;
  const first = days[0].timestamp;
  const last = days.at(-1).timestamp;
  const duration = last - first;
  const x = day => duration ? chart.left + (day - first) / duration * (chart.right - chart.left) : (chart.left + chart.right) / 2;
  const peak = days.reduce((max, day) => Math.max(max,Number(day.Entrees) || 0,Number(day.Sorties) || 0),0);
  const y = amount => chart.bottom - Number(amount || 0) / (peak || 1) * (chart.bottom - chart.top);
  const chosen = days.find(day => day.timestamp === activeTimestamp) ?? days.at(-1);
  const marks = duration ? [first, first + Math.round(duration / dayMs / 2) * dayMs, last] : [first];
  const index = days.indexOf(chosen);
  return <figure className="caisse-flow-chart" aria-labelledby={titleId}>
    <div className="caisse-flow-heading">
      <h3 id={titleId}>Évolution quotidienne des flux</h3>
      <div className="caisse-flow-legend">{series.map(({key,label}) => <span key={key} className={"caisse-flow-" + key}>{label}</span>)}</div>
    </div>
    <svg viewBox="0 0 760 206" aria-hidden="true" onPointerMove={event => {
      const box = event.currentTarget.getBoundingClientRect();
      const position = (event.clientX - box.left) / box.width * 760;
      let nearest = days[0];
      for (const day of days) if (Math.abs(x(day.timestamp) - position) < Math.abs(x(nearest.timestamp) - position)) nearest = day;
      setActiveTimestamp(nearest.timestamp);
    }}>
      {(peak ? [0, .25, .5, .75, 1] : [0]).map(level => <g key={level}>
        <line className="caisse-flow-gridline" x1={chart.left} x2={chart.right} y1={y(peak * level)} y2={y(peak * level)}/>
        <text x={chart.left - 9} y={y(peak * level) + 4} textAnchor="end">{axisNumber.format(peak * level)}</text>
      </g>)}
      <line className="caisse-flow-guide" x1={x(chosen.timestamp)} x2={x(chosen.timestamp)} y1={chart.top} y2={chart.bottom}/>
      {series.map(({key}) => <g key={key} className={"caisse-flow-" + key}>
        <polyline points={days.map(day => x(day.timestamp) + "," + y(day[key])).join(" ")} fill="none"/>
        <circle cx={x(chosen.timestamp)} cy={y(chosen[key])} r={key === "Entrees" ? 5 : 3.4}/>
      </g>)}
      {[...new Set(marks)].map((timestamp, i, values) => <text key={timestamp} className={values.length===3&&i===1?"caisse-flow-midmark":undefined} x={x(timestamp)} y="195"
        textAnchor={values.length === 1 || i === 1 && values.length === 3 ? "middle" : i === 0 ? "start" : "end"}>{axisFormat.format(timestamp)}</text>)}
    </svg>
    <figcaption className="caisse-flow-reading">
      <time dateTime={new Date(chosen.timestamp).toISOString().slice(0,10)}>{dayFormat.format(chosen.timestamp)}</time>
      {series.map(({key,label}) => <span key={key}>{label} <strong>{formatCurrency(chosen[key], currency)}</strong></span>)}
    </figcaption>
    {days.length > 1 ? <input className="caisse-flow-day" type="range" min="0" max={days.length - 1} value={index}
      aria-label={"Jour du graphique " + currency} aria-valuetext={dayFormat.format(chosen.timestamp)}
      onChange={event => setActiveTimestamp(days[Number(event.target.value)].timestamp)}/> : null}
  </figure>;
}