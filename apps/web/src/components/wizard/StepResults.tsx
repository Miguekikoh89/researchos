'use client';
import { useState, useRef } from 'react';
import { Activity, BarChart2, TrendingUp, BookOpen, Shield, ChevronLeft, ChevronRight, ChevronDown, ChevronUp } from 'lucide-react';
import type { WizardState } from '@/app/analysis/new/page';

interface Props { state: WizardState; onNext: () => void; onBack: () => void; }

function dt(text: any): string {
  if (!text) return '';
  let s = String(text);
  // Fix <U+00F3> style unicode
  s = s.replace(/<U[+]([0-9A-Fa-f]{4})>/g, (_: string, hex: string) => String.fromCharCode(parseInt(hex, 16)));
  return s
    .replace(/<c3><b3>/g,'ó').replace(/<c3><a1>/g,'á').replace(/<c3><a9>/g,'é')
    .replace(/<c3><ad>/g,'í').replace(/<c3><ba>/g,'ú').replace(/<c3><b1>/g,'ñ')
    .replace(/<c3><93>/g,'Ó').replace(/<c3><81>/g,'Á').replace(/<c3><89>/g,'É')
    .replace(/<cf><81>/g,'ρ').replace(/<ce><b1>/g,'α')
    .replace(/<cf><87>/g,'χ').replace(/<c2><b2>/g,'²').replace(/<c2><b3>/g,'³')
    .replace(/<e2><89><a4>/g,'≤').replace(/<e2><89><a5>/g,'≥')
    .replace(/<e2><80><93>/g,'–').replace(/<e2><9c><97>/g,'✗').replace(/<e2><9c><93>/g,'✓')
    .replace(/<e2><89><a4>/g,'\u2264').replace(/<e2><89><a5>/g,'\u2265').replace(/<e2><89><a0>/g,'\u2260')
    .replace(/<e2><9c><97>/g,'\u2717').replace(/<e2><9c><93>/g,'\u2713').replace(/<e2><80><93>/g,'\u2013').replace(/<e2><82><80>/g,'₀');
}

function sa(val: any): any[] {
  if (Array.isArray(val)) return val;
  if (val && typeof val === 'object') return Object.values(val);
  return [];
}

function Section({ title, icon: Icon, color='indigo', defaultOpen=true, children }: {
  title: string; icon: any; color?: string; defaultOpen?: boolean; children: React.ReactNode;
}) {
  const [open, setOpen] = useState(defaultOpen);
  const bc: Record<string,string> = { indigo:'border-indigo-200 bg-indigo-50/40', teal:'border-teal-200 bg-teal-50/40', amber:'border-amber-200 bg-amber-50/40', blue:'border-blue-200 bg-blue-50/40', purple:'border-purple-200 bg-purple-50/40', green:'border-green-200 bg-green-50/40' };
  const ic: Record<string,string> = { indigo:'text-indigo-600', teal:'text-teal-600', amber:'text-amber-600', blue:'text-blue-600', purple:'text-purple-600', green:'text-green-600' };
  return (
    <div className={`rounded-2xl border ${bc[color]||bc.indigo} overflow-hidden`}>
      <button onClick={() => setOpen(!open)} className="w-full flex items-center justify-between px-5 py-4 hover:bg-white/40 transition">
        <div className="flex items-center gap-3"><Icon className={`w-5 h-5 ${ic[color]}`}/><span className="font-semibold text-slate-800">{title}</span></div>
        {open ? <ChevronUp className="w-4 h-4 text-slate-400"/> : <ChevronDown className="w-4 h-4 text-slate-400"/>}
      </button>
      {open && <div className="px-5 pb-5 space-y-4">{children}</div>}
    </div>
  );
}

