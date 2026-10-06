'use strict';

// ============================================================
// DialogueApp — app.js (v3)
// - Selección de nodos + Box Selection con Shift
// - Copiar / Pegar (Ctrl+C / Ctrl+V), Borrar (Supr/Backspace)
// - Atajos: Numpad+ (+ Diálogo), F (Fit)
// - Menú de Variables en Sidebar + Nodo Variable funcional
// - Nodo Evento desacoplado con selector de eventos del juego
// - Panel lateral derecho sincronizado (Inspector)
// ============================================================

const API_BASE = '';

// ============================================================
// 1. STATE
// ============================================================

const AppState = {
  tabs: [],
  activeTabIndex: -1,
  dialogueFiles: [],
  variables: [], // flags de historia: [{ name, type, defaultValue }] (ruta = flag.<name>)
  systemVars: [], // solo lectura: [{ path, type, readonly, description }]
};

// Clipboard para copiar y pegar
let clipboardNodes = [];

// Selección múltiple
const selectedNodeIds = new Set();

// Conexiones interactivas
let isConnecting = false;
let connectFromNodeId = null;
let connectFromChoiceIdx = -1;
let connectPreviewPath = null;

// Arrastre de nodos (individual y múltiple)
let isDraggingNode = false;
let draggingNodeId = null;
let dragNodeOffsets = new Map(); // nodeId -> { x, y }

// Pan del canvas
let isPanning = false;
let panStartX = 0;
let panStartY = 0;

// Box selection con Shift
let isBoxSelecting = false;
let boxStartX = 0;
let boxStartY = 0;

// ============================================================
// 2. API CLIENT
// ============================================================

async function apiGet(path) {
  const r = await fetch(API_BASE + path);
  if (!r.ok) throw new Error(`GET ${path} → ${r.status}`);
  return r.json();
}

async function apiPost(path, body) {
  const r = await fetch(API_BASE + path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!r.ok) throw new Error(`POST ${path} → ${r.status}`);
  return r.json();
}

// ============================================================
// 3. INIT & EVENT BINDINGS
// ============================================================

function init() {
  loadDialogueFiles();
  loadProjectConfig();
  loadSystemVariables();

  // Header & Sidebar
  document.getElementById('btn-new-dialogue')?.addEventListener('click', handleNewDialogue);
  document.getElementById('btn-refresh-files')?.addEventListener('click', loadDialogueFiles);
  document.getElementById('btn-add-variable')?.addEventListener('click', handleAddVariable);
  document.getElementById('btn-save')?.addEventListener('click', saveActiveTab);
  document.getElementById('btn-quick-rewrite')?.addEventListener('click', handleQuickRewrite);
  document.getElementById('btn-new-tab')?.addEventListener('click', handleNewDialogue);

  // Canvas buttons
  document.getElementById('btn-add-node')?.addEventListener('click', () => handleAddGenericNode('dialogue'));
  document.getElementById('btn-add-var-node')?.addEventListener('click', () => handleAddGenericNode('variable'));
  document.getElementById('btn-add-event-node')?.addEventListener('click', () => handleAddGenericNode('event'));
  document.getElementById('btn-add-condition-node')?.addEventListener('click', () => handleAddGenericNode('condition'));
  document.getElementById('btn-fit-view')?.addEventListener('click', handleFitView);

  // Modal
  document.getElementById('modal-overlay')?.addEventListener('click', (e) => {
    if (e.target.id === 'modal-overlay') closeModal();
  });

  initCanvasInteraction();
  initContextMenu();
  initKeyboardShortcuts();

  setStatus('Listo');
  updateEmptyState();
  updateInspector();
}

document.addEventListener('DOMContentLoaded', init);

// ============================================================
// 4. KEYBOARD SHORTCUTS
// ============================================================

function initKeyboardShortcuts() {
  document.addEventListener('keydown', (e) => {
    const activeEl = document.activeElement;
    const isTyping = activeEl && (
      activeEl.tagName === 'INPUT' ||
      activeEl.tagName === 'TEXTAREA' ||
      activeEl.tagName === 'SELECT' ||
      activeEl.isContentEditable
    );

    // Ctrl+S: Guardar
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
      e.preventDefault();
      saveActiveTab();
      return;
    }

    // Escape: cerrar modales o deseleccionar
    if (e.key === 'Escape') {
      closeModal();
      hideContextMenu();
      if (!isTyping) {
        clearSelection();
      }
      return;
    }

    // Ctrl+C: Copiar
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'c' && !isTyping) {
      e.preventDefault();
      copySelectedNodes();
      return;
    }

    // Ctrl+V: Pegar
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'v' && !isTyping) {
      e.preventDefault();
      pasteNodes();
      return;
    }

    // Delete / Backspace: Borrar selección
    if ((e.key === 'Delete' || e.key === 'Backspace') && !isTyping) {
      if (selectedNodeIds.size > 0) {
        e.preventDefault();
        deleteSelectedNodes();
      }
      return;
    }

    // F: Fit view (solo si no estamos escribiendo)
    if (!e.ctrlKey && !e.metaKey && !e.altKey && e.key.toLowerCase() === 'f' && !isTyping) {
      e.preventDefault();
      handleFitView();
      return;
    }

    // + (Numpad o teclado principal): Añadir nodo diálogo (solo si no estamos escribiendo)
    if (!e.ctrlKey && !e.metaKey && !e.altKey && (e.key === '+' || e.code === 'NumpadAdd') && !isTyping) {
      e.preventDefault();
      handleAddGenericNode('dialogue');
      return;
    }

    // V: Añadir nodo variable (solo si no estamos escribiendo)
    if (!e.ctrlKey && !e.metaKey && !e.altKey && e.key.toLowerCase() === 'v' && !isTyping) {
      e.preventDefault();
      handleAddGenericNode('variable');
      return;
    }

    // E: Añadir nodo evento (solo si no estamos escribiendo)
    if (!e.ctrlKey && !e.metaKey && !e.altKey && e.key.toLowerCase() === 'e' && !isTyping) {
      e.preventDefault();
      handleAddGenericNode('event');
      return;
    }

    // C: Añadir nodo condición (solo si no estamos escribiendo)
    if (!e.ctrlKey && !e.metaKey && !e.altKey && e.key.toLowerCase() === 'c' && !isTyping) {
      e.preventDefault();
      handleAddGenericNode('condition');
      return;
    }
  });
}

// ============================================================
// 5. CONFIG & VARIABLES (SIDEBAR)
// ============================================================

const VAR_NAME_RE = /^[a-z][a-z0-9_]*$/;
// FLAG_PREFIX, toVarPath, formatVarValue y generateId vienen de dialogue-format.js

function escapeHtml(str) {
  return String(str ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function validateVarName(name, exceptName) {
  if (!name) return 'El nombre no puede estar vacío.';
  if (!VAR_NAME_RE.test(name)) return 'Nombre inválido: usa minúsculas, números y guion bajo, empezando por letra (a-z0-9_).';
  if (name !== exceptName && AppState.variables.some(v => v.name === name)) return 'Ya existe una variable con ese nombre.';
  return '';
}

/** Busca el tipo declarado de una ruta (flag.* del proyecto o variable del sistema). */
function getVarType(path) {
  if (path.startsWith(FLAG_PREFIX)) {
    const v = AppState.variables.find(f => f.name === path.slice(FLAG_PREFIX.length));
    return v ? (v.type || 'bool') : '';
  }
  const sys = AppState.systemVars.find(sv => sv.path === path);
  if (sys) return sys.type;
  if (path.startsWith('quest.')) return 'string';
  return '';
}

async function loadProjectConfig() {
  try {
    const config = await apiGet('/api/config');
    AppState.variables = config.variables || [];
    renderVariableList();
  } catch (err) {
    console.warn('No se pudo cargar config previa, inicializando vacía:', err);
    AppState.variables = [];
    renderVariableList();
  }
}

async function loadSystemVariables() {
  try {
    AppState.systemVars = await apiGet('/api/system-variables');
  } catch (err) {
    console.warn('No se pudieron cargar las variables del sistema:', err);
    AppState.systemVars = [];
  }
  renderSystemVariableList();
  refreshAllVariableNodes();
}

async function saveProjectConfig() {
  try {
    await apiPost('/api/config', { variables: AppState.variables });
  } catch (err) {
    console.error('Error guardando variables:', err);
  }
}

function renderVariableList() {
  const list = document.getElementById('variable-list');
  if (!list) return;
  list.innerHTML = '';

  AppState.variables.forEach((v, idx) => {
    const li = document.createElement('li');
    li.className = 'var-item';

    const nameSpan = document.createElement('span');
    nameSpan.className = 'var-item-name';
    nameSpan.textContent = v.name;
    nameSpan.title = `${FLAG_PREFIX}${v.name} (${v.type || 'bool'}) = ${v.defaultValue}`;

    const badge = document.createElement('span');
    badge.className = 'var-item-badge type-' + (v.type || 'bool');
    badge.textContent = v.type || 'bool';

    const renBtn = document.createElement('button');
    renBtn.className = 'btn-small';
    renBtn.textContent = '✎';
    renBtn.title = 'Renombrar variable';
    renBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      handleRenameVariable(v);
    });

    const delBtn = document.createElement('button');
    delBtn.className = 'btn-small';
    delBtn.style.color = 'var(--accent-danger)';
    delBtn.textContent = '✕';
    delBtn.title = 'Eliminar variable';
    delBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      if (confirm(`¿Eliminar la variable "${v.name}"?`)) {
        AppState.variables.splice(idx, 1);
        saveProjectConfig();
        renderVariableList();
        refreshAllVariableNodes();
      }
    });

    li.appendChild(nameSpan);
    li.appendChild(badge);
    li.appendChild(renBtn);
    li.appendChild(delBtn);
    list.appendChild(li);
  });
}

function renderSystemVariableList() {
  const list = document.getElementById('system-variable-list');
  if (!list) return;
  list.innerHTML = '';
  AppState.systemVars.forEach(sv => {
    const li = document.createElement('li');
    li.className = 'var-item';
    const nameSpan = document.createElement('span');
    nameSpan.className = 'var-item-name';
    nameSpan.textContent = sv.path;
    nameSpan.title = `${sv.path} (${sv.type}, solo lectura) — ${sv.description || ''}`;
    const badge = document.createElement('span');
    badge.className = 'var-item-badge type-' + sv.type;
    badge.textContent = sv.type;
    li.appendChild(nameSpan);
    li.appendChild(badge);
    list.appendChild(li);
  });
}

function handleRenameVariable(v) {
  const bodyHTML = `
    <label style="font-weight: 600; margin-bottom: 4px; display: block;">Nuevo nombre para "${escapeHtml(v.name)}":</label>
    <input id="modal-var-name" type="text" value="${escapeHtml(v.name)}" autocomplete="off">
    <div id="modal-var-error" style="color: var(--accent-danger); margin-top: 8px; font-size: 12px;"></div>
  `;
  showModal({
    title: 'Renombrar Variable',
    bodyHTML,
    onConfirm: () => {
      const name = document.getElementById('modal-var-name')?.value.trim() || '';
      if (name === v.name) return true;
      const err = validateVarName(name, v.name);
      if (err) {
        const errEl = document.getElementById('modal-var-error');
        if (errEl) errEl.textContent = err;
        return false;
      }
      const oldPath = FLAG_PREFIX + v.name;
      const newPath = FLAG_PREFIX + name;
      // Actualiza referencias en las pestañas abiertas (los archivos en disco no se tocan hasta guardarlos)
      for (const tab of AppState.tabs) {
        let touched = false;
        for (const n of tab.nodes) {
          if (n.varName === oldPath) { n.varName = newPath; touched = true; }
          if (n.conditionVar === oldPath) { n.conditionVar = newPath; touched = true; }
        }
        if (touched) {
          tab.rev = (tab.rev || 0) + 1;
          tab.isDirty = true;
        }
      }
      v.name = name;
      saveProjectConfig();
      renderVariableList();
      updateTabBar();
      refreshAllVariableNodes();
      setStatus(`Variable renombrada a "${name}"`, 'success');
      return true;
    }
  });
}

