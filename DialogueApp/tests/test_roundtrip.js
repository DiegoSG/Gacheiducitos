'use strict';
// Tests de round-trip del parser/serializer de .dialogue.
// Uso: node tests/test_roundtrip.js   (sale con código 1 si algo falla)

const fs = require('fs');
const path = require('path');
const F = require('../public/dialogue-format.js');

let failures = 0;
let passed = 0;

function check(name, cond, extra) {
  if (cond) {
    passed++;
  } else {
    failures++;
    console.error('FALLO: ' + name + (extra ? '\n' + extra : ''));
  }
}

function load(content) {
  const { header, nodes, startAlias } = F.parseDialogueFile(content, {});
  return { header, nodes, startAlias };
}

function roundtrip(content) {
  return F.serializeDialogue(load(content));
}

function findNode(tab, title) {
  return tab.nodes.find(n => n.title === title);
}

function walk(dir, out) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith('.dialogue')) out.push(p);
  }
  return out;
}

// ------------------------------------------------------------
// (a) Archivos reales del proyecto
// ------------------------------------------------------------
const srcDir = path.resolve(__dirname, '../../rpg-g/src');
const files = fs.existsSync(srcDir) ? walk(srcDir, []) : [];
check('hay .dialogue de ejemplo en rpg-g/src', files.length > 0);
for (const f of files) {
  const original = fs.readFileSync(f, 'utf-8');
  check('round-trip exacto: ' + path.relative(srcDir, f), roundtrip(original) === original);
}

// ------------------------------------------------------------
// (b) Sintaxis rara: todo idéntico byte a byte
// ------------------------------------------------------------
const WEIRD = [
  'import "res://dialogue/common.dialogue" as common',
  'using GameVariables',
  '# comentario de cabecera',
  '',
  '~ start',
  '',
  '// comentario',
  'Narrador: Hola [#tag] mundo',
  'set GameVariables.x = 1',
  '% Una opcion',
  '% Otra opcion',
  '- Opcion A => a',
  '\tAlgo indentado bajo la opcion',
  '- Opcion B => b',
  '',
  '~ a',
  '',
  'if GameVariables.get_var("flag.x") == true',
  '\tNarrador: condicionada',
  'else',
  '\tNarrador: si no',
  '=> b',
  '',
  '~ b',
  'do GameManager.trigger_event("puerta", "abrir")',
  '=> c',
  '',
  '~ c',
  'Narrador: texto con do',
  'do GameVariables.set_var("flag.x", true)',
  '=> END',
  '',
  '~ d',
  '- sin destino',
  '- con [if cond] inline => end',
  '',
  '~ end',
  '',
  '=> END',
  '',
  '~ ultimo',
  'Hola',
  '=> END', // sin salto de línea final
].join('\n');

check('fixture raro: round-trip exacto', roundtrip(WEIRD) === WEIRD);
check('fixture raro con CRLF: round-trip exacto', roundtrip(WEIRD.replace(/\n/g, '\r\n')) === WEIRD.replace(/\n/g, '\r\n'));

{
  const tab = load(WEIRD);
  check('header literal', tab.header === 'import "res://dialogue/common.dialogue" as common\nusing GameVariables\n# comentario de cabecera\n\n');
  for (const t of ['start', 'a', 'b', 'c', 'd']) {
    check(`nodo "${t}" es raw`, findNode(tab, t).nodeType === 'raw' && findNode(tab, t).modelable === false);
  }
  check('rawTargets de start', JSON.stringify(findNode(tab, 'start').rawTargets) === '["a","b"]');
  check('rawTargets de a', JSON.stringify(findNode(tab, 'a').rawTargets) === '["b"]');
  const endNode = findNode(tab, 'end');
  check('~ end real es nodo normal', endNode && endNode.nodeType === 'dialogue' && endNode.goto === 'END');
  check('~ end real no se borra al serializar', F.serializeDialogue(tab).includes('~ end\n'));
  check('START apunta a start', findNode(tab, '__START__').goto === 'start');
}

