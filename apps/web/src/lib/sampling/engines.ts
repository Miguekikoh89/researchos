// ══════════════════════════════════════════════════════════════════════════════
// CanchariOS — Sampling Decision Engines
// Basado en: Cochran (1977), Cohen (1988), Hair et al. (2022),
// Kock & Hadaya (2018), Faul et al. (2007), Krejcie & Morgan (1970)
// ══════════════════════════════════════════════════════════════════════════════

// ── Tipos ────────────────────────────────────────────────────────────────────
export interface SamplingState {
  // Paso 1 — Tipo de estudio
  enfoque: string;
  alcance: string;
  diseño: string;
  // Paso 2 — Objetivo
  objetivo: string;
  analisis: string;
  // PLS-SEM params
  itemsMax: number;
  flechasMax: number;
  constructosN: number;
  // Otros análisis
  predictores: number;
  f2: number;
  grupos: number;
  fAnova: number;
  rEsp: number;
  cohenD: number;
  // Paso 3 — Población
  tipoPob: string;
  nPobl: number;
  tamConocido: string;
  ubicacion: string;
  periodo: string;
  unidadAnalisis: string;
  // Paso 4 — Marco muestral
  padron: string;
  estratos: string;
  // Paso 5 — Accesibilidad
  accesibilidad: string;
  // Paso 6 — Muestreo
  tecnicaCual: string;
  // Paso 7 — Parámetros
  z: number;
  e: number;
  p: number;
  tasaNoResp: number;
  // Paso 8 — Criterios
  inclusion: string;
  exclusion: string;
  sesgos: string[];
}

export const INIT_STATE: SamplingState = {
  enfoque:'', alcance:'', diseño:'',
  objetivo:'', analisis:'',
  itemsMax:0, flechasMax:0, constructosN:0,
  predictores:3, f2:0.15,
  grupos:3, fAnova:0.25,
  rEsp:0.3, cohenD:0.5,
  tipoPob:'', nPobl:0, tamConocido:'', ubicacion:'', periodo:'', unidadAnalisis:'',
  padron:'', estratos:'ninguno',
  accesibilidad:'',
  tecnicaCual:'',
  z:1.96, e:0.05, p:0.5, tasaNoResp:0.15,
  inclusion:'', exclusion:'', sesgos:[],
};

// ── Calculadoras ──────────────────────────────────────────────────────────────
export const cochranInf = (z:number,e:number,p:number) => Math.ceil((z*z*p*(1-p))/(e*e));
export const cochranFin = (z:number,e:number,p:number,N:number) => {
  const n0 = cochranInf(z,e,p);
  return Math.ceil(n0/(1+(n0-1)/N));
};

export const krejcieMorgan = (N:number): number => {
  const t:[number,number][] = [
    [10,10],[15,14],[20,19],[25,24],[30,28],[35,32],[40,36],[45,40],[50,44],
    [55,48],[60,52],[65,56],[70,59],[75,63],[80,66],[85,70],[90,73],[95,76],
    [100,80],[110,86],[120,92],[130,97],[140,103],[150,108],[160,113],[170,118],
    [180,123],[190,127],[200,132],[220,140],[240,148],[260,155],[280,162],
    [300,169],[320,175],[340,181],[360,186],[380,191],[400,196],[420,201],
    [440,205],[460,210],[480,214],[500,217],[550,226],[600,234],[650,242],
    [700,248],[750,254],[800,260],[900,269],[1000,278],[1200,291],[1500,306],
    [2000,322],[3000,341],[5000,357],[10000,370],[20000,377],[50000,381],[100000,384],
  ];
  if(N<=10) return N;
  for(let i=t.length-1;i>=0;i--) if(N>=t[i][0]) return t[i][1];
  return 384;
};

// G*Power: regresión múltiple (Faul et al., 2007)
export const gPowerReg = (u:number, f2:number) =>
  Math.max(Math.ceil(u + 1 + (u+1)/f2 * 0.87 + 3), u*15);

// G*Power: ANOVA (Cohen, 1988)
export const gPowerAnova = (k:number, f:number) =>
  Math.ceil(k * Math.ceil(2.48/(f*f)+2));

