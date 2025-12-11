/**
 * BCT Toolstrip Component
 * Horizontal toolbar with grouped action buttons
 */

(function() {
  'use strict';

  // ============================================================================
  // STATE & CONFIGURATION
  // ============================================================================

  const state = new BCT.StateManager({
    buttons: {},
    groups: {},
    activeButton: null,
    enabled: true
  });

  const defaultGroups = {
    data: {
      id: 'data',
      label: 'Data',
      buttons: [
        { id: 'loadMesh', label: 'Load Mesh', icon: 'upload', cmd: 'loadMesh' },
        { id: 'loadSignal', label: 'Load Signal', icon: 'upload', cmd: 'loadSignal' },
        { id: 'saveMesh', label: 'Save', icon: 'save', cmd: 'saveMesh' }
      ]
    },
    analysis: {
      id: 'analysis',
      label: 'Analysis',
      buttons: [
        { id: 'computeEigen', label: 'Eigenbasis', icon: 'play', cmd: 'computeEigenbasis' },
        { id: 'filterDesigner', label: 'Filter Designer', icon: 'settings', cmd: 'openFilterDesigner' },
        { id: 'analyze', label: 'Analyze', icon: 'play', cmd: 'runAnalysis' }
      ]
    },
    visualization: {
      id: 'visualization',
      label: 'Visualization',
      buttons: [
        { id: 'plotMesh', label: 'Plot Mesh', icon: 'play', cmd: 'plotMesh' },
        { id: 'plotSignal', label: 'Plot Signal', icon: 'play', cmd: 'plotSignal' },
        { id: 'plotSpectrum', label: 'Spectrum', icon: 'play', cmd: 'plotSpectrum' }
      ]
    }
  };

  // ============================================================================
  // UI RENDERING
  // ============================================================================

  /**
   * Create button element
   */
  function createButton(button, groupId) {
    const isActive = state.get('activeButton') === button.id;
    const isEnabled = state.get('buttons')[button.id]?.enabled !== false;

    const btn = BCT.createElement('button', {
      className: `btn-icon ${isActive ? 'active' : ''} ${!isEnabled ? 'opacity-50 cursor-not-allowed' : ''}`,
      id: `btn-${button.id}`,
      title: button.label,
      disabled: !isEnabled,
      dataset: { 
        buttonId: button.id, 
        groupId: groupId,
        cmd: button.cmd 
      },
      onClick: () => handleButtonClick(button.id, button.cmd)
    },
      BCT.createElement('div', { 
        className: 'w-5 h-5',
        innerHTML: BCT.getIcon(button.icon) 
      })
    );

    // Add label for non-icon buttons
    if (button.showLabel !== false) {
      const label = BCT.createElement('span', {
        className: 'text-xs hidden lg:inline ml-1'
      }, button.label);
      btn.appendChild(label);
      btn.classList.add('flex', 'items-center', 'gap-1', 'px-3');
    }

    return btn;
  }

  /**
   * Create button group
   */
  function createButtonGroup(group) {
    const container = BCT.createElement('div', {
      className: 'flex items-center gap-1 px-2 border-r border-light-border dark:border-dark-border',
      id: `group-${group.id}`,
      dataset: { groupId: group.id }
    });

    // Group label (optional)
    if (group.showLabel !== false) {
      const label = BCT.createElement('div', {
        className: 'text-xs font-medium text-light-text-tertiary dark:text-dark-text-tertiary mr-2 hidden xl:block'
      }, group.label);
      container.appendChild(label);
    }

    // Buttons
    const buttonsContainer = BCT.createElement('div', {
      className: 'flex items-center gap-1'
    });

    group.buttons.forEach(button => {
      buttonsContainer.appendChild(createButton(button, group.id));
    });

    container.appendChild(buttonsContainer);
    return container;
  }

  /**
   * Render all button groups
   */
  function render() {
    const container = BCT.$('#button-groups');
    if (!container) return;

    container.innerHTML = '';

    const groups = state.get('groups');
    Object.values(groups).forEach(group => {
      container.appendChild(createButtonGroup(group));
    });
  }

  // ============================================================================
  // EVENT HANDLERS
  // ============================================================================

  /**
   * Handle button click
   */
  function handleButtonClick(buttonId, cmd) {
    const button = findButton(buttonId);
    if (!button || state.get('buttons')[buttonId]?.enabled === false) {
      return;
    }

    // Update active state
    state.set('activeButton', buttonId);

    // Send command to MATLAB
    BCT.sendToMatlab(cmd, { 
      buttonId: buttonId,
      timestamp: Date.now()
    });

    // Visual feedback
    BCT.notify.show(`Executing: ${button.label}`, 'info', 2000);
  }

  /**
   * Handle theme toggle
   */
  function handleThemeToggle() {
    const isDark = BCT.toggleDarkMode();
    BCT.sendToMatlab('themeChanged', { theme: isDark ? 'dark' : 'light' });
  }

  /**
   * Handle settings click
   */
  function handleSettingsClick() {
    BCT.sendToMatlab('openSettings');
  }

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  /**
   * Initialize toolstrip with groups
   */
  function init(groups = defaultGroups) {
    // Initialize state
    const buttons = {};
    Object.values(groups).forEach(group => {
      group.buttons.forEach(button => {
        buttons[button.id] = { enabled: true };
      });
    });

    state.set({
      groups: groups,
      buttons: buttons
    });

    // Render
    render();

    // Setup event listeners
    BCT.on(BCT.$('#theme-toggle'), 'click', handleThemeToggle);
    BCT.on(BCT.$('#settings-btn'), 'click', handleSettingsClick);

    // Listen for state changes
    state.subscribe((newState, oldState) => {
      if (newState.groups !== oldState.groups || 
          newState.buttons !== oldState.buttons ||
          newState.activeButton !== oldState.activeButton) {
        render();
      }
    });

    // Notify MATLAB
    BCT.sendToMatlab('toolstripReady', { groups: Object.keys(groups) });
  }

  /**
   * Add button to group
   */
  function addButton(groupId, button) {
    const groups = state.get('groups');
    if (!groups[groupId]) {
      console.error(`Group ${groupId} not found`);
      return;
    }

    groups[groupId].buttons.push(button);
    const buttons = state.get('buttons');
    buttons[button.id] = { enabled: true };

    state.set({ groups, buttons });
  }

  /**
   * Remove button
   */
  function removeButton(buttonId) {
    const groups = state.get('groups');
    let found = false;

    Object.values(groups).forEach(group => {
      const index = group.buttons.findIndex(b => b.id === buttonId);
      if (index !== -1) {
        group.buttons.splice(index, 1);
        found = true;
      }
    });

    if (found) {
      const buttons = state.get('buttons');
      delete buttons[buttonId];
      state.set({ groups, buttons });
    }
  }

  /**
   * Enable/disable button
   */
  function setButtonEnabled(buttonId, enabled) {
    const buttons = state.get('buttons');
    if (buttons[buttonId]) {
      buttons[buttonId].enabled = enabled;
      state.set({ buttons });
    }
  }

  /**
   * Add button group
   */
  function addGroup(group) {
    const groups = state.get('groups');
    groups[group.id] = group;
    
    const buttons = state.get('buttons');
    group.buttons.forEach(button => {
      buttons[button.id] = { enabled: true };
    });

    state.set({ groups, buttons });
  }

  /**
   * Remove button group
   */
  function removeGroup(groupId) {
    const groups = state.get('groups');
    const group = groups[groupId];
    
    if (group) {
      const buttons = state.get('buttons');
      group.buttons.forEach(button => {
        delete buttons[button.id];
      });
      
      delete groups[groupId];
      state.set({ groups, buttons });
    }
  }

  /**
   * Find button by ID
   */
  function findButton(buttonId) {
    const groups = state.get('groups');
    for (const group of Object.values(groups)) {
      const button = group.buttons.find(b => b.id === buttonId);
      if (button) return button;
    }
    return null;
  }

  /**
   * Handle message from MATLAB
   */
  function onMessage(data) {
    switch (data.cmd) {
      case 'addButton':
        addButton(data.groupId, data.button);
        break;
      case 'removeButton':
        removeButton(data.buttonId);
        break;
      case 'enableButton':
        setButtonEnabled(data.buttonId, true);
        break;
      case 'disableButton':
        setButtonEnabled(data.buttonId, false);
        break;
      case 'setActiveButton':
        state.set('activeButton', data.buttonId);
        break;
      case 'addGroup':
        addGroup(data.group);
        break;
      case 'removeGroup':
        removeGroup(data.groupId);
        break;
      case 'setTheme':
        BCT.setTheme(data.theme);
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
    document.addEventListener('DOMContentLoaded', () => init());
  } else {
    init();
  }

  // Export API
  window.BctToolstrip = {
    init,
    addButton,
    removeButton,
    setButtonEnabled,
    addGroup,
    removeGroup,
    getState: () => state.get()
  };

})();
