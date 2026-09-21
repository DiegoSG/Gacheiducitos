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

// Lista canónica de eventos del juego soportados por el motor
const GAME_EVENTS_LIST = [
  { id: 'abrir_puerta', label: '🚪 Abrir Puerta' },
  { id: 'cerrar_puerta', label: '🔒 Cerrar Puerta' },
  { id: 'dar_oro', label: '💰 Dar Oro' },
  { id: 'dar_item', label: '🎒 Dar Ítem al Inventario' },
  { id: 'remover_item', label: '🗑️ Quitar Ítem' },
  { id: 'iniciar_alerta', label: '🚨 Iniciar Alerta' },
  { id: 'terminar_alerta', label: '🕊️ Terminar Alerta' },
  { id: 'iniciar_minijuego', label: '🎮 Iniciar Minijuego' },
  { id: 'cambiar_nivel', label: '🗺️ Cambiar de Nivel' },
  { id: 'reproducir_sonido', label: '🔊 Reproducir Sonido' },
  { id: 'reproducir_musica', label: '🎵 Reproducir Música' },
  { id: 'custom', label: '⚙️ Otro (Personalizado)...' }
];

// ============================================================
// 1. STATE
// ============================================================

const AppState = {
  tabs: [],
  activeTabIndex: -1,
  dialogueFiles: [],
  variables: [], // [{ name, type, defaultValue }]
};

// Clipboard para copiar y pegar
let clipboardNodes = [];

// Selección múltiple
const selectedNodeIds = new Set();
let lastSelectedNodeId = null;

let contextMenuTargetId = null;

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
  document.getElementById('modal-cancel')?.addEventListener('click', closeModal);
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

async function loadProjectConfig() {
  try {
    const config = await apiGet('/api/config');
    AppState.variables = config.variables || config.flags || [];
    renderVariableList();
  } catch (err) {
    console.warn('No se pudo cargar config previa, inicializando vacía:', err);
    AppState.variables = [];
    renderVariableList();
  }
}

async function saveProjectConfig() {
  try {
    await apiPost('/api/config', {
      variables: AppState.variables,
      flags: AppState.variables
    });
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
    nameSpan.title = `${v.name} (${v.type || 'bool'}) = ${v.defaultValue}`;

    const badge = document.createElement('span');
    badge.className = 'var-item-badge type-' + (v.type || 'bool');
    badge.textContent = v.type || 'bool';

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
    li.appendChild(delBtn);
    list.appendChild(li);
  });
}

