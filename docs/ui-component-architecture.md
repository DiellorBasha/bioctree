# BCT UI Component System Architecture

## Overview

The `bct.ui` package provides a professional, reusable HTML/CSS/JS component framework for MATLAB App Designer applications. This architecture enables building modern, interactive user interfaces with clean separation between presentation (HTML/CSS/JS) and business logic (MATLAB).

## Core Principles

### 1. **Object-Oriented Component Model**
- All components inherit from `bct.ui.Component` abstract base class
- Each component is a self-contained unit with its own HTML, CSS, and JavaScript
- Components communicate with MATLAB through a standardized messaging protocol

### 2. **Bidirectional Communication**
- **MATLAB → JavaScript**: `obj.send(message)` sends data to the component's JavaScript
- **JavaScript → MATLAB**: `BCT.sendToMatlab(id, cmd, data)` triggers MATLAB callbacks
- Messages are routed through `DataChangedFcn` callbacks on HTML UI Components

### 3. **Separation of Concerns**
- **MATLAB Classes**: State management, data processing, business logic
- **HTML**: Structure and semantic markup
- **CSS**: Styling, animations, responsive design
- **JavaScript**: UI interactivity, DOM manipulation, rendering

## Component Lifecycle

```
1. Construction
   ├─ new Component(app, htmlComponent, id)
   ├─ Set up properties
   └─ Register DataChangedFcn callback

2. Initialization
   ├─ loadHTML(filename)
   ├─ JavaScript loads and initializes
   └─ JS sends 'ready' message to MATLAB

3. Configuration
   ├─ MATLAB receives 'ready'
   ├─ sendConfiguration()
   └─ JS receives and applies config

4. Operation
   ├─ User interacts with component
   ├─ JS sends messages to MATLAB
   ├─ MATLAB processes and updates state
   └─ MATLAB sends updates back to JS

5. Updates
   ├─ State changes in MATLAB
   ├─ Component methods called (e.g., addButton)
   └─ Messages sent to JS to update UI
```

## Message Protocol

### MATLAB → JavaScript Messages

All messages sent from MATLAB include:
```matlab
struct(
    'id', componentId,        % Component identifier
    'cmd', commandName,       % Command to execute
    'timestamp', posixtime,   % When message was sent
    ... additional fields ...
)
```

### JavaScript → MATLAB Messages

All messages sent from JavaScript include:
```javascript
{
    id: componentId,          // Component identifier
    cmd: commandName,         // Command being sent
    timestamp: Date.now(),    // When message was sent
    ... additional fields ...
}
```

## File Organization

### MATLAB Files (`+bct/+ui/*.m`)
- Define component classes
- Implement business logic
- Handle state management
- Route messages to app methods

### HTML Files (`+bct/+ui/html/*.html`)
- Define component structure
- Include CSS and JS references
- Provide semantic markup
- Set up container elements

### JavaScript Files (`+bct/+ui/js/*.js`)
- Implement UI interactivity
- Handle DOM manipulation
- Manage component rendering
- Communicate with MATLAB

### CSS Files (`+bct/+ui/css/*.css`)
- Define visual styling
- Implement animations
- Ensure responsive design
- Maintain design consistency

## Design System

### CSS Variables (`bct-common.css`)

The design system uses CSS custom properties for consistency:

```css
:root {
    /* Colors */
    --bct-primary: #0066cc;
    --bct-success: #28a745;
    --bct-warning: #ffc107;
    --bct-error: #dc3545;
    
    /* Spacing */
    --bct-spacing-sm: 8px;
    --bct-spacing-md: 16px;
    --bct-spacing-lg: 24px;
    
    /* Typography */
    --bct-font-family: system-ui, sans-serif;
    --bct-font-size-md: 14px;
    
    /* Effects */
    --bct-transition-normal: 250ms ease;
    --bct-border-radius-md: 6px;
}
```

### Utility Classes

Common patterns are provided as utility classes:

- **Layout**: `.bct-flex`, `.bct-flex-column`
- **Spacing**: `.bct-mt-md`, `.bct-p-sm`
- **Components**: `.bct-btn`, `.bct-card`, `.bct-input`

## JavaScript Utilities (`bct-common.js`)

### Communication Helpers

```javascript
// Send message to MATLAB
BCT.sendToMatlab(componentId, cmd, data);

// Listen for MATLAB messages
BCT.onMatlabMessage(callback);
```

### State Management

```javascript
// Create state manager
const state = new BCT.StateManager({
    property1: value1,
    property2: value2
});

// Get state
const value = state.get('property1');
const allState = state.get();

// Set state
state.set('property1', newValue);

// Subscribe to changes
state.subscribe((newState) => {
    console.log('State changed:', newState);
});
```

### DOM Utilities

```javascript
// Create element with options
const button = BCT.createElement('button', {
    classes: ['bct-btn', 'bct-btn-primary'],
    attrs: { 'data-id': 'myButton' },
    text: 'Click Me'
});

// Show notification
BCT.notify('Operation complete!', 'success', 3000);
```

### Performance Helpers

```javascript
// Debounce rapid calls
const debouncedSave = BCT.debounce(saveData, 500);

// Throttle continuous updates
const throttledUpdate = BCT.throttle(updateView, 100);
```

## Component Communication Patterns

