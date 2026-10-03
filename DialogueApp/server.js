// @ts-check
const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3131;

// Path constants
const BASE_SRC = path.resolve(__dirname, '../rpg-g/src');
const RPG_ROOT = path.resolve(__dirname, '../rpg-g');
const CONFIG_FILE = path.resolve(__dirname, 'data/project_config.json');
const LAYOUTS_DIR = path.resolve(__dirname, 'data/layouts');
const PUBLIC_DIR = path.resolve(__dirname, 'public');
// Solo lectura: catalogo de items / estados (nunca se escribe fuera de rpg-g/src)
const DATA_DIR = path.resolve(__dirname, '../rpg-g/data');
const VAR_NAME_RE = /^[a-z][a-z0-9_]*$/;

/**
 * Normaliza la config: una sola lista `variables` (elimina `flags`),
 * descarta variables con nombre invalido o duplicado.
 * @param {any} raw
 * @returns {any}
 */
function normalizeConfig(raw) {
  const cfg = (raw && typeof raw === 'object') ? { ...raw } : {};
  const source = Array.isArray(cfg.variables) ? cfg.variables : (Array.isArray(cfg.flags) ? cfg.flags : []);
  delete cfg.flags;
  const seen = new Set();
  cfg.variables = [];
  for (const v of source) {
    const name = v && typeof v.name === 'string' ? v.name : '';
    if (!VAR_NAME_RE.test(name)) {
      console.warn(`[config] Variable descartada (nombre invalido, debe cumplir ${VAR_NAME_RE}): ${JSON.stringify(v && v.name)}`);
      continue;
    }
    if (seen.has(name)) {
      console.warn(`[config] Variable duplicada descartada: "${name}"`);
      continue;
    }
    seen.add(name);
    cfg.variables.push(v);
  }
  return cfg;
}

/**
 * Lee (solo lectura) los .tres de un subdirectorio de rpg-g/data y extrae id/name.
 * @param {string} subdir
 * @returns {Promise<{id: string, name: string}[]>}
 */
async function readResourceIds(subdir) {
  const dir = path.resolve(DATA_DIR, subdir);
  if (!dir.startsWith(DATA_DIR + path.sep)) return [];
  const files = await scanDir(dir, '.tres');
  /** @type {{id: string, name: string}[]} */
  const out = [];
  for (const f of files.sort()) {
    try {
      const content = await fs.promises.readFile(f, 'utf-8');
      const idm = content.match(/^id\s*=\s*"([^"]+)"/m);
      if (!idm) continue;
      const nm = content.match(/^name\s*=\s*"([^"]*)"/m);
      out.push({ id: idm[1], name: nm ? nm[1] : '' });
    } catch (err) {
      console.error(`[readResourceIds] ${f}:`, err);
    }
  }
  return out;
}

/**
 * Validates that a target path is safely contained within BASE_SRC.
 * @param {string} targetPath - Absolute path to validate.
 * @returns {boolean} True if safely inside BASE_SRC, false otherwise.
 */
function isSafePath(targetPath) {
  const normalizedTarget = path.normalize(targetPath);
  const normalizedBase = path.normalize(BASE_SRC);
  return normalizedTarget === normalizedBase || normalizedTarget.startsWith(normalizedBase + path.sep);
}

/**
 * Recursively scans directory for files with a given extension (excluding .import files).
 * @param {string} dir - Directory to search.
 * @param {string} ext - Extension to match (e.g. '.dialogue' or '.tscn').
 * @returns {Promise<string[]>} List of absolute file paths.
 */
async function scanDir(dir, ext) {
  /** @type {string[]} */
  const results = [];
  try {
    const entries = await fs.promises.readdir(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        const subFiles = await scanDir(fullPath, ext);
        results.push(...subFiles);
      } else if (entry.isFile()) {
        if (fullPath.endsWith(ext) && !fullPath.endsWith(`${ext}.import`)) {
          results.push(fullPath);
        }
      }
    }
  } catch (err) {
    console.error(`[scanDir] Failed to scan directory "${dir}":`, err);
  }
  return results;
}

/**
 * @typedef {Object} TriggerInfo
 * @property {string} name - Trigger name.
 * @property {string} source - Source type ('tscn').
 * @property {string} file - Relative path from rpg-g root.
 */

/**
 * Parses a .tscn file content and extracts trigger entries.
 * @param {string} content - Raw content of the .tscn file.
 * @param {string} relPath - Relative path from rpg-g root.
 * @returns {TriggerInfo[]} Extracted triggers.
 */
