import test from 'node:test';
import assert from 'node:assert/strict';
import {equal,safeEndpoint,validateClaims,selectModel,form} from '../oauth.mjs';
const identity={sub:'account',exp:Math.floor(Date.now()/1000)+1000,nonce:'expected',aud:'client'};
test('state and nonce comparisons reject mismatch and malformed values',()=>{assert.equal(equal('a','a'),true);assert.equal(equal('a','aa'),false);assert.equal(equal(null,'a'),false);assert.equal(equal('a','b'),false)});
test('discovery cannot redirect credentials off the trusted issuer',()=>{assert.throws(()=>safeEndpoint('https://attacker.example/token'));assert.throws(()=>safeEndpoint('http://auth.openai.com/token'));assert.equal(safeEndpoint('https://auth.openai.com/token'),'https://auth.openai.com/token')});
test('nonce, subject and authorized party are bound to the pending account',()=>{assert.throws(()=>validateClaims({...identity,nonce:'other'},{clientID:'client',nonce:'expected'}));assert.throws(()=>validateClaims(identity,{clientID:'client',subject:'other'}));assert.throws(()=>validateClaims({...identity,azp:'other'},{clientID:'client'}));assert.equal(validateClaims(identity,{clientID:'client',nonce:'expected',subject:'account'}).sub,'account')});
test('missing expiry and ambiguous audience are rejected',()=>{assert.throws(()=>validateClaims({sub:'account'},{clientID:'client'}));assert.throws(()=>validateClaims({...identity,aud:['client','other']},{clientID:'client'}))});
test('hidden and malformed catalog entries cannot be selected',()=>{assert.equal(selectModel([{slug:'hidden',visibility:'hidden'}]),undefined);assert.equal(selectModel([{slug:'first',visibility:'list'},{slug:'model-mini',visibility:'list'}]).slug,'model-mini')});
test('authorization code and verifier use form encoding',()=>{assert.equal(form({code:'a+b&c',code_verifier:'x/y'}).get('code'),'a+b&c');assert.ok(form({code:'a+b&c'}).toString().includes('%2B'))});

test('authorization endpoints reject credentials and nonstandard ports',()=>{for(const url of ['https://user:secret@auth.openai.com/token','https://auth.openai.com:8443/token','https://auth.openai.com.attacker.example/token'])assert.throws(()=>safeEndpoint(url));});