// G*Power: correlación
export const gPowerCorr = (r:number) =>
  Math.ceil(Math.pow((1.96+0.842)/(0.5*Math.log((1+r)/(1-r))),2)+3);

// G*Power: t-test independiente
export const gPowerT = (d:number) =>
  Math.ceil(2*Math.pow((1.96+0.842)/d,2));

// PLS-SEM: Inverse Square Root Method (Kock & Hadaya, 2018)
export const inverseSquareRoot = (flechas:number): number => {
  // n mínimo = 1 / (sqrt(e) * sqrt(1-r²)) donde e ≈ 0.05 y r² ≈ efecto medio
  // Aproximación práctica: n ≥ (1.645/sqrt(alpha)) / sqrt(f²) + u
  return Math.ceil(2.486 / Math.sqrt(0.1) + flechas + 1);
};

// PLS-SEM: Gamma-Exponential Method (Kock & Hadaya, 2018)
export const gammaExponential = (flechas:number): number => {
  // Aproximación para α=0.05, power=0.80
  return Math.ceil(Math.pow(2.486/Math.sqrt(0.1), 2) / flechas + flechas*2);
};

// ── PopulationDecisionEngine ─────────────────────────────────────────────────
export interface PopDecision {
  tipoPoblacion: string;
  esFinita: boolean;
  esCenso: boolean;
  razon: string;
  ref: string;
  advertencia?: string;
}

export function populationDecisionEngine(s: SamplingState): PopDecision {
  if(s.nPobl>0 && s.nPobl<=100) return {
    tipoPoblacion:'Finita y pequeña',
    esFinita:true, esCenso:true,
    razon:`La población es pequeña (N = ${s.nPobl} ≤ 100 elementos) y accesible. Metodológicamente corresponde aplicar un censo para eliminar el error muestral.`,
    ref:'Hernández-Sampieri (2018); Kish (1965)',
  };
  if(s.tamConocido==='desconocido'||s.tamConocido==='') return {
    tipoPoblacion:'Indeterminada / Infinita',
    esFinita:false, esCenso:false,
    razon:'La población es indeterminada o de tamaño desconocido. Se aplica la fórmula de Cochran para población infinita como caso más conservador.',
    ref:'Cochran (1977)',
    advertencia:'Al trabajar con población indeterminada, los resultados tienen validez para la muestra estudiada. La generalización requiere cautela.',
  };
  if(s.nPobl>100) return {
    tipoPoblacion:`Finita (N = ${s.nPobl})`,
    esFinita:true, esCenso:false,
    razon:`La población es finita y conocida (N = ${s.nPobl}). Se aplicará la fórmula de Cochran con corrección por población finita.`,
    ref:'Cochran (1977); Krejcie & Morgan (1970)',
  };
  return {
    tipoPoblacion:'No definida',
    esFinita:false, esCenso:false,
    razon:'Defina el tamaño de la población para obtener una recomendación precisa.',
    ref:'',
  };
}

// ── SamplingDecisionEngine ───────────────────────────────────────────────────
export interface SamplingDecision {
  tipoMuestreo: string;
  tecnica: string;
  detalle: string;
  ref: string;
  advertencia?: string;
}

