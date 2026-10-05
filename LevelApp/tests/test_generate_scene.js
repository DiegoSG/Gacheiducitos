// Prueba del generador de escenas de LevelApp. Uso: node LevelApp/tests/test_generate_scene.js [carpeta_salida]
// Extrae genScene/genPromptsDoc de public/index.html y los ejecuta contra sample_levels_spec.json.
const fs = require("fs"), path = require("path"), vm = require("vm"), assert = require("assert");
const html = fs.readFileSync(path.join(__dirname, "..", "public", "index.html"), "utf8");
const code = html.slice(html.indexOf("/*GEN-START*/"), html.indexOf("/*GEN-END*/"));
const ctx = {}; vm.createContext(ctx); vm.runInContext(code + "\nthis.genScene=genScene;this.genPromptsDoc=genPromptsDoc;", ctx);
const spec = JSON.parse(fs.readFileSync(path.join(__dirname, "sample_levels_spec.json"), "utf8"));
const out = Object.fromEntries(spec.levels.map(L => [L.scene_file, ctx.genScene(spec, L)]));
const [a, b] = [out["level_01.tscn"], out["level_02.tscn"]];
assert(a.includes('arrival_id = "start"'));
assert(a.includes('target_level_path = "res://src/overworld/levels/level_02.tscn"') && a.includes('exit_id = "at_P02"'));
assert(a.includes('[node name="SpawnPoint" parent="Portals/P01"]\nposition = Vector2(0, 60)'), "llegada del portal en el mismo nivel");
assert(!a.includes('name="at_P01"'), "no duplica la llegada propia del portal");
assert(a.includes('name="at_P03" parent="SpawnPoints"'), "llegada de P03 vive en Level_01");
assert(b.includes('arrival_id = "at_P03_local"'), "P03 conserva un id propio distinto");
assert(b.includes("win_spawn_id = \"at_M01_win\"") && b.includes("minigame_type = 2"));
assert(a.includes('persistence_id = "level_01_E01"') && a.includes('name="SceneMusic"'));
assert(ctx.genPromptsDoc(spec).includes("PROMPT: agregar un arbol grande"));
const dir = process.argv[2]; if (dir) { fs.mkdirSync(dir, { recursive: true }); for (const k in out) fs.writeFileSync(path.join(dir, k), out[k]); }
console.log("OK");