function handleAddVariable() {
  const bodyHTML = `
    <label style="font-weight: 600; margin-bottom: 4px; display: block;">Nombre de la Variable (flag.&lt;nombre&gt;):</label>
    <input id="modal-var-name" type="text" placeholder="ej. tiene_llave, oro_reclamado" autocomplete="off" style="margin-bottom: 12px;">
    
    <label style="font-weight: 600; margin-bottom: 4px; display: block;">Tipo:</label>
    <select id="modal-var-type" style="margin-bottom: 12px;">
      <option value="bool">Booleano (true / false)</option>
      <option value="int">Entero (Número)</option>
      <option value="float">Decimal (Float)</option>
      <option value="string">Texto (String)</option>
    </select>
    
    <label style="font-weight: 600; margin-bottom: 4px; display: block;">Valor Inicial / Por Defecto:</label>
    <input id="modal-var-default" type="text" placeholder="false (o 0 o texto)" autocomplete="off">
    <div id="modal-var-error" style="color: var(--accent-danger); margin-top: 8px; font-size: 12px;"></div>
  `;

  showModal({
    title: 'Nueva Variable Narrativa',
    bodyHTML,
    onConfirm: () => {
      const name = document.getElementById('modal-var-name')?.value.trim() || '';
      const type = document.getElementById('modal-var-type')?.value || 'bool';
      let defVal = document.getElementById('modal-var-default')?.value.trim();

      const err = validateVarName(name);
      if (err) {
        const errEl = document.getElementById('modal-var-error');
        if (errEl) errEl.textContent = err;
        return false;
      }
      if (defVal === '') {
        defVal = type === 'bool' ? 'false' : (type === 'int' ? '0' : (type === 'float' ? '0.0' : ''));
      }

      AppState.variables.push({ name, type, defaultValue: defVal });
      saveProjectConfig();
      renderVariableList();
      refreshAllVariableNodes();
      setStatus(`Variable "${name}" creada`, 'success');
      return true;
    }
  });
}

function refreshAllVariableNodes() {
  const tab = getActiveTab();
  if (tab) renderCanvas(tab);
  updateInspector();
}

// ============================================================
// 6. FILE MANAGEMENT
// ============================================================

async function loadDialogueFiles() {
  try {
    const files = await apiGet('/api/dialogues');
    AppState.dialogueFiles = Array.isArray(files) ? files : [];
    renderFileList();
  } catch (err) {
    setStatus('Error cargando archivos: ' + err.message, 'error');
  }
}

function renderFileList() {
  const list = document.getElementById('file-list');
  if (!list) return;
  list.innerHTML = '';
  for (const file of AppState.dialogueFiles) {
    const li = document.createElement('li');
    li.className = 'file-item';
    li.dataset.path = file.relPath;
    li.textContent = '📄 ' + file.name;
    li.title = file.relPath;
    li.addEventListener('click', () => openFile(file.relPath));
    list.appendChild(li);
  }
}

async function openFile(relPath) {
  const existingIdx = AppState.tabs.findIndex(t => t.relPath === relPath);
  if (existingIdx !== -1) {
    activateTab(existingIdx);
    return;
  }

  try {
    setStatus('Abriendo ' + relPath + '…');
    const result = await apiGet('/api/dialogues/read?path=' + encodeURIComponent(relPath));
    const content = typeof result === 'string' ? result : (result.content || '');

    let layoutData = {};
    try {
      layoutData = await loadLayout(relPath);
    } catch (_) {}

    const { header, nodes } = parseDialogueFile(content, layoutData);

    const tabData = {
      relPath,
      title: relPath.split('/').pop(),
      header, // texto literal previo al primer "~ " (imports, using, comentarios)
      nodes,
      isDirty: false,
      rev: 0, // contador de ediciones (para no perder cambios hechos mientras se guarda)
      saving: false,
      canvas: { zoom: 1, panX: 0, panY: 0 },
    };

    AppState.tabs.push(tabData);
    activateTab(AppState.tabs.length - 1);
    setStatus('Abierto: ' + tabData.title, 'success');
  } catch (err) {
    setStatus('Error: ' + err.message, 'error');
  }
}

async function saveActiveTab() {
  const tab = getActiveTab();
  if (!tab) {
    setStatus('No hay archivo abierto', 'error');
    return;
  }

  if (tab.saving) return; // ya hay un guardado en curso

  tab.saving = true;
  const revAtStart = tab.rev || 0;
  try {
    setStatus('Guardando…');
    const content = serializeDialogue(tab, getVarType);
    await apiPost('/api/dialogues/save', { path: tab.relPath, content });
    await saveLayout(tab);
    // Si hubo ediciones mientras se guardaba, la pestaña sigue sucia
    if ((tab.rev || 0) === revAtStart) tab.isDirty = false;
    updateTabBar();
    setStatus('Guardado: ' + tab.title, 'success');
  } catch (err) {
    setStatus('Error guardando: ' + err.message, 'error');
  } finally {
    tab.saving = false;
  }
}

// ============================================================
// 7. TAB SYSTEM
// ============================================================

function getActiveTab() {
  if (AppState.activeTabIndex < 0 || AppState.activeTabIndex >= AppState.tabs.length) return null;
  return AppState.tabs[AppState.activeTabIndex];
}

function activateTab(index) {
  clearSelection();
  AppState.activeTabIndex = index;
  updateTabBar();
  const tab = getActiveTab();
  if (tab) {
    renderCanvas(tab);
  } else {
    updateEmptyState();
  }
  updateInspector();
}

function closeTab(index) {
  const tab = AppState.tabs[index];
  if (!tab) return;
  if (tab.isDirty && !window.confirm(`"${tab.title}" tiene cambios sin guardar. ¿Cerrar?`)) return;

  AppState.tabs.splice(index, 1);
  if (AppState.tabs.length === 0) {
    AppState.activeTabIndex = -1;
    clearCanvas();
  } else {
    activateTab(Math.min(index, AppState.tabs.length - 1));
  }
  updateTabBar();
}

function updateTabBar() {
  const container = document.getElementById('tabs-container');
  if (!container) return;
  container.innerHTML = '';

  AppState.tabs.forEach((tab, i) => {
    const div = document.createElement('div');
    div.className = 'tab' + (i === AppState.activeTabIndex ? ' active' : '') + (tab.isDirty ? ' dirty' : '');
    div.title = tab.relPath;
    div.innerHTML = `📄 ${escapeHtml(tab.title)} <span class="tab-close" data-idx="${i}">×</span>`;
    div.addEventListener('click', (e) => {
      if (e.target.classList.contains('tab-close')) closeTab(parseInt(e.target.dataset.idx));
      else activateTab(i);
    });
    container.appendChild(div);
  });
  updateEmptyState();
}

function markDirty() {
  const tab = getActiveTab();
  if (!tab) return;
  tab.rev = (tab.rev || 0) + 1;
  if (!tab.isDirty) {
    tab.isDirty = true;
    updateTabBar();
  }
}

function updateEmptyState() {
  const hasTab = AppState.activeTabIndex >= 0 && AppState.tabs.length > 0;
  document.getElementById('canvas-empty-state')?.classList.toggle('hidden', hasTab);
  document.getElementById('canvas-controls')?.classList.toggle('hidden', !hasTab);
}

function clearCanvas() {
  const nl = document.getElementById('nodes-layer');
  const svg = document.getElementById('connections-svg');
  if (nl) nl.innerHTML = '';
  if (svg) svg.innerHTML = '';
  updateEmptyState();
  updateInspector();
}

// ============================================================
// 8. PARSER / SERIALIZER
// Viven en dialogue-format.js (parseDialogueFile, serializeDialogue,
// forEachNodeRef, renameNode, etc.), cargado antes que este script.
// ============================================================

// ============================================================
// 10. CANVAS RENDERING
// ============================================================

function renderCanvas(tabData) {
  const nodesLayer = document.getElementById('nodes-layer');
  const svg = document.getElementById('connections-svg');
  if (!nodesLayer || !svg) return;

  nodesLayer.innerHTML = '';
  svg.innerHTML = '';
  if (!tabData) {
    updateEmptyState();
    return;
  }
  updateEmptyState();
  applyCanvasTransform(tabData);

  for (const node of tabData.nodes) {
    nodesLayer.appendChild(createNodeElement(node, tabData));
  }

  requestAnimationFrame(() => renderConnections(tabData));
}

function applyCanvasTransform(tab) {
  const vp = document.getElementById('canvas-viewport');
  if (vp) {
    vp.style.transform = `scale(${tab.canvas.zoom}) translate(${tab.canvas.panX}px, ${tab.canvas.panY}px)`;
  }
  const cc = document.getElementById('canvas-container');
  if (cc) {
    const size = 32 * tab.canvas.zoom;
    const posX = (tab.canvas.panX * tab.canvas.zoom) % size;
    const posY = (tab.canvas.panY * tab.canvas.zoom) % size;
    cc.style.backgroundPosition = `${posX}px ${posY}px`;
    cc.style.backgroundSize = `${size}px ${size}px`;
  }
  const zl = document.getElementById('zoom-label');
  if (zl) zl.textContent = Math.round(tab.canvas.zoom * 100) + '%';
}

// ============================================================
// 11. NODE ELEMENTS (DOM GENERATION)
// ============================================================

