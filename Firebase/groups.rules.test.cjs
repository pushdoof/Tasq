const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { test, before, after, beforeEach } = require('node:test');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, getDocs, collection, query, where, orderBy, limit, updateDoc, deleteDoc, serverTimestamp, Timestamp } = require('firebase/firestore');
let env;
const path = 'friendHubGroups/g';
const db = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const base = () => ({id:'g', name:'Cozy crew', adminID:'alice', memberIDs:['alice','bob'], memberNames:{alice:'Alice',bob:'Bob'}, gamesEnabled:true,focusEnabled:true,createdAt:Timestamp.fromMillis(1000)});
const game = () => ({board:Array(9).fill(''), xID:'alice',oID:'bob',turn:'X'});
const avatar = {bodyColorRaw:'skin7',mouthRaw:'none',eyesRaw:'none',hairRaw:'none',furRaw:'none',itemRaw:'none',hairHue:0,hairSaturation:.72,hairBrightness:.86,scarfHue:.78};
const presence = () => ({id:'s',userID:'bob',name:'Bob',avatar,roomID:'lounge',x:.5,y:.65,isMoving:false,lastSeen:serverTimestamp(),reaction:'',reactionAt:Timestamp.fromMillis(1000)});
async function seed(p, data) { await env.withSecurityRulesDisabled(async c => setDoc(doc(c.firestore(),p),data)); }
before(async () => { env = await initializeTestEnvironment({projectId:'demo-tasq-groups',firestore:{host:'127.0.0.1',port:8188,rules:readFileSync(resolve(__dirname,'firestore.groups.rules'),'utf8')}}); });
after(async () => { await env?.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); await seed(path,base()); await seed('friendHubProfiles/alice',{friendIDs:['bob','cara']}); });
test('member query and room/chat reads succeed', async () => {
 await assertSucceeds(getDocs(query(collection(db('bob'),'friendHubGroups'),where('memberIDs','array-contains','bob'))));
 await assertSucceeds(getDocs(query(collection(db('bob'),path+'/presence'),where('lastSeen','>',Timestamp.fromMillis(Date.now()-60000)))));
 await assertSucceeds(getDocs(query(collection(db('bob'),path+'/messages'),orderBy('createdAt','desc'),limit(80))));
});
test('unauthenticated and outsider reads and writes fail', async () => {
 for (const uid of [null,'eve']) {
  await assertFails(getDoc(doc(db(uid),path)));
  await assertFails(getDocs(collection(db(uid),'friendHubGroups')));
  await assertFails(getDocs(collection(db(uid),path+'/messages')));
  await assertFails(updateDoc(doc(db(uid),path),{name:'Hijacked'}));
 }
});
test('create requires self as admin and selected friends', async () => {
 const valid = {...base(),id:'new',createdAt:serverTimestamp()};
 await assertSucceeds(setDoc(doc(db('alice'),'friendHubGroups/new'),valid));
 await assertFails(setDoc(doc(db('bob'),'friendHubGroups/forged'),{...valid,id:'forged'}));
 await assertFails(setDoc(doc(db('alice'),'friendHubGroups/stranger'),{...valid,id:'stranger',memberIDs:['alice','eve'],memberNames:{alice:'Alice',eve:'Eve'}}));
});
test('admin can add a friend, remove members and transfer role', async () => {
 await assertSucceeds(updateDoc(doc(db('alice'),path),{memberIDs:['alice','bob','cara'],memberNames:{alice:'Alice',bob:'Bob',cara:'Cara'}}));
 await assertSucceeds(updateDoc(doc(db('alice'),path),{adminID:'bob'}));
 await assertFails(updateDoc(doc(db('alice'),path),{gamesEnabled:false}));
 await seed('friendHubProfiles/bob',{friendIDs:[]});
 await assertSucceeds(updateDoc(doc(db('bob'),path),{memberIDs:['bob','cara'],memberNames:{bob:'Bob',cara:'Cara'}}));
 await assertFails(getDoc(doc(db('alice'),path)));
});
test('ordinary member cannot grant privileges or edit rooms', async () => {
 for (const change of [{adminID:'bob'},{gamesEnabled:false},{focusEnabled:false},{name:'Changed'}, {memberIDs:['alice','bob','eve'],memberNames:{alice:'Alice',bob:'Bob',eve:'Eve'}}])
  await assertFails(updateDoc(doc(db('bob'),path),change));
});
test('member may leave only themselves, admin must transfer first', async () => {
 await assertFails(updateDoc(doc(db('bob'),path),{memberIDs:['bob'],memberNames:{bob:'Bob'}}));
 await assertSucceeds(updateDoc(doc(db('bob'),path),{memberIDs:['alice'],memberNames:{alice:'Alice'}}));
 await assertFails(getDoc(doc(db('bob'),path)));
 await assertFails(updateDoc(doc(db('alice'),path),{memberIDs:[],memberNames:{}}));
});
test('schema, field lengths, immutable timestamps and types validated on update', async () => {
 for (const change of [{name:'x'.repeat(33)},{name:42},{name:''},{createdAt:serverTimestamp()},{id:'wrong'},{extra:'pollution'},{memberNames:{alice:'x'.repeat(10000),bob:'Bob'}},{memberIDs:['alice','alice']},{gamesEnabled:'true'},{memberNames:{alice:'Alice'}}])
  await assertFails(updateDoc(doc(db('alice'),path),change));
});
test('presence ownership, movement bounds and timestamps enforced', async () => {
 const ref = doc(db('bob'),path+'/presence/s');
 await assertSucceeds(setDoc(ref,presence()));
 await assertSucceeds(updateDoc(ref,{x:.7,lastSeen:serverTimestamp()}));
 await assertFails(updateDoc(doc(db('alice'),path+'/presence/s'),{x:.2,lastSeen:serverTimestamp()}));
 for(const change of [{x:-1},{y:5},{name:'x'.repeat(33)},{userID:'alice'},{extra:1},{avatar:{...avatar,scarfHue:99}},{lastSeen:Timestamp.fromMillis(0)}])
  await assertFails(updateDoc(ref,{lastSeen:serverTimestamp(),...change}));
 await assertFails(deleteDoc(doc(db('alice'),path+'/presence/s')));
 await assertSucceeds(deleteDoc(ref));
});
test('disabled rooms reject presence and new activities', async () => {
 await seed(path,{...base(),gamesEnabled:false,focusEnabled:false});
 await assertFails(setDoc(doc(db('bob'),path+'/presence/s'),{...presence(),roomID:'arcade'}));
 await assertFails(setDoc(doc(db('bob'),path+'/presence/s'),{...presence(),roomID:'quiet'}));
 await assertFails(setDoc(doc(db('alice'),path+'/activities/tictactoe'),{...game(),oID:''}));
 await assertFails(setDoc(doc(db('alice'),path+'/activities/focus'),{endsAt:Timestamp.fromMillis(Date.now()+25*60000)}));
});
test('removed member loses all room access, can clean their presence', async () => {
 await seed(path+'/presence/s',{...presence(),lastSeen:Timestamp.now()});
 await seed(path,{...base(),memberIDs:['alice'],memberNames:{alice:'Alice'}});
 await assertFails(getDocs(collection(db('bob'),path+'/presence')));
 await assertFails(setDoc(doc(db('bob'),path+'/presence/s'),presence()));
 await assertSucceeds(deleteDoc(doc(db('bob'),path+'/presence/s')));
});
test('messages enforce sender, size, schema and immutability', async () => {
 const message = {id:'m',senderID:'bob',senderName:'Bob',text:'Hello!',createdAt:serverTimestamp()};
 const ref = doc(db('bob'),path+'/messages/m');
 await assertSucceeds(setDoc(ref,message));
 await assertFails(updateDoc(ref,{text:'Edited'}));
 await assertFails(deleteDoc(ref));
 for(const change of [{senderID:'alice'},{text:'x'.repeat(501)},{text:''},{extra:true},{createdAt:Timestamp.fromMillis(1000)}])
  await assertFails(setDoc(doc(db('bob'),path+'/messages/bad'),{...message,id:'bad',...change}));
});
test('only admin starts bounded focus sessions', async () => {
 const value = {endsAt:Timestamp.fromMillis(Date.now()+25*60000)};
 await assertSucceeds(setDoc(doc(db('alice'),path+'/activities/focus'),value));
 await assertFails(setDoc(doc(db('bob'),path+'/activities/focus'),value));
 await assertFails(updateDoc(doc(db('alice'),path+'/activities/focus'),{endsAt:Timestamp.fromMillis(Date.now()+99*60000)}));
 await assertFails(deleteDoc(doc(db('bob'),path+'/activities/focus')));
 await assertSucceeds(deleteDoc(doc(db('alice'),path+'/activities/focus')));
});
test('two players join without stealing a seat', async () => {
 await assertSucceeds(setDoc(doc(db('alice'),path+'/activities/tictactoe'),{...game(),oID:''}));
 await assertFails(updateDoc(doc(db('alice'),path+'/activities/tictactoe'),{oID:'alice'}));
 await assertSucceeds(updateDoc(doc(db('bob'),path+'/activities/tictactoe'),{oID:'bob'}));
 await assertFails(updateDoc(doc(db('bob'),path+'/activities/tictactoe'),{xID:'bob',oID:'alice'}));
});
test('game allows exactly one move in the correct turn', async () => {
 await seed(path+'/activities/tictactoe',game());
 const move = {...game(),board:['X','','','','','','','',''],turn:'O'};
 await assertFails(setDoc(doc(db('bob'),path+'/activities/tictactoe'),move));
 await assertFails(setDoc(doc(db('alice'),path+'/activities/tictactoe'),{...move,board:['X','X','','','','','','','']}));
 await assertSucceeds(setDoc(doc(db('alice'),path+'/activities/tictactoe'),move));
 await assertFails(updateDoc(doc(db('bob'),path+'/activities/tictactoe'),{board:['O','','','','','','','',''],turn:'X'}));
 await assertSucceeds(updateDoc(doc(db('bob'),path+'/activities/tictactoe'),{board:['X','O','','','','','','',''],turn:'X'}));
});
test('finished games reject moves and allow a player reset', async () => {
 await seed(path+'/activities/tictactoe',{...game(),board:['X','X','X','O','O','','','',''],turn:'O'});
 await assertFails(updateDoc(doc(db('bob'),path+'/activities/tictactoe'),{board:['X','X','X','O','O','O','','',''],turn:'X'}));
 await assertSucceeds(setDoc(doc(db('bob'),path+'/activities/tictactoe'),{...game(),xID:'',oID:''}));
});
test('orphaned subcollections and unknown activities deny access', async () => {
 await assertFails(getDocs(collection(db('alice'),'friendHubGroups/missing/messages')));
 await assertFails(setDoc(doc(db('alice'),path+'/activities/unknown'),{secret:true}));
 await assertFails(getDoc(doc(db('alice'),'privateUsers/bob')));
});
test('a complete nine-move draw stays within the rules evaluation budget', async () => {
 await seed(path+'/activities/tictactoe',game());
 let state = game();
 for(const index of [0,1,2,4,3,5,7,6,8]) {
  const uid = state.turn === 'X' ? 'alice' : 'bob';
  state = {...state,board:[...state.board]}; state.board[index] = state.turn; state.turn = state.turn === 'X' ? 'O' : 'X';
  await assertSucceeds(setDoc(doc(db(uid),path+'/activities/tictactoe'),state));
 }
});
test('maximum size group works and oversized group fails', async () => {
 const ids = ['alice', ...Array.from({length:19},(_,i)=>'friend'+i)];
 await seed('friendHubProfiles/alice',{friendIDs:ids.slice(1)});
 const value = {...base(),id:'large',memberIDs:ids,memberNames:Object.fromEntries(ids.map(id=>[id,id])),createdAt:serverTimestamp()};
 await assertSucceeds(setDoc(doc(db('alice'),'friendHubGroups/large'),value));
 await assertSucceeds(updateDoc(doc(db('alice'),'friendHubGroups/large'),{name:'Twenty friends'}));
 await assertFails(updateDoc(doc(db('alice'),'friendHubGroups/large'),{memberNames:{...value.memberNames,friend18:'x'.repeat(33)}}));
 await assertFails(updateDoc(doc(db('alice'),'friendHubGroups/large'),{memberIDs:[...ids,'extra'],memberNames:{...value.memberNames,extra:'Extra'}}));
});
