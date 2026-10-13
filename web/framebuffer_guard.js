/* KIKORI — MIT. WebKit framebuffer presentation compatibility.
 * https://github.com/godotengine/godot/issues/122816
 * Resolve final screen copies through a distinct color framebuffer. Shader-only
 * presentation can leave WebKit's default image unchanged; the two explicit
 * framebuffer copies preserve both the rendered image and compositing updates.
 * All other copies use the original API. Errors are never filtered.
 */
(function (root) {
  'use strict';
  function protectContext(gl) {
    if (!gl || typeof gl.blitFramebuffer !== 'function' || gl.kikoriFramebufferGuard) return gl;
    let read = gl.getParameter(gl.READ_FRAMEBUFFER_BINDING);
    let draw = gl.getParameter(gl.DRAW_FRAMEBUFFER_BINDING);
    const originalBind = gl.bindFramebuffer.bind(gl);
    const originalBlit = gl.blitFramebuffer.bind(gl);
    const stats = { skippedSelfBlits: 0, forwardedBlits: 0, intermediateScreenCopies: 0 };
    let copy = null;
    function present(width, height) {
      if (typeof gl.createFramebuffer !== 'function' ||
          gl.getParameter(gl.READ_BUFFER) !== gl.COLOR_ATTACHMENT0) return false;
      const source = gl.getParameter(gl.READ_FRAMEBUFFER_BINDING);
      const destination = gl.getParameter(gl.DRAW_FRAMEBUFFER_BINDING);
      const previousTexture = gl.getParameter(gl.TEXTURE_BINDING_2D);
      const previousUnpack = gl.getParameter(gl.PIXEL_UNPACK_BUFFER_BINDING);
      if (!copy) copy = { texture: gl.createTexture(), framebuffer: gl.createFramebuffer(), width: 0, height: 0 };
      try {
        gl.bindTexture(gl.TEXTURE_2D, copy.texture);
        if (previousUnpack) gl.bindBuffer(gl.PIXEL_UNPACK_BUFFER, null);
        if (copy.width !== width || copy.height !== height) {
          gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
          copy.width = width;
          copy.height = height;
        }
        originalBind(gl.DRAW_FRAMEBUFFER, copy.framebuffer);
        gl.framebufferTexture2D(gl.DRAW_FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, copy.texture, 0);
        originalBlit(0, 0, width, height, 0, 0, width, height, gl.COLOR_BUFFER_BIT, gl.NEAREST);
        originalBind(gl.READ_FRAMEBUFFER, copy.framebuffer);
        originalBind(gl.DRAW_FRAMEBUFFER, destination);
        originalBlit(0, 0, width, height, 0, 0, width, height, gl.COLOR_BUFFER_BIT, gl.NEAREST);
      } finally {
        originalBind(gl.READ_FRAMEBUFFER, source);
        originalBind(gl.DRAW_FRAMEBUFFER, destination);
        gl.bindTexture(gl.TEXTURE_2D, previousTexture);
        if (previousUnpack) gl.bindBuffer(gl.PIXEL_UNPACK_BUFFER, previousUnpack);
      }
      stats.intermediateScreenCopies++;
      return true;
    }
    gl.bindFramebuffer = function (target, framebuffer) {
      originalBind(target, framebuffer);
      if (target === gl.FRAMEBUFFER || target === gl.READ_FRAMEBUFFER) read = framebuffer;
      if (target === gl.FRAMEBUFFER || target === gl.DRAW_FRAMEBUFFER) draw = framebuffer;
    };
    gl.blitFramebuffer = function (sx0, sy0, sx1, sy1, dx0, dy0, dx1, dy1, mask, filter) {
      if (read === draw && sx0 === dx0 && sy0 === dy0 && sx1 === dx1 && sy1 === dy1 &&
          mask === gl.COLOR_BUFFER_BIT && filter === gl.NEAREST) {
        stats.skippedSelfBlits++;
        return;
      }
      if (read && draw === null && mask === gl.COLOR_BUFFER_BIT && filter === gl.NEAREST &&
          sx0 === 0 && sy0 === 0 && dx0 === 0 && dy0 === 0 &&
          sx1 === dx1 && sy1 === dy1 && dx1 === gl.drawingBufferWidth && dy1 === gl.drawingBufferHeight &&
          present(dx1, dy1)) return;
      stats.forwardedBlits++;
      originalBlit(sx0, sy0, sx1, sy1, dx0, dy0, dx1, dy1, mask, filter);
    };
    gl.kikoriFramebufferGuard = stats;
    if (gl.canvas && typeof gl.canvas.addEventListener === 'function') {
      gl.canvas.addEventListener('webglcontextrestored', () => { copy = null; read = null; draw = null; });
    }
    if (typeof window !== 'undefined') window.kikoriRenderer = stats;
    return gl;
  }
  if (typeof module !== 'undefined' && module.exports) module.exports = protectContext;
  else root.KikoriProtectWebGL = protectContext;
})(typeof globalThis !== 'undefined' ? globalThis : this);