function createNodeElement(node, tabData) {
  const div = document.createElement('div');
  div.className = 'dialogue-node';
  div.dataset.id = node.id;
  div.style.left = node.x + 'px';
  div.style.top = node.y + 'px';

  if (selectedNodeIds.has(node.id)) {
    div.classList.add('selected');
  }

  const isStart = node.title === '__START__';
  const isEnd = node.title === '__END__';

  if (isStart) div.classList.add('node-start');
  if (isEnd) div.classList.add('node-end');
  if (node.nodeType === 'variable') div.classList.add('node-variable');
  if (node.nodeType === 'event') div.classList.add('node-event');
  if (node.nodeType === 'condition') div.classList.add('node-condition');
  if (node.nodeType === 'raw') div.classList.add('node-raw');

  // --- HEADER ---
  const header = document.createElement('div');
  header.className = 'node-header';

  // Puerto de entrada (todos menos START)
  if (!isStart) {
    const portIn = document.createElement('span');
    portIn.className = 'port-in';
    portIn.dataset.nodeId = node.id;
    header.appendChild(portIn);
  }

  if (isStart || isEnd) {
    const titleSpan = document.createElement('input');
    titleSpan.className = 'node-title-input';
    titleSpan.value = isStart ? '▶ START' : '⬛ END';
    titleSpan.readOnly = true;
    titleSpan.style.cursor = 'default';
    header.appendChild(titleSpan);
  } else {
    const titleInput = document.createElement('input');
    titleInput.className = 'node-title-input';
    titleInput.value = node.title;
    titleInput.placeholder = 'nombre_nudo';
    titleInput.readOnly = true;
    titleInput.title = 'Doble clic para renombrar';

    titleInput.addEventListener('dblclick', (e) => {
      e.stopPropagation();
      titleInput.readOnly = false;
      titleInput.classList.add('editing');
      titleInput.focus();
      titleInput.select();
    });

    const finishEditing = () => {
      if (titleInput.readOnly) return;
      titleInput.readOnly = true;
      titleInput.classList.remove('editing');
      const sanitized = titleInput.value.replace(/\s+/g, '_').trim();
      if (sanitized && sanitized !== node.title) {
        if (applyNodeRename(tabData, node, sanitized)) {
          markDirty();
          renderCanvas(tabData);
          updateInspector();
          return;
        }
      }
      titleInput.value = node.title; // vacío, sin cambios o rechazado: se revierte
      updateInspector();
    };

    titleInput.addEventListener('blur', finishEditing);
    titleInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        titleInput.blur();
      } else if (e.key === 'Escape') {
        titleInput.value = node.title;
        titleInput.blur();
      }
    });

    titleInput.addEventListener('input', () => {
      const sanitized = titleInput.value.replace(/\s+/g, '_');
      titleInput.value = sanitized;
    });

    titleInput.addEventListener('mousedown', (e) => {
      if (!titleInput.readOnly) {
        e.stopPropagation();
      }
    });

    header.appendChild(titleInput);
  }

  // START tiene puerto de salida en header
  if (isStart) {
    const portOut = document.createElement('span');
    portOut.className = 'port-out';
    portOut.dataset.sourceId = node.id;
    portOut.dataset.choiceIdx = '-1';
    portOut.title = 'Arrastrar para conectar inicio';
    portOut.addEventListener('mousedown', (e) => {
      e.stopPropagation();
      startConnection(e, node.id, -1);
    });
    header.appendChild(portOut);
  }

  div.appendChild(header);

  // Nodos especiales no tienen cuerpo
  if (isStart || isEnd) {
    attachNodeEventListeners(div, node, tabData);
    return div;
  }

  // --- BODY SEGÚN TIPO DE NODO ---
  const body = document.createElement('div');
  body.className = 'node-body';

  if (node.nodeType === 'raw') {
    // --- NODO RAW (sintaxis no modelable): cuerpo de solo lectura + destinos visuales ---
    const bodyLines = getRawBody(node).replace(/\s+$/, '').split('\n');
    const MAX_LINES = 8;
    const pre = document.createElement('pre');
    pre.className = 'node-raw-body';
    pre.textContent = bodyLines.slice(0, MAX_LINES).join('\n') + (bodyLines.length > MAX_LINES ? '\n…' : '');
    body.appendChild(pre);

    const note = document.createElement('div');
    note.className = 'node-raw-note';
    note.textContent = 'Editar en vista Escritura';
    note.title = 'Sintaxis no representable en el canvas: se conserva tal cual. Edítala como texto en el Inspector.';
    body.appendChild(note);
    div.appendChild(body);

    if ((node.rawTargets || []).length > 0) {
      const outsDiv = document.createElement('div');
      outsDiv.className = 'node-choices';
      node.rawTargets.forEach((target, idx) => {
        const row = document.createElement('div');
        row.className = 'node-choice';
        row.style.justifyContent = 'space-between';

        const lbl = document.createElement('span');
        lbl.className = 'node-raw-target';
        lbl.textContent = `=> ${target}`;

        const portOut = document.createElement('span');
        portOut.className = 'port-out port-readonly';
        portOut.dataset.sourceId = node.id;
        portOut.dataset.rawIdx = String(idx);
        portOut.title = 'Conexión de solo lectura';

        row.appendChild(lbl);
        row.appendChild(portOut);
        outsDiv.appendChild(row);
      });
      div.appendChild(outsDiv);
    }

  } else if (node.nodeType === 'condition') {
    // --- NODO CONDICIÓN ---
    const configDiv = document.createElement('div');
    configDiv.className = 'node-condition-config';

    const rowVar = document.createElement('div');
    rowVar.className = 'node-var-row';
    const lblVar = document.createElement('span');
    lblVar.className = 'node-var-label';
    lblVar.textContent = 'Variable:';

    const selectVar = document.createElement('select');
    selectVar.addEventListener('mousedown', (e) => e.stopPropagation());
    rebuildVariableSelectOptions(selectVar, node.conditionVar, 'get');
    selectVar.addEventListener('change', () => {
      node.conditionVar = selectVar.value;
      markDirty();
      updateInspector();
    });

    rowVar.appendChild(lblVar);
    rowVar.appendChild(selectVar);
    configDiv.appendChild(rowVar);

    const rowMode = document.createElement('div');
    rowMode.className = 'node-var-row';
    const lblMode = document.createElement('span');
    lblMode.className = 'node-var-label';
    lblMode.textContent = node.conditionMode === 'compare' ? 'Compara:' : 'Switch:';

    const modeDisplay = document.createElement('span');
    modeDisplay.style.fontFamily = 'var(--font-mono)';
    modeDisplay.style.fontSize = '11px';
    if (node.conditionMode === 'compare') {
      modeDisplay.textContent = `${node.conditionOperator} ${node.conditionValue}`;
    } else {
      modeDisplay.textContent = `${(node.switchCases || []).length} casos`;
    }

    rowMode.appendChild(lblMode);
    rowMode.appendChild(modeDisplay);
    configDiv.appendChild(rowMode);

    body.appendChild(configDiv);
    div.appendChild(body);

    const choicesDiv = document.createElement('div');
    choicesDiv.className = 'node-choices';

    const outputKeys = node.conditionMode === 'compare' 
      ? ['true', 'false'] 
      : [...(node.switchCases || []), 'default'];

    outputKeys.forEach((key) => {
      const choiceRow = document.createElement('div');
      choiceRow.className = 'node-choice';
      choiceRow.style.justifyContent = 'space-between';

      const lbl = document.createElement('span');
      lbl.textContent = node.conditionMode === 'compare' ? (key === 'true' ? '✅ True' : '❌ False') : (key === 'default' ? 'Default' : `Caso ${key}`);
      lbl.style.fontSize = '11px';

      const portOut = document.createElement('span');
      portOut.className = 'port-out';
      portOut.dataset.sourceId = node.id;
      portOut.dataset.choiceIdx = `cond_${key}`;
      portOut.addEventListener('mousedown', (e) => {
        e.stopPropagation();
        startConnection(e, node.id, `cond_${key}`);
      });

      choiceRow.appendChild(lbl);
      choiceRow.appendChild(portOut);
      choicesDiv.appendChild(choiceRow);
    });

    div.appendChild(choicesDiv);

  } else if (node.nodeType === 'variable') {
    // --- NODO VARIABLE ---
    const configDiv = document.createElement('div');
    configDiv.className = 'node-var-config';
    
    const rowVar = document.createElement('div');
    rowVar.className = 'node-var-row';
    const lblVar = document.createElement('span');
    lblVar.className = 'node-var-label';
    lblVar.textContent = 'Variable:';
    
    const selectVar = document.createElement('select');
    selectVar.addEventListener('mousedown', (e) => e.stopPropagation());
    rebuildVariableSelectOptions(selectVar, node.varName, 'set');
    selectVar.addEventListener('change', () => {
      node.varName = selectVar.value;
      markDirty();
      updateInspector();
    });
    
    rowVar.appendChild(lblVar);
    rowVar.appendChild(selectVar);
    configDiv.appendChild(rowVar);
    
    const rowVal = document.createElement('div');
    rowVal.className = 'node-var-row';
    const lblVal = document.createElement('span');
    lblVal.className = 'node-var-label';
    lblVal.textContent = 'Valor:';
    
    const valInput = document.createElement('input');
    valInput.type = 'text';
    valInput.value = node.varValue ?? 'true';
    valInput.placeholder = 'true / false / 123';
    valInput.addEventListener('mousedown', (e) => e.stopPropagation());
    valInput.addEventListener('input', () => {
      node.varValue = valInput.value;
      markDirty();
      updateInspector();
    });
    
    rowVal.appendChild(lblVal);
    rowVal.appendChild(valInput);
    configDiv.appendChild(rowVal);
    
    body.appendChild(configDiv);
    div.appendChild(body);
    attachSingleOutputFooter(div, node);
  } else if (node.nodeType === 'event') {
    // --- NODO EVENTO ---
    const configDiv = document.createElement('div');
    configDiv.className = 'node-event-config';

    const rowParam = document.createElement('div');
    rowParam.className = 'node-var-row';
    const lblParam = document.createElement('span');
    lblParam.className = 'node-var-label';
    lblParam.textContent = 'Actor / Objeto:';

    const paramInput = document.createElement('input');
    paramInput.type = 'text';
    paramInput.value = node.eventParam || node.eventName || '';
    paramInput.placeholder = 'Nombre del DialogueEvent / Actor';
    paramInput.addEventListener('mousedown', (e) => e.stopPropagation());
    paramInput.addEventListener('input', () => {
      node.eventParam = paramInput.value.trim();
      node.eventName = node.eventParam;
      markDirty();
      updateInspector();
    });

    rowParam.appendChild(lblParam);
    rowParam.appendChild(paramInput);
    configDiv.appendChild(rowParam);

    body.appendChild(configDiv);
    div.appendChild(body);
    attachSingleOutputFooter(div, node);

  } else {
    // --- NODO DIÁLOGO ESTÁNDAR ---
    node.lines.forEach((line, idx) => {
      const row = document.createElement('div');
      row.className = 'node-line-row';

      const actorInput = document.createElement('input');
      actorInput.className = 'node-actor-input';
      actorInput.value = line.actor;
      actorInput.placeholder = 'Orador';
      actorInput.addEventListener('mousedown', (e) => e.stopPropagation());
      actorInput.addEventListener('input', () => {
        line.actor = actorInput.value;
        markDirty();
        updateInspector();
      });

      const textInput = document.createElement('input');
      textInput.className = 'node-text-input';
      textInput.value = line.text;
      textInput.placeholder = 'Texto del diálogo…';
      textInput.addEventListener('mousedown', (e) => e.stopPropagation());
      textInput.addEventListener('input', () => {
        line.text = textInput.value;
        markDirty();
        updateInspector();
      });

      const delBtn = document.createElement('button');
      delBtn.className = 'node-line-delete';
      delBtn.textContent = '✕';
      delBtn.title = 'Eliminar línea';
      delBtn.addEventListener('mousedown', (e) => e.stopPropagation());
      delBtn.addEventListener('click', () => {
        node.lines.splice(idx, 1);
        markDirty();
        renderCanvas(tabData);
        updateInspector();
      });

      row.appendChild(actorInput);
      row.appendChild(textInput);
      row.appendChild(delBtn);
      body.appendChild(row);
    });

    const addLineBtn = document.createElement('button');
    addLineBtn.className = 'node-add-line';
    addLineBtn.textContent = '+ Línea';
    addLineBtn.addEventListener('mousedown', (e) => e.stopPropagation());
    addLineBtn.addEventListener('click', () => {
      node.lines.push({ actor: '', text: '', condition: '' });
      markDirty();
      renderCanvas(tabData);
      updateInspector();
    });
    body.appendChild(addLineBtn);
    div.appendChild(body);

    // Opciones de respuesta (Choices)
    if (node.choices.length > 0) {
      const choicesDiv = document.createElement('div');
      choicesDiv.className = 'node-choices';

      node.choices.forEach((choice, idx) => {
        const choiceDiv = document.createElement('div');
        choiceDiv.className = 'node-choice';

        const labelInput = document.createElement('input');
        labelInput.className = 'node-choice-input';
        labelInput.value = choice.label;
        labelInput.placeholder = 'Opción…';
        labelInput.addEventListener('mousedown', (e) => e.stopPropagation());
        labelInput.addEventListener('input', () => {
          choice.label = labelInput.value;
          markDirty();
          updateInspector();
        });

        const delBtn = document.createElement('button');
        delBtn.className = 'node-choice-delete';
        delBtn.textContent = '✕';
        delBtn.addEventListener('mousedown', (e) => e.stopPropagation());
        delBtn.addEventListener('click', () => {
          node.choices.splice(idx, 1);
          if (node.choices.length === 0) node.goto = 'END';
          markDirty();
          renderCanvas(tabData);
          updateInspector();
        });

        const portOut = document.createElement('span');
        portOut.className = 'port-out';
        portOut.dataset.sourceId = node.id;
        portOut.dataset.choiceIdx = idx;
        portOut.title = 'Conectar opción: → ' + (choice.targetTitle || 'Sin conectar');
        portOut.addEventListener('mousedown', (e) => {
          e.stopPropagation();
          startConnection(e, node.id, idx);
        });

        choiceDiv.appendChild(labelInput);
        choiceDiv.appendChild(delBtn);
        choiceDiv.appendChild(portOut);
        choicesDiv.appendChild(choiceDiv);
      });
      div.appendChild(choicesDiv);
    }

    const addChoiceBtn = document.createElement('button');
    addChoiceBtn.className = 'node-add-choice';
    addChoiceBtn.textContent = '+ Opción';
    addChoiceBtn.addEventListener('mousedown', (e) => e.stopPropagation());
    addChoiceBtn.addEventListener('click', () => {
      node.choices.push({ label: 'Opción', targetTitle: '' });
      node.goto = '';
      markDirty();
      renderCanvas(tabData);
      updateInspector();
    });
    div.appendChild(addChoiceBtn);

    // Salida por defecto si no tiene choices
    if (node.choices.length === 0) {
      attachSingleOutputFooter(div, node);
    }
  }

  attachNodeEventListeners(div, node, tabData);
  return div;
}

