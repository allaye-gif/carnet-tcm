/* Vérifications de conformité au carnet papier ASECNA.
   À lancer depuis la racine du dépôt :  node tests/verif-conformite.js
   Aucune dépendance, aucun navigateur, aucune base de données : le script charge
   le JavaScript de public/index.html dans un bac à sable et contrôle les fonctions
   de calcul et de conversion. Sort en code 1 si un contrôle échoue. */

const fs = require('fs');
const vm = require('vm');
const path = require('path');

const fichier = path.join(__dirname, '..', 'public', 'index.html');
const html = fs.readFileSync(fichier, 'utf8');
const src = [...html.matchAll(/<script(?![^>]*src=)[^>]*>([\s\S]*?)<\/script>/g)][0][1];

// Bac à sable minimal : l'application s'arrête d'elle-même faute de vrai DOM,
// mais toutes les fonctions sont alors définies et utilisables.
const bac = {
  console, Math, Date, JSON, String, Number, Array, Object,
  parseInt, parseFloat, isNaN, RegExp, setTimeout, clearTimeout, navigator: {},
  document: { addEventListener(){}, querySelectorAll: ()=>[], querySelector: ()=>null, getElementById: ()=>null },
  window: { addEventListener(){} },
  localStorage: { getItem: ()=>null, setItem(){} },
  fetch: ()=>Promise.reject(new Error('hors ligne'))
};
bac.globalThis = bac;
vm.createContext(bac);
try { vm.runInContext(src, bac); } catch (e) { /* l'initialisation DOM échoue, c'est attendu */ }

let echecs = 0;
function verifie(condition, libelle, detail){
  if(!condition) echecs++;
  const etat = condition ? '  OK    ' : '  ECHEC ';
  console.log(etat + libelle + (detail === undefined ? '' : '  -> ' + JSON.stringify(detail)));
}
function titre(t){ console.log('\n' + t); }

titre('1. Saisie en dixièmes, comme sur le carnet papier');
[['192','19.2'],['210','21'],['083','8.3'],['042','4.2'],['10132','1013.2'],
 ['19,2','19.2'],['19.2','19.2'],['-035','-3.5'],['X','X'],['','']]
  .forEach(([saisi, attendu])=>{
    const obtenu = bac.inputToTenths(saisi);
    verifie(obtenu === attendu, `saisir ${JSON.stringify(saisi)} enregistre ${attendu}`, obtenu);
  });
[['19.2','192'],['21','210'],['8.3','83'],['1013.2','10132'],['-3.5','-35'],['X','X']]
  .forEach(([stocke, attendu])=>{
    const obtenu = bac.tenthsToInput(stocke);
    verifie(obtenu === attendu, `${stocke} se réaffiche ${attendu}`, obtenu);
  });

titre('2. Heures : toujours HH:MM sur 24 h, quel que soit le navigateur');
[['6','06:00'],['06','06:00'],['0630','06:30'],['6h30','06:30'],['06:30','06:30'],['18','18:00'],['','']]
  .forEach(([saisi, attendu])=>{
    const obtenu = bac.normalizeHeure(saisi);
    verifie(obtenu === attendu, `${JSON.stringify(saisi)} devient ${attendu || '(vide)'}`, obtenu);
  });

titre('3. Début, fin et durée des phénomènes');
let d = bac.phenDuration('14:20','15:05');
verifie(d && d.minutes === 45, 'phénomène de 45 minutes', d && d.label);
d = bac.phenDuration('23:40','01:15');
verifie(d && d.minutes === 95 && d.apresMinuit, 'phénomène à cheval sur minuit', d && d.label);
verifie(d && d.heures === '1.6' && d.carnet === '16', 'durée en heures et écriture carnet', d && (d.heures + ' h -> ' + d.carnet));
d = bac.phenDuration('06:00','12:00');
verifie(d && d.heures === '6' && d.carnet === '60', '6 h pleines s\'écrivent 60 en 1/10 h', d && d.carnet);
verifie(bac.phenDuration('06:00','') === null, 'sans heure de fin, pas de durée calculée');

