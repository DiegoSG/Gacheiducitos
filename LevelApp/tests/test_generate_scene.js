// Prueba del generador de escenas de LevelApp. Uso: node LevelApp/tests/test_generate_scene.js [carpeta_salida]
// Extrae genScene/genPromptsDoc de public/index.html y los ejecuta contra sample_levels_spec.json.
const fs = require("fs"), path = require("path"), vm = require("vm"), assert = require("assert");
const html = fs.readFileSync(path.join(__dirname, "..", "public", "index.html"), "utf8");
const code = html.slice(html.indexOf("/*GEN-START*/"), html.indexOf("/*GEN-END*/"));
const ctx = {}; vm.createContext(ctx); vm.runInContext(code + "\nthis.genScene=genScene;this.genPromptsDoc=genPromptsDoc;this.genDialogueProxies=genDialogueProxies;", ctx);
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
assert(Object.values(out).some(t => t.includes('path="res://src/overworld/npcs/npc_barnaby.tscn"')) && !Object.values(out).some(t => t.includes("dummy_npc")), "NPCs usan npc_barnaby.tscn");
assert(ctx.genPromptsDoc(spec).includes("PROMPT: agregar un arbol grande"));

// Capas y orden en Z (design/Capas_y_Orden_Z.md)
assert(a.includes('[node name="Environment" type="Node2D" parent="."]\ny_sort_enabled = true'), "Environment participa del y-sort");
assert(a.includes('[node name="GroundLayer" type="TileMapLayer" parent="Environment"]\nz_index = -2') && a.includes('[node name="DetailLayer" type="TileMapLayer" parent="Environment"]\nz_index = -1'), "suelo bajo el jugador");
assert(/\[node name="GroundLayer"[^\n]*\]\nz_index = -2\ntile_set = [^\n]+\ncollision_enabled = false/.test(a) && /\[node name="DetailLayer"[^\n]*\]\nz_index = -1\ntile_set = [^\n]+\ncollision_enabled = false/.test(a), "suelo y detalle sin colision");
assert(/\[node name="OverheadLayer" type="TileMapLayer" parent="Environment"\]\nz_index = 10\ntile_set = [^\n]+\ncollision_enabled = false/.test(a), "OverheadLayer sobre el jugador y sin colision");
assert(a.includes("dialogue_resource = null") && ctx.genDialogueProxies(spec).length === 0, "NPC sin diálogo no hereda el de la escena base");