function attachSingleOutputFooter(div, node) {
  const footer = document.createElement('div');
  footer.className = 'node-footer';

  const targetName = node.goto ? (node.goto === '__END__' ? 'END' : node.goto) : '(sin salida)';
  const label = document.createElement('span');
  label.style.fontSize = '10px';
  label.style.color = 'var(--text-muted)';
  label.style.fontFamily = 'var(--font-mono)';
  label.textContent = `=> ${targetName}`;

  const portOut = document.createElement('span');
  portOut.className = 'port-out';
  portOut.dataset.sourceId = node.id;
  portOut.dataset.choiceIdx = '-1';
  portOut.title = 'Arrastrar para conectar';
  portOut.addEventListener('mousedown', (e) => {
    e.stopPropagation();
    startConnection(e, node.id, -1);
  });

  footer.appendChild(label);
  footer.appendChild(portOut);
  div.appendChild(footer);
}

/**
 * Rellena un <select> de variables.
 * mode 'set': solo flag.* del proyecto (asignación).
 * mode 'get': flag.* + variables del sistema agrupadas + quest.<id> libre (condición).
 */
function rebuildVariableSelectOptions(selectEl, selectedVal, mode = 'set') {
  selectEl.innerHTML = '';
  const addOpt = (parent, value, text) => {
    const opt = document.createElement('option');
    opt.value = value;
    opt.textContent = text;
    parent.appendChild(opt);
    return opt;
  };
  const addGroup = (label) => {
    const g = document.createElement('optgroup');
    g.label = label;
    selectEl.appendChild(g);
    return g;
  };

  addOpt(selectEl, '', '-- Seleccionar Variable --');
  selectedVal = selectedVal ? toVarPath(selectedVal) : '';
  const known = new Set();

  const gStory = addGroup('Historia');
  AppState.variables.forEach(v => {
    const path = FLAG_PREFIX + v.name;
    known.add(path);
    addOpt(gStory, path, `${path} (${v.type || 'bool'})`);
  });

  if (mode === 'get') {
    const groups = [
      ['Jugador', 'player.'],
      ['Ítems', 'item.'],
      ['Estados', 'status.'],
    ];
    for (const [label, prefix] of groups) {
      const items = AppState.systemVars.filter(sv => sv.path.startsWith(prefix));
      if (items.length === 0) continue;
      const g = addGroup(label);
      items.forEach(sv => {
        known.add(sv.path);
        addOpt(g, sv.path, `${sv.path} (${sv.type})`);
      });
    }
    addOpt(selectEl, '__quest__', 'quest.<id> (escribir misión)...');
  }

  if (selectedVal && !known.has(selectedVal)) {
    const isQuest = mode === 'get' && selectedVal.startsWith('quest.');
    addOpt(selectEl, selectedVal, isQuest ? selectedVal : `${selectedVal} (externa)`);
  }
  selectEl.value = selectedVal;

  if (mode === 'get') {
    // Registrado antes que el listener del llamador: intercepta la opción de misión libre
    let previous = selectedVal;
    selectEl.addEventListener('change', (e) => {
      if (selectEl.value !== '__quest__') {
        previous = selectEl.value;
        return;
      }
      e.stopImmediatePropagation();
      const id = (prompt('Id de la misión (quest.<id>):', '') || '').trim();
      if (!/^[A-Za-z0-9_]+$/.test(id)) {
        if (id) alert('Id inválido: usa letras, números y guion bajo.');
        selectEl.value = previous;
        return;
      }
      const path = `quest.${id}`;
      if (!Array.from(selectEl.options).some(o => o.value === path)) {
        const opt = document.createElement('option');
        opt.value = path;
        opt.textContent = path;
        selectEl.insertBefore(opt, selectEl.querySelector('option[value="__quest__"]'));
      }
      selectEl.value = path;
      previous = path;
      selectEl.dispatchEvent(new Event('change'));
    });
  }
}

function attachNodeEventListeners(div, node, tabData) {
  div.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;
    if (e.target.classList.contains('port-out') || e.target.classList.contains('port-in')) return;

    // Manejo de selección
    if (e.shiftKey) {
      // Toggle en selección múltiple
      if (selectedNodeIds.has(node.id)) {
        selectedNodeIds.delete(node.id);
        div.classList.remove('selected');
      } else {
        selectedNodeIds.add(node.id);
        div.classList.add('selected');
      }
    } else {
      // Si no tiene shift y el nodo no estaba seleccionado, se convierte en la única selección
      if (!selectedNodeIds.has(node.id)) {
        clearSelection();
        selectedNodeIds.add(node.id);
        div.classList.add('selected');
      }
    }

    updateInspector();

    if (e.target.classList.contains('node-title-input')) {
      if (!e.target.readOnly) {
        return;
      }
    } else if (e.target.tagName === 'INPUT' || e.target.tagName === 'BUTTON' || e.target.tagName === 'SELECT' || e.target.tagName === 'TEXTAREA') {
      return;
    }

    e.stopPropagation();
    startNodeDrag(e, node.id);
  });

  div.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    e.stopPropagation();
    showContextMenu(e.clientX, e.clientY);
  });
}

/**
 * Renombra un nodo (rechaza títulos repetidos). Las referencias se actualizan
 * con forEachNodeRef y, en nodos raw, reemplazando los destinos en su texto.
 * @returns {boolean} true si se renombró (o no había cambios)
 */
function applyNodeRename(tab, node, newTitle) {
  const res = renameNode(tab, node, newTitle);
  if (!res.ok) {
    setStatus(res.error, 'error');
    return false;
  }
  return true;
}

// ============================================================
// 12. CONNECTIONS (SVG)
// ============================================================

function renderConnections(tabData) {
  const svg = document.getElementById('connections-svg');
  if (!svg || !tabData) return;
  svg.innerHTML = '';

  if (connectPreviewPath) svg.appendChild(connectPreviewPath);

  const nodeMap = {};
  for (const node of tabData.nodes) nodeMap[node.title] = node;

  for (const node of tabData.nodes) {
    const fromNodeEl = document.querySelector(`.dialogue-node[data-id="${node.id}"]`);
    if (!fromNodeEl) continue;

    if (node.nodeType === 'raw') {
      // Conexiones de solo lectura (punteadas) a partir de los destinos del texto
      (node.rawTargets || []).forEach((target, idx) => {
        const targetNode = nodeMap[target === 'END' ? '__END__' : target];
        if (!targetNode || targetNode === node) return;
        const toNodeEl = document.querySelector(`.dialogue-node[data-id="${targetNode.id}"]`);
        const fromPort = fromNodeEl.querySelector(`.port-out[data-raw-idx="${idx}"]`);
        const toPort = toNodeEl?.querySelector('.port-in');
        if (fromPort && toPort) drawConnection(svg, fromPort, toPort, 'connection-raw');
      });
      continue;
    }

    if (node.nodeType === 'condition') {
      const keys = Object.keys(node.conditionOutputs || {});
      keys.forEach((key) => {
        const targetRaw = node.conditionOutputs[key];
        if (!targetRaw || targetRaw === '') return;
        const targetTitle = targetRaw === 'END' ? '__END__' : targetRaw;
        const targetNode = nodeMap[targetTitle];
        if (!targetNode) return;
        const toNodeEl = document.querySelector(`.dialogue-node[data-id="${targetNode.id}"]`);
        if (!toNodeEl) return;
        
        const fromPort = fromNodeEl.querySelector(`.port-out[data-choice-idx="cond_${key}"]`);
        const toPort = toNodeEl.querySelector('.port-in');
        if (fromPort && toPort) drawConnection(svg, fromPort, toPort);
      });
      continue; // Skip the rest of the node types for connections
    }

    // Conexiones de choices
    node.choices.forEach((choice, idx) => {
      if (!choice.targetTitle || choice.targetTitle === '') return;
      const targetTitle = choice.targetTitle === 'END' ? '__END__' : choice.targetTitle;
      const targetNode = nodeMap[targetTitle];
      if (!targetNode) return;
      const toNodeEl = document.querySelector(`.dialogue-node[data-id="${targetNode.id}"]`);
      if (!toNodeEl) return;

      const fromPort = fromNodeEl.querySelector(`.port-out[data-choice-idx="${idx}"]`);
      const toPort = toNodeEl.querySelector('.port-in');
      if (fromPort && toPort) drawConnection(svg, fromPort, toPort);
    });

    // Conexión directa
    if (node.choices.length === 0 && node.goto && node.goto !== '') {
      const targetTitle = node.goto === 'END' ? '__END__' : node.goto;
      const targetNode = nodeMap[targetTitle];
      if (targetNode) {
        const toNodeEl = document.querySelector(`.dialogue-node[data-id="${targetNode.id}"]`);
        if (toNodeEl) {
          const fromPort = fromNodeEl.querySelector('.port-out[data-choice-idx="-1"]');
          const toPort = toNodeEl.querySelector('.port-in');
          if (fromPort && toPort) drawConnection(svg, fromPort, toPort);
        }
      }
    }
  }
}

function drawConnection(svg, fromEl, toEl, extraClass) {
  const tab = getActiveTab();
  const zoom = tab ? tab.canvas.zoom : 1;
  const vpRect = document.getElementById('canvas-viewport')?.getBoundingClientRect();
  if (!vpRect) return;

  const fromRect = fromEl.getBoundingClientRect();
  const toRect = toEl.getBoundingClientRect();

  const x1 = (fromRect.left + fromRect.width / 2 - vpRect.left) / zoom;
  const y1 = (fromRect.top + fromRect.height / 2 - vpRect.top) / zoom;
  const x2 = (toRect.left + toRect.width / 2 - vpRect.left) / zoom;
  const y2 = (toRect.top + toRect.height / 2 - vpRect.top) / zoom;

  const dx = Math.abs(x2 - x1) * 0.45 + 30;
  const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  path.setAttribute('class', 'connection' + (extraClass ? ' ' + extraClass : ''));
  path.setAttribute('d', `M${x1},${y1} C${x1 + dx},${y1} ${x2 - dx},${y2} ${x2},${y2}`);
  path.setAttribute('fill', 'none');
  svg.appendChild(path);
}

// ============================================================
// 13. DRAG-CONNECT
// ============================================================

