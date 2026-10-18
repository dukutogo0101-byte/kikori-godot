/* Installation is offered by Chrome; a user gesture opens its native prompt.
 * Do not cancel beforeinstallprompt: Chrome may also show its own promotion.
 */
(() => {
  'use strict';
  let installPrompt = null, registration = null, reloading = false;
  const dialog = document.getElementById('app-dialog');
  const description = document.getElementById('app-description');
  const install = document.getElementById('app-install');
  const update = document.getElementById('app-update');
  const status = document.getElementById('app-status');
  const standalone = () => matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  const refresh = () => {
    install.hidden = !installPrompt || standalone();
    install.disabled = false;
    update.hidden = !registration?.waiting;
    description.textContent = standalone()
      ? 'KIKORIはアプリとして起動しています。進行状況はこの端末に保存されます。'
      : installPrompt
        ? 'ホーム画面にKIKORIを追加すると、アプリの画面で起動できます。'
        : /iPhone|iPad|iPod/.test(navigator.userAgent)
          ? 'Safariの共有メニューから「ホーム画面に追加」を選んでください。'
          : 'Chromeの右上のメニューから「ホーム画面に追加」→「インストール」を選んでください。案内が出ない場合は、Chromeでこのページを直接開き、少し遊んでからお試しください。';
    status.textContent = registration?.waiting
      ? '新しいバージョンがあります。保存して更新できます。'
      : navigator.onLine ? '更新は起動時に確認します。インストールの案内が出るタイミングはChromeが決めます。' : 'オフラインで起動中です。更新には通信が必要です。';
  };
  const open = () => {
    if (dialog.open) return;
    refresh();
    window.dispatchEvent(new CustomEvent('kikori-web-modal-change', {detail: true}));
    dialog.showModal();
  };
  window.KikoriInstall = Object.freeze({open});
  window.addEventListener('beforeinstallprompt', event => { installPrompt = event; if (dialog.open) refresh(); });
  window.addEventListener('appinstalled', () => { installPrompt = null; refresh(); });
  dialog.addEventListener('close', () => {
    window.dispatchEvent(new CustomEvent('kikori-web-modal-change', {detail: false}));
    document.getElementById('canvas').focus();
  });
  document.getElementById('app-close').addEventListener('click', () => dialog.close());
  install.addEventListener('click', async () => {
    if (!installPrompt) return;
    const prompt = installPrompt;
    installPrompt = null;
    install.disabled = true;
    try {
      await prompt.prompt();
      const choice = await prompt.userChoice;
      refresh();
      status.textContent = choice.outcome === 'accepted' ? 'インストールを受け付けました。ホーム画面をご確認ください。' : '今回は追加しませんでした。Chromeのメニューからいつでも追加できます。';
    } catch (_) { refresh(); status.textContent = 'Chromeのメニューから「ホーム画面に追加」をお試しください。'; }
  });
  update.addEventListener('click', () => {
    if (!registration?.waiting) return;
    update.disabled = true;
    status.textContent = '進行状況を保存しています…';
    // Godot acknowledges its synchronous localStorage write before activation.
    // With unavailable storage, stay in the current game instead of losing it.
    window.dispatchEvent(new Event('kikori-save-before-update'));
  });
  window.addEventListener('kikori-update-saved', event => {
    if (!event.detail) {
      update.disabled = false;
      status.textContent = '保存できないため更新を中止しました。この画面を閉じてプレイを続けられます。';
      return;
    }
    if (registration?.waiting) registration.waiting.postMessage({type: 'ACTIVATE_SAVED_UPDATE'});
  });
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      // First installation claims this page too. Only reload a requested update.
      if (update.disabled && !reloading) { reloading = true; location.reload(); }
    });
    window.addEventListener('load', async () => {
      try {
        registration = await navigator.serviceWorker.register('./sw.js', {scope: './', updateViaCache: 'none'});
        registration.addEventListener('updatefound', () => {
          const worker = registration.installing;
          worker?.addEventListener('statechange', () => { if (worker.state === 'installed' && dialog.open) refresh(); });
        });
        if (dialog.open) refresh();
        await registration.update();
      } catch (_) {
        // Storage restrictions/offline updates must never prevent the game loading.
        if (dialog.open) status.textContent = 'この環境ではオフライン保存を準備できません。通信中はそのまま遊べます。';
      }
    });
  }
})();
