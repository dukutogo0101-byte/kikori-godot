/* KIKORI — MIT. WebGL framebuffer presentation compatibility.
 * https://github.com/godotengine/godot/issues/122816
 * WebKit rejects Godot/Emscripten's final framebuffer blit even when rendering
 * is otherwise correct. Present full-screen, color-only, level-0 texture copies
 * through an exact texel-fetch shader. Save/restore every changed GL state.
 * All other copies use the original API. No error filtering is used.
 */
(function (root) {
  'use strict';
  function protectContext(gl) {
    if (!gl || typeof gl.blitFramebuffer !== 'function' || gl.kikoriFramebufferGuard) return gl;
    let read = gl.getParameter(gl.READ_FRAMEBUFFER_BINDING);
    let draw = gl.getParameter(gl.DRAW_FRAMEBUFFER_BINDING);
    const originalBind = gl.bindFramebuffer.bind(gl);
    const originalBlit = gl.blitFramebuffer.bind(gl);
    const stats = { skippedSelfBlits: 0, forwardedBlits: 0, shaderScreenCopies: 0 };
    let textureTargets = new WeakMap();
    let copy = null;
    if (typeof gl.bindTexture === 'function') {
      const bindTexture = gl.bindTexture.bind(gl);
      gl.bindTexture = function (target, texture) {
        bindTexture(target, texture);
        if (texture) textureTargets.set(texture, target);
      };
    }
    function resources() {
      if (copy) return copy;
      function compile(type, source) {
        const shader = gl.createShader(type);
        gl.shaderSource(shader, source);
        gl.compileShader(shader);
        if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
          const error = gl.getShaderInfoLog(shader);
          gl.deleteShader(shader);
          throw new Error(error);
        }
        return shader;
      }
      const vertex = compile(gl.VERTEX_SHADER, '#version 300 es\nvoid main(){vec2 p=vec2(float((gl_VertexID<<1)&2),float(gl_VertexID&2));gl_Position=vec4(p*2.0-1.0,0.0,1.0);}');
      const fragment = compile(gl.FRAGMENT_SHADER, '#version 300 es\nprecision highp float;uniform highp sampler2D u_source;out vec4 result;void main(){result=texelFetch(u_source,ivec2(gl_FragCoord.xy),0);}');
      const program = gl.createProgram();
      gl.attachShader(program, vertex);
      gl.attachShader(program, fragment);
      gl.linkProgram(program);
      gl.deleteShader(vertex);
      gl.deleteShader(fragment);
      if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
        const error = gl.getProgramInfoLog(program);
        gl.deleteProgram(program);
        throw new Error(error);
      }
      const sampler = gl.createSampler();
      gl.samplerParameteri(sampler, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
      gl.samplerParameteri(sampler, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
      gl.samplerParameteri(sampler, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.samplerParameteri(sampler, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      copy = { program, sampler, texture: gl.createTexture(), framebuffer: gl.createFramebuffer(), width: 0, height: 0, vao: gl.createVertexArray(), uniform: gl.getUniformLocation(program, 'u_source') };
      return copy;
    }
    function presentTexture(width, height) {
      if (typeof gl.createShader !== 'function') return false;
      if (gl.getParameter(gl.READ_BUFFER) !== gl.COLOR_ATTACHMENT0) return false;
      function attachment(parameter) {
        const previous = gl.getParameter(gl.DRAW_FRAMEBUFFER_BINDING);
        originalBind(gl.DRAW_FRAMEBUFFER, gl.getParameter(gl.READ_FRAMEBUFFER_BINDING));
        try { return gl.getFramebufferAttachmentParameter(gl.READ_FRAMEBUFFER, gl.COLOR_ATTACHMENT0, parameter); }
        finally { originalBind(gl.DRAW_FRAMEBUFFER, previous); }
      }
      const kind = attachment(gl.FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE);
      if (kind !== gl.TEXTURE) return false;
      const level = attachment(gl.FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL);
      if (level !== 0) return false;
      const texture = attachment(gl.FRAMEBUFFER_ATTACHMENT_OBJECT_NAME);
      if (textureTargets.get(texture) !== gl.TEXTURE_2D) return false;
      let renderer;
      try { renderer = resources(); } catch (error) { console.error('KIKORI presentation shader:', error); return false; }
      const program = gl.getParameter(gl.CURRENT_PROGRAM);
      const vao = gl.getParameter(gl.VERTEX_ARRAY_BINDING);
      const active = gl.getParameter(gl.ACTIVE_TEXTURE);
      const viewport = gl.getParameter(gl.VIEWPORT);
      const colorMask = gl.getParameter(gl.COLOR_WRITEMASK);
      const flags = [gl.BLEND, gl.DEPTH_TEST, gl.STENCIL_TEST, gl.CULL_FACE, gl.RASTERIZER_DISCARD, gl.SAMPLE_COVERAGE, gl.SAMPLE_ALPHA_TO_COVERAGE];
      const enabled = flags.map(flag => gl.isEnabled(flag));
      gl.activeTexture(gl.TEXTURE0);
      const previousTexture = gl.getParameter(gl.TEXTURE_BINDING_2D);
      const previousSampler = gl.getParameter(gl.SAMPLER_BINDING);
      const inspect = stats.shaderScreenCopies === 0 || stats.shaderScreenCopies === 30;
      let sourceSignature;
      function signature() {
        const bytes = new Uint8Array(width * height * 4);
        gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, bytes);
        let hash = 2166136261;
        for(let i=0;i<bytes.length;i+=64) hash=Math.imul(hash^bytes[i],16777619);
        return hash >>> 0;
      }
      if(inspect) sourceSignature=signature();
      try {
        flags.forEach(flag => gl.disable(flag));
        gl.colorMask(true, true, true, true);
        gl.viewport(0, 0, width, height);
        gl.useProgram(renderer.program);
        gl.bindVertexArray(renderer.vao);
        // A distinct copy prevents feedback if WebKit aliases its default
        // drawing image with Godot's read attachment during presentation.
        gl.bindTexture(gl.TEXTURE_2D, renderer.texture);
        if (renderer.width !== width || renderer.height !== height) {
          gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
          renderer.width = width;
          renderer.height = height;
        }
        const sourceFramebuffer = gl.getParameter(gl.READ_FRAMEBUFFER_BINDING);
        originalBind(gl.DRAW_FRAMEBUFFER, renderer.framebuffer);
        gl.framebufferTexture2D(gl.DRAW_FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, renderer.texture, 0);
        originalBlit(0, 0, width, height, 0, 0, width, height, gl.COLOR_BUFFER_BIT, gl.NEAREST);
        originalBind(gl.READ_FRAMEBUFFER, renderer.framebuffer);
        originalBind(gl.DRAW_FRAMEBUFFER, null);
        originalBlit(0, 0, width, height, 0, 0, width, height, gl.COLOR_BUFFER_BIT, gl.NEAREST);
        originalBind(gl.READ_FRAMEBUFFER, sourceFramebuffer);
        if(inspect){
          const sourceFramebuffer=gl.getParameter(gl.READ_FRAMEBUFFER_BINDING);
          originalBind(gl.READ_FRAMEBUFFER,null);
          const output=signature();
          originalBind(gl.READ_FRAMEBUFFER,sourceFramebuffer);
          stats.samples=stats.samples||[];
          stats.samples.push({frame:stats.shaderScreenCopies,source:sourceSignature,output,
            scissor:gl.isEnabled(gl.SCISSOR_TEST),box:Array.from(gl.getParameter(gl.SCISSOR_BOX)),
            drawBuffer:gl.getParameter(gl.DRAW_BUFFER0)});
        }
      } finally {
        gl.bindSampler(0, previousSampler);
        gl.bindTexture(gl.TEXTURE_2D, previousTexture);
        gl.activeTexture(active);
        gl.bindVertexArray(vao);
        gl.useProgram(program);
        gl.viewport(...viewport);
        gl.colorMask(...colorMask);
        flags.forEach((flag, index) => enabled[index] ? gl.enable(flag) : gl.disable(flag));
      }
      stats.shaderScreenCopies++;
      return true;
    }
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
      if (read && draw === null && mask === 0x4000 && filter === 0x2600 &&
          sx0 === 0 && sy0 === 0 && dx0 === 0 && dy0 === 0 &&
          sx1 === dx1 && sy1 === dy1 && dx1 === gl.drawingBufferWidth && dy1 === gl.drawingBufferHeight &&
          presentTexture(dx1, dy1)) return;
      stats.forwardedBlits++;
      originalBlit(sx0, sy0, sx1, sy1, dx0, dy0, dx1, dy1, mask, filter);
    };
    gl.kikoriFramebufferGuard = stats;
    if (gl.canvas && typeof gl.canvas.addEventListener === 'function') {
      gl.canvas.addEventListener('webglcontextrestored', () => {
        copy = null; read = null; draw = null; textureTargets = new WeakMap();
      });
    }
    if (typeof window !== 'undefined') window.kikoriRenderer = stats;
    return gl;
  }
  if (typeof module !== 'undefined' && module.exports) module.exports = protectContext;
  else root.KikoriProtectWebGL = protectContext;
})(typeof globalThis !== 'undefined' ? globalThis : this);