// Clasificación de sintaxis
{
  const cases = [
    ['Actor: texto\n=> END\n', 'dialogue'],
    ['Solo texto\n- Si => x\n- No => y\n', 'dialogue'],
    ['if GameVariables.get_var("flag.a") == true\n\tA: hola\nB: chao\n=> END\n', 'dialogue'],
    ['if GameVariables.get_var("flag.a") == true\n\t=> x\n=> y\n', 'condition'],
    ['if GameVariables.get_var("flag.a") == 1\n\t=> x\nelif GameVariables.get_var("flag.a") == 2\n\t=> y\n=> z\n', 'condition'],
    ['if GameVariables.get_var("flag.a") == 1\n\t=> x\nelif GameVariables.get_var("flag.b") == 2\n\t=> y\n=> z\n', 'raw'],
    ['if GameVariables.get_var("flag.a") >= 1\n\t=> x\nelif GameVariables.get_var("flag.a") == 2\n\t=> y\n=> z\n', 'raw'],
    ['if GameVariables.get_var("flag.a") == true:\n\t=> x\n', 'raw'],
    ['do GameVariables.set_var("flag.a", true)\n=> x\n', 'variable'],
    ['do NarrativeManager.set_flag("a", false)\n=> x\n', 'variable'],
    ['do GameVariables.set_var("flag.a", foo(1))\n=> x\n', 'raw'],
    ['do GameManager.trigger_event("x")\n=> y\n', 'event'],
    ['do GameManager.trigger_event("x", "y")\n=> y\n', 'raw'],
    ['do GameManager.trigger_event("x")\ndo GameManager.trigger_event("y")\n=> y\n', 'raw'],
    ['A: hola\ndo GameManager.trigger_event("x")\n', 'raw'],
    ['A: hola\n=> x\n- a => b\n', 'raw'],
    ['=> x\nA: hola\n', 'raw'],
    ['A: hola\nelse\n', 'raw'],
    ['A: hola [#tag]\n', 'raw'],
    ['A: hola {{do x()}}\n', 'raw'],
    ['A: hola\n  => x\n', 'raw'],
    ['- opcion\n', 'dialogue'],
    ['- opcion =>\n', 'dialogue'],
    ['- opcion\n\tA: hijo\n', 'raw'],
    ['- a b => c d\n', 'dialogue'],
    ['- \n', 'dialogue'],
    ['A: hola\n- a\n- b => c\n', 'dialogue'],
    ['=>< sub\n', 'raw'],
    ['', 'dialogue'],
  ];
  for (const [body, expected] of cases) {
    const tab = load('~ n\n\n' + body);
    check('clasifica ' + JSON.stringify(body) + ' como ' + expected, findNode(tab, 'n').nodeType === expected,
      'obtenido: ' + findNode(tab, 'n').nodeType);
    check('round-trip ' + JSON.stringify(body), F.serializeDialogue(tab) === '~ n\n\n' + body);
  }
}

// ------------------------------------------------------------
// (c) Editar una línea solo cambia ese nodo
// ------------------------------------------------------------
{
  const content = [
    '# cabecera',
    '~ start',
    '',
    'Hola, viajero.',
    '- Aceptar => ok',
    '- Rechazar => no',
    '',
    '~ ok',
    'Barnaby: Genial',
    '=> END',
    '',
    '~ no',
    '% raro',
    'Barnaby: Mal',
    '',
    '~ otro',
    '',
    'A: texto',
    '=> END',
    '',
  ].join('\n');
  const tab = load(content);
  findNode(tab, 'ok').lines[0].text = 'Genial, de verdad';
  const out = F.serializeDialogue(tab);
  const expected = content.replace('~ ok\nBarnaby: Genial\n=> END\n', '~ ok\n\nBarnaby: Genial, de verdad\n=> END\n');
  check('editar una línea solo cambia ese nodo', out === expected, out);

  // Revertir el cambio devuelve el texto literal original
  findNode(tab, 'ok').lines[0].text = 'Genial';
  check('revertir la edición restituye el original', F.serializeDialogue(tab) === content);

  // Nodo nuevo al final: lo demás no cambia
  const nuevo = {
    id: 'n1', nodeType: 'dialogue', title: 'nuevo', x: 0, y: 0, modelable: true,
    lines: [{ actor: 'X', text: 'hola', condition: '' }], choices: [], mutations: [], goto: 'END',
  };
  tab.nodes.splice(tab.nodes.length - 1, 0, nuevo);
  const out2 = F.serializeDialogue(tab);
  check('nodo nuevo se agrega sin tocar el resto', out2 === content + '~ nuevo\n\nX: hola\n=> END\n', out2);
}

