'use strict';

// ============================================================
// DialogueApp — dialogue-format.js
// Parser y serializer de archivos .dialogue (Dialogue Manager 3).
//
// Diseño sin pérdidas:
//  - El texto previo al primer "~ " se conserva literal (tab.header).
//  - Cada nodo guarda su texto literal (rawText) y una huella (fingerprint)
//    de sus campos estructurados. Al serializar, un nodo cuya huella no
//    cambió se emite con su rawText tal cual; solo se reescriben los
//    nodos realmente editados.
//  - Los nodos con sintaxis que el modelo no representa fielmente
//    (else, set, %, comentarios, tags, etc.) son 'raw': se conservan
//    literales y se editan como texto.
//
// Funciona como script clásico en el navegador (funciones globales) y
// como módulo en Node (module.exports).
// ============================================================

const FLAG_PREFIX = 'flag.';

// ------------------------------------------------------------
// Utilidades puras
// ------------------------------------------------------------

function generateId() {
  return typeof crypto !== 'undefined' && crypto.randomUUID
    ? crypto.randomUUID()
    : 'id_' + Math.random().toString(36).slice(2) + '_' + Date.now().toString(36);
}

/** Convierte un nombre legacy ("x") en ruta ("flag.x"); las rutas con punto se dejan igual. */
function toVarPath(name) {
  if (!name) return '';
  return name.includes('.') ? name : FLAG_PREFIX + name;
}

/**
 * Formatea un valor para .dialogue: strings entre comillas; bool/número tal cual.
 * @param {any} raw
 * @param {string} path ruta de la variable
 * @param {(path: string) => string} [getVarType] devuelve el tipo declarado de la ruta
 */