export function samplingDecisionEngine(s: SamplingState): SamplingDecision {
  if(s.enfoque==='cualitativo') {
    const map: Record<string,{tecnica:string,detalle:string}> = {
      propositivo: {tecnica:'Muestreo propositivo / intencional', detalle:'Selección deliberada de casos con capacidad informativa máxima para el fenómeno.'},
      bola_nieve: {tecnica:'Muestreo bola de nieve', detalle:'Participantes iniciales refieren a nuevos participantes con el perfil requerido.'},
      teorico: {tecnica:'Muestreo teórico', detalle:'Selección guiada por las categorías emergentes del análisis (Grounded Theory).'},
      criterio: {tecnica:'Muestreo por criterio', detalle:'Todos los casos cumplen criterios predefinidos relevantes al estudio.'},
      maximo: {tecnica:'Máxima variación', detalle:'Selección de casos muy diferentes para capturar la diversidad del fenómeno.'},
    };
    const t = map[s.tecnicaCual]||map['propositivo'];
    return { tipoMuestreo:'No probabilístico', ...t, ref:'Patton (2015); Maxwell (2013); Creswell (2013)' };
  }
  if(s.tipoPob==='oculta') return {
    tipoMuestreo:'No probabilístico',
    tecnica:'Bola de nieve (Snowball sampling)',
    detalle:'Para poblaciones sin marco muestral o de difícil localización. Los participantes iniciales refieren a nuevos participantes.',
    ref:'Heckathorn (1997); Etikan et al. (2016)',
    advertencia:'Al no existir marco muestral completo, los resultados no deben generalizarse estadísticamente.',
  };
  if(s.padron==='si') {
    if(s.estratos&&s.estratos!=='ninguno') return {
      tipoMuestreo:'Probabilístico',
      tecnica:'Muestreo estratificado proporcional',
      detalle:`La población se divide en estratos homogéneos. Asignación proporcional: nᵢ = n × (Nᵢ/N). Garantiza representación de cada subgrupo (${s.estratos}).`,
      ref:'Cochran (1977); Lohr (2010); Kish (1965)',
    };
    return {
      tipoMuestreo:'Probabilístico',
      tecnica:'Muestreo aleatorio simple (MAS)',
      detalle:'Cada elemento tiene igual probabilidad π = n/N de selección. Requiere listado completo numerado.',
      ref:'Cochran (1977); Kish (1965)',
    };
  }
  if(s.padron==='sistematico') return {
    tipoMuestreo:'Probabilístico',
    tecnica:'Muestreo sistemático',
    detalle:'Se selecciona cada k-ésimo elemento (k = N/n). Simple y práctico con listados extensos.',
    ref:'Cochran (1977); Lohr (2010)',
  };
  if(s.padron==='parcial') return {
    tipoMuestreo:'Probabilístico',
    tecnica:'Muestreo por conglomerados',
    detalle:'Se seleccionan grupos (conglomerados) y se encuesta a sus integrantes. Útil sin listado completo pero con grupos identificables.',
    ref:'Kish (1965); Cochran (1977)',
  };
  return {
    tipoMuestreo:'No probabilístico',
    tecnica:'Muestreo por conveniencia con criterios',
    detalle:'Sin marco muestral disponible. Se requieren criterios de inclusión/exclusión estrictos para controlar sesgos de selección.',
    ref:'Hernández-Sampieri (2018); Saunders et al. (2019)',
    advertencia:'Al no existir marco muestral completo, los resultados no deben generalizarse estadísticamente a toda la población objetivo.',
  };
}

// ── SampleSizeDecisionEngine ─────────────────────────────────────────────────
export interface SizeRoute {
  ruta: string;
  label: string;
  razon: string;
  ref: string;
}

export function sampleSizeRoute(s: SamplingState): SizeRoute {
  if(s.enfoque==='cualitativo') return {
    ruta:'saturacion',
    label:'Saturación teórica',
    razon:'En investigación cualitativa el tamaño no se determina estadísticamente. Se continúa seleccionando hasta que los datos no aportan nuevas categorías.',
    ref:'Morse (1995); Patton (2015); Lincoln & Guba (1985)',
  };
  if(s.nPobl>0&&s.nPobl<=100) return {
    ruta:'censo',
    label:'Censo',
    razon:`N = ${s.nPobl} ≤ 100. El censo elimina el error muestral y no requiere cálculo estadístico.`,
    ref:'Hernández-Sampieri (2018)',
  };
  if(s.analisis==='pls_sem') return {
    ruta:'pls_sem',
    label:'PLS-SEM (Hair et al., 2022 + Kock & Hadaya, 2018)',
    razon:'Los modelos PLS-SEM requieren criterios específicos: G*Power, Inverse Square Root e Gamma-Exponential. Se adopta el más conservador.',
    ref:'Hair et al. (2022); Kock & Hadaya (2018); Faul et al. (2007)',
  };
  if(s.analisis==='cb_sem') return {
    ruta:'cb_sem',
    label:'CB-SEM (Tabachnick & Fidell, 2013)',
    razon:'CB-SEM requiere n ≥ 200 mínimo y n ≥ 300 para modelos complejos, independientemente de la fórmula de Cochran.',
    ref:'Tabachnick & Fidell (2013); Bentler & Chou (1987)',
  };
  if(['regresion','correlacion','anova','ttest','comparacion','logistica','manova'].includes(s.analisis)) return {
    ruta:'potencia',
    label:'Potencia estadística — G*Power (Cohen, 1988)',
    razon:'Cuando el objetivo es probar hipótesis inferenciales, la muestra debe garantizar potencia estadística ≥ 0.80 para detectar el efecto esperado.',
    ref:'Cohen (1988); Faul et al. (2007) G*Power 3.1',
  };
  return {
    ruta:'representatividad',
    label:'Representatividad — Cochran (1977)',
    razon:'Para estudios descriptivos o de prevalencia, el objetivo es estimar características poblacionales con precisión, no detectar efectos.',
    ref:'Cochran (1977); Krejcie & Morgan (1970); Lohr (2010)',
  };
}

