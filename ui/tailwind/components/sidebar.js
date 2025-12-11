/**
 * BCT Sidebar Component
 * Collapsible sidebar with sectioned controls
 */

(function() {
  'use strict';

  // ============================================================================
  // STATE & CONFIGURATION
  // ============================================================================

  const state = new BCT.StateManager({
    sections: {},
    collapsed: {}
  });

  // ============================================================================
  // UI RENDERING
  // ============================================================================

  /**
   * Create control element based on type
   */
  function createControl(control) {
    const container = BCT.createElement('div', {
      className: 'mb-3',
      id: `control-${control.id}`
    });

    // Label
    if (control.label) {
      const label = BCT.createElement('label', {
        className: 'block text-xs font-medium mb-1.5 text-light-text-secondary dark:text-dark-text-secondary',
        for: `input-${control.id}`
      }, control.label);
      container.appendChild(label);
    }

    // Control based on type
    let input;
    switch (control.type) {
      case 'slider':
        input = createSlider(control);
        break;
      case 'toggle':
        input = createToggle(control);
        break;
      case 'dropdown':
        input = createDropdown(control);
        break;
      case 'input':
        input = createInput(control);
        break;
      case 'button':
        input = createButton(control);
        break;
      default:
        console.warn('Unknown control type:', control.type);
        return container;
    }

    container.appendChild(input);

    // Description
    if (control.description) {
      const desc = BCT.createElement('div', {
        className: 'text-xs text-light-text-tertiary dark:text-dark-text-tertiary mt-1'
      }, control.description);
      container.appendChild(desc);
    }

    return container;
  }

  /**
   * Create slider control
   */
  function createSlider(control) {
    const wrapper = BCT.createElement('div', { className: 'space-y-1' });

    const valueDisplay = BCT.createElement('div', {
      className: 'flex justify-between text-xs',
      id: `value-${control.id}`
    },
      BCT.createElement('span', {}, control.min || 0),
      BCT.createElement('span', { className: 'font-medium' }, control.value || 0),
      BCT.createElement('span', {}, control.max || 100)
    );

    const slider = BCT.createElement('input', {
      type: 'range',
      className: 'slider w-full',
      id: `input-${control.id}`,
      min: control.min || 0,
      max: control.max || 100,
      step: control.step || 1,
      value: control.value || 0,
      onInput: (e) => handleControlChange(control.id, parseFloat(e.target.value))
    });

    wrapper.appendChild(valueDisplay);
    wrapper.appendChild(slider);
    return wrapper;
  }

  /**
   * Create toggle control
   */
  function createToggle(control) {
    const wrapper = BCT.createElement('div', { className: 'flex items-center gap-2' });

    const toggle = BCT.createElement('button', {
      className: `toggle ${control.value ? 'active' : ''}`,
      id: `input-${control.id}`,
      onClick: () => handleControlChange(control.id, !control.value)
    },
      BCT.createElement('span', { className: 'toggle-thumb' })
    );

    wrapper.appendChild(toggle);
    
    if (control.label) {
      const label = BCT.createElement('span', {
        className: 'text-sm'
      }, control.label);
      wrapper.appendChild(label);
    }

    return wrapper;
  }

  /**
   * Create dropdown control
   */
  function createDropdown(control) {
    const select = BCT.createElement('select', {
      className: 'select w-full',
      id: `input-${control.id}`,
      onChange: (e) => handleControlChange(control.id, e.target.value)
    });

    (control.options || []).forEach(option => {
      const opt = BCT.createElement('option', {
        value: option.value,
        selected: option.value === control.value
      }, option.label);
      select.appendChild(opt);
    });

    return select;
  }

  /**
   * Create input control
   */
  function createInput(control) {
    return BCT.createElement('input', {
      type: control.inputType || 'text',
      className: 'input w-full',
      id: `input-${control.id}`,
      value: control.value || '',
      placeholder: control.placeholder || '',
      onChange: (e) => handleControlChange(control.id, e.target.value)
    });
  }

  /**
   * Create button control
   */
  function createButton(control) {
    return BCT.createElement('button', {
      className: `btn ${control.variant === 'primary' ? 'btn-primary' : 'btn-secondary'} w-full`,
      id: `input-${control.id}`,
      onClick: () => handleButtonClick(control.id)
    }, control.label || 'Button');
  }

  /**
   * Create section
   */
  function createSection(section) {
    const isCollapsed = state.get('collapsed')[section.id];

    const card = BCT.createElement('div', {
      className: 'card',
      id: `section-${section.id}`,
      dataset: { sectionId: section.id }
    });

    // Header
    const header = BCT.createElement('button', {
      className: 'card-header w-full flex items-center justify-between cursor-pointer hover:bg-light-bg-tertiary dark:hover:bg-dark-bg-tertiary transition-colors',
      onClick: () => toggleSection(section.id)
    },
      BCT.createElement('span', {}, section.title),
      BCT.createElement('svg', {
        className: `w-4 h-4 transition-transform ${isCollapsed ? '' : 'rotate-180'}`,
        fill: 'none',
        stroke: 'currentColor',
        viewBox: '0 0 24 24',
        innerHTML: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>'
      })
    );

    card.appendChild(header);

    // Body
    if (!isCollapsed) {
      const body = BCT.createElement('div', {
        className: 'card-body space-y-3',
        id: `section-body-${section.id}`
      });

      (section.controls || []).forEach(control => {
        body.appendChild(createControl(control));
      });

      card.appendChild(body);
    }

    return card;
  }

  /**
   * Render all sections
   */
  function render() {
    const container = BCT.$('#sections-container');
    if (!container) return;

    container.innerHTML = '';

    const sections = state.get('sections');
    Object.values(sections).forEach(section => {
      container.appendChild(createSection(section));
    });
  }

  // ============================================================================
  // EVENT HANDLERS
  // ============================================================================

  /**
   * Handle control value change
   */
  function handleControlChange(controlId, value) {
    // Update slider value display
    const valueDisplay = BCT.$(`#value-${controlId} span:nth-child(2)`);
    if (valueDisplay) {
      valueDisplay.textContent = value;
    }

    // Update toggle appearance
    const toggle = BCT.$(`#input-${controlId}.toggle`);
    if (toggle) {
      if (value) {
        toggle.classList.add('active');
      } else {
        toggle.classList.remove('active');
      }
    }

    // Send to MATLAB
    BCT.sendToMatlab('controlChanged', {
      controlId: controlId,
      value: value,
      timestamp: Date.now()
    });
  }

  /**
   * Handle button click
   */
  function handleButtonClick(controlId) {
    BCT.sendToMatlab('buttonClicked', {
      controlId: controlId,
      timestamp: Date.now()
    });
  }

  /**
   * Toggle section collapse
   */
  function toggleSection(sectionId) {
    const collapsed = state.get('collapsed');
    collapsed[sectionId] = !collapsed[sectionId];
    state.set({ collapsed });
  }

  /**
   * Collapse all sections
   */
  function collapseAll() {
    const sections = state.get('sections');
    const collapsed = {};
    Object.keys(sections).forEach(id => {
      collapsed[id] = true;
    });
    state.set({ collapsed });
  }

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  /**
   * Initialize sidebar with sections
   */
  function init(sections = {}) {
    state.set({
      sections: sections,
      collapsed: {}
    });

    render();

    // Setup event listeners
    BCT.on(BCT.$('#collapse-all'), 'click', collapseAll);

    // Listen for state changes
    state.subscribe(() => render());

    // Notify MATLAB
    BCT.sendToMatlab('sidebarReady', { 
      sections: Object.keys(sections) 
    });
  }

  /**
   * Add section
   */
  function addSection(section) {
    const sections = state.get('sections');
    sections[section.id] = section;
    state.set({ sections });
  }

  /**
   * Remove section
   */
  function removeSection(sectionId) {
    const sections = state.get('sections');
    delete sections[sectionId];
    
    const collapsed = state.get('collapsed');
    delete collapsed[sectionId];
    
    state.set({ sections, collapsed });
  }

  /**
   * Update section
   */
  function updateSection(sectionId, updates) {
    const sections = state.get('sections');
    if (sections[sectionId]) {
      Object.assign(sections[sectionId], updates);
      state.set({ sections });
    }
  }

  /**
   * Update control value
   */
  function updateControl(sectionId, controlId, value) {
    const sections = state.get('sections');
    const section = sections[sectionId];
    
    if (section) {
      const control = section.controls.find(c => c.id === controlId);
      if (control) {
        control.value = value;
        state.set({ sections });
      }
    }
  }

  /**
   * Handle message from MATLAB
   */
  function onMessage(data) {
    switch (data.cmd) {
      case 'addSection':
        addSection(data.section);
        break;
      case 'removeSection':
        removeSection(data.sectionId);
        break;
      case 'updateSection':
        updateSection(data.sectionId, data.updates);
        break;
      case 'updateControl':
        updateControl(data.sectionId, data.controlId, data.value);
        break;
      case 'collapseSection':
        toggleSection(data.sectionId);
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
  window.BctSidebar = {
    init,
    addSection,
    removeSection,
    updateSection,
    updateControl,
    getState: () => state.get()
  };

})();