// ------------------------------------------------------------
// (d) Renombrar actualiza referencias (incl. conditionOutputs y raw)
// ------------------------------------------------------------
{
  const content = [
    '~ start',
    '',
    'A: hola',
    '- Uno => destino',
    '- Dos => otro',
    '',
    '~ cond',
    '',
    'if GameVariables.get_var("flag.a") == true',
    '\t=> destino',
    '=> otro',
    '',
    '~ sw',
    '',
    'if GameVariables.get_var("flag.a") == 1',
    '\t=> destino',
    'elif GameVariables.get_var("flag.a") == 2',
    '\t=> otro',
    '=> destino',
    '',
    '~ crudo',
    '% x',
    '=> destino',
    '- opt => destino',
    '- opt2 => destino_largo',
    '',
    '~ destino',
    'A: fin',
    '=> END',
    '',
    '~ otro',
    'A: fin',
    '=> END',
    '',
    '~ destino_largo',
    'A: fin',
    '=> END',
    '',
  ].join('\n');
  const tab = load(content);
  const tgt = findNode(tab, 'destino');
  const r = F.renameNode(tab, tgt, 'meta');
  check('renombrar OK', r.ok);
  const out = F.serializeDialogue(tab);
  const reparsed = load(out);
  check('choices actualizadas', findNode(reparsed, 'start').choices[0].targetTitle === 'meta');
  check('conditionOutputs (compare) actualizados',
    findNode(reparsed, 'cond').conditionOutputs['true'] === 'meta' && findNode(reparsed, 'cond').conditionOutputs['false'] === 'otro');
  check('conditionOutputs (switch) actualizados',
    findNode(reparsed, 'sw').conditionOutputs['1'] === 'meta' && findNode(reparsed, 'sw').conditionOutputs['default'] === 'meta');
  const crudo = findNode(tab, 'crudo');
  check('raw: destinos reemplazados con límites de palabra',
    crudo.rawText === '~ crudo\n% x\n=> meta\n- opt => meta\n- opt2 => destino_largo\n\n', JSON.stringify(crudo.rawText));
  check('raw: rawTargets recalculados', JSON.stringify(crudo.rawTargets) === '["meta","destino_largo"]');
  check('el nodo renombrado aparece con su nuevo título', out.includes('~ meta\n') && !out.includes('~ destino\n'));
  check('nodo sin referencias intacto', out.includes('~ otro\nA: fin\n=> END\n'));

  // Renombrar un nodo raw reescribe su línea ~
  const r2 = F.renameNode(tab, crudo, 'crudo2');
  check('renombrar nodo raw', r2.ok && F.serializeDialogue(tab).includes('~ crudo2\n% x\n'));

  // Duplicados y reservados rechazados
  const r3 = F.renameNode(tab, findNode(tab, 'otro'), 'meta');
  check('rechaza título existente', !r3.ok && findNode(tab, 'otro').title === 'otro');
  check('rechaza END', !F.renameNode(tab, findNode(tab, 'otro'), 'END').ok);
}