titre('4. Calculs faits par l\'application à la place de l\'observateur');
const rec = { extras: bac.emptyExtras() };
Object.assign(rec.extras, {
  evapPiche06_prec:'13.4', evapPiche06_lect:'15.8', evapPiche18_prec:'0', evapPiche18_lect:'4.9',
  bac06_h1:'7.0', bac06_h2:'4.2',
  extr06_abriMini:'16.1', extr06_abriMaxi:'33.4', extr06_abriMaxiHeure:'14:00',
  extr18_abriMini:'15.2', extr18_abriMaxi:'31.6',
  insolationMatin:'4.8', insolationSoir:'5.1',
  precip18h6h:'2.5', precip6h18h:'7.5',
  sol06_10:'21', sol12_10:'26.8', sol06_20:'23.3'
});
bac.recomputeExtrasDerived(rec);
const x = rec.extras;
verifie(x.evapPiche06_diff === '2.4', 'Piché 06h : 15,8 − 13,4', x.evapPiche06_diff);
verifie(x.evapPiche18_diff === '4.9', 'Piché 18h : 4,9 − 0', x.evapPiche18_diff);
verifie(x.evapPiche === '7.3', 'Piché, total du jour', x.evapPiche);
verifie(x.bac06_diff === '2.8', 'bac : D = h1 − h2', x.bac06_diff);
verifie(x.bac06_evap === '2.8', 'bac : évaporation = D + appoint', x.bac06_evap);
verifie(x.tempMaxiAbri === '33.4' && x.tempMaxiAbriHeure === '14:00', 'Tx du jour et son heure', x.tempMaxiAbri + ' à ' + x.tempMaxiAbriHeure);
verifie(x.tempMiniAbri === '15.2', 'Tn du jour = le plus bas des mini horaires', x.tempMiniAbri);
verifie(x.insolationTotal === '9.9', 'insolation totale = matin + soir', x.insolationTotal);
verifie(x.precipitation24h === '10', 'précipitations 24h = 18h→6h + 6h→18h', x.precipitation24h);
verifie(x.sol10_12h === '26.8' && x.sol20 === '23.3', 'anciennes clés de sol tenues à jour pour le tableau mensuel');

titre('5. Reprise des carnets saisis avant la mise en conformité');
const ancien = bac.withDefaults({
  stationId:'S', date:'2025-01-01', hours:{}, grainsOrages:[],
  observationsSpeciales:[{id:'a', heure:'14:20', description:'Pluie'}],
  extras:{ evapPicheLecturePrecedente:'13.4', evapPicheLecture:'15.8',
           tempMiniAbri:'16.1', tempMaxiAbri:'33.4', sol10_6h:'21', sol20:'23.3' }
}, 'S', '2025-01-01');
verifie(ancien.extras.evapPiche06_prec === '13.4', 'ancien Piché repris dans la ligne 06h');
verifie(ancien.extras.extr06_abriMaxi === '33.4', 'ancien Tx repris dans la ligne 06h');
verifie(ancien.extras.sol06_10 === '21' && ancien.extras.sol06_20 === '23.3', 'anciennes températures du sol reprises dans la grille');
verifie(ancien.observationsSpeciales[0].heureDebut === '14:20', 'ancienne observation : heure devient heure de début');
verifie(ancien.observationsSpeciales[0].description === 'Pluie', 'description de l\'observation conservée');

titre('6. Aucune régression sur le calcul d\'humidité (exemple officiel Guide CIMO)');
const heure = { Tsec:'20.2', Tw:'14.6' };
bac.autoComputeHygro(heure, 1000);
verifie(heure.pointRosee === '10.7', 'point de rosée conforme à l\'exemple officiel (10,7 °C)', heure.pointRosee);

titre('7. Les tableaux du carnet se construisent sans erreur');
const jeu = bac.withDefaults({ stationId:'S', date:'2025-01-01', hours:{},
  grainsOrages:[{id:'g', heureCrochet:'14:00'}],
  observationsSpeciales:[{id:'1', phenomene:'21', heureDebut:'23:40', heureFin:'01:15'}], extras:{} }, 'S','2025-01-01');
