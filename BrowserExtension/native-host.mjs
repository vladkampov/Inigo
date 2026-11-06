import net from 'node:net';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
let buffer=Buffer.alloc(0),socket;
function send(value){const data=Buffer.from(JSON.stringify(value));const header=Buffer.alloc(4);header.writeUInt32LE(data.length);process.stdout.write(Buffer.concat([header,data]));}
process.stdin.on('data',chunk=>{buffer=Buffer.concat([buffer,chunk]);if(buffer.length>100004)process.exit(1);if(buffer.length<4)return;const size=buffer.readUInt32LE();if(size>100000)process.exit(1);if(buffer.length<4+size)return;
try{const message=JSON.parse(buffer.subarray(4,4+size));buffer=buffer.subarray(4+size);if(message.private!==false)throw Error();const route=JSON.parse(fs.readFileSync(path.join(os.homedir(),'Library/Application Support/Inigo/browser-route.json'),'utf8'));socket=net.connect({host:'127.0.0.1',port:route.port},()=>socket.write(JSON.stringify({...message,token:route.token})+'\n'));let response='';socket.on('data',data=>{response+=data.toString();if(response.length>100000)process.exit(1);if(response.includes('\n')){send(JSON.parse(response.split('\n')[0]));socket.end()}});socket.on('error',()=>{send({error:'Open Inigo and try again.'});process.exit(0)})}catch{send({error:'Open Inigo and install the browser connection.'})}});
process.stdin.on('end',()=>{socket?.destroy();process.exit(0)});
