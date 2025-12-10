/**
 * BCT Sidebar JavaScript
 * 
 * Manages the sidebar UI component including sections, collapsing,
 * and property controls.
 */

(function() {
    'use strict';
    
    const COMPONENT_ID = 'Sidebar';
    let state = new BCT.StateManager({
        sections: [],
        collapsed: false,
        width: 280,
        initialized: false
    });
    
    // DOM elements
    let sidebar, sidebarContent, sectionsContainer, toggleBtn;
    
    /**
     * Initialize the sidebar component
     */
    function init() {
        sidebar = document.getElementById('bct-sidebar');
        sidebarContent = document.getElementById('sidebar-content');
        sectionsContainer = document.getElementById('sidebar-sections');
        toggleBtn = document.getElementById('sidebar-toggle');
        
        if (!sidebar || !sectionsContainer) {
            console.error('Sidebar elements not found');
            return;
        }
        
        // Set up toggle button
        toggleBtn.addEventListener('click', toggleSidebar);
        
        // Set up MATLAB message listener
        setupMessageListener();
        
        // Notify MATLAB that component is ready
        BCT.sendToMatlab(COMPONENT_ID, 'ready');
        
        console.log('Sidebar initialized');
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
                    
                case 'addSection':
                    addSection(data.section);
                    break;
                    
                case 'removeSection':
                    removeSection(data.id);
                    break;
                    
                case 'updateSection':
                    updateSection(data.id, data.content);
                    break;
                    
                case 'setCollapsed':
                    setCollapsed(data.collapsed);
                    break;
                    
                case 'setWidth':
                    setWidth(data.width);
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
     * Configure the sidebar
     */
    function configure(config) {
        if (!config) {
            console.error('Invalid configuration');
            return;
        }
        
        state.set({
            sections: config.sections || [],
            collapsed: config.collapsed || false,
            width: config.width || 280,
            initialized: true
        });
        
        setWidth(state.get('width'));
        setCollapsed(state.get('collapsed'));
        render();
    }
    
    /**
     * Render all sections
     */
    function render() {
        const sections = state.get('sections');
        
        if (!sections || sections.length === 0) {
            sectionsContainer.innerHTML = '<div class="sidebar-empty">No sections</div>';
            return;
        }
        
        sectionsContainer.innerHTML = '';
        
        sections.forEach(section => {
            const sectionElem = createSection(section);
            sectionsContainer.appendChild(sectionElem);
        });
    }
    
    /**
     * Create a section element
     */
    function createSection(sectionDef) {
        const section = BCT.createElement('div', {
            classes: ['sidebar-section', sectionDef.collapsed ? 'collapsed' : ''],
            attrs: { 'data-id': sectionDef.id }
        });
        
        // Section header
        const header = BCT.createElement('div', {
            classes: 'sidebar-section-header'
        });
        
        const title = BCT.createElement('h4', {
            classes: 'sidebar-section-title',
            text: sectionDef.title
        });
        
        const toggleIcon = BCT.createElement('span', {
            classes: 'sidebar-section-toggle',
            text: '▼'
        });
        
        header.appendChild(title);
        header.appendChild(toggleIcon);
        header.addEventListener('click', function() {
            toggleSection(sectionDef.id);
        });
        
        // Section content
        const content = BCT.createElement('div', {
            classes: 'sidebar-section-content'
        });
        
        if (sectionDef.content) {
            content.appendChild(renderContent(sectionDef.content, sectionDef.id));
        }
        
        section.appendChild(header);
        section.appendChild(content);
        
        return section;
    }
    
    /**
     * Render section content based on type
     */
    function renderContent(content, sectionId) {
        const container = BCT.createElement('div', {
            classes: 'sidebar-content-container'
        });
        
        if (typeof content === 'object' && !Array.isArray(content)) {
            // Render as key-value pairs
            Object.keys(content).forEach(key => {
                const row = createPropertyRow(key, content[key], sectionId);
                container.appendChild(row);
            });
        } else if (typeof content === 'string') {
            // Render as text
            container.textContent = content;
        } else {
            container.textContent = JSON.stringify(content, null, 2);
        }
        
        return container;
    }
    
    /**
     * Create a property row with label and value/control
     */
    function createPropertyRow(key, value, sectionId) {
        const row = BCT.createElement('div', {
            classes: 'sidebar-property-row'
        });
        
        const label = BCT.createElement('label', {
            classes: 'sidebar-property-label',
            text: key
        });
        
        const valueElem = createValueControl(key, value, sectionId);
        
        row.appendChild(label);
        row.appendChild(valueElem);
        
        return row;
    }
    
    /**
     * Create appropriate control based on value type
     */
    function createValueControl(key, value, sectionId) {
        const valueType = typeof value;
        
        if (valueType === 'boolean') {
            // Checkbox
            const checkbox = BCT.createElement('input', {
                classes: 'sidebar-property-value',
                attrs: { type: 'checkbox' }
            });
            checkbox.checked = value;
            checkbox.addEventListener('change', function() {
                notifyPropertyChange(sectionId, key, this.checked);
            });
            return checkbox;
            
        } else if (valueType === 'number') {
            // Number input
            const input = BCT.createElement('input', {
                classes: 'sidebar-property-value',
                attrs: { type: 'number', value: value }
            });
            input.addEventListener('change', BCT.debounce(function() {
                notifyPropertyChange(sectionId, key, parseFloat(this.value));
            }, 500));
            return input;
            
        } else {
            // Text display/input
            const span = BCT.createElement('span', {
                classes: 'sidebar-property-value',
                text: String(value)
            });
            return span;
        }
    }
    
    /**
     * Toggle a section's collapsed state
     */
    function toggleSection(sectionId) {
        const sectionElem = document.querySelector(`[data-id="${sectionId}"]`);
        if (!sectionElem) return;
        
        const isCollapsed = sectionElem.classList.toggle('collapsed');
        
        // Update state
        const sections = state.get('sections');
        const section = sections.find(s => s.id === sectionId);
        if (section) {
            section.collapsed = isCollapsed;
        }
        
        // Notify MATLAB
        BCT.sendToMatlab(COMPONENT_ID, 'sectionToggle', {
            id: sectionId,
            collapsed: isCollapsed
        });
    }
    
    /**
     * Toggle sidebar collapsed state
     */
    function toggleSidebar() {
        const collapsed = !state.get('collapsed');
        setCollapsed(collapsed);
        
        BCT.sendToMatlab(COMPONENT_ID, 'toggleSidebar', {
            collapsed: collapsed
        });
    }
    
    /**
     * Set sidebar collapsed state
     */
    function setCollapsed(collapsed) {
        state.set('collapsed', collapsed);
        
        if (collapsed) {
            sidebar.classList.add('collapsed');
            toggleBtn.textContent = '▶';
        } else {
            sidebar.classList.remove('collapsed');
            toggleBtn.textContent = '◀';
        }
    }
    
    /**
     * Set sidebar width
     */
    function setWidth(width) {
        state.set('width', width);
        sidebar.style.width = width + 'px';
    }
    
    /**
     * Add a new section
     */
    function addSection(sectionDef) {
        const sections = state.get('sections');
        sections.push(sectionDef);
        state.set('sections', sections);
        render();
    }
    
    /**
     * Remove a section
     */
    function removeSection(sectionId) {
        const sections = state.get('sections');
        const filtered = sections.filter(s => s.id !== sectionId);
        state.set('sections', filtered);
        render();
    }
    
    /**
     * Update section content
     */
    function updateSection(sectionId, content) {
        const sections = state.get('sections');
        const section = sections.find(s => s.id === sectionId);
        
        if (section) {
            section.content = content;
            render();
        }
    }
    
    /**
     * Notify MATLAB of property change
     */
    function notifyPropertyChange(sectionId, property, value) {
        BCT.sendToMatlab(COMPONENT_ID, 'propertyChange', {
            section: sectionId,
            property: property,
            value: value
        });
    }
    
    /**
     * Enable sidebar
     */
    function enable() {
        sidebar.classList.remove('disabled');
    }
    
    /**
     * Disable sidebar
     */
    function disable() {
        sidebar.classList.add('disabled');
    }
    
    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
    
})();
