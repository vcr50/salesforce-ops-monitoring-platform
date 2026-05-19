// ─── TomCodex Academy — Calendar Scheduler & Google Calendar Sync ─────────────
// Manages: Local CRUD + Google Calendar API v3 integration

(function () {
  let gcalToken = null;        
  let calYear   = new Date().getFullYear();
  let calMonth  = new Date().getMonth();
  let editingEventId = null;   
  let fetchedGCalEvents = [];  
  window.fetchedGCalEvents = fetchedGCalEvents; 

  // ─── LOCAL STORAGE HELPERS ─────────────────────────
  function getLocalEvents() {
    return (window.globalState && window.globalState.calendarEvents) ? window.globalState.calendarEvents : [];
  }
  function saveLocalEvents(events) {
    if (window.globalState) {
      window.globalState.calendarEvents = events;
      if (window.saveState) window.saveState();
    }
  }

  // ─── GOOGLE CALENDAR TOKEN ──────────────────────────
  let tokenValidated = false;

  async function getGCalToken() {
    if (gcalToken) return gcalToken;
    const sessionToken = localStorage.getItem('gcalToken');
    if (sessionToken) {
      gcalToken = sessionToken;
      return gcalToken;
    }
    // If no token, return null (don't auto-trigger popup on render!)
    return null;
  }

  // Validate token by making a lightweight API call
  async function validateToken(token) {
    try {
      const res = await fetch('https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=' + token);
      if (res.ok) {
        const data = await res.json();
        // Token is valid if it has more than 60 seconds of life remaining
        return data.expires_in > 60;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Try to refresh the token via re-auth if expired
  async function ensureValidToken() {
    const token = localStorage.getItem('gcalToken');
    if (!token) return null;
    
    if (!tokenValidated) {
      const isValid = await validateToken(token);
      if (!isValid) {
        console.warn('GCal token expired, clearing...');
        gcalToken = null;
        localStorage.removeItem('gcalToken');
        window.lastSyncError = 'Token expired. Please reconnect Google Calendar.';
        updateConnectBarUI(false);
        if (window.showToast) window.showToast('⚠️ Google Calendar session expired. Please reconnect.', 'warning');
        return null;
      }
      tokenValidated = true;
      // Re-validate every 45 minutes
      setTimeout(() => { tokenValidated = false; }, 45 * 60 * 1000);
    }
    return token;
  }

  // ─── GOOGLE CALENDAR API ────────────────────────────
  async function fetchGCalEvents(startDate, endDate) {
    const token = await ensureValidToken();
    if (!token) {
      // Still try holidays (they use API key, not user token)
      return await fetchHolidaysOnly(startDate, endDate);
    }
    
    let allEvents = [];
    window.lastSyncError = null; // Reset on fresh sync
    
    try {
      // Fetch user's calendar list to get ALL their calendars (including holidays, work, etc)
      const urlCalendarList = `https://www.googleapis.com/calendar/v3/users/me/calendarList`;
      const res1 = await fetch(urlCalendarList, { headers: { Authorization: `Bearer ${token}` } });
      
      if (res1.ok) {
        const dataList = await res1.json();
        // Filter out explicitly hidden calendars, but keep anything selected
        const calendars = (dataList.items || []).filter(c => c.selected !== false);
        
        const fetchPromises = calendars.map(async (cal) => {
          try {
            const calId = encodeURIComponent(cal.id);
            const urlEvents = `https://www.googleapis.com/calendar/v3/calendars/${calId}/events?timeMin=${startDate.toISOString()}&timeMax=${endDate.toISOString()}&singleEvents=true&orderBy=startTime&maxResults=100`;
            const evRes = await fetch(urlEvents, { headers: { Authorization: `Bearer ${token}` } });
            
            if (evRes.ok) {
              const evData = await evRes.json();
              return (evData.items || []).map(ev => ({
                id:          ev.id,
                title:       ev.summary || '(no title)',
                date:        (ev.start?.date || ev.start?.dateTime || '').split('T')[0],
                time:        ev.start?.dateTime ? ev.start.dateTime.split('T')[1]?.slice(0,5) : '',
                description: ev.description || '',
                color:       cal.backgroundColor || '#4285F4', 
                fromGcal:    true,
                gcalId:      ev.id,
                calendarId:  cal.id,
                isReadOnly:  cal.accessRole === 'reader' || cal.accessRole === 'freeBusyReader'
              }));
            } else {
              if (evRes.status !== 404 && evRes.status !== 403) {
                 console.warn(`Failed to fetch events from ${cal.id}: ${evRes.status}`);
              }
            }
          } catch(e) { console.warn('Error fetching calendar', cal.summary, e); }
          return [];
        });

        const allCalendarsEvents = await Promise.all(fetchPromises);
        allCalendarsEvents.forEach(evArray => {
          allEvents = allEvents.concat(evArray);
        });
        
      } else if (res1.status === 401 || res1.status === 403) {
        gcalToken = null;
        tokenValidated = false;
        localStorage.removeItem('gcalToken');
        window.lastSyncError = `Auth Error (${res1.status}): Token expired or revoked. Please reconnect.`;
        updateConnectBarUI(false);
        if (window.showToast) window.showToast('⚠️ Calendar session expired. Please reconnect.');
      } else {
        const errText = await res1.text();
        let errMsg = 'Unknown API error';
        try { errMsg = JSON.parse(errText).error?.message || errText; } catch(_) { errMsg = errText; }
        window.lastSyncError = `Calendar API Error (${res1.status}): ${errMsg}`;
      }
    } catch (e) { 
      console.warn('GCal fetch error', e); 
      window.lastSyncError = 'Network error fetching calendar: ' + e.message;
    }

    return allEvents;
  }

  // Fallback for public holidays when offline/logged out
  async function fetchHolidaysOnly(startDate, endDate) {
    try {
      const apiKey = 'AIzaSyA8DHO1aGSe-8-L9x77-rtAeFgw5xYyzqc';
      const holidayId = encodeURIComponent('en.indian#holiday@group.v.calendar.google.com');
      const urlHolidays = `https://www.googleapis.com/calendar/v3/calendars/${holidayId}/events?key=${apiKey}&timeMin=${startDate.toISOString()}&timeMax=${endDate.toISOString()}&singleEvents=true&orderBy=startTime&maxResults=50`;
      
      const res2 = await fetch(urlHolidays);
      if (res2.ok) {
        const data2 = await res2.json();
        return (data2.items || []).map(ev => ({
          id:          ev.id,
          title:       ev.summary || 'Holiday',
          date:        (ev.start?.date || ev.start?.dateTime || '').split('T')[0],
          time:        '',
          description: ev.description || 'Indian Public Holiday',
          color:       '#34A853', 
          fromGcal:    true,
          gcalId:      ev.id,
          calendarId:  holidayId,
          isReadOnly:  true       
        }));
      } else {
        const errData = await res2.text();
        let errorMsg = 'Unknown error';
        try { errorMsg = JSON.parse(errData).error?.message || errData; } catch(_) { errorMsg = errData.substring(0, 200); }
        window.lastHolidayError = `Holiday API Error (${res2.status}): ${errorMsg}`;
        return [];
      }
    } catch (e) { 
      window.lastHolidayError = 'Holiday fetch network error: ' + e.message;
      return [];
    }
  }

  window.checkSyncStatus = function() {
    let report = '';
    
    // 1. Token status
    const token = localStorage.getItem('gcalToken');
    if (!token) {
      report += '🔴 GOOGLE ACCOUNT: Not connected\n';
      report += '   → Click "Connect Google Calendar" to sign in.\n\n';
    } else {
      report += '🟢 GOOGLE ACCOUNT: Connected (token present)\n\n';
    }

    // 2. Calendar sync status
    if (window.lastSyncError) {
      report += '🔴 CALENDAR SYNC ERROR:\n';
      report += '   ' + window.lastSyncError + '\n\n';
    } else if (token) {
      const pCount = (window.fetchedGCalEvents || []).filter(e => !e.isReadOnly).length;
      report += `🟢 CALENDAR: ${pCount} events synced successfully\n\n`;
    }

    // 3. Holiday status
    if (window.lastHolidayError) {
      report += '🟡 HOLIDAY SYNC ERROR:\n';
      report += '   ' + window.lastHolidayError + '\n';
      report += '   (Holidays use a public API key — this may be rate limited)\n\n';
    } else {
      const hCount = (window.fetchedGCalEvents || []).filter(e => e.isReadOnly).length;
      report += `🟢 HOLIDAYS: ${hCount} Indian holidays loaded\n\n`;
    }

    // 4. Timestamp
    report += '🕐 Last checked: ' + new Date().toLocaleString('en-IN');
    
    alert(report);
  };

  function getEndDateStr(dateStr) {
    const d = new Date(dateStr);
    d.setDate(d.getDate() + 1); 
    return d.toISOString().split('T')[0];
  }

  function getEndTimeStr(timeStr) {
    if (!timeStr) return '';
    let [h, m] = timeStr.split(':').map(Number);
    h = (h + 1) % 24; 
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:00`;
  }

  async function createGCalEvent(ev) {
    const token = await ensureValidToken();
    if (!token) return null;
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    const body = {
      summary:     ev.title,
      description: ev.description || '',
      start: ev.time ? { dateTime: `${ev.date}T${ev.time}:00`, timeZone: tz } : { date: ev.date },
      end:   ev.time ? { dateTime: `${ev.date}T${getEndTimeStr(ev.time)}`, timeZone: tz } : { date: getEndDateStr(ev.date) },
    };
    try {
      const res  = await fetch('https://www.googleapis.com/calendar/v3/calendars/primary/events', {
        method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (res.ok) {
        const data = await res.json();
        return data.id || null;
      }
      return null;
    } catch (e) { console.error('GCal create error', e); return null; }
  }

  async function updateGCalEvent(gcalId, ev, calendarId = 'primary') {
    const token = await ensureValidToken();
    if (!token || !gcalId) return;
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    const body = {
      summary:     ev.title,
      description: ev.description || '',
      start: ev.time ? { dateTime: `${ev.date}T${ev.time}:00`, timeZone: tz } : { date: ev.date },
      end:   ev.time ? { dateTime: `${ev.date}T${getEndTimeStr(ev.time)}`, timeZone: tz } : { date: getEndDateStr(ev.date) },
    };
    try {
      const calIdEnc = encodeURIComponent(calendarId);
      await fetch(`https://www.googleapis.com/calendar/v3/calendars/${calIdEnc}/events/${gcalId}`, {
        method: 'PATCH', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
    } catch (e) { console.warn('GCal update error', e); }
  }

  async function deleteGCalEvent(gcalId, calendarId = 'primary') {
    const token = await ensureValidToken();
    if (!token || !gcalId) return;
    try {
      const calIdEnc = encodeURIComponent(calendarId);
      await fetch(`https://www.googleapis.com/calendar/v3/calendars/${calIdEnc}/events/${gcalId}`, {
        method: 'DELETE', headers: { Authorization: `Bearer ${token}` },
      });
    } catch (e) { console.warn('GCal delete error', e); }
  }

  // ─── AM/PM HELPERS ─────────────────────────────────
  function ampmTo24h(hour, min, ampm) {
    if (!hour) return '';
    let h = parseInt(hour);
    if (ampm === 'PM' && h !== 12) h += 12;
    if (ampm === 'AM' && h === 12) h = 0;
    return `${String(h).padStart(2,'0')}:${min || '00'}`;
  }

  function h24ToAmpm(timeStr) {
    if (!timeStr) return { h: '', m: '00', ampm: 'AM' };
    let [h, m] = timeStr.split(':').map(Number);
    const ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12 || 12;
    return { h: String(h), m: String(m).padStart(2,'0'), ampm };
  }

  function syncTimeDropdownsToHidden() {
    const h = document.getElementById('calEvHour')?.value;
    const m = document.getElementById('calEvMin')?.value || '00';
    const a = document.getElementById('calEvAmpm')?.value || 'AM';
    const hiddenTime = document.getElementById('calEvTime');
    if (hiddenTime) hiddenTime.value = h ? ampmTo24h(h, m, a) : '';
  }

  // ─── WEATHER WIDGET ────────────────────────────────
  async function loadWeather() {
    async function processCoords(lat, lon) {
      try {
        const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current_weather=true&hourly=relativehumidity_2m`;
        const res  = await fetch(url);
        const json = await res.json();
        const cw   = json.current_weather;
        const temp = Math.round(cw.temperature);
        const code = cw.weathercode;
        const icons = {0:'☀️',1:'🌤️',2:'⛅',3:'☁️',45:'🌫️',48:'🌫️',51:'🌦️',53:'🌦️',55:'🌧️',61:'🌧️',63:'🌧️',65:'🌧️',71:'🌨️',73:'🌨️',75:'🌨️',80:'🌦️',81:'🌧️',82:'🌩️',95:'⛈️',96:'⛈️',99:'⛈️'};
        const icon  = icons[code] || '🌡️';
        let city = 'Your Location';
        try {
          const geoRes = await fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lon}`);
          const geo    = await geoRes.json();
          city = geo.address?.city || geo.address?.town || geo.address?.village || geo.address?.state || 'Your Location';
        } catch(_) {}
        if (document.getElementById('calWeatherIcon')) document.getElementById('calWeatherIcon').textContent  = icon;
        if (document.getElementById('calWeatherTemp')) document.getElementById('calWeatherTemp').textContent  = `${temp}°C`;
        if (document.getElementById('calWeatherLoc')) document.getElementById('calWeatherLoc').textContent   = city;
      } catch(e) {}
    }

    function denyLocation() {
      if (document.getElementById('calWeatherLoc')) document.getElementById('calWeatherLoc').textContent = 'Location denied';
    }

    try {
      if (window.CapacitorGeolocation && window.Capacitor?.isNativePlatform?.()) {
        try { await window.CapacitorGeolocation.requestPermissions(); } catch(e){}
        const pos = await window.CapacitorGeolocation.getCurrentPosition({ timeout: 10000, enableHighAccuracy: true });
        await processCoords(pos.coords.latitude, pos.coords.longitude);
      } else if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(
          async (pos) => await processCoords(pos.coords.latitude, pos.coords.longitude),
          () => denyLocation()
        );
      }
    } catch (e) { denyLocation(); }
  }

  // ─── CALENDAR RENDER ───────────────────────────────
  function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate(); }
  function firstDay(y, m)    { return new Date(y, m, 1).getDay(); }
  
  function format12h(timeStr) {
    if (!timeStr) return '';
    let [h, m] = timeStr.split(':').map(Number);
    const ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12 || 12;
    return `${h}:${String(m).padStart(2, '0')} ${ampm}`;
  }
  window.format12h = format12h; 

  // Helper to update the connect bar visibility
  function updateConnectBarUI(isConnected) {
    const connectBar = document.querySelector('.gcal-connect-bar');
    const connectBtn = document.getElementById('gcalConnectBtn');
    const connectedDiv = document.getElementById('gcalConnected');
    
    if (isConnected) {
      // Hide the entire banner when connected
      if (connectBar) {
        connectBar.style.transition = 'opacity 0.4s ease, max-height 0.4s ease, margin 0.3s ease, padding 0.3s ease';
        connectBar.style.opacity = '0';
        connectBar.style.maxHeight = '0';
        connectBar.style.margin = '0';
        connectBar.style.padding = '0';
        connectBar.style.overflow = 'hidden';
        setTimeout(() => { connectBar.style.display = 'none'; }, 400);
      }
    } else {
      if (connectBar) {
        connectBar.style.display = 'flex';
        connectBar.style.opacity = '1';
        connectBar.style.maxHeight = '200px';
        connectBar.style.margin = '';
        connectBar.style.padding = '';
        connectBar.style.overflow = '';
      }
      if (connectBtn) connectBtn.style.display = '';
      if (connectedDiv) connectedDiv.style.display = 'none';
    }
  }

  async function renderCalendar() {
    const header    = document.getElementById('calMonthLabel');
    const grid      = document.getElementById('calGrid');
    const syncBadge = document.getElementById('calSyncBadge');
    if (!header || !grid) return;

    header.textContent = `${['January','February','March','April','May','June','July','August','September','October','November','December'][calMonth]} ${calYear}`;

    const startDate = new Date(calYear, calMonth, 1);
    const endDate   = new Date(calYear, calMonth + 1, 0, 23, 59, 59);
    
    const fetched = await fetchGCalEvents(startDate, endDate);
    if (fetched) {
      fetchedGCalEvents = fetched;
      window.fetchedGCalEvents = fetched; 
      const pCount = fetched.filter(e => !e.isReadOnly).length;
      const hCount = fetched.filter(e => e.isReadOnly).length;
      const hasToken = !!localStorage.getItem('gcalToken');
      
      if (syncBadge) {
        if (hasToken) {
          syncBadge.innerHTML = `🟢 ${pCount} <span style="opacity:0.6; font-size:10px;">Events</span> | 🇮🇳 ${hCount} <span style="opacity:0.6; font-size:10px;">Holidays</span>`;
          // Auto-hide the banner since sync is active
          updateConnectBarUI(true);
        } else {
          syncBadge.innerHTML = `🇮🇳 ${hCount} <span style="opacity:0.6; font-size:10px;">Holidays</span>`;
        }
      }
    } else {
      fetchedGCalEvents = [];
      window.fetchedGCalEvents = [];
      if (syncBadge) syncBadge.textContent = '⚪ Not synced';
    }

    const localEvents = getLocalEvents();
    const allEvents   = [...fetchedGCalEvents];
    localEvents.forEach(le => {
      if (!le.gcalId || !fetchedGCalEvents.find(ge => ge.gcalId === le.gcalId)) {
        allEvents.push(le);
      }
    });

    const eventsByDate = {};
    allEvents.forEach(ev => {
      if (!eventsByDate[ev.date]) eventsByDate[ev.date] = [];
      eventsByDate[ev.date].push(ev);
    });

    const todayStr = `${new Date().getFullYear()}-${String(new Date().getMonth()+1).padStart(2,'0')}-${String(new Date().getDate()).padStart(2,'0')}`;
    const days     = daysInMonth(calYear, calMonth);
    const startWd  = firstDay(calYear, calMonth);

    grid.innerHTML = ''; 
    ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].forEach(d => {
      const h = document.createElement('div'); h.className = 'cal-day-header'; h.textContent = d; grid.appendChild(h);
    });
    for (let i = 0; i < startWd; i++) {
       const empty = document.createElement('div'); empty.className = 'cal-cell empty'; grid.appendChild(empty);
    }
    for (let d = 1; d <= days; d++) {
      const dateStr = `${calYear}-${String(calMonth+1).padStart(2,'0')}-${String(d).padStart(2,'0')}`;
      const evs = eventsByDate[dateStr] || [];
      const cell = document.createElement('div'); cell.className = `cal-cell${dateStr === todayStr ? ' today' : ''}`;
      cell.onclick = () => window.openCalModal(dateStr);
      const dayNum = document.createElement('div'); dayNum.className = `cal-day-num${dateStr === todayStr ? ' today-num' : ''}`; dayNum.textContent = d; cell.appendChild(dayNum);
      if (evs.length > 0) {
        const wrap = document.createElement('div'); wrap.className = 'cal-events-wrap';
        evs.slice(0,3).forEach(ev => {
          const pill = document.createElement('div'); pill.className = 'cal-event-pill';
          const c = ev.color || '#1B96FF';
          pill.style.cssText = `background:${c}22; color:${c}; border-left:3px solid ${c};`;
          pill.onclick = (e) => { e.stopPropagation(); window.openEditCalEvent(ev.id||ev.gcalId, dateStr); };
          if (ev.time) { const t = document.createElement('span'); t.style.opacity = '0.6'; t.textContent = format12h(ev.time) + ' '; pill.appendChild(t); }
          pill.appendChild(document.createTextNode(ev.title));
          wrap.appendChild(pill);
        });
        if (evs.length > 3) {
          const m = document.createElement('div'); m.className = 'cal-more'; m.textContent = `+${evs.length-3} more`; wrap.appendChild(m);
        }
        cell.appendChild(wrap);
      }
      grid.appendChild(cell);
    }
    renderTodayAgenda(allEvents);
  }

  function renderTodayAgenda(allEvents) {
    const agendaTimeline = document.getElementById('todayAgendaTimeline');
    if (!agendaTimeline) return;
    const todayStr = `${new Date().getFullYear()}-${String(new Date().getMonth()+1).padStart(2,'0')}-${String(new Date().getDate()).padStart(2,'0')}`;
    if (document.getElementById('todayAgendaDate')) document.getElementById('todayAgendaDate').textContent = new Date().toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'});
    const todayEvs = allEvents.filter(ev => ev.date === todayStr).sort((a,b) => {
      if (!a.time && b.time) return -1;
      if (a.time && !b.time) return 1;
      return (a.time || '').localeCompare(b.time || '');
    });
    agendaTimeline.innerHTML = '';
    if (todayEvs.length === 0) {
      const e = document.createElement('div'); e.className = 'agenda-empty'; 
      e.innerHTML = `<div class=\"agenda-empty-icon\">📂</div><p>No events scheduled for today.</p><button class=\"btn-detail\" onclick=\"document.getElementById('calNewEventBtn').click()\">+ Schedule One</button>`;
      agendaTimeline.appendChild(e); return;
    }
    todayEvs.forEach(ev => {
      const item = document.createElement('div'); item.className = 'agenda-item'; item.onclick = () => window.openEditCalEvent(ev.id||ev.gcalId, ev.date);
      const meta = document.createElement('div'); meta.className = 'agenda-time-meta';
      const time = document.createElement('div'); time.className = 'agenda-time'; time.textContent = ev.time ? format12h(ev.time) : 'All Day'; meta.appendChild(time);
      const dot = document.createElement('div'); dot.className = 'agenda-dot'; dot.style.background = ev.color||'#1B96FF'; meta.appendChild(dot); item.appendChild(meta);
      const card = document.createElement('div'); card.className = 'agenda-content-card'; card.style.borderLeft = `4px solid ${ev.color||'#1B96FF'}`;
      const t = document.createElement('div'); t.className = 'agenda-event-title'; t.textContent = ev.title; card.appendChild(t);
      if (ev.description) { const d = document.createElement('div'); d.className = 'agenda-event-desc'; d.textContent = ev.description; card.appendChild(d); }
      if (ev.fromGcal) { const g = document.createElement('div'); g.className = 'agenda-gcal-tag'; g.textContent = ev.isReadOnly ? 'Public Holiday' : 'Google Sync'; card.appendChild(g); }
      item.appendChild(card); agendaTimeline.appendChild(item);
    });
  }

  window.handleManualSync = async function() {
    const btn = document.getElementById('calSyncBtn');
    if (btn) btn.classList.add('spinning');
    if (window.showToast) window.showToast('Syncing with Google... 🔄');
    
    // Reset validation flag to force a fresh token check
    tokenValidated = false;
    window.lastSyncError = null;
    window.lastHolidayError = null;
    
    await renderCalendar();
    if (btn) btn.classList.remove('spinning');
    
    if (window.lastSyncError) {
      if (window.showToast) window.showToast('⚠️ Sync had errors. Click ❔ for details.');
    } else {
      if (window.showToast) window.showToast('Sync Complete! ✅');
    }
  };

  window.openCalModal = (date) => {
    editingEventId = null;
    document.getElementById('calModalTitle').textContent = '+ Add Event';
    document.getElementById('calEvTitle').value = ''; document.getElementById('calEvDate').value = date; document.getElementById('calEvTime').value = '';
    document.getElementById('calEvHour').value = ''; document.getElementById('calEvMin').value = '00'; document.getElementById('calEvAmpm').value = 'AM';
    document.getElementById('calEvDesc').value = ''; document.getElementById('calEvColor').value = '#1B96FF';
    document.getElementById('calEvDeleteBtn').style.display = 'none'; document.getElementById('calEventModal').classList.add('open');
  };

  window.openEditCalEvent = (id, date) => {
    const ev = [...getLocalEvents(), ...fetchedGCalEvents].find(e => e.id===id||e.gcalId===id);
    if (!ev) { window.openCalModal(date); return; }
    editingEventId = id;
    document.getElementById('calModalTitle').textContent = ev.isReadOnly ? '📍 Holiday' : '✏️ Edit Event';
    document.getElementById('calEvTitle').value = ev.title||''; document.getElementById('calEvDate').value = ev.date||date;
    const t = h24ToAmpm(ev.time); document.getElementById('calEvHour').value=t.h; document.getElementById('calEvMin').value=t.m; document.getElementById('calEvAmpm').value=t.ampm;
    document.getElementById('calEvDesc').value = ev.description||''; document.getElementById('calEvColor').value = ev.color||'#1B96FF';
    const lock = ev.isReadOnly;
    document.getElementById('calEvTitle').disabled = lock; document.getElementById('calEvDate').disabled = lock; 
    ['calEvHour','calEvMin','calEvAmpm','calEvDesc','calEvColor'].forEach(x => document.getElementById(x).disabled = lock);
    document.getElementById('calEvDeleteBtn').style.display = lock ? 'none' : 'inline-flex'; document.getElementById('calEvSaveBtn').style.display = lock ? 'none' : 'inline-flex';
    document.getElementById('calEventModal').classList.add('open');
  };

  async function saveCalEvent() {
    const title = document.getElementById('calEvTitle').value.trim();
    if (!title) return;
    const ev = { title, date: document.getElementById('calEvDate').value, time: ampmTo24h(document.getElementById('calEvHour').value, document.getElementById('calEvMin').value, document.getElementById('calEvAmpm').value), description: document.getElementById('calEvDesc').value, color: document.getElementById('calEvColor').value };
    const local = getLocalEvents();
    if (editingEventId) {
      const idx = local.findIndex(e => e.id===editingEventId||e.gcalId===editingEventId);
      if (idx!==-1) { 
        local[idx] = {...local[idx], ...ev}; 
        saveLocalEvents(local); 
        const gEv = fetchedGCalEvents.find(e => e.gcalId===editingEventId||e.id===editingEventId);
        const calId = local[idx].calendarId || (gEv ? gEv.calendarId : 'primary');
        if (local[idx].gcalId) await updateGCalEvent(local[idx].gcalId, ev, calId); 
      }
    } else {
      const newEv = { id: 'cal_'+Date.now(), ...ev, calendarId: 'primary' }; 
      local.push(newEv); 
      saveLocalEvents(local);
      const gId = await createGCalEvent(ev); 
      if (gId) { newEv.gcalId = gId; saveLocalEvents(local); }
    }
    document.getElementById('calEventModal').classList.remove('open'); renderCalendar();
  }

  async function deleteCalEvent() {
    if (!editingEventId) return;
    const local = getLocalEvents(); const idx = local.findIndex(e => e.id===editingEventId||e.gcalId===editingEventId);
    const gEv = fetchedGCalEvents.find(e => e.gcalId===editingEventId||e.id===editingEventId);
    const gId = idx!==-1 ? local[idx].gcalId : (gEv?gEv.gcalId:null);
    const calId = idx!==-1 ? local[idx].calendarId : (gEv?gEv.calendarId:'primary');
    if (gId) await deleteGCalEvent(gId, calId);
    if (idx!==-1) { local.splice(idx,1); saveLocalEvents(local); }
    document.getElementById('calEventModal').classList.remove('open'); renderCalendar();
  }

  window.initCalendar = function() {
    if (window._calInitDone) return; window._calInitDone = true;
    document.getElementById('calPrevBtn')?.addEventListener('click', () => { calMonth--; if(calMonth<0){calMonth=11;calYear--;} renderCalendar(); });
    document.getElementById('calNextBtn')?.addEventListener('click', () => { calMonth++; if(calMonth>11){calMonth=0;calYear++;} renderCalendar(); });
    document.getElementById('calTodayBtn')?.addEventListener('click', () => { calYear=new Date().getFullYear(); calMonth=new Date().getMonth(); renderCalendar(); });
    document.getElementById('calModalClose')?.addEventListener('click', () => document.getElementById('calEventModal').classList.remove('open'));
    document.getElementById('calEvSaveBtn')?.addEventListener('click', saveCalEvent);
    document.getElementById('calEvDeleteBtn')?.addEventListener('click', deleteCalEvent);
    document.getElementById('calNewEventBtn')?.addEventListener('click', () => window.openCalModal(`${new Date().getFullYear()}-${String(new Date().getMonth()+1).padStart(2,'0')}-${String(new Date().getDate()).padStart(2,'0')}`));
    
    // ─── WIRE UP THE CONNECT BUTTON ─────────────────
    document.getElementById('gcalConnectBtn')?.addEventListener('click', async () => {
      const btn = document.getElementById('gcalConnectBtn');
      if (btn) {
        btn.disabled = true;
        btn.textContent = '⏳ Connecting...';
      }
      
      try {
        // Trigger the Google services connect flow only when the user opts in.
        if (window.fbConnectGoogleServices) {
          await window.fbConnectGoogleServices();
        } else if (window.fbSignIn) {
          await window.fbSignIn();
        }
        
        // Check if we got a token after sign-in
        const token = localStorage.getItem('gcalToken');
        if (token) {
          gcalToken = token;
          tokenValidated = false; // Force fresh validation
          if (window.showToast) window.showToast('🟢 Google Calendar connected! Syncing...');
          updateConnectBarUI(true);
          await renderCalendar();
          if (window.showToast) window.showToast('✅ Calendar synced successfully!');
        } else {
          if (btn) {
            btn.disabled = false;
            btn.textContent = '🔗 Connect Google Calendar';
          }
          if (window.showToast) window.showToast('Connection cancelled or failed. Try again.');
        }
      } catch (e) {
        console.error('GCal connect error:', e);
        if (btn) {
          btn.disabled = false;
          btn.textContent = '🔗 Connect Google Calendar';
        }
        if (window.showToast) window.showToast('❌ Connection failed: ' + e.message);
      }
    });
    
    loadWeather(); 
    renderCalendar();
    
    // ─── PERIODIC AUTO-REFRESH (every 5 minutes) ──────
    setInterval(() => {
      if (localStorage.getItem('gcalToken')) {
        renderCalendar();
      }
    }, 5 * 60 * 1000);
  };

  window.syncCalendarUI = function() {
    const saved = localStorage.getItem('gcalToken');
    if (saved) {
      gcalToken = saved;
      updateConnectBarUI(true);
      renderCalendar();
    } else {
      updateConnectBarUI(false);
    }
  };

  document.addEventListener('DOMContentLoaded', () => {
    window.initCalendar();
    window.syncCalendarUI();
  });
})();
