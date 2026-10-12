const assert = require('node:assert/strict');
const protect = require('../web/framebuffer_guard.js');
const calls = [];
const gl = {
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