// ── PLSSampleSizeEngine ───────────────────────────────────────────────────────
export interface PLSResult {
  gPower: number;
  inverseRoot: number;
  gammaExp: number;
  regla10x: number;
  conservador: number;
  metodo: string;
}

export function plsSampleSizeEngine(flechas:number, items:number): PLSResult {
  const gp = gPowerReg(flechas||4, 0.15);
  const ir = inverseSquareRoot(flechas||4);
  const ge = gammaExponential(flechas||4);
  const r10 = items*10;
  const conservador = Math.max(gp, ir, ge, r10, 100);
  return {
    gPower: gp,
    inverseRoot: ir,
    gammaExp: ge,
    regla10x: r10,
    conservador,
    metodo: conservador===gp?'G*Power':conservador===ir?'Inverse Square Root':conservador===ge?'Gamma-Exponential':'Regla 10×',
  };
}

// ── Cálculo final ─────────────────────────────────────────────────────────────
export interface CalcResult {
  nCochran: number;
  nKM?: number;
  nGPower?: number;
  nMetodo?: number;
  nBase: number;
  nFinal: number;
  metodoLabel: string;
  pls?: PLSResult;
  ruta: SizeRoute;
}

export function calcularMuestra(s: SamplingState): CalcResult {
  const {z,e,p,nPobl,tasaNoResp,analisis,itemsMax,flechasMax,constructosN,predictores,f2,grupos,fAnova,rEsp,cohenD} = s;
  const N = nPobl>0?nPobl:0;
  const ruta = sampleSizeRoute(s);
  const nCochran = N>0?cochranFin(z,e,p,N):cochranInf(z,e,p);
  const nKM = N>0?krejcieMorgan(N):undefined;
  let nGPower:number|undefined, nMetodo:number|undefined, metodoLabel='Cochran (1977)', pls:PLSResult|undefined;

  if(ruta.ruta==='pls_sem') {
    pls = plsSampleSizeEngine(flechasMax||4, itemsMax||5);
    nMetodo = pls.conservador;
    nGPower = pls.gPower;
    metodoLabel = `PLS-SEM (${pls.metodo})`;
  } else if(ruta.ruta==='cb_sem') {
    nMetodo = constructosN>5?300:200;
    metodoLabel = 'CB-SEM (Tabachnick & Fidell)';
  } else if(ruta.ruta==='potencia') {
    if(analisis==='regresion'){nGPower=gPowerReg(predictores,f2);metodoLabel='G*Power Regresión';}
    else if(analisis==='anova'){nGPower=gPowerAnova(grupos,fAnova);metodoLabel='G*Power ANOVA';}
    else if(analisis==='correlacion'){nGPower=gPowerCorr(rEsp);metodoLabel='G*Power Correlación';}
    else if(analisis==='ttest'||analisis==='comparacion'){nGPower=gPowerT(cohenD);metodoLabel='G*Power t-test';}
    else if(analisis==='logistica'){nGPower=gPowerReg(predictores||3,f2||0.15);metodoLabel='G*Power Logística';}
    else {nGPower=gPowerReg(predictores||3,0.15);metodoLabel='G*Power (aprox.)';}
  } else {
    metodoLabel='Cochran (1977)';
  }

  const nBase = Math.max(nCochran, nGPower||0, nMetodo||0);
  const nFinal = Math.ceil(nBase*(1+tasaNoResp));
  return {nCochran,nKM,nGPower,nMetodo,nBase,nFinal,metodoLabel,pls,ruta};
}