function startConnection(e, nodeId, choiceIdx) {
  isConnecting = true;
  connectFromNodeId = nodeId;
  connectFromChoiceIdx = choiceIdx;

  const canvasContainer = document.getElementById('canvas-container');
  if (canvasContainer) canvasContainer.classList.add('connecting');

  connectPreviewPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  connectPreviewPath.setAttribute('class', 'connection-preview');
  connectPreviewPath.setAttribute('fill', 'none');
  const svg = document.getElementById('connections-svg');
  if (svg) svg.appendChild(connectPreviewPath);

  e.preventDefault();
}

function handleConnectionMove(e) {
  if (!isConnecting || !connectPreviewPath) return;

  const tab = getActiveTab();
  if (!tab) return;
  const zoom = tab.canvas.zoom;
  const vpRect = document.getElementById('canvas-viewport')?.getBoundingClientRect();
  if (!vpRect) return;

  const fromNodeEl = document.querySelector(`.dialogue-node[data-id="${connectFromNodeId}"]`);
  if (!fromNodeEl) return;
  const selector = `.port-out[data-choice-idx="${connectFromChoiceIdx}"]`;
  const fromPort = fromNodeEl.querySelector(selector);
  if (!fromPort) return;

  const fromRect = fromPort.getBoundingClientRect();
  const x1 = (fromRect.left + fromRect.width / 2 - vpRect.left) / zoom;
  const y1 = (fromRect.top + fromRect.height / 2 - vpRect.top) / zoom;
  const x2 = (e.clientX - vpRect.left) / zoom;
  const y2 = (e.clientY - vpRect.top) / zoom;

  const dx = Math.abs(x2 - x1) * 0.45 + 30;
  connectPreviewPath.setAttribute('d', `M${x1},${y1} C${x1 + dx},${y1} ${x2 - dx},${y2} ${x2},${y2}`);

  // Resaltado de nodo destino potencial
  document.querySelectorAll('.dialogue-node.drop-target').forEach(el => el.classList.remove('drop-target'));
  const hovered = document.elementFromPoint(e.clientX, e.clientY)?.closest('.dialogue-node');
  if (hovered && hovered.dataset.id !== connectFromNodeId) {
    const targetNode = tab.nodes.find(n => n.id === hovered.dataset.id);
    if (targetNode && targetNode.title !== '__START__') {
      hovered.classList.add('drop-target');
    }
  }
}

/**
 * Conecta el nodo visual START con un destino.
 * Si ya existe un nodo `start` real, solo se redirige cuando es un alias simple
 * (sin líneas ni opciones); si no, START emite un `~ start` nuevo al serializar.
 * @returns {boolean} true si hubo cambio
 */
function connectStartTo(tab, startNode, targetNode) {
  const realStart = tab.nodes.find(n => n.title === 'start');
  if (!realStart) {
    startNode.goto = targetNode.title;
    startNode.startTouched = true;
    return true;
  }
  if (realStart === targetNode) return false;
  const isAlias = realStart.nodeType === 'dialogue' && realStart.lines.length === 0 && realStart.choices.length === 0;
  if (!isAlias) {
    setStatus('El nodo "start" tiene contenido propio: conecta su salida en lugar de START.', 'error');
    return false;
  }
  realStart.goto = targetNode.title;
  return true;
}

function endConnection(e) {
  if (!isConnecting) return;

  const canvasContainer = document.getElementById('canvas-container');
  if (canvasContainer) canvasContainer.classList.remove('connecting');

  document.querySelectorAll('.dialogue-node.drop-target').forEach(el => el.classList.remove('drop-target'));

  const target = document.elementFromPoint(e.clientX, e.clientY);
  const targetNodeEl = target?.closest('.dialogue-node');

  if (targetNodeEl) {
    const targetNodeId = targetNodeEl.dataset.id;
    if (targetNodeId && targetNodeId !== connectFromNodeId) {
      const tab = getActiveTab();
      if (tab) {
        const sourceNode = tab.nodes.find(n => n.id === connectFromNodeId);
        const targetNode = tab.nodes.find(n => n.id === targetNodeId);
        if (sourceNode && targetNode && targetNode.title !== '__START__') {
          let changed = true;
          if (typeof connectFromChoiceIdx === 'string' && connectFromChoiceIdx.startsWith('cond_')) {
            const key = connectFromChoiceIdx.replace('cond_', '');
            sourceNode.conditionOutputs[key] = targetNode.title;
          } else if (connectFromChoiceIdx >= 0 && sourceNode.choices[connectFromChoiceIdx]) {
            sourceNode.choices[connectFromChoiceIdx].targetTitle = targetNode.title;
          } else if (sourceNode.title === '__START__') {
            changed = connectStartTo(tab, sourceNode, targetNode);
          } else if (sourceNode.nodeType === 'raw') {
            changed = false; // los nodos raw no tienen salidas editables desde el canvas
          } else {
            sourceNode.goto = targetNode.title;
          }
          if (changed) {
            markDirty();
            renderCanvas(tab);
            updateInspector();
          }
        }
      }
    }
  } else {
    // Soltado en vacío -> conectar directamente con END
    const tab = getActiveTab();
    if (tab) {
      const sourceNode = tab.nodes.find(n => n.id === connectFromNodeId);
      if (sourceNode) {
        if (typeof connectFromChoiceIdx === 'string' && connectFromChoiceIdx.startsWith('cond_')) {
          const key = connectFromChoiceIdx.replace('cond_', '');
          sourceNode.conditionOutputs[key] = 'END';
        } else if (connectFromChoiceIdx >= 0 && sourceNode.choices[connectFromChoiceIdx]) {
          sourceNode.choices[connectFromChoiceIdx].targetTitle = 'END';
        } else if (sourceNode.title !== '__START__') {
          sourceNode.goto = 'END';
        }
        markDirty();
        renderCanvas(tab);
        updateInspector();
      }
    }
  }

  if (connectPreviewPath && connectPreviewPath.parentNode) {
    connectPreviewPath.parentNode.removeChild(connectPreviewPath);
  }
  connectPreviewPath = null;
  isConnecting = false;
  connectFromNodeId = null;
  connectFromChoiceIdx = -1;
}

// ============================================================
// 14. PAN, ZOOM & BOX SELECTION (CANVAS)
// ============================================================

function initCanvasInteraction() {
  const cc = document.getElementById('canvas-container');
  const selBox = document.getElementById('selection-box');
  if (!cc) return;

  cc.addEventListener('wheel', (e) => {
    e.preventDefault();
    const tab = getActiveTab();
    if (!tab) return;
    const factor = e.deltaY > 0 ? -0.1 : 0.1;
    tab.canvas.zoom = Math.max(0.15, Math.min(3, tab.canvas.zoom + factor));
    applyCanvasTransform(tab);
    requestAnimationFrame(() => renderConnections(tab));
  }, { passive: false });

  cc.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;

    const isBackground = e.target === cc || e.target.id === 'canvas-viewport'
      || e.target.id === 'nodes-layer' || e.target.id === 'connections-svg'
      || e.target.id === 'canvas-empty-state';

    if (isBackground) {
      if (e.shiftKey) {
        // Shift + Drag: Iniciar Box Selection
        isBoxSelecting = true;
        boxStartX = e.clientX;
        boxStartY = e.clientY;
        cc.classList.add('box-selecting');
        if (selBox) {
          selBox.style.left = boxStartX + 'px';
          selBox.style.top = boxStartY + 'px';
          selBox.style.width = '0px';
          selBox.style.height = '0px';
          selBox.classList.remove('hidden');
        }
        e.preventDefault();
      } else {
        // Click normal en fondo: Deseleccionar y hacer Pan
        clearSelection();
        updateInspector();

        isPanning = true;
        panStartX = e.clientX;
        panStartY = e.clientY;
        cc.classList.add('panning');
        e.preventDefault();
      }
    }
  });

  document.addEventListener('mousemove', (e) => {
    // Pan
    if (isPanning) {
      const tab = getActiveTab();
      if (!tab) return;
      tab.canvas.panX += (e.clientX - panStartX) / tab.canvas.zoom;
      tab.canvas.panY += (e.clientY - panStartY) / tab.canvas.zoom;
      panStartX = e.clientX;
      panStartY = e.clientY;
      applyCanvasTransform(tab);
      requestAnimationFrame(() => renderConnections(tab));
    }

    // Box Selection
    if (isBoxSelecting && selBox) {
      const x = Math.min(boxStartX, e.clientX);
      const y = Math.min(boxStartY, e.clientY);
      const w = Math.abs(e.clientX - boxStartX);
      const h = Math.abs(e.clientY - boxStartY);

      selBox.style.left = x + 'px';
      selBox.style.top = y + 'px';
      selBox.style.width = w + 'px';
      selBox.style.height = h + 'px';

      // Comprobar intersección con nodos
      const tab = getActiveTab();
      if (tab) {
        const boxRect = { left: x, top: y, right: x + w, bottom: y + h };
        tab.nodes.forEach(node => {
          const el = document.querySelector(`.dialogue-node[data-id="${node.id}"]`);
          if (!el) return;
          const r = el.getBoundingClientRect();
          const intersects = !(r.right < boxRect.left || r.left > boxRect.right || r.bottom < boxRect.top || r.top > boxRect.bottom);
          if (intersects) {
            selectedNodeIds.add(node.id);
            el.classList.add('selected');
          }
        });
      }
    }

    handleNodeDragMove(e);
    handleConnectionMove(e);
  });

  document.addEventListener('mouseup', (e) => {
    if (isPanning) {
      isPanning = false;
      cc.classList.remove('panning');
    }
    if (isBoxSelecting) {
      isBoxSelecting = false;
      cc.classList.remove('box-selecting');
      if (selBox) selBox.classList.add('hidden');
      updateInspector();
    }
    endNodeDrag();
    endConnection(e);
  });
}

// ============================================================
// 15. NODE DRAG (SINGLE & MULTI-SELECTION)
// ============================================================

function startNodeDrag(e, nodeId) {
  const tab = getActiveTab();
  if (!tab) return;

  isDraggingNode = true;
  draggingNodeId = nodeId;

  // Si el nodo clickeado no está seleccionado, seleccionarlo
  if (!selectedNodeIds.has(nodeId)) {
    if (!e.shiftKey) clearSelection();
    selectedNodeIds.add(nodeId);
    document.querySelector(`.dialogue-node[data-id="${nodeId}"]`)?.classList.add('selected');
    updateInspector();
  }

  // Guardar offsets de todos los nodos seleccionados
  dragNodeOffsets.clear();
  selectedNodeIds.forEach(id => {
    const el = document.querySelector(`.dialogue-node[data-id="${id}"]`);
    if (!el) return;
    const rect = el.getBoundingClientRect();
    dragNodeOffsets.set(id, {
      offX: (e.clientX - rect.left) / tab.canvas.zoom,
      offY: (e.clientY - rect.top) / tab.canvas.zoom
    });
  });
}

function handleNodeDragMove(e) {
  if (!isDraggingNode || !draggingNodeId) return;
  const tab = getActiveTab();
  if (!tab) return;
  const vpRect = document.getElementById('canvas-viewport')?.getBoundingClientRect();
  if (!vpRect) return;

  // Mover todos los nodos seleccionados
  selectedNodeIds.forEach(id => {
    const offset = dragNodeOffsets.get(id);
    if (!offset) return;

    const nodeData = tab.nodes.find(n => n.id === id);
    if (!nodeData) return;

    const x = (e.clientX - vpRect.left) / tab.canvas.zoom - offset.offX;
    const y = (e.clientY - vpRect.top) / tab.canvas.zoom - offset.offY;

    nodeData.x = Math.round(x);
    nodeData.y = Math.round(y);

    const nodeEl = document.querySelector(`.dialogue-node[data-id="${id}"]`);
    if (nodeEl) {
      nodeEl.style.left = nodeData.x + 'px';
      nodeEl.style.top = nodeData.y + 'px';
    }
  });

  renderConnections(tab);
  tab.rev = (tab.rev || 0) + 1;
  tab.isDirty = true;
}

