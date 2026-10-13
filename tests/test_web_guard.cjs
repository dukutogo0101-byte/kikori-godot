const assert = require('node:assert/strict');
const protect = require('../web/framebuffer_guard.js');
const calls = [];
const gl = {
  COLOR_BUFFER_BIT: 16384, NEAREST: 9728,
  FRAMEBUFFER: 36160, READ_FRAMEBUFFER: 36008, DRAW_FRAMEBUFFER: 36009,
  READ_FRAMEBUFFER_BINDING: 36010, DRAW_FRAMEBUFFER_BINDING: 36006,
  getParameter() { return null; },
  bindFramebuffer(...args) { calls.push(['bind', ...args]); },
  blitFramebuffer(...args) { calls.push(['blit', ...args]); }
};
assert.equal(protect(gl), gl);
const same = [0, 0, 100, 80, 0, 0, 100, 80, 16384, 9728];
gl.blitFramebuffer(...same);
assert.equal(calls.filter(c => c[0] === 'blit').length, 0, 'Identical default framebuffer copy is a no-op');
const source = {}, destination = {};
gl.bindFramebuffer(gl.READ_FRAMEBUFFER, source);
gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, destination);
gl.blitFramebuffer(...same);
assert.deepEqual(calls.at(-1), ['blit', ...same], 'Real source → destination copy must be preserved');
gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, source);
gl.blitFramebuffer(...same);
assert.equal(gl.kikoriFramebufferGuard.skippedSelfBlits, 2, 'Identical explicit framebuffer copy is skipped');
const shifted = [0, 0, 100, 80, 1, 0, 101, 80, 16384, 9728];
gl.blitFramebuffer(...shifted);
assert.deepEqual(calls.at(-1), ['blit', ...shifted], 'Different rectangles must reach WebGL validation unchanged');
gl.bindFramebuffer(gl.FRAMEBUFFER, destination);
gl.blitFramebuffer(...same);
assert.equal(gl.kikoriFramebufferGuard.skippedSelfBlits, 3, 'Combined binding changes both targets');
assert.equal(protect(gl), gl);
gl.blitFramebuffer(...same);
assert.equal(gl.kikoriFramebufferGuard.skippedSelfBlits, 4, 'Protecting twice does not wrap twice');
assert.equal(protect(null), null);
assert.deepEqual(protect({}), {});
console.log('KIKORI_WEB_GUARD passed');
// Real screen resolve must preserve bindings and reuse one bounded allocation.
const bindings = {read: source, draw: null, texture: {old:true}, unpack: {old:true}};
const resolved = [];
let textures = 0, framebuffers = 0, allocations = 0;
const gpu = {
  FRAMEBUFFER:36160, READ_FRAMEBUFFER:36008, DRAW_FRAMEBUFFER:36009,
  READ_FRAMEBUFFER_BINDING:36010, DRAW_FRAMEBUFFER_BINDING:36006,
  COLOR_BUFFER_BIT:16384, NEAREST:9728, READ_BUFFER:3074, COLOR_ATTACHMENT0:36064,
  TEXTURE_2D:3553, TEXTURE_BINDING_2D:32873, PIXEL_UNPACK_BUFFER:35052,
  PIXEL_UNPACK_BUFFER_BINDING:35055, RGBA8:32856, RGBA:6408, UNSIGNED_BYTE:5121,
  drawingBufferWidth:100, drawingBufferHeight:80,
  getParameter(key) { return ({36010:bindings.read,36006:bindings.draw,3074:36064,32873:bindings.texture,35055:bindings.unpack})[key]; },
  bindFramebuffer(target,value) { if(target===36160||target===36008)bindings.read=value;if(target===36160||target===36009)bindings.draw=value; },
  bindTexture(target,value) { bindings.texture=value; },
  bindBuffer(target,value) { bindings.unpack=value; },
  createTexture() { textures++;return {scratch:true}; },
  createFramebuffer() { framebuffers++;return {scratch:true}; },
  texImage2D() { allocations++; },
  framebufferTexture2D() {},
  blitFramebuffer() { resolved.push({from:bindings.read,to:bindings.draw}); }
};
const saved={...bindings};protect(gpu);gpu.blitFramebuffer(...same);
assert.equal(resolved.length,2);
assert.equal(resolved[0].from,source);
assert.notEqual(resolved[0].to,null);
assert.equal(resolved[1].from,resolved[0].to);
assert.equal(resolved[1].to,null);
assert.deepEqual(bindings,saved,'Resolve restores source, destination, texture and unpack buffer');
gpu.blitFramebuffer(...same);
assert.equal(textures,1);assert.equal(framebuffers,1);assert.equal(allocations,1);
gpu.drawingBufferWidth=120;
gpu.blitFramebuffer(0,0,120,80,0,0,120,80,16384,9728);
assert.equal(allocations,2,'Resize replaces storage without growing object count');
assert.deepEqual(bindings,saved);
console.log('KIKORI_FRAMEBUFFER_RESOLVE passed');
