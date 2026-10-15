// Workspace selection policy. The Odysseus-style renderer and its actions
// live in odysseus-chat.js; this wrapper keeps an intentionally empty chat
// visible after the user deletes the active session.
const rashinLoadWorkspace = loadWorkspace;
loadWorkspace = async function () {
  try {
    const data = await api('/api/workspace');
    const sessions = (data.sessions || []).filter((item) => !state.projectFilter || item.projectId === state.projectFilter);
    const keepEmpty = !!state.keepEmptySession;
    if (!keepEmpty && state.projectFilter) {
      if (!sessions.some((item) => item.id === state.currentSession)) state.currentSession = sessions[0]?.id || '';
    } else if (!keepEmpty && (!state.currentSession || !sessions.some((item) => item.id === state.currentSession))) {
      state.currentSession = data.defaultSessionId || sessions[0]?.id || '';
    }
    renderProjects(data.projects || []);
    renderSessions(sessions);
    if (data.models) renderModelSelect(data.models);
    if (state.currentSession) {
      await loadSessionMessages();
    } else {
      $('messages').innerHTML = '<div class="empty-chat odysseus-empty"><span class="empty-chat-mark">✦</span><strong>Selecciona una sesión o crea una nueva.</strong><small>Las sesiones y archivos permanecen en esta máquina.</small></div>';
      $('queue').innerHTML = '';
    }
    state.keepEmptySession = false;
  } catch (error) {
    // A daemon restart should not make the already-open chat unusable.
    rashinLoadWorkspace().catch(() => {});
  }
};