[['bas de la page 3 (pluviomètre, Piché, sol)', ()=>bac.basPage3Table(jeu)],
 ['quantité et durée des précipitations', ()=>bac.quantiteDureeTable(jeu)],
 ['évaporation bac classe A', ()=>bac.bacTable(jeu)],
 ['insolation et rayonnement', ()=>bac.insolationTable(jeu)],
 ['températures extrêmes', ()=>bac.tempExtremesTable(jeu)],
 ['pressions extrêmes', ()=>bac.pressionsExtremesTable(jeu)],
 ['valeurs extrêmes du jour', ()=>bac.valeursExtremesTable(jeu)],
 ['grains, orages, grêles', ()=>bac.grainsTable(jeu)],
 ['observations spéciales', ()=>bac.obsSpecialesTable(jeu)],
 ['observations supplémentaires — page 1', ()=>bac.obsSupTable(jeu, 'p1')],
 ['observations supplémentaires — page 2', ()=>bac.obsSupTable(jeu, 'p2')]
].forEach(([nom, fn])=>{
  try { verifie(fn().length > 100, `tableau « ${nom} »`); }
  catch(e){ verifie(false, `tableau « ${nom} »`, e.message); }
});
const ve = bac.valeursExtremesTable(jeu);
// 7 cases d'heure et non 9 : direction et vitesse d'un même vent partagent une
// seule heure, comme sur le carnet (la rafale a une heure, pas deux).
verifie(ve.split('data-heure=').length - 1 === 7, 'la ligne HEURE couvre les 9 colonnes en 7 cases',
  ve.split('data-heure=').length - 1);
const te = bac.tempExtremesTable(jeu);
verifie(['00','06','12','18'].every(h=> te.includes('>'+h+'<')), 'les 4 heures de relevé 00/06/12/18 sont présentes');

titre('8. Inventaire des colonnes du carnet papier');
/* Chaque numéro imprimé sur le carnet (relevé sur les photos du carnet réel) doit
   apparaître quelque part dans l'application. C'est le contrôle qui empêche
   d'oublier à nouveau une partie du bas de page. */
const station = { id:'S', name:'Station test', lat:'12', lon:'-8', alt:'381', active:true };
const rendu = [1,2,3,4].map(n=> bac['paperPage'+n](jeu, station)).join('\n');
const presente = n => new RegExp('>' + n + '<').test(rendu);
const blocs = [
  ['Tour d\'horizon (page 1)',            [2,3,4,5,6,7,8,9,10,11,12,13,14]],
  ['Grains, orages, grêles',              [23,24,25,26,27,28,29,30,31,32,33,34,35,36,37]],
  ['Observations spéciales (page 2)',     [38,39,40,41,42,43]],
  ['Précipitations, température (page 3)',[46,47,48,49,50,51,52,53,54,55,56]],
  ['Pression (page 4)',                   [57,58,59,60,61,62,63,64,65,66,67]],
  ['Bas de page 3 : pluvio, Piché, sol',  [68,69,70,71,72,73,74,75,76,77,78]],
  ['Quantité et durée des précipitations',[79,80]],
  ['Bac classe A et son anémomètre',      [81,82,83,84,85,86,87,88,89,90]],
  ['Insolation et rayonnement',           [91,92,93,94,95]],
  ['Températures extrêmes',               [96,97,98,99,100,101,102]],
  ['Pressions extrêmes',                  [103,104,105,106,107,108]],
  ['Valeurs extrêmes du jour',            [109,110,111,112,113,114,115,116,117]]
];
blocs.forEach(([nom, nums])=>{
  const manquants = nums.filter(n=> !presente(n));
  verifie(manquants.length === 0, `${nom} — colonnes ${nums[0]} à ${nums[nums.length-1]}`,
    manquants.length ? 'manque ' + manquants.join(', ') : undefined);
});

console.log(echecs ? `\n${echecs} contrôle(s) en échec.` : '\nTous les contrôles passent.');
process.exit(echecs ? 1 : 0);