function endNodeDrag() {
  if (isDraggingNode) {
    isDraggingNode = false;
    draggingNodeId = null;
    dragNodeOffsets.clear();
    updateTabBar();
  }
}

// ============================================================
// 16. SELECTION MANAGEMENT & CLIPBOARD
// ============================================================

function clearSelection() {
  selectedNodeIds.clear();
  document.querySelectorAll('.dialogue-node.selected').forEach(el => el.classList.remove('selected'));
}

function copySelectedNodes() {
  const tab = getActiveTab();
  if (!tab || selectedNodeIds.size === 0) return;

  clipboardNodes = [];
  selectedNodeIds.forEach(id => {
    const node = tab.nodes.find(n => n.id === id);
    if (node && !node.isSpecial) {
      clipboardNodes.push(JSON.parse(JSON.stringify(node)));
    }
  });

  if (clipboardNodes.length > 0) {
    setStatus(`${clipboardNodes.length} nodo(s) copiado(s)`, 'success');
  }
}

function pasteNodes() {
  const tab = getActiveTab();
  if (!tab || clipboardNodes.length === 0) return;

  clearSelection();

  // Mapeo de títulos antiguos a nuevos para preservar ramas internas
  const titleMapping = new Map();
  const existingTitles = new Set(tab.nodes.map(n => n.title));

  clipboardNodes.forEach(node => {
    let base = node.title.replace(/_copy\d*$/, '');
    let newTitle = base + '_copy';
    let counter = 1;
    while (existingTitles.has(newTitle)) {
      newTitle = `${base}_copy${counter}`;
      counter++;
    }
    existingTitles.add(newTitle);
    titleMapping.set(node.title, newTitle);
  });

  const pastedNodes = [];
  const endIdx = tab.nodes.findIndex(n => n.title === '__END__');

  clipboardNodes.forEach(orig => {
    const copy = JSON.parse(JSON.stringify(orig));
    copy.id = generateId();
    copy.title = titleMapping.get(orig.title) || copy.title;
    copy.x += 60;
    copy.y += 60;

    // Actualizar referencias internas (goto, opciones, condiciones)
    forEachNodeRef(copy, (t) => (titleMapping.has(t) ? titleMapping.get(t) : undefined));
    if (copy.nodeType === 'raw') {
      // Nodo raw: el texto es la fuente de verdad; se remapean sus destinos y su línea "~ titulo"
      for (const [oldT, newT] of titleMapping) copy.rawText = renameInRawText(copy.rawText, oldT, newT);
      copy.rawText = copy.rawText.replace(/^~ [^\r\n]*/, '~ ' + copy.title);
      copy.rawTargets = extractRawTargets(copy.rawText);
    } else {
      // Nodo estructurado nuevo: se serializa con el formato actual
      delete copy.rawText;
      delete copy.fingerprint;
    }

    if (endIdx >= 0) tab.nodes.splice(endIdx, 0, copy);
    else tab.nodes.push(copy);

    pastedNodes.push(copy);
    selectedNodeIds.add(copy.id);
  });

  markDirty();
  renderCanvas(tab);
  updateInspector();
  setStatus(`${pastedNodes.length} nodo(s) pegado(s)`, 'success');
}

function deleteSelectedNodes() {
  const tab = getActiveTab();
  if (!tab || selectedNodeIds.size === 0) return;

  const toDelete = Array.from(selectedNodeIds).filter(id => {
    const n = tab.nodes.find(node => node.id === id);
    return n && !n.isSpecial;
  });

  if (toDelete.length === 0) return;

  const confirmMsg = toDelete.length === 1
    ? `¿Eliminar el nodo seleccionado?`
    : `¿Eliminar los ${toDelete.length} nodos seleccionados?`;

  if (!confirm(confirmMsg)) return;

  const deletedTitles = new Set();
  toDelete.forEach(id => {
    const n = tab.nodes.find(node => node.id === id);
    if (n) deletedTitles.add(n.title);
  });

  tab.nodes = tab.nodes.filter(n => !selectedNodeIds.has(n.id));

  // Limpiar referencias a nodos borrados
  for (const n of tab.nodes) {
    forEachNodeRef(n, (t) => (deletedTitles.has(t) ? '' : undefined));
  }
  // Los nodos raw conservan su texto; se avisa si aún apuntan a nodos borrados
  const rawDangling = tab.nodes.filter(n => n.nodeType === 'raw' && n.rawTargets.some(t => deletedTitles.has(t))).length;

  clearSelection();
  markDirty();
  renderCanvas(tab);
  updateInspector();
  setStatus(rawDangling > 0
    ? `Nodo(s) eliminado(s). ${rawDangling} nodo(s) raw aún apuntan a ellos.`
    : 'Nodo(s) eliminado(s)', 'info');
}

// ============================================================
// 17. RIGHT PANEL (INSPECTOR SINCRONIZADO)
// ============================================================

