/* KIKORI — MIT. Narrow workaround for redundant WebGL framebuffer self-blits.
 * https://github.com/godotengine/godot/issues/122816
 * Copying an identical rectangle onto the same framebuffer cannot change it,
 * and WebGL correctly rejects the call. Never skip copies between different
 * targets, or copies whose rectangles differ. No error filtering is used.
 */
(function (root) {
  'use strict';
  function protectContext(gl) {
    if (!gl || typeof gl.blitFramebuffer !== 'function' || gl.kikoriFramebufferGuard) return gl;
    let read = gl.getParameter(gl.READ_FRAMEBUFFER_BINDING);
    let draw = gl.getParameter(gl.DRAW_FRAMEBUFFER_BINDING);
    const originalBind = gl.bindFramebuffer.bind(gl);
    const originalBlit = gl.blitFramebuffer.bind(gl);
    const stats = { skippedSelfBlits: 0, forwardedBlits: 0 };
    gl.bindFramebuffer = function (target, framebuffer) {
      originalBind(target, framebuffer);
      if (target === gl.FRAMEBUFFER || target === gl.READ_FRAMEBUFFER) read = framebuffer;
      if (target === gl.FRAMEBUFFER || target === gl.DRAW_FRAMEBUFFER) draw = framebuffer;
    };
    gl.blitFramebuffer = function (sx0, sy0, sx1, sy1, dx0, dy0, dx1, dy1, mask, filter) {
      if (read === draw && sx0 === dx0 && sy0 === dy0 && sx1 === dx1 && sy1 === dy1) {
        stats.skippedSelfBlits++;
        return;
      }
      stats.forwardedBlits++;
      originalBlit(sx0, sy0, sx1, sy1, dx0, dy0, dx1, dy1, mask, filter);
    };
    gl.kikoriFramebufferGuard = stats;
    if (typeof window !== 'undefined') window.kikoriRenderer = stats;
    return gl;
  }
  if (typeof module !== 'undefined' && module.exports) module.exports = protectContext;
  else root.KikoriProtectWebGL = protectContext;
})(typeof globalThis !== 'undefined' ? globalThis : this);