function formatVarValue(raw, path, getVarType) {
  const v = String(raw ?? '').trim();
  if (v === '') return 'true';
  if (/^(".*"|'.*')$/s.test(v)) return v;
  const type = typeof getVarType === 'function' ? getVarType(path) : '';
  if (type === 'string') return `"${v.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
  if (v === 'true' || v === 'false' || /^-?\d+(\.\d+)?$/.test(v)) return v;
  return `"${v.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

/** true si el texto es un literal simple (bool, número o string entre comillas). */
function isLiteralValue(v) {
  return /^(true|false|-?\d+(\.\d+)?|".*"|'.*')$/s.test(String(v).trim());
}

function escapeRegExp(s) {
  return String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Sintaxis nueva: GameVariables.get_var("ruta"). Antigua: NarrativeManager.get_flag("x") => ruta "flag.x".
const GET_VAR_SRC = String.raw`(?:GameVariables\.get_var\(\s*['"]([^'"]+)['"]\s*\)|NarrativeManager\.get_flag\(\s*['"]([^'"]+)['"]\s*\))`;

/** Parsea "<get_var/get_flag> <op> <valor>" → { path, op, value } o null. */
function parseVarCondition(cond) {
  const m = String(cond).trim().match(new RegExp('^' + GET_VAR_SRC + '\\s*(==|!=|>=|<=|>|<)\\s*(.+)$'));
  if (!m) return null;
  return { path: m[1] || toVarPath(m[2]), op: m[3], value: m[4].trim() };
}

/** Migra get_flag("x") → GameVariables.get_var("flag.x") dentro de un texto de condición. */
function migrateLegacyCondition(text) {
  return String(text).replace(/NarrativeManager\.get_flag\(\s*(['"])([^'"]+)\1\s*\)/g,
    (_, q, name) => `GameVariables.get_var(${q}${toVarPath(name)}${q})`);
}

/**
 * Parsea una línea "do ...". Devuelve { type, name, value } y marca
 * `unknown: true` cuando el modelo no la representa fielmente.
 */
function parseMutation(line) {
  const text = String(line).trim();

  // Asignación: do GameVariables.set_var("ruta", val) o (antigua) do NarrativeManager.set_flag("x", val)
  const setMatch = text.match(/^do\s+GameVariables\.set_var\(\s*(['"])([^'"]+)\1\s*,\s*(.+)\)$/);
  if (setMatch) {
    return { type: 'variable', name: setMatch[2], value: setMatch[3].trim() };
  }
  const flagMatch = text.match(/^do\s+NarrativeManager\.set_flag\(\s*(['"])([^'"]+)\1\s*,\s*(.+)\)$/);
  if (flagMatch) {
    return { type: 'variable', name: toVarPath(flagMatch[2]), value: flagMatch[3].trim() };
  }

  // Evento con un único argumento: do GameManager.trigger_event("x")
  const evtMatch = text.match(/^do\s+GameManager\.trigger_event\(\s*(['"])([^'"]*)\1\s*\)$/);
  if (evtMatch) {
    return { type: 'event', name: evtMatch[2], value: evtMatch[2] };
  }

  // Cualquier otra cosa: no representable
  return { type: 'event', name: text.slice(2).trim(), value: '', unknown: true };
}

// ------------------------------------------------------------
// Huella y texto crudo
// ------------------------------------------------------------

/** JSON de los campos estructurados del nodo (para detectar ediciones). */
function computeFingerprint(node) {
  return JSON.stringify({
    title: node.title,
    nodeType: node.nodeType,
    lines: (node.lines || []).map(l => [l.actor || '', l.text || '', l.condition || '']),
    choices: (node.choices || []).map(c => [c.label || '', c.targetTitle || '']),
    goto: node.goto || '',
    mutations: node.mutations || [],
    conditionalGotos: node.conditionalGotos || [],
    varName: node.varName,
    varValue: node.varValue,
    eventName: node.eventName,
    eventParam: node.eventParam,
    conditionVar: node.conditionVar,
    conditionMode: node.conditionMode,
    conditionOperator: node.conditionOperator,
    conditionValue: node.conditionValue,
    switchCases: node.switchCases,
    conditionOutputs: node.conditionOutputs,
  });
}

/** Extrae los destinos "=> x" / "=>< x" y "- ... => x" del texto de un nodo (sin duplicados). */
function extractRawTargets(rawText) {
  const targets = [];
  for (const rawLine of String(rawText).split('\n')) {
    const line = rawLine.replace(/\r$/, '').trim();
    let m = null;
    if (line.startsWith('=>')) m = line.match(/^=>(?:<)?\s+(\S+)/);
    else if (line.startsWith('- ')) m = line.match(/\s=>(?:<)?\s+(\S+)\s*$/);
    if (!m) continue;
    const dest = m[1].replace(/!$/, '');
    if (dest && !targets.includes(dest)) targets.push(dest);
  }
  return targets;
}

/** Cuerpo editable de un nodo raw: su texto sin la primera línea "~ titulo". */
function getRawBody(node) {
  const raw = node.rawText || '';
  const idx = raw.indexOf('\n');
  return idx < 0 ? '' : raw.slice(idx + 1);
}

/** Reemplaza el cuerpo de un nodo raw (conserva la línea "~ titulo") y recalcula rawTargets. */
function setRawBody(node, body) {
  const raw = node.rawText || '';
  const idx = raw.indexOf('\n');
  const head = idx < 0 ? raw : raw.slice(0, idx);
  node.rawText = head + '\n' + body;
  node.rawTargets = extractRawTargets(node.rawText);
}

/** Título válido para Godot: solo [A-Za-z0-9_]; sin acentos, espacios ni símbolos. 'END' no se toca. */
function validTitle(title) {
  const t = String(title ?? '').trim();
  if (t === 'END' || t === '') return t;
  const base = t.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  let v = base.replace(/[^A-Za-z0-9_]+/g, '_');
  if (/^[^A-Za-z0-9_]/.test(base)) v = v.replace(/^_+/, '');
  if (/[^A-Za-z0-9_]$/.test(base)) v = v.replace(/_+$/, '');
  return v;
}

/** true si el título (o destino) usa caracteres no válidos para Godot. */
function isInvalidTitle(title) {
  const t = String(title ?? '').trim();
  return t !== '' && t !== 'END' && t !== '__START__' && t !== '__END__' && validTitle(t) !== t;
}

/**
 * Reescribe los destinos de las líneas "=> dest" / "- texto => dest" de un texto.
 * El destino es el resto de la línea (recortado, sin "!" final). `fn(dest)` devuelve el nuevo o undefined.
 */
function rewriteDestsInText(text, fn) {
  return String(text).split('\n').map(line => {
    const m = line.match(/^([ \t]*=>(?:<)?[ \t]+)(.*?)([ \t\r]*)$/) ||
      (/^[ \t]*-[ \t]/.test(line) ? line.match(/^([ \t]*-[ \t].*?[ \t]=>(?:<)?[ \t]+)(.*?)([ \t\r]*)$/) : null);
    if (!m) return line;
    const bang = m[2].endsWith('!') ? '!' : '';
    const dest = bang ? m[2].slice(0, -1) : m[2];
    const res = fn(dest);
    return typeof res === 'string' && res !== dest ? m[1] + res + bang + m[3] : line;
  }).join('\n');
}

/** Reemplaza los destinos "=> viejo" por "=> nuevo" (coincidencia exacta del destino completo). */
function renameInRawText(rawText, oldTitle, newTitle) {
  return rewriteDestsInText(rawText, d => (d === oldTitle ? newTitle : undefined));
}

// ------------------------------------------------------------
// Referencias entre nodos
// ------------------------------------------------------------

/**
 * Recorre todos los destinos de un nodo: goto, choices[].targetTitle,
 * conditionalGotos[].goto y conditionOutputs.
 * `fn(destino)` puede devolver un string para reemplazar ese destino.
 */
function forEachNodeRef(node, fn) {
  const apply = (obj, key) => {
    const res = fn(obj[key]);
    if (typeof res === 'string') obj[key] = res;
  };
  if (typeof node.goto === 'string') apply(node, 'goto');
  for (const ch of node.choices || []) apply(ch, 'targetTitle');
  for (const cg of node.conditionalGotos || []) apply(cg, 'goto');
  if (node.conditionOutputs) {
    for (const key of Object.keys(node.conditionOutputs)) apply(node.conditionOutputs, key);
  }
}

/** Actualiza en todos los nodos las referencias a `oldTitle` → `newTitle` (también en nodos raw). */
function updateNodeReferences(tab, oldTitle, newTitle) {
  if (oldTitle === newTitle) return;
  for (const n of tab.nodes) {
    forEachNodeRef(n, (t) => (t === oldTitle ? newTitle : undefined));
    if (n.nodeType === 'raw') {
      n.rawText = renameInRawText(n.rawText, oldTitle, newTitle);
      n.rawTargets = extractRawTargets(n.rawText);
    }
  }
}

/**
 * Renombra un nodo: valida que el título no exista, actualiza referencias y,
 * si el nodo es raw, su línea "~ titulo".
 * @returns {{ok: boolean, error?: string, normalized?: {from: string, to: string}}}
 */
function renameNode(tab, node, newTitle) {
  const typed = String(newTitle ?? '').trim();
  const title = validTitle(typed);
  const oldTitle = node.title;
  const normalized = title !== typed ? { from: typed, to: title } : undefined;
  if (!title) return { ok: false, error: 'El título no puede estar vacío.' };
  if (title === oldTitle) return { ok: true, normalized };
  if (title === 'END' || title === '__START__' || title === '__END__') {
    return { ok: false, error: `"${title}" es un nombre reservado.` };
  }
  if (tab.nodes.some(n => n !== node && n.title === title)) {
    return { ok: false, error: `Ya existe un nodo llamado "${title}".` };
  }
  node.title = title;
  if (node.nodeType === 'raw' && node.rawText) {
    const idx = node.rawText.indexOf('\n');
    const eol = idx > 0 && node.rawText[idx - 1] === '\r' ? '\r' : '';
    const rest = idx < 0 ? '' : node.rawText.slice(idx);
    node.rawText = `~ ${title}${eol}${rest}`;
  }
  updateNodeReferences(tab, oldTitle, title);
  return { ok: true, normalized };
}

// ------------------------------------------------------------
// Orden de flujo
// ------------------------------------------------------------

/** Destinos de un nodo en el orden en que aparecen (opciones, saltos, condiciones). Puede incluir '' y 'END'. */
function nodeTargets(node) {
  if (!node || node.isSpecial) return [];
  if (node.nodeType === 'raw') return (node.rawTargets || []).filter(Boolean);
  const out = [];
  if (node.nodeType === 'condition' && node.conditionOutputs) {
    const o = node.conditionOutputs;
    const keys = node.conditionMode === 'compare' ? ['true', 'false'] : [...(node.switchCases || []), 'default'];
    for (const k of keys) out.push(o[k]);
  } else {
    for (const cg of node.conditionalGotos || []) out.push(cg.goto);
    for (const ch of node.choices || []) out.push(ch.targetTitle);
    out.push(node.goto);
  }
  return out.filter(Boolean);
}

/** Destino actual de una salida: choiceIdx -1 = goto, n = opción n, 'cond_<clave>' = rama de condición. */
function getOutputTarget(node, choiceIdx) {
  if (typeof choiceIdx === 'string' && choiceIdx.startsWith('cond_')) {
    return (node.conditionOutputs || {})[choiceIdx.replace('cond_', '')] || '';
  }
  if (choiceIdx >= 0 && node.choices && node.choices[choiceIdx]) return node.choices[choiceIdx].targetTitle || '';
  return node.goto || '';
}

/** Hijo de un nodo: su goto; con opciones/ramas, el destino de la primera; sin salida, 'END'. */
function nodeChild(node) {
  if (!node) return 'END';
  let t = '';
  if (node.nodeType === 'raw' || node.nodeType === 'condition') t = nodeTargets(node)[0] || '';
  else if (node.choices && node.choices.length) t = (node.choices.find(c => c.targetTitle) || {}).targetTitle || '';
  else t = node.goto || '';
  if (!t && node.nodeType !== 'raw') t = nodeTargets(node)[0] || '';
  return t || 'END';
}

/**
 * Inserta `node` entre la salida (`prevTarget`) y su destino anterior: node.goto = prevTarget,
 * o 'END' si no apuntaba a nada / a END / a un nodo inexistente.
 */
function linkInsertedNode(tab, node, prevTarget) {
  const exists = prevTarget && prevTarget !== 'END' && prevTarget !== '__END__' &&
    tab.nodes.some(n => n.title === prevTarget);
  node.goto = exists ? prevTarget : 'END';
}

/**
 * Borra los nodos `ids` sin cortar el flujo: toda salida que apuntaba a un borrado pasa a su hijo
 * (en cadena si el hijo también se borra; ciclos → END). Incluye START, alias, opciones, ramas y raw.
 * @returns {number} nodos borrados
 */
function deleteNodesReconnect(tab, ids) {
  const set = new Set(ids);
  const doomed = tab.nodes.filter(n => set.has(n.id) && !n.isSpecial);
  if (!doomed.length) return 0;
  const byTitle = new Map(doomed.map(n => [n.title, n]));
  const resolve = (title) => {
    const seen = new Set();
    let cur = title;
    while (byTitle.has(cur)) {
      if (seen.has(cur)) return 'END';
      seen.add(cur);
      cur = nodeChild(byTitle.get(cur));
    }
    return cur;
  };
  const fix = (t) => (byTitle.has(t) ? resolve(t) : undefined);
  tab.nodes = tab.nodes.filter(n => !doomed.includes(n));
  const targets = [...tab.nodes];
  if (tab.startAlias && !targets.includes(tab.startAlias.node)) targets.push(tab.startAlias.node);
  for (const n of targets) {
    forEachNodeRef(n, fix);
    if (n.nodeType === 'raw') {
      n.rawText = rewriteDestsInText(n.rawText, d => fix(d));
      n.rawTargets = extractRawTargets(n.rawText);
    }
  }
  return doomed.length;
}

/**
 * Desconecta `node` del flujo sin borrarlo: toda salida que apuntaba a él pasa a su hijo.
 * El nodo conserva sus opciones; su goto único se vacía para poder reinsertarlo.
 * @returns {boolean} true si hubo cambios
 */
function detachNodeReconnect(tab, node) {
  if (!node || node.isSpecial) return false;
  let child = nodeChild(node);
  if (child === node.title) child = 'END';
  const fix = (t) => (t === node.title ? child : undefined);
  const targets = tab.nodes.filter(n => n !== node);
  if (tab.startAlias && !targets.includes(tab.startAlias.node)) targets.push(tab.startAlias.node);
  for (const n of targets) {
    forEachNodeRef(n, fix);
    if (n.nodeType === 'raw') {
      n.rawText = rewriteDestsInText(n.rawText, d => fix(d));
      n.rawTargets = extractRawTargets(n.rawText);
    }
  }
  if (node.nodeType === 'dialogue' && !(node.choices && node.choices.length)) node.goto = '';
  return true;
}

/**
 * Orden de flujo de los nodos reales (ignora __START__/__END__): recorrido en profundidad desde
 * `start` (o el primer nodo) siguiendo los destinos en orden de aparición; un nodo va después de
 * TODOS sus predecesores directos (orden topológico estable; en ciclos manda el primero visitado).
 * Los nodos no alcanzables (y los de título duplicado) van al final en su orden original.
 * @param {any[]} nodes
 * @param {string} [rootTitle] destino del alias `~ start` oculto (raíz del recorrido)
 * @returns {any[]} nuevo array con los nodos reales reordenados
 */
function flowOrder(nodes, rootTitle) {
  const real = nodes.filter(n => !n.isSpecial && n.title !== '__START__' && n.title !== '__END__');
  if (real.length === 0) return [];
  const byTitle = new Map();
  for (const n of real) if (!byTitle.has(n.title)) byTitle.set(n.title, n);
  const root = byTitle.get(rootTitle) || byTitle.get('start') || real[0];

  // DFS: orden de descubrimiento y aristas de retroceso (ciclos), que se ignoran
  const disc = new Map();
  const onStack = new Set();
  const succ = new Map(); // nodo -> Set de nodos (sin aristas de retroceso ni autobucles)
  const dfs = (n) => {
    disc.set(n, disc.size);
    onStack.add(n);
    const out = new Set();
    for (const t of nodeTargets(n)) {
      const d = byTitle.get(t);
      if (!d || d === n) continue;
      if (onStack.has(d)) continue; // retroceso
      out.add(d);
      if (!disc.has(d)) dfs(d);
    }
    succ.set(n, out);
    onStack.delete(n);
  };
  dfs(root);

  // Orden topológico estable (Kahn) priorizando el orden de descubrimiento
  const indeg = new Map();
  for (const n of disc.keys()) indeg.set(n, 0);
  for (const outs of succ.values()) for (const d of outs) indeg.set(d, indeg.get(d) + 1);
  const ready = [root];
  const result = [];
  while (ready.length) {
    let bi = 0;
    for (let i = 1; i < ready.length; i++) if (disc.get(ready[i]) < disc.get(ready[bi])) bi = i;
    const n = ready.splice(bi, 1)[0];
    result.push(n);
    for (const d of succ.get(n)) {
      indeg.set(d, indeg.get(d) - 1);
      if (indeg.get(d) === 0) ready.push(d);
    }
  }
  const placed = new Set(result);
  for (const n of real) if (!placed.has(n)) result.push(n);
  return result;
}

/** Slug para títulos de nodo: minúsculas, sin acentos, [a-z0-9_], máx. 24 caracteres. */
function slugifyTitle(label) {
  const s = String(label).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
    .replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 24).replace(/_+$/g, '');
  return s || 'opcion';
}

/** Devuelve `base` o `base_2`, `base_3`... hasta que no esté en `titles` (Set). */
function uniqueTitle(base, titles) {
  if (!titles.has(base)) return base;
  let i = 2;
  while (titles.has(`${base}_${i}`)) i++;
  return `${base}_${i}`;
}

/**
 * Inserta `node` en `nodes` justo después del último nodo de su origen: tras `origin` y tras los
 * nodos contiguos que `origin` ya referencia (para conservar el orden pregunta → respuestas).
 * Sin origen, antes del __END__ visual (o al final).
 */
function insertNodeAfter(nodes, node, origin) {
  let at = origin ? nodes.indexOf(origin) : -1;
  if (at < 0) {
    const endIdx = nodes.findIndex(n => n.title === '__END__');
    if (endIdx >= 0) nodes.splice(endIdx, 0, node); else nodes.push(node);
    return;
  }
  const targets = new Set(nodeTargets(origin));
  while (at + 1 < nodes.length && !nodes[at + 1].isSpecial && targets.has(nodes[at + 1].title)) at++;
  nodes.splice(at + 1, 0, node);
}

/**
 * Reordena tab.nodes por flujo (los especiales conservan su sitio). Los nodos con texto literal
 * reciben una línea en blanco final si dejan de ser el último. Devuelve true si cambió el orden.
 */
function applyFlowOrder(tab, rootTitle) {
  const real = tab.nodes.filter(n => !n.isSpecial);
  const ordered = flowOrder(real, rootTitle || (tab.startAlias && tab.startAlias.node.goto));
  const aliasMoves = !!tab.startAlias && tab.startAlias.index !== 0 && real.length > 0;
  if (ordered.length !== real.length || (ordered.every((n, i) => n === real[i]) && !aliasMoves)) return false;
  let k = 0;
  tab.nodes = tab.nodes.map(n => (n.isSpecial ? n : ordered[k++]));
  if (tab.startAlias) tab.startAlias.index = 0; // la entrada va primero
  const list = tab.nodes.filter(n => !n.isSpecial);
  if (tab.startAlias && list.length) list.unshift(tab.startAlias.node); // el alias va siempre primero
  list.forEach((n, i) => {
    if (i === list.length - 1 || typeof n.rawText !== 'string') return;
    const eol = n.rawText.includes('\r\n') ? '\r\n' : '\n';
    if (!n.rawText.endsWith(eol + eol)) n.rawText += n.rawText.endsWith(eol) ? eol : eol + eol;
  });
  return true;
}

// ------------------------------------------------------------
// Parser (.dialogue → modelo)
// ------------------------------------------------------------

const DEST_RE = /^[^\s!{}\[\]<>](?:[^!{}\[\]<>]*[^\s!{}\[\]<>])?$/; // admite espacios internos (se avisa)
const CHOICE_RE = /^-\s+(.+?)\s+=>\s+(\S.*?)\s*$/;

/**
 * Parsea una línea de opción "- texto [=> destino]". Toda línea "- ..." es una opción:
 * sin "=>" (o con la flecha a medias) queda sin destino (`target: ''`, `bare: true`).
 * Devuelve { label, target, bare } o null si no es representable.
 */
function parseChoiceLine(t) {
  const cm = t.match(CHOICE_RE);
  if (cm) return DEST_RE.test(cm[2]) ? { label: cm[1].trim(), target: cm[2], bare: false } : null;
  if (/^-\s*$/.test(t)) return { label: '', target: '', bare: true };
  const m = t.match(/^-\s+(.+)$/);
  if (!m) return null;
  const label = m[1].replace(/\s*(=>|->)\s*$/, '').trim();
  if (label === '' || /=>/.test(label)) return null;
  return { label, target: '', bare: true };
}

/** Valida una línea de texto/actor y la separa en { actor, text }; null si no es representable. */
function parseTextLine(t) {
  if (/^(=>|-|%|#|\/\/|~|\$|\||elif\b|else\b|while\b|match\b|when\b|do\b|set\b|using\b|import\b|if\b)/.test(t)) return null;
  if (/\[#/.test(t) || /\[\/?(if|else)\b/.test(t) || /\[\[/.test(t) || /\{\{\s*(do|set)\b/.test(t)) return null;
  const colonIdx = t.indexOf(': ');
  if (colonIdx > 0 && colonIdx < 30) {
    return { actor: t.slice(0, colonIdx).trim(), text: t.slice(colonIdx + 2).trim() };
  }
  return { actor: '', text: t };
}

/** "=> destino" → destino, o null si no es representable. */
function parseGotoLine(t) {
  const m = t.match(/^=>\s+(\S.*?)\s*$/);
  return m && DEST_RE.test(m[1]) ? m[1] : null;
}

/**
 * Analiza el cuerpo de un nodo. Devuelve un nodo parcial
 * { lines, choices, mutations, conditionalGotos, goto } o null si usa
 * sintaxis que el modelo no representa fielmente.
 */
function analyzeBody(bodyLines) {
  const items = [];
  let pending = null; // { kind: 'if'|'elif', cond }

  for (const rawLine of bodyLines) {
    const line = rawLine.replace(/\r$/, '');
    if (line.trim() === '') continue;
    const t = line.trim();

    if (/^[ \t]/.test(line)) {
      // Indentado: solo válido como cuerpo de un if/elif
      if (!pending) return null;
      if (t.startsWith('=>')) {
        const dest = parseGotoLine(t);
        if (dest === null) return null;
        items.push({ kind: pending.kind, cond: pending.cond, goto: dest });
      } else {
        const tl = parseTextLine(t);
        if (!tl) return null;
        items.push({ kind: pending.kind, cond: pending.cond, actor: tl.actor, text: tl.text });
      }
      pending = null;
      continue;
    }

    if (pending) return null; // if sin cuerpo indentado

    let m;
    if ((m = t.match(/^(if|elif)\s+(\S.*)$/))) {
      if (/:$/.test(m[2])) return null;
      pending = { kind: m[1], cond: migrateLegacyCondition(m[2].trim()) };
    } else if (/^else\b/.test(t)) {
      return null;
    } else if (t.startsWith('=>')) {
      const dest = parseGotoLine(t);
      if (dest === null) return null;
      items.push({ kind: 'goto', goto: dest });
    } else if (t.startsWith('-')) {
      const cm = parseChoiceLine(t);
      if (!cm) return null;
      if (/\[#/.test(cm.label) || /\[\/?(if|else)\b/.test(cm.label) || /\{\{\s*(do|set)\b/.test(cm.label)) return null;
      items.push({ kind: 'choice', label: cm.label, target: cm.target, bare: cm.bare });
    } else if (/^do\s/.test(t)) {
      items.push({ kind: 'do', text: t });
    } else {
      const tl = parseTextLine(t);
      if (!tl) return null;
      items.push({ kind: 'text', actor: tl.actor, text: tl.text });
    }
  }
  if (pending) return null;

  const node = { lines: [], choices: [], mutations: [], goto: '' };
  const isCond = (i) => i.kind === 'if' || i.kind === 'elif';

  // --- Nodo variable / evento: un único do, opcionalmente seguido de => destino
  if (items.some(i => i.kind === 'do')) {
    if (items[0].kind !== 'do') return null;
    if (items.length === 1) return { ...node, mutations: [parseMutation(items[0].text)] };
    if (items.length === 2 && items[1].kind === 'goto') {
      return { ...node, mutations: [parseMutation(items[0].text)], goto: items[1].goto };
    }
    return null;
  }

  // --- Nodo condición: if/elif con "=> destino" indentado y un "=> default" final opcional
  if (items.some(i => isCond(i) && i.goto !== undefined)) {
    let k = 0;
    node.conditionalGotos = [];
    for (; k < items.length && isCond(items[k]); k++) {
      const it = items[k];
      if (it.goto === undefined) return null;
      if ((k === 0) !== (it.kind === 'if')) return null;
      node.conditionalGotos.push({ condition: it.cond, goto: it.goto });
    }
    if (k < items.length) {
      if (k !== items.length - 1 || items[k].kind !== 'goto') return null;
      node.goto = items[k].goto;
    }
    return node;
  }

  // --- Nodo de diálogo: líneas (opcionalmente condicionadas), luego opciones o un salto
  let phase = 0; // 0 = texto, 1 = opciones, 2 = salto
  for (const it of items) {
    if (it.kind === 'text' || it.kind === 'if') {
      if (phase !== 0 || it.goto !== undefined) return null;
      node.lines.push({ actor: it.actor, text: it.text, condition: it.kind === 'if' ? it.cond : '' });
    } else if (it.kind === 'choice') {
      if (phase === 2) return null;
      phase = 1;
      const ch = { label: it.label, targetTitle: it.target };
      if (it.bare) ch.bare = true; // opción sin "=>" en el texto (no entra en la huella)
      node.choices.push(ch);
    } else if (it.kind === 'goto') {
      if (phase !== 0) return null;
      phase = 2;
      node.goto = it.goto;
    } else {
      return null; // elif suelto, etc.
    }
  }
  return node;
}

/**
 * Deduce el tipo del nodo (diálogo / variable / evento / condición).
 * Si el contenido no cabe en el modelo marca `modelable = false`.
 */
function finalizeParsedNode(node) {
  const cg = node.conditionalGotos || [];

  if (cg.length > 0) {
    node.nodeType = 'condition';
    node.conditionOutputs = { default: node.goto || '' };
    node.switchCases = [];

    const first = parseVarCondition(cg[0].condition);
    if (!first || !isLiteralValue(first.value)) { node.modelable = false; return node; }
    node.conditionVar = first.path;
    node.conditionOperator = first.op;

    if (cg.length === 1) {
      // Un solo if: modo comparación, conserva operador y valor tal cual
      node.conditionMode = 'compare';
      node.conditionValue = first.value;
      node.conditionOutputs['true'] = cg[0].goto;
      node.conditionOutputs['false'] = node.goto || '';
    } else {
      node.conditionMode = 'switch';
      for (const c of cg) {
        const m = parseVarCondition(c.condition);
        const reserved = m && (m.value === 'default' || m.value === 'true' || m.value === 'false');
        if (!m || m.op !== '==' || m.path !== first.path || !isLiteralValue(m.value) || reserved
          || node.switchCases.includes(m.value)) {
          node.modelable = false;
          return node;
        }
        node.switchCases.push(m.value);
        node.conditionOutputs[m.value] = c.goto;
      }
    }
    return node;
  }

  if (node.mutations.length > 0) {
    const mut = node.mutations[0];
    if (mut.unknown) { node.modelable = false; return node; }
    if (mut.type === 'variable') {
      if (!isLiteralValue(mut.value)) { node.modelable = false; return node; }
      node.nodeType = 'variable';
      node.varName = mut.name;
      node.varValue = mut.value;
    } else {
      node.nodeType = 'event';
      node.eventParam = mut.value || mut.name;
      node.eventName = node.eventParam;
    }
  }
  return node;
}

function newParsedNodeBase(title, pos, slot) {
  return {
    id: generateId(),
    nodeType: 'dialogue', // 'dialogue' | 'variable' | 'event' | 'condition' | 'raw'
    title,
    x: pos.x ?? slot.x,
    y: pos.y ?? slot.y,
    lines: [],
    choices: [],
    mutations: [],
    goto: '',
    varName: '',
    varValue: 'true',
    eventName: 'abrir_puerta',
    eventParam: '',
  };
}

/**
 * Parsea un .dialogue completo.
 * @returns {{header: string, nodes: any[]}} header = texto literal antes del primer "~ ".
 */
function parseDialogueFile(content, layoutData) {
  const nodesLayout = layoutData?.nodes || {};
  content = String(content ?? '');

  // Posiciones de los inicios de nodo: "~ " en columna 0
  const starts = [];
  const re = /^~ /gm;
  let m;
  while ((m = re.exec(content)) !== null) starts.push(m.index);

  const header = starts.length ? content.slice(0, starts[0]) : content;
  const nodes = [];
  const slot = { x: 280, y: 160 };

  starts.forEach((start, i) => {
    const rawText = content.slice(start, i + 1 < starts.length ? starts[i + 1] : content.length);
    const lines = rawText.split('\n');
    const title = lines[0].replace(/\r$/, '').slice(2).trim();
    const pos = nodesLayout[title] || {};

    let node = newParsedNodeBase(title, pos, slot);
    slot.x += 340;
    if (slot.x > 2000) {
      slot.x = 280;
      slot.y += 320;
    }

    const body = analyzeBody(lines.slice(1));
    let modelable = !!body;
    if (body) {
      Object.assign(node, body);
      node = finalizeParsedNode(node);
      modelable = node.modelable !== false;
    }

    if (modelable) {
      node.modelable = true;
      node.rawText = rawText;
      node.fingerprint = computeFingerprint(node);
    } else {
      node = {
        ...newParsedNodeBase(title, pos, { x: node.x, y: node.y }),
        id: node.id,
        nodeType: 'raw',
        modelable: false,
        rawText,
        rawTargets: extractRawTargets(rawText),
      };
    }
    nodes.push(node);
  });

  // `~ start` alias puro (solo `=> destino` o vacío): no es un nodo visible; lo representa START.
  let startAlias = null;
  const ai = nodes.findIndex(n => n.title === 'start');
  if (ai >= 0 && isPureStartAlias(nodes[ai])) {
    startAlias = { node: nodes[ai], index: ai };
    nodes.splice(ai, 1);
  }

  ensureSpecialNodes(nodes, nodesLayout, startAlias);
  return { header, nodes, startAlias };
}

/** Compatibilidad: devuelve solo los nodos. */
/** `~ start` sin líneas, opciones, mutaciones ni condiciones: solo alias de entrada. */
function isPureStartAlias(n) {
  return n.nodeType === 'dialogue' && n.modelable !== false
    && !(n.lines || []).length && !(n.choices || []).length && !(n.mutations || []).length
    && !(n.conditionalGotos || []).length;
}

function parseDialogue(content, layoutData) {
  return parseDialogueFile(content, layoutData).nodes;
}

/**
 * Añade los nodos visuales __START__ y __END__ (no se serializan).
 * START apunta a `start` si existe, si no al primer nodo. END representa "=> END".
 */
function ensureSpecialNodes(nodes, nodesLayout, startAlias) {
  const hasStart = nodes.some(n => n.title === '__START__');
  const hasEnd = nodes.some(n => n.title === '__END__');

  if (!hasStart) {
    const pos = nodesLayout['__START__'] || {};
    const real = nodes.filter(n => n.title !== '__END__');
    const startNode = real.find(n => n.title === 'start');
    const target = startAlias ? (startAlias.node.goto || '')
      : (startNode ? startNode.title : (real[0] ? real[0].title : ''));
    nodes.unshift({
      id: generateId(),
      nodeType: 'special',
      title: '__START__',
      x: pos.x ?? 40,
      y: pos.y ?? 160,
      lines: [],
      choices: [],
      mutations: [],
      goto: target,
      defaultGoto: target,
      startTouched: false,
      isSpecial: true,
    });
  }

  if (!hasEnd) {
    const maxX = nodes.reduce((mx, n) => Math.max(mx, n.x), 0);
    const pos = nodesLayout['__END__'] || {};
    nodes.push({
      id: generateId(),
      nodeType: 'special',
      title: '__END__',
      x: pos.x ?? (maxX + 360),
      y: pos.y ?? 160,
      lines: [],
      choices: [],
      mutations: [],
      goto: '',
      isSpecial: true,
    });
  }

  nodes.forEach(n => {
    if (n.title === '__START__' || n.title === '__END__') {
      n.isSpecial = true;
      n.nodeType = 'special';
    }
  });
}

// ------------------------------------------------------------
// Serializer (modelo → .dialogue)
// ------------------------------------------------------------

function cleanTarget(tgt) {
  if (!tgt || tgt === '__END__' || tgt === 'END') return 'END';
  return tgt.trim().replace(/\s+/g, '_');
}

/** Serializa un nodo estructurado con el formato actual. Termina en línea en blanco. */
function serializeNode(node, getVarType) {
  const safeTitle = (node.title || 'nodo').trim().replace(/\s+/g, '_');
  let out = `~ ${safeTitle}\n\n`;

  if (node.nodeType === 'variable') {
    const vPath = toVarPath(node.varName || 'variable');
    const vVal = formatVarValue(node.varValue, vPath, getVarType);
    out += `do GameVariables.set_var("${vPath}", ${vVal})\n`;
    out += `=> ${cleanTarget(node.goto)}\n\n`;
    return out;
  }

  if (node.nodeType === 'event') {
    const actorTarget = (node.eventParam || node.eventName || 'DialogueEvent').trim();
    out += `do GameManager.trigger_event("${actorTarget}")\n`;
    out += `=> ${cleanTarget(node.goto)}\n\n`;
    return out;
  }

  if (node.nodeType === 'condition') {
    const vName = toVarPath(node.conditionVar || 'var');
    if (node.conditionMode === 'compare') {
      const op = node.conditionOperator || '==';
      const val = formatVarValue(node.conditionValue, vName, getVarType);
      out += `if GameVariables.get_var("${vName}") ${op} ${val}\n`;
      out += `\t=> ${cleanTarget(node.conditionOutputs?.['true'])}\n`;
      out += `=> ${cleanTarget(node.conditionOutputs?.['false'])}\n\n`;
    } else {
      const cases = node.switchCases || [];
      for (let i = 0; i < cases.length; i++) {
        const cval = cases[i];
        out += `${i === 0 ? 'if' : 'elif'} GameVariables.get_var("${vName}") == ${formatVarValue(cval, vName, getVarType)}\n`;
        out += `\t=> ${cleanTarget(node.conditionOutputs?.[cval])}\n`;
      }
      out += `=> ${cleanTarget(node.conditionOutputs?.['default'])}\n\n`;
    }
    return out;
  }

  // Nodo estándar de diálogo
  let body = '';
  for (const line of node.lines || []) {
    if (!line.actor && !line.text) continue;
    if (line.condition) body += `if ${line.condition}\n\t`;
    if (line.actor) body += `${line.actor}: `;
    body += `${line.text}\n`;
  }
  if ((node.choices || []).length > 0) {
    for (const ch of node.choices) {
      const bare = ch.bare && !ch.targetTitle;
      body += `- ${ch.label}${bare ? '' : ' => ' + cleanTarget(ch.targetTitle)}\n`;
    }
  } else if (node.goto) {
    body += `=> ${cleanTarget(node.goto)}\n`;
  }
  if (body) out += body + '\n';
  return out;
}

/**
 * Serializa la pestaña. Los nodos raw y los nodos estructurados sin cambios
 * se emiten con su texto literal; solo se reescriben los editados o nuevos.
 * @param {{header?: string, nodes: any[]}} tabData
 * @param {(path: string) => string} [getVarType]
 */
function serializeDialogue(tabData, getVarType) {
  const real = tabData.nodes.filter(n => !n.isSpecial && n.title !== '__START__' && n.title !== '__END__');
  const startNode = tabData.nodes.find(n => n.title === '__START__');
  const alias = tabData.startAlias ? tabData.startAlias.node : null;

  // Cambio estructural hecho en Nodos: el texto sigue el orden de flujo (una sola vez)
  if (tabData.flowDirty) {
    tabData.flowDirty = false;
    let root = alias ? (alias.goto || '') : '';
    if (startNode && startNode.startTouched && startNode.goto) {
      root = startNode.goto;
      if (alias) alias.goto = startNode.goto; // START manda sobre su destino
    }
    applyFlowOrder(tabData, cleanTarget(root));
    return serializeDialogue(tabData, getVarType);
  }

  const chunks = [];
  const header = tabData.header || '';
  if (header) chunks.push({ text: header, literal: true });

  // El usuario conectó START y no existe ningún nodo `start`: se emite uno al principio
  if (startNode && startNode.startTouched && startNode.goto && !alias && !real.some(n => n.title === 'start')) {
    chunks.push({ text: `~ start\n\n=> ${cleanTarget(startNode.goto)}\n\n`, literal: false });
  }

  // El alias `~ start` oculto se reinyecta en su posición original; START manda sobre su destino
  if (alias && startNode && startNode.startTouched) alias.goto = startNode.goto || 'END';
  const emit = alias ? real.slice() : real;
  if (alias) emit.splice(Math.min(tabData.startAlias.index, emit.length), 0, alias);

  for (const node of emit) {
    const unchanged = node.nodeType === 'raw'
      || (node.rawText !== undefined && node.fingerprint !== undefined && computeFingerprint(node) === node.fingerprint);
    if (unchanged && node.rawText !== undefined) chunks.push({ text: node.rawText, literal: true });
    else chunks.push({ text: serializeNode(node, getVarType), literal: false });
  }

  let out = '';
  chunks.forEach((c, i) => {
    if (out !== '' && !out.endsWith('\n')) out += '\n';
    let text = c.text;
    // Un nodo reescrito al final del archivo no deja líneas en blanco sobrantes
    if (!c.literal && i === chunks.length - 1) text = text.replace(/\n+$/, '\n');
    out += text;
  });
  return out;
}

const DialogueFormat = {
  FLAG_PREFIX, generateId, toVarPath, formatVarValue, isLiteralValue,
  parseVarCondition, migrateLegacyCondition, parseMutation, computeFingerprint,
  extractRawTargets, getRawBody, setRawBody, renameInRawText,
  forEachNodeRef, updateNodeReferences, renameNode,
  analyzeBody, finalizeParsedNode, parseDialogueFile, parseDialogue, ensureSpecialNodes,
  cleanTarget, serializeNode, serializeDialogue,
  parseChoiceLine, nodeTargets, flowOrder, slugifyTitle, validTitle, isInvalidTitle, isPureStartAlias, rewriteDestsInText, uniqueTitle, insertNodeAfter, applyFlowOrder,
  getOutputTarget, nodeChild, linkInsertedNode, deleteNodesReconnect, detachNodeReconnect,
};

if (typeof module !== 'undefined' && module.exports) {
  module.exports = DialogueFormat;
}
