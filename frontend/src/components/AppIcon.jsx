import "./AppIcon.css";
const paths = {
  pin:"m16 3 5 5-3 1-3 6v3l-3-3H9l6-6 1-6ZM3 21l6-6",
  search:"m21 21-4.35-4.35M19 11a8 8 0 1 1-16 0 8 8 0 0 1 16 0Z",
  reset:"M3 10a9 9 0 1 1 2.4 8.1M3 4v6h6",
  refresh:"M20 7a9 9 0 0 0-15.5-2M4 3v5h5M4 17a9 9 0 0 0 15.5 2M20 21v-5h-5",
  download:"M12 3v12m-4-4 4 4 4-4M5 15v4a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-4",
  filter:"M4 4h16l-6 7v7l-4 2v-9L4 4Z",
  columns:"M4 4h16v16H4V4Zm5 0v16m6-16v16",
  expand:"M8 3H3v5m0-5 6 6M16 21h5v-5m0 5-6-6",
  compact:"M3 9h6V3m0 6L3 3M21 15h-6v6m0-6 6 6",
  'chevron-up':"m6 15 6-6 6 6", 'chevron-down':"m6 9 6 6 6-6", 'chevron-left':"m15 6-6 6 6 6", 'chevron-right':"m9 6 6 6-6 6",
  'arrow-up':"M12 20V4m-6 6 6-6 6 6", 'arrow-up-right':"M7 17 17 7M7 7h10v10",
  close:"m6 6 12 12M6 18 18 6", plus:"M12 5v14M5 12h14",
  box:"m3 7 9-5 9 5v10l-9 5-9-5V7Zm0 0 9 5 9-5m-9 5v10M7.5 4.5l9 5",
  document:"M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9l-6-6Zm0 0v6h6M8 13h8m-8 4h6",
  receipt:"M6 3h12v18l-3-2-3 2-3-2-3 2V3Zm3 5h6m-6 4h6m-6 4h4",
  list:"M9 6h12M9 12h12M9 18h12M3 6h.01M3 12h.01M3 18h.01",
  movements:"M4 7h16m-4-4 4 4-4 4M20 17H4m4-4-4 4 4 4",
  wallet:"M20 7V5a2 2 0 0 0-2-2H6a3 3 0 0 0 0 6h14v11H6a3 3 0 0 1-3-3V6m17 6h-5v5h5m-2.5-2.5h.01",
  dashboard:"M3 3h7v7H3V3Zm11 0h7v7h-7V3ZM3 14h7v7H3v-7Zm11 0h7v7h-7v-7Z",
  apps:"M3 3h5v5H3V3Zm13 0h5v5h-5V3ZM3 16h5v5H3v-5Zm13 0h5v5h-5v-5ZM10 10h4v4h-4v-4Z",
  sidebar:"M4 3h16v18H4V3Zm5 0v18",
  alert:"m12 3 10 18H2L12 3Zm0 6v5m0 3h.01",
  clock:"M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-5v5l3 2",
  'stock-in':"M4 14v6h16v-6M12 3v12m-4-4 4 4 4-4",
  'stock-out':"M4 14v6h16v-6M12 15V3m-4 4 4-4 4 4",
  cash:"M3 6h18v12H3V6Zm12 6a3 3 0 1 1-6 0 3 3 0 0 1 6 0ZM6 9h.01M18 15h.01",
  'check-circle':"M21 11.1V12a9 9 0 1 1-5.3-8.2M21 4l-9 9-3-3",
  calendar:"M4 5h16v16H4V5Zm4-3v6m8-6v6M4 10h16",
  'calendar-x':"M4 5h16v16H4V5Zm4-3v6m8-6v6M4 10h16m-9 4 4 4m-4 0 4-4",
  bell:"M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9Zm-8 12h4",
  tag:"M3 3h8l10 10-8 8L3 11V3Zm4 4h.01",
  chart:"M4 3v18h17M8 16v-4m5 4V7m5 9v-6",
  percent:"m5 19 14-14M9 6a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm12 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z",
  logout:"M9 4H4v16h5m5-12 4 4-4 4m-7-4h14",
  print:"M6 8V3h12v5M6 17H3V9h18v8h-3M6 14h12v7H6v-7Zm12-3h.01"
};
const aliases={ 'bi-search':'search','bi-arrow-counterclockwise':'reset','bi-arrow-clockwise':'refresh','bi-arrow-repeat':'refresh','bi-box':'box','bi-box-seam':'box','bi-receipt':'receipt','bi-list-ul':'list','bi-list-check':'list','bi-arrow-left-right':'movements','bi-wallet2':'wallet','bi-speedometer2':'dashboard','bi-grid':'apps','bi-grid-3x3-gap':'apps','bi-layout-sidebar':'sidebar','bi-layout-sidebar-inset':'sidebar','bi-file-earmark':'document','bi-file-earmark-text':'document','bi-hourglass-split':'clock','bi-box-arrow-in-down':'stock-in','bi-box-arrow-up':'stock-out','bi-cash-stack':'cash','bi-check2-circle':'check-circle','bi-exclamation-triangle':'alert','bi-exclamation-circle':'alert','bi-calendar-event':'calendar','bi-calendar-x':'calendar-x','bi-bell':'bell','bi-tag':'tag','bi-bar-chart':'chart','bi-percent':'percent' };
export default function AppIcon({name,size=16,className=""}) {
  const key=aliases[name] || name;
  if(!paths[key]) return null;
  return <svg className={"app-icon " + className} data-icon={key} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false"><path d={paths[key]} /></svg>;
}