// ------------------------------------------------------------
// (e) Línea condicionada: "if cond" sin ":" y línea indentada con tab
// ------------------------------------------------------------
{
  const tab = load('~ n\n\nA: hola\n=> END\n');
  const n = findNode(tab, 'n');
  n.lines.push({ actor: 'B', text: 'condicional', condition: 'GameVariables.get_var("flag.x") == true' });
  const out = F.serializeDialogue(tab);
  check('línea condicionada con if sin dos puntos e indentada con tab',
    out === '~ n\n\nA: hola\nif GameVariables.get_var("flag.x") == true\n\tB: condicional\n=> END\n', out);
  const re = load(out);
  check('la línea condicionada se re-parsea', findNode(re, 'n').lines[1].condition === 'GameVariables.get_var("flag.x") == true');
}

// ------------------------------------------------------------
// START / END visuales y archivos vacíos
// ------------------------------------------------------------
{
  const empty = load('');
  check('archivo vacío: START y END visuales', empty.nodes.length === 2 && empty.nodes[0].title === '__START__' && empty.nodes[1].title === '__END__');
  check('archivo vacío: serializa vacío', F.serializeDialogue(empty) === '');

  // Sin ~ start y START conectado por el usuario: se emite ~ start
  const tab = load('~ a\nA: x\n=> END\n');
  check('sin ~ start y sin tocar START no se inyecta nada', F.serializeDialogue(tab) === '~ a\nA: x\n=> END\n');
  check('START apunta al primer nodo', findNode(tab, '__START__').goto === 'a');
  const st = findNode(tab, '__START__');
  st.goto = 'a';
  st.startTouched = true;
  check('START conectado inyecta ~ start al principio', F.serializeDialogue(tab) === '~ start\n\n=> a\n\n~ a\nA: x\n=> END\n');

  // Con ~ start real no se inyecta aunque START esté tocado
  const tab2 = load('~ start\n\n=> a\n\n~ a\nA: x\n=> END\n');
  findNode(tab2, '__START__').startTouched = true;
  check('con ~ start real no se duplica', F.serializeDialogue(tab2) === '~ start\n\n=> a\n\n~ a\nA: x\n=> END\n');

  // END visual nunca genera ~ end
  check('END visual no genera ~ end', !F.serializeDialogue(load('~ a\n=> END\n')).includes('~ end'));

  // Archivo nuevo creado por el servidor
  const nuevo = load('~ start\n\n=> END\n');
  check('archivo nuevo: round-trip', F.serializeDialogue(nuevo) === '~ start\n\n=> END\n');
}

// formatVarValue con getVarType
{
  check('formatVarValue string tipado', F.formatVarValue('hola', 'flag.x', () => 'string') === '"hola"');
  check('formatVarValue bool', F.formatVarValue('true', 'flag.x') === 'true');
  const tab = load('~ v\n\ndo GameVariables.set_var("flag.n", 1)\n=> END\n');
  findNode(tab, 'v').varValue = 'abc';
  check('serializeDialogue usa getVarType', F.serializeDialogue(tab, () => 'string').includes('set_var("flag.n", "abc")'));
}

// ------------------------------------------------------------
// Opciones sin destino ("- texto" sin "=>")
// ------------------------------------------------------------
{
  const tab = load('~ q\n\nB: ¿Quieres?\n- Sí\n- No => q_no\n');
  const q = findNode(tab, 'q');
  check('opción sin => es opción del modelo', q.nodeType === 'dialogue' && q.choices.length === 2);
  check('opción sin => tiene destino vacío', q.choices[0].label === 'Sí' && q.choices[0].targetTitle === '' && q.choices[1].targetTitle === 'q_no');
  check('opción sin => no se convierte en raw', q.nodeType !== 'raw');
  q.lines[0].text = '¿Seguro?';
  check('editar el nodo conserva la opción sin => (sin inventar END)',
    F.serializeDialogue(tab) === '~ q\n\nB: ¿Seguro?\n- Sí\n- No => q_no\n');
  q.choices[0].targetTitle = 'q_si';
  check('conectar la opción añade el =>', F.serializeDialogue(tab).includes('- Sí => q_si\n'));
  const half = load('~ q\n\n- Sí =>\n');
  check('flecha a medias: opción sin destino', findNode(half, 'q').choices[0].label === 'Sí' && F.serializeDialogue(half) === '~ q\n\n- Sí =>\n');
  const idx = load('~ q\n\n- Sí\n\tA: hijo\n');
  check('opción con hijas indentadas sigue siendo raw', findNode(idx, 'q').nodeType === 'raw');
}

