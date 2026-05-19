// ─── TomCodex Academy — Google Tasks API Integration ─────────────
// Manages: Fetching and Syncing Tasks for the Todo List

(function() {
  let tasksToken = null;

  async function getTasksToken() {
    if (tasksToken) return tasksToken;
    const sessionToken = localStorage.getItem('gcalToken'); // Reuse same token if possible
    if (sessionToken) {
      tasksToken = sessionToken;
      return tasksToken;
    }
    return null;
  }

  // ─── TASKS API OPERATIONS ──────────────────────────

  window.fetchTaskLists = async function() {
    const token = await getTasksToken();
    if (!token) return [];
    try {
      const res = await fetch('https://tasks.googleapis.com/tasks/v1/users/@me/lists', {
        headers: { Authorization: `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        return data.items || [];
      }
      if (res.status === 401) {
        localStorage.removeItem('gcalToken');
        tasksToken = null;
      }
    } catch (e) { console.error('Tasks API error:', e); }
    return [];
  };

  window.fetchTasks = async function(listId = '@default') {
    const token = await getTasksToken();
    if (!token) return [];
    try {
      const res = await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${listId}/tasks?showCompleted=true&showHidden=true`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        return data.items || [];
      }
    } catch (e) { console.error('Fetch tasks error:', e); }
    return [];
  };

  window.createGoogleTask = async function(task, listId = '@default') {
    const token = await getTasksToken();
    if (!token) return null;
    try {
      const body = {
        title: task.text,
        notes: task.priority ? `Priority: ${task.priority}` : '',
        status: task.done ? 'completed' : 'needsAction'
      };
      // Google Tasks doesn't support arbitrary properties, so we store priority in notes
      if (task.date) {
        const date = new Date(task.date);
        body.due = date.toISOString();
      }

      const res = await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${listId}/tasks`, {
        method: 'POST',
        headers: { 
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(body)
      });
      if (res.ok) {
        const data = await res.json();
        return data.id;
      }
    } catch (e) { console.error('Create task error:', e); }
    return null;
  };

  window.updateGoogleTask = async function(taskId, task, listId = '@default') {
    const token = await getTasksToken();
    if (!token || !taskId) return;
    try {
      const body = {
        title: task.text,
        notes: task.priority ? `Priority: ${task.priority}` : '',
        status: task.done ? 'completed' : 'needsAction'
      };
      if (task.date) {
        const date = new Date(task.date);
        body.due = date.toISOString();
      }

      await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${listId}/tasks/${taskId}`, {
        method: 'PATCH',
        headers: { 
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(body)
      });
    } catch (e) { console.error('Update task error:', e); }
  };

  window.deleteGoogleTask = async function(taskId, listId = '@default') {
    const token = await getTasksToken();
    if (!token || !taskId) return;
    try {
      await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${listId}/tasks/${taskId}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` }
      });
    } catch (e) { console.error('Delete task error:', e); }
  };

})();