// Diálogos en NPC y triggers
const dlg = f => ({ file: "src/" + f, res_path: "res://src/" + f, title: "start" });
const s2 = JSON.parse(JSON.stringify(spec)), L1 = s2.levels[0];
L1.music_id = "music_level_01";
L1.npcs[0].dialogue = dlg("overworld/npcs/barnaby.dialogue");
const pos = { cell: { x: 1, y: 1 }, px: { x: 90, y: 90 } };
L1.triggers = [
  { id: "G01", ...pos, kind: "area", mode: "interact", one_shot: true, dialogue: { ...dlg("overworld/dialogues/level_01_g01.dialogue"), title: "intro" } },
  { id: "G02", ...pos, kind: "plate", one_shot: false, dialogue: dlg("overworld/dialogues/level_01_g01.dialogue") },
  { id: "G03", ...pos, kind: "switch", one_shot: true, dialogue: dlg("overworld/dialogues/level_01_g03.dialogue") },
  { id: "G04", ...pos, kind: "event", event_id: "abrir_puerta", one_shot: true, dialogue: dlg("overworld/dialogues/level_01_g04.dialogue") },
  { id: "G05", ...pos, kind: "area", mode: "on_enter", one_shot: true, dialogue: null }
];
const t = ctx.genScene(s2, L1);
assert(t.includes('dialogue_resource = ExtResource("') && t.includes('dialogue_start_title = "start"'), "NPC con diálogo asignado");
assert((t.match(/path="res:\/\/src\/overworld\/dialogues\/level_01_g01\.dialogue"/g) || []).length === 1, "un ext_resource por archivo de diálogo");
assert((t.match(/dialogue_action\.gd/g) || []).length === 1 && (t.match(/^\[sub_resource type="Resource" id="dlgaction/gm) || []).length === 4, "un DialogueAction por trigger con diálogo");
assert(t.includes('dialogue_title = "intro"'));
const node = n => t.split("\n\n").find(b => b.startsWith('[node name="' + n + '"')) || "";
const scenePath = b => { const id = (b.match(/instance=ExtResource\("([^"]+)"\)/) || [])[1]; return (t.match(new RegExp('path="([^"]+)" id="' + id + '"')) || [])[1]; };
const [g1, g2, g3, g4, g5] = ["G01", "G02", "G03", "G04", "G05"].map(node);
assert(scenePath(g1).endsWith("interactables/game_trigger_area.tscn") && g1.includes("trigger_mode = 3\none_shot = true\ncollision_layer = 16") && g1.includes("actions_if_true = Array["), "área interactuable");
assert(scenePath(g2).endsWith("pressure_plate.tscn") && g2.includes("one_shot = false") && g2.includes("on_enter_actions = Array["), "placa");
assert(scenePath(g3).endsWith("switch_interactable.tscn") && g3.includes("is_toggleable = false") && g3.includes("trigger_actions = Array["), "palanca");
assert(scenePath(g4).endsWith("dialogue_event.tscn") && g4.includes('event_id = "abrir_puerta"') && g4.includes("\nactions = Array["), "evento remoto");
assert(g5.includes("trigger_mode = 0") && !g5.includes("Array[") && !g5.includes("collision_layer"), "trigger sin diálogo no lleva acciones ni capa de interacción");
assert(t.includes('music_id = &"music_level_01"') && !a.includes("music_id"), "música del nivel; sin música = SceneMusic sin music_id");
const px = ctx.genDialogueProxies(s2);
assert.strictEqual(px.map(p => p.file).join(), ["src/overworld/npcs/barnaby.dialogue", "src/overworld/dialogues/level_01_g01.dialogue", "src/overworld/dialogues/level_01_g03.dialogue", "src/overworld/dialogues/level_01_g04.dialogue"].join());
assert(px[0].content.startsWith("~ start\n\nBarnaby: ") && px[1].content.startsWith("~ intro\n") && px[1].content.endsWith("=> END\n"));

// Cuadros de colisión: StaticBody2D + CollisionShape2D rectangular bajo Collisions
assert(!a.includes('name="Collisions"'), "sin cuadros no hay nodo Collisions");
const s3 = JSON.parse(JSON.stringify(spec));
s3.levels[0].collisions = [{ id: "Col_01", cell: { x: 2, y: 1 }, size: { w: 3, h: 2 }, rect_px: { x: 120, y: 60, w: 180, h: 120 } }];
const c3 = ctx.genScene(s3, s3.levels[0]);
assert(c3.includes('[sub_resource type="RectangleShape2D" id="colshape1"]\nsize = Vector2(180, 120)'), "forma rectangular del tamaño del cuadro");
assert(c3.includes('[node name="Col_01" type="StaticBody2D" parent="Collisions"]\nposition = Vector2(210, 120)\ncollision_mask = 0'), "cuerpo estático centrado en el cuadro");
assert(c3.includes('[node name="CollisionShape2D" type="CollisionShape2D" parent="Collisions/Col_01"]\nshape = SubResource("colshape1")'));
assert(c3.indexOf("[sub_resource") < c3.indexOf("[node "), "sub_resources antes de los nodos");
const dir = process.argv[2]; if (dir) { fs.mkdirSync(dir, { recursive: true }); for (const k in out) fs.writeFileSync(path.join(dir, k), out[k]); }
console.log("OK");