// ------------------------------------------------------------
// flowOrder / helpers de nodos
// ------------------------------------------------------------
{
  const titles = (arr) => arr.map(n => n.title).join(',');
  const fo = (t) => F.flowOrder(t.nodes, t.startAlias && t.startAlias.node.goto);
  // La respuesta aparece antes que la pregunta en el archivo
  const a = load('~ resp1\n\n=> END\n\n~ resp2\n\n=> END\n\n~ start\n\nA: ¿?\n- Sí => resp1\n- No => resp2\n');
  check('flowOrder: pregunta, resp1, resp2', titles(fo(a)) === 'start,resp1,resp2', titles(fo(a)));
  check('flowOrder ignora START/END visuales', !fo(a).some(n => n.isSpecial));

  // Un nodo con dos predecesores va después de ambos
  const b = load('~ start\n\n- x => a\n- y => c\n\n~ c\n\n=> END\n\n~ a\n\n=> c\n');
  check('flowOrder: nodo tras todos sus predecesores', titles(fo(b)) === 'start,a,c', titles(fo(b)));

  // Ciclo: el primero visitado manda
  const c = load('~ start\n\n=> b\n\n~ b\n\n- otra => start\n- sigue => c\n\n~ c\n\n=> b\n');
  check('flowOrder con ciclos', titles(fo(c)) === 'b,c', titles(fo(c)));

  // Huérfanos al final en su orden original
  const d = load('~ h2\n\n=> END\n\n~ start\n\n=> x\n\n~ h1\n\n=> END\n\n~ x\n\n=> END\n');
  check('flowOrder: huérfanos al final', titles(fo(d)) === 'x,h2,h1', titles(fo(d)));

  // Sin start: parte del primer nodo; condiciones y raw cuentan
  const e = load('~ a\n\nif GameVariables.get_var("flag.k") == true\n\t=> c\n=> b\n\n~ b\n\n=> END\n\n~ c\n\n% raro\n=> b\n');
  check('flowOrder: condiciones y raw', titles(fo(e)) === 'a,c,b', titles(fo(e)));

  // applyFlowOrder: serializa reordenado y conserva el texto literal de cada nodo
  const f = load('~ resp1\n\n=> END\n\n~ start\n\nA: ¿?\n- Sí => resp1\n- No => resp2\n\n~ resp2\n% raro\n=> END');
  check('applyFlowOrder cambia el orden', F.applyFlowOrder(f) === true);
  const out = F.serializeDialogue(f);
  check('applyFlowOrder: texto reordenado', out === '~ start\n\nA: ¿?\n- Sí => resp1\n- No => resp2\n\n~ resp1\n\n=> END\n\n~ resp2\n% raro\n=> END', JSON.stringify(out));
  check('applyFlowOrder idempotente', F.applyFlowOrder(f) === false && F.serializeDialogue(f) === out);
  const g = load('~ start\n\n=> END\n\n~ b\n\n=> END\n');
  check('applyFlowOrder sin cambios no toca nada', F.applyFlowOrder(g) === false);

  // Reorden con último nodo sin salto de línea final
  const h = load('~ b\n\n=> END\n~ start\n\n=> b');
  F.applyFlowOrder(h);
  check('applyFlowOrder separa nodos pegados', F.serializeDialogue(h) === '~ start\n\n=> b\n\n~ b\n\n=> END\n', JSON.stringify(F.serializeDialogue(h)));

  // Helpers
  check('slugifyTitle', F.slugifyTitle('¡Sí, claro!') === 'si_claro' && F.slugifyTitle('') === 'opcion');
  check('slugifyTitle máx 24', F.slugifyTitle('a'.repeat(40)).length === 24);
  check('uniqueTitle', F.uniqueTitle('x', new Set(['x', 'x_2'])) === 'x_3' && F.uniqueTitle('y', new Set()) === 'y');
  const t = load('~ q\n\n- a => q_a\n- b => q_b\n\n~ q_a\n\n=> END\n\n~ otro\n\n=> END\n');
  const nuevo = { title: 'q_b', nodeType: 'dialogue', lines: [], choices: [], goto: 'END' };
  F.insertNodeAfter(t.nodes, nuevo, findNode(t, 'q'));
  check('insertNodeAfter: tras los hijos contiguos del origen', t.nodes.map(n => n.title).join(',') === '__START__,q,q_a,q_b,otro,__END__', t.nodes.map(n => n.title).join(','));
}

