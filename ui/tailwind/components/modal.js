/**
 * BCT Modal Component
 * Reusable modal dialog system
 */

(function() {
  'use strict';

  // ============================================================================
  // STATE & CONFIGURATION
  // ============================================================================

  const state = new BCT.StateManager({
    isOpen: false,
    title: '',
    content: '',
    type: 'default', // default, confirm, alert, prompt
    onConfirm: null,
    onCancel: null,
    promptValue: ''
  });

  // ============================================================================
  // UI RENDERING
  // ============================================================================

  /**
   * Update modal content
   */
  function updateContent() {
    const title = state.get('title');
    const content = state.get('content');
    const type = state.get('type');

    BCT.$('#modal-title').textContent = title;
    
    const body = BCT.$('#modal-body');
    if (typeof content === 'string') {
      body.innerHTML = `<p class="text-light-text-secondary dark:text-dark-text-secondary">${content}</p>`;
    } else if (content instanceof Node) {
      body.innerHTML = '';
      body.appendChild(content);
    }

    // Handle prompt input
    if (type === 'prompt') {
      const input = BCT.createElement('input', {
        type: 'text',
        className: 'input w-full mt-3',
        id: 'prompt-input',
        value: state.get('promptValue'),
        placeholder: 'Enter value...',
        onInput: (e) => state.set('promptValue', e.target.value)
      });
      body.appendChild(input);
      // Focus input after render
      setTimeout(() => input.focus(), 100);
    }

    // Update footer buttons
    const footer = BCT.$('#modal-footer');
    const cancelBtn = BCT.$('#modal-cancel');
    const confirmBtn = BCT.$('#modal-confirm');

    switch (type) {
      case 'alert':
        cancelBtn.classList.add('hidden');
        confirmBtn.textContent = 'OK';
        break;
      case 'confirm':
        cancelBtn.classList.remove('hidden');
        cancelBtn.textContent = 'Cancel';
        confirmBtn.textContent = 'Confirm';
        break;
      case 'prompt':
        cancelBtn.classList.remove('hidden');
        cancelBtn.textContent = 'Cancel';
        confirmBtn.textContent = 'OK';
        break;
      default:
        cancelBtn.classList.remove('hidden');
        cancelBtn.textContent = 'Cancel';
        confirmBtn.textContent = 'Confirm';
    }
  }

  /**
   * Show modal
   */
  function show() {
    state.set('isOpen', true);
    const overlay = BCT.$('#modal-overlay');
    overlay.classList.remove('hidden');
    
    // Prevent body scroll
    document.body.style.overflow = 'hidden';
    
    updateContent();
  }

  /**
   * Hide modal
   */
  function hide() {
    state.set('isOpen', false);
    const overlay = BCT.$('#modal-overlay');
    overlay.classList.add('hidden');
    
    // Restore body scroll
    document.body.style.overflow = '';
    
    // Reset state
    state.set({
      title: '',
      content: '',
      type: 'default',
      onConfirm: null,
      onCancel: null,
      promptValue: ''
    });
  }

  // ============================================================================
  // EVENT HANDLERS
  // ============================================================================

  /**
   * Handle confirm button
   */
  function handleConfirm() {
    const type = state.get('type');
    const onConfirm = state.get('onConfirm');
    
    let result = true;
    if (type === 'prompt') {
      result = state.get('promptValue');
    }
    
    if (onConfirm) {
      onConfirm(result);
    }
    
    BCT.sendToMatlab('modalConfirm', { 
      type, 
      value: result 
    });
    
    hide();
  }

  /**
   * Handle cancel button
   */
  function handleCancel() {
    const onCancel = state.get('onCancel');
    
    if (onCancel) {
      onCancel();
    }
    
    BCT.sendToMatlab('modalCancel');
    
    hide();
  }

  /**
   * Handle close button
   */
  function handleClose() {
    handleCancel();
  }

  /**
   * Handle overlay click (close on backdrop)
   */
  function handleOverlayClick(e) {
    if (e.target.id === 'modal-overlay') {
      handleCancel();
    }
  }

  /**
   * Handle escape key
   */
  function handleEscape(e) {
    if (e.key === 'Escape' && state.get('isOpen')) {
      handleCancel();
    }
  }

  /**
   * Handle enter key (for prompt)
   */
  function handleEnter(e) {
    if (e.key === 'Enter' && state.get('type') === 'prompt' && state.get('isOpen')) {
      handleConfirm();
    }
  }

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  /**
   * Initialize modal
   */
  function init() {
    // Setup event listeners
    BCT.on(BCT.$('#modal-close'), 'click', handleClose);
    BCT.on(BCT.$('#modal-cancel'), 'click', handleCancel);
    BCT.on(BCT.$('#modal-confirm'), 'click', handleConfirm);
    BCT.on(BCT.$('#modal-overlay'), 'click', handleOverlayClick);
    BCT.on(document, 'keydown', handleEscape);
    BCT.on(document, 'keydown', handleEnter);

    // Notify MATLAB
    BCT.sendToMatlab('modalReady');
  }

  /**
   * Open modal with options
   */
  function open(options = {}) {
    state.set({
      title: options.title || 'Modal',
      content: options.content || '',
      type: options.type || 'default',
      onConfirm: options.onConfirm || null,
      onCancel: options.onCancel || null,
      promptValue: options.defaultValue || ''
    });
    
    show();
  }

  /**
   * Alert dialog (OK only)
   */
  function alert(title, message, onConfirm) {
    open({
      title: title,
      content: message,
      type: 'alert',
      onConfirm: onConfirm
    });
  }

  /**
   * Confirm dialog (OK/Cancel)
   */
  function confirm(title, message, onConfirm, onCancel) {
    open({
      title: title,
      content: message,
      type: 'confirm',
      onConfirm: onConfirm,
      onCancel: onCancel
    });
  }

  /**
   * Prompt dialog (input with OK/Cancel)
   */
  function prompt(title, message, defaultValue, onConfirm, onCancel) {
    open({
      title: title,
      content: message,
      type: 'prompt',
      defaultValue: defaultValue || '',
      onConfirm: onConfirm,
      onCancel: onCancel
    });
  }

  /**
   * Custom modal with HTML content
   */
  function custom(title, htmlContent, onConfirm, onCancel) {
    open({
      title: title,
      content: htmlContent,
      type: 'default',
      onConfirm: onConfirm,
      onCancel: onCancel
    });
  }

  /**
   * Close modal
   */
  function close() {
    hide();
  }

  /**
   * Handle message from MATLAB
   */
  function onMessage(data) {
    switch (data.cmd) {
      case 'open':
        open(data.options);
        break;
      case 'alert':
        alert(data.title, data.message);
        break;
      case 'confirm':
        confirm(data.title, data.message);
        break;
      case 'prompt':
        prompt(data.title, data.message, data.defaultValue);
        break;
      case 'close':
        close();
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
  window.BctModal = {
    init,
    open,
    alert,
    confirm,
    prompt,
    custom,
    close,
    getState: () => state.get()
  };

})();
