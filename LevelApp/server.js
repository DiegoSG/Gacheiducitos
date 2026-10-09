// LevelApp: servidor local sin dependencias. Las rutas del proyecto son fijas (relativas a este archivo).
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3132;
const PUBLIC_DIR = path.resolve(__dirname, 'public');
const PROJECT_FILE = path.resolve(__dirname, 'data/levelapp_proyecto.json');
const RPG_ROOT = path.resolve(__dirname, '../rpg-g');
const SRC_DIR = path.resolve(RPG_ROOT, 'src');
const LEVELS_DIR = path.resolve(SRC_DIR, 'overworld/levels');
const PROMPTS_FILE = path.resolve(__dirname, '../design/Level_Prompts.md');
const SCENE_FILE_RE = /^[a-z0-9_]+\.tscn$/;
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json' };

function send(res, code, body, type = 'application/json') {
  res.writeHead(code, { 'Content-Type': type });
  res.end(typeof body === 'string' || Buffer.isBuffer(body) ? body : JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', c => { data += c; if (data.length > 20e6) { reject(new Error('Cuerpo demasiado grande')); req.destroy(); } });
    req.on('end', () => resolve(data));
    req.on('error', reject);
  });
}

function listLevels() {
  return fs.existsSync(LEVELS_DIR) ? fs.readdirSync(LEVELS_DIR).filter(f => f.endsWith('.tscn')) : [];
}

/** .dialogue de rpg-g/src, como rutas relativas a rpg-g (src/...). */
function listDialogues(dir = SRC_DIR, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const d of fs.readdirSync(dir, { withFileTypes: true })) {
    const abs = path.join(dir, d.name);
    if (d.isDirectory()) listDialogues(abs, out);
    else if (d.name.endsWith('.dialogue')) out.push(path.relative(RPG_ROOT, abs).split(path.sep).join('/'));
  }
  return out.sort();
}

/** Ruta absoluta de un .dialogue relativo a rpg-g, o null si sale de rpg-g/src. */
function dialoguePath(rel) {
  if (typeof rel !== 'string' || !rel.endsWith('.dialogue') || path.isAbsolute(rel)) return null;
  const abs = path.resolve(RPG_ROOT, rel);
  return abs.startsWith(SRC_DIR + path.sep) ? abs : null;
}

/** Crea los .tscn nuevos y los .dialogue proxy que falten. Nunca sobrescribe: si algún nivel existe, no escribe nada. */
function generate(body) {
  const scenes = Array.isArray(body.scenes) ? body.scenes : [];
  const dialogues = Array.isArray(body.dialogues) ? body.dialogues : [];
  if (!scenes.length) return { code: 400, out: { error: 'Sin escenas' } };
  const seen = new Set();
  for (const sc of scenes) {
    if (!SCENE_FILE_RE.test(sc.file || '') || typeof sc.content !== 'string') return { code: 400, out: { error: 'Nombre de archivo inválido: ' + sc.file } };
    if (seen.has(sc.file)) return { code: 400, out: { error: 'Archivo repetido: ' + sc.file } };
    seen.add(sc.file);
  }
  for (const d of dialogues)
    if (!dialoguePath(d.file) || typeof d.content !== 'string') return { code: 400, out: { error: 'Ruta de diálogo inválida: ' + d.file } };
  const conflicts = scenes.map(s => s.file).filter(f => fs.existsSync(path.join(LEVELS_DIR, f)));
  if (conflicts.length) return { code: 409, out: { error: 'Ya existen estos niveles; no se sobrescribe nada.', conflicts } };
  const dialoguesCreated = [], dialoguesExisting = [];
  for (const d of dialogues) {
    const abs = dialoguePath(d.file);
    if (fs.existsSync(abs)) { dialoguesExisting.push(d.file); continue; }
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, d.content);
    dialoguesCreated.push(d.file);
  }
  fs.mkdirSync(LEVELS_DIR, { recursive: true });
  for (const sc of scenes) fs.writeFileSync(path.join(LEVELS_DIR, sc.file), sc.content);
  if (typeof body.prompts === 'string') fs.writeFileSync(PROMPTS_FILE, body.prompts);
  return { code: 200, out: { written: scenes.map(s => s.file), levelsDir: 'rpg-g/src/overworld/levels', promptsFile: 'design/Level_Prompts.md', dialoguesCreated, dialoguesExisting } };
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    if (url.pathname === '/api/levels' && req.method === 'GET') return send(res, 200, { files: listLevels() });
    if (url.pathname === '/api/dialogues' && req.method === 'GET') return send(res, 200, { files: listDialogues() });
    if (url.pathname === '/api/project' && req.method === 'GET')
      return send(res, 200, fs.existsSync(PROJECT_FILE) ? fs.readFileSync(PROJECT_FILE) : '{}');
    if (url.pathname === '/api/project' && req.method === 'POST') {
      const text = await readBody(req); JSON.parse(text);
      fs.mkdirSync(path.dirname(PROJECT_FILE), { recursive: true });
      fs.writeFileSync(PROJECT_FILE, text);
      return send(res, 200, { ok: true });
    }
    if (url.pathname === '/api/generate' && req.method === 'POST') {
      const r = generate(JSON.parse(await readBody(req)));
      return send(res, r.code, r.out);
    }
    if (req.method !== 'GET') return send(res, 405, { error: 'Método no permitido' });
    const rel = url.pathname === '/' ? 'index.html' : url.pathname.slice(1);
    const file = path.resolve(PUBLIC_DIR, rel);
    if (!file.startsWith(PUBLIC_DIR + path.sep) || !fs.existsSync(file)) return send(res, 404, { error: 'No encontrado' });
    return send(res, 200, fs.readFileSync(file), MIME[path.extname(file)] || 'application/octet-stream');
  } catch (e) {
    return send(res, 500, { error: e.message });
  }
});

server.listen(PORT, () => console.log(`LevelApp server running at http://localhost:${PORT}`));