function updateInspector() {
  const emptyEl = document.getElementById('inspector-empty');
  const formEl = document.getElementById('inspector-form');
  const titleHeader = document.getElementById('inspector-title');
  if (!emptyEl || !formEl) return;

  const tab = getActiveTab();
  if (!tab || selectedNodeIds.size !== 1) {
    emptyEl.classList.remove('hidden');
    formEl.classList.add('hidden');
    if (titleHeader) {
      titleHeader.textContent = selectedNodeIds.size > 1
        ? `${selectedNodeIds.size} nodos seleccionados`
        : 'Inspector de Nodo';
    }
    return;
  }

  const selectedId = selectedNodeIds.values().next().value;
  const node = tab.nodes.find(n => n.id === selectedId);
  if (!node) {
    emptyEl.classList.remove('hidden');
    formEl.classList.add('hidden');
    return;
  }

  emptyEl.classList.add('hidden');
  formEl.classList.remove('hidden');

  if (titleHeader) {
    titleHeader.textContent = node.isSpecial
      ? `Nodo Especial: ${node.title}`
      : `Inspector: ${node.title}`;
  }

  formEl.innerHTML = '';

  // Nodo Especial START / END
  if (node.isSpecial) {
    formEl.innerHTML = `
      <div class="inspector-field">
        <label>Tipo:</label>
        <input type="text" value="${node.title === '__START__' ? 'Punto de Inicio (START)' : 'Fin de Diálogo (END)'}" readonly>
      </div>
      ${node.title === '__START__' ? `
        <div class="inspector-field">
          <label>Conectado a:</label>
          <input type="text" value="${escapeHtml(node.goto || '(sin conectar)')}" readonly>
        </div>
      ` : ''}
    `;
    return;
  }

  // Campo común: Título del nodo
  const titleField = createInspectorField('Nombre del Nudo (Título)', 'text', node.title, () => {});
  const titleInputEl = titleField.querySelector('input');
  // Se renombra al confirmar (change), no en cada tecla: así no hay títulos intermedios repetidos
  titleInputEl.addEventListener('change', () => {
    const sanitized = titleInputEl.value.replace(/\s+/g, '_').trim();
    if (sanitized && sanitized !== node.title && applyNodeRename(tab, node, sanitized)) {
      markDirty();
      renderCanvas(tab);
      updateInspector();
    } else {
      titleInputEl.value = node.title;
    }
  });
  formEl.appendChild(titleField);

  // Inspector según tipo de nodo
  if (node.nodeType === 'raw') {
    // --- INSPECTOR RAW: texto editable tal cual ---
    const note = document.createElement('div');
    note.className = 'inspector-note';
    note.textContent = 'Este nudo usa sintaxis que el canvas no representa (else, set, %, comentarios, tags, etc.). Se guarda exactamente como lo escribas aquí.';
    formEl.appendChild(note);

    const rawField = document.createElement('div');
    rawField.className = 'inspector-field';
    rawField.innerHTML = '<label>Texto del nudo (sin la línea "~ título"):</label>';
    const rawArea = document.createElement('textarea');
    rawArea.className = 'inspector-textarea inspector-raw';
    rawArea.rows = 14;
    rawArea.spellcheck = false;
    rawArea.value = getRawBody(node);
    const targetsInfo = document.createElement('div');
    targetsInfo.className = 'inspector-note';
    const refreshTargets = () => {
      targetsInfo.textContent = 'Destinos detectados: ' + ((node.rawTargets || []).join(', ') || '(ninguno)');
    };
    refreshTargets();
    rawArea.addEventListener('input', () => {
      setRawBody(node, rawArea.value);
      refreshTargets();
      markDirty();
      renderCanvas(tab);
    });
    rawField.appendChild(rawArea);
    formEl.appendChild(rawField);
    formEl.appendChild(targetsInfo);

  } else if (node.nodeType === 'variable') {
    // --- INSPECTOR VARIABLE ---
    const fieldVar = document.createElement('div');
    fieldVar.className = 'inspector-field';
    fieldVar.innerHTML = '<label>Variable (flag.*):</label>';
    const selectVar = document.createElement('select');
    rebuildVariableSelectOptions(selectVar, node.varName, 'set');
    selectVar.addEventListener('change', () => {
      node.varName = selectVar.value;
      markDirty();
      renderCanvas(tab);
    });
    fieldVar.appendChild(selectVar);
    formEl.appendChild(fieldVar);

    const fieldVal = createInspectorField('Nuevo Valor a Asignar:', 'text', node.varValue ?? 'true', (val) => {
      node.varValue = val;
      markDirty();
      renderCanvas(tab);
    });
    formEl.appendChild(fieldVal);

    appendGotoInspectorField(formEl, node, tab);

  } else if (node.nodeType === 'event') {
    // --- INSPECTOR EVENTO ---
    const fieldParam = createInspectorField('Nombre del DialogueEvent / Actor a Gatillar:', 'text', node.eventParam || node.eventName || '', (p) => {
      node.eventParam = p.trim();
      node.eventName = node.eventParam;
      markDirty();
      renderCanvas(tab);
    });
    formEl.appendChild(fieldParam);

    appendGotoInspectorField(formEl, node, tab);

  } else if (node.nodeType === 'condition') {
    // --- INSPECTOR CONDICIÓN ---
    const fieldVar = document.createElement('div');
    fieldVar.className = 'inspector-field';
    fieldVar.innerHTML = '<label>Variable Narrativa a Evaluar:</label>';
    const selectVar = document.createElement('select');
    rebuildVariableSelectOptions(selectVar, node.conditionVar, 'get');
    selectVar.addEventListener('change', () => {
      node.conditionVar = selectVar.value;
      markDirty();
      renderCanvas(tab);
    });
    fieldVar.appendChild(selectVar);
    formEl.appendChild(fieldVar);

    const fieldMode = document.createElement('div');
    fieldMode.className = 'inspector-field';
    fieldMode.innerHTML = '<label>Modo de Evaluación:</label>';
    const selectMode = document.createElement('select');
    selectMode.innerHTML = `
      <option value="compare">Comparación Booleana (True / False)</option>
      <option value="switch">Switch (Múltiples Casos)</option>
    `;
    selectMode.value = node.conditionMode || 'compare';
    selectMode.addEventListener('change', () => {
      node.conditionMode = selectMode.value;
      if (!node.conditionOutputs) node.conditionOutputs = {};
      markDirty();
      renderCanvas(tab);
      updateInspector(); // rebuild dynamic form
    });
    fieldMode.appendChild(selectMode);
    formEl.appendChild(fieldMode);

    if (node.conditionMode === 'compare') {
      const fieldOp = document.createElement('div');
      fieldOp.className = 'inspector-field';
      fieldOp.innerHTML = '<label>Operador:</label>';
      const selectOp = document.createElement('select');
      selectOp.innerHTML = `
        <option value="==">Es igual a (==)</option>
        <option value="!=">Es diferente a (!=)</option>
        <option value=">">Mayor que (&gt;)</option>
        <option value="<">Menor que (&lt;)</option>
        <option value=">=">Mayor o igual (&gt;=)</option>
        <option value="<=">Menor o igual (&lt;=)</option>
      `;
      selectOp.value = node.conditionOperator || '==';
      selectOp.addEventListener('change', () => {
        node.conditionOperator = selectOp.value;
        markDirty();
        renderCanvas(tab);
      });
      fieldOp.appendChild(selectOp);
      formEl.appendChild(fieldOp);

      const fieldVal = createInspectorField('Valor Esperado:', 'text', node.conditionValue || 'true', (val) => {
        node.conditionValue = val;
        markDirty();
        renderCanvas(tab);
      });
      formEl.appendChild(fieldVal);

      // Outputs Dropdowns
      ['true', 'false'].forEach(key => {
        const fieldOut = document.createElement('div');
        fieldOut.className = 'inspector-field';
        fieldOut.innerHTML = `<label>Destino si ${key === 'true' ? 'Cumple (True)' : 'Falla (False)'}:</label>`;
        const selectOut = document.createElement('select');
        buildNodeTargetOptions(selectOut, tab, node.conditionOutputs[key]);
        selectOut.addEventListener('change', () => {
          node.conditionOutputs[key] = selectOut.value;
          markDirty();
          renderCanvas(tab);
        });
        fieldOut.appendChild(selectOut);
        formEl.appendChild(fieldOut);
      });

    } else {
      // Switch Mode
      const fieldCases = document.createElement('div');
      fieldCases.className = 'inspector-field';
      fieldCases.innerHTML = '<label>Casos Posibles:</label>';
      const casesContainer = document.createElement('div');
      casesContainer.style.display = 'flex';
      casesContainer.style.flexDirection = 'column';
      casesContainer.style.gap = '8px';

      (node.switchCases || []).forEach((cval, idx) => {
        const caseRow = document.createElement('div');
        caseRow.style.display = 'flex';
        caseRow.style.gap = '4px';
        
        const inputVal = document.createElement('input');
        inputVal.type = 'text';
        inputVal.value = cval;
        inputVal.style.width = '60px';
        inputVal.placeholder = 'Valor';
        inputVal.addEventListener('input', () => {
          // Si cambia la key, ¿cambiamos el target? Mejor dejamos que el target se pierda o lo renombramos
          const oldVal = node.switchCases[idx];
          const target = node.conditionOutputs[oldVal];
          delete node.conditionOutputs[oldVal];
          node.switchCases[idx] = inputVal.value;
          node.conditionOutputs[inputVal.value] = target;
          markDirty();
          renderCanvas(tab);
        });

        const selectOut = document.createElement('select');
        selectOut.style.flex = '1';
        buildNodeTargetOptions(selectOut, tab, node.conditionOutputs[cval]);
        selectOut.addEventListener('change', () => {
          node.conditionOutputs[node.switchCases[idx]] = selectOut.value;
          markDirty();
          renderCanvas(tab);
        });

        const btnDel = document.createElement('button');
        btnDel.className = 'btn-small';
        btnDel.style.color = 'var(--accent-danger)';
        btnDel.textContent = '✕';
        btnDel.addEventListener('click', () => {
          delete node.conditionOutputs[node.switchCases[idx]];
          node.switchCases.splice(idx, 1);
          markDirty();
          renderCanvas(tab);
          updateInspector();
        });

        caseRow.appendChild(inputVal);
        caseRow.appendChild(selectOut);
        caseRow.appendChild(btnDel);
        casesContainer.appendChild(caseRow);
      });

      const btnAddCase = document.createElement('button');
      btnAddCase.className = 'btn-small';
      btnAddCase.textContent = '+ Añadir Caso';
      btnAddCase.style.marginTop = '4px';
      btnAddCase.addEventListener('click', () => {
        const newCase = (node.switchCases.length).toString();
        node.switchCases.push(newCase);
        node.conditionOutputs[newCase] = '';
        markDirty();
        renderCanvas(tab);
        updateInspector();
      });

      fieldCases.appendChild(casesContainer);
      fieldCases.appendChild(btnAddCase);
      formEl.appendChild(fieldCases);

      // Default output
      const fieldDef = document.createElement('div');
      fieldDef.className = 'inspector-field';
      fieldDef.innerHTML = '<label>Destino por defecto (Default):</label>';
      const selectDef = document.createElement('select');
      buildNodeTargetOptions(selectDef, tab, node.conditionOutputs['default']);
      selectDef.addEventListener('change', () => {
        node.conditionOutputs['default'] = selectDef.value;
        markDirty();
        renderCanvas(tab);
      });
      fieldDef.appendChild(selectDef);
      formEl.appendChild(fieldDef);
    }

  } else {
    // --- INSPECTOR DIÁLOGO ---
    // Orador
    const firstLine = node.lines[0] || { actor: '', text: '' };
    const actorField = createInspectorField('Orador / Participante:', 'text', firstLine.actor, (act) => {
      if (node.lines.length === 0) node.lines.push({ actor: act, text: '' });
      else node.lines[0].actor = act;
      markDirty();
      renderCanvas(tab);
    });
    formEl.appendChild(actorField);

    // Texto de diálogo
    const textField = document.createElement('div');
    textField.className = 'inspector-field';
    textField.innerHTML = '<label>Texto del Diálogo:</label>';
    const textarea = document.createElement('textarea');
    textarea.className = 'inspector-textarea';
    textarea.placeholder = 'Escribe el diálogo aquí…';
    textarea.value = node.lines.map(l => (l.actor ? `${l.actor}: ` : '') + l.text).join('\n');
    textarea.addEventListener('input', () => {
      // Re-parsear texto en líneas
      const raw = textarea.value;
      const lines = raw.split('\n');
      node.lines = lines.map(line => {
        const colonIdx = line.indexOf(': ');
        if (colonIdx > 0 && colonIdx < 30) {
          return { actor: line.slice(0, colonIdx).trim(), text: line.slice(colonIdx + 2).trim() };
        }
        return { actor: '', text: line };
      });
      markDirty();
      renderCanvas(tab);
    });
    textField.appendChild(textarea);
    formEl.appendChild(textField);

    // Opciones de respuesta
    const choicesBox = document.createElement('div');
    choicesBox.className = 'inspector-field';
    choicesBox.innerHTML = '<label>Opciones de Respuesta:</label>';

    const choicesContainer = document.createElement('div');
    node.choices.forEach((ch, cIdx) => {
      const row = document.createElement('div');
      row.className = 'inspector-choice-item';

      const chInput = document.createElement('input');
      chInput.type = 'text';
      chInput.value = ch.label;
      chInput.placeholder = 'Texto opción…';
      chInput.addEventListener('input', () => {
        ch.label = chInput.value;
        markDirty();
        renderCanvas(tab);
      });

      const chTarget = document.createElement('select');
      buildNodeTargetOptions(chTarget, tab, ch.targetTitle);
      chTarget.addEventListener('change', () => {
        ch.targetTitle = chTarget.value;
        markDirty();
        renderCanvas(tab);
      });

      const chDel = document.createElement('button');
      chDel.className = 'btn-small';
      chDel.style.color = 'var(--accent-danger)';
      chDel.textContent = '✕';
      chDel.addEventListener('click', () => {
        node.choices.splice(cIdx, 1);
        if (node.choices.length === 0) node.goto = 'END';
        markDirty();
        renderCanvas(tab);
        updateInspector();
      });

      row.appendChild(chInput);
      row.appendChild(chTarget);
      row.appendChild(chDel);
      choicesContainer.appendChild(row);
    });

    const addChoiceBtn = document.createElement('button');
    addChoiceBtn.className = 'btn-small';
    addChoiceBtn.textContent = '+ Añadir Opción';
    addChoiceBtn.addEventListener('click', () => {
      node.choices.push({ label: 'Nueva Opción', targetTitle: '' });
      node.goto = '';
      markDirty();
      renderCanvas(tab);
      updateInspector();
    });

    choicesBox.appendChild(choicesContainer);
    choicesBox.appendChild(addChoiceBtn);
    formEl.appendChild(choicesBox);

    if (node.choices.length === 0) {
      appendGotoInspectorField(formEl, node, tab);
    }
  }

  // Botón eliminar nodo desde inspector
  const btnDelete = document.createElement('button');
  btnDelete.className = 'btn-danger';
  btnDelete.style.marginTop = '16px';
  btnDelete.textContent = '🗑️ Eliminar Nodo';
  btnDelete.addEventListener('click', () => deleteSelectedNodes());
  formEl.appendChild(btnDelete);
}

function createInspectorField(label, type, val, onInput) {
  const f = document.createElement('div');
  f.className = 'inspector-field';
  f.innerHTML = `<label>${label}</label>`;
  const inp = document.createElement('input');
  inp.type = type;
  inp.value = val ?? '';
  inp.addEventListener('input', () => onInput(inp.value));
  f.appendChild(inp);
  return f;
}

function appendGotoInspectorField(formEl, node, tab) {
  const f = document.createElement('div');
  f.className = 'inspector-field';
  f.innerHTML = '<label>Flujo Directo (Salto a):</label>';
  const sel = document.createElement('select');
  buildNodeTargetOptions(sel, tab, node.goto);
  sel.addEventListener('change', () => {
    node.goto = sel.value;
    markDirty();
    renderCanvas(tab);
  });
  f.appendChild(sel);
  formEl.appendChild(f);
}

function buildNodeTargetOptions(selectEl, tab, currentVal) {
  selectEl.innerHTML = '';

  const noneOpt = document.createElement('option');
  noneOpt.value = '';
  noneOpt.textContent = '-- Sin Conectar --';
  selectEl.appendChild(noneOpt);

  const endOpt = document.createElement('option');
  endOpt.value = 'END';
  endOpt.textContent = '⬛ END (Fin)';
  selectEl.appendChild(endOpt);

  tab.nodes.forEach(n => {
    if (n.title === '__START__' || n.title === '__END__') return;
    const opt = document.createElement('option');
    opt.value = n.title;
    opt.textContent = n.title;
    selectEl.appendChild(opt);
  });

  selectEl.value = (currentVal === '__END__' ? 'END' : currentVal) || '';
}

// ============================================================
// 18. NODE CREATION (GENERIC)
// ============================================================

function handleAddGenericNode(type) {
  const tab = getActiveTab();
  if (!tab) return;

  const cc = document.getElementById('canvas-container');
  let x = 380, y = 240;
  if (cc && tab) {
    const rect = cc.getBoundingClientRect();
    x = Math.round(rect.width / 2 / tab.canvas.zoom - tab.canvas.panX);
    y = Math.round(rect.height / 2 / tab.canvas.zoom - tab.canvas.panY);
  }

  const prefix = type === 'variable' ? 'var_' : (type === 'event' ? 'evento_' : (type === 'condition' ? 'check_' : 'nudo_'));
  const existingTitles = new Set(tab.nodes.map(n => n.title));
  let title = prefix + (tab.nodes.length - 1);
  let counter = 1;
  while (existingTitles.has(title)) {
    title = `${prefix}${tab.nodes.length - 1 + counter}`;
    counter++;
  }

  const node = {
    id: generateId(),
    nodeType: type,
    title,
    x: Math.max(20, x),
    y: Math.max(20, y),
    lines: type === 'dialogue' ? [{ actor: '', text: '' }] : [],
    choices: [],
    mutations: [],
    goto: '',
    varName: AppState.variables[0] ? FLAG_PREFIX + AppState.variables[0].name : '',
    varValue: 'true',
    eventName: 'DialogueEvent',
    eventParam: 'DialogueEvent',
    conditionVar: AppState.variables[0] ? FLAG_PREFIX + AppState.variables[0].name : '',
    conditionMode: 'compare',
    conditionOperator: '==',
    conditionValue: 'true',
    switchCases: ['0', '1', '2'],
    conditionOutputs: {
      'true': '',
      'false': '',
      '0': '',
      '1': '',
      '2': '',
      'default': ''
    }
  };

  const endIdx = tab.nodes.findIndex(n => n.title === '__END__');
  if (endIdx >= 0) tab.nodes.splice(endIdx, 0, node);
  else tab.nodes.push(node);

  clearSelection();
  selectedNodeIds.add(node.id);

  markDirty();
  renderCanvas(tab);
  updateInspector();
}