function Tbl({ headers, rows }: { headers: string[]; rows: any[][] }) {
  return (
    <div className="overflow-x-auto rounded-xl border border-slate-200">
      <table className="w-full text-sm">
        <thead className="bg-slate-50 border-b border-slate-200"><tr>{headers.map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600 whitespace-nowrap">{h}</th>)}</tr></thead>
        <tbody>{sa(rows).map((row,i)=><tr key={i} className="border-b border-slate-100 hover:bg-slate-50">{sa(row).map((cell,j)=><td key={j} className="px-3 py-2 text-slate-700">{cell}</td>)}</tr>)}</tbody>
      </table>
    </div>
  );
}

function KPI({ label, value }: { label: string; value: any }) {
  return (
    <div className="bg-white rounded-xl border border-slate-200 p-3 text-center">
      <p className="text-xs text-slate-500 mb-1">{label}</p>
      <p className="font-bold text-indigo-700">{value}</p>
    </div>
  );
}

const ALL_TABS = [
  { id:'resumen',       label:'Resumen',       icon:BookOpen,    methods:['all'] },
  { id:'normalidad',    label:'Normalidad',    icon:Activity,    methods:['correlacional','comparacion','anova','regresion','logistica','instrumentos','descriptivo'] },
  { id:'confiabilidad', label:'Confiabilidad', icon:Shield,      methods:['correlacional','comparacion','anova','regresion','logistica','instrumentos','descriptivo'] },
  { id:'correlacion',   label:'Correlación',   icon:TrendingUp,  methods:['correlacional'] },
  { id:'descriptivos',  label:'Descriptivos',  icon:BarChart2,   methods:['correlacional','comparacion','anova','regresion','logistica','instrumentos'] },
  { id:'baremos',       label:'Baremos',       icon:BarChart2,   methods:['correlacional','comparacion','anova','instrumentos'] },
  { id:'comparacion',   label:'Comparación',   icon:Activity,    methods:['comparacion'] },
  { id:'anova',         label:'ANOVA',         icon:BarChart2,   methods:['anova'] },
  { id:'regresion',     label:'Regresión',     icon:TrendingUp,  methods:['regresion'] },
  { id:'logistica',     label:'Logística',     icon:TrendingUp,  methods:['logistica'] },
  { id:'chi',           label:'Chi²',          icon:Activity,    methods:['chi_cuadrado'] },
  { id:'instrumentos',  label:'Validación',    icon:Shield,      methods:['instrumentos'] },
  { id:'ordinal',        label:'Reg. Ordinal',  icon:TrendingUp,  methods:['regresion_ordinal'] },
  { id:'jerarquica',     label:'Reg. Jerárq.',  icon:TrendingUp,  methods:['regresion_jerarquica'] },
  { id:'ancova',         label:'ANCOVA',        icon:BarChart2,   methods:['ancova'] },
  { id:'discriminante',  label:'Discriminante', icon:Activity,    methods:['discriminante'] },
    { id:'cluster',        label:'Clúster',       icon:BarChart2,   methods:['cluster'] },
  { id:'cronbach_tab',   label:'Confiabilidad', icon:Shield,      methods:['cronbach'] },
  { id:'descriptivo_tab', label:'Análisis Descriptivo', icon:BarChart2, methods:['descriptivo'] },
];
function getVisibleTabs(method: string) {
  return ALL_TABS.filter(t =>
    t.methods.includes('all') || t.methods.includes(method)
  );
}


// ============================================================================
// PLS-SEM Results Component — Fase 1 Completa (basado en app Scopus)
// ============================================================================
function PlsTable({ headers, rows, colorCol, thresholds, colors }: any) {
  return (
    <div className="overflow-x-auto rounded-xl border border-slate-200">
      <table className="w-full text-sm">
        <thead className="bg-gradient-to-r from-slate-700 to-slate-800 text-white">
          <tr>{headers.map((h:string)=><th key={h} className="px-3 py-2.5 text-left font-semibold text-xs uppercase tracking-wide whitespace-nowrap">{h}</th>)}</tr>
        </thead>
        <tbody>
          {sa(rows).map((row:any,i:number)=>(
            <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
              {Object.values(row).map((cell:any,j:number)=>(
                <td key={j} className="px-3 py-2 text-slate-700 whitespace-nowrap">{String(cell??'—')}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function PCard({ title, icon, color='indigo', children }: any) {
  const [open, setOpen] = useState(true);
  const colors: Record<string,string> = {
    indigo:'border-indigo-200 bg-indigo-50/30', teal:'border-teal-200 bg-teal-50/30',
    purple:'border-purple-200 bg-purple-50/30', amber:'border-amber-200 bg-amber-50/30',
    cyan:'border-cyan-200 bg-cyan-50/30', green:'border-green-200 bg-green-50/30',
    red:'border-red-200 bg-red-50/30', blue:'border-blue-200 bg-blue-50/30',
  };
  const iconColors: Record<string,string> = {
    indigo:'bg-indigo-600', teal:'bg-teal-600', purple:'bg-purple-600',
    amber:'bg-amber-500', cyan:'bg-cyan-600', green:'bg-green-600',
    red:'bg-red-600', blue:'bg-blue-600',
  };
  return (
    <div className={`rounded-2xl border ${colors[color]||colors.indigo} overflow-hidden`}>
      <button onClick={()=>setOpen(!open)} className="w-full flex items-center justify-between px-5 py-4 hover:bg-white/40 transition">
        <div className="flex items-center gap-3">
          <div className={`w-9 h-9 ${iconColors[color]||iconColors.indigo} rounded-xl flex items-center justify-center text-white font-bold text-sm flex-shrink-0`}>{icon}</div>
          <span className="font-bold text-slate-800 text-base">{title}</span>
        </div>
        <span className="text-slate-400 text-lg">{open?'▲':'▼'}</span>
      </button>
      {open && <div className="px-5 pb-5 space-y-4">{children}</div>}
    </div>
  );
}


// ============================================================================
// PLS-SEM Diagram PRO — Draggable, Zoom, Pan, Download
// ============================================================================
function PlsDiagram({ paths, cargas, r2list, hypotheses }: any) {
  const svgRef = useRef<SVGSVGElement>(null);
  const [zoom, setZoom] = useState(0.85);
  const [pan, setPan] = useState({x:0,y:0});
  const [isPanning, setIsPanning] = useState(false);
  const [panStart, setPanStart] = useState({x:0,y:0});
  const [dragNode, setDragNode] = useState<string|null>(null);
  const [nodePos, setNodePos] = useState<Record<string,{x:number,y:number}>>({});
  const [initialized, setInitialized] = useState(false);

  // Build structures
  const itemsByCon: Record<string,any[]> = {};
  cargas.forEach((c:any)=>{ if(!itemsByCon[c.Constructo]) itemsByCon[c.Constructo]=[]; itemsByCon[c.Constructo].push(c); });
  const maxItems = Math.max(...Object.values(itemsByCon).map((v:any)=>v.length), 4);
  const W = 1200, H = Math.max(720, maxItems * 36 + 240);

  const allFrom = paths.map((p:any)=>p.Path?.split(' -> ')[0]?.trim()).filter(Boolean);
  const allTo   = paths.map((p:any)=>p.Path?.split(' -> ')[1]?.trim()).filter(Boolean);
  const allCons = [...new Set([...allFrom,...allTo])];

  // Topological levels
  const levels: Record<string,number> = {};
  allCons.forEach((cn:string)=>{ levels[cn] = !allTo.includes(cn)?0:!allFrom.includes(cn)?99:1; });
  for(let it=0;it<12;it++){paths.forEach((p:any)=>{
    const fr=p.Path?.split(' -> ')[0]?.trim(); const to=p.Path?.split(' -> ')[1]?.trim();
    if(fr&&to&&levels[fr]!==undefined&&levels[to]!==undefined&&levels[to]<=levels[fr]) levels[to]=levels[fr]+1;
  });}
  const maxRealLvl = Math.max(...Object.values(levels).filter(v=>v<99));
  Object.keys(levels).forEach(k=>{ if(levels[k]===99) levels[k]=maxRealLvl; });
  const maxLvl = Math.max(...Object.values(levels));

  // Initial positions
  const initPositions = () => {
    const pos: Record<string,{x:number,y:number}> = {};
    const MARGIN_X = 180, ITEM_AREA = 160;
    const consByLevel: Record<number,string[]> = {};
    Object.entries(levels).forEach(([cn,l])=>{ if(!consByLevel[l]) consByLevel[l]=[]; consByLevel[l].push(cn); });
    Object.entries(consByLevel).forEach(([lvl,cons])=>{
      const x = MARGIN_X + ITEM_AREA + (Number(lvl)/(maxLvl||1))*(W - 2*(MARGIN_X+ITEM_AREA));
      cons.forEach((cn,i)=>{ pos[cn]={x, y:(i+1)*(H/(cons.length+1))}; });
    });
    // Items
    Object.entries(itemsByCon).forEach(([con,items]:any)=>{
      const pc=pos[con]; if(!pc) return;
      const isLeft=(levels[con]||0)===0;
      const ix = isLeft ? pc.x - ITEM_AREA : pc.x + ITEM_AREA;
      const spacing = Math.min(32, Math.max(22, (H-100)/(items.length+1)));
      const startY = pc.y - ((items.length-1)/2)*spacing;
      items.forEach((item:any,i:number)=>{ pos[item.Item]={x:ix, y:startY+i*spacing}; });
    });
    return pos;
  };

  // Initialize positions once
  if (!initialized && paths.length > 0 && cargas.length > 0) {
    const initPos = initPositions();
    setNodePos(initPos);
    setInitialized(true);
  }

  const pos = Object.keys(nodePos).length > 0 ? nodePos : initPositions();
  const r2map: Record<string,number> = {};
  r2list.forEach((r:any)=>{ r2map[r.Constructo]=Number(r.R2); });
  const CON_RX=56, CON_RY=30, IT_W=64, IT_H=22;
  const allItems = cargas.map((c:any)=>c.Item);

  // SVG coordinate from mouse event
  const getSVGCoords = (e: any) => {
    if(!svgRef.current) return {x:0,y:0};
    const rect = svgRef.current.getBoundingClientRect();
    return {
      x: (e.clientX - rect.left - pan.x) / zoom,
      y: (e.clientY - rect.top - pan.y) / zoom
    };
  };

  const handleMouseDown = (e: any, nodeId: string) => {
    e.stopPropagation();
    setDragNode(nodeId);
  };

  const handleSVGMouseDown = (e: any) => {
    if(!dragNode) { setIsPanning(true); setPanStart({x:e.clientX-pan.x, y:e.clientY-pan.y}); }
  };

  const handleMouseMove = (e: any) => {
    if(dragNode) {
      const {x,y} = getSVGCoords(e);
      setNodePos(prev=>({...prev, [dragNode]:{x,y}}));
    } else if(isPanning) {
      setPan({x:e.clientX-panStart.x, y:e.clientY-panStart.y});
    }
  };

  const handleMouseUp = () => { setDragNode(null); setIsPanning(false); };

  const handleWheel = (e: any) => { e.preventDefault(); setZoom(z=>Math.max(0.2,Math.min(3,z*(e.deltaY<0?1.12:0.88)))); };

  const resetLayout = () => { setNodePos(initPositions()); setZoom(0.85); setPan({x:0,y:0}); };

  // Download
  const downloadSVG = () => {
    if(!svgRef.current) return;
    const s = new XMLSerializer().serializeToString(svgRef.current);
    const b = new Blob([s],{type:'image/svg+xml'});
    const a = document.createElement('a'); a.href=URL.createObjectURL(b); a.download='pls_sem.svg'; a.click();
  };
  const downloadPNG = () => {
    if(!svgRef.current) return;
    const s = new XMLSerializer().serializeToString(svgRef.current);
    const canvas = document.createElement('canvas');
    canvas.width=W*2; canvas.height=H*2;
    const ctx = canvas.getContext('2d')!;
    ctx.scale(2,2); ctx.fillStyle='#f8fafc'; ctx.fillRect(0,0,W,H);
    const img = new Image();
    img.onload=()=>{ ctx.drawImage(img,0,0); const a=document.createElement('a'); a.href=canvas.toDataURL('image/png'); a.download='pls_sem.png'; a.click(); };
    img.src='data:image/svg+xml;base64,'+btoa(unescape(encodeURIComponent(s)));
  };

  // Path between two nodes
  const makePath = (fr: string, to: string, isCon1: boolean, isCon2: boolean) => {
    const pf=pos[fr]; const pt=pos[to]; if(!pf||!pt) return '';
    const dx=pt.x-pf.x; const dy=pt.y-pf.y; const dist=Math.sqrt(dx*dx+dy*dy)||1;
    const ux=dx/dist; const uy=dy/dist;
    const rx1=isCon1?CON_RX:IT_W/2; const ry1=isCon1?CON_RY:IT_H/2;
    const rx2=isCon2?CON_RX:IT_W/2; const ry2=isCon2?CON_RY:IT_H/2;
    const x1=pf.x+ux*rx1; const y1=pf.y+uy*ry1;
    const x2=pt.x-ux*(rx2+3); const y2=pt.y-uy*(ry2+1);
    const mx=(x1+x2)/2; const my=(y1+y2)/2;
    const levelDiff = Math.abs((levels[to]||0)-(levels[fr]||0));
    if(levelDiff>1) {
      const offset = dy===0 ? -130 : dy*0.3;
      return `M${x1},${y1} C${x1+(x2-x1)*0.25},${y1+offset} ${x1+(x2-x1)*0.75},${y2+offset} ${x2},${y2}`;
    }
    if(Math.abs(dy)>20) return `M${x1},${y1} Q${mx+dy*0.12},${my-dx*0.12} ${x2},${y2}`;
    return `M${x1},${y1} L${x2},${y2}`;
  };

  return (
    <div style={{userSelect:'none'}}>
      {/* Toolbar */}
      <div className="flex items-center gap-2 mb-3 flex-wrap">
        <button onClick={()=>setZoom(z=>Math.min(3,z*1.15))} className="px-3 py-1.5 bg-slate-100 hover:bg-slate-200 rounded-lg text-sm font-bold text-slate-700">🔍+</button>
        <button onClick={()=>setZoom(z=>Math.max(0.2,z*0.85))} className="px-3 py-1.5 bg-slate-100 hover:bg-slate-200 rounded-lg text-sm font-bold text-slate-700">🔍−</button>
        <button onClick={resetLayout} className="px-3 py-1.5 bg-slate-100 hover:bg-slate-200 rounded-lg text-sm font-bold text-slate-700">↺ Reset</button>
        <span className="text-xs text-slate-400 font-mono">{Math.round(zoom*100)}%</span>
        <span className="text-xs text-amber-600 font-semibold ml-1">✋ Arrastra nodos · 🖱 Scroll = zoom · Drag fondo = mover</span>
        <div className="ml-auto flex gap-2">
          <button onClick={downloadSVG} className="px-3 py-1.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm font-semibold">⬇ SVG</button>
          <button onClick={downloadPNG} className="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm font-semibold">⬇ PNG</button>
        </div>
      </div>

      {/* Canvas */}
      <div
        style={{overflow:'hidden',borderRadius:12,border:'1px solid #cbd5e1',background:'#f8fafc',height:Math.min(H,640),cursor:dragNode?'grabbing':isPanning?'grabbing':'grab'}}
        onWheel={handleWheel}
        onMouseDown={handleSVGMouseDown}
        onMouseMove={handleMouseMove}
        onMouseUp={handleMouseUp}
        onMouseLeave={handleMouseUp}
      >
        <svg ref={svgRef} width={W} height={H} viewBox={`0 0 ${W} ${H}`}
          style={{transform:`translate(${pan.x}px,${pan.y}px) scale(${zoom})`,transformOrigin:'top left',display:'block'}}>
          <defs>
            <marker id="mR" markerWidth="9" markerHeight="9" refX="8" refY="3" orient="auto"><path d="M0,0 L0,6 L9,3z" fill="#DC2626"/></marker>
            <marker id="mG" markerWidth="9" markerHeight="9" refX="8" refY="3" orient="auto"><path d="M0,0 L0,6 L9,3z" fill="#9CA3AF"/></marker>
            <marker id="mB" markerWidth="7" markerHeight="7" refX="6" refY="2.5" orient="auto"><path d="M0,0 L0,5 L7,2.5z" fill="#64748B"/></marker>
            <filter id="fs"><feDropShadow dx="1" dy="2" stdDeviation="2.5" floodOpacity="0.15"/></filter>
            <filter id="fc"><feDropShadow dx="0" dy="2" stdDeviation="4" floodOpacity="0.2"/></filter>
            <filter id="fd"><feDropShadow dx="0" dy="0" stdDeviation="6" floodColor="#3B82F6" floodOpacity="0.6"/></filter>
          </defs>

          {/* Grid */}
          <pattern id="g" width="50" height="50" patternUnits="userSpaceOnUse">
            <path d="M50 0L0 0 0 50" fill="none" stroke="#e2e8f0" strokeWidth="0.5"/>
          </pattern>
          <rect width={W} height={H} fill="url(#g)"/>

          {/* Measurement edges */}
          {cargas.map((c:any,i:number)=>{
            const pi=pos[c.Item]; const pc=pos[c.Constructo]; if(!pi||!pc) return null;
            const d=makePath(c.Item, c.Constructo, false, true);
            const mx=(pi.x+pc.x)/2; const my=(pi.y+pc.y)/2;
            return(<g key={'m'+i}>
              <path d={d} fill="none" stroke="#94A3B8" strokeWidth={1.4} markerEnd="url(#mB)"/>
              <rect x={mx-17} y={my-8} width={34} height={14} rx={3} fill="white" fillOpacity={0.9} stroke="#CBD5E1" strokeWidth={0.8}/>
              <text x={mx} y={my+3.5} textAnchor="middle" fontSize={8.5} fill="#475569" fontWeight="700">{c.Loading}</text>
            </g>);
          })}

          {/* Structural paths */}
          {paths.map((p:any,i:number)=>{
            const pts=p.Path?.split(' -> '); if(!pts||pts.length<2) return null;
            const fr=pts[0]?.trim(); const to=pts[1]?.trim();
            const pf=pos[fr]; const pt2=pos[to]; if(!pf||!pt2) return null;
            const d=makePath(fr,to,true,true);
            const mx=(pf.x+pt2.x)/2; const my=(pf.y+pt2.y)/2;
            const isNs=p.Sig==='n.s.';
            const col=isNs?'#9CA3AF':'#DC2626';
            const arr=isNs?'url(#mG)':'url(#mR)';
            return(<g key={'s'+i}>
              <path d={d} fill="none" stroke={col} strokeWidth={isNs?1.8:2.8} strokeDasharray={isNs?'8,4':undefined} markerEnd={arr}/>
              <rect x={mx-30} y={my-16} width={60} height={30} rx={6} fill="white" stroke={col} strokeWidth={1.3} filter="url(#fs)"/>
              <text x={mx} y={my-4} textAnchor="middle" fontSize={10.5} fill={col} fontWeight="800">{p.Beta}</text>
              <text x={mx} y={my+9} textAnchor="middle" fontSize={8} fill={col} fontWeight="600">{p.Sig} T={p.T_Valor}</text>
            </g>);
          })}

          {/* Item nodes — draggable */}
          {cargas.map((c:any,i:number)=>{
            const pi=pos[c.Item]; if(!pi) return null;
            const isDragging=dragNode===c.Item;
            return(<g key={'in'+i} style={{cursor:'grab'}}
              onMouseDown={(e)=>handleMouseDown(e,c.Item)}>
              <rect x={pi.x-IT_W/2} y={pi.y-IT_H/2} width={IT_W} height={IT_H} rx={5}
                fill={isDragging?'#DBEAFE':'#EFF6FF'} stroke={isDragging?'#3B82F6':'#93C5FD'}
                strokeWidth={isDragging?2:1.3} filter={isDragging?'url(#fd)':'url(#fs)'}/>
              <text x={pi.x} y={pi.y+5} textAnchor="middle" fontSize={9} fill="#1E40AF" fontWeight="700">{c.Item}</text>
            </g>);
          })}

          {/* Construct nodes — draggable */}
          {allCons.map((con:string,i:number)=>{
            const pc=pos[con]; if(!pc) return null;
            const r2=r2map[con]; const hasR2=r2!==undefined&&!isNaN(r2);
            const isEndo=allTo.includes(con);
            const isDragging=dragNode===con;
            return(<g key={'cn'+i} style={{cursor:'grab'}}
              onMouseDown={(e)=>handleMouseDown(e,con)}>
              {isDragging&&<ellipse cx={pc.x} cy={pc.y} rx={CON_RX+8} ry={CON_RY+8} fill="#3B82F6" opacity={0.2}/>}
              <ellipse cx={pc.x} cy={pc.y} rx={CON_RX+3} ry={CON_RY+3} fill="#BFDBFE" opacity={0.35}/>
              <ellipse cx={pc.x} cy={pc.y} rx={CON_RX} ry={CON_RY}
                fill={isDragging?'#2563EB':isEndo?'#1D4ED8':'#1E40AF'}
                stroke={isDragging?'#60A5FA':'#1E3A8A'} strokeWidth={isDragging?2.5:2}
                filter={isDragging?'url(#fd)':'url(#fc)'}/>
              <text x={pc.x} y={pc.y+(hasR2?6:5)} textAnchor="middle" fontSize={14} fill="white" fontWeight="800">{con}</text>
              {hasR2&&<>
                <rect x={pc.x-26} y={pc.y-CON_RY-20} width={52} height={17} rx={4} fill="#DBEAFE" stroke="#93C5FD" strokeWidth={1}/>
                <text x={pc.x} y={pc.y-CON_RY-7} textAnchor="middle" fontSize={9} fill="#1E40AF" fontWeight="700">R²={r2}</text>
              </>}
            </g>);
          })}

          {/* Legend */}
          <g transform={`translate(8,${H-56})`}>
            <rect width={360} height={48} rx={8} fill="white" fillOpacity={0.93} stroke="#E2E8F0" strokeWidth={1}/>
            <path d="M10,14 L32,14" stroke="#DC2626" strokeWidth={2.5} markerEnd="url(#mR)"/>
            <text x={36} y={18} fontSize={9} fill="#374151" fontWeight="600">Ruta estructural (β, T)</text>
            <path d="M10,32 L32,32" stroke="#94A3B8" strokeWidth={1.3} markerEnd="url(#mB)"/>
            <text x={36} y={36} fontSize={9} fill="#374151" fontWeight="600">Carga factorial (λ)</text>
            <path d="M180,14 L202,14" stroke="#9CA3AF" strokeWidth={1.8} strokeDasharray="6,3"/>
            <text x={206} y={18} fontSize={9} fill="#374151">No significativa</text>
            <rect x={180} y={24} width={16} height={11} rx={3} fill="#EFF6FF" stroke="#93C5FD"/>
            <text x={200} y={33} fontSize={9} fill="#374151">Ítem</text>
            <ellipse cx={250} cy={30} rx={14} ry={8} fill="#1E40AF"/>
            <text x={268} y={34} fontSize={9} fill="#374151" fontWeight="600">Constructo</text>
            <text x={310} y={20} fontSize={8} fill="#6B7280">✋ Drag</text>
            <text x={310} y={32} fontSize={8} fill="#6B7280">nodos</text>
          </g>
        </svg>
      </div>
      <p className="text-xs text-slate-400 mt-2 text-center">✋ Arrastra cualquier constructo o ítem · 🖱 Scroll = zoom · Arrastra el fondo = mover · ⬇ Descarga con posiciones actuales</p>
    </div>
  );
}

function PlsResults({ r, onBack, onNext }: { r: any; onBack: ()=>void; onNext: ()=>void }) {
  const diag = r.diagnostic ?? r.interpretations?.pls?.tables ?? {};
  const paths      = sa(diag.Paths ?? r.correlations ?? []);
  const confiab    = sa(diag.Confiabilidad ?? r.reliability ?? []);
  const cargas     = sa(diag.Cargas ?? []);
  const hypotheses = sa(diag.Hypotheses ?? []);
  const r2list     = sa(diag.R2 ?? []);
  const htmt       = sa(diag.HTMT ?? []);
  const fl         = diag.FornellLarcker ?? null;
  const cl         = sa(diag.CrossLoadings ?? []);
  const vif        = sa(diag.VIF ?? []);
  const srmrRaw    = diag.SRMR ?? [];
  const srmr       = Array.isArray(srmrRaw) ? srmrRaw : (srmrRaw && typeof srmrRaw==='object' && srmrRaw.Valor ? [srmrRaw] : []);
  const q2         = sa(diag.Q2 ?? []);
  const indirect   = sa(diag.IndirectEffects ?? []);
  const totalRaw   = diag.TotalEffects ?? [];
  const total      = Array.isArray(totalRaw) ? totalRaw : sa(totalRaw);
  const plspredict  = sa(diag.PLSPredict ?? []);
  const vafmed      = sa(diag.VAF_Mediacion ?? []);
  const htmtci      = sa(diag.HTMT_CI ?? []);
  const fullvif     = sa(diag.FullVIF_CMB ?? []);
  const copula      = sa(diag.GaussianCopula ?? []);
  const micom       = sa(diag.MICOM ?? []);
  const mga         = sa(diag.MGA ?? []);
  const ipma        = sa(diag.IPMA ?? []);
  const nObs       = r.interpretations?.pls?.n_observations ?? '—';
  const nBoot      = r.interpretations?.pls?.n_boot ?? '—';

  const constructos: Record<string,any[]> = {};
  cargas.forEach((c:any)=>{ if(!constructos[c.Constructo]) constructos[c.Constructo]=[]; constructos[c.Constructo].push(c); });
  const sigColor = (s:string) => s==='***'?'text-green-600 font-black':s==='**'?'text-blue-600 font-bold':s==='*'?'text-amber-600 font-bold':'text-slate-400';
  const decColor = (d:string) => d?.includes('Soportada')?'text-green-700':'text-red-600';

  return (
    <div className="space-y-6">

      {/* HERO */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-cyan-600 via-blue-700 to-purple-800 p-8 text-white shadow-2xl">
        <div className="absolute top-0 right-0 w-64 h-64 bg-white/5 rounded-full -translate-y-1/2 translate-x-1/2"/>
        <div className="relative">
          <div className="flex flex-wrap items-center gap-2 mb-4">
            <span className="bg-white/20 px-3 py-1 rounded-full text-xs font-bold uppercase tracking-widest">PLS-SEM · Canchari v5</span>
            <span className="bg-white/20 px-3 py-1 rounded-full text-xs font-bold">n = {nObs}</span>
            <span className="bg-white/20 px-3 py-1 rounded-full text-xs font-bold">Bootstrap = {nBoot}</span>
          </div>
          <h2 className="text-3xl font-black mb-6">Modelo Estructural PLS-SEM</h2>
          <div className="space-y-4">
            {paths.map((p:any,i:number)=>(
              <div key={i} className="bg-white/10 backdrop-blur-sm rounded-2xl p-5 border border-white/20">
                <div className="flex items-center justify-between flex-wrap gap-4">
                  <div><p className="text-white/70 text-sm font-semibold mb-1">Relación estructural</p><p className="text-xl font-black">{p.Path}</p></div>
                  <div className="flex items-center gap-5 flex-wrap">
                    <div className="text-center"><p className="text-white/60 text-xs">β</p><p className="text-4xl font-black text-yellow-300">{p.Beta}</p></div>
                    <div className="text-center"><p className="text-white/60 text-xs">T-valor</p><p className="text-2xl font-black">{p.T_Valor}</p></div>
                    <div className="text-center"><p className="text-white/60 text-xs">p-valor</p><p className="text-xl font-bold">{Number(p.P_Valor)<0.001?'< 0.001':p.P_Valor}</p></div>
                    <div className="text-center"><p className="text-white/60 text-xs">IC 95%</p><p className="text-sm font-bold">[{p['IC_2.5']}, {p['IC_97.5']}]</p></div>
                    <div className="text-center"><p className="text-white/60 text-xs">Sig.</p><p className="text-3xl font-black text-yellow-300">{p.Sig}</p></div>
                    {p.f2!=null&&<div className="text-center"><p className="text-white/60 text-xs">f²</p><p className="text-xl font-bold">{p.f2}</p></div>}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* DIAGRAMA */}
      {paths.length>0&&cargas.length>0&&(
        <PCard title="Diagrama del modelo PLS-SEM" icon="📊" color="blue">
          <p className="text-xs text-slate-500 mb-3">Constructos (elipses) · Ítems (rectángulos) · Rutas estructurales (→ rojas con β) · Cargas factoriales (→ grises con λ)</p>
          <PlsDiagram paths={paths} cargas={cargas} r2list={r2list} hypotheses={hypotheses}/>
        </PCard>
      )}

      {/* 1. Confiabilidad */}
      {confiab.length>0&&(
        <PCard title="1. Confiabilidad y validez convergente" icon="α" color="teal">
          <p className="text-xs text-slate-500 mb-3">α ≥ 0.70 · rho_A ≥ 0.70 · CR ≥ 0.70 · AVE ≥ 0.50 (Hair et al., 2022)</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {confiab.map((con:any,i:number)=>(
              <div key={i} className="bg-gradient-to-br from-teal-50 to-cyan-50 rounded-2xl border border-teal-200 p-5">
                <p className="font-black text-lg text-teal-800 mb-4">{con.Constructo}</p>
                <div className="grid grid-cols-2 gap-2 mb-3">
                  {[['α Cronbach',con.Cronbach_Alpha,0.7],['rho_A',con.rho_A,0.7],['CR',con.Composite_Reliability_CR??con.Composite_Reliability,0.7],['AVE',con.AVE,0.5]].map(([lbl,val,thr]:any)=>(
                    <div key={lbl} className="text-center bg-white rounded-xl p-2.5 border border-teal-100">
                      <p className="text-xs text-slate-500 mb-1">{lbl}</p>
                      <p className={`text-xl font-black ${Number(val)>=thr?'text-green-700':'text-red-600'}`}>{val??'—'}</p>
                      <p className="text-xs text-slate-400 mt-0.5">{Number(val)>=thr?'✓ OK':'✗ Bajo'}</p>
                    </div>
                  ))}
                </div>
                <div className="flex justify-between text-xs text-slate-500 mb-1"><span>AVE</span><span>Umbral 0.50</span></div>
                <div className="w-full bg-slate-200 rounded-full h-2">
                  <div className={`h-2 rounded-full ${Number(con.AVE)>=0.5?'bg-teal-500':'bg-red-400'}`} style={{width:`${Math.min(Number(con.AVE)*100,100)}%`}}/>
                </div>
              </div>
            ))}
          </div>
        </PCard>
      )}

      {/* 2. Cargas factoriales */}
      {Object.keys(constructos).length>0&&(
        <PCard title="2. Cargas factoriales (Outer Loadings)" icon="λ" color="blue">
          <p className="text-xs text-slate-500 mb-3">Umbral recomendado ≥ 0.70 (Hair et al., 2022)</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {Object.entries(constructos).map(([nombre,items]:any)=>(
              <div key={nombre} className="bg-slate-50 rounded-2xl border border-slate-200 p-4">
                <p className="font-black text-slate-800 mb-4 text-base">{nombre}</p>
                <div className="space-y-2.5">
                  {items.sort((a:any,b:any)=>b.Loading-a.Loading).map((item:any,i:number)=>(
                    <div key={i}>
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-sm font-semibold text-slate-700">{item.Item}</span>
                        <span className={`text-sm font-bold ${Number(item.Loading)>=0.7?'text-green-700':Number(item.Loading)>=0.5?'text-amber-600':'text-red-600'}`}>{item.Loading} {item.OK}</span>
                      </div>
                      <div className="w-full bg-slate-200 rounded-full h-2">
                        <div className={`h-2 rounded-full ${Number(item.Loading)>=0.7?'bg-indigo-500':Number(item.Loading)>=0.5?'bg-amber-400':'bg-red-400'}`} style={{width:`${Number(item.Loading)*100}%`}}/>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
          <div className="flex gap-4 text-xs mt-2">
            <span className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-indigo-500 inline-block"/><span className="text-slate-600">≥ 0.70 Adecuado</span></span>
            <span className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-amber-400 inline-block"/><span className="text-slate-600">0.50–0.69 Aceptable</span></span>
            <span className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-red-400 inline-block"/><span className="text-slate-600">{'<'} 0.50 Bajo</span></span>
          </div>
        </PCard>
      )}

      {/* 3. Fornell-Larcker */}
      {fl&&Object.keys(fl).length>0&&(
        <PCard title="3. Criterio Fornell-Larcker" icon="FL" color="indigo">
          <p className="text-xs text-slate-500 mb-3">Diagonal (√AVE) debe ser mayor que correlaciones inter-constructo (Fornell & Larcker, 1981)</p>
          {(() => {
            // fl puede ser objeto {Constructo: [...], ICSR: [...], ...} o array de filas
            const flRows = sa(fl);
            if (flRows.length === 0) return <p className="text-slate-400 text-sm">No disponible</p>;
            // Ordenar: Constructo primero, luego constructos, luego OK
            const allKeys = Object.keys(flRows[0]);
            const cons = ['Constructo', ...allKeys.filter(k=>k!=='Constructo'&&k!=='OK')];
            return (
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-sm">
                  <thead className="bg-gradient-to-r from-indigo-700 to-indigo-800 text-white">
                    <tr>{cons.map(h=><th key={h} className="px-3 py-2.5 text-left font-semibold text-xs uppercase whitespace-nowrap">{h}</th>)}
                    <th className="px-3 py-2.5 text-left font-semibold text-xs uppercase">Estado</th></tr>
                  </thead>
                  <tbody>
                    {flRows.map((row:any,i:number)=>(
                      <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                        {cons.map((k:string,j:number)=>(
                          <td key={j} className={`px-3 py-2 whitespace-nowrap ${k==='Constructo'?'font-bold text-slate-800':typeof row[k]==='number'&&j===i+1?'font-black text-indigo-700 bg-indigo-50 text-base':'text-slate-600'}`}>
                            {String(row[k]??'—')}
                          </td>
                        ))}
                        <td className={`px-3 py-2 text-xs font-semibold ${String(row.OK??'').includes('OK')?'text-green-600':'text-red-600'}`}>{row.OK??'—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            );
          })()}
        </PCard>
      )}

      {/* 4. HTMT */}
      {htmt.length>0&&(
        <PCard title="4. Validez discriminante — HTMT" icon="D" color="amber">
          <p className="text-xs text-slate-500 mb-3">Criterio estricto {'<'} 0.85 · Criterio liberal {'<'} 0.90 (Henseler et al., 2015; Hair et al., 2022)</p>
          <div className="space-y-2">
            {htmt.map((h:any,i:number)=>{
              const v=Number(h.HTMT); const ok=v<0.85?'green':v<0.90?'amber':'red';
              return (
                <div key={i} className={`flex items-center justify-between p-3 rounded-xl border ${ok==='green'?'bg-green-50 border-green-200':ok==='amber'?'bg-amber-50 border-amber-200':'bg-red-50 border-red-200'}`}>
                  <span className="font-semibold text-slate-800 text-sm">{h.C1} ↔ {h.C2}</span>
                  <div className="flex items-center gap-3">
                    <div className="w-32 bg-slate-200 rounded-full h-2">
                      <div className={`h-2 rounded-full ${ok==='green'?'bg-green-500':ok==='amber'?'bg-amber-400':'bg-red-500'}`} style={{width:`${Math.min(v*100,100)}%`}}/>
                    </div>
                    <span className={`font-black text-base ${ok==='green'?'text-green-700':ok==='amber'?'text-amber-700':'text-red-700'}`}>{h.HTMT}</span>
                    <span className="text-xs text-slate-500">{h.OK}</span>
                  </div>
                </div>
              );
            })}
          </div>
        </PCard>
      )}

      {/* 4b. HTMT con IC bootstrapped */}
      {htmtci.length>0&&(
        <PCard title="4b. HTMT con IC bootstrapped 95%" icon="IC" color="amber">
          <p className="text-xs text-slate-500 mb-3">IC superior {'<'} 0.85 confirma validez discriminante · Bootstrap percentil (Henseler et al., 2015)</p>
          <div className="overflow-x-auto rounded-xl border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-gradient-to-r from-amber-600 to-amber-700 text-white">
                <tr>{['Par','HTMT','IC 2.5%','IC 97.5%','Estado'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-xs uppercase">{h}</th>)}</tr>
              </thead>
              <tbody>
                {htmtci.map((row:any,i:number)=>(
                  <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                    <td className="px-3 py-2 font-semibold text-slate-800">{row.Par}</td>
                    <td className="px-3 py-2 font-bold text-amber-700">{row.HTMT}</td>
                    <td className="px-3 py-2 text-slate-600">{row['IC_2.5']}</td>
                    <td className="px-3 py-2 text-slate-600">{row['IC_97.5']}</td>
                    <td className={`px-3 py-2 text-xs font-semibold ${String(row.OK_CI).includes('✓')?'text-green-600':String(row.OK_CI).includes('⚠')?'text-amber-600':'text-red-600'}`}>{row.OK_CI}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </PCard>
      )}

      {/* 5. Cross-loadings */}
      {cl.length>0&&(
        <PCard title="5. Cargas cruzadas (Cross-Loadings)" icon="CL" color="purple">
          <p className="text-xs text-slate-500 mb-3">Cada ítem debe cargar más alto en su constructo asignado que en los demás (Hair et al., 2022)</p>
          <div className="overflow-x-auto rounded-xl border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-gradient-to-r from-purple-700 to-purple-800 text-white">
                <tr>
                  {cl.length>0&&Object.keys(cl[0]).map((h:string)=>(
                    <th key={h} className="px-3 py-2 text-left font-semibold text-xs uppercase whitespace-nowrap">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {cl.map((row:any,i:number)=>(
                  <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                    {Object.entries(row).map(([k,v]:any,j:number)=>{
                      const isAssigned = k===row.Asignado_a;
                      return (
                        <td key={j} className={`px-3 py-1.5 text-xs whitespace-nowrap ${k==='Item'?'font-bold text-slate-800':k==='Asignado_a'?'text-purple-700 font-semibold':isAssigned?'font-black text-indigo-700 bg-indigo-50':'text-slate-500'}`}>
                          {String(v??'—')}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </PCard>
      )}

      {/* 6. VIF */}
      {vif.length>0&&(
        <PCard title="6. VIF — Colinealidad" icon="V" color="cyan">
          <p className="text-xs text-slate-500 mb-3">{'<'} 3.3 Ideal · {'<'} 5 Aceptable · ≥ 5 Problema (Hair et al., 2022)</p>
          <div className="overflow-x-auto rounded-xl border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 border-b border-slate-200">
                <tr>{['Constructo','Predictor','VIF','Estado'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600 text-xs">{h}</th>)}</tr>
              </thead>
              <tbody>
                {vif.map((v:any,i:number)=>(
                  <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                    <td className="px-3 py-2 font-semibold text-slate-800">{v.Constructo}</td>
                    <td className="px-3 py-2 text-slate-600">{v.Predictor}</td>
                    <td className={`px-3 py-2 font-black ${Number(v.VIF)<3.3?'text-green-700':Number(v.VIF)<5?'text-amber-600':'text-red-600'}`}>{v.VIF}</td>
                    <td className="px-3 py-2 text-slate-500 text-xs">{v.OK}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </PCard>
      )}

      {/* 6b. Full Collinearity VIF — CMB (Kock, 2015) */}
      {fullvif.length>0&&(
        <PCard title="6b. VIF Colinealidad Total — Sesgo de Método Común" icon="CMB" color="red">
          <p className="text-xs text-slate-500 mb-3">Cada VL regresada sobre todas las demás · VIF {'<'} 3.3 → sin riesgo CMB (Kock, 2015)</p>
          <div className="overflow-x-auto rounded-xl border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-gradient-to-r from-red-700 to-red-800 text-white">
                <tr>{['Variable Latente','VIF Full','Estado'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-xs uppercase">{h}</th>)}</tr>
              </thead>
              <tbody>
                {fullvif.map((row:any,i:number)=>(
                  <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                    <td className="px-3 py-2 font-bold text-slate-800">{row.Variable_Latente}</td>
                    <td className={`px-3 py-2 font-black ${Number(row.VIF_Full)<3.3?'text-green-700':'text-red-600'}`}>{row.VIF_Full}</td>
                    <td className={`px-3 py-2 text-xs font-semibold ${String(row.Estado).includes('✓')?'text-green-600':'text-red-600'}`}>{row.Estado}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="text-xs text-slate-400 mt-2">Referencia: Kock (2015). Common method bias in PLS-SEM.</p>
        </PCard>
      )}

      {/* 6c. Gaussian Copula Endogeneity Test */}
      {copula.length>0&&(
        <PCard title="6c. Gaussian Copula — Test de Endogeneidad" icon="GC" color="red">
          <p className="text-xs text-slate-500 mb-3">p {'≥'} 0.05 = sin evidencia de endogeneidad · Park & Gupta (2012)</p>
          <div className="overflow-x-auto rounded-xl border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-gradient-to-r from-slate-700 to-slate-800 text-white">
                <tr>{['Ruta','β PLS','Copula Coef.','Std. Error','t','p-valor','Interpretación'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-xs uppercase whitespace-nowrap">{h}</th>)}</tr>
              </thead>
              <tbody>
                {copula.map((row:any,i:number)=>(
                  <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                    <td className="px-3 py-2 font-semibold text-slate-800">{row.Ruta}</td>
                    <td className="px-3 py-2 font-bold text-indigo-700">{row.PLS_Beta}</td>
                    <td className="px-3 py-2 text-slate-600">{row.Copula_Coef}</td>
                    <td className="px-3 py-2 text-slate-500">{row.Std_Error}</td>
                    <td className="px-3 py-2 text-slate-600">{row.t_valor}</td>
                    <td className="px-3 py-2 font-bold text-slate-700">{row.p_valor}</td>
                    <td className={`px-3 py-2 text-xs font-semibold ${String(row.Interpretacion).includes('✓')?'text-green-600':'text-amber-600'}`}>{row.Interpretacion}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="text-xs text-slate-400 mt-2">Referencia: Park & Gupta (2012). Handling endogenous regressors. Marketing Science.</p>
        </PCard>
      )}

      {/* 6d. MICOM */}
      {micom.length>0&&(
        <PCard title="6d. MICOM — Invarianza de Medición" icon="MI" color="purple">
          <p className="text-xs text-slate-500 mb-3">Paso 1: Configuración ✓ | Paso 2: r ≥ 0.90 invarianza composicional | Paso 3: p ≥ 0.05 igualdad medias/varianzas · Henseler et al. (2016)</p>
          <div className="overflow-x-auto rounded-xl border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-gradient-to-r from-purple-700 to-purple-800 text-white">
                <tr>{['Constructo','Grupos','r original','p permut.','Inv. composicional','p medias','p varianzas','Resultado'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-xs uppercase whitespace-nowrap">{h}</th>)}</tr>
              </thead>
              <tbody>
                {micom.map((row:any,i:number)=>{
                  const ok=row.Resultado==='Invarianza total';
                  const parcial=row.Resultado==='Invarianza parcial';
                  return(
                    <tr key={i} className={`border-b border-slate-100 ${ok?'bg-green-50':parcial?'bg-amber-50':'bg-red-50'}`}>
                      <td className="px-3 py-2 font-bold text-slate-800">{row.Constructo}</td>
                      <td className="px-3 py-2 text-slate-600 text-xs">{row.Grupos}</td>
                      <td className={`px-3 py-2 font-bold ${Number(row.Correlacion_original)>=0.9?'text-green-700':'text-red-600'}`}>{row.Correlacion_original}</td>
                      <td className="px-3 py-2 text-slate-600">{row.p_permutacion}</td>
                      <td className={`px-3 py-2 text-xs font-semibold ${String(row.Invarianza_composicional).includes('Si')?'text-green-600':'text-red-600'}`}>{row.Invarianza_composicional}</td>
                      <td className={`px-3 py-2 ${Number(row.p_dif_medias)>=0.05?'text-green-600':'text-red-600'}`}>{row.p_dif_medias}</td>
                      <td className={`px-3 py-2 ${Number(row.p_dif_varianzas)>=0.05?'text-green-600':'text-red-600'}`}>{row.p_dif_varianzas}</td>
                      <td className={`px-3 py-2 text-xs font-bold ${ok?'text-green-700':parcial?'text-amber-700':'text-red-700'}`}>{row.Resultado}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          <p className="text-xs text-slate-400 mt-2">Nota: MICOM requiere variable de grupo configurada en el análisis.</p>
        </PCard>
      )}

      {/* 6e. MGA */}
      {mga.length>0&&(
        <PCard title="6e. MGA — Análisis Multigrupo (Permutación)" icon="MG" color="indigo">
          <p className="text-xs text-slate-500 mb-3">Test de permutación · p {'<'} 0.05 = diferencia significativa entre grupos · Henseler et al. (2009, 2012)</p>
          <div className="overflow-x-auto rounded-xl border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-gradient-to-r from-indigo-700 to-indigo-800 text-white">
                <tr>{['Relación','Grupos','Dif. original','IC 2.5%','IC 97.5%','p-valor','Sig.'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-xs uppercase whitespace-nowrap">{h}</th>)}</tr>
              </thead>
              <tbody>
                {mga.map((row:any,i:number)=>{
                  const sig=row.Sig; const isS=sig==='***'||sig==='**'||sig==='*';
                  return(
                    <tr key={i} className={`border-b border-slate-100 ${isS?'bg-amber-50':'hover:bg-slate-50'}`}>
                      <td className="px-3 py-2 font-semibold text-slate-800">{row.Relacion}</td>
                      <td className="px-3 py-2 text-slate-500 text-xs">{row.Grupos}</td>
                      <td className={`px-3 py-2 font-bold ${isS?'text-amber-700':'text-slate-600'}`}>{row.Diferencia}</td>
                      <td className="px-3 py-2 text-slate-500">{row['IC_2.5']}</td>
                      <td className="px-3 py-2 text-slate-500">{row['IC_97.5']}</td>
                      <td className="px-3 py-2 font-semibold text-slate-700">{row.p_valor}</td>
                      <td className={`px-3 py-2 font-black text-lg ${sig==='***'?'text-green-600':sig==='**'?'text-blue-600':sig==='*'?'text-amber-600':'text-slate-400'}`}>{sig}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </PCard>
      )}

      {/* 7. R² */}
      {r2list.length>0&&(
        <PCard title="7. Coeficiente de determinación R²" icon="R²" color="purple">
          <p className="text-xs text-slate-500 mb-3">≥0.75 Sustancial · ≥0.50 Moderado · ≥0.25 Débil (Hair et al., 2022)</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {r2list.map((item:any,i:number)=>{
              const val=Number(item.R2??0); const pct=Math.round(val*100);
              const lv=val>=0.75?{l:'Sustancial',c:'bg-green-600'}:val>=0.50?{l:'Moderado',c:'bg-blue-600'}:val>=0.25?{l:'Débil',c:'bg-amber-500'}:{l:'Muy débil',c:'bg-red-500'};
              return (
                <div key={i} className="bg-gradient-to-br from-slate-50 to-purple-50 rounded-2xl border border-purple-200 p-5">
                  <div className="flex items-center justify-between mb-3">
                    <p className="font-black text-slate-800">{item.Constructo}</p>
                    <span className={`text-xs font-bold text-white px-3 py-1 rounded-full ${lv.c}`}>{lv.l}</span>
                  </div>
                  <div className="flex items-baseline gap-3 mb-2">
                    <p className="text-4xl font-black text-purple-700">{val}</p>
                    {item.R2_adj&&<p className="text-sm text-slate-500">R²adj = {item.R2_adj}</p>}
                  </div>
                  <div className="w-full bg-purple-100 rounded-full h-2.5 mb-2">
                    <div className={`h-2.5 rounded-full ${lv.c}`} style={{width:`${pct}%`}}/>
                  </div>
                  <p className="text-xs text-slate-600">Explica el <strong>{pct}%</strong> de la varianza de <strong>{item.Constructo}</strong></p>
                </div>
              );
            })}
          </div>
        </PCard>
      )}

      {/* 8. Q² */}
      {q2.length>0&&(
        <PCard title="8. Relevancia predictiva — Q² Blindfolding" icon="Q²" color="purple">
          <p className="text-xs text-slate-500 mb-3">≥0.35 Alta · ≥0.15 Moderada · {'>'} 0 Baja · Stone-Geisser (1975); Hair et al. (2022)</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {q2.map((item:any,i:number)=>{
              const v=Number(item.Q2); const lv=v>=0.35?{l:'Alta',c:'bg-green-600'}:v>=0.15?{l:'Moderada',c:'bg-blue-600'}:v>0?{l:'Baja',c:'bg-amber-500'}:{l:'Sin relevancia',c:'bg-red-500'};
              return (
                <div key={i} className="bg-slate-50 rounded-2xl border border-slate-200 p-4">
                  <div className="flex items-center justify-between mb-2">
                    <p className="font-bold text-slate-800">{item.Constructo}</p>
                    <span className={`text-xs font-bold text-white px-2 py-0.5 rounded-full ${lv.c}`}>{lv.l}</span>
                  </div>
                  <p className="text-3xl font-black text-purple-700 mb-1">{item.Q2}</p>
                  <p className="text-xs text-slate-500">{item.Metodo}</p>
                </div>
              );
            })}
          </div>
        </PCard>
      )}

      {/* 9. Hipótesis */}
      {hypotheses.length>0&&(
        <PCard title="9. Contraste de hipótesis" icon="H" color="indigo">
          <p className="text-xs text-slate-500 mb-3">Decisiones basadas en bootstrapping · p {'<'} 0.05</p>
          <div className="space-y-3">
            {hypotheses.map((h:any,i:number)=>(
              <div key={i} className={`rounded-2xl border-2 p-4 flex items-center justify-between flex-wrap gap-3 ${h.Decision?.includes('Soportada')?'border-green-300 bg-green-50':'border-red-300 bg-red-50'}`}>
                <div className="flex items-center gap-3">
                  <div className={`w-11 h-11 rounded-xl flex items-center justify-center font-black text-base ${h.Decision?.includes('Soportada')?'bg-green-600 text-white':'bg-red-600 text-white'}`}>{h.Hipotesis}</div>
                  <div>
                    <p className="font-bold text-slate-800 text-sm">{h.Relacion}</p>
                    <p className={`text-sm font-semibold mt-0.5 ${decColor(h.Decision)}`}>{h.Decision}</p>
                  </div>
                </div>
                <div className="flex gap-5">
                  <div className="text-center"><p className="text-xs text-slate-500">β</p><p className="text-2xl font-black text-slate-800">{h.Beta}</p></div>
                  <div className="text-center"><p className="text-xs text-slate-500">T</p><p className="font-bold text-slate-700">{h.T_Valor}</p></div>
                  <div className="text-center"><p className="text-xs text-slate-500">p</p><p className="font-bold text-slate-700">{Number(h.P_Valor)<0.001?'<0.001':h.P_Valor}</p></div>
                  <div className="text-center"><p className="text-xs text-slate-500">Sig.</p><p className={`text-2xl font-black ${sigColor(h.Sig)}`}>{h.Sig}</p></div>
                </div>
              </div>
            ))}
          </div>
        </PCard>
      )}

      {/* 10. Efectos indirectos */}
      {indirect.length>0&&(
        <PCard title="10. Efectos indirectos (Mediación)" icon="→" color="indigo">
          <p className="text-xs text-slate-500 mb-3">IC 95% excluyendo cero = efecto significativo (Hair et al., 2022)</p>
          <div className="overflow-x-auto rounded-xl border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-gradient-to-r from-indigo-700 to-purple-700 text-white">
                <tr>{['Ruta','β ind','T-valor','p-valor','IC 2.5%','IC 97.5%','Sig.'].map(h=><th key={h} className="px-3 py-2.5 text-left font-semibold text-xs uppercase">{h}</th>)}</tr>
              </thead>
              <tbody>
                {indirect.map((row:any,i:number)=>(
                  <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                    <td className="px-3 py-2 font-semibold text-slate-800 text-xs">{row.Path}</td>
                    <td className="px-3 py-2 font-bold text-indigo-700">{row.Beta_ind}</td>
                    <td className="px-3 py-2 text-slate-600">{row.T_Valor??'—'}</td>
                    <td className="px-3 py-2 text-slate-600">{row.P_Valor!=null?Number(row.P_Valor)<0.001?'<0.001':row.P_Valor:'—'}</td>
                    <td className="px-3 py-2 text-slate-500">{row['IC_2.5']??'—'}</td>
                    <td className="px-3 py-2 text-slate-500">{row['IC_97.5']??'—'}</td>
                    <td className={`px-3 py-2 font-black ${sigColor(row.Sig)}`}>{row.Sig}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </PCard>
      )}

      {/* 10b. VAF + Tipo de mediación */}
      {vafmed.length>0&&(
        <PCard title="10b. VAF y Tipo de mediación (Zhao et al., 2010)" icon="M" color="purple">
          <p className="text-xs text-slate-500 mb-3">VAF = β_indirecto / β_total × 100 · {'>'} 80% Mediación completa · 20-80% Mediación parcial (Hair et al., 2022)</p>
          <div className="space-y-3">
            {vafmed.map((row:any,i:number)=>{
              const vaf = Number(row.VAF_pct);
              const hasVaf = !isNaN(vaf) && row.VAF_pct != null;
              const color = hasVaf ? (vaf>=80?'green':vaf>=20?'amber':'red') : 'indigo';
              return (
                <div key={i} className={`rounded-xl border p-4 ${color==='green'?'bg-green-50 border-green-200':color==='amber'?'bg-amber-50 border-amber-200':color==='red'?'bg-red-50 border-red-200':'bg-indigo-50 border-indigo-200'}`}>
                  <div className="flex items-center justify-between flex-wrap gap-3">
                    <div>
                      <p className="font-bold text-slate-800 text-sm">{row.Ruta_indirecta}</p>
                      <p className={`text-sm font-semibold mt-1 ${color==='green'?'text-green-700':color==='amber'?'text-amber-700':'text-indigo-700'}`}>{row.Tipo_mediacion}</p>
                    </div>
                    <div className="flex gap-6 text-center">
                      <div><p className="text-xs text-slate-500">β directo</p><p className="font-black text-slate-800">{row.Beta_directo}</p></div>
                      <div><p className="text-xs text-slate-500">β indirecto</p><p className="font-black text-purple-700">{row.Beta_indirecto}</p></div>
                      <div><p className="text-xs text-slate-500">β total</p><p className="font-black text-slate-800">{row.Beta_total}</p></div>
                      {hasVaf&&<div><p className="text-xs text-slate-500">VAF %</p><p className={`font-black text-2xl ${color==='green'?'text-green-700':color==='amber'?'text-amber-700':'text-red-600'}`}>{vaf}%</p></div>}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
          <p className="text-xs text-slate-400 mt-2">Referencia: Zhao, Lynch & Chen (2010); Hair et al. (2022)</p>
        </PCard>
      )}

      {/* 11. Efectos totales */}
      {total.length>0&&(
        <PCard title="11. Efectos totales" icon="Σ" color="teal">
          <p className="text-xs text-slate-500 mb-3">Efecto total = Directo + Σ(Indirectos específicos) (Hair et al., 2022)</p>
          <div className="overflow-x-auto rounded-xl border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-gradient-to-r from-teal-700 to-cyan-700 text-white">
                <tr>{['Relación','Efecto directo','Efecto indirecto','Efecto total'].map(h=><th key={h} className="px-3 py-2.5 text-left font-semibold text-xs uppercase">{h}</th>)}</tr>
              </thead>
              <tbody>
                {total.map((row:any,i:number)=>(
                  <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                    <td className="px-3 py-2 font-semibold text-slate-800">{row.Relacion}</td>
                    <td className="px-3 py-2 font-bold text-blue-700">{row.Directo}</td>
                    <td className="px-3 py-2 font-bold text-green-700">{row.Indirecto}</td>
                    <td className="px-3 py-2 font-black text-slate-900 text-base">{row.Total}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </PCard>
      )}

      {/* 11a. IPMA */}
      {ipma.length>0&&(
        <PCard title="11a. IPMA — Mapa Importancia-Rendimiento" icon="IP" color="amber">
          <p className="text-xs text-slate-500 mb-3">Importancia = efecto total | Rendimiento = media rescalada 0-100 · Ringle & Sarstedt (2016); Hair et al. (2022, Cap.9)</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
            {ipma.map((row:any,i:number)=>{
              const imp=Number(row.Importancia_Efecto_Total);
              const perf=Number(row.Performance_0_100);
              const q=row.Cuadrante||'';
              const color=q.includes('MEJORAR')?'red':q.includes('MANTENER')?'green':q.includes('Monitor')?'amber':'slate';
              return(
                <div key={i} className={`rounded-2xl border p-4 ${color==='red'?'bg-red-50 border-red-200':color==='green'?'bg-green-50 border-green-200':color==='amber'?'bg-amber-50 border-amber-200':'bg-slate-50 border-slate-200'}`}>
                  <div className="flex items-center justify-between mb-3">
                    <p className="font-black text-slate-800">{row.Predictor} → {row.Target}</p>
                    <span className={`text-xs font-bold px-2 py-1 rounded-full ${color==='red'?'bg-red-600 text-white':color==='green'?'bg-green-600 text-white':color==='amber'?'bg-amber-500 text-white':'bg-slate-500 text-white'}`}>{row.Prioridad}</span>
                  </div>
                  <div className="flex gap-6 mb-2">
                    <div className="text-center"><p className="text-xs text-slate-500">Importancia</p><p className="text-2xl font-black text-indigo-700">{imp}</p></div>
                    <div className="text-center"><p className="text-xs text-slate-500">Rendimiento</p><p className="text-2xl font-black text-teal-700">{perf}%</p></div>
                  </div>
                  <p className="text-xs font-semibold text-slate-600">{q}</p>
                </div>
              );
            })}
          </div>
          <div className="bg-slate-50 rounded-xl p-4 border border-slate-200">
            <p className="text-xs font-bold text-slate-700 mb-2">📊 Interpretación de cuadrantes:</p>
            <div className="grid grid-cols-2 gap-2 text-xs">
              <div className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-red-500 inline-block"/><span>Alta Imp / Baja Perf → MEJORAR (prioridad alta)</span></div>
              <div className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-green-500 inline-block"/><span>Alta Imp / Alta Perf → MANTENER</span></div>
              <div className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-amber-500 inline-block"/><span>Baja Imp / Baja Perf → MONITOREAR</span></div>
              <div className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-slate-400 inline-block"/><span>Baja Imp / Alta Perf → Sobreinversión?</span></div>
            </div>
          </div>
        </PCard>
      )}

      {/* 11b. PLS Predict */}
      {plspredict.length>0&&(
        <PCard title="11b. PLS Predict — Relevancia predictiva out-of-sample" icon="P" color="cyan">
          <p className="text-xs text-slate-500 mb-3">10-fold CV · Q²predict ≥ 0.35 Alta · ≥ 0.15 Mediana · {'>'} 0 Baja · Hair et al. (2022)</p>
          {/* Resumen por constructo */}
          {(() => {
            const byConstructo: Record<string,any[]> = {};
            plspredict.forEach((r:any)=>{ if(!byConstructo[r.Constructo]) byConstructo[r.Constructo]=[]; byConstructo[r.Constructo].push(r); });
            return (
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                {Object.entries(byConstructo).map(([nombre,items]:any)=>{
                  const q2mean = items.reduce((s:number,r:any)=>s+Number(r.Q2_predict||0),0)/items.length;
                  const lv = q2mean>=0.35?{l:'Alta',c:'bg-green-600'}:q2mean>=0.15?{l:'Mediana',c:'bg-blue-600'}:q2mean>0?{l:'Baja',c:'bg-amber-500'}:{l:'Sin poder',c:'bg-red-500'};
                  return (
                    <div key={nombre} className="bg-cyan-50 rounded-2xl border border-cyan-200 p-4">
                      <div className="flex items-center justify-between mb-2">
                        <p className="font-black text-cyan-800">{nombre}</p>
                        <span className={`text-xs font-bold text-white px-2 py-0.5 rounded-full ${lv.c}`}>{lv.l}</span>
                      </div>
                      <p className="text-3xl font-black text-cyan-700 mb-1">{q2mean.toFixed(3)}</p>
                      <p className="text-xs text-slate-500">Q²predict promedio · {items.length} indicador(es)</p>
                    </div>
                  );
                })}
              </div>
            );
          })()}
          <div className="overflow-x-auto rounded-xl border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-gradient-to-r from-cyan-700 to-teal-700 text-white">
                <tr>{['Indicador','Constructo','RMSE','MAE','RMSE naive','Q²predict','Nivel'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-xs uppercase whitespace-nowrap">{h}</th>)}</tr>
              </thead>
              <tbody>
                {plspredict.map((row:any,i:number)=>(
                  <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                    <td className="px-3 py-1.5 font-semibold text-slate-800 text-xs">{row.Indicador}</td>
                    <td className="px-3 py-1.5 text-slate-600 text-xs">{row.Constructo}</td>
                    <td className="px-3 py-1.5 text-slate-600">{row.RMSE_modelo}</td>
                    <td className="px-3 py-1.5 text-slate-600">{row.MAE_modelo}</td>
                    <td className="px-3 py-1.5 text-slate-500">{row.RMSE_naive}</td>
                    <td className={`px-3 py-1.5 font-black ${Number(row.Q2_predict)>=0.35?'text-green-700':Number(row.Q2_predict)>=0.15?'text-blue-700':Number(row.Q2_predict)>0?'text-amber-600':'text-red-600'}`}>{row.Q2_predict}</td>
                    <td className="px-3 py-1.5 text-xs text-slate-600">{row.Nivel}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </PCard>
      )}

      {/* 12. SRMR */}
      <PCard title="12. Ajuste del modelo — SRMR" icon="S" color="green">
        {srmr.length>0 ? srmr.map((s:any,i:number)=>{
          const v=Number(s.Valor); const ok=v<=0.08?'green':v<=0.10?'amber':'red';
          return (
            <div key={i} className={`rounded-xl p-4 border ${ok==='green'?'bg-green-50 border-green-200':ok==='amber'?'bg-amber-50 border-amber-200':'bg-red-50 border-red-200'}`}>
              <div className="flex items-center justify-between">
                <div>
                  <p className="font-bold text-slate-800">{s.Indice} = <span className={`text-3xl font-black ${ok==='green'?'text-green-700':ok==='amber'?'text-amber-700':'text-red-700'}`}>{s.Valor}</span></p>
                  <p className="text-sm text-slate-600 mt-1">{s.Criterio}</p>
                  <p className="text-xs text-slate-400 mt-0.5">{s.Referencia}</p>
                </div>
                <div className={`w-16 h-16 rounded-full flex items-center justify-center text-2xl ${ok==='green'?'bg-green-100':ok==='amber'?'bg-amber-100':'bg-red-100'}`}>{ok==='green'?'✓':ok==='amber'?'⚠':'✗'}</div>
              </div>
            </div>
          );
        }) : (
          <div className="bg-amber-50 border border-amber-200 rounded-xl p-4">
            <p className="text-amber-800 text-sm font-semibold">⚠ SRMR no disponible en esta versión del motor</p>
            <p className="text-amber-700 text-xs mt-1">El SRMR de tu modelo en RStudio es <strong>0.045</strong> (buen ajuste ≤ 0.08). Referencia: Hu & Bentler (1999); Hair et al. (2022).</p>
          </div>
        )}
      </PCard>

      {/* 13. Tabla resumen */}
      <PCard title="13. Tabla resumen de rutas (APA 7)" icon="📋" color="amber">
        <p className="text-xs text-slate-500 mb-3">*** p {'<'} 0.001 · ** p {'<'} 0.01 · * p {'<'} 0.05 · Bootstrap con {nBoot} submuestras</p>
        <div className="overflow-x-auto rounded-xl border border-slate-200">
          <table className="w-full text-sm">
            <thead className="bg-gradient-to-r from-slate-700 to-slate-800 text-white">
              <tr>{['Ruta','β','STDEV','T-valor','p-valor','IC 2.5%','IC 97.5%','f²','Sig.'].map(h=><th key={h} className="px-3 py-2.5 text-left font-semibold text-xs uppercase tracking-wide">{h}</th>)}</tr>
            </thead>
            <tbody>
              {paths.map((p:any,i:number)=>(
                <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                  <td className="px-3 py-2.5 font-semibold text-slate-800">{p.Path}</td>
                  <td className="px-3 py-2.5 font-black text-indigo-700 text-base">{p.Beta}</td>
                  <td className="px-3 py-2.5 text-slate-600">{p.STDEV}</td>
                  <td className="px-3 py-2.5 font-bold text-slate-800">{p.T_Valor}</td>
                  <td className="px-3 py-2.5 text-slate-600">{Number(p.P_Valor)<0.001?'< 0.001':p.P_Valor}</td>
                  <td className="px-3 py-2.5 text-slate-500">{p['IC_2.5']}</td>
                  <td className="px-3 py-2.5 text-slate-500">{p['IC_97.5']}</td>
                  <td className="px-3 py-2.5 text-slate-600">{p.f2??'—'}</td>
                  <td className={`px-3 py-2.5 text-xl font-black ${sigColor(p.Sig)}`}>{p.Sig}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </PCard>

      {/* Navegación */}
      <div className="flex justify-between pt-2">
        <button onClick={onBack} className="flex items-center gap-2 text-slate-600 hover:text-slate-800 font-medium px-5 py-2.5 rounded-xl border border-slate-300 hover:bg-slate-50 transition-all">
          <ChevronLeft className="w-4 h-4"/> Atrás
        </button>
        <button onClick={onNext} className="flex items-center gap-2 bg-cyan-700 hover:bg-cyan-800 text-white font-semibold px-7 py-3 rounded-xl transition-all">
          Exportar resultados <ChevronRight className="w-4 h-4"/>
        </button>
      </div>
    </div>
  );
}


export default function StepResults({ state, onNext, onBack }: Props) {
  const r = state.results;
  const initTab = (() => {
    const cat = (state.config?.analysisCategory ?? '') as string;
    if(cat==='comparacion') return 'comparacion';
    if(cat==='anova') return 'anova';
    if(cat==='regresion') return 'regresion';
    if(cat==='logistica') return 'logistica';
    if(cat==='chi_cuadrado') return 'chi';
    if(cat==='correlacional') return 'correlacion';
    if(cat==='instrumentos') return 'instrumentos';
    if(cat==='regresion_ordinal') return 'ordinal';
    if(cat==='regresion_jerarquica') return 'jerarquica';
    if(cat==='ancova') return 'ancova';
    if(cat==='discriminante') return 'discriminante';
    if(cat==='cluster') return 'cluster';
    if(cat==='cronbach') return 'cronbach_tab';
    if(cat==='descriptivo') return 'descriptivo_tab';
    return 'resumen';
  })();
  const [tab, setTab] = useState(initTab);
  if (!r) return <div className="py-12 text-center text-slate-500">No hay resultados. Vuelve al paso anterior.</div>;

  if (r.method === 'pls_sem') {
    return <PlsResults r={r} onBack={onBack} onNext={onNext} />;
  }

  // Detectar método real: primero config del wizard, luego resultado del job
  const configMethod = state.config?.analysisCategory ?? '';
  const jobMethod = r.method ?? '';
  // Mapear analysisCategory a method del job
  const catToMethod: Record<string,string> = {
    correlacional: 'spearman', comparacion: 'ttest', anova: 'anova',
    regresion: 'regression', logistica: 'logistic', chi_cuadrado: 'chi_square',
    instrumentos: 'instruments',
  };
  const method = jobMethod || catToMethod[configMethod] || 'spearman';
  const effectiveMethod = configMethod || jobMethod;
  const sym = method === 'pearson' ? 'r' : 'ρ';
  const corrs = sa(r.correlations);
  const mainCorr = corrs.find((c:any)=>c.type==='general');
  const dimCorrs = corrs.filter((c:any)=>c.type!=='general');

  const badge = r.analisis_descriptivo ? 'Análisis Descriptivo' : r.baremos_only ? 'Baremos' : r.cronbach_only ? 'Alfa de Cronbach' : r.descriptives_full ? 'Descriptivos' : r.frequencies ? 'Frecuencias' : r.cluster ? 'Análisis clúster' : r.discriminant ? 'Discriminante' : r.ancova ? 'ANCOVA' : r.hierarchical_regression ? 'Regresión jerárquica' : r.ordinal_regression ? 'Regresión ordinal' : r.instruments ? 'Validación de instrumento' : r.ttest ? (r.ttest.auto_selected||'Comparación') : r.anova ? (r.anova.auto_selected||'ANOVA') : r.regression ? `R² = ${r.regression?.R2 ?? r.regression?.r2 ?? '—'}` : r.logistic ? 'Regresión logística' : r.chi_square ? 'Chi-cuadrado' : method==='pearson' ? 'r de Pearson' : 'Rho de Spearman';
  const badgeColor = r.analisis_descriptivo ? 'bg-emerald-100 text-emerald-700' : r.baremos_only ? 'bg-lime-100 text-lime-700' : r.cronbach_only ? 'bg-blue-100 text-blue-700' : r.descriptives_full ? 'bg-emerald-100 text-emerald-700' : r.frequencies ? 'bg-yellow-100 text-yellow-700' : r.cluster ? 'bg-violet-100 text-violet-700' : r.discriminant ? 'bg-teal-100 text-teal-700' : r.ancova ? 'bg-orange-100 text-orange-700' : r.hierarchical_regression ? 'bg-purple-100 text-purple-700' : r.ordinal_regression ? 'bg-sky-100 text-sky-700' : r.instruments ? 'bg-cyan-100 text-cyan-700' : r.ttest ? 'bg-purple-100 text-purple-700' : r.anova ? 'bg-amber-100 text-amber-700' : r.regression ? 'bg-green-100 text-green-700' : r.logistic ? 'bg-pink-100 text-pink-700' : r.chi_square ? 'bg-orange-100 text-orange-700' : 'bg-indigo-100 text-indigo-700';

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between flex-wrap gap-2">
        <div><h2 className="text-2xl font-bold text-slate-800">Resultados del análisis</h2><p className="text-slate-500 mt-1">Resumen estadístico completo con interpretación APA 7.</p></div>
        <span className={`text-sm font-semibold px-4 py-1.5 rounded-full ${badgeColor}`}>{badge}</span>
      </div>
      {(r.objective || r.hypothesis_h1) && (() => {
        let answer = '';
        if (mainCorr) {
          answer = `${sym} = ${mainCorr.r_apa}, p ${mainCorr.p_apa} - ${dt(mainCorr.decision)}. Ver tabla de correlacion.`;
        } else if (r.anova) {
          answer = `F(${r.anova.df_between}, ${r.anova.df_within}) = ${r.anova.F}, p ${r.anova.p_apa} - ${dt(r.anova.decision)}. Ver tabla ANOVA.`;
        }
        if (!answer) return null;
        return (
          <div className="bg-gradient-to-br from-indigo-50 to-purple-50 border-2 border-indigo-200 rounded-2xl p-5">
            <p className="text-xs font-bold text-indigo-700 uppercase tracking-wider mb-2">Esto responde a tu objetivo</p>
            {r.objective && <p className="text-sm text-slate-700 mb-1"><span className="font-semibold">Objetivo:</span> {dt(r.objective)}</p>}
            {r.hypothesis_h1 && <p className="text-sm text-slate-700 mb-2"><span className="font-semibold">H1:</span> {dt(r.hypothesis_h1)}</p>}
            <p className="text-sm font-bold text-indigo-800 bg-white/60 rounded-xl px-3 py-2 mt-2">{answer}</p>
          </div>
        );
      })()}

      {sa(r.warnings).length > 0 && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 text-sm text-amber-800">
          <p className="font-semibold mb-1">Advertencias metodológicas</p>
          {sa(r.warnings).map((w:string,i:number)=><p key={i}>• {dt(w)}</p>)}
        </div>
      )}

      <div className="relative">
        <div className="flex gap-1.5 overflow-x-auto pb-1 scrollbar-hide" style={{scrollbarWidth:'none'}}>
          {getVisibleTabs(effectiveMethod || r.method || 'correlacional').map((t,i)=>{
            const isActive = tab === t.id;
            const colors = ['#6366f1','#8b5cf6','#06b6d4','#10b981','#f59e0b','#ef4444','#ec4899','#14b8a6','#3b82f6','#a855f7','#f97316','#84cc16'];
            const color = colors[i % colors.length];
            return (
              <button key={t.id} onClick={()=>setTab(t.id)}
                className={`flex items-center gap-1.5 px-4 py-2.5 rounded-xl text-sm font-semibold whitespace-nowrap transition-all duration-200 border ${
                  isActive
                    ? 'text-white shadow-lg scale-105 border-transparent'
                    : 'bg-white text-slate-500 border-slate-200 hover:border-slate-300 hover:text-slate-700 hover:scale-102'
                }`}
                style={isActive ? {background:`linear-gradient(135deg, ${color}, ${color}dd)`, boxShadow:`0 4px 15px ${color}44`} : {}}>
                <t.icon className="w-3.5 h-3.5"/>
                {t.label}
              </button>
            );
          })}
        </div>
      </div>

      {/* RESUMEN */}
      {tab==='resumen' && (
        <div className="space-y-4">
          <div className="grid grid-cols-3 gap-4">
            {[{label:'Participantes',value:r.diagnostic?.n_rows??'-',sub:'observaciones'},{label:'Variables',value:r.diagnostic?.n_cols??'-',sub:'columnas'},{label:'Datos perdidos',value:`${r.diagnostic?.missing_pct??0}%`,sub:'del total'}].map(k=>(
              <div key={k.label} className="bg-white rounded-xl border border-slate-200 p-4 text-center">
                <p className="text-xs font-semibold text-slate-500 uppercase">{k.label}</p>
                <p className="text-3xl font-bold text-indigo-700 my-1">{k.value}</p>
                <p className="text-xs text-slate-400">{k.sub}</p>
              </div>
            ))}
          </div>
          {r.analisis_descriptivo && (
            <div className="bg-gradient-to-br from-emerald-600 to-green-700 rounded-2xl p-6 text-white">
              <p className="text-emerald-200 text-sm font-semibold uppercase mb-1">Resultado principal — Análisis Descriptivo</p>
              <p className="font-bold text-lg">{dt(r.analisis_descriptivo.var_name)}</p>
              <div className="flex items-baseline gap-3 mt-2">
                <span className="text-5xl font-black">M = {r.analisis_descriptivo.mean}</span>
                <span className="text-emerald-200">DE = {r.analisis_descriptivo.sd}</span>
              </div>
              <div className="flex flex-wrap gap-2 mt-3">
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">n = {r.analisis_descriptivo.n}</span>
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">k = {r.analisis_descriptivo.k} ítems</span>
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">{r.analisis_descriptivo.normal?'Normal':'No normal'} (SW)</span>
              </div>
              {sa(r.analisis_descriptivo.distribution).length>0&&(
                <div className="mt-4 grid grid-cols-3 gap-3">
                  {sa(r.analisis_descriptivo.distribution).map((b:any,i:number)=>(
                    <div key={i} className="bg-white/10 rounded-xl p-3 text-center">
                      <p className="text-xs font-bold uppercase text-emerald-200">{dt(b.nivel)}</p>
                      <p className="text-2xl font-black mt-1">{b.pct}%</p>
                      <p className="text-xs text-emerald-200 mt-1">f = {b.f}</p>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
          {r.cronbach_only && (
            <div className="bg-gradient-to-br from-blue-600 to-indigo-700 rounded-2xl p-6 text-white">
              <p className="text-blue-200 text-sm font-semibold uppercase mb-1">Resultado principal — Confiabilidad</p>
              <p className="font-bold text-lg">{dt(r.cronbach_only.var_name)}</p>
              <div className="flex items-baseline gap-3 mt-2">
                <span className="text-5xl font-black">α = {r.cronbach_only.alpha}</span>
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">{dt(r.cronbach_only.interpretation)}</span>
              </div>
              <div className="flex flex-wrap gap-2 mt-3">
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">n = {r.cronbach_only.n}</span>
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">k = {r.cronbach_only.k} ítems</span>
                {r.cronbach_only.omega&&<span className="bg-white/20 px-3 py-1 rounded-full text-sm">ω = {r.cronbach_only.omega}</span>}
              </div>
            </div>
          )}
          {r.descriptives_full && (
            <div className="bg-gradient-to-br from-emerald-600 to-teal-700 rounded-2xl p-6 text-white">
              <p className="text-emerald-200 text-sm font-semibold uppercase mb-1">Resultado principal — Descriptivos</p>
              <p className="font-bold text-lg">{dt(r.descriptives_full.var_name)}</p>
              <div className="flex items-baseline gap-3 mt-2">
                <span className="text-5xl font-black">M = {r.descriptives_full.mean}</span>
                <span className="text-emerald-200">DE = {r.descriptives_full.sd}</span>
              </div>
              <div className="flex flex-wrap gap-2 mt-3">
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">n = {r.descriptives_full.n}</span>
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">Mediana = {r.descriptives_full.median}</span>
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">{r.descriptives_full.normal?'Normal':'No normal'}</span>
              </div>
            </div>
          )}
          {r.frequencies && (
            <div className="bg-gradient-to-br from-amber-500 to-orange-700 rounded-2xl p-6 text-white">
              <p className="text-amber-200 text-sm font-semibold uppercase mb-1">Resultado principal — Frecuencias</p>
              <p className="font-bold text-lg">{dt(r.frequencies.var_name)}</p>
              <div className="flex items-baseline gap-3 mt-2">
                <span className="text-5xl font-black">M = {r.frequencies.total_mean}</span>
                <span className="text-amber-200">DE = {r.frequencies.total_sd}</span>
              </div>
              <div className="flex flex-wrap gap-2 mt-3">
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">n = {r.frequencies.n}</span>
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">k = {r.frequencies.k} ítems</span>
              </div>
            </div>
          )}
          {mainCorr && (
            <div className="bg-gradient-to-br from-indigo-600 to-purple-700 rounded-2xl p-6 text-white">
              <p className="text-indigo-200 text-sm font-semibold uppercase mb-1">Resultado principal</p>
              <p className="font-bold text-lg">{dt(mainCorr.var_a)} × {dt(mainCorr.var_b)}</p>
              <div className="flex items-baseline gap-3 mt-2">
                <span className="text-5xl font-black">{sym} = {mainCorr.r_apa}</span>
                <span className="text-indigo-200">p {mainCorr.p_apa}</span>
                <span className="text-yellow-300 text-xl font-bold">{mainCorr.stars}</span>
              </div>
              <div className="flex flex-wrap gap-2 mt-3">
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">Correlación {dt(mainCorr.magnitude)}</span>
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">n = {mainCorr.n}</span>
                <span className={`px-3 py-1 rounded-full text-sm font-semibold ${mainCorr.significant?'bg-green-400/30':'bg-red-400/30'}`}>{dt(mainCorr.decision)}</span>
              </div>
              {mainCorr.ci_lower!=null&&<p className="text-indigo-200 text-xs mt-2">IC 95%: [{mainCorr.ci_lower}, {mainCorr.ci_upper}] | Potencia: {mainCorr.power?`${Math.round(mainCorr.power*100)}%`:'-'}</p>}
              {mainCorr.text_apa&&<div className="mt-4 bg-white/10 rounded-xl p-4"><p className="text-xs font-bold text-indigo-200 uppercase mb-1">Redacción APA 7</p><p className="text-sm leading-relaxed italic">{dt(mainCorr.text_apa)}</p></div>}
            </div>
          )}
          {dimCorrs.length>0&&(
            <div className="space-y-2">
              <p className="text-sm font-semibold text-slate-700">Correlaciones por dimensiones</p>
              {dimCorrs.map((c:any,i:number)=>(
                <div key={i} className="bg-white rounded-xl border border-slate-200 p-4 flex items-center justify-between">
                  <div><p className="font-medium text-slate-800">{dt(c.var_a)} × {dt(c.var_b)}</p><p className="text-xs text-slate-500">Magnitud: {dt(c.magnitude)} · n = {c.n}</p></div>
                  <div className="text-right"><p className="text-xl font-bold text-indigo-700">{sym} = {c.r_apa}<span className="text-yellow-500 ml-1">{c.stars}</span></p><p className="text-xs text-slate-500">p {c.p_apa}</p></div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* NORMALIDAD */}
      {tab==='normalidad' && (
        <Section title="Prueba de normalidad" icon={Activity} color="blue">
          <Tbl headers={['Variable','n','SW (W)','p (SW)','KS (D)','p (KS)','Decisión']}
            rows={sa(r.normality).map((row:any)=>[dt(String(row.variable||'')),row.n,row.sw_statistic,
              <span className={row.sw_p<0.05?'text-red-600 font-semibold':''}>{row.sw_p}</span>,
              row.ks_statistic,
              <span className={row.ks_p<0.05?'text-red-600 font-semibold':''}>{row.ks_p}</span>,
              <span className={row.decision==='No normal'?'text-red-600 font-semibold':'text-green-600'}>{row.decision}</span>
            ])} />
          {r.interpretations?.normality_text&&<p className="text-sm text-slate-700 bg-white rounded-xl p-4 border border-slate-200">{dt(r.interpretations.normality_text)}</p>}
        </Section>
      )}

      {/* CONFIABILIDAD */}
      {tab==='confiabilidad' && (
        <div className="space-y-4">
          <Section title="Alfa de Cronbach" icon={Shield} color="indigo">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {sa(r.reliability).map((cr:any,i:number)=>(
                <div key={i} className={`rounded-xl border-2 p-4 ${cr.interpretation==='Excelente'?'border-green-300 bg-green-50':cr.interpretation==='Bueno'?'border-blue-300 bg-blue-50':cr.interpretation==='Aceptable'?'border-amber-300 bg-amber-50':'border-red-300 bg-red-50'}`}>
                  <p className="font-bold text-slate-800 mb-1">{dt(String(cr.name||""))}</p>
                  <p className="text-2xl font-black">α = {cr.alpha}<span className="text-sm font-normal text-slate-500 ml-2">IC [{cr.ci_lower}, {cr.ci_upper}]</span></p>
                  <p className="text-sm text-slate-600 mt-1">{cr.interpretation} · k={cr.k} ítems · n={cr.n}</p>
                  {cr.omega&&<div className="mt-2 pt-2 border-t border-slate-200 grid grid-cols-3 gap-1 text-xs text-slate-500"><span>ω = {cr.omega.omega_t}</span><span>α std = {cr.alpha_std}</span><span>r̄ = {cr.inter_item_mean}</span></div>}
                </div>
              ))}
            </div>
          </Section>
          {sa(r.reliability).filter((cr:any)=>cr.item_stats&&Object.keys(cr.item_stats).length>0).map((cr:any,idx:number)=>(
            <Section key={idx} title={`Estadísticos elemento-total — ${dt(String(cr.name||""))}`} icon={Shield} color="purple" defaultOpen={idx===0}>
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-xs">
                  <thead className="bg-slate-50 border-b border-slate-200"><tr>{['Ítem','M','DE','M escala s/ítem','r ítem-total','α si elimina','Interp.'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600 whitespace-nowrap">{h}</th>)}</tr></thead>
                  <tbody>{sa(Object.values(cr.item_stats||{})).map((it:any,i:number)=>(
                    <tr key={i} className={`border-b border-slate-100 ${it.alpha_if_deleted>cr.alpha?'bg-amber-50':'hover:bg-slate-50'}`}>
                      <td className="px-3 py-1.5 font-bold">{it.item}</td>
                      <td className="px-3 py-1.5">{it.mean}</td><td className="px-3 py-1.5">{it.sd}</td>
                      <td className="px-3 py-1.5">{it.mean_scale_del}</td>
                      <td className="px-3 py-1.5 font-semibold text-indigo-700">{it.r_item_total_corr}</td>
                      <td className={`px-3 py-1.5 font-semibold ${it.alpha_if_deleted>cr.alpha?'text-amber-600':''}`}>{it.alpha_if_deleted}</td>
                      <td className="px-3 py-1.5 text-slate-500">{it.interpretation_del}</td>
                    </tr>
                  ))}</tbody>
                </table>
              </div>
            </Section>
          ))}
        </div>
      )}

      {/* CORRELACION */}
      {tab==='correlacion' && (
        <div className="space-y-4">
          {mainCorr&&(
            <Section title={`Objetivo general: ${dt(mainCorr.var_a)} × ${dt(mainCorr.var_b)}`} icon={TrendingUp} color="indigo">
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {([{label:'Coeficiente',value:`${sym} = ${mainCorr.r_apa}${mainCorr.stars}`},{label:'p-valor',value:`p ${mainCorr.p_apa}`},{label:'IC 95%',value:mainCorr.ci_lower!=null?`[${mainCorr.ci_lower}, ${mainCorr.ci_upper}]`:'-'},{label:'Potencia',value:mainCorr.power?`${Math.round(mainCorr.power*100)}%`:'-'}] as {label:string,value:any}[]).map(k=>(
                  <KPI key={k.label} label={k.label} value={k.value}/>
                ))}
              </div>
              <div className="bg-slate-50 rounded-xl p-4 border border-slate-200">
                <p className="text-xs font-bold text-slate-500 uppercase mb-2">Decisión: {dt(mainCorr.decision)}</p>
                <p className="text-sm text-slate-700 leading-relaxed italic">{dt(mainCorr.text_apa)}</p>
              </div>
            </Section>
          )}
          {dimCorrs.length>0&&(
            <Section title="Objetivos específicos" icon={TrendingUp} color="teal">
              <div className="space-y-3">
                {dimCorrs.map((c:any,i:number)=>(
                  <div key={i} className="bg-white rounded-xl border border-slate-200 p-4">
                    <div className="flex items-center justify-between mb-2">
                      <p className="font-semibold text-slate-800">{dt(c.var_a)} × {dt(c.var_b)}</p>
                      <span className={`text-xs px-3 py-1 rounded-full font-semibold ${c.significant?'bg-green-100 text-green-700':'bg-slate-100 text-slate-600'}`}>{dt(c.decision)}</span>
                    </div>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-2 text-sm">
                      <div><span className="text-slate-500">Coef. </span><span className="font-bold text-indigo-700">{sym} = {c.r_apa}{c.stars}</span></div>
                      <div><span className="text-slate-500">p </span><span className="font-medium">{c.p_apa}</span></div>
                      <div><span className="text-slate-500">Magnitud </span><span className="font-medium">{dt(c.magnitude)}</span></div>
                      <div><span className="text-slate-500">n </span><span className="font-medium">{c.n}</span></div>
                    </div>
                    {c.ci_lower!=null&&<p className="text-xs text-slate-400 mt-1">IC 95%: [{c.ci_lower}, {c.ci_upper}] | Potencia: {c.power?`${Math.round(c.power*100)}%`:'-'}</p>}
                  </div>
                ))}
              </div>
            </Section>
          )}
        </div>
      )}

      {/* DESCRIPTIVOS */}
      {tab==='descriptivos' && (
        <Section title="Estadística descriptiva" icon={BarChart2} color="green">
          <Tbl headers={['Variable','n','M','DE','Mín','Máx','Asimetría']}
            rows={sa(r.descriptives).map((row:any)=>[<span className="font-medium">{dt(String(row.variable||""))}</span>,row.n,row.mean,row.sd,row.min,row.max,row.skewness])} />
        </Section>
      )}

      {/* BAREMOS */}
      {tab==='baremos' && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {[r.baremoA,r.baremoB].filter(Boolean).map((br:any,idx:number)=>(
            <Section key={idx} title={`Baremo — ${dt(String(br.variable||""))}`} icon={BarChart2} color="amber">
              <Tbl headers={['Nivel','Desde','Hasta']} rows={sa(br.table).map((row:any)=>[<span className="font-semibold">{row.nivel}</span>,row.desde,row.hasta])} />
              {sa(br.frequencies).length>0&&<>
                <p className="text-sm font-semibold text-slate-700">Distribución de niveles</p>
                <Tbl headers={['Nivel','f','%','% acumulado']} rows={sa(br.frequencies).map((row:any)=>[<span className="font-semibold">{row.nivel}</span>,row.f,`${row.pct}%`,`${row.pct_ac}%`])} />
                {br.levels_text&&<p className="text-xs text-slate-500 italic">{dt(br.levels_text)}</p>}
              </>}
            </Section>
          ))}
        </div>
      )}

      {/* COMPARACION */}
      {tab==='comparacion' && r.ttest && (
        <div className="space-y-4">
          <Section title={`Comparación — ${r.ttest.auto_selected||r.ttest.test_type}`} icon={Activity} color="purple">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {(r.ttest.test_type==='mann_whitney'?[{label:'U Mann-Whitney',value:r.ttest.U},{label:'p-valor',value:`p ${r.ttest.p_apa}`},{label:'r rango biserial',value:r.ttest.r_rb},{label:'Tamaño efecto',value:r.ttest.r_interpret}]:r.ttest.test_type==='wilcoxon_pareado'?[{label:'W Wilcoxon',value:r.ttest.W},{label:'p-valor',value:`p ${r.ttest.p_apa}`},{label:'r rango biserial',value:r.ttest.r_rb},{label:'Tamaño efecto',value:r.ttest.r_interpret}]:[{label:'t',value:r.ttest.t},{label:'gl',value:r.ttest.df},{label:'p-valor',value:`p ${r.ttest.p_apa}`},{label:'d Cohen',value:`${r.ttest.d} (${r.ttest.d_interpret})`}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            {r.ttest.ci_lower!=null&&<p className="text-sm text-slate-600">IC 95%: [{r.ttest.ci_lower}, {r.ttest.ci_upper}]</p>}
            <div className={`rounded-xl p-4 border ${r.ttest.significant?'bg-green-50 border-green-200':'bg-slate-50 border-slate-200'}`}>
              <p className="font-semibold">{dt(r.ttest.decision)}</p>
              <p className="text-xs text-slate-500 mt-1">α = {r.ttest.alpha} | Método: {r.ttest.auto_selected}</p>
            </div>
          </Section>
          {r.ttest.descriptives&&(
            <Section title="Descriptivos por grupo" icon={BarChart2} color="teal">
              <Tbl headers={['Grupo','n','M','DE','Mediana/SE']}
                rows={[r.ttest.descriptives.group1,r.ttest.descriptives.group2].filter(Boolean).map((g:any)=>[<span className="font-semibold">{dt(String(g.name||""))}</span>,g.n,g.mean,g.sd,g.median??g.se??'-'])} />
            </Section>
          )}
          {r.ttest.levene&&(
            <Section title="Prueba de Levene" icon={Shield} color="amber">
              <div className="grid grid-cols-3 gap-3">
                {([{label:'F Levene',value:r.ttest.levene.F},{label:'p-valor',value:r.ttest.levene.p},{label:'Varianzas',value:r.ttest.levene.equal_variances?'Iguales':'Desiguales'}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
              </div>
            </Section>
          )}
          {r.ttest.normality&&(
            <Section title="Normalidad por grupo" icon={Activity} color="blue">
              <Tbl headers={['Grupo','SW (W)','p','¿Normal?']}
                rows={[{name:r.ttest.descriptives?.group1?.name,data:r.ttest.normality.group1},{name:r.ttest.descriptives?.group2?.name,data:r.ttest.normality.group2}].filter(x=>x.data).map((g:any)=>[
                  g.name??'-', g.data?.W, g.data?.p,
                  <span className={g.data?.normal?'text-green-600':'text-red-600 font-semibold'}>{g.data?.normal?'Sí':'No'}</span>
                ])} />
            </Section>
          )}
        </div>
      )}

      {/* ANOVA */}
      {tab==='anova' && r.anova && (
        <div className="space-y-4">
          <Section title={`ANOVA — ${r.anova.auto_selected||r.anova.test_type}`} icon={BarChart2} color="purple">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {(r.anova.test_type==='anova'?[{label:'F',value:r.anova.F},{label:`gl (${r.anova.df_between},${r.anova.df_within})`,value:'-'},{label:'p-valor',value:`p ${r.anova.p_apa}`},{label:`η² = ${r.anova.eta2}`,value:r.anova.eta2_interpret}]:[{label:'H Kruskal-Wallis',value:r.anova.H},{label:`gl = ${r.anova.df}`,value:'-'},{label:'p-valor',value:`p ${r.anova.p_apa}`},{label:`ε² = ${r.anova.epsilon2}`,value:r.anova.epsilon2_interpret}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            <div className={`rounded-xl p-4 border ${r.anova.significant?'bg-green-50 border-green-200':'bg-slate-50 border-slate-200'}`}>
              <p className="font-semibold">{dt(r.anova.decision)}</p>
              <p className="text-xs text-slate-500 mt-1">Método: {r.anova.auto_selected} | Post-hoc: {r.anova.posthoc_method}</p>
            </div>
          </Section>
          {r.anova.test_type==='anova'&&(
            <Section title="Tabla ANOVA" icon={BarChart2} color="indigo">
              <Tbl headers={['Fuente','SC','gl','MC','F','p']} rows={[
                ['Entre grupos',r.anova.ss_between,r.anova.df_between,r.anova.ms_between,r.anova.F,`p ${r.anova.p_apa}`],
                ['Dentro grupos',r.anova.ss_within,r.anova.df_within,r.anova.ms_within,'-','-'],
                ['Total',r.anova.ss_total,(r.anova.df_between||0)+(r.anova.df_within||0),'-','-','-'],
              ]}/>
            </Section>
          )}
          {sa(r.anova.descriptives).length>0&&(
            <Section title="Descriptivos por grupo" icon={BarChart2} color="teal">
              <Tbl headers={['Grupo','n','M','DE',r.anova.test_type==='anova'?'SE':'Mediana']}
                rows={sa(r.anova.descriptives).map((g:any)=>[<span className="font-semibold">{dt(String(g.group||""))}</span>,g.n,g.mean,g.sd,g.se??g.median??'-'])} />
            </Section>
          )}
          {r.anova.test_type==='anova'&&sa(r.anova.posthoc).length>0&&(
            <Section title={`Post-hoc: ${r.anova.posthoc_method}`} icon={Activity} color="amber">
              <Tbl headers={['Comparación','Diferencia','IC inf','IC sup','p ajustado','Sig.']}
                rows={sa(r.anova.posthoc).map((row:any)=>[row.comparison,row.diff,row.ci_lower,row.ci_upper,row.p_adj,<span className={row.significant?'text-green-600 font-semibold':'text-slate-400'}>{row.significant?'Sí *':'No'}</span>])} />
            </Section>
          )}
          {r.anova.test_type==='kruskal_wallis'&&sa(r.anova.posthoc).length>0&&(
            <Section title="Post-hoc: Dunn (Bonferroni)" icon={Activity} color="amber">
              <Tbl headers={['Comparación','z','p sin ajuste','p Bonferroni','Sig.']}
                rows={sa(r.anova.posthoc).map((row:any)=>[row.comparison,row.z,row.p_raw,row.p_bonf,<span className={row.significant?'text-green-600 font-semibold':'text-slate-400'}>{row.significant?'Sí *':'No'}</span>])} />
            </Section>
          )}
          {r.anova.levene&&(
            <Section title="Prueba de Levene" icon={Shield} color="blue">
              <div className="grid grid-cols-3 gap-3">
                {([{label:'F Levene',value:r.anova.levene.F},{label:'p-valor',value:r.anova.levene.p},{label:'Varianzas',value:r.anova.levene.equal_variances?'Iguales':'Desiguales'}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
              </div>
            </Section>
          )}
        </div>
      )}


      {/* REGRESION ORDINAL */}
      {tab==='ordinal' && r.ordinal_regression && (
        <div className="space-y-4">
          <Section title="Regresion ordinal (polr)" icon={TrendingUp} color="blue">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {([{label:'n',value:r.ordinal_regression.n},{label:'Nagelkerke R2',value:r.ordinal_regression.nagelkerke_r2},{label:'AIC',value:r.ordinal_regression.aic},{label:'Significativo',value:r.ordinal_regression.significant?'Si':'No'}]).map((k)=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            <div className={["rounded-xl p-4 border",r.ordinal_regression.significant?'bg-green-50 border-green-200':'bg-slate-50 border-slate-200'].join(' ')}>
              <p className="font-semibold">{dt(r.ordinal_regression.decision)}</p>
            </div>
          </Section>
          {sa(r.ordinal_regression.coefficients).length>0&&(
            <Section title="Coeficientes (OR)" icon={TrendingUp} color="indigo">
              <Tbl headers={['Variable','B','OR','IC inf','IC sup','t','p']}
                rows={sa(r.ordinal_regression.coefficients).map((co)=>[co.term,co.B,co.OR,co.ci_lower,co.ci_upper,co.t,'p '+co.p_apa])} />
            </Section>
          )}
          {sa(r.ordinal_regression.distribution).length>0&&(
            <Section title="Distribucion por niveles" icon={BarChart2} color="teal">
              <Tbl headers={['Nivel','n','%']} rows={sa(r.ordinal_regression.distribution).map((d)=>[d.Nivel,d.n,d.pct+'%'])} />
            </Section>
          )}
        </div>
      )}

      {/* REGRESION JERARQUICA */}
      {tab==='jerarquica' && r.hierarchical_regression && (
        <div className="space-y-4">
          <Section title="Regresion jerarquica" icon={TrendingUp} color="purple">
            <div className="grid grid-cols-3 gap-3">
              {([{label:'n',value:r.hierarchical_regression.n},{label:'R2 final',value:r.hierarchical_regression.final_r2},{label:'R2 ajustado',value:r.hierarchical_regression.final_r2_adj}]).map((k)=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
          </Section>
          {sa(r.hierarchical_regression.blocks).length>0&&(
            <Section title="Resumen por bloques" icon={BarChart2} color="indigo">
              <Tbl headers={['Bloque','Predictor','R2','R2 adj','dR2','F','p']}
                rows={sa(r.hierarchical_regression.blocks).map((b)=>[b.block,b.name,b.r2,b.r2_adj,b.delta_r2,b.F,'p '+b.p_apa])} />
            </Section>
          )}
          {sa(r.hierarchical_regression.final_coefficients).length>0&&(
            <Section title="Coeficientes modelo final" icon={TrendingUp} color="teal">
              <Tbl headers={['Variable','B','SE','t','p']}
                rows={sa(r.hierarchical_regression.final_coefficients).map((co)=>[co.term,co.B,co.SE,co.t,'p '+co.p_apa])} />
            </Section>
          )}
        </div>
      )}

      {/* ANCOVA */}
      {tab==='ancova' && r.ancova && (
        <div className="space-y-4">
          <Section title="ANCOVA" icon={BarChart2} color="amber">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {([{label:'n',value:r.ancova.n},{label:'R2 ANCOVA',value:r.ancova.r2_ancova},{label:'R2 ANOVA',value:r.ancova.r2_anova},{label:'Mejora R2',value:r.ancova.r2_improvement}]).map((k)=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            <div className={["rounded-xl p-4 border",r.ancova.significant?'bg-green-50 border-green-200':'bg-slate-50 border-slate-200'].join(' ')}>
              <p className="font-semibold">{dt(r.ancova.decision)}</p>
            </div>
          </Section>
          {sa(r.ancova.ancova_table).length>0&&(
            <Section title="Tabla ANCOVA" icon={BarChart2} color="indigo">
              <Tbl headers={['Fuente','SC','gl','MC','F','p']} rows={sa(r.ancova.ancova_table).map((row)=>[row.source,row.SS,row.df,row.MS,row.F,'p '+row.p_apa])} />
            </Section>
          )}
          {sa(r.ancova.adjusted_means).length>0&&(
            <Section title="Medias ajustadas" icon={Activity} color="teal">
              <Tbl headers={['Grupo','Media ajustada','SE','IC inf','IC sup']} rows={sa(r.ancova.adjusted_means).map((m)=>[m.group,m.mean_adj,m.se,m.ci_lower,m.ci_upper])} />
            </Section>
          )}
        </div>
      )}

      {/* DISCRIMINANTE */}
      {tab==='discriminante' && r.discriminant && (
        <div className="space-y-4">
          <Section title="Analisis discriminante lineal" icon={Activity} color="teal">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {([{label:'n',value:r.discriminant.n},{label:'Precision',value:r.discriminant.precision+'%'},{label:'Wilks Lambda',value:r.discriminant.wilks_lambda},{label:'Funciones',value:r.discriminant.n_functions}]).map((k)=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            <div className="bg-teal-50 border border-teal-200 rounded-xl p-4">
              <p className="font-semibold text-teal-800">{dt(r.discriminant.decision)}</p>
            </div>
          </Section>
          {sa(r.discriminant.coefficients).length>0&&(
            <Section title="Coeficientes discriminantes" icon={BarChart2} color="indigo">
              <Tbl headers={['Variable','LD1','LD2']} rows={sa(r.discriminant.coefficients).map((co)=>[co.variable,co.LD1||'-',co.LD2||'-'])} />
            </Section>
          )}
        </div>
      )}

      {/* FRECUENCIAS */}
      {tab==='frecuencias' && r.frequencies && (
        <div className="space-y-4">
          <Section title="Estadisticos generales" icon={BarChart2} color="amber">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {([{label:'n',value:r.frequencies.n},{label:'Media total',value:r.frequencies.total_mean},{label:'DE total',value:r.frequencies.total_sd},{label:'Mediana',value:r.frequencies.total_median}]).map((k)=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
          </Section>
          {sa(r.frequencies.items).map((item,i)=>(
            <Section key={i} title={item.item+' — Frecuencias'} icon={BarChart2} color="indigo" defaultOpen={false}>
              <div className="grid grid-cols-4 gap-2 mb-3">
                {([{label:'Media',value:item.mean},{label:'Mediana',value:item.median},{label:'Moda',value:item.mode},{label:'DE',value:item.sd}]).map((k)=><KPI key={k.label} label={k.label} value={k.value}/>)}
              </div>
              <Tbl headers={['Valor','n','%','% Acum.']} rows={sa(item.frequency_table).map((f)=>[f.valor,f.n,f.pct+'%',f.pct_acum+'%'])} />
            </Section>
          ))}
        </div>
      )}

      {/* CLUSTER */}
      {tab==='cluster' && r.cluster && (
        <div className="space-y-4">
          <Section title="Analisis cluster K-means" icon={BarChart2} color="indigo">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {([{label:'n',value:r.cluster.n},{label:'Clusteres',value:r.cluster.n_clusters},{label:'Silhouette',value:r.cluster.silhouette},{label:'Calidad',value:r.cluster.silhouette_interpret}]).map((k)=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
          </Section>
          {sa(r.cluster.clusters).length>0&&(
            <Section title="Descripcion de clusteres" icon={Activity} color="teal">
              <Tbl headers={['Cluster','n','%','Media','DE','Nivel']} rows={sa(r.cluster.clusters).map((cl)=>[cl.cluster,cl.n,cl.pct+'%',cl.mean,cl.sd,cl.label])} />
            </Section>
          )}
        </div>
      )}

      {/* CRONBACH INDEPENDIENTE */}
      {tab==='cronbach_tab' && r.cronbach_only && (
        <div className="space-y-4">
          <Section title="Alfa de Cronbach" icon={Shield} color="blue">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {([{label:'Alpha',value:r.cronbach_only.alpha},{label:'Omega',value:r.cronbach_only.omega||'-'},{label:'IC 95%',value:'['+r.cronbach_only.ci_lower+', '+r.cronbach_only.ci_upper+']'},{label:'Interpretacion',value:r.cronbach_only.interpretation}]).map((k)=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
          </Section>
          {sa(r.cronbach_only.item_stats).length>0&&(
            <Section title="Estadisticos elemento-total" icon={BarChart2} color="indigo">
              <Tbl headers={['Item','M','DE','r item-total','Alpha si elimina','Decision']}
                rows={sa(r.cronbach_only.item_stats).map((it)=>[it.item,it.mean,it.sd,it.r_item_total,it.alpha_if_deleted,it.interpretation])} />
            </Section>
          )}
        </div>
      )}

      {/* ANALISIS DESCRIPTIVO (combinado) */}
      {tab==='descriptivo_tab' && r.analisis_descriptivo && (
        <div className="space-y-4">
          <Section title="Estadísticos descriptivos" icon={BarChart2} color="emerald">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {([{label:'n',value:r.analisis_descriptivo.n},{label:'Media',value:r.analisis_descriptivo.mean},{label:'Mediana',value:r.analisis_descriptivo.median},{label:'Moda',value:r.analisis_descriptivo.mode},{label:'DE',value:r.analisis_descriptivo.sd},{label:'Varianza',value:r.analisis_descriptivo.variance},{label:'Asimetría',value:r.analisis_descriptivo.skewness},{label:'Curtosis',value:r.analisis_descriptivo.kurtosis}]).map((k:any)=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-3">
              {([{label:'IC 95% inf',value:r.analisis_descriptivo.ci_lower},{label:'IC 95% sup',value:r.analisis_descriptivo.ci_upper},{label:'CV%',value:r.analisis_descriptivo.cv},{label:'IQR',value:r.analisis_descriptivo.iqr},{label:'P25',value:r.analisis_descriptivo.p25},{label:'P50',value:r.analisis_descriptivo.p50},{label:'P75',value:r.analisis_descriptivo.p75},{label:'Normal SW',value:r.analisis_descriptivo.normal?'Sí':'No'}]).map((k:any)=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            <div className={`rounded-xl p-3 border mt-2 ${r.analisis_descriptivo.normal?'bg-green-50 border-green-200':'bg-amber-50 border-amber-200'}`}>
              <p className="text-sm font-semibold">Distribución: {dt(r.analisis_descriptivo.skewness_interpret)} · {dt(r.analisis_descriptivo.kurtosis_interpret)}</p>
              <p className="text-xs text-slate-500 mt-1">SW: W={r.analisis_descriptivo.sw_W}, p={r.analisis_descriptivo.sw_p}</p>
              {r.analisis_descriptivo.texto_descriptivo && <p className="text-sm text-slate-700 mt-2 italic">{dt(r.analisis_descriptivo.texto_descriptivo)}</p>}
            </div>
          </Section>

          {sa(r.analisis_descriptivo.item_stats).length>0&&(
            <Section title="Descriptivos por ítem" icon={BarChart2} color="indigo" defaultOpen={false}>
              <Tbl headers={['Ítem','n','M','Md','Mo','DE','Asim.','Kurt.','P25','P75']}
                rows={sa(r.analisis_descriptivo.item_stats).map((it:any)=>[it.item,it.n,it.mean,it.median,it.mode,it.sd,it.skewness,it.kurtosis,it.p25,it.p75])} />
            </Section>
          )}

          <Section title="Baremo (regla de corte)" icon={BarChart2} color="green">
            <p className="text-xs text-slate-500 mb-3">Tabla de clasificación según el método: {dt(r.analisis_descriptivo.method)}. No incluye porcentajes — es la norma de medición.</p>
            {sa(r.analisis_descriptivo.baremo).length>0&&(
              <Tbl headers={['Nivel','Desde','Hasta']} rows={sa(r.analisis_descriptivo.baremo).map((b:any)=>[dt(b.nivel),b.desde,b.hasta])} />
            )}
            {r.analisis_descriptivo.texto_baremo && <p className="text-sm text-slate-700 mt-3 italic">{dt(r.analisis_descriptivo.texto_baremo)}</p>}
          </Section>

          <Section title="Distribución por niveles (aplicado a la muestra)" icon={Activity} color="teal">
            {sa(r.analisis_descriptivo.distribution).length>0&&(
              <>
                <Tbl headers={['Nivel','f','%','% Acumulado']} rows={sa(r.analisis_descriptivo.distribution).map((d:any)=>[
                  <span className={`font-bold ${d.nivel==='Alto'?'text-green-600':d.nivel==='Bajo'?'text-red-600':'text-amber-600'}`}>{dt(d.nivel)}</span>,
                  d.f, d.pct+'%', d.pct_ac+'%'
                ])} />
                <div className="mt-4 grid grid-cols-3 gap-3">
                  {sa(r.analisis_descriptivo.distribution).map((d:any,i:number)=>{
                    const maxF = Math.max(...sa(r.analisis_descriptivo.distribution).map((x:any)=>x.f), 1);
                    const heightPct = Math.round((d.f/maxF)*100);
                    const barColor = d.nivel==='Alto'?'bg-emerald-500':d.nivel==='Bajo'?'bg-red-400':'bg-amber-400';
                    return (
                      <div key={i} className="flex flex-col items-center">
                        <p className="text-xs font-bold text-slate-600 mb-1">{d.pct}%</p>
                        <div className="w-full bg-slate-100 rounded-lg flex items-end" style={{height:'120px'}}>
                          <div className={`w-full rounded-lg ${barColor}`} style={{height: heightPct+'%'}}></div>
                        </div>
                        <p className="text-xs font-semibold text-slate-700 mt-2">{dt(d.nivel)}</p>
                        <p className="text-xs text-slate-400">f={d.f}</p>
                      </div>
                    );
                  })}
                </div>
              </>
            )}
            {r.analisis_descriptivo.texto_niveles && <p className="text-sm text-slate-700 mt-4 italic">{dt(r.analisis_descriptivo.texto_niveles)}</p>}
          </Section>

          {sa(r.analisis_descriptivo.percentiles).length>0&&(
            <Section title="Percentiles" icon={Activity} color="indigo" defaultOpen={false}>
              <Tbl headers={['Percentil','Puntaje']} rows={sa(r.analisis_descriptivo.percentiles).map((p:any)=>[dt(p.percentile),p.value])} />
            </Section>
          )}
        </div>
      )}

      {/* REGRESION */}
      {tab==='regresion' && r.regression && (
        <div className="space-y-4">
          <Section title={`Regresión ${r.regression.k===1?'simple':'múltiple'}`} icon={TrendingUp} color="indigo">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {([{label:'R',value:r.regression.R},{label:'R²',value:`${r.regression.R2} (${r.regression.R2_interpret})`},{label:'R² ajustado',value:r.regression.R2_adj},{label:'F',value:`${r.regression.F} (p ${r.regression.p_apa})`}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            <div className={`rounded-xl p-4 border ${r.regression.significant?'bg-green-50 border-green-200':'bg-slate-50 border-slate-200'}`}>
              <p className="font-semibold">{dt(r.regression.decision)}</p>
              <p className="text-xs text-slate-500 mt-1">n = {r.regression.n} | SE = {r.regression.SE_est}</p>
            </div>
          </Section>
          <Section title="Coeficientes" icon={TrendingUp} color="teal">
            <Tbl headers={['Variable','B','SE','β','t','p','IC inf','IC sup','Sig.']}
              rows={sa(r.regression.coefficients).map((c:any)=>[<span className="font-semibold">{c.term}</span>,c.B,c.SE,c.beta??'-',c.t,`p ${c.p_apa}`,c.ci_lower,c.ci_upper,<span className={c.significant?'text-green-600 font-bold':'text-slate-400'}>{c.significant?'*':''}</span>])} />
          </Section>
          {sa(r.regression.vif).length>0&&(
            <Section title="VIF — Multicolinealidad" icon={Shield} color="amber">
              <Tbl headers={['Variable','VIF','Interpretación']}
                rows={sa(r.regression.vif).map((v:any)=>[v.term,<span className={v.vif>=5?'text-red-600 font-bold':'text-green-600'}>{v.vif}</span>,v.interpretation])} />
            </Section>
          )}
          {r.regression.assumptions&&(
            <Section title="Verificación de supuestos" icon={Activity} color="blue">
              {(()=>{
                const a=r.regression.assumptions;
                const rows=[
                  {label:'Normalidad residuos (SW)',result:`W = ${a.normality_residuals?.W}, p = ${a.normality_residuals?.p}`,ok:a.normality_residuals?.ok,text:a.normality_residuals?.interpretation},
                  {label:'Independencia (Durbin-Watson)',result:`DW = ${a.independence?.dw}`,ok:a.independence?.ok,text:a.independence?.interpretation},
                  {label:'Homocedasticidad (Breusch-Pagan)',result:`p = ${a.homoscedasticity?.p}`,ok:a.homoscedasticity?.ok,text:a.homoscedasticity?.interpretation},
                  {label:'Outliers influyentes (Cook)',result:`n = ${a.influential_cases?.n_outliers}`,ok:a.influential_cases?.ok,text:a.influential_cases?.interpretation},
                  {label:'Especificación (RESET)',result:`p = ${a.model_specification?.p}`,ok:a.model_specification?.ok,text:a.model_specification?.interpretation},
                ];
                return <Tbl headers={['Supuesto','Resultado','Estado']} rows={rows.map(r=>[r.label,r.result,<span className={r.ok?'text-green-600':'text-red-600 font-semibold'}>{r.text}</span>])}/>;
              })()}
            </Section>
          )}
        </div>
      )}

      {/* LOGISTICA */}
      {tab==='logistica' && r.logistic && (
        <div className="space-y-4">
          <Section title={`Regresión logística ${r.logistic.test_type==='logistica_binaria'?'binaria':'ordinal'}`} icon={TrendingUp} color="purple">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {([{label:'R² Nagelkerke',value:`${r.logistic.r2_nagelkerke} (${r.logistic.r2_interpret})`},{label:'R² Cox-Snell',value:r.logistic.r2_cox_snell},{label:'-2LL ratio',value:r.logistic.ll_ratio},{label:'p-valor',value:`p ${r.logistic.p_apa}`}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            <div className={`rounded-xl p-4 border ${r.logistic.significant?'bg-green-50 border-green-200':'bg-slate-50 border-slate-200'}`}>
              <p className="font-semibold">{dt(r.logistic.decision)}</p>
            </div>
          </Section>
          <Section title="Coeficientes y Odds Ratio" icon={TrendingUp} color="teal">
            <Tbl headers={['Variable','B','SE','Wald','p','OR','IC OR inf','IC OR sup','Sig.']}
              rows={sa(r.logistic.coefficients).map((c:any)=>[<span className="font-semibold">{c.term}</span>,c.B,c.SE,c.Wald,`p ${c.p_apa}`,<span className="font-bold text-indigo-700">{c.OR}</span>,c.OR_ci_lower,c.OR_ci_upper,<span className={c.significant?'text-green-600 font-bold':'text-slate-400'}>{c.significant?'*':''}</span>])} />
          </Section>
          {r.logistic.hosmer_lemeshow&&(
            <Section title="Hosmer-Lemeshow" icon={Shield} color="green">
              <div className="grid grid-cols-3 gap-3">
                {([{label:'χ²',value:r.logistic.hosmer_lemeshow.chi2},{label:'gl',value:r.logistic.hosmer_lemeshow.df},{label:'p-valor',value:r.logistic.hosmer_lemeshow.p}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
              </div>
              <p className={`text-sm font-semibold ${r.logistic.hosmer_lemeshow.ok?'text-green-600':'text-red-600'}`}>{r.logistic.hosmer_lemeshow.interpretation}</p>
            </Section>
          )}
          {r.logistic.classification&&(
            <Section title="Tabla de clasificación" icon={BarChart2} color="amber">
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {([{label:'Accuracy',value:`${r.logistic.classification.overall_pct}%`},{label:'Sensibilidad',value:r.logistic.classification.sensitivity},{label:'Especificidad',value:r.logistic.classification.specificity},{label:'Punto corte',value:'0.50'}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
              </div>
            </Section>
          )}
        </div>
      )}

      {/* CHI-CUADRADO */}
      {tab==='chi' && r.chi_square && (
        <div className="space-y-4">
          <Section title={`Chi-cuadrado — ${r.chi_square.method_used}`} icon={Activity} color="purple">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {([{label:'χ²',value:r.chi_square.chi2},{label:`gl = ${r.chi_square.df}`,value:`p ${r.chi_square.p_apa}`},{label:'V de Cramer',value:r.chi_square.v_cramer},{label:'Tamaño efecto',value:r.chi_square.v_interpret}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            {r.chi_square.phi&&<p className="text-sm text-slate-600">Phi = {r.chi_square.phi} | n = {r.chi_square.n} | Tabla {r.chi_square.r}×{r.chi_square.c}</p>}
            {r.chi_square.chi2_yates && typeof r.chi_square.chi2_yates === 'number' && <p className="text-sm text-slate-600">χ² Yates = {r.chi_square.chi2_yates} | p = {r.chi_square.p_yates}</p>}
            {r.chi_square.p_fisher && typeof r.chi_square.p_fisher === 'number' && <p className="text-sm text-slate-600">Fisher exacto: p = {r.chi_square.p_fisher}{typeof r.chi_square.or_fisher === 'number' ? ` | OR = ${r.chi_square.or_fisher}` : ''}</p>}
            <div className={`rounded-xl p-4 border ${r.chi_square.significant?'bg-green-50 border-green-200':'bg-slate-50 border-slate-200'}`}>
              <p className="font-semibold">{dt(r.chi_square.decision)}</p>
              <p className="text-xs text-slate-500 mt-1">{r.chi_square.assumption_note}</p>
            </div>
          </Section>
          {sa(r.chi_square.contingency_table).length>0&&(
            <Section title="Tabla de contingencia" icon={BarChart2} color="teal">
              {(()=>{
                const rows=sa(r.chi_square.row_names);
                const cols=sa(r.chi_square.col_names);
                const cells=sa(r.chi_square.contingency_table);
                const getCell=(row:string,col:string)=>cells.find((c:any)=>c.row===row&&c.col===col);
                return (
                  <div className="overflow-x-auto rounded-xl border border-slate-200">
                    <table className="w-full text-sm">
                      <thead className="bg-slate-50 border-b border-slate-200"><tr>
                        <th className="px-3 py-2"></th>
                        {cols.map((col:string)=><th key={col} className="px-3 py-2 text-center font-semibold text-slate-600">{col}</th>)}
                        <th className="px-3 py-2 text-center font-semibold text-slate-600">Total</th>
                      </tr></thead>
                      <tbody>
                        {rows.map((row:string,i:number)=>(
                          <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                            <td className="px-3 py-2 font-semibold text-slate-800">{row}</td>
                            {cols.map((col:string)=>{const cell=getCell(row,col);return <td key={col} className="px-3 py-2 text-center"><div className="font-medium">{cell?.observed??0}</div><div className="text-xs text-slate-400">({cell?.expected??0})</div></td>;})}
                            <td className="px-3 py-2 text-center font-semibold text-indigo-700">{cols.reduce((s:number,col:string)=>{const c=getCell(row,col);return s+(c?.observed??0);},0)}</td>
                          </tr>
                        ))}
                        <tr className="bg-slate-50 border-t border-slate-200">
                          <td className="px-3 py-2 font-semibold">Total</td>
                          {cols.map((col:string)=><td key={col} className="px-3 py-2 text-center font-semibold">{rows.reduce((s:number,row:string)=>{const c=getCell(row,col);return s+(c?.observed??0);},0)}</td>)}
                          <td className="px-3 py-2 text-center font-bold text-indigo-700">{r.chi_square.n}</td>
                        </tr>
                      </tbody>
                    </table>
                    <p className="text-xs text-slate-400 p-3">Observadas. Entre paréntesis: esperadas.</p>
                  </div>
                );
              })()}
            </Section>
          )}
        </div>
      )}

      {/* INSTRUMENTOS */}
      {tab === 'instrumentos' && r.instruments && (
        <div className="space-y-4 animate-fade-in">

          {/* KMO + Bartlett */}
          {r.instruments.kmo && (
            <Section title="KMO y Prueba de Bartlett" icon={Shield} color="indigo">
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {([
                  {label:'KMO', value: r.instruments.kmo.kmo_overall},
                  {label:'Interpretación', value: r.instruments.kmo.kmo_interpret},
                  {label:'Bartlett χ²', value: r.instruments.kmo.bartlett_chi2},
                  {label:'p-valor', value: `p ${r.instruments.kmo.bartlett_p_apa}`},
                ] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
              </div>
              <div className={`rounded-xl p-4 border ${r.instruments.kmo.factorizable?'bg-green-50 border-green-200':'bg-red-50 border-red-200'}`}>
                <p className="font-semibold text-sm">{r.instruments.kmo.factorizable ? '✅ Datos factorizables — Procede con AFE/AFC' : '❌ Datos no factorizables — Revisar instrumento'}</p>
              </div>
            </Section>
          )}

          {/* Normalidad por ítem */}
          {r.instruments.normality?.por_item && (
            <Section title="Normalidad por ítem (Asimetría y Curtosis)" icon={Activity} color="blue">
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200">
                    <tr>{['Ítem','n','M','DE','Asimetría','Curtosis','Estado'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600">{h}</th>)}</tr>
                  </thead>
                  <tbody>
                    {sa(r.instruments.normality?.por_item).sort((a:any,b:any)=>{ const n=(s:string)=>parseInt(s.replace(/\D/g,'')); return n(a.item)-n(b.item); }).map((row:any,i:number)=>(
                      <tr key={i} className={`border-b border-slate-100 ${row.no_normal?'bg-amber-50':''}`}>
                        <td className="px-3 py-2 font-semibold">{row.item}</td>
                        <td className="px-3 py-2">{row.n}</td>
                        <td className="px-3 py-2">{row.media}</td>
                        <td className="px-3 py-2">{row.de}</td>
                        <td className={`px-3 py-2 ${Math.abs(row.skewness)>2?'text-red-600 font-semibold':''}`}>{row.skewness}</td>
                        <td className={`px-3 py-2 ${Math.abs(row.kurtosis)>7?'text-red-600 font-semibold':''}`}>{row.kurtosis}</td>
                        <td className="px-3 py-2"><span className={row.no_normal?'text-amber-600 font-semibold':'text-green-600'}>{row.no_normal?'⚠️ Revisar':'✓ Normal'}</span></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {r.instruments.normality.mardia_skew != null && (
                <div className="bg-slate-50 rounded-xl p-4 border border-slate-200 text-sm">
                  <p className="font-semibold mb-1">Normalidad multivariante de Mardia</p>
                  <p>Asimetría: {r.instruments.normality.mardia_skew} (p = {r.instruments.normality.mardia_skew_p})</p>
                  <p>Curtosis: {r.instruments.normality.mardia_kurt} (p = {r.instruments.normality.mardia_kurt_p})</p>
                  <p className="mt-2 font-semibold text-indigo-700">{r.instruments.normality.recommend_mlr ? '→ Se recomienda estimador MLR en AFC' : '→ Estimador ML apropiado'}</p>
                </div>
              )}
            </Section>
          )}

          {/* Confiabilidad */}
          {r.instruments.reliability && Object.keys(r.instruments.reliability).length > 0 && (
            <Section title="Confiabilidad — Cronbach · Omega · CR · AVE" icon={Shield} color="purple">
              <div className="space-y-4">
                {sa(Object.values(r.instruments.reliability||{})).map((rel:any, i:number) => (
                  <div key={i} className={`rounded-xl border-2 p-4 ${rel.alpha>=.90?'border-green-300 bg-green-50':rel.alpha>=.70?'border-amber-300 bg-amber-50':'border-red-300 bg-red-50'}`}>
                    <p className="font-bold text-slate-800 mb-2">{dt(String(rel.name||""))}</p>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-3">
                      {([
                        {label:'α Cronbach', value:`${rel.alpha} — ${rel.interpretation}`},
                        {label:'ω McDonald', value:rel.omega??'-'},
                        {label:'IC 95%', value:`[${rel.ci_lower}, ${rel.ci_upper}]`},
                        {label:'r̄ inter-ítem', value:rel.inter_item??'-'},
                      ] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
                    </div>
                    {/* Item-total table */}
                    {sa(rel.item_stats).length > 0 && (
                      <div className="overflow-x-auto rounded-xl border border-slate-200 mt-2">
                        <table className="w-full text-xs">
                          <thead className="bg-slate-50 border-b border-slate-200">
                            <tr>{['Ítem','M','DE','r ítem-total corr.','α si elimina'].map(h=><th key={h} className="px-3 py-1.5 text-left font-semibold text-slate-600">{h}</th>)}</tr>
                          </thead>
                          <tbody>
                            {sa(rel.item_stats).filter((it:any)=>typeof it==='object'&&it!==null).sort((a:any,b:any)=>{ const n=(s:string)=>parseInt(s.replace(/\D/g,'')); return n(a.item)-n(b.item); }).filter((it:any)=>typeof it==='object'&&it!==null&&!Array.isArray(it)).map((it:any,j:number)=>(
                              <tr key={j} className={`border-b border-slate-100 ${it.alpha_drop>rel.alpha?'bg-amber-50':''}`}>
                                <td className="px-3 py-1.5 font-bold">{it.item}</td>
                                <td className="px-3 py-1.5">{it.mean}</td>
                                <td className="px-3 py-1.5">{it.sd}</td>
                                <td className={`px-3 py-1.5 font-semibold ${it.r_cor<0.3?'text-red-600':''}`}>{it.r_cor}</td>
                                <td className={`px-3 py-1.5 ${it.alpha_drop>rel.alpha?'text-amber-600 font-semibold':''}`}>{it.alpha_drop}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </Section>
          )}

          {/* AFE */}
          {r.instruments.afe && !r.instruments.afe.error && (
            <Section title={`AFE — ${r.instruments.afe.n_factors} factor(es) · Rotación ${r.instruments.afe.rotation}`} icon={BarChart2} color="teal">
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {([
                  {label:'Factores sugeridos (AP)', value:r.instruments.afe.n_factors_pa},
                  {label:'Factores usados', value:r.instruments.afe.n_factors},
                  {label:'RMSEA', value:r.instruments.afe.rmsea},
                  {label:'TLI', value:r.instruments.afe.tli},
                ] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
              </div>
              {/* Loadings table */}
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200">
                    <tr>
                      <th className="px-3 py-2 text-left font-semibold text-slate-600">Ítem</th>
                      {Array.from({length: r.instruments.afe?.n_factors||1}).map((_,i) => (
                        <th key={i} className="px-3 py-2 text-center font-semibold text-slate-600">F{i+1}</th>
                      ))}
                      <th className="px-3 py-2 text-center font-semibold text-slate-600">h²</th>
                    </tr>
                  </thead>
                  <tbody>
                    {sa(r.instruments.afe?.loadings).sort((a:any,b:any)=>{ const n=(s:string)=>parseInt(s.replace(/\D/g,'')); return n(a.item)-n(b.item); }).map((row:any,i:number)=>(
                      <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                        <td className="px-3 py-2 font-semibold">{row.item}</td>
                        {Array.from({length: r.instruments.afe?.n_factors||1}).map((_,j) => {
                          const val = row[`F${j+1}`] ?? 0;
                          return <td key={j} className={`px-3 py-2 text-center font-medium ${Math.abs(val)>=0.4?'text-indigo-700 font-bold':'text-slate-400'}`}>{val}</td>;
                        })}
                        <td className="px-3 py-2 text-center">{row.h2}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {/* Variance explained */}
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200">
                    <tr>{['Factor','SS Cargas','% Varianza','% Acumulado'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600">{h}</th>)}</tr>
                  </thead>
                  <tbody>
                    {sa(r.instruments.afe?.variance).map((row:any,i:number)=>(
                      <tr key={i} className="border-b border-slate-100">
                        <td className="px-3 py-2 font-semibold">{row.factor}</td>
                        <td className="px-3 py-2">{row.ss_load}</td>
                        <td className="px-3 py-2">{row.pct_var}%</td>
                        <td className="px-3 py-2 font-semibold text-indigo-700">{row.cum_var}%</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Section>
          )}

          {/* AFC */}
          {r.instruments.afc && !r.instruments.afc.error && (
            <Section title="AFC — Análisis Factorial Confirmatorio" icon={TrendingUp} color="green">
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200">
                    <tr>{['Índice','Valor','Criterio','Evaluación'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600">{h}</th>)}</tr>
                  </thead>
                  <tbody>
                    {sa(r.instruments.afc?.fit_table).map((row:any,i:number)=>(
                      <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                        <td className="px-3 py-2 font-semibold">{dt(row.indice)}</td>
                        <td className="px-3 py-2 font-bold text-indigo-700">{row.valor}</td>
                        <td className="px-3 py-2 text-slate-500">{dt(String(row.criterio||""))}</td>
                        <td className="px-3 py-2">
                          <span className={`font-semibold ${row.eval==='Excelente'||row.eval==='✓'?'text-green-600':row.eval==='Aceptable'?'text-amber-600':row.eval==='Deficiente'||row.eval==='✗'?'text-red-600':'text-slate-500'}`}>{row.eval}</span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className={`rounded-xl p-4 border ${r.instruments.afc.ajuste_global==='excelente'?'bg-green-50 border-green-200':r.instruments.afc.ajuste_global==='aceptable'?'bg-amber-50 border-amber-200':'bg-red-50 border-red-200'}`}>
                <p className="font-semibold">Ajuste global: {r.instruments.afc.ajuste_global}</p>
                <p className="text-xs text-slate-500 mt-1">Estimador: {r.instruments.afc.estimator} | n = {r.instruments.afc.n}</p>
              </div>
              {/* Cargas estandarizadas */}
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200">
                    <tr>{['Factor','Ítem','λ std','SE','z','p','Estado'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600">{h}</th>)}</tr>
                  </thead>
                  <tbody>
                    {sa(r.instruments.afc?.loadings).sort((a:any,b:any)=>{ const n=(s:string)=>parseInt(s.replace(/\D/g,'')); return n(a.item)-n(b.item); }).map((row:any,i:number)=>(
                      <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                        <td className="px-3 py-2 font-semibold text-indigo-700">{row.factor}</td>
                        <td className="px-3 py-2 font-semibold">{row.item}</td>
                        <td className={`px-3 py-2 font-bold ${Math.abs(row.lambda)>=0.5?'text-green-700':'text-red-600'}`}>{row.lambda}</td>
                        <td className="px-3 py-2 text-slate-500">{row.se}</td>
                        <td className="px-3 py-2">{row.z}</td>
                        <td className="px-3 py-2">{row.p_apa}</td>
                        <td className="px-3 py-2"><span className={row.ok?'text-green-600':'text-red-600'}>{row.ok?'✓':'⚠️'}</span></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Section>
          )}

          {/* HTMT */}
          {r.instruments.htmt && !r.instruments.htmt.error && sa(r.instruments.htmt.pairs).length > 0 && (
            <Section title={`HTMT — Validez Discriminante (Bootstrap n=${r.instruments.htmt.n_boot})`} icon={Activity} color="amber">
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200">
                    <tr>{['Par de constructos','HTMT','IC 95% inf','IC 95% sup','Veredicto'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600">{h}</th>)}</tr>
                  </thead>
                  <tbody>
                    {sa(r.instruments.htmt?.pairs).map((row:any,i:number)=>(
                      <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                        <td className="px-3 py-2 font-semibold">{dt(row.par)}</td>
                        <td className={`px-3 py-2 font-bold ${row.ok?'text-green-700':'text-red-600'}`}>{row.htmt}</td>
                        <td className="px-3 py-2 text-slate-500">{row.ic_low}</td>
                        <td className="px-3 py-2 text-slate-500">{row.ic_high}</td>
                        <td className="px-3 py-2"><span className={row.ok?'text-green-600 font-semibold':'text-red-600 font-semibold'}>{dt(String(row.verdict||'')).replace('x','✗')}</span></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <p className="text-xs text-slate-500">Criterio: HTMT {'<'} .85 indica validez discriminante (Henseler et al., 2015)</p>
            </Section>
          )}

        </div>
      )}

      <div className="flex justify-between pt-4">
        <button onClick={onBack} className="flex items-center gap-2 text-slate-600 hover:text-slate-800 font-medium px-5 py-2.5 rounded-xl border border-slate-300 hover:bg-slate-50 transition-all">
          <ChevronLeft className="w-4 h-4"/> Atrás
        </button>
        <button onClick={onNext} className="flex items-center gap-2 bg-blue-700 hover:bg-blue-800 text-white font-semibold px-7 py-3 rounded-xl transition-all">
          Exportar resultados <ChevronRight className="w-4 h-4"/>
        </button>
      </div>
    </div>
  );
}