// ------------------------------------------------------------
// Títulos/destinos con espacios (Dialogue Manager no los admite)
// ------------------------------------------------------------
{
  const src = '~ start\n\n=> Bien Venida\n\n~ Bien Venida\nNPC 1: Hola\n- SI => Bien Venida_si\n- No => Bien Venida_no\n\n~ Bien Venida_si\nNPC 1: x\n=> END\n';
  const a = load(src);
  const nz = a.nodes.filter(n => !n.isSpecial);
  check('espacios: ningún nodo raw', nz.every(n => n.nodeType !== 'raw'), nz.map(n => n.title + ':' + n.nodeType).join(','));
  check('espacios: START apunta a destino completo', findNode(a, '__START__').goto === 'Bien Venida', JSON.stringify(findNode(a, '__START__').goto));
  check('espacios: títulos inválidos detectados', F.isInvalidTitle('Bien Venida') && !F.isInvalidTitle('Bien_Venida') && !F.isInvalidTitle('END'));
  check('validTitle', F.validTitle('Bien Venida') === 'Bien_Venida' && F.validTitle('¡Sí, él!') === 'Si_el' && F.validTitle('END') === 'END');
  check('round-trip sin cambios idéntico', F.serializeDialogue(a) === src);

  // Normalización: texto → versión válida con referencias
  const norm = F.rewriteDestsInText(src, d => (F.isInvalidTitle(d) ? F.validTitle(d) : undefined))
    .replace('~ Bien Venida', '~ Bien_Venida').replace('~ Bien Venida_si', '~ Bien_Venida_si');
  const b = load(norm);
  const bn = b.nodes.filter(n => !n.isSpecial);
  check('normalizado: sin raw', bn.every(n => n.nodeType === 'dialogue' || n.modelable), bn.map(n => n.title + ':' + n.nodeType).join(','));
  const bv = bn.find(n => n.title === 'Bien_Venida');
  check('normalizado: Bien_Venida con 2 opciones reales',
    bv && bv.choices.length === 2 && bv.choices[0].targetTitle === 'Bien_Venida_si' && bv.choices[1].targetTitle === 'Bien_Venida_no',
    JSON.stringify(bv && bv.choices));
  check('normalizado: alias start oculto, START → Bien_Venida', !bn.some(n => n.title === 'start') && findNode(b, '__START__').goto === 'Bien_Venida');

  // Destinos exactos: no confunde prefijos ni toca END
  const r = F.rewriteDestsInText('=> Bien\n- a => Bien Venida\n=> END', d => (d === 'Bien' ? 'X' : undefined));
  check('rewriteDests: solo coincidencia exacta', r === '=> X\n- a => Bien Venida\n=> END', r);

  // Renombrar con espacios en el canvas
  const c = load('~ start\n\n- a => uno\n\n~ uno\n\n=> END\n');
  const un = c.nodes.find(n => n.title === 'uno');
  const res = F.renameNode(c, un, 'Bien Venida');
  check('renameNode normaliza', res.ok && res.normalized && res.normalized.to === 'Bien_Venida' && un.title === 'Bien_Venida');
  check('renameNode actualiza refs', c.nodes.find(n => n.title === 'start').choices[0].targetTitle === 'Bien_Venida');
}

