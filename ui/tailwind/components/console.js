/**
 * BCT Console Component
 * Terminal-style logging panel
 */

(function() {
  'use strict';

  // ============================================================================
  // STATE & CONFIGURATION
  // ============================================================================

  const state = new BCT.StateManager({
    messages: [],
    filter: 'all',
    maxMessages: 1000,
    commandHistory: [],
    historyIndex: -1
  });

  const levelColors = {
    info: 'text-bct-info',
    success: 'text-bct-success',
    warning: 'text-bct-warning',
    error: 'text-bct-error',
    default: 'text-dark-text-primary'
  };

  const levelSymbols = {
    info: 'ℹ',
    success: '✓',
    warning: '⚠',
    error: '✗',
    default: '·'
  };

  // ============================================================================
  // UI RENDERING
  // ============================================================================

  /**
   * Create message element
   */
  function createMessage(message) {
    const color = levelColors[message.level] || levelColors.default;
    const symbol = levelSymbols[message.level] || levelSymbols.default;

    return BCT.createElement('div', {
      className: `console-line ${message.level} ${color} flex gap-2`,
      dataset: { 
        level: message.level, 
        timestamp: message.timestamp 
      }
    },
      BCT.createElement('span', {
        className: 'text-dark-text-tertiary text-xs'
      }, BCT.formatTime(message.timestamp)),
      BCT.createElement('span', {
        className: 'font-bold'
      }, symbol),
      BCT.createElement('span', {
        className: 'flex-1 whitespace-pre-wrap break-words'
      }, message.text)
    );
  }

  /**
   * Render messages
   */
  function render() {
    const container = BCT.$('#messages');
    if (!container) return;

    const filter = state.get('filter');
    const messages = state.get('messages');

    // Filter messages
    const filtered = filter === 'all' 
      ? messages 
      : messages.filter(m => m.level === filter);

    // Clear and render
    container.innerHTML = '';
    
    if (filtered.length === 0) {
      const empty = BCT.createElement('div', {
        className: 'text-dark-text-tertiary text-center py-8'
      }, 'No messages to display');
      container.appendChild(empty);
    } else {
      filtered.forEach(message => {
        container.appendChild(createMessage(message));
      });
    }

    // Auto-scroll to bottom
    container.scrollTop = container.scrollHeight;
  }

  /**
   * Update filter buttons
   */
  function updateFilterButtons() {
    const filter = state.get('filter');
    BCT.$$('.filter-btn').forEach(btn => {
      if (btn.dataset.level === filter) {
        btn.classList.add('active', 'bg-dark-bg-tertiary');
      } else {
        btn.classList.remove('active', 'bg-dark-bg-tertiary');
      }
    });
  }

  // ============================================================================
  // EVENT HANDLERS
  // ============================================================================

  /**
   * Add message to console
   */
  function addMessage(level, text) {
    const messages = state.get('messages');
    const maxMessages = state.get('maxMessages');

    messages.push({
      level: level,
      text: text,
      timestamp: Date.now()
    });

    // Trim if exceeds max
    if (messages.length > maxMessages) {
      messages.shift();
    }

    state.set({ messages });
  }

  /**
   * Handle filter button click
   */
  function handleFilterClick(level) {
    state.set('filter', level);
    updateFilterButtons();
    render();
  }

  /**
   * Clear all messages
   */
  function clearMessages() {
    state.set({ messages: [] });
    BCT.sendToMatlab('consoleClear');
  }

  /**
   * Export log to file
   */
  function exportLog() {
    const messages = state.get('messages');
    const text = messages.map(m => 
      `[${BCT.formatTime(m.timestamp)}] ${m.level.toUpperCase()}: ${m.text}`
    ).join('\n');

    const blob = new Blob([text], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `bct-console-${Date.now()}.txt`;
    a.click();
    URL.revokeObjectURL(url);

    BCT.notify.show('Log exported', 'success', 2000);
  }

  /**
   * Handle command input
   */
  function handleCommand(command) {
    if (!command.trim()) return;

    // Add to history
    const history = state.get('commandHistory');
    history.push(command);
    state.set({ 
      commandHistory: history,
      historyIndex: -1
    });

    // Echo command
    addMessage('default', `> ${command}`);

    // Send to MATLAB
    BCT.sendToMatlab('executeCommand', {
      command: command,
      timestamp: Date.now()
    });

    // Clear input
    const input = BCT.$('#command-input');
    if (input) input.value = '';
  }

  /**
   * Handle command history navigation
   */
  function navigateHistory(direction) {
    const history = state.get('commandHistory');
    let index = state.get('historyIndex');

    if (direction === 'up') {
      index = Math.min(index + 1, history.length - 1);
    } else {
      index = Math.max(index - 1, -1);
    }

    state.set('historyIndex', index);

    const input = BCT.$('#command-input');
    if (input) {
      input.value = index >= 0 ? history[history.length - 1 - index] : '';
    }
  }

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  /**
   * Initialize console
   */
  function init() {
    // Setup event listeners
    BCT.on(BCT.$('#clear-btn'), 'click', clearMessages);
    BCT.on(BCT.$('#export-btn'), 'click', exportLog);
    BCT.on(BCT.$('#send-btn'), 'click', () => {
      const input = BCT.$('#command-input');
      if (input) handleCommand(input.value);
    });

    // Command input
    const input = BCT.$('#command-input');
    BCT.on(input, 'keydown', (e) => {
      if (e.key === 'Enter') {
        handleCommand(input.value);
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        navigateHistory('up');
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        navigateHistory('down');
      }
    });

    // Filter buttons
    BCT.$$('.filter-btn').forEach(btn => {
      BCT.on(btn, 'click', () => handleFilterClick(btn.dataset.level));
    });

    // Listen for state changes
    state.subscribe((newState, oldState) => {
      if (newState.messages !== oldState.messages) {
        render();
      }
    });

    // Initial render
    render();

    // Welcome message
    addMessage('info', 'BCT Console ready. Type commands below.');

    // Notify MATLAB
    BCT.sendToMatlab('consoleReady');
  }

  /**
   * Public logging methods
   */
  function log(message) {
    addMessage('default', message);
  }

  function info(message) {
    addMessage('info', message);
  }

  function success(message) {
    addMessage('success', message);
  }

  function warn(message) {
    addMessage('warning', message);
  }

  function error(message) {
    addMessage('error', message);
  }

  /**
   * Handle message from MATLAB
   */
  function onMessage(data) {
    switch (data.cmd) {
      case 'log':
        addMessage(data.level || 'default', data.message);
        break;
      case 'clear':
        clearMessages();
        break;
      case 'setFilter':
        handleFilterClick(data.level);
        break;
      default:
        console.warn('Unknown command:', data.cmd);
    }
  }

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  // Setup message handler
  BCT.onMatlabMessage(onMessage);

  // Initialize on load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // Export API
  window.BctConsole = {
    init,
    log,
    info,
    success,
    warn,
    error,
    clear: clearMessages,
    getState: () => state.get()
  };

})();