function handleAddVariable() {
  const bodyHTML = `
    <label style="font-weight: 600; margin-bottom: 4px; display: block;">Nombre de la Variable:</label>
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
  `;

  showModal({
    title: 'Nueva Variable Narrativa',
    bodyHTML,
    onConfirm: () => {
      const name = document.getElementById('modal-var-name')?.value.trim();
      const type = document.getElementById('modal-var-type')?.value || 'bool';
      let defVal = document.getElementById('modal-var-default')?.value.trim();

      if (!name) return;
      if (defVal === '') {
        defVal = type === 'bool' ? 'false' : (type === 'int' ? '0' : (type === 'float' ? '0.0' : '""'));
      }

      if (AppState.variables.some(v => v.name === name)) {
        alert('Ya existe una variable con ese nombre.');
        return;
      }

      AppState.variables.push({ name, type, defaultValue: defVal });
      saveProjectConfig();
      renderVariableList();
      refreshAllVariableNodes();
      setStatus(`Variable "${name}" creada`, 'success');
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

    const nodes = parseDialogue(content, layoutData);

    const tabData = {
      relPath,
      title: relPath.split('/').pop(),
      nodes,
      isDirty: false,
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

  try {
    setStatus('Guardando…');
    const content = serializeDialogue(tab);
    await apiPost('/api/dialogues/save', { path: tab.relPath, content });
    await saveLayout(tab);
    tab.isDirty = false;
    updateTabBar();
    setStatus('Guardado: ' + tab.title, 'success');
  } catch (err) {
    setStatus('Error guardando: ' + err.message, 'error');
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
    div.innerHTML = `📄 ${tab.title} <span class="tab-close" data-idx="${i}">×</span>`;
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
  if (tab && !tab.isDirty) {
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
// 8. PARSER (.dialogue → Model)
// ============================================================

function generateId() {
  return typeof crypto !== 'undefined' && crypto.randomUUID
    ? crypto.randomUUID()
    : 'id_' + Math.random().toString(36).slice(2) + '_' + Date.now().toString(36);
}

function parseDialogue(content, layoutData) {
  const nodesLayout = layoutData?.nodes || {};
  const lines = content.split('\n');
  const nodes = [];
  let currentNode = null;
  let defaultX = 280;
  let defaultY = 160;
  let pendingCondition = '';

  for (const rawLine of lines) {
    const line = rawLine.trim();

    if (line.startsWith('~ ')) {
      if (currentNode) nodes.push(finalizeParsedNode(currentNode));
      pendingCondition = '';
      const title = line.slice(2).trim();
      const pos = nodesLayout[title] || {};
      currentNode = {
        id: generateId(),
        nodeType: 'dialogue', // 'dialogue' | 'variable' | 'event'
        title,
        x: pos.x ?? defaultX,
        y: pos.y ?? defaultY,
        lines: [],
        choices: [],
        mutations: [],
        goto: 'END',
        varName: '',
        varValue: 'true',
        eventName: 'abrir_puerta',
        eventParam: ''
      };
      defaultX += 340;
      if (defaultX > 2000) {
        defaultX = 280;
        defaultY += 320;
      }
    } else if (line.startsWith('if ') && currentNode) {
      pendingCondition = line.replace(/^if\s+/, '').replace(/:$/, '').trim();
    } else if (line.startsWith('elif ') && currentNode) {
      pendingCondition = line.replace(/^elif\s+/, '').replace(/:$/, '').trim();
    } else if (line.startsWith('- ') && currentNode) {
      const match = line.match(/^-\s+(.+?)\s+=>\s+(.+)$/);
      if (match) {
        currentNode.choices.push({ label: match[1].trim(), targetTitle: match[2].trim() });
        currentNode.goto = '';
      }
      pendingCondition = '';
    } else if (line.startsWith('=> ') && currentNode) {
      if (pendingCondition) {
        if (!currentNode.conditionalGotos) currentNode.conditionalGotos = [];
        currentNode.conditionalGotos.push({ condition: pendingCondition, goto: line.slice(3).trim() });
        pendingCondition = '';
      } else {
        currentNode.goto = line.slice(3).trim();
      }
    } else if (line.startsWith('do ') && currentNode) {
      const mut = parseMutation(line);
      currentNode.mutations.push(mut);
      pendingCondition = '';
    } else if (line && !line.startsWith('#') && !line.startsWith('//') && currentNode) {
      const colonIdx = line.indexOf(': ');
      if (colonIdx > 0 && colonIdx < 30) {
        currentNode.lines.push({
          actor: line.slice(0, colonIdx).trim(),
          text: line.slice(colonIdx + 2).trim(),
          condition: pendingCondition,
        });
      } else {
        currentNode.lines.push({
          actor: '',
          text: line,
          condition: pendingCondition,
        });
      }
      pendingCondition = '';
    }
  }

  if (currentNode) nodes.push(finalizeParsedNode(currentNode));

  // Asegurar nodos especiales START y END
  ensureSpecialNodes(nodes, nodesLayout);

  return nodes;
}

function finalizeParsedNode(node) {
  if (node.lines.length === 0 && node.mutations.length === 0 && node.conditionalGotos?.length > 0) {
    node.nodeType = 'condition';
    node.conditionOutputs = { default: node.goto || '' };
    node.switchCases = [];
    
    const firstCond = node.conditionalGotos[0].condition;
    const match = firstCond.match(/NarrativeManager\.get_flag\(['"](.+?)['"]\)\s*(==|!=|>|<|>=|<=)\s*(.+)/);
    if (match) {
      node.conditionVar = match[1];
      node.conditionOperator = match[2];
      const val = match[3];
      
      if (node.conditionalGotos.length === 1 && (val === 'true' || val === 'false')) {
        node.conditionMode = 'compare';
        node.conditionValue = 'true';
        if (val === 'true' && node.conditionOperator === '==') {
          node.conditionOutputs['true'] = node.conditionalGotos[0].goto;
          node.conditionOutputs['false'] = node.goto || '';
        } else {
          node.conditionOutputs['false'] = node.conditionalGotos[0].goto;
          node.conditionOutputs['true'] = node.goto || '';
        }
      } else {
        node.conditionMode = 'switch';
        for (const cg of node.conditionalGotos) {
          const m = cg.condition.match(/NarrativeManager\.get_flag\(['"](.+?)['"]\)\s*==\s*(.+)/);
          if (m) {
            node.switchCases.push(m[2]);
            node.conditionOutputs[m[2]] = cg.goto;
          }
        }
      }
    }
    return node;
  }

  // Deducir si el nodo es en realidad un nodo de evento o de variable si no tiene diálogo
  if (node.lines.length === 0 && node.mutations.length === 1) {
    const mut = node.mutations[0];
    if (mut.type === 'variable') {
      node.nodeType = 'variable';
      node.varName = mut.name;
      node.varValue = mut.value;
    } else if (mut.type === 'event') {
      node.nodeType = 'event';
      node.eventParam = mut.value || mut.name;
      node.eventName = node.eventParam;
    }
  }
  return node;
}

function parseMutation(line) {
  // Detectar flag/variable: do NarrativeManager.set_flag("var", val)
  const flagMatch = line.match(/do\s+NarrativeManager\.set_flag\(['"](.+?)['"],\s*(.+?)\)/);
  if (flagMatch) {
    return { type: 'variable', name: flagMatch[1], value: flagMatch[2] };
  }

  // Detectar evento: do GameManager.trigger_event("actor") o ("evento", "param")
  const evtMatch = line.match(/do\s+GameManager\.trigger_event\(['"](.+?)['"](?:\s*,\s*['"]?(.*?)['"]?)?\)/);
  if (evtMatch) {
    const actorOrParam = evtMatch[2] ? evtMatch[2] : evtMatch[1];
    return { type: 'event', name: actorOrParam, value: actorOrParam };
  }

  // Triggers legacy
  const runTrig = line.match(/do\s+GameManager\.run_trigger\(['"](.+?)['"]\)/);
  if (runTrig) {
    return { type: 'event', name: runTrig[1], value: '' };
  }

  return { type: 'event', name: line.slice(3).trim(), value: '' };
}

function ensureSpecialNodes(nodes, nodesLayout) {
  // Detectar si hay un alias puro de start: un nodo 'start' sin diálogo que solo salta a otro nodo
  const startAliasIdx = nodes.findIndex(n => n.title?.toLowerCase() === 'start' && n.lines.length === 0 && n.choices.length === 0 && n.mutations.length === 0 && (!n.conditionalGotos || n.conditionalGotos.length === 0) && n.goto);
  let aliasTarget = '';
  if (startAliasIdx !== -1) {
    aliasTarget = nodes[startAliasIdx].goto;
    nodes.splice(startAliasIdx, 1);
  }

  // Detectar si hay un alias puro de end: un nodo 'end' sin diálogo que solo salta a END
  const endAliasIdx = nodes.findIndex(n => n.title?.toLowerCase() === 'end' && n.lines.length === 0 && n.choices.length === 0 && n.mutations.length === 0 && (!n.conditionalGotos || n.conditionalGotos.length === 0) && (n.goto === 'END' || !n.goto));
  if (endAliasIdx !== -1) {
    nodes.splice(endAliasIdx, 1);
  }

  const hasStart = nodes.some(n => n.title === '__START__');
  const hasEnd = nodes.some(n => n.title === '__END__');

  if (!hasStart) {
    const pos = nodesLayout['__START__'] || {};
    const firstReal = nodes.find(n => n.title !== '__END__');
    nodes.unshift({
      id: generateId(),
      nodeType: 'special',
      title: '__START__',
      x: pos.x ?? 40,
      y: pos.y ?? 160,
      lines: [],
      choices: [],
      mutations: [],
      goto: aliasTarget || (firstReal ? firstReal.title : ''),
      isSpecial: true,
    });
  } else if (aliasTarget) {
    const startNode = nodes.find(n => n.title === '__START__');
    if (startNode && (!startNode.goto || startNode.goto === '__END__')) {
      startNode.goto = aliasTarget;
    }
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

// ============================================================
// 9. SERIALIZER (Model → .dialogue)
// ============================================================

function serializeDialogue(tabData) {
  let out = '';

  const startNode = tabData.nodes.find(n => n.title === '__START__');
  const firstTitle = startNode ? startNode.goto : '';

  const realNodes = tabData.nodes.filter(n => n.title !== '__START__' && n.title !== '__END__');
  if (firstTitle) {
    const firstIdx = realNodes.findIndex(n => n.title === firstTitle);
    if (firstIdx > 0) {
      const [firstItem] = realNodes.splice(firstIdx, 1);
      realNodes.unshift(firstItem);
    }
  }

  const cleanTarget = (tgt) => {
    if (!tgt || tgt === '__END__' || tgt === 'END') return 'END';
    return tgt.trim().replace(/\s+/g, '_');
  };

  // Código correspondiente para el nodo START presente por defecto
  const hasExplicitStartNode = realNodes.some(n => (n.title || '').trim().toLowerCase() === 'start');
  if (!hasExplicitStartNode) {
    const startTarget = cleanTarget(firstTitle || 'END');
    out += `~ start\n\n=> ${startTarget}\n\n`;
  }

  for (const node of realNodes) {
    const safeTitle = (node.title || 'nudo').trim().replace(/\s+/g, '_');
    out += `~ ${safeTitle}\n\n`;

    if (node.nodeType === 'variable') {
      const vName = node.varName || 'variable';
      const vVal = node.varValue !== undefined && node.varValue !== '' ? node.varValue : 'true';
      out += `do NarrativeManager.set_flag("${vName}", ${vVal})\n`;
      out += `=> ${cleanTarget(node.goto)}\n\n`;
      continue;
    }

    if (node.nodeType === 'event') {
      const actorTarget = (node.eventParam || node.eventName || 'DialogueEvent').trim();
      out += `do GameManager.trigger_event("${actorTarget}")\n`;
      out += `=> ${cleanTarget(node.goto)}\n\n`;
      continue;
    }

    if (node.nodeType === 'condition') {
      const vName = node.conditionVar || 'var';
      if (node.conditionMode === 'compare') {
        const op = node.conditionOperator || '==';
        const val = node.conditionValue || 'true';
        out += `if NarrativeManager.get_flag("${vName}") ${op} ${val}\n`;
        out += `\t=> ${cleanTarget(node.conditionOutputs?.['true'])}\n`;
        out += `=> ${cleanTarget(node.conditionOutputs?.['false'])}\n\n`;
      } else {
        const cases = node.switchCases || [];
        for (let i = 0; i < cases.length; i++) {
          const cval = cases[i];
          if (i === 0) {
            out += `if NarrativeManager.get_flag("${vName}") == ${cval}\n`;
          } else {
            out += `elif NarrativeManager.get_flag("${vName}") == ${cval}\n`;
          }
          out += `\t=> ${cleanTarget(node.conditionOutputs?.[cval])}\n`;
        }
        out += `=> ${cleanTarget(node.conditionOutputs?.['default'])}\n\n`;
      }
      continue;
    }

    // Nodo estándar de diálogo
    for (const line of node.lines) {
      if (line.condition) out += `if ${line.condition}:\n`;
      if (line.actor) out += `${line.actor}: `;
      out += `${line.text}\n`;
    }

    if (node.choices.length > 0) {
      for (const ch of node.choices) {
        out += `- ${ch.label} => ${cleanTarget(ch.targetTitle)}\n`;
      }
    } else if (node.goto) {
      out += `=> ${cleanTarget(node.goto)}\n`;
    }
    out += '\n';
  }

  // Código correspondiente para el nodo END presente por defecto
  const hasExplicitEndNode = realNodes.some(n => (n.title || '').trim().toLowerCase() === 'end');
  const hasEndNode = tabData.nodes.some(n => n.title === '__END__');
  if (hasEndNode && !hasExplicitEndNode) {
    out += `~ end\n\n=> END\n\n`;
  }

  return out.trimEnd() + '\n';
}

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
      const oldTitle = node.title;
      const sanitized = titleInput.value.replace(/\s+/g, '_');
      titleInput.value = sanitized;
      node.title = sanitized.trim() || oldTitle;
      updateNodeReferences(tabData, oldTitle, node.title);
      markDirty();
      updateInspector();
      requestAnimationFrame(() => renderConnections(tabData));
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

  if (node.nodeType === 'condition') {
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
    rebuildVariableSelectOptions(selectVar, node.conditionVar);
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
    rebuildVariableSelectOptions(selectVar, node.varName);
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

function rebuildVariableSelectOptions(selectEl, selectedVal) {
  selectEl.innerHTML = '';
  const defaultOpt = document.createElement('option');
  defaultOpt.value = '';
  defaultOpt.textContent = '-- Seleccionar Variable --';
  selectEl.appendChild(defaultOpt);

  AppState.variables.forEach(v => {
    const opt = document.createElement('option');
    opt.value = v.name;
    opt.textContent = `${v.name} (${v.type || 'bool'})`;
    selectEl.appendChild(opt);
  });

  if (selectedVal && !AppState.variables.some(v => v.name === selectedVal)) {
    const customOpt = document.createElement('option');
    customOpt.value = selectedVal;
    customOpt.textContent = `${selectedVal} (externa)`;
    selectEl.appendChild(customOpt);
  }
  selectEl.value = selectedVal || '';
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
        lastSelectedNodeId = node.id;
      }
    } else {
      // Si no tiene shift y el nodo no estaba seleccionado, se convierte en la única selección
      if (!selectedNodeIds.has(node.id)) {
        clearSelection();
        selectedNodeIds.add(node.id);
        div.classList.add('selected');
      }
      lastSelectedNodeId = node.id;
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
    contextMenuTargetId = node.id;
    showContextMenu(e.clientX, e.clientY);
  });
}

function updateNodeReferences(tab, oldTitle, newTitle) {
  for (const n of tab.nodes) {
    for (const ch of n.choices) {
      if (ch.targetTitle === oldTitle) ch.targetTitle = newTitle;
    }
    if (n.goto === oldTitle) n.goto = newTitle;
  }
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

function drawConnection(svg, fromEl, toEl) {
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
  path.setAttribute('class', 'connection');
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
          if (typeof connectFromChoiceIdx === 'string' && connectFromChoiceIdx.startsWith('cond_')) {
            const key = connectFromChoiceIdx.replace('cond_', '');
            sourceNode.conditionOutputs[key] = targetNode.title;
          } else if (connectFromChoiceIdx >= 0 && sourceNode.choices[connectFromChoiceIdx]) {
            sourceNode.choices[connectFromChoiceIdx].targetTitle = targetNode.title;
          } else {
            sourceNode.goto = targetNode.title;
          }
          markDirty();
          renderCanvas(tab);
          updateInspector();
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
            lastSelectedNodeId = node.id;
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
    lastSelectedNodeId = nodeId;
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
  lastSelectedNodeId = null;
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

    // Actualizar referencias internas
    copy.choices.forEach(ch => {
      if (titleMapping.has(ch.targetTitle)) {
        ch.targetTitle = titleMapping.get(ch.targetTitle);
      }
    });
    if (titleMapping.has(copy.goto)) {
      copy.goto = titleMapping.get(copy.goto);
    }

    if (endIdx >= 0) tab.nodes.splice(endIdx, 0, copy);
    else tab.nodes.push(copy);

    pastedNodes.push(copy);
    selectedNodeIds.add(copy.id);
    lastSelectedNodeId = copy.id;
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
    for (const ch of n.choices) {
      if (deletedTitles.has(ch.targetTitle)) ch.targetTitle = '';
    }
    if (deletedTitles.has(n.goto)) n.goto = '';
  }

  clearSelection();
  markDirty();
  renderCanvas(tab);
  updateInspector();
  setStatus('Nodo(s) eliminado(s)', 'info');
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
          <input type="text" value="${node.goto || '(sin conectar)'}" readonly>
        </div>
      ` : ''}
    `;
    return;
  }

  // Campo común: Título del nodo
  const titleField = createInspectorField('Nombre del Nudo (Título)', 'text', node.title, (newVal) => {
    const oldTitle = node.title;
    const sanitized = newVal.replace(/\s+/g, '_');
    node.title = sanitized.trim() || oldTitle;
    updateNodeReferences(tab, oldTitle, node.title);
    markDirty();
    renderCanvas(tab);
  });
  formEl.appendChild(titleField);

  // Inspector según tipo de nodo
  if (node.nodeType === 'variable') {
    // --- INSPECTOR VARIABLE ---
    const fieldVar = document.createElement('div');
    fieldVar.className = 'inspector-field';
    fieldVar.innerHTML = '<label>Variable Narrativa:</label>';
    const selectVar = document.createElement('select');
    rebuildVariableSelectOptions(selectVar, node.varName);
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
    rebuildVariableSelectOptions(selectVar, node.conditionVar);
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
    varName: AppState.variables[0]?.name || '',
    varValue: 'true',
    eventName: 'DialogueEvent',
    eventParam: 'DialogueEvent',
    conditionVar: AppState.variables[0]?.name || '',
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
  lastSelectedNodeId = node.id;

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
  `;

  showModal({
    title: 'Nuevo Diálogo',
    bodyHTML,
    onConfirm: async () => {
      let filename = document.getElementById('modal-filename')?.value.trim() || '';
      if (!filename) return;
      if (!filename.endsWith('.dialogue')) filename += '.dialogue';
      const relPath = selectedFolder + '/' + filename;

      try {
        const result = await apiPost('/api/dialogues/create', { relPath });
        if (result.ok === false && result.error === 'already_exists') {
          setStatus('El archivo ya existe', 'error');
          return;
        }
        await loadDialogueFiles();
        await openFile(relPath);
        setStatus('Creado: ' + relPath, 'success');
      } catch (err) {
        setStatus('Error: ' + err.message, 'error');
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
          <span>📁 ${data.currentPath}/</span>`;
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
  if (confirmBtn) confirmBtn.onclick = () => { onConfirm(); closeModal(); };
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
