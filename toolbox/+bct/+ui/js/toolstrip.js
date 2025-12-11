/**
 * BCT Toolstrip JavaScript
 * 
 * Manages the toolstrip UI component including button rendering,
 * state management, and MATLAB communication.
 */

(function() {
    'use strict';
    
    const COMPONENT_ID = 'Toolstrip';
    let state = new BCT.StateManager({
        buttons: [],
        groups: {},
        initialized: false
    });
    
    // DOM elements
    let groupsContainer;
    
    /**
     * Initialize the toolstrip component
     */
    function init() {
        groupsContainer = document.getElementById('toolstrip-groups');
        
        if (!groupsContainer) {
            console.error('Toolstrip groups container not found');
            return;
        }
        
        // Set up MATLAB message listener
        setupMessageListener();
        
        // Notify MATLAB that component is ready
        BCT.sendToMatlab(COMPONENT_ID, 'ready');
        
        console.log('Toolstrip initialized');
    }
    
    /**
     * Set up listener for messages from MATLAB
     */
    function setupMessageListener() {
        BCT.onMatlabMessage(function(data) {
            if (data.id !== COMPONENT_ID) return;
            
            const cmd = data.cmd;
            
            switch (cmd) {
                case 'configure':
                    configure(data.config);
                    break;
                    
                case 'addButton':
                    addButton(data.button);
                    break;
                    
                case 'removeButton':
                    removeButton(data.id);
                    break;
                    
                case 'enableButton':
                    setButtonEnabled(data.id, true);
                    break;
                    
                case 'disableButton':
                    setButtonEnabled(data.id, false);
                    break;
                    
                case 'setButtonState':
                    setButtonActive(data.id, data.active);
                    break;
                    
                case 'enable':
                    enableToolstrip();
                    break;
                    
                case 'disable':
                    disableToolstrip();
                    break;
                    
                default:
                    console.warn('Unknown command:', cmd);
            }
        });
    }
    
    /**
     * Configure the toolstrip with buttons and groups
     */
    function configure(config) {
        if (!config || !config.buttons) {
            console.error('Invalid configuration');
            return;
        }
        
        state.set({
            buttons: config.buttons,
            groups: config.groups || {},
            initialized: true
        });
        
        render();
    }
    
    /**
     * Render the entire toolstrip
     */
    function render() {
        const { buttons, groups } = state.get();
        
        if (!buttons || buttons.length === 0) {
            groupsContainer.innerHTML = '<div class="toolstrip-empty">No buttons configured</div>';
            return;
        }
        
        // Clear existing content
        groupsContainer.innerHTML = '';
        
        // Group buttons by their group property
        const buttonsByGroup = {};
        buttons.forEach(btn => {
            const group = btn.group || 'default';
            if (!buttonsByGroup[group]) {
                buttonsByGroup[group] = [];
            }
            buttonsByGroup[group].push(btn);
        });
        
        // Get sorted group names
        const groupNames = Object.keys(buttonsByGroup).sort((a, b) => {
            const orderA = groups[a]?.order || 999;
            const orderB = groups[b]?.order || 999;
            return orderA - orderB;
        });
        
        // Render each group
        groupNames.forEach(groupName => {
            const groupDiv = createButtonGroup(
                groupName,
                groups[groupName]?.label || groupName,
                buttonsByGroup[groupName]
            );
            groupsContainer.appendChild(groupDiv);
        });
    }
    
    /**
     * Create a button group element
     */
    function createButtonGroup(groupId, label, buttons) {
        const group = BCT.createElement('div', {
            classes: 'toolstrip-group',
            attrs: { 'data-group': groupId }
        });
        
        // Group label
        const labelDiv = BCT.createElement('div', {
            classes: 'toolstrip-group-label',
            text: label
        });
        group.appendChild(labelDiv);
        
        // Buttons container
        const buttonsDiv = BCT.createElement('div', {
            classes: 'toolstrip-buttons'
        });
        
        buttons.forEach(btn => {
            const buttonElem = createButton(btn);
            buttonsDiv.appendChild(buttonElem);
        });
        
        group.appendChild(buttonsDiv);
        
        return group;
    }
    
    /**
     * Create a button element
     */
    function createButton(buttonDef) {
        const btn = BCT.createElement('button', {
            classes: ['bct-btn', 'toolstrip-btn'],
            attrs: {
                'data-id': buttonDef.id,
                'title': buttonDef.label
            }
        });
        
        // Icon
        if (buttonDef.icon) {
            const icon = BCT.createElement('span', {
                classes: 'toolstrip-btn-icon',
                text: buttonDef.icon
            });
            btn.appendChild(icon);
        }
        
        // Label
        const label = BCT.createElement('span', {
            classes: 'toolstrip-btn-label',
            text: buttonDef.label
        });
        btn.appendChild(label);
        
        // Set initial state
        if (!buttonDef.enabled) {
            btn.disabled = true;
        }
        
        // Click handler
        btn.addEventListener('click', function() {
            handleButtonClick(buttonDef.id);
        });
        
        return btn;
    }
    
    /**
     * Handle button click
     */
    function handleButtonClick(buttonId) {
        console.log('Button clicked:', buttonId);
        
        // Visual feedback
        const btn = document.querySelector(`[data-id="${buttonId}"]`);
        if (btn) {
            btn.classList.add('clicked');
            setTimeout(() => btn.classList.remove('clicked'), 200);
        }
        
        // Send to MATLAB
        BCT.sendToMatlab(COMPONENT_ID, 'buttonClick', { id: buttonId });
    }
    
    /**
     * Add a new button dynamically
     */
    function addButton(buttonDef) {
        const buttons = state.get('buttons');
        buttons.push(buttonDef);
        state.set('buttons', buttons);
        render();
    }
    
    /**
     * Remove a button
     */
    function removeButton(buttonId) {
        const buttons = state.get('buttons');
        const filtered = buttons.filter(btn => btn.id !== buttonId);
        state.set('buttons', filtered);
        render();
    }
    
    /**
     * Enable/disable a specific button
     */
    function setButtonEnabled(buttonId, enabled) {
        const btn = document.querySelector(`[data-id="${buttonId}"]`);
        if (btn) {
            btn.disabled = !enabled;
        }
        
        // Update state
        const buttons = state.get('buttons');
        const button = buttons.find(b => b.id === buttonId);
        if (button) {
            button.enabled = enabled;
        }
    }
    
    /**
     * Set button active state (for toggle buttons)
     */
    function setButtonActive(buttonId, active) {
        const btn = document.querySelector(`[data-id="${buttonId}"]`);
        if (btn) {
            if (active) {
                btn.classList.add('active');
            } else {
                btn.classList.remove('active');
            }
        }
    }
    
    /**
     * Enable entire toolstrip
     */
    function enableToolstrip() {
        const buttons = document.querySelectorAll('.toolstrip-btn');
        buttons.forEach(btn => {
            const buttonId = btn.getAttribute('data-id');
            const buttonDef = state.get('buttons').find(b => b.id === buttonId);
            if (buttonDef && buttonDef.enabled) {
                btn.disabled = false;
            }
        });
    }
    
    /**
     * Disable entire toolstrip
     */
    function disableToolstrip() {
        const buttons = document.querySelectorAll('.toolstrip-btn');
        buttons.forEach(btn => {
            btn.disabled = true;
        });
    }
    
    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
    
})();