// Archivos reales de rpg-g: siguen idénticos
{
  const dir = path.join(__dirname, '..', '..', 'rpg-g');
  const found = [];
  (function walk(d) {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      if (e.name === '.git' || e.name === '.godot' || e.name === 'node_modules') continue;
      const p = path.join(d, e.name);
      if (e.isDirectory()) walk(p); else if (e.name.endsWith('.dialogue')) found.push(p);
    }
  })(dir);
  for (const f of found) {
    const txt = fs.readFileSync(f, 'utf8');
    check('rpg-g idéntico: ' + path.basename(f), F.serializeDialogue(load(txt)) === txt);
  }
}

// ------------------------------------------------------------
// Alias `~ start` oculto
// ------------------------------------------------------------
{
  const nuevo = load('~ start\n\n=> END\n');
  check('alias: archivo nuevo sin nodo start', !nuevo.nodes.some(n => n.title === 'start') && nuevo.nodes.length === 2);
  check('alias: START → END', findNode(nuevo, '__START__').goto === 'END');
  check('alias: vacío → START sin conexión', findNode(load('~ start\n\n~ a\n=> END\n'), '__START__').goto === '');
  const t = load('~ start\n\n=> accepted\n\n~ accepted\nA: hi\n=> END\n');
  check('alias: START conecta directo al destino', findNode(t, '__START__').goto === 'accepted' && !findNode(t, 'start'));
  const c = load('~ start\nA: hola\n=> a\n\n~ a\n=> END\n');
  check('start con contenido sigue siendo nodo', !!findNode(c, 'start') && !c.startAlias && findNode(c, '__START__').goto === 'start');
  // Reconectar START reescribe el alias
  const st = findNode(t, '__START__');
  st.goto = 'otro'; st.startTouched = true;
  check('alias: reconectar START reescribe goto', F.serializeDialogue(t) === '~ start\n\n=> otro\n\n~ accepted\nA: hi\n=> END\n', F.serializeDialogue(t));
  st.goto = ''; 
  check('alias: START sin conexión → => END', F.serializeDialogue(t).startsWith('~ start\n\n=> END\n\n~ accepted'));
  // alias en medio del archivo conserva su posición
  const m = '~ a\n=> END\n\n~ start\n\n=> a\n\n~ b\n=> END\n';
  check('alias en medio: round-trip', roundtrip(m) === m);
}

// ------------------------------------------------------------
// flowDirty: cambio estructural en Nodos reordena el texto por flujo
// ------------------------------------------------------------
{
  const src = '~ start\n\n=> Bien_Venida\n\n~ Bien_Venida\nNPC: Hola\n- Si => Bien_Venida_si\n- No => Bien_Venida_no\n\n~ Bien_Venida_si\nNPC: a\n=> END\n\n~ Bien_Venida_no\nNPC: b\n=> END\n';
  const mk = () => {
    const t = load(src);
    const nuevo = { id: 'n_nuevo', title: 'nuevo', nodeType: 'dialogue', lines: [{ actor: 'NPC', text: 'x' }], choices: [], goto: 'Bien_Venida', x: 0, y: 0, conditionOutputs: {} };
    F.insertNodeAfter(t.nodes, nuevo, null); // como en Nodos: va antes del END visual
    const st = findNode(t, '__START__');
    st.goto = 'nuevo'; st.startTouched = true;
    return t;
  };
  const sinFlag = mk();
  const outSin = F.serializeDialogue(sinFlag);
  check('flowDirty ausente: el orden se mantiene (nuevo al final)', outSin.indexOf('~ nuevo') > outSin.indexOf('~ Bien_Venida_no'), outSin);
  const t = mk();
  t.flowDirty = true;
  const out = F.serializeDialogue(t);
  const idx = ['~ start => nuevo', '~ nuevo', '~ Bien_Venida\n', '~ Bien_Venida_si', '~ Bien_Venida_no'].map(k => out.indexOf(k.replace('~ start => nuevo', '~ start')));
  check('flowDirty: orden start, nuevo, Bien_Venida, si, no', idx.every((v, i) => v >= 0 && (i === 0 || v > idx[i - 1])), out);
  check('flowDirty: alias start apunta al nuevo', out.startsWith('~ start\n\n=> nuevo\n\n~ nuevo\n'), out);
  check('flowDirty: se limpia tras serializar', t.flowDirty === false);
  check('flowDirty: serializar de nuevo es estable', F.serializeDialogue(t) === out);
  check('flowDirty: nodos sin cambios conservan texto', out.includes('~ Bien_Venida\nNPC: Hola\n- Si => Bien_Venida_si\n- No => Bien_Venida_no\n\n~ Bien_Venida_si\nNPC: a\n=> END\n\n~ Bien_Venida_no\nNPC: b\n=> END\n'), out);
  // flowDirty sin cambios reales de orden: archivo idéntico
  const same = load(src); same.flowDirty = true;
  check('flowDirty sin cambio de flujo: idéntico', F.serializeDialogue(same) === src);
}

