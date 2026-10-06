'use strict';

// ============================================================
// DialogueApp — writing.js
// Vista Escritura: editor de guion a pantalla completa (alterna con la vista Nodos).
// - El texto es la fuente de verdad mientras se escribe: se parsea con debounce
//   (parseDialogueFile) y reemplaza tab.nodes conservando posiciones x/y.
// - Capa de resaltado (técnica backdrop), minimapa SVG, lista de nodos, paleta Ctrl+P,
//   autocompletado, escritura rápida y barra de inserción.
// Depende de dialogue-format.js y de app.js (getActiveTab, markDirty, AppState...).
// ============================================================

(function () {
  const LS_VIEW = 'dialogueapp.view';
  const LS_SIDE = 'dialogueapp.writingSide';

  function lsGet(key) { try { return localStorage.getItem(key); } catch (_) { return null; } }
  function lsSet(key, val) { try { localStorage.setItem(key, val); } catch (_) { /* sin almacenamiento */ } }

  const $ = (id) => document.getElementById(id);
  const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

  // Elementos (se resuelven en init)
  let ta, hl, stack, popup, toastEl, minimap, nodeListEl, nodeCountEl;
  let paletteEl, paletteInput, paletteList;

  // Estado del editor
  let boundTab = null;      // pestaña cuyo texto está en el textarea
  let parseTimer = null;
  let busy = false;         // edición programática en curso (no disparar autocompletado, etc.)
  let curTitle = '';        // nodo bajo el cursor
  let lastLineIdx = -1;     // para detectar "salir de línea"
  let headerWatch = null;   // { idx, title }: encabezado de nodo que se está editando
  let toastTimer = null;
  const jumpStack = [];     // posiciones previas (Alt+←)

  // ------------------------------------------------------------
  // Vistas
  // ------------------------------------------------------------

  function getPreferredView() {
    return lsGet(LS_VIEW) === 'writing' ? 'writing' : 'nodes';
  }

  function isWritingView() {
    const tab = getActiveTab();
    return !!tab && tab.view === 'writing';
  }

  /** Aplica clases de vista en #app y marca el botón activo. */
  function applyViewClasses() {
    const tab = getActiveTab();
    const writing = !!tab && tab.view === 'writing';
    $('app')?.classList.toggle('view-writing', writing);
    $('writing-view')?.classList.toggle('hidden', !writing);
    $('canvas-wrapper')?.classList.toggle('hidden', writing);
    $('btn-view-writing')?.classList.toggle('active', writing);
    $('btn-view-nodes')?.classList.toggle('active', !writing);
  }

  /** Cambia la vista de la pestaña activa. opts.title: nodo en el que dejar el cursor/selección. */
  function setView(view, opts = {}) {
    const tab = getActiveTab();
    if (!tab) return;
    const prev = tab.view || 'nodes';
    if (prev === view) {
      if (view === 'writing' && opts.title) jumpToNode(opts.title);
      return;
    }

    let title = opts.title || '';
    if (prev === 'writing' && view === 'nodes') {
      leaveEditor();
      title = title || tab.cursorTitle || '';
    } else if (prev === 'nodes' && view === 'writing' && !title) {
      const sel = getSingleSelectedNode(tab);
      title = sel ? sel.title : '';
    }

    tab.view = view;
    lsSet(LS_VIEW, view);
    applyViewClasses();

    if (view === 'writing') {
      enterWriting(tab, title);
    } else {
      enterNodes(tab, title);
    }
  }

  /** Llamado por activateTab: sincroniza clases y editor con la pestaña activa. */
  function applyViewForTab() {
    applyViewClasses();
    const tab = getActiveTab();
    if (tab && tab.view === 'writing') enterWriting(tab, '');
  }

  function enterNodes(tab, title) {
    clearSelection();
    const node = title ? tab.nodes.find(n => n.title === title) : null;
    if (node) selectedNodeIds.add(node.id);
    renderCanvas(tab);
    updateInspector();
    if (node) centerOnNode(tab, node);
  }

  function centerOnNode(tab, node) {
    const cc = $('canvas-container');
    if (!cc) return;
    const rect = cc.getBoundingClientRect();
    const el = document.querySelector(`.dialogue-node[data-id="${node.id}"]`);
    const w = el ? el.offsetWidth : 260;
    const h = el ? el.offsetHeight : 120;
    tab.canvas.panX = rect.width / 2 / tab.canvas.zoom - (node.x + w / 2);
    tab.canvas.panY = rect.height / 2 / tab.canvas.zoom - (node.y + h / 2);
    applyCanvasTransform(tab);
    requestAnimationFrame(() => renderConnections(tab));
  }

  // ------------------------------------------------------------
  // Entrada / salida del editor, sincronización texto → nodos
  // ------------------------------------------------------------

  function enterWriting(tab, title) {
    if (!ta) return;
    clearTimeout(parseTimer);
    boundTab = tab;
    const text = serializeDialogue(tab, getVarType);
    tab.eol = text.includes('\r\n') ? '\r\n' : '\n';
    tab.scriptText = text;
    ta.value = text; // el textarea normaliza CRLF a LF; tab.eol lo restituye al parsear
    tab.lastParsedText = ta.value;
    jumpStack.length = 0;
    lastLineIdx = -1;
    headerWatch = null;
    refreshAll();

    const side = lsGet(LS_SIDE) !== '0';
    $('writing-view')?.classList.toggle('side-hidden', !side);

    requestAnimationFrame(() => {
      if (boundTab !== tab) return;
      if (title && jumpToNode(title, { noPush: true })) return;
      const c = tab.writeCaret;
      if (c) {
        ta.setSelectionRange(Math.min(c.s, ta.value.length), Math.min(c.e, ta.value.length));
        ta.scrollTop = c.top || 0;
        syncScroll();
      }
      ta.focus();
      updateCursor();
    });
  }

  /** Vuelca el texto a la pestaña y suelta el editor (cambio de pestaña o de vista). */
  function leaveEditor() {
    if (!boundTab) return;
    const tab = boundTab;
    finalizeHeaderWatch();
    syncFromText(tab);
    tab.writeCaret = { s: ta.selectionStart, e: ta.selectionEnd, top: ta.scrollTop };
    tab.cursorTitle = curTitle || tab.cursorTitle || '';
    hidePopup();
    boundTab = null;
  }

  /** Parsea lo último escrito sin soltar el editor (guardar, cerrar pestaña). */
  function flushWritingSync() {
    if (boundTab) syncFromText(boundTab);
  }

  /** Si el modelo cambió por fuera (p. ej. renombrar variable), refresca el texto del editor. */
  function syncModelToEditor() {
    if (!boundTab || boundTab !== getActiveTab()) return;
    const text = serializeDialogue(boundTab, getVarType);
    if (text.replace(/\r\n/g, '\n') === ta.value) { refreshSide(); return; }
    const s = ta.selectionStart, top = ta.scrollTop;
    boundTab.scriptText = text;
    ta.value = text;
    boundTab.lastParsedText = ta.value;
    ta.setSelectionRange(Math.min(s, ta.value.length), Math.min(s, ta.value.length));
    ta.scrollTop = top;
    refreshAll();
  }

  function scheduleParse() {
    clearTimeout(parseTimer);
    parseTimer = setTimeout(() => { if (boundTab) syncFromText(boundTab); }, 300);
  }

  function targetsOf(node) {
    if (node.isSpecial) return [];
    if (node.nodeType === 'raw') return (node.rawTargets || []).filter(Boolean);
    const out = [];
    forEachNodeRef(node, (t) => { if (t) out.push(t); });
    return out;
  }

  /**
   * Parsea tab.scriptText y reemplaza tab.nodes conservando ids y posiciones por título.
   * Los nodos nuevos se colocan a la derecha del primero que los referencia.
   */
  function syncFromText(tab) {
    clearTimeout(parseTimer);
    if (tab !== boundTab) return;
    const text = ta.value;
    if (text === tab.lastParsedText) return;

    const old = tab.nodes;
    const posByTitle = Object.assign({}, tab.posCache || {});
    const idByTitle = {};
    for (const n of old) {
      if (!(n.title in idByTitle)) {
        idByTitle[n.title] = n.id;
        posByTitle[n.title] = { x: n.x, y: n.y };
      }
    }

    const eolText = (tab.eol === '\r\n') ? text.replace(/\n/g, '\r\n') : text;
    const parsed = parseDialogueFile(eolText, { nodes: posByTitle });
    const nodes = parsed.nodes;
    const isReal = (n) => !n.isSpecial;

    // Ids estables por título (conserva la selección del canvas)
    const seen = new Set();
    for (const n of nodes) {
      if (seen.has(n.title)) continue;
      seen.add(n.title);
      if (idByTitle[n.title]) n.id = idByTitle[n.title];
    }

    // Títulos duplicados: el segundo se desplaza para que no se solape
    const firstByTitle = new Map();
    const dupCount = new Map();
    for (const n of nodes) {
      if (!isReal(n)) continue;
      if (!firstByTitle.has(n.title)) { firstByTitle.set(n.title, n); continue; }
      const k = (dupCount.get(n.title) || 0) + 1;
      dupCount.set(n.title, k);
      n.x = firstByTitle.get(n.title).x + 30 * k;
      n.y = firstByTitle.get(n.title).y + 30 * k;
    }

    // Nodos nuevos = real sin posición conocida
    const known = (t) => (t in posByTitle);
    const fresh = nodes.filter(n => isReal(n) && !known(n.title));
    const newTitles = new Set(nodes.filter(isReal).map(n => n.title));
    const lost = old.filter(n => isReal(n) && !newTitles.has(n.title));
    if (fresh.length === 1 && lost.length === 1) {
      // Renombrado mientras se escribe: hereda posición e id
      fresh[0].x = lost[0].x;
      fresh[0].y = lost[0].y;
      fresh[0].id = lost[0].id;
    } else {
      placeNewNodes(nodes, fresh);
    }

    // START visual conectado a mano: se conserva si sigue siendo válido
    const oldStart = old.find(n => n.title === '__START__');
    const newStart = nodes.find(n => n.title === '__START__');
    if (oldStart && oldStart.startTouched && newStart && !parsed.startAlias && !nodes.some(n => n.title === 'start')
        && newTitles.has(oldStart.goto)) {
      newStart.goto = oldStart.goto;
      newStart.startTouched = true;
    }

    tab.header = parsed.header;
    tab.startAlias = parsed.startAlias;
    tab.nodes = nodes;
    tab.scriptText = text;
    tab.lastParsedText = text;
    tab.posCache = tab.posCache || {};
    for (const n of nodes) tab.posCache[n.title] = { x: n.x, y: n.y };

    // Selección: descarta ids que ya no existen
    const ids = new Set(nodes.map(n => n.id));
    for (const id of Array.from(selectedNodeIds)) if (!ids.has(id)) selectedNodeIds.delete(id);

    refreshSide();
  }

  /** Coloca nodos nuevos: a la derecha (+340) del primer nodo que los referencia; si no, debajo del último. */
  function placeNewNodes(nodes, fresh) {
    if (fresh.length === 0) return;
    const real = nodes.filter(n => !n.isSpecial);
    const freshSet = new Set(fresh);
    const placed = new Set(real.filter(n => !freshSet.has(n)));
    const isFree = (x, y) => {
      for (const n of nodes) {
        if (n.isSpecial && n.title === '__END__') continue;
        if (!placed.has(n) && !n.isSpecial) continue;
        if (Math.abs(n.x - x) < 200 && Math.abs(n.y - y) < 150) return false;
      }
      return true;
    };
    for (const n of fresh) {
      const ref = real.find(r => r !== n && placed.has(r) && targetsOf(r).includes(n.title));
      let x, y;
      if (ref) {
        x = ref.x + 340;
        y = ref.y;
        for (let g = 0; g < 60 && !isFree(x, y); g++) y += 190;
      } else {
        const list = Array.from(placed);
        const last = list.length ? list.reduce((a, b) => (b.y >= a.y ? b : a)) : null;
        x = last ? last.x : 280;
        y = last ? last.y + 220 : 160;
        for (let g = 0; g < 60 && !isFree(x, y); g++) y += 190;
      }
      n.x = x;
      n.y = y;
      placed.add(n);
    }
  }

  // ------------------------------------------------------------
  // Utilidades de texto
  // ------------------------------------------------------------

  function lineInfo(text, pos) {
    const s = pos === 0 ? 0 : text.lastIndexOf('\n', pos - 1) + 1;
    let e = text.indexOf('\n', pos);
    if (e < 0) e = text.length;
    return { start: s, end: e, text: text.slice(s, e) };
  }

  function lineIndexAt(text, pos) {
    let n = 0;
    for (let i = text.indexOf('\n'); i >= 0 && i < pos; i = text.indexOf('\n', i + 1)) n++;
    return n;
  }

  /** Rangos de nodo: [{title, line, start, end}] en orden del archivo. */
  function nodeRanges(text) {
    const out = [];
    const re = /^~ (.*)$/gm;
    let m;
    while ((m = re.exec(text)) !== null) {
      out.push({ title: m[1].trim(), line: lineIndexAt(text, m.index), start: m.index, end: text.length, hdrEnd: m.index + m[0].length });
    }
    for (let i = 0; i + 1 < out.length; i++) out[i].end = out[i + 1].start;
    return out;
  }

  function collectTitles(text) {
    const set = new Set();
    const re = /^~ (.*)$/gm;
    let m;
    while ((m = re.exec(text)) !== null) set.add(m[1].trim());
    return set;
  }

  const NOT_TEXT = /^(=>|-|%|#|\/\/|~|\$|\||elif\b|else\b|while\b|match\b|when\b|do\b|set\b|using\b|import\b|if\b)/;

  /** { indent, actor, rest } de una línea "Actor: texto" (o solo "Actor:"), o null. */
  function splitActor(line) {
    const m = line.match(/^(\s*)(.*)$/);
    const indent = m[1], t = m[2];
    if (!t || NOT_TEXT.test(t)) return null;
    let actor, rest;
    const i = t.indexOf(': ');
    if (i > 0 && i < 30) { actor = t.slice(0, i); rest = t.slice(i + 2); }
    else if (/^[^:]{1,29}:$/.test(t)) { actor = t.slice(0, -1); rest = ''; }
    else return null;
    if (/[\[\]{}"]/.test(actor) || !actor.trim()) return null;
    return { indent, actor: actor.trim(), rest };
  }

  function collectActors(text) {
    const set = new Set();
    for (const l of text.split('\n')) {
      const sp = splitActor(l);
      if (sp) set.add(sp.actor);
    }
    return Array.from(set);
  }

  function destOnLine(line) {
    const m = /=>(?:<)?\s+(\S.*?)\s*$/.exec(line);
    if (!m) return null;
    const dest = m[1].replace(/!$/, '');
    const s2 = line.indexOf(m[1], m.index + 2);
    return { dest, s: s2, e: s2 + dest.length };
  }

  const slugify = slugifyTitle;

  function currentNodeRange(text, pos) {
    const ranges = nodeRanges(text);
    let cur = null;
    for (const r of ranges) if (r.start <= pos) cur = r;
    return cur;
  }

  // ------------------------------------------------------------
  // Edición programática (mantiene el undo del navegador)
  // ------------------------------------------------------------

  function replaceRange(a, b, str) {
    busy = true;
    try {
      ta.focus();
      ta.setSelectionRange(a, b);
      let ok = false;
      try {
        ok = str === '' ? (a === b ? true : document.execCommand('delete')) : document.execCommand('insertText', false, str);
      } catch (_) { ok = false; }
      if (!ok) {
        ta.setRangeText(str, a, b, 'end');
        ta.dispatchEvent(new Event('input', { bubbles: true }));
      }
    } finally {
      busy = false;
    }
  }

  function setCaret(s, e = s) {
    ta.setSelectionRange(s, e);
    scrollCaretIntoView();
    updateCursor();
  }

  // ------------------------------------------------------------
  // Resaltado (capa backdrop)
  // ------------------------------------------------------------

  const actorColorCache = new Map();
  function actorColor(name) {
    let c = actorColorCache.get(name);
    if (!c) {
      let h = 7;
      for (const ch of name.toLowerCase()) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
      c = `hsl(${h % 360} 68% 72%)`;
      actorColorCache.set(name, c);
    }
    return c;
  }

  function destSpan(dest, titles) {
    const d = dest.replace(/!$/, '');
    let cls = 'w-dest';
    if (d === 'END') cls = 'w-end';
    else if (!titles.has(d)) cls = 'w-missing';
    return `<span class="${cls}">${esc(dest)}</span>`;
  }

  function highlightLine(raw, titles) {
    if (raw.startsWith('~ ')) return { html: `<span class="w-node">${esc(raw)}</span>`, cls: 'is-node' };
    const m = raw.match(/^(\s*)(.*)$/);
    const indent = m[1], rest = m[2];
    let html;
    if (rest === '') {
      html = esc(indent);
    } else if (rest.startsWith('#') || rest.startsWith('//')) {
      html = esc(indent) + `<span class="w-comment">${esc(rest)}</span>`;
    } else if (/^=>/.test(rest)) {
      const g = rest.match(/^(=>(?:<)?)(\s+)(\S.*?)(\s*)$/);
      html = g
        ? esc(indent) + `<span class="w-arrow">${esc(g[1])}</span>${esc(g[2])}${destSpan(g[3], titles)}${esc(g[4])}`
        : esc(indent) + `<span class="w-arrow">${esc(rest)}</span>`;
    } else if (/^-(\s|$)/.test(rest)) {
      const g = rest.match(/^(-\s*)(.*?)(\s+=>(?:<)?\s+)(\S.*?)(\s*)$/);
      if (g) {
        html = esc(indent) + `<span class="w-bullet">${esc(g[1])}</span><span class="w-option">${esc(g[2])}</span>`
          + `<span class="w-arrow">${esc(g[3])}</span>${destSpan(g[4], titles)}${esc(g[5])}`;
      } else {
        const b = rest.match(/^(-\s*)(.*)$/);
        html = esc(indent) + `<span class="w-bullet">${esc(b[1])}</span><span class="w-option">${esc(b[2])}</span>`;
      }
    } else if (/^(if|elif|else|while|match|when)\b/.test(rest)) {
      const g = rest.match(/^(\w+)(.*)$/);
      html = esc(indent) + `<span class="w-kw">${esc(g[1])}</span><span class="w-code">${esc(g[2])}</span>`;
    } else if (/^(do|set)\b/.test(rest)) {
      const g = rest.match(/^(\w+)(.*)$/);
      html = esc(indent) + `<span class="w-do">${esc(g[1])}</span><span class="w-code">${esc(g[2])}</span>`;
    } else {
      const sp = splitActor(raw);
      if (sp) {
        const prefixLen = sp.indent.length + sp.actor.length;
        const after = raw.slice(prefixLen);
        html = esc(sp.indent) + `<span class="w-actor" style="color:${actorColor(sp.actor)}">${esc(raw.slice(sp.indent.length, prefixLen))}</span>`
          + `<span class="w-colon">${esc(after.slice(0, 1))}</span>${esc(after.slice(1))}`;
      } else {
        html = esc(raw);
      }
    }
    return { html, cls: '' };
  }

  function renderHighlight() {
    const text = ta.value;
    const titles = collectTitles(text);
    const lines = text.split('\n');
    const out = new Array(lines.length);
    for (let i = 0; i < lines.length; i++) {
      const h = highlightLine(lines[i], titles);
      out[i] = `<div class="l ${h.cls}" data-n="${i + 1}">${h.html || '&#8203;'}</div>`;
    }
    hl.innerHTML = out.join('');
    syncScroll();
    markCurrentLine();
  }

  function markCurrentLine() {
    const idx = lineIndexAt(ta.value, ta.selectionStart);
    const prev = hl.querySelector('.l.cur');
    if (prev) prev.classList.remove('cur');
    const el = hl.children[idx];
    if (el) el.classList.add('cur');
  }

  function syncScroll() {
    hl.scrollTop = ta.scrollTop;
  }

  // Espejo para medir la posición (x, y) del cursor en coordenadas de contenido
  let mirror = null;
  function caretXY(pos) {
    if (!mirror) {
      mirror = document.createElement('div');
      mirror.id = 'script-mirror';
      stack.appendChild(mirror);
    }
    const cs = getComputedStyle(ta);
    mirror.style.width = ta.clientWidth + 'px';
    mirror.style.font = cs.font;
    mirror.style.letterSpacing = cs.letterSpacing;
    mirror.style.padding = cs.padding;
    mirror.style.tabSize = cs.tabSize;
    mirror.textContent = ta.value.slice(0, pos);
    const mark = document.createElement('span');
    mark.textContent = '​';
    mirror.appendChild(mark);
    return { x: mark.offsetLeft, y: mark.offsetTop, h: parseFloat(cs.lineHeight) || 24 };
  }

  function scrollCaretIntoView() {
    const c = caretXY(ta.selectionStart);
    const margin = c.h * 2;
    if (c.y < ta.scrollTop + margin) ta.scrollTop = Math.max(0, c.y - margin);
    else if (c.y + c.h > ta.scrollTop + ta.clientHeight - margin) ta.scrollTop = c.y + c.h - ta.clientHeight + margin;
    syncScroll();
  }

  // ------------------------------------------------------------
  // Panel lateral: minimapa, lista, avisos
  // ------------------------------------------------------------

  /** Avisos por título: destino inexistente, título duplicado, nodo sin salida. */
  function analyzeNodes(tab) {
    const warnings = new Map();
    const add = (t, msg) => { if (!warnings.has(t)) warnings.set(t, []); warnings.get(t).push(msg); };
    const real = tab.nodes.filter(n => !n.isSpecial);
    const count = new Map();
    for (const n of real) count.set(n.title, (count.get(n.title) || 0) + 1);
    for (const n of real) {
      if (count.get(n.title) > 1) add(n.title, 'Título duplicado');
      if (isInvalidTitle(n.title) || targetsOf(n).some(isInvalidTitle)) {
        add(n.title, 'Título no válido para Godot: usa guiones bajos');
      }
      const targets = targetsOf(n);
      if (targets.length === 0) add(n.title, 'Nodo sin salida');
      for (const t of targets) {
        if (t === 'END' || t === '__END__') continue;
        if (!count.has(t)) add(n.title, `Destino inexistente: ${t}`);
      }
    }
    return warnings;
  }

  function nodeSize(n) {
    if (n.isSpecial) return { w: 120, h: 50 };
    if (n.nodeType === 'raw') {
      const lines = (n.rawText || '').split('\n').length;
      return { w: 260, h: Math.min(260, 70 + lines * 14) };
    }
    const rows = (n.lines || []).length + (n.choices || []).length;
    return { w: 260, h: 80 + rows * 30 };
  }

  function renderMinimap(tab) {
    if (!minimap) return;
    const real = flowOrder(tab.nodes, tab.startAlias && tab.startAlias.node.goto); // se dibuja en orden de flujo (solo visual)
    const nodes = [tab.nodes.find(n => n.title === '__START__'), ...real, tab.nodes.find(n => n.title === '__END__')].filter(Boolean);
    if (nodes.length === 0) { minimap.innerHTML = ''; return; }
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const n of nodes) {
      const s = nodeSize(n);
      minX = Math.min(minX, n.x); minY = Math.min(minY, n.y);
      maxX = Math.max(maxX, n.x + s.w); maxY = Math.max(maxY, n.y + s.h);
    }
    const pad = 30;
    let w = maxX - minX + pad * 2, h = maxY - minY + pad * 2;
    const cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    w = Math.max(w, 700); h = Math.max(h, 360);
    minimap.setAttribute('viewBox', `${cx - w / 2} ${cy - h / 2} ${w} ${h}`);

    const byTitle = new Map();
    for (const n of nodes) if (!byTitle.has(n.title)) byTitle.set(n.title, n);
    const parts = [];
    const edge = (a, b) => {
      const sa = nodeSize(a), sb = nodeSize(b);
      const x1 = a.x + sa.w, y1 = a.y + sa.h / 2, x2 = b.x, y2 = b.y + sb.h / 2;
      const dx = Math.max(40, Math.abs(x2 - x1) * 0.45);
      parts.push(`<path class="mm-edge" d="M${x1},${y1} C${x1 + dx},${y1} ${x2 - dx},${y2} ${x2},${y2}"/>`);
    };
    for (const n of nodes) {
      const targets = n.title === '__START__' ? [n.goto] : targetsOf(n);
      const seen = new Set();
      for (const t of targets) {
        if (!t || seen.has(t)) continue;
        seen.add(t);
        const dst = byTitle.get(t === 'END' ? '__END__' : t);
        if (dst && dst !== n) edge(n, dst);
      }
    }
    const warn = tab._warnings || new Map();
    for (const n of nodes) {
      const s = nodeSize(n);
      const cls = 'mm-node'
        + (n.title === '__START__' ? ' mm-start' : '') + (n.title === '__END__' ? ' mm-endnode' : '')
        + (n.nodeType === 'raw' ? ' mm-raw' : '') + (n.title === curTitle ? ' cur' : '')
        + (warn.has(n.title) ? ' mm-warn' : '');
      const label = n.title === '__START__' ? 'START' : (n.title === '__END__' ? 'END' : n.title);
      parts.push(`<rect class="${cls}" data-title="${esc(n.title)}" x="${n.x}" y="${n.y}" width="${s.w}" height="${s.h}" rx="14"><title>${esc(label)}</title></rect>`);
    }
    minimap.innerHTML = parts.join('');
  }

  function renderNodeList(tab) {
    if (!nodeListEl) return;
    const warn = tab._warnings || new Map();
    const real = flowOrder(tab.nodes, tab.startAlias && tab.startAlias.node.goto);
    nodeCountEl.textContent = `(${real.length})`;
    nodeListEl.innerHTML = real.map(n => {
      const w = warn.get(n.title);
      return `<li class="nl-item${n.title === curTitle ? ' cur' : ''}" data-title="${esc(n.title)}">`
        + `<span class="nl-t">${esc(n.title)}</span>`
        + (w ? `<span class="nl-warn" title="${esc(w.join('\n'))}">⚠</span>` : '')
        + '</li>';
    }).join('');
  }

  function refreshSide() {
    const tab = boundTab;
    if (!tab) return;
    tab._warnings = analyzeNodes(tab);
    renderMinimap(tab);
    renderNodeList(tab);
  }

  function refreshAll() {
    renderHighlight();
    refreshSide();
    updateCursor(true);
  }

  /** Marca el nodo bajo el cursor en minimapa y lista (sin reconstruirlos). */
  /** Desplaza `box` lo mínimo para que `el` quede visible (sin tocar otros contenedores). */
  function scrollInto(box, el) {
    if (!box || !el) return;
    const top = el.offsetTop, bottom = top + el.offsetHeight;
    if (top < box.scrollTop) box.scrollTop = top;
    else if (bottom > box.scrollTop + box.clientHeight) box.scrollTop = bottom - box.clientHeight;
  }

  function highlightCurrentInSide() {
    minimap?.querySelectorAll('.mm-node.cur').forEach(el => el.classList.remove('cur'));
    nodeListEl?.querySelectorAll('.nl-item.cur').forEach(el => el.classList.remove('cur'));
    if (!curTitle) return;
    minimap?.querySelectorAll('.mm-node').forEach(el => { if (el.dataset.title === curTitle) el.classList.add('cur'); });
    nodeListEl?.querySelectorAll('.nl-item').forEach(el => {
      if (el.dataset.title === curTitle) {
        el.classList.add('cur');
        scrollInto(nodeListEl, el);
      }
    });
  }

  // ------------------------------------------------------------
  // Cursor, saltos
  // ------------------------------------------------------------

  function updateCursor(force) {
    if (!boundTab) return;
    const text = ta.value;
    const pos = ta.selectionStart;
    const r = currentNodeRange(text, pos);
    const title = r ? r.title : '';
    if (title !== curTitle || force) {
      curTitle = title;
      highlightCurrentInSide();
    }
    boundTab.cursorTitle = curTitle;
    markCurrentLine();

    // Salir de una línea: crea los nodos de destino que falten
    const idx = lineIndexAt(text, pos);
    if (headerWatch && headerWatch.idx !== idx) finalizeHeaderWatch();
    if (!headerWatch) {
      const lt = text.split('\n')[idx] || '';
      if (lt.startsWith('~ ')) headerWatch = { idx, title: lt.slice(2).trim() };
    }
    if (lastLineIdx >= 0 && idx !== lastLineIdx && !busy) {
      const prev = text.split('\n')[lastLineIdx];
      if (prev !== undefined) completeLine(lastLineIdx);
    }
    lastLineIdx = idx;
  }

  /**
   * Al salir de un encabezado `~ titulo` editado, actualiza los `=> titulo` que apuntaban al
   * título anterior (igual que renombrar en el canvas).
   */
  function finalizeHeaderWatch(force) {
    const w = headerWatch;
    headerWatch = null;
    if (!w || !boundTab) return;
    const text = ta.value;
    const lines = text.split('\n');
    const line = lines[w.idx];
    if (line === undefined || !line.startsWith('~ ')) return;
    const typed = line.slice(2).trim();
    if (!typed) return;
    const edited = typed !== w.title;
    const target = validTitle(typed);
    const fixHeader = target !== typed && target !== '' && (edited || force);
    if (!edited && !fixHeader) return;
    // Referencias: al título anterior (si ya no existe) y al texto escrito (p. ej. "=> Bien Venida")
    const stillOld = collectTitles(text).has(w.title);
    const map = new Map();
    if (edited && !stillOld) map.set(w.title, target);
    if (fixHeader) map.set(typed, target);
    const updated = rewriteDestsInText(text, (d) => map.get(d)).split('\n');
    if (updated.length !== lines.length) return;
    if (fixHeader) updated[w.idx] = '~ ' + target;
    // Caret por (línea, columna) para que los cambios en otras líneas no lo muevan
    const pos = ta.selectionStart;
    const cLine = lineIndexAt(text, pos);
    const cCol = pos - lineInfo(text, pos).start;
    const starts = [];
    let off = 0;
    for (const l of lines) { starts.push(off); off += l.length + 1; }
    let changed = 0;
    for (let i = lines.length - 1; i >= 0; i--) {
      if (lines[i] !== updated[i]) {
        replaceRange(starts[i], starts[i] + lines[i].length, updated[i]);
        changed++;
      }
    }
    if (changed) {
      const now = ta.value;
      const ls = now.split('\n');
      let o = 0;
      for (let i = 0; i < cLine; i++) o += ls[i].length + 1;
      const np = Math.min(o + cCol, now.length);
      ta.setSelectionRange(np, np);
      toast(fixHeader
        ? `Título «${typed}» → «${target}» (sin espacios)`
        : `Referencias a «${w.title}» actualizadas a «${target}»`);
    }
  }

  function jumpToNode(title, opts = {}) {
    const r = nodeRanges(ta.value).find(x => x.title === title);
    if (!r) return false;
    if (!opts.noPush) jumpStack.push(ta.selectionStart);
    ta.focus();
    ta.setSelectionRange(r.hdrEnd, r.hdrEnd);
    const c = caretXY(r.start);
    ta.scrollTop = Math.max(0, c.y - ta.clientHeight * 0.25);
    syncScroll();
    lastLineIdx = lineIndexAt(ta.value, r.hdrEnd);
    updateCursor();
    return true;
  }

  function jumpBack() {
    if (!jumpStack.length) return;
    const pos = Math.min(jumpStack.pop(), ta.value.length);
    ta.focus();
    ta.setSelectionRange(pos, pos);
    const c = caretXY(pos);
    ta.scrollTop = Math.max(0, c.y - ta.clientHeight * 0.3);
    syncScroll();
    lastLineIdx = lineIndexAt(ta.value, pos);
    updateCursor();
  }

  function jumpToDestAtCaret(strict, pos) {
    const li = lineInfo(ta.value, pos);
    const d = destOnLine(li.text);
    if (!d) return false;
    const col = pos - li.start;
    if (strict && (col < d.s || col > d.e)) return false;
    if (d.dest === 'END') { toast('«END» termina el diálogo'); return true; }
    if (!jumpToNode(d.dest)) toast(`El nodo «${d.dest}» no existe`);
    return true;
  }

  // ------------------------------------------------------------
  // Toast
  // ------------------------------------------------------------

  function toast(msg) {
    if (!toastEl) return;
    toastEl.textContent = msg;
    toastEl.classList.remove('hidden');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.add('hidden'), 2400);
  }

  // ------------------------------------------------------------
  // Creación de nodos "a la par"
  // ------------------------------------------------------------

  /** Reemplaza [a, b) conservando el cursor y el scroll (el cursor se desplaza si estaba después). */
  function editKeepCaret(a, b, str) {
    const s = ta.selectionStart, e = ta.selectionEnd, top = ta.scrollTop;
    const d = str.length - (b - a);
    const adj = (p) => (p > b || (p === b && a !== b) ? p + d : p); // inserción pura en el caret: el caret se queda delante
    replaceRange(a, b, str);
    ta.setSelectionRange(adj(s), adj(e));
    ta.scrollTop = top;
    syncScroll();
  }

  /**
   * Inserta el stub `~ dest => END` justo después del nodo que contiene `originPos` (y de los nodos
   * contiguos a los que ese nodo ya apunta), para que el texto conserve el flujo pregunta → respuestas.
   */
  function insertStub(dest, originPos) {
    const t = ta.value;
    const ranges = nodeRanges(t);
    let i = -1;
    ranges.forEach((r, k) => { if (r.start <= originPos) i = k; });
    if (i < 0) i = ranges.length - 1;
    let at = t.length;
    if (i >= 0) {
      const targets = new Set();
      const own = t.slice(ranges[i].start, ranges[i].end);
      rewriteDestsInText(own, (d) => { targets.add(d); });
      let j = i;
      while (j + 1 < ranges.length && targets.has(ranges[j + 1].title)) j++;
      at = ranges[j].end;
    }
    let str;
    if (at >= t.length) {
      const sep = t.endsWith('\n\n') ? '' : (t.endsWith('\n') ? '\n' : (t === '' ? '' : '\n\n'));
      str = `${sep}~ ${dest}\n\n=> END\n`;
    } else {
      const before = t.slice(0, at);
      const sep = before.endsWith('\n\n') ? '' : (before.endsWith('\n') ? '\n' : '\n\n');
      str = `${sep}~ ${dest}\n\n=> END\n\n`;
    }
    editKeepCaret(at, at, str);
    toast(`Nodo «${dest}» creado`);
    lastLineIdx = lineIndexAt(ta.value, ta.selectionStart);
  }

  /**
   * Completa la línea `lineIdx`: una opción "- texto" sin destino recibe "=> <nodo>_<slug>" y, si el
   * destino de la línea no existe, se crea su nodo stub tras el nodo de origen.
   */
  function completeLine(lineIdx) {
    if (typeof autoNodesEnabled === 'function' && !autoNodesEnabled()) return false;
    const t = ta.value;
    const lines = t.split('\n');
    const line = lines[lineIdx];
    if (line === undefined) return false;
    const tt = line.trim();
    if (!(tt.startsWith('=>') || /^-\s/.test(tt))) return false;
    let ls = 0;
    for (let i = 0; i < lineIdx; i++) ls += lines[i].length + 1;

    let dest;
    const om = line.match(/^(\s*)-\s+(.+?)\s*$/);
    const noDest = om && (!/=>/.test(om[2]) || /\s=>\s*$/.test(om[2]));
    if (noDest) {
      const label = om[2].replace(/\s*(=>|->)\s*$/, '').trim();
      if (!label) return false;
      const origin = currentNodeRange(t, ls);
      const base = ((origin && origin.title) || 'nodo') + '_' + slugify(label);
      dest = uniqueTitle(base, collectTitles(t));
      editKeepCaret(ls, ls + line.length, `${om[1]}- ${label} => ${dest}`);
    } else {
      const d = destOnLine(tt);
      if (!d) return false;
      dest = d.dest;
      if (dest === 'END' || dest === '__END__' || dest === '__START__') return false;
      const vd = validTitle(dest);
      if (vd !== dest) {
        if (!vd || !/^[^\s!{}\[\]<>"'=]+$/.test(vd)) return false;
        // El destino abarca hasta el final de la línea: se normaliza a la versión válida
        const nl = rewriteDestsInText(line, () => vd);
        editKeepCaret(ls, ls + line.length, nl);
        toast(`Destino «${dest}» → «${vd}» (sin espacios)`);
        dest = vd;
      }
      if (!/^[^\s!{}\[\]<>"'=]+$/.test(dest)) return false;
      if (collectTitles(t).has(dest)) return false;
    }
    insertStub(dest, ls);
    return true;
  }

  // ------------------------------------------------------------
  // Escritura rápida
  // ------------------------------------------------------------

  /** Otro orador distinto de `current`: primero dentro del nodo, luego el archivo (hacia atrás y adelante). */
  function otherActor(lineIdx, current) {
    const lines = ta.value.split('\n');
    const actorAt = (i) => { const sp = splitActor(lines[i]); return sp ? sp.actor : null; };
    // 1) hacia atrás dentro del nodo
    for (let i = lineIdx - 1; i >= 0; i--) {
      if (lines[i].startsWith('~ ')) break;
      const a = actorAt(i);
      if (a && a !== current) return a;
    }
    // 2) hacia atrás en el archivo
    for (let i = lineIdx - 1; i >= 0; i--) {
      const a = actorAt(i);
      if (a && a !== current) return a;
    }
    // 3) hacia adelante
    for (let i = lineIdx + 1; i < lines.length; i++) {
      const a = actorAt(i);
      if (a && a !== current) return a;
    }
    return null;
  }

  function handleEnter() {
    if (ta.selectionStart !== ta.selectionEnd) return false;
    const t = ta.value, pos = ta.selectionStart;
    const li = lineInfo(t, pos);
    if (pos !== li.end) return false; // solo al final de la línea

    // Encabezado de nodo: baja a la primera línea del cuerpo
    if (li.text.startsWith('~ ')) {
      const idx0 = lineIndexAt(t, pos);
      if (isInvalidTitle(li.text.slice(2))) {
        if (!headerWatch || headerWatch.idx !== idx0) headerWatch = { idx: idx0, title: li.text.slice(2).trim() };
        finalizeHeaderWatch(true);
        return handleEnter();
      }
      const next = lineInfo(t, Math.min(li.end + 1, t.length));
      if (li.end >= t.length) { replaceRange(li.end, li.end, '\n\n'); return true; }
      setCaret(next.end === next.start ? next.start : next.start);
      return true;
    }

    const indent = (li.text.match(/^\s*/) || [''])[0];
    const sp = splitActor(li.text);

    if (sp && sp.rest.trim() === '') {
      // Solo el prefijo "Actor: " → se borra
      replaceRange(li.start + sp.indent.length, li.end, '');
      return true;
    }
    if (sp) {
      replaceRange(pos, pos, '\n' + indent + sp.actor + ': ');
      return true;
    }

    // Opción ("- texto") o salto: se completa el destino y se crea el nodo si no existe
    if (/^\s*-\s*$/.test(li.text)) {
      // Solo "- ": se borra (igual que el prefijo "Orador: ")
      replaceRange(li.start + indent.length, li.end, '');
      return true;
    }
    if (/^\s*(-\s|=>)/.test(li.text)) {
      const idx = lineIndexAt(t, pos);
      replaceRange(pos, pos, '\n' + indent);
      completeLine(idx);
      scrollCaretIntoView();
      return true;
    }

    if (indent) { replaceRange(pos, pos, '\n' + indent); return true; }
    return false;
  }

  function handleTab() {
    if (ta.selectionStart !== ta.selectionEnd) return false;
    const t = ta.value, pos = ta.selectionStart;
    const li = lineInfo(t, pos);
    const lineIdx = lineIndexAt(t, pos);
    const sp = splitActor(li.text);
    const isEmpty = li.text.trim() === '';

    if (isEmpty) {
      const a = otherActor(lineIdx, '');
      if (!a) return false;
      replaceRange(li.start, li.end, `${a}: `);
      return true;
    }
    if (!sp) return false;
    const atStart = pos <= li.start + sp.indent.length;
    if (!(sp.rest.trim() === '' || atStart)) return false;
    const a = otherActor(lineIdx, sp.actor);
    if (!a) return true; // sin otro orador: no hace nada (evita perder el foco)
    const prefixEnd = li.end - sp.rest.length;
    const from = li.start + sp.indent.length;
    replaceRange(from, prefixEnd, `${a}: `);
    setCaret(from + a.length + 2);
    return true;
  }

  // ------------------------------------------------------------
  // Barra de inserción
  // ------------------------------------------------------------

  /** Inserta `str` en una línea propia; caretOffset = desplazamiento del cursor dentro de str. */
  function insertOnFreshLine(str, caretOffset, selLen = 0) {
    const t = ta.value;
    const s = ta.selectionStart, e = ta.selectionEnd;
    const li = lineInfo(t, s);
    let a, b, pre = '';
    if (li.text.trim() === '') { a = li.start; b = lineInfo(t, e).end; }
    else { a = li.end; b = li.end; pre = '\n'; }
    replaceRange(a, b, pre + str);
    const caret = a + pre.length + caretOffset;
    setCaret(caret, caret + selLen);
  }

  function insertNewNode() {
    const t = ta.value;
    const pos = ta.selectionStart;
    const titles = collectTitles(t);
    let n = 1;
    while (titles.has(`nuevo_nodo_${n}`)) n++;
    const title = `nuevo_nodo_${n}`;
    const r = currentNodeRange(t, pos);
    jumpStack.push(pos);

    let a, b, str, titleStart;
    if (!r) {
      // Antes del primer nodo (cabecera) o texto vacío: se añade al final
      const body = t.replace(/\s+$/, '');
      a = body.length; b = t.length;
      str = (body ? '\n\n' : '') + `~ ${title}\n\n`;
      titleStart = a + (body ? 2 : 0) + 2;
    } else {
      const region = t.slice(r.start, r.end);
      const trimmed = region.replace(/\s+$/, '');
      const hasExit = /^[ \t]*(-[ \t].*)?=>(<)?[ \t]+\S+/m.test(trimmed.split('\n').slice(1).join('\n'));
      const exit = hasExit ? '' : `\n=> ${title}`;
      const hasNext = r.end < t.length;
      a = r.start + trimmed.length;
      b = r.end;
      str = `${exit}\n\n~ ${title}\n\n${hasNext ? '\n' : ''}`;
      titleStart = a + exit.length + 2 + 2;
    }
    replaceRange(a, b, str);
    setCaret(titleStart, titleStart + title.length);
    toast(`Nodo «${title}» creado: escribe para renombrarlo`);
  }

  function insertOption() {
    const s = ta.selectionStart, e = ta.selectionEnd;
    if (s !== e) {
      const sel = ta.value.slice(s, e).replace(/\n/g, ' ');
      replaceRange(s, e, `- ${sel}`);
      setCaret(s + 2 + sel.length);
      return;
    }
    // Línea que solo tiene "Orador: " (continuación automática): se sustituye por la opción
    const li = lineInfo(ta.value, s);
    const sp = splitActor(li.text);
    if (sp && sp.rest.trim() === '') {
      replaceRange(li.start + sp.indent.length, li.end, '- ');
      setCaret(li.start + sp.indent.length + 2);
      return;
    }
    insertOnFreshLine('- ', 2);
  }

  /** Reordena los nodos del texto por flujo (pregunta → respuestas) y conserva el cursor. */
  function orderByFlow() {
    const tab = boundTab;
    if (!tab) return;
    syncFromText(tab);
    const pos = ta.selectionStart;
    const cur = currentNodeRange(ta.value, pos);
    const off = cur ? pos - cur.start : 0;
    if (!applyFlowOrder(tab)) { toast('Los nodos ya están en orden de flujo'); return; }
    const text = serializeDialogue(tab, getVarType);
    replaceRange(0, ta.value.length, text);
    syncFromText(tab);
    const r = cur ? nodeRanges(ta.value).find(x => x.title === cur.title) : null;
    const np = r ? Math.min(r.start + off, ta.value.length) : 0;
    ta.setSelectionRange(np, np);
    scrollCaretIntoView();
    updateCursor(true);
    refreshAll();
    toast('Nodos ordenados por flujo');
  }

  function insertCondition() {
    const head = 'if GameVariables.get_var("';
    insertOnFreshLine(`${head}") == true\n\t`, head.length);
    openAutocomplete();
  }

  function insertVariable() {
    const head = 'do GameVariables.set_var("';
    insertOnFreshLine(`${head}", true)`, head.length);
    openAutocomplete();
  }

  function insertEvent() {
    const head = 'do GameManager.trigger_event("';
    insertOnFreshLine(`${head}")`, head.length);
  }

  function insertEnd() {
    insertOnFreshLine('=> END', 6);
  }

  const ACTIONS = {
    node: insertNewNode, option: insertOption, condition: insertCondition,
    variable: insertVariable, event: insertEvent, end: insertEnd,
  };

  // ------------------------------------------------------------
  // Autocompletado
  // ------------------------------------------------------------

  const ac = { open: false, items: [], idx: 0, kind: '', from: 0, to: 0, query: '', navigated: false };

  function acContext() {
    const t = ta.value, pos = ta.selectionStart;
    if (ta.selectionEnd !== pos) return null;
    const li = lineInfo(t, pos);
    const before = t.slice(li.start, pos);

    let m = before.match(/GameVariables\.(?:get_var|set_var)\(\s*["']([^"']*)$/);
    if (m) {
      const q = m[1];
      const all = [];
      for (const v of AppState.variables) all.push({ value: FLAG_PREFIX + v.name, hint: v.type || 'bool' });
      for (const sv of AppState.systemVars) all.push({ value: sv.path, hint: sv.type });
      const items = all.filter(i => i.value.toLowerCase().includes(q.toLowerCase()));
      return { kind: 'vars', query: q, from: pos - q.length, to: pos, items };
    }

    m = before.match(/=>(?:<)?[ \t]+([^\s]*)$/);
    if (m) {
      const q = m[1];
      const items = [{ value: 'END', hint: 'fin' }];
      for (const r of nodeRanges(t)) items.push({ value: r.title, hint: 'nodo' });
      const seen = new Set();
      const filtered = items.filter(i => {
        if (seen.has(i.value) || !i.value.toLowerCase().startsWith(q.toLowerCase()) || i.value === q) return false;
        seen.add(i.value);
        return true;
      });
      return { kind: 'nodes', query: q, from: pos - q.length, to: pos, items: filtered };
    }

    m = before.match(/^(\s*)([^\s:=~\-#\[\]{}"'(),.!?¿¡]{1,28})$/);
    if (m && pos === li.end && !NOT_TEXT.test(m[2])) {
      const q = m[2];
      const items = collectActors(t)
        .filter(a => a.toLowerCase().startsWith(q.toLowerCase()) && a !== q)
        .map(a => ({ value: a, hint: 'orador' }));
      return { kind: 'actors', query: q, from: pos - q.length, to: pos, items };
    }
    return null;
  }

  function openAutocomplete() {
    if (!ta) return;
    const ctx = acContext();
    if (!ctx || ctx.items.length === 0) { hidePopup(); return; }
    ac.open = true;
    ac.items = ctx.items.slice(0, 40);
    ac.kind = ctx.kind;
    ac.from = ctx.from; ac.to = ctx.to; ac.query = ctx.query;
    ac.idx = 0;
    ac.navigated = false;
    renderPopup();
  }

  function renderPopup() {
    popup.innerHTML = ac.items.map((it, i) =>
      `<div class="ac-item${i === ac.idx ? ' sel' : ''}" data-i="${i}"><span>${esc(it.value)}</span><span class="ac-hint">${esc(it.hint || '')}</span></div>`
    ).join('');
    popup.classList.remove('hidden');
    const c = caretXY(ac.from);
    const left = Math.min(Math.max(8, c.x - ta.scrollLeft), Math.max(8, stack.clientWidth - 260));
    let top = c.y + c.h - ta.scrollTop;
    const ph = popup.offsetHeight;
    if (top + ph > stack.clientHeight - 8) top = Math.max(8, c.y - ta.scrollTop - ph);
    popup.style.left = left + 'px';
    popup.style.top = top + 'px';
    scrollInto(popup, popup.querySelector('.ac-item.sel'));
  }

  function hidePopup() {
    ac.open = false;
    popup?.classList.add('hidden');
  }

  function acceptCompletion() {
    const it = ac.items[ac.idx];
    if (!it) { hidePopup(); return; }
    const { from, to, kind } = ac;
    hidePopup();
    const val = kind === 'actors' ? `${it.value}: ` : it.value;
    replaceRange(from, to, val);
    setCaret(from + val.length);
  }

  // ------------------------------------------------------------
  // Eventos del textarea
  // ------------------------------------------------------------

  function onInput(e) {
    const tab = boundTab;
    if (!tab) return;
    if (ta.value !== tab.scriptText) {
      markDirty();
      tab.scriptText = ta.value;
    }

    // "->" → "=>" (en líneas de opción o al inicio de línea)
    if (!busy && e && e.inputType === 'insertText' && e.data === '>') {
      const pos = ta.selectionStart;
      const li = lineInfo(ta.value, pos);
      const before = ta.value.slice(li.start, pos);
      if (/->$/.test(before) && (/^\s*-\s/.test(before) || /^\s*->$/.test(before))) {
        replaceRange(pos - 2, pos, '=>');
      }
    }

    renderHighlight();
    scheduleParse();
    if (!busy) {
      updateCursor();
      openAutocomplete();
    }
  }

  function onKeyDown(e) {
    const mod = e.ctrlKey || e.metaKey;

    // Popup abierto
    if (ac.open) {
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        ac.idx = (ac.idx + (e.key === 'ArrowDown' ? 1 : -1) + ac.items.length) % ac.items.length;
        ac.navigated = true;
        renderPopup();
        return;
      }
      if (e.key === 'Escape') { e.preventDefault(); hidePopup(); return; }
      if (e.key === 'Tab' && !e.shiftKey) { e.preventDefault(); acceptCompletion(); return; }
      if (e.key === 'Enter' && !mod && !e.shiftKey) {
        if (ac.navigated || (ac.kind !== 'actors' && ac.query === '')) { e.preventDefault(); acceptCompletion(); return; }
        hidePopup();
      }
    }

    // Atajos de inserción (solo con foco en el editor)
    if (mod && e.key === 'Enter') { e.preventDefault(); insertNewNode(); return; }
    if (mod && !e.shiftKey && !e.altKey && e.key.toLowerCase() === 'o') { e.preventDefault(); insertOption(); return; }
    if (mod && !e.shiftKey && !e.altKey && e.key.toLowerCase() === 'i') { e.preventDefault(); insertCondition(); return; }
    if (mod && !e.shiftKey && !e.altKey && e.key === '.') { e.preventDefault(); insertEnd(); return; }
    if (e.altKey && !mod && e.key.toLowerCase() === 'v') { e.preventDefault(); insertVariable(); return; }
    if (e.altKey && !mod && e.key.toLowerCase() === 'e') { e.preventDefault(); insertEvent(); return; }

    if (e.key === 'F12') { e.preventDefault(); jumpToDestAtCaret(false, ta.selectionStart); return; }

    if (e.key === 'Enter' && !mod && !e.shiftKey && !e.altKey && !e.isComposing) {
      if (handleEnter()) e.preventDefault();
      return;
    }

    if (e.key === 'Tab' && !mod && !e.altKey) {
      e.preventDefault();
      if (e.shiftKey) { replaceRange(ta.selectionStart, ta.selectionEnd, '\t'); return; }
      if (!handleTab()) replaceRange(ta.selectionStart, ta.selectionEnd, '\t');
      return;
    }

    if (e.key === 'Escape') hidePopup();
  }

  function onCursorMoved() {
    if (busy) return;
    updateCursor();
    if (ac.open) openAutocomplete();
  }

  // ------------------------------------------------------------
  // Paleta Ctrl+P
  // ------------------------------------------------------------

  const pal = { items: [], idx: 0 };

  function openPalette() {
    if (!boundTab) return;
    paletteEl.classList.remove('hidden');
    paletteInput.value = '';
    filterPalette();
    paletteInput.focus();
  }

  function closePalette(refocus = true) {
    paletteEl.classList.add('hidden');
    if (refocus && boundTab) ta.focus();
  }

  function filterPalette() {
    const q = paletteInput.value.trim().toLowerCase();
    const all = nodeRanges(ta.value).map(r => r.title);
    pal.items = all.filter(t => !q || t.toLowerCase().includes(q))
      .sort((a, b) => {
        const sa = a.toLowerCase().startsWith(q) ? 0 : 1, sb = b.toLowerCase().startsWith(q) ? 0 : 1;
        return sa - sb;
      });
    pal.idx = 0;
    renderPalette();
  }

  function renderPalette() {
    const warn = boundTab?._warnings || new Map();
    paletteList.innerHTML = pal.items.map((t, i) =>
      `<li class="pal-item${i === pal.idx ? ' sel' : ''}" data-i="${i}"><span>${esc(t)}</span>${warn.has(t) ? '<span class="nl-warn">⚠</span>' : ''}</li>`
    ).join('') || '<li class="pal-empty">Sin resultados</li>';
    scrollInto(paletteList, paletteList.querySelector('.sel'));
  }

  function paletteGo(i) {
    const t = pal.items[i];
    closePalette(false);
    if (t) jumpToNode(t);
  }

  // ------------------------------------------------------------
  // Init
  // ------------------------------------------------------------

  function toggleSide() {
    const v = $('writing-view');
    if (!v) return;
    const hidden = v.classList.toggle('side-hidden');
    lsSet(LS_SIDE, hidden ? '0' : '1');
  }

  function init() {
    ta = $('script-editor');
    hl = $('script-hl');
    stack = $('editor-stack');
    popup = $('ac-popup');
    toastEl = $('writing-toast');
    minimap = $('minimap');
    nodeListEl = $('node-list');
    nodeCountEl = $('node-count');
    paletteEl = $('palette');
    paletteInput = $('palette-input');
    paletteList = $('palette-list');
    if (!ta) return;

    ta.addEventListener('input', onInput);
    ta.addEventListener('keydown', onKeyDown);
    ta.addEventListener('keyup', (e) => {
      if (['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End', 'PageUp', 'PageDown'].includes(e.key)) onCursorMoved();
    });
    ta.addEventListener('click', (e) => {
      if ((e.ctrlKey || e.metaKey) && jumpToDestAtCaret(true, ta.selectionStart)) { e.preventDefault(); return; }
      onCursorMoved();
    });
    ta.addEventListener('blur', () => setTimeout(() => { if (document.activeElement !== ta) hidePopup(); }, 120));
    ta.addEventListener('scroll', () => { syncScroll(); if (ac.open) renderPopup(); });
    document.addEventListener('selectionchange', () => {
      if (document.activeElement === ta) onCursorMoved();
    });

    popup.addEventListener('mousedown', (e) => {
      e.preventDefault();
      const it = e.target.closest('.ac-item');
      if (!it) return;
      ac.idx = parseInt(it.dataset.i, 10);
      acceptCompletion();
    });

    // Barra de inserción: no roba el foco del editor
    const bar = $('insert-bar');
    bar?.addEventListener('mousedown', (e) => { if (e.target.closest('button')) e.preventDefault(); });
    bar?.querySelectorAll('button[data-act]').forEach(btn => {
      btn.addEventListener('click', () => { if (!boundTab) return; ta.focus(); ACTIONS[btn.dataset.act]?.(); });
    });
    $('btn-flow-order')?.addEventListener('click', () => { if (boundTab) { ta.focus(); orderByFlow(); } });
    $('btn-palette')?.addEventListener('click', openPalette);
    $('btn-toggle-side')?.addEventListener('click', toggleSide);

    // Minimapa y lista
    minimap.addEventListener('click', (e) => {
      const r = e.target.closest('.mm-node');
      if (!r) return;
      const title = r.dataset.title;
      if (title === '__START__' || title === '__END__') return;
      jumpToNode(title);
    });
    nodeListEl.addEventListener('click', (e) => {
      const li = e.target.closest('.nl-item');
      if (li) jumpToNode(li.dataset.title);
    });

    // Paleta
    paletteInput.addEventListener('input', filterPalette);
    paletteInput.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        if (pal.items.length) pal.idx = (pal.idx + (e.key === 'ArrowDown' ? 1 : -1) + pal.items.length) % pal.items.length;
        renderPalette();
      } else if (e.key === 'Enter') {
        e.preventDefault();
        paletteGo(pal.idx);
      } else if (e.key === 'Escape') {
        e.preventDefault();
        closePalette();
      }
    });
    paletteList.addEventListener('mousedown', (e) => {
      e.preventDefault();
      const li = e.target.closest('.pal-item');
      if (li) paletteGo(parseInt(li.dataset.i, 10));
    });
    paletteEl.addEventListener('mousedown', (e) => { if (e.target === paletteEl) closePalette(); });

    // Atajos globales de la vista Escritura
    document.addEventListener('keydown', (e) => {
      if (!isWritingView()) return;
      const mod = e.ctrlKey || e.metaKey;
      if (mod && !e.shiftKey && !e.altKey && e.key.toLowerCase() === 'p') { e.preventDefault(); openPalette(); return; }
      if (e.altKey && !mod && e.key.toLowerCase() === 'm') { e.preventDefault(); toggleSide(); return; }
      if (e.altKey && !mod && e.key === 'ArrowLeft') { e.preventDefault(); jumpBack(); }
    });
  }

  document.addEventListener('DOMContentLoaded', init);

  // API global (usada por app.js)
  Object.assign(window, {
    getPreferredView, isWritingView, setView, applyViewForTab,
    flushWritingSync, syncModelToWritingEditor: syncModelToEditor, leaveWritingEditor: leaveEditor,
  });
  window.Writing = { analyzeNodes, targetsOf, collectTitles, nodeRanges, slugify, splitActor, orderByFlow };
})();