// ── MethodologicalTextGenerator ───────────────────────────────────────────────
export function generarTextoTesis(s: SamplingState): string {
  const calc = calcularMuestra(s);
  const popDec = populationDecisionEngine(s);
  const sampDec = samplingDecisionEngine(s);
  const {z,e,p,nPobl,tasaNoResp,analisis,flechasMax,predictores,f2,grupos,fAnova,rEsp,cohenD,constructosN} = s;
  const zPct = z===1.96?'95%':z===2.576?'99%':'90%';
  const tipoPobMap:Record<string,string> = {institucional:'institucional',educativa:'educativa',clinica:'clínica y de salud',empresarial:'empresarial',comunitaria:'comunitaria',online:'en línea',oculta:'de difícil acceso',registros:'secundaria (registros administrativos)'};
  const enfoqueMap:Record<string,string> = {cuantitativo:'cuantitativo',cualitativo:'cualitativo',mixto:'mixto'};
  const alcanceMap:Record<string,string> = {exploratorio:'exploratorio',descriptivo:'descriptivo',correlacional:'correlacional',explicativo:'explicativo-causal',predictivo:'predictivo'};
  const tp = tipoPobMap[s.tipoPob]||'general';
  const ef = enfoqueMap[s.enfoque]||'cuantitativo';
  const alc = alcanceMap[s.alcance]||'';
  const ua = s.unidadAnalisis||`integrantes de la población ${tp}`;

  if(s.enfoque==='cualitativo') return `3.4. Población y muestra\n\nUnidad de análisis. La unidad de análisis de la presente investigación ${ef} de alcance ${alc} la constituyen ${ua}${s.ubicacion?`, ubicados en ${s.ubicacion}`:''} ${s.periodo?`durante el período ${s.periodo}`:''}.\n\nPoblación objetivo y accesible. La población objetivo comprende el conjunto de individuos que poseen experiencia directa con el fenómeno de estudio. La población accesible se circunscribe a aquellos participantes a quienes el investigador tiene posibilidad real de acceder y que cumplen los criterios metodológicos establecidos.\n\n${s.inclusion?`Criterios de inclusión: ${s.inclusion}.\n\n`:''}${s.exclusion?`Criterios de exclusión: ${s.exclusion}.\n\n`:''}Marco muestral. Dado el carácter cualitativo del estudio, no se construyó un marco muestral en el sentido estadístico convencional.\n\nTipo y técnica de muestreo. Se aplicó ${sampDec.tipoMuestreo.toLowerCase()}, mediante la técnica de ${sampDec.tecnica.toLowerCase()}. ${sampDec.detalle}\n\nTamaño de la muestra. En concordancia con la epistemología interpretativa, el tamaño muestral no fue determinado a priori mediante fórmulas estadísticas. Se siguió el principio de saturación teórica (Morse, 1995): el proceso de selección continuó hasta que la información dejó de aportar nuevas categorías o propiedades al análisis. Este criterio es el estándar metodológico en investigación cualitativa (Lincoln & Guba, 1985; Patton, 2015).\n\nAlcance de la generalización. Los resultados no tienen pretensión de generalización estadística. Siguiendo a Maxwell (2013), se busca transferibilidad analítica: los hallazgos pueden ser relevantes en contextos con características similares, siempre que el lector evalúe la pertinencia de dicha transferencia.\n\nReferencias: ${sampDec.ref}; Morse, J.M. (1995). The significance of saturation. Qualitative Health Research, 5(2), 147-149.`;

  if(popDec.esCenso) return `3.4. Población y muestra\n\nUnidad de análisis. La unidad de análisis corresponde a ${ua}${s.ubicacion?`, en ${s.ubicacion}`:''} ${s.periodo?`durante el período ${s.periodo}`:''}.\n\nPoblación. La población objetivo está conformada por N = ${nPobl} elementos, pertenecientes a una población de tipo ${tp}. La población accesible coincide con la población objetivo, dado que se cuenta con acceso a la totalidad de sus integrantes.\n\n${s.inclusion?`Criterios de inclusión: ${s.inclusion}.\n\n`:''}${s.exclusion?`Criterios de exclusión: ${s.exclusion}.\n\n`:''}Censo. Dado que la población es reducida (N = ${nPobl} ≤ 100 elementos) y plenamente accesible, se aplicó un censo, incorporando a la totalidad de los elementos que cumplieron los criterios de inclusión. Este procedimiento elimina el error muestral y permite obtener estimaciones exactas de los parámetros poblacionales sin necesidad de inferencia estadística (Hernández-Sampieri, 2018; Kish, 1965).\n\nAlcance de la generalización. Al trabajar con la población completa, los resultados son directamente representativos de la misma y no requieren inferencia estadística.\n\nReferencias: Hernández-Sampieri, R. (2018). Metodología de la Investigación (6ª ed.). McGraw-Hill. Kish, L. (1965). Survey Sampling. Wiley.`;

  const justSize = (() => {
    if(calc.ruta.ruta==='pls_sem'&&calc.pls) {
      const {gPower,inverseRoot,gammaExp,regla10x,conservador,metodo} = calc.pls;
      return `El tamaño mínimo de muestra fue determinado mediante un enfoque basado en potencia estadística y criterios específicos para modelos de ecuaciones estructurales por mínimos cuadrados parciales (PLS-SEM). Se aplicó un análisis de potencia mediante G*Power 3.1 (Faul et al., 2007) considerando el mayor número de predictores dirigidos hacia un constructo endógeno del modelo estructural (${flechasMax} flechas), con f² = 0.15 (efecto mediano), α = 0.05 y potencia = 0.80, obteniéndose n ≥ ${gPower}. Complementariamente, se evaluó la suficiencia muestral mediante el método Inverse Square Root (n ≥ ${inverseRoot}) y el método Gamma-Exponential (n ≥ ${gammaExp}), propuestos por Kock y Hadaya (2018). Adicionalmente, se aplicó la regla de 10× de Hair et al. (2022), que establece un mínimo de 10 observaciones por el constructo con mayor número de indicadores (${s.itemsMax} ítems → n ≥ ${regla10x}). Adoptando el criterio más conservador (${metodo}: n = ${conservador}), y considerando una tasa de no respuesta estimada del ${Math.round(tasaNoResp*100)}%, se planificó trabajar con n = ${calc.nFinal} participantes.`;
    }
    if(calc.ruta.ruta==='cb_sem') return `El tamaño muestral se justificó según los criterios para modelos de ecuaciones estructurales basados en covarianza (CB-SEM). Tabachnick & Fidell (2013) establecen n ≥ 200 como mínimo absoluto, recomendando n ≥ 300 para modelos con más de cinco constructos latentes (${constructosN} constructos). Adicionalmente, la fórmula de Cochran (1977) determina n = ${calc.nCochran}. Se adoptó n = ${calc.nBase} como criterio más conservador${calc.nFinal!==calc.nBase?`, alcanzando n = ${calc.nFinal} al incorporar la tasa de no respuesta del ${Math.round(tasaNoResp*100)}%`:''}. Referencias: Tabachnick, B.G. & Fidell, L.S. (2013). Using Multivariate Statistics (6th ed.). Pearson; Bentler, P.M. & Chou, C.P. (1987). Practical issues in structural modeling. Sociological Methods & Research, 16(1), 78-117.`;
    if(calc.ruta.ruta==='potencia') {
      const gLabel = analisis==='regresion'?`regresión múltiple con ${predictores} predictores, f² = ${f2}`:analisis==='anova'?`ANOVA con ${grupos} grupos, f = ${fAnova}`:analisis==='correlacion'?`correlación con r = ${rEsp}`:analisis==='ttest'||analisis==='comparacion'?`t de Student para muestras independientes con d = ${cohenD}`:'análisis inferencial';
      return `El tamaño muestral se determinó mediante análisis de potencia estadística con G*Power 3.1 (Faul et al., 2007): ${gLabel}, α = 0.05, potencia = 0.80, obteniéndose n ≥ ${calc.nGPower||'?'}. Adicionalmente, la fórmula de Cochran (1977) determina n = ${calc.nCochran}. Se adoptó el criterio más exigente: n = ${calc.nBase}, alcanzando n = ${calc.nFinal} al considerar la tasa de no respuesta estimada del ${Math.round(tasaNoResp*100)}%. Referencias: Cohen, J. (1988). Statistical Power Analysis for the Behavioral Sciences (2nd ed.). Lawrence Erlbaum; Faul, F., et al. (2007). G*Power 3. Behavior Research Methods, 39(2), 175-191.`;
    }
    return `El tamaño muestral se determinó mediante la fórmula de Cochran (1977) para población ${nPobl>0?'finita':'infinita'}: Z = ${z} (confianza ${zPct}), e = ${e} (error ±${Math.round(e*100)}%), p = ${p} (proporción de variabilidad), obteniéndose n = ${calc.nCochran}${nPobl>0?` (ajustado para N = ${nPobl})`:''}. ${calc.nKM?`Krejcie & Morgan (1970) recomiendan n = ${calc.nKM} para N = ${nPobl}.`:''} Se planificó trabajar con n = ${calc.nFinal} participantes, incorporando ${Math.round(tasaNoResp*100)}% adicional para compensar la tasa de no respuesta. Referencias: Cochran, W.G. (1977). Sampling Techniques (3rd ed.). Wiley.${calc.nKM?' Krejcie, R.V. & Morgan, D.W. (1970). Determining sample size for research activities. Educational and Psychological Measurement, 30(3), 607-610.':''}`;
  })();

  return `3.4. Población y muestra\n\nUnidad de análisis. La unidad de análisis de la presente investigación ${ef}${alc?` de alcance ${alc}`:''}${analisis?` con análisis ${analisis.replace('_',' ').toUpperCase()}`:''}${s.ubicacion?`, desarrollada en ${s.ubicacion}`:''}${s.periodo?` durante el período ${s.periodo}`:''}. la constituyen ${ua}.\n\nPoblación objetivo. La población objetivo está conformada por ${nPobl>0?`N = ${nPobl} elementos`:'el conjunto de individuos que cumplen los criterios de inclusión establecidos'} de tipo ${tp}. ${popDec.razon}\n\nPoblación accesible. La población accesible comprende aquellos elementos a los que el investigador tiene posibilidad real de acceder durante el período de recolección de datos y que cumplen los criterios de inclusión definidos.\n\n${s.inclusion?`Criterios de inclusión: ${s.inclusion}.\n\n`:''}${s.exclusion?`Criterios de exclusión: ${s.exclusion}.\n\n`:''}Marco muestral. ${s.padron==='si'?'Se contó con acceso al listado completo de los integrantes de la población, constituyendo el marco muestral para la aplicación del procedimiento probabilístico de selección.':s.padron==='parcial'?'Se dispuso de acceso parcial a registros de la población mediante grupos o conglomerados identificables.':'No se dispuso de un marco muestral exhaustivo. '+( sampDec.advertencia||'')}\n\nTipo y técnica de muestreo. Se aplicó muestreo de tipo ${sampDec.tipoMuestreo.toLowerCase()}, mediante la técnica de ${sampDec.tecnica.toLowerCase()}. ${sampDec.detalle}\n\nJustificación del tamaño muestral. ${justSize}\n\n${s.sesgos&&s.sesgos.length>0?`Posibles sesgos y limitaciones. Se identificaron los siguientes riesgos metodológicos que deben considerarse en la interpretación de los resultados: ${s.sesgos.join('; ')}. Se adoptaron medidas de control mediante la definición de criterios de inclusión y exclusión explícitos y la aplicación sistemática de los instrumentos.\n\n`:''} Alcance de la generalización. ${sampDec.tipoMuestreo==='Probabilístico'?`Dado el carácter probabilístico del muestreo, los resultados son generalizables estadísticamente a la población objetivo con un nivel de confianza del ${zPct} y un margen de error de ±${Math.round(e*100)}% (Cochran, 1977). `:'Los resultados de esta investigación tienen alcance de generalización analítica, no estadística. La transferibilidad a otros contextos debe ser evaluada por el lector en función de la similitud con el contexto estudiado (Lincoln & Guba, 1985; Saunders et al., 2019). '}\n\nReferencias. Hernández-Sampieri, R. (2018). Metodología de la Investigación (6ª ed.). McGraw-Hill. ${sampDec.ref}. ${popDec.ref}. ${calc.ruta.ref}.`;
}
