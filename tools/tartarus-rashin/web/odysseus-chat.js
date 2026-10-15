/*
 * Tartarus Rashin chat workspace.
 *
 * The interaction patterns and inline SVG icon treatment are adapted from
 * the local Odysseus frontend (AGPL-3.0), then kept deliberately small so
 * Rashin can retain its own local websocket/API and Tartarus theme.
 */
(function () {
  'use strict';

  const icon = {
    folder: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>',
    chat: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>',
    dots: '<svg viewBox="0 0 24 24" aria-hidden="true" fill="currentColor" stroke="none"><circle cx="12" cy="5" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="12" cy="19" r="2"/></svg>',
    chevron: '<svg viewBox="0 0 24 24" aria-hidden="true"><polyline points="6 9 12 15 18 9"/></svg>',
    edit: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/></svg>',
    archive: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="2" y="3" width="20" height="5" rx="1"/><path d="M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8M10 12h4"/></svg>',
    trash: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg>',
    copy: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>',
    plus: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>',
    paperclip: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.82-2.83l8.49-8.48"/></svg>',
    send: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 19V5M5 12l7-7 7 7"/></svg>',
    x: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M18 6 6 18M6 6l12 12"/></svg>',
    file: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>',
    image: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="M21 15l-5-5L5 21"/></svg>',
    spinner: '<span class="rashin-spinner" aria-hidden="true"></span>'
  };

  function makeButton(className, title, svg, label) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = className;
    button.title = title;
    button.setAttribute('aria-label', title);
    button.innerHTML = svg + (label ? '<span>' + label + '</span>' : '');
    return button;
  }

  function toast(message, kind) {
    let host = document.getElementById('rashin-toast-host');
    if (!host) {
      host = document.createElement('div');
      host.id = 'rashin-toast-host';
      document.body.appendChild(host);
    }
    const item = document.createElement('div');
    item.className = 'rashin-toast ' + (kind || '');
    item.textContent = message;
    host.appendChild(item);
    setTimeout(() => item.remove(), 3400);
  }

  function dialog(options) {
    return new Promise((resolve) => {
      const backdrop = document.createElement('div');
      backdrop.className = 'rashin-dialog-backdrop';
      const box = document.createElement('form');
      box.className = 'rashin-dialog';
      box.setAttribute('role', 'dialog');
      box.setAttribute('aria-modal', 'true');

      const heading = document.createElement('div');
      heading.className = 'rashin-dialog-heading';
      heading.innerHTML = '<div><p class="eyebrow">TARTARUS / RASHIN</p><h3>' + escapeHtml(options.title || 'Confirmar') + '</h3></div>';
      const close = makeButton('rashin-dialog-close', 'Cerrar', icon.x);
      heading.appendChild(close);
      box.appendChild(heading);

      const copy = document.createElement('p');
      copy.className = 'rashin-dialog-copy';
      copy.textContent = options.message || '';
      box.appendChild(copy);

      let input;
      if (options.input) {
        input = document.createElement('input');
        input.className = 'search-input rashin-dialog-input';
        input.value = options.value || '';
        input.placeholder = options.placeholder || '';
        input.required = true;
        box.appendChild(input);
      }

      const actions = document.createElement('div');
      actions.className = 'rashin-dialog-actions';
      const cancel = makeButton('secondary', 'Cancelar', icon.x, 'Cancelar');
      const accept = makeButton(options.danger ? 'rashin-danger-button' : 'primary', options.confirmLabel || 'Confirmar', icon.edit, options.confirmLabel || 'Confirmar');
      accept.type = 'submit';
      actions.append(cancel, accept);
      box.appendChild(actions);
      backdrop.appendChild(box);
      document.body.appendChild(backdrop);

      let finished = false;
      const finish = (value) => {
        if (finished) return;
        finished = true;
        document.removeEventListener('keydown', onKey);
        backdrop.remove();
        resolve(value);
      };
      const onKey = (event) => {
        if (event.key === 'Escape') finish(null);
      };
      close.onclick = () => finish(null);
      cancel.onclick = () => finish(null);
      backdrop.addEventListener('click', (event) => {
        if (event.target === backdrop) finish(null);
      });
      box.addEventListener('submit', (event) => {
        event.preventDefault();
        finish(options.input ? input.value.trim() : true);
      });
      document.addEventListener('keydown', onKey);
      requestAnimationFrame(() => (input || accept).focus());
    });
  }

  function setWelcome(message) {
    const host = $('messages');
    if (host) host.innerHTML = '<div class="empty-chat odysseus-empty"><span class="empty-chat-mark">✦</span><strong>' + escapeHtml(message || 'Escribe una pregunta para empezar.') + '</strong><small>Las sesiones y archivos permanecen en esta máquina.</small></div>';
    $('queue') && ($('queue').innerHTML = '');
    $('thinking-status') && $('thinking-status').classList.add('hidden');
    $('permission') && $('permission').classList.add('hidden');
  }

  function closeWorkspaceMenus(except) {
    document.querySelectorAll('.workspace-menu.open').forEach((menu) => {
      if (menu !== except) menu.classList.remove('open');
    });
  }

  function workspaceMenu(row, actions) {
    const toggle = makeButton('workspace-menu-toggle', 'Acciones', icon.dots);
    const menu = document.createElement('div');
    menu.className = 'workspace-menu';
    actions.forEach((action) => {
      const button = makeButton('workspace-menu-item ' + (action.danger ? 'danger' : ''), action.label, action.icon, action.label);
      button.removeAttribute('title');
      button.removeAttribute('aria-label');
      button.onclick = (event) => {
        event.stopPropagation();
        menu.classList.remove('open');
        action.run();
      };
      menu.appendChild(button);
    });
    toggle.onclick = (event) => {
      event.stopPropagation();
      const opening = !menu.classList.contains('open');
      closeWorkspaceMenus(menu);
      menu.classList.toggle('open', opening);
    };
    row.append(toggle, menu);
  }

  async function projectAction(action, id, project) {
    try {
      if (action === 'rename') {
        const name = await dialog({ title: 'Renombrar proyecto', message: 'El nombre se guarda solo en Rashin.', input: true, value: project.name, placeholder: 'Nombre del proyecto', confirmLabel: 'Guardar' });
        if (!name) return;
        await api('/api/projects/' + encodeURIComponent(id), { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name }) });
      } else if (action === 'delete') {
        const ok = await dialog({ title: 'Borrar proyecto', message: 'Se eliminarán sus sesiones, mensajes y adjuntos locales. Esta acción no se puede deshacer.', confirmLabel: 'Borrar proyecto', danger: true });
        if (!ok) return;
        if (state.projectFilter === id) {
          clearCurrentChat();
          state.projectFilter = '';
          state.keepEmptySession = true;
        }
        await api('/api/projects/' + encodeURIComponent(id), { method: 'DELETE' });
      }
      await loadWorkspace();
    } catch (error) {
      toast(error.message || 'No se pudo actualizar el proyecto', 'error');
    }
  }

  async function copySession(id) {
    try {
      const list = await api('/api/sessions/' + encodeURIComponent(id) + '/messages');
      const text = (list || []).map((item) => (item.role === 'user' ? 'Tú' : 'Rashin') + ':\n' + item.content).join('\n\n');
      await navigator.clipboard.writeText(text);
      toast('Chat copiado al portapapeles');
    } catch (error) {
      toast(error.message || 'No se pudo copiar el chat', 'error');
    }
  }

  function cancelRequestsForSession() {
    const requests = Array.isArray(state.requests) ? state.requests.slice() : [];
    requests.forEach((item) => {
      if (item.queueId) fetch('/api/queue/' + encodeURIComponent(item.queueId) + '/cancel', { method: 'POST' }).catch(() => {});
    });
    if (state.working) fetch('/api/ask/cancel', { method: 'POST' }).catch(() => {});
  }

  function clearCurrentChat() {
    cancelRequestsForSession();
    state.requests = [];
    state.activeRequest = null;
    state.working = false;
    setWelcome('Selecciona una sesión o crea una nueva.');
    if ($('working')) $('working').textContent = '';
  }

  async function sessionAction(action, id, session) {
    try {
      if (action === 'rename') {
        const title = await dialog({ title: 'Renombrar sesión', message: 'Ponle un nombre reconocible para encontrarla después.', input: true, value: session.title, placeholder: 'Nombre de la sesión', confirmLabel: 'Guardar' });
        if (!title) return;
        await api('/api/sessions/' + encodeURIComponent(id), { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ title }) });
      } else if (action === 'archive') {
        await api('/api/sessions/' + encodeURIComponent(id), { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ archived: true }) });
        if (id === state.currentSession) {
          state.currentSession = '';
          state.keepEmptySession = true;
          clearCurrentChat();
        }
      } else if (action === 'copy') {
        await copySession(id);
        return;
      } else if (action === 'delete') {
        const ok = await dialog({ title: 'Borrar sesión', message: 'Se eliminarán este chat, sus mensajes y sus adjuntos locales. Esta acción no se puede deshacer.', confirmLabel: 'Borrar sesión', danger: true });
        if (!ok) return;
        if (id === state.currentSession) {
          clearCurrentChat();
          state.currentSession = '';
          state.keepEmptySession = true;
        }
        await api('/api/sessions/' + encodeURIComponent(id), { method: 'DELETE' });
      }
      await loadWorkspace();
    } catch (error) {
      toast(error.message || 'No se pudo actualizar la sesión', 'error');
    }
  }

  window.renderProjects = function (items) {
    const host = $('projects-list');
    if (!host) return;
    host.textContent = '';
    if (!items.length) {
      host.innerHTML = '<span class="muted">Sin proyectos</span>';
      return;
    }
    items.forEach((project) => {
      const row = document.createElement('div');
      row.className = 'workspace-row project-row' + (state.projectFilter === project.id ? ' active' : '');
      const select = makeButton('workspace-select project-button', 'Abrir proyecto ' + project.name, icon.folder);
      const text = document.createElement('span');
      text.className = 'workspace-title';
      text.textContent = project.name;
      select.appendChild(text);
      select.onclick = () => {
        state.projectFilter = state.projectFilter === project.id ? '' : project.id;
        state.currentSession = '';
        state.keepEmptySession = false;
        loadWorkspace();
      };
      row.appendChild(select);
      const actions = [{ label: 'Renombrar', icon: icon.edit, run: () => projectAction('rename', project.id, project) }];
      if (project.name !== 'General') actions.push({ label: 'Borrar', icon: icon.trash, danger: true, run: () => projectAction('delete', project.id, project) });
      workspaceMenu(row, actions);
      host.appendChild(row);
    });
  };

  window.renderSessions = function (items) {
    const host = $('sessions-list');
    if (!host) return;
    host.textContent = '';
    if (!items.length) {
      host.innerHTML = '<span class="muted">Sin sesiones</span>';
      return;
    }
    items.forEach((session) => {
      const row = document.createElement('div');
      row.className = 'workspace-row session-row' + (state.currentSession === session.id ? ' active' : '');
      const select = makeButton('workspace-select session-button', 'Abrir sesión ' + session.title, icon.chat);
      const copy = document.createElement('span');
      copy.className = 'workspace-title-wrap';
      const title = document.createElement('strong');
      title.className = 'workspace-title';
      title.textContent = session.title;
      const status = document.createElement('small');
      status.textContent = session.status || 'idle';
      copy.append(title, status);
      select.appendChild(copy);
      select.onclick = () => {
        state.currentSession = session.id;
        state.keepEmptySession = false;
        loadSessionMessages();
        loadWorkspace();
      };
      row.appendChild(select);
      workspaceMenu(row, [
        { label: 'Renombrar', icon: icon.edit, run: () => sessionAction('rename', session.id, session) },
        { label: 'Copiar chat', icon: icon.copy, run: () => sessionAction('copy', session.id, session) },
        { label: 'Archivar', icon: icon.archive, run: () => sessionAction('archive', session.id, session) },
        { label: 'Borrar', icon: icon.trash, danger: true, run: () => sessionAction('delete', session.id, session) }
      ]);
      host.appendChild(row);
    });
  };

  async function createSessionOdysseus() {
    const title = await dialog({ title: 'Nueva sesión', message: 'Las conversaciones se guardan localmente en este espacio.', input: true, value: 'Nueva conversación', placeholder: 'Nombre de la sesión', confirmLabel: 'Crear sesión' });
    if (!title) return;
    try {
      const item = await api('/api/sessions', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ projectId: state.projectFilter, title }) });
      state.currentSession = item.id;
      state.keepEmptySession = false;
      await loadWorkspace();
    } catch (error) {
      toast(error.message || 'No se pudo crear la sesión', 'error');
    }
  }

  async function createProjectOdysseus() {
    const name = await dialog({ title: 'Nuevo proyecto', message: 'Agrupa conversaciones y adjuntos relacionados.', input: true, value: 'Nuevo proyecto', placeholder: 'Nombre del proyecto', confirmLabel: 'Crear proyecto' });
    if (!name) return;
    try {
      const item = await api('/api/projects', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name }) });
      state.projectFilter = item.id;
      state.currentSession = '';
      state.keepEmptySession = true;
      await loadWorkspace();
    } catch (error) {
      toast(error.message || 'No se pudo crear el proyecto', 'error');
    }
  }

  async function ensureCurrentSession() {
    if (state.currentSession) return;
    const item = await api('/api/sessions', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ projectId: state.projectFilter, title: 'Nueva conversación' }) });
    state.currentSession = item.id;
    state.keepEmptySession = false;
    await loadWorkspace();
  }

  window.renderAttachments = function () {
    const host = $('attachment-preview');
    if (!host) return;
    host.textContent = '';
    state.pendingFiles.forEach((file, index) => {
      const item = document.createElement('div');
      item.className = 'attachment-card';
      const visual = document.createElement('span');
      visual.className = 'attachment-visual';
      visual.innerHTML = file.type && file.type.startsWith('image/') ? icon.image : icon.file;
      const info = document.createElement('span');
      info.className = 'attachment-info';
      const name = document.createElement('strong');
      name.textContent = file.name;
      const size = document.createElement('small');
      size.textContent = Math.max(1, Math.round(file.size / 1024)) + ' KB';
      info.append(name, size);
      const remove = makeButton('attachment-remove', 'Quitar ' + file.name, icon.x);
      remove.onclick = () => {
        state.pendingFiles.splice(index, 1);
        renderAttachments();
      };
      item.append(visual, info, remove);
      host.appendChild(item);
    });
  };

  window.clearAttachments = function () {
    state.pendingFiles = [];
    if ($('attachments')) $('attachments').value = '';
    renderAttachments();
  };

  function addFiles(files) {
    const incoming = Array.from(files || []).filter((file) => file && file.name);
    const known = new Set(state.pendingFiles.map((file) => file.name + ':' + file.size + ':' + file.lastModified));
    incoming.forEach((file) => {
      const key = file.name + ':' + file.size + ':' + file.lastModified;
      if (!known.has(key)) {
        state.pendingFiles.push(file);
        known.add(key);
      }
    });
    renderAttachments();
  }

  window.renderQueueItem = function (event) {
    const host = $('queue');
    if (!host || !event.queueId) return;
    let node = document.querySelector('[data-queue-id="' + CSS.escape(event.queueId) + '"]');
    if (!node) {
      node = document.createElement('div');
      node.className = 'queue-item odysseus-queue-item';
      node.dataset.queueId = event.queueId;
      const label = document.createElement('div');
      label.className = 'queue-copy';
      const title = document.createElement('strong');
      title.className = 'queue-title';
      const detail = document.createElement('span');
      detail.className = 'queue-detail';
      label.append(title, detail);
      const stateLabel = document.createElement('span');
      stateLabel.className = 'queue-state';
      const cancel = makeButton('queue-cancel', 'Cancelar consulta', icon.x);
      cancel.onclick = async () => {
        try {
          const interrupted = node.dataset.status === 'interrupted';
          if (interrupted) {
            await api('/api/queue/' + encodeURIComponent(event.queueId) + '/resume', { method: 'POST' });
            const socket = await rashinWaitForSocket();
            socket.send(JSON.stringify({ type: 'resume', queueId: event.queueId, clientId: state.clientId }));
            renderQueueItem({ ...event, status: 'queued', stateText: 'Reanudando…' });
            toast('Consulta reanudada');
          } else {
            await api('/api/queue/' + encodeURIComponent(event.queueId) + '/cancel', { method: 'POST' });
            removeQueueItem(event.queueId);
            toast('Consulta cancelada');
          }
        } catch (error) {
          toast(error.message || (node.dataset.status === 'interrupted' ? 'No se pudo reanudar' : 'No se pudo cancelar'), 'error');
        }
      };
      const spinner = document.createElement('span');
      spinner.className = 'rashin-spinner';
      spinner.setAttribute('aria-hidden', 'true');
      node.append(spinner, label, stateLabel, cancel);
      host.appendChild(node);
    }
    node.dataset.status = event.status || node.dataset.status || 'queued';
    const item = state.requests.find((request) => request.queueId === event.queueId);
    const prompt = (item && item.user ? item.user.querySelector('.body')?.textContent : '') || event.prompt || '';
    node.querySelector('.queue-title').textContent = prompt || 'Consulta en curso';
    node.querySelector('.queue-detail').textContent = event.position ? 'posición ' + event.position : 'sesión actual';
    const interrupted = node.dataset.status === 'interrupted';
    const running = node.dataset.status === 'running';
    node.querySelector('.queue-state').textContent = event.stateText || event.text || (interrupted ? 'Interrumpida · pulsa para reanudar' : running ? 'Trabajando…' : 'En cola');
    const action = node.querySelector('.queue-cancel');
    if (action) {
      action.classList.toggle('resume', interrupted);
      action.innerHTML = interrupted ? icon.send : icon.x;
      action.title = interrupted ? 'Reanudar consulta' : 'Cancelar consulta';
      action.setAttribute('aria-label', action.title);
    }
  };

  window.removeQueueItem = function (id) {
    if (!id) return;
    document.querySelector('[data-queue-id="' + CSS.escape(id) + '"]')?.remove();
  };

  const originalHandleChatEvent = window.handleChatEvent;
  window.handleChatEvent = function (event) {
    if (event.clientId && event.clientId !== state.clientId) return;
    if (event.type === 'connected' && event.queueId && !state.requests.some((request) => request.queueId === event.queueId)) {
      const response = addMessage('Rashin', '', 'assistant');
      const item = { queueId: event.queueId, user: null, response: response.item, body: response.body, answer: '', done: false };
      state.requests.push(item);
      state.activeRequest = item;
    }
    originalHandleChatEvent(event);
    if (event.type === 'queued') {
      renderQueueItem({ ...event, status: 'queued' });
      return;
    }
    if (event.type === 'connected') {
      renderQueueItem({ ...event, status: 'running', stateText: 'Trabajando…' });
      const node = document.querySelector('[data-queue-id="' + CSS.escape(event.queueId || '') + '"]');
      if (node) node.classList.add('running');
      return;
    }
    if (event.type === 'working' || event.type === 'tool' || event.type === 'permission') {
      if (event.queueId) renderQueueItem({ ...event, status: 'running', stateText: event.text || event.title || 'Trabajando…' });
      return;
    }
    if (event.type === 'done' || event.type === 'error' || event.type === 'cancelled') {
      removeQueueItem(event.queueId);
    }
  };

  window.sendChat = async function (text) {
    const question = String(text || '').trim();
    if (!question) return;
    try {
      await ensureCurrentSession();
      const item = pendingRequest(question);
      item.prompt = question;
      item.clientId = state.clientId;
      state.lastPrompt = question;
      state.lastMode = chatMode();
      setWorking(true);
      $('question').value = '';
      const socket = await rashinWaitForSocket();
      const ids = await uploadPending();
      clearAttachments();
      socket.send(JSON.stringify({ type: 'prompt', text: question, mode: state.lastMode, sessionId: state.currentSession, modelProfile: $('model-profile').value, fastMode: $('fast-mode').checked, attachmentIds: ids, clientId: state.clientId }));
    } catch (error) {
      const item = state.activeRequest;
      if (item) {
        item.done = true;
        item.response.classList.add('error');
        item.body.textContent = 'No se pudo enviar: ' + (error.message || error);
      }
      setWorking(false);
      toast(error.message || 'No se pudo enviar la consulta', 'error');
    }
  };

  function styleComposer() {
    const form = $('composer');
    if (!form) return;
    form.classList.add('odysseus-composer');
    const textarea = $('question');
    if (textarea) {
      textarea.rows = 4;
      textarea.placeholder = 'Escribe a Rashin… Puedes soltar archivos aquí o pegarlos desde el portapapeles.';
      textarea.addEventListener('keydown', (event) => {
        if (event.key === 'Enter' && !event.shiftKey) {
          event.preventDefault();
          form.requestSubmit();
        }
      });
      textarea.addEventListener('paste', (event) => {
        const files = event.clipboardData && event.clipboardData.files;
        if (files && files.length) addFiles(files);
      });
    }
    form.addEventListener('dragover', (event) => {
      event.preventDefault();
      form.classList.add('dragging');
    });
    form.addEventListener('dragleave', (event) => {
      if (event.target === form) form.classList.remove('dragging');
    });
    form.addEventListener('drop', (event) => {
      event.preventDefault();
      form.classList.remove('dragging');
      addFiles(event.dataTransfer && event.dataTransfer.files);
    });

    const attach = $('attach-menu-toggle');
    if (attach) {
      attach.innerHTML = icon.plus;
      attach.title = 'Añadir archivo, foto, vídeo o documento';
      attach.setAttribute('aria-label', attach.title);
    }
    const clear = $('clear-attachments');
    if (clear) {
      clear.innerHTML = icon.x + '<span>Limpiar</span>';
      clear.onclick = clearAttachments;
    }
    const submit = form.querySelector('button[type="submit"]');
    if (submit) {
      submit.innerHTML = icon.send + '<span>Enviar</span>';
      submit.title = 'Enviar mensaje';
    }
    const input = $('attachments');
    if (input) input.onchange = (event) => addFiles(event.target.files);
    renderAttachments();
  }

  document.addEventListener('click', (event) => {
    if (!event.target.closest('.workspace-row')) closeWorkspaceMenus();
  });

  const newSession = $('new-session');
  if (newSession) newSession.onclick = createSessionOdysseus;
  const newProject = $('new-project');
  if (newProject) newProject.onclick = createProjectOdysseus;
  styleComposer();
})();
