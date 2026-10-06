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
  const { header, nodes } = F.parseDialogueFile(content, {});
  return { header, nodes };
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
    ['- opcion\n', 'raw'],
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

console.log(`${passed} comprobaciones correctas, ${failures} fallos`);
process.exit(failures ? 1 : 0);