### Pattern 1: Simple Command
```
User clicks button in JS
  ↓
JS: BCT.sendToMatlab(id, 'buttonClick', {buttonId: 'save'})
  ↓
MATLAB: onMessage receives {cmd: 'buttonClick', buttonId: 'save'}
  ↓
MATLAB: Routes to app.saveData()
  ↓
App executes save logic
```

### Pattern 2: State Update
```
MATLAB: Property changes (e.g., new data loaded)
  ↓
MATLAB: obj.setState({data: newData})
  ↓
MATLAB: obj.send({cmd: 'stateUpdate', state: {...}})
  ↓
JS: Receives message, updates state
  ↓
JS: Re-renders UI with new state
```

### Pattern 3: Request-Response
```
JS: User requests data export
  ↓
JS: BCT.sendToMatlab(id, 'export', {filename: 'data.txt'})
  ↓
MATLAB: Processes export
  ↓
MATLAB: obj.send({cmd: 'exportComplete', success: true})
  ↓
JS: Shows success notification
```

## Error Handling

### MATLAB Side
```matlab
try
    % Operation that might fail
    result = processData();
catch ME
    warning('bct:ui:Component:Error', ...
        'Operation failed: %s', ME.message);
    obj.send(struct('cmd', 'error', 'message', ME.message));
end
```

### JavaScript Side
```javascript
try {
    // Operation that might fail
    const result = processData();
    BCT.sendToMatlab(id, 'success', {result: result});
} catch (error) {
    console.error('Operation failed:', error);
    BCT.notify(error.message, 'error');
}
```

## Performance Considerations

### 1. **Message Batching**
- Batch related updates into single messages
- Use debouncing for rapid property changes
- Avoid sending messages in tight loops

### 2. **Rendering Optimization**
- Use `requestAnimationFrame` for smooth animations
- Implement virtual scrolling for large lists
- Render complex visualizations asynchronously

### 3. **Memory Management**
- Limit stored messages (console: 1000 messages)
- Clean up event listeners when components destroy
- Use weak references where appropriate

### 4. **Data Transfer**
- Minimize data sent between MATLAB and JavaScript
- Use compressed formats when possible
- Stream large datasets rather than bulk transfer

## Security Considerations

### 1. **Input Validation**
- Always validate messages from JavaScript
- Sanitize user input before evaluation
- Use type checking on all inputs

### 2. **Command Execution**
- Whitelist allowed commands
- Never use `eval()` on untrusted input
- Implement permission checks for sensitive operations

### 3. **Data Exposure**
- Only send necessary data to JavaScript
- Don't expose sensitive information in console logs
- Implement proper error messages without sensitive details

## Testing Strategy

### Unit Tests
- Test each component class independently
- Mock HTML UI Component interactions
- Verify message handling logic

### Integration Tests
- Test component communication with app
- Verify state synchronization
- Test error handling paths

### UI Tests
- Test JavaScript functionality
- Verify DOM manipulation
- Check event handlers

## Extensibility

### Adding New Components

1. **Create MATLAB Class**
   ```matlab
   classdef NewComponent < bct.ui.Component
       % Implementation
   end
   ```

2. **Create HTML Template**
   ```html
   <!-- +ui/html/newcomponent.html -->
   <div id="bct-newcomponent">
       <!-- Structure -->
   </div>
   ```

3. **Create JavaScript Logic**
   ```javascript
   // +ui/js/newcomponent.js
   (function() {
       // Implementation
   })();
   ```

4. **Create Styles**
   ```css
   /* +ui/css/newcomponent.css */
   .bct-newcomponent {
       /* Styles */
   }
   ```

### Integrating External Libraries

**D3.js Example:**
```html
<script src="https://d3js.org/d3.v7.min.js"></script>
<script src="../js/mycomponent.js"></script>
```

**Three.js Example:**
```html
<script src="https://cdn.jsdelivr.net/npm/three@0.150.0/build/three.min.js"></script>
<script src="../js/mycomponent.js"></script>
```

## Best Practices Summary

1. ✅ **Always initialize components in startupFcn**
2. ✅ **Use Console for all user feedback**
3. ✅ **Disable controls during long operations**
4. ✅ **Validate all inputs from JavaScript**
5. ✅ **Follow naming conventions**
6. ✅ **Document all public methods**
7. ✅ **Handle errors gracefully**
8. ✅ **Keep components focused and modular**
9. ✅ **Use design system variables**
10. ✅ **Test components independently**

## Migration from Legacy UI

If you have existing MATLAB App Designer apps with traditional UI components:

1. Add HTML UI Component widgets
2. Initialize bct.ui components alongside existing UI
3. Gradually migrate functionality to new components
4. Remove old components when migration complete

Components can coexist with traditional App Designer UI elements.

## Resources

- **MATLAB Documentation**: [HTML UI Components](https://www.mathworks.com/help/matlab/ref/uihtml.html)
- **MDN Web Docs**: [HTML](https://developer.mozilla.org/en-US/docs/Web/HTML), [CSS](https://developer.mozilla.org/en-US/docs/Web/CSS), [JavaScript](https://developer.mozilla.org/en-US/docs/Web/JavaScript)
- **Component Examples**: See `examples/demo_ui_components.m`

## Version History

- **v1.0** (2025-12-10): Initial release with Toolstrip, Sidebar, Console, and PlotPanel components