function extractTriggersFromTscn(content, relPath) {
  if (!content.includes('game_trigger.gd')) {
    return [];
  }

  /** @type {TriggerInfo[]} */
  const triggers = [];
  const lines = content.split(/\r?\n/);

  // 1. Collect all ExtResource IDs referencing game_trigger.gd
  /** @type {Set<string>} */
  const triggerExtIds = new Set();
  for (const line of lines) {
    if (line.includes('game_trigger.gd')) {
      const idMatch = line.match(/\bid="?([^"\s\]]+)"?/);
      if (idMatch) {
        triggerExtIds.add(idMatch[1]);
      }
    }
  }

  // 2. Identify the root node name (first line matching [node name=...)
  let rootNodeName = null;
  for (const line of lines) {
    const rootMatch = line.match(/\[node\s+[^\]]*\bname\s*=\s*"([^"]+)"/);
    if (rootMatch) {
      rootNodeName = rootMatch[1];
      break;
    }
  }

  if (rootNodeName) {
    triggers.push({
      name: rootNodeName,
      source: 'tscn',
      file: relPath
    });
  }

  // 3. Identify individual nodes attached to game_trigger.gd
  let currentSectionType = null;
  let currentNodeName = null;
  let currentHasTrigger = false;

  for (const line of lines) {
    if (line.startsWith('[')) {
      if (currentSectionType === 'node' && currentNodeName && currentHasTrigger) {
        triggers.push({
          name: currentNodeName,
          source: 'tscn',
          file: relPath
        });
      }

      const nodeMatch = line.match(/^\[node\s+[^\]]*\bname\s*=\s*"([^"]+)"/);
      if (nodeMatch) {
        currentSectionType = 'node';
        currentNodeName = nodeMatch[1];
        currentHasTrigger = line.includes('game_trigger.gd');
      } else {
        currentSectionType = 'other';
        currentNodeName = null;
        currentHasTrigger = false;
      }
    } else if (currentSectionType === 'node') {
      if (line.includes('game_trigger.gd')) {
        currentHasTrigger = true;
      } else {
        for (const extId of triggerExtIds) {
          if (line.includes(`ExtResource("${extId}")`) || line.includes(`ExtResource(${extId})`)) {
            currentHasTrigger = true;
            break;
          }
        }
      }
    }
  }

  if (currentSectionType === 'node' && currentNodeName && currentHasTrigger) {
    triggers.push({
      name: currentNodeName,
      source: 'tscn',
      file: relPath
    });
  }

  return triggers;
}

// 1. Static files middleware
app.use(express.static(PUBLIC_DIR));

// 2. CORS middleware
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

// 3. JSON body parser
app.use(express.json());

app.get('/favicon.ico', (req, res) => res.status(204).end());

// 4. API Endpoints

/**
 * GET /api/dialogues
 * Scans BASE_SRC for *.dialogue files.
 */
app.get('/api/dialogues', async (req, res) => {
  try {
    const files = await scanDir(BASE_SRC, '.dialogue');
    const result = files.map((absPath) => ({
      name: path.basename(absPath),
      path: absPath,
      relPath: path.relative(RPG_ROOT, absPath).replace(/\\/g, '/')
    }));
    res.json(result);
  } catch (err) {
    console.error('[GET /api/dialogues] Error:', err);
    res.status(500).json({ error: 'Failed to scan dialogues' });
  }
});

/**
 * GET /api/dialogues/read?path=<relPath>
 * Reads dialogue file content.
 */
app.get('/api/dialogues/read', async (req, res) => {
  try {
    const relPath = req.query.path;
    if (!relPath || typeof relPath !== 'string') {
      return res.status(400).json({ error: 'Missing or invalid "path" query parameter' });
    }

    const targetPath = path.resolve(RPG_ROOT, relPath);
    if (!isSafePath(targetPath)) {
      return res.status(403).json({ error: 'Forbidden: Path must be inside rpg-g/src' });
    }

    try {
      const content = await fs.promises.readFile(targetPath, 'utf-8');
      res.json({ content });
    } catch (readErr) {
      if (/** @type {NodeJS.ErrnoException} */ (readErr).code === 'ENOENT') {
        res.json({ content: '' });
      } else {
        throw readErr;
      }
    }
  } catch (err) {
    console.error('[GET /api/dialogues/read] Error:', err);
    res.status(500).json({ error: 'Failed to read dialogue file' });
  }
});

/**
 * POST /api/dialogues/save
 * Saves content to dialogue file.
 */
app.post('/api/dialogues/save', async (req, res) => {
  try {
    const { path: relPath, content } = req.body || {};
    if (!relPath || typeof relPath !== 'string') {
      return res.status(400).json({ error: 'Missing or invalid "path" in body' });
    }

    const targetPath = path.resolve(RPG_ROOT, relPath);
    if (!isSafePath(targetPath)) {
      return res.status(403).json({ error: 'Forbidden: Path must be inside rpg-g/src' });
    }

    await fs.promises.mkdir(path.dirname(targetPath), { recursive: true });
    await fs.promises.writeFile(targetPath, content ?? '', 'utf-8');
    res.json({ ok: true });
  } catch (err) {
    console.error('[POST /api/dialogues/save] Error:', err);
    res.status(500).json({ error: 'Failed to save dialogue file' });
  }
});