// ============================================================
// 19. CONTEXT MENU
// ============================================================

function initContextMenu() {
  document.addEventListener('click', (e) => {
    const menu = document.getElementById('context-menu');
    if (menu && !menu.contains(e.target)) hideContextMenu();
  });

  const menu = document.getElementById('context-menu');
  if (menu) {
    menu.addEventListener('click', (e) => {
      const action = e.target.closest('[data-action]')?.dataset.action;
      if (!action) return;
      hideContextMenu();
      if (action === 'duplicate') copySelectedNodes(), pasteNodes();
      else if (action === 'delete') deleteSelectedNodes();
    });
  }
}

function showContextMenu(x, y) {
  const menu = document.getElementById('context-menu');
  if (!menu) return;
  menu.style.left = x + 'px';
  menu.style.top = y + 'px';
  menu.classList.remove('hidden');
}

function hideContextMenu() {
  document.getElementById('context-menu')?.classList.add('hidden');
}

// ============================================================
// 20. NUEVO DIÁLOGO (CON NAVEGADOR DE CARPETAS)
// ============================================================

async function handleNewDialogue() {
  let currentBrowsePath = 'src/overworld/npcs';
  let selectedFolder = currentBrowsePath;

  const bodyHTML = `
    <label style="font-weight: 600; margin-bottom: 4px; display: block;">Nombre del archivo:</label>
    <input id="modal-filename" type="text" placeholder="nuevo_dialogo.dialogue" autocomplete="off" style="margin-bottom: 12px;">
    <label style="font-weight: 600; margin-bottom: 4px; display: block;">Carpeta destino:</label>
    <div class="folder-browser" id="modal-folder-browser" style="margin-bottom: 8px;">
      <div class="folder-path" id="modal-folder-path"></div>
      <div id="modal-folder-list"></div>
    </div>
    <div id="modal-full-path" style="color: var(--text-muted); font-family: var(--font-mono); font-size: 11px; padding: 4px 0;"></div>
    <div id="modal-new-error" style="color: var(--accent-danger); margin-top: 8px; font-size: 12px;"></div>
  `;

  showModal({
    title: 'Nuevo Diálogo',
    bodyHTML,
    onConfirm: async () => {
      const fail = (msg) => {
        const errEl = document.getElementById('modal-new-error');
        if (errEl) errEl.textContent = msg;
        setStatus(msg, 'error');
        return false;
      };
      let filename = document.getElementById('modal-filename')?.value.trim() || '';
      if (filename.endsWith('.dialogue')) filename = filename.slice(0, -'.dialogue'.length);
      if (!filename) return fail('Escribe un nombre de archivo.');
      if (!/^[a-z0-9_\-\/]+$/.test(filename) || filename.includes('..') || filename.includes('//')
        || filename.startsWith('/') || filename.endsWith('/')) {
        return fail('Nombre inválido: usa minúsculas, números, guion bajo, guion y "/" (sin "..").');
      }
      const relPath = selectedFolder + '/' + filename + '.dialogue';

      try {
        const result = await apiPost('/api/dialogues/create', { relPath });
        if (result.ok === false && result.error === 'already_exists') {
          return fail('El archivo ya existe');
        }
        await loadDialogueFiles();
        await openFile(relPath);
        setStatus('Creado: ' + relPath, 'success');
      } catch (err) {
        return fail('Error: ' + err.message);
      }
    },
  });

  async function browseFolder(dir) {
    try {
      const data = await apiGet('/api/browse?dir=' + encodeURIComponent(dir));
      currentBrowsePath = data.currentPath;
      selectedFolder = data.currentPath;

      const pathEl = document.getElementById('modal-folder-path');
      if (pathEl) {
        const canGoUp = data.currentPath !== 'src' && data.currentPath.includes('/');
        pathEl.innerHTML = `${canGoUp ? '<span class="folder-up" id="folder-go-up" title="Subir carpeta">⬆ ..</span>' : ''}
          <span>📁 ${escapeHtml(data.currentPath)}/</span>`;
        if (canGoUp) {
          document.getElementById('folder-go-up')?.addEventListener('click', () => {
            const parent = data.currentPath.split('/').slice(0, -1).join('/') || 'src';
            browseFolder(parent);
          });
        }
      }

      const listEl = document.getElementById('modal-folder-list');
      if (listEl) {
        listEl.innerHTML = '';
        for (const dirName of data.directories) {
          const item = document.createElement('div');
          item.className = 'folder-item';
          item.textContent = '📂 ' + dirName;
          item.addEventListener('click', () => browseFolder(data.currentPath + '/' + dirName));
          listEl.appendChild(item);
        }
        if (data.directories.length === 0) {
          listEl.innerHTML = '<div style="padding: 8px; color: var(--text-muted); font-size: 11px;">(Sin subcarpetas)</div>';
        }
      }

      updateFullPath();
    } catch (err) {
      console.error('Browse error:', err);
    }
  }

  function updateFullPath() {
    const filename = document.getElementById('modal-filename')?.value.trim() || 'nombre.dialogue';
    const pathEl = document.getElementById('modal-full-path');
    if (pathEl) pathEl.textContent = `Ruta final: ${selectedFolder}/${filename}`;
  }

  setTimeout(() => {
    browseFolder(currentBrowsePath);
    document.getElementById('modal-filename')?.addEventListener('input', updateFullPath);
  }, 50);
}

// ============================================================
// 21. MODAL
// ============================================================

function showModal({ title, bodyHTML, onConfirm }) {
  const overlay = document.getElementById('modal-overlay');
  if (!overlay) return;
  document.getElementById('modal-title').textContent = title;
  document.getElementById('modal-body').innerHTML = bodyHTML;
  overlay.classList.remove('hidden');

  const confirmBtn = document.getElementById('modal-confirm');
  const cancelBtn = document.getElementById('modal-cancel');
  if (confirmBtn) {
    confirmBtn.onclick = async () => {
      if (confirmBtn.disabled) return; // evita doble envío mientras se espera onConfirm
      confirmBtn.disabled = true;
      try {
        // Si onConfirm devuelve false el modal sigue abierto (error de validación)
        if ((await onConfirm()) !== false) closeModal();
      } catch (err) {
        console.error('Error en el modal:', err);
        setStatus('Error: ' + (err && err.message ? err.message : err), 'error');
      } finally {
        confirmBtn.disabled = false;
      }
    };
  }
  if (cancelBtn) cancelBtn.onclick = closeModal;

  setTimeout(() => {
    overlay.querySelector('input')?.focus();
  }, 50);
}

function handleQuickRewrite() {
  const tab = getActiveTab();
  if (!tab) {
    alert('Abre un archivo de diálogo primero.');
    return;
  }

  const dialogueNodes = Object.values(tab.nodes).filter(n => n.type === 'dialogue' || !n.type);
  if (dialogueNodes.length === 0) {
    alert('No hay nodos de diálogo en este archivo.');
    return;
  }

  const modalBox = document.getElementById('modal-box');
  if (modalBox) modalBox.classList.add('modal-wide');

  let html = `<p style="color:var(--text-secondary); margin-bottom:12px;">Edita rápidamente los textos y hablantes de todos los nodos de diálogo a la vez:</p>`;
  
  dialogueNodes.forEach(node => {
    html += `
      <div class="quick-rewrite-item" data-node-id="${node.id}">
        <div class="quick-rewrite-header">
          <span>Nodo: ${escapeHtml(node.title || node.id)}</span>
          <div>
            <label style="font-size:11px; margin-right:4px;">Personaje:</label>
            <input type="text" class="quick-rewrite-character" value="${escapeHtml(node.character || '')}" placeholder="Narrador/Personaje">
          </div>
        </div>
        <textarea class="quick-rewrite-textarea" rows="2" placeholder="Texto del diálogo...">${escapeHtml(node.text || '')}</textarea>
      </div>
    `;
  });

  showModal({
    title: `📝 Guión Rápido — ${tab.filename}`,
    bodyHTML: html,
    onConfirm: () => {
      const items = document.querySelectorAll('.quick-rewrite-item');
      items.forEach(el => {
        const nodeId = el.dataset.nodeId;
        const charInput = el.querySelector('.quick-rewrite-character');
        const textInput = el.querySelector('.quick-rewrite-textarea');
        if (tab.nodes[nodeId]) {
          tab.nodes[nodeId].character = charInput.value.trim();
          tab.nodes[nodeId].text = textInput.value;
        }
      });
      tab.isDirty = true;
      updateStatusBadge();
      renderCanvas();
      updateInspector();
    }
  });
}

function closeModal() {
  const modalBox = document.getElementById('modal-box');
  if (modalBox) modalBox.classList.remove('modal-wide');
  document.getElementById('modal-overlay')?.classList.add('hidden');
}

// ============================================================
// 22. LAYOUT
// ============================================================

function getLayoutId(relPath) {
  return relPath.replace(/\//g, '_').replace(/\.dialogue$/, '');
}

async function loadLayout(relPath) {
  return await apiGet('/api/layouts/' + getLayoutId(relPath));
}

async function saveLayout(tabData) {
  const nodes = {};
  for (const node of tabData.nodes) {
    nodes[node.title] = { x: node.x, y: node.y };
  }
  await apiPost('/api/layouts/' + getLayoutId(tabData.relPath), { nodes });
}

// ============================================================
// 23. UTILITIES
// ============================================================

function setStatus(msg, type) {
  const badge = document.getElementById('status-badge');
  if (!badge) return;
  badge.textContent = msg;
  badge.className = 'badge' + (type ? ' badge-' + type : '');
  if (type && type !== 'error') {
    setTimeout(() => {
      badge.textContent = 'Listo';
      badge.className = 'badge';
    }, 3000);
  }
}

function handleFitView() {
  const tab = getActiveTab();
  if (!tab || tab.nodes.length === 0) return;
  const cc = document.getElementById('canvas-container');
  if (!cc) return;

  const rect = cc.getBoundingClientRect();
  const MARGIN = 80;
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

  for (const node of tab.nodes) {
    const el = document.querySelector(`.dialogue-node[data-id="${node.id}"]`);
    const w = el ? el.offsetWidth : 260;
    const h = el ? el.offsetHeight : 120;
    minX = Math.min(minX, node.x);
    minY = Math.min(minY, node.y);
    maxX = Math.max(maxX, node.x + w);
    maxY = Math.max(maxY, node.y + h);
  }

  const cW = rect.width - MARGIN * 2;
  const cH = rect.height - MARGIN * 2;
  const zoom = Math.max(0.15, Math.min(2, Math.min(cW / (maxX - minX), cH / (maxY - minY))));

  tab.canvas.zoom = zoom;
  tab.canvas.panX = rect.width / 2 / zoom - (minX + maxX) / 2;
  tab.canvas.panY = rect.height / 2 / zoom - (minY + maxY) / 2;

  applyCanvasTransform(tab);
  requestAnimationFrame(() => renderConnections(tab));
}
