/**
 * BCT Console JavaScript
 * 
 * Manages the console UI component including message display,
 * filtering, and command input.
 */

(function() {
    'use strict';
    
    const COMPONENT_ID = 'Console';
    let state = new BCT.StateManager({
        messages: [],
        maxMessages: 1000,
        autoScroll: true,
        showTimestamps: true,
        filterLevel: 0,
        initialized: false
    });
    
    // DOM elements
    let messagesContainer, inputField, filterSelect, btnClear, btnExport;
    
    /**
     * Initialize the console component
     */
    function init() {
        messagesContainer = document.getElementById('console-messages');
        inputField = document.getElementById('console-input');
        filterSelect = document.getElementById('filter-level');
        btnClear = document.getElementById('btn-clear');
        btnExport = document.getElementById('btn-export');
        
        if (!messagesContainer || !inputField) {
            console.error('Console elements not found');
            return;
        }
        
        // Set up event listeners
        inputField.addEventListener('keydown', handleInputKeydown);
        filterSelect.addEventListener('change', handleFilterChange);
        btnClear.addEventListener('click', clearMessages);
        btnExport.addEventListener('click', exportLog);
        
        // Set up MATLAB message listener
        setupMessageListener();
        
        // Notify MATLAB that component is ready
        BCT.sendToMatlab(COMPONENT_ID, 'ready');
        
        console.log('Console initialized');
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
                    
                case 'message':
                    addMessage(data.message);
                    break;
                    
                case 'clear':
                    clearMessages();
                    break;
                    
                case 'setFilter':
                    setFilter(data.level);
                    break;
                    
                case 'setMaxMessages':
                    state.set('maxMessages', data.max);
                    break;
                    
                case 'setAutoScroll':
                    state.set('autoScroll', data.enabled);
                    break;
                    
                case 'export':
                    exportToFile(data.filename);
                    break;
                    
                case 'enable':
                    enable();
                    break;
                    
                case 'disable':
                    disable();
                    break;
                    
                default:
                    console.warn('Unknown command:', cmd);
            }
        });
    }
    
    /**
     * Configure the console
     */
    function configure(config) {
        if (!config) {
            console.error('Invalid configuration');
            return;
        }
        
        state.set({
            maxMessages: config.maxMessages || 1000,
            autoScroll: config.autoScroll !== false,
            showTimestamps: config.showTimestamps !== false,
            filterLevel: config.filterLevel || 0,
            initialized: true
        });
        
        filterSelect.value = state.get('filterLevel');
    }
    
    /**
     * Add a message to the console
     */
    function addMessage(message) {
        const messages = state.get('messages');
        messages.push(message);
        
        // Enforce max messages limit
        const maxMessages = state.get('maxMessages');
        if (messages.length > maxMessages) {
            messages.shift();
        }
        
        state.set('messages', messages);
        
        // Render the message
        const messageElem = createMessageElement(message);
        messagesContainer.appendChild(messageElem);
        
        // Remove oldest if over limit
        const children = messagesContainer.children;
        if (children.length > maxMessages) {
            messagesContainer.removeChild(children[0]);
        }
        
        // Apply filter
        applyFilter();
        
        // Auto-scroll
        if (state.get('autoScroll')) {
            scrollToBottom();
        }
    }
    
    /**
     * Create a message element
     */
    function createMessageElement(message) {
        const elem = BCT.createElement('div', {
            classes: ['console-message', `console-message-${message.level}`],
            attrs: { 'data-id': message.id, 'data-level': getLevelValue(message.level) }
        });
        
        // Timestamp
        if (state.get('showTimestamps')) {
            const timestamp = BCT.createElement('span', {
                classes: 'console-timestamp',
                text: BCT.formatTime(message.timestamp * 1000)
            });
            elem.appendChild(timestamp);
        }
        
        // Level badge
        const badge = BCT.createElement('span', {
            classes: 'console-badge',
            text: getLevelBadge(message.level)
        });
        elem.appendChild(badge);
        
        // Message text
        const text = BCT.createElement('span', {
            classes: 'console-text',
            text: message.text
        });
        elem.appendChild(text);
        
        return elem;
    }
    
    /**
     * Get numeric level value
     */
    function getLevelValue(level) {
        const levels = {
            'info': 1,
            'success': 1,
            'warning': 2,
            'error': 3
        };
        return levels[level] || 0;
    }
    
    /**
     * Get level badge text
     */
    function getLevelBadge(level) {
        const badges = {
            'info': 'ℹ',
            'success': '✓',
            'warning': '⚠',
            'error': '✗'
        };
        return badges[level] || '·';
    }
    
    /**
     * Apply filter to messages
     */
    function applyFilter() {
        const filterLevel = state.get('filterLevel');
        const messages = messagesContainer.querySelectorAll('.console-message');
        
        messages.forEach(msg => {
            const msgLevel = parseInt(msg.getAttribute('data-level'));
            if (msgLevel >= filterLevel) {
                msg.style.display = '';
            } else {
                msg.style.display = 'none';
            }
        });
    }
    
    /**
     * Set filter level
     */
    function setFilter(level) {
        state.set('filterLevel', level);
        filterSelect.value = level;
        applyFilter();
    }
    
    /**
     * Handle filter dropdown change
     */
    function handleFilterChange() {
        setFilter(parseInt(filterSelect.value));
    }
    
    /**
     * Clear all messages
     */
    function clearMessages() {
        messagesContainer.innerHTML = '';
        state.set('messages', []);
    }
    
    /**
     * Handle input keydown (Enter to send command)
     */
    function handleInputKeydown(e) {
        if (e.key === 'Enter') {
            const input = inputField.value.trim();
            if (input) {
                sendCommand(input);
                inputField.value = '';
            }
        }
    }
    
    /**
     * Send command to MATLAB
     */
    function sendCommand(input) {
        BCT.sendToMatlab(COMPONENT_ID, 'command', { input: input });
        
        // Echo command in console
        addMessage({
            id: Date.now(),
            level: 'info',
            text: `> ${input}`,
            timestamp: Date.now() / 1000
        });
    }
    
    /**
     * Export log to file
     */
    function exportLog() {
        const messages = state.get('messages');
        
        if (messages.length === 0) {
            alert('No messages to export');
            return;
        }
        
        // Build export content
        const showTimestamps = state.get('showTimestamps');
        const lines = messages.map(msg => {
            let line = '';
            if (showTimestamps) {
                line += `[${BCT.formatTime(msg.timestamp * 1000)}] `;
            }
            line += `[${msg.level.toUpperCase()}] ${msg.text}`;
            return line;
        });
        
        const content = lines.join('\n');
        
        // Send to MATLAB for file writing
        BCT.sendToMatlab(COMPONENT_ID, 'exportData', {
            content: content,
            filename: 'console.txt'
        });
    }
    
    /**
     * Export to specific file
     */
    function exportToFile(filename) {
        const messages = state.get('messages');
        const showTimestamps = state.get('showTimestamps');
        
        const lines = messages.map(msg => {
            let line = '';
            if (showTimestamps) {
                line += `[${BCT.formatTime(msg.timestamp * 1000)}] `;
            }
            line += `[${msg.level.toUpperCase()}] ${msg.text}`;
            return line;
        });
        
        const content = lines.join('\n');
        
        BCT.sendToMatlab(COMPONENT_ID, 'exportData', {
            content: content,
            filename: filename
        });
    }
    
    /**
     * Scroll to bottom of messages
     */
    function scrollToBottom() {
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }
    
    /**
     * Enable console
     */
    function enable() {
        inputField.disabled = false;
        filterSelect.disabled = false;
        btnClear.disabled = false;
        btnExport.disabled = false;
    }
    
    /**
     * Disable console
     */
    function disable() {
        inputField.disabled = true;
        filterSelect.disabled = true;
        btnClear.disabled = true;
        btnExport.disabled = true;
    }
    
    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
    
})();