/**
 * POST /api/dialogues/create
 * Creates a new dialogue file with starter content if it doesn't already exist.
 */
app.post('/api/dialogues/create', async (req, res) => {
  try {
    const { relPath } = req.body || {};
    if (!relPath || typeof relPath !== 'string') {
      return res.status(400).json({ error: 'Missing or invalid "relPath" in body' });
    }

    const targetPath = path.resolve(RPG_ROOT, relPath);
    if (!isSafePath(targetPath)) {
      return res.status(403).json({ error: 'Forbidden: Path must be inside rpg-g/src' });
    }

    try {
      await fs.promises.access(targetPath);
      return res.json({ ok: false, error: 'already_exists' });
    } catch {
      // File does not exist, can be created
    }

    await fs.promises.mkdir(path.dirname(targetPath), { recursive: true });
    await fs.promises.writeFile(targetPath, '~ start\n\n=> END\n', 'utf-8');
    res.json({ ok: true, path: relPath });
  } catch (err) {
    console.error('[POST /api/dialogues/create] Error:', err);
    res.status(500).json({ error: 'Failed to create dialogue file' });
  }
});

/**
 * GET /api/config
 * Reads project configuration file or creates default if not found.
 */
app.get('/api/config', async (req, res) => {
  try {
    try {
      const data = await fs.promises.readFile(CONFIG_FILE, 'utf-8');
      return res.json(normalizeConfig(JSON.parse(data)));
    } catch {
      const initialConfig = { actors: [], variables: [], triggers: [] };
      await fs.promises.mkdir(path.dirname(CONFIG_FILE), { recursive: true });
      await fs.promises.writeFile(CONFIG_FILE, JSON.stringify(initialConfig, null, 2), 'utf-8');
      return res.json(initialConfig);
    }
  } catch (err) {
    console.error('[GET /api/config] Error:', err);
    res.status(500).json({ error: 'Failed to get config' });
  }
});

/**
 * POST /api/config
 * Saves project configuration.
 */
app.post('/api/config', async (req, res) => {
  try {
    if (!req.body || typeof req.body !== 'object') {
      return res.status(400).json({ error: 'Invalid config body' });
    }
    const configData = normalizeConfig(req.body);

    await fs.promises.mkdir(path.dirname(CONFIG_FILE), { recursive: true });
    await fs.promises.writeFile(CONFIG_FILE, JSON.stringify(configData, null, 2), 'utf-8');

    // Auto-generate narrative_defaults.gd
    const defaultsPath = path.resolve(BASE_SRC, 'core/data/narrative_defaults.gd');
    let gdContent = '# AUTO-GENERATED by DialogueApp — No editar manualmente\n';
    gdContent += '# Valores iniciales de variables narrativas del proyecto\n';
    gdContent += 'class_name NarrativeDefaults\n\n';
    gdContent += 'const DEFAULTS: Dictionary = {\n';
    
    const variables = configData.variables;
    for (const v of variables) {
      let val = v.defaultValue;
      if (v.type === 'bool') {
        val = val === 'true' ? 'true' : 'false';
      } else if (v.type === 'int') {
        val = parseInt(val) || 0;
      } else if (v.type === 'float') {
        val = parseFloat(val) || 0.0;
        if (Number.isInteger(val)) {
          val = val.toFixed(1);
        } else {
          val = val.toString();
        }
      } else if (v.type === 'string') {
        val = `"${val}"`;
      }
      gdContent += `\t"${v.name}": ${val},\n`;
    }
    
    gdContent += '}\n';
    
    await fs.promises.mkdir(path.dirname(defaultsPath), { recursive: true });
    await fs.promises.writeFile(defaultsPath, gdContent, 'utf-8');

    res.json({ ok: true });
  } catch (err) {
    console.error('[POST /api/config] Error:', err);
    res.status(500).json({ error: 'Failed to save config' });
  }
});

/**
 * GET /api/system-variables
 * Variables de solo lectura del juego: player.*, item.<id>, status.<id>.
 */