{
  // Borrado sin cortar el flujo + inserción al soltar en vacío
  const src = '~ start\nNPC: hola\n- A => a\n- B => b\n\n~ a\nNPC: a\n=> c\n\n~ b\nNPC: b\n=> c\n\n~ c\nNPC: c\n=> d\n\n~ d\nNPC: d\n=> END\n\n~ r\n=> a\n- X => a\n';
  const tab = load(src);
  const ids = ['a', 'c'].map(t => findNode(tab, t).id);
  const n = F.deleteNodesReconnect(tab, ids);
  check('delete: borra 2 nodos', n === 2 && !findNode(tab, 'a') && !findNode(tab, 'c'));
  check('delete: opción A pasa al hijo en cadena (a→c→d)', findNode(tab, 'start').choices[0].targetTitle === 'd');
  check('delete: goto de b pasa a d', findNode(tab, 'b').goto === 'd');
  const r = findNode(tab, 'r');
  check('delete: raw reescrito', r.rawText.includes('=> d') && !r.rawText.includes('=> a') && r.rawTargets.includes('d'), r.rawText);
  // Nodo con opciones: usa la primera opción
  const t2 = load('~ start\n=> q\n\n~ q\nNPC: q\n- Si => y\n- No => z\n\n~ y\nNPC: y\n=> END\n\n~ z\nNPC: z\n=> END\n');
  F.deleteNodesReconnect(t2, [findNode(t2, 'q').id]);
  check('delete: nodo con opciones → primera opción', t2.nodes.some(x => x.title === '__START__' ? x.goto === 'y' : false) || (t2.startAlias && t2.startAlias.node.goto === 'y'));
  // Ciclo → END
  const t3 = load('~ start\nNPC: s\n=> p\n\n~ p\nNPC: p\n=> q\n\n~ q\nNPC: q\n=> p\n');
  F.deleteNodesReconnect(t3, [findNode(t3, 'p').id, findNode(t3, 'q').id]);
  check('delete: ciclo → END', findNode(t3, 'start').goto === 'END');
  // Inserción
  const t4 = load('~ start\nNPC: s\n=> b\n\n~ b\nNPC: b\n=> END\n');
  const nn = { goto: '' };
  F.linkInsertedNode(t4, nn, F.getOutputTarget(findNode(t4, 'start'), -1));
  check('insert: N → B', nn.goto === 'b');
  F.linkInsertedNode(t4, nn, '');
  check('insert: sin destino → END', nn.goto === 'END');
  F.linkInsertedNode(t4, nn, 'END');
  check('insert: END → END', nn.goto === 'END');
}

{
  const tab = load('~ start\nNPC: s\n=> b\n\n~ b\nNPC: b\n=> c\n\n~ c\nNPC: c\n=> END\n');
  F.detachNodeReconnect(tab, findNode(tab, 'b'));
  check('detach: padre → hijo', findNode(tab, 'start').goto === 'c');
  check('detach: nodo queda libre', findNode(tab, 'b').goto === '' && findNode(tab, 'b') !== undefined);
}

console.log(`${passed} comprobaciones correctas, ${failures} fallos`);
process.exit(failures ? 1 : 0);
