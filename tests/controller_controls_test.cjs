const fs = require('fs'), vm = require('vm'), assert = require('assert');
const source = fs.readFileSync('web/controller.html','utf8').split('<script>')[1].split('</script>')[0];
const elements = {};
function element(id) { return elements[id] ||= { hidden:false, style:{}, dataset:{}, clientHeight:400,
  setAttribute(k,v){this[k]=v}, setPointerCapture(){}, getBoundingClientRect(){return {top:0,height:400}},
  querySelectorAll(){return buttons} }; }
const modes = ['touch','tilt','buttons'].map(mode => Object.assign(element(mode), {dataset:{mode}}));
const buttons = [-1,1].map(axis => Object.assign(element('axis'+axis), {dataset:{axis:String(axis)}}));
const handlers = {}, frames = [], packets = [];
let now = 100, heartbeatCallback, closeCount = 0;
class Socket { static OPEN=1; constructor(){this.readyState=1; Socket.instance=this} send(s){packets.push(JSON.parse(s))} close(){closeCount++} }
const window = { addEventListener(type,callback){handlers[type]=callback}, DeviceOrientationEvent:{}, orientation:0 };
const context = { sessionStorage:{getItem(){return null},setItem(){}}, crypto:{randomUUID(){return "controller-test-session"}}, DeviceOrientationEvent:window.DeviceOrientationEvent, document:{getElementById:element, querySelectorAll(){return modes}}, window,
  screen:{orientation:{angle:0}}, location:{hostname:'localhost'}, WebSocket:Socket,
  performance:{now(){return now}}, requestAnimationFrame(fn){frames.push(fn)},
  setTimeout(){},clearTimeout(){},setInterval(fn){heartbeatCallback=fn},clearInterval(){}, console };
vm.createContext(context); vm.runInContext(source,context); Socket.instance.onopen();
const tick = time => frames.shift()(time);
(async()=>{
  element('pad').onpointerdown({pointerId:1,clientY:400});tick(116);
  assert.equal(packets.at(-1).type,'move');assert.equal(packets.at(-1).y,1);
  await modes[2].onclick(); buttons[0].onpointerdown({pointerId:2});tick(150);
  assert(packets.at(-1).y < 1); const stopped=packets.at(-1).y;
  buttons[0].onpointercancel({pointerId:2});tick(166);assert.equal(packets.at(-1).y,stopped);
  await modes[1].onclick();handlers.deviceorientation({beta:15,gamma:0});tick(182);assert.equal(packets.at(-1).y,.5);
  handlers.deviceorientation({beta:45,gamma:0});tick(198);assert.equal(packets.at(-1).y,1);
  element('calibrate').onclick();tick(214);assert.equal(packets.at(-1).y,.5);
  Socket.instance.onmessage({data:JSON.stringify({type:'pong',sent:100})});
  assert.equal(element('ping').textContent,'PING 0 ms');assert.equal(packets.at(-1).type,'latency');
  assert.equal(packets.find(p => p.type === 'hello').session, 'controller-test-session');
  now=2100; heartbeatCallback(); now=4100; heartbeatCallback();
  now=5100; Socket.instance.onmessage({data:JSON.stringify({type:'pong',sent:2100})});
  assert.equal(element('ping').textContent,'PING 3000 ms');
  now=12000; heartbeatCallback(); assert.equal(closeCount,0);
  Socket.instance.onmessage({data:JSON.stringify({type:'status',text:'Match paused • Right phone disconnected'})});
  assert(element('status').textContent.includes('Match paused'));
  window.DeviceOrientationEvent.requestPermission=async()=> 'denied';await modes[1].onclick();
  assert(element('hint').textContent.includes('denied'));
  console.log('PASS: drag, held buttons, pointer cancellation, tilt, calibration, permission denial, ping UI, delayed pong, stale-ping tolerance, stable session, and match status');
})().catch(e=>{console.error(e);process.exitCode=1});