app.get('/api/system-variables', async (req, res) => {
  try {
    /** @type {{path: string, type: string, readonly: boolean, description: string}[]} */
    const list = [
      { path: 'player.health', type: 'int', readonly: true, description: 'Vida actual del jugador' },
      { path: 'player.max_health', type: 'int', readonly: true, description: 'Vida maxima del jugador' },
      { path: 'player.gold', type: 'int', readonly: true, description: 'Oro del jugador' },
      { path: 'player.speed', type: 'float', readonly: true, description: 'Velocidad del jugador' },
      { path: 'player.strength', type: 'int', readonly: true, description: 'Fuerza del jugador' },
      { path: 'player.resistance', type: 'int', readonly: true, description: 'Resistencia del jugador' },
    ];
    for (const it of await readResourceIds('items')) {
      list.push({ path: `item.${it.id}`, type: 'int', readonly: true, description: `Cantidad en inventario${it.name ? ': ' + it.name : ''}` });
    }
    for (const st of await readResourceIds('status_effects')) {
      list.push({ path: `status.${st.id}`, type: 'bool', readonly: true, description: `Estado activo${st.name ? ': ' + st.name : ''}` });
    }
    res.json(list);
  } catch (err) {
    console.error('[GET /api/system-variables] Error:', err);
    res.status(500).json({ error: 'Failed to read system variables' });
  }
});

/**
 * GET /api/triggers
 * Scans BASE_SRC for .tscn files using game_trigger.gd.
 */
app.get('/api/triggers', async (req, res) => {
  try {
    const tscnFiles = await scanDir(BASE_SRC, '.tscn');
    /** @type {TriggerInfo[]} */
    const allTriggers = [];

    for (const filePath of tscnFiles) {
      try {
        const content = await fs.promises.readFile(filePath, 'utf-8');
        const relPath = path.relative(RPG_ROOT, filePath).replace(/\\/g, '/');
        const fileTriggers = extractTriggersFromTscn(content, relPath);
        allTriggers.push(...fileTriggers);
      } catch (fileErr) {
        console.error(`[GET /api/triggers] Error reading ${filePath}:`, fileErr);
      }
    }

    // Deduplicate by trigger name
    /** @type {Set<string>} */
    const seen = new Set();
    /** @type {TriggerInfo[]} */
    const uniqueTriggers = [];

    for (const item of allTriggers) {
      if (!seen.has(item.name)) {
        seen.add(item.name);
        uniqueTriggers.push(item);
      }
    }

    res.json(uniqueTriggers);
  } catch (err) {
    console.error('[GET /api/triggers] Error:', err);
    res.status(500).json({ error: 'Failed to scan triggers' });
  }
});

/**
 * GET /api/layouts/:layoutId
 * Gets layout data for a specific dialogue.
 */
app.get('/api/layouts/:layoutId', async (req, res) => {
  try {
    const layoutId = path.basename(req.params.layoutId);
    const layoutPath = path.join(LAYOUTS_DIR, `${layoutId}.json`);

    try {
      const data = await fs.promises.readFile(layoutPath, 'utf-8');
      res.json(JSON.parse(data));
    } catch (readErr) {
      if (/** @type {NodeJS.ErrnoException} */ (readErr).code === 'ENOENT') {
        res.json({ nodes: {} });
      } else {
        throw readErr;
      }
    }
  } catch (err) {
    console.error('[GET /api/layouts/:layoutId] Error:', err);
    res.status(500).json({ error: 'Failed to read layout' });
  }
});

/**
 * POST /api/layouts/:layoutId
 * Saves layout data for a specific dialogue.
 */
app.post('/api/layouts/:layoutId', async (req, res) => {
  try {
    const layoutId = path.basename(req.params.layoutId);
    const layoutPath = path.join(LAYOUTS_DIR, `${layoutId}.json`);

    await fs.promises.mkdir(LAYOUTS_DIR, { recursive: true });
    await fs.promises.writeFile(layoutPath, JSON.stringify(req.body || {}, null, 2), 'utf-8');
    res.json({ ok: true });
  } catch (err) {
    console.error('[POST /api/layouts/:layoutId] Error:', err);
    res.status(500).json({ error: 'Failed to save layout' });
  }
});

/**
 * GET /api/browse?dir=<relPath>
 * Lists directories inside rpg-g/src/ for folder browsing.
 * Returns { directories: string[], currentPath: string }
 */
app.get('/api/browse', async (req, res) => {
  try {
    const relDir = req.query.dir || 'src';
    const targetPath = path.resolve(RPG_ROOT, relDir);
    if (!isSafePath(targetPath)) {
      return res.status(403).json({ error: 'Forbidden: Path must be inside rpg-g/src' });
    }

    const entries = await fs.promises.readdir(targetPath, { withFileTypes: true });
    const directories = entries
      .filter(e => e.isDirectory())
      .map(e => e.name)
      .sort();

    res.json({
      currentPath: path.relative(RPG_ROOT, targetPath).replace(/\\/g, '/'),
      directories,
    });
  } catch (err) {
    console.error('[GET /api/browse] Error:', err);
    res.status(500).json({ error: 'Failed to browse directory' });
  }
});

// 5. Start server
const server = app.listen(PORT, () => {
  console.log(`DialogueApp server running at http://localhost:${PORT}`);
});

module.exports = { normalizeConfig, app, server, scanDir, extractTriggersFromTscn, isSafePath };
