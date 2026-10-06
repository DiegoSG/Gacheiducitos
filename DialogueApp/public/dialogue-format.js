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

/** Reemplaza los destinos "=> viejo" por "=> nuevo" en las líneas de salto de un texto raw. */
function renameInRawText(rawText, oldTitle, newTitle) {
  const re = new RegExp('(=>(?:<)?[ \\t]+)' + escapeRegExp(oldTitle) + '(?![\\w\\-])', 'g');
  return String(rawText).split('\n').map(line => {
    if (!/^[ \t]*(=>|-[ \t])/.test(line)) return line;
    return line.replace(re, (_, pre) => pre + newTitle);
  }).join('\n');
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
 * @returns {{ok: boolean, error?: string}}
 */
function renameNode(tab, node, newTitle) {
  const title = String(newTitle ?? '').trim().replace(/\s+/g, '_');
  const oldTitle = node.title;
  if (!title) return { ok: false, error: 'El título no puede estar vacío.' };
  if (title === oldTitle) return { ok: true };
  if (title === 'END' || title === '__START__' || title === '__END__') {
    return { ok: false, error: `"${title}" es un nombre reservado.` };
  }
  if (tab.nodes.some(n => n !== node && n.title === title)) {
    return { ok: false, error: `Ya existe un nudo llamado "${title}".` };
  }
  node.title = title;
  if (node.nodeType === 'raw' && node.rawText) {
    const idx = node.rawText.indexOf('\n');
    const eol = idx > 0 && node.rawText[idx - 1] === '\r' ? '\r' : '';
    const rest = idx < 0 ? '' : node.rawText.slice(idx);
    node.rawText = `~ ${title}${eol}${rest}`;
  }
  updateNodeReferences(tab, oldTitle, title);
  return { ok: true };
}

// ------------------------------------------------------------
// Parser (.dialogue → modelo)
// ------------------------------------------------------------

const DEST_RE = /^[^\s!{}\[\]<>]+$/;
const CHOICE_RE = /^-\s+(.+?)\s+=>\s+(\S+)$/;

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
  const m = t.match(/^=>\s+(\S+)$/);
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
      const cm = t.match(CHOICE_RE);
      if (!cm || !DEST_RE.test(cm[2])) return null;
      if (/\[#/.test(cm[1]) || /\[\/?(if|else)\b/.test(cm[1]) || /\{\{\s*(do|set)\b/.test(cm[1])) return null;
      items.push({ kind: 'choice', label: cm[1].trim(), target: cm[2] });
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
      node.choices.push({ label: it.label, targetTitle: it.target });
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

  ensureSpecialNodes(nodes, nodesLayout);
  return { header, nodes };
}

/** Compatibilidad: devuelve solo los nodos. */
function parseDialogue(content, layoutData) {
  return parseDialogueFile(content, layoutData).nodes;
}

/**
 * Añade los nodos visuales __START__ y __END__ (no se serializan).
 * START apunta a `start` si existe, si no al primer nodo. END representa "=> END".
 */
function ensureSpecialNodes(nodes, nodesLayout) {
  const hasStart = nodes.some(n => n.title === '__START__');
  const hasEnd = nodes.some(n => n.title === '__END__');

  if (!hasStart) {
    const pos = nodesLayout['__START__'] || {};
    const real = nodes.filter(n => n.title !== '__END__');
    const startNode = real.find(n => n.title === 'start');
    const target = startNode ? startNode.title : (real[0] ? real[0].title : '');
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
  const safeTitle = (node.title || 'nudo').trim().replace(/\s+/g, '_');
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
      body += `- ${ch.label} => ${cleanTarget(ch.targetTitle)}\n`;
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

  const chunks = [];
  const header = tabData.header || '';
  if (header) chunks.push({ text: header, literal: true });

  // El usuario conectó START y no existe ningún nodo `start`: se emite uno al principio
  if (startNode && startNode.startTouched && startNode.goto && !real.some(n => n.title === 'start')) {
    chunks.push({ text: `~ start\n\n=> ${cleanTarget(startNode.goto)}\n\n`, literal: false });
  }

  for (const node of real) {
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
};

if (typeof module !== 'undefined' && module.exports) {
  module.exports = DialogueFormat;
}
