# BCT Tailwind UI - Quick Start

Get up and running in 5 minutes!

## Step 1: Build the CSS (One-time setup)

```bash
cd toolbox/+bct/+ui/tailwind
npm install
npm run build
```

**Output:** `dist/bct-ui.css` (30.67 KB minified)

## Step 2: Preview Components

Open any component in your browser:

```bash
# Toolstrip
start components/toolstrip.html

# Sidebar
start components/sidebar.html

# Console
start components/console.html

# Plot Panel
start components/plotpanel.html

# Modal
start components/modal.html

# All UI Elements
start components/elements/ui-elements.html
```

## Step 3: Use in Your HTML

```html
<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="../dist/bct-ui.css">
</head>
<body>
  <!-- Your UI here -->
  <div class="card">
    <div class="card-header">Hello BCT</div>
    <div class="card-body">
      <button class="btn btn-primary">Click Me</button>
    </div>
  </div>

  <!-- Scripts -->
  <script src="../dist/bct-ui.js"></script>
  <script src="./your-component.js"></script>
</body>
</html>
```

## Step 4: Add JavaScript Functionality

```javascript
// your-component.js
(function() {
  'use strict';

  // Create state
  const state = new BCT.StateManager({ count: 0 });

  // Handle button click
  function handleClick() {
    const count = state.get('count') + 1;
    state.set('count', count);
    BCT.notify.show(`Clicked ${count} times`, 'success');
  }

  // Initialize
  function init() {
    BCT.$('.btn').addEventListener('click', handleClick);
    BCT.sendToMatlab('componentReady');
  }

  // Setup message handler
  BCT.onMatlabMessage((data) => {
    console.log('Received from MATLAB:', data);
  });

  // Start
  document.addEventListener('DOMContentLoaded', init);
})();
```

## Step 5: Integrate with MATLAB

```matlab
% Create wrapper class
classdef MyComponent < bct.ui.Component
    methods
        function obj = MyComponent(app, htmlControl)
            obj@bct.ui.Component(app, htmlControl);
            obj.HTMLPath = fullfile(...
                fileparts(mfilename('fullpath')), ...
                'tailwind', 'components', 'my-component.html');
            obj.loadHTML();
        end
        
        function onMessage(obj, data)
            switch data.cmd
                case 'componentReady'
                    disp('Component initialized');
                case 'buttonClick'
                    obj.App.handleButtonClick();
            end
        end
    end
end

% Use in App Designer
function startupFcn(app)
    app.MyComponent = MyComponent(app, app.HTMLControl);
end
```

## Common Tasks

### Toggle Dark Mode
```javascript
BCT.toggleDarkMode();
```

### Show Notification
```javascript
BCT.notify.show('Message', 'success', 5000);
```

### Send Data to MATLAB
```javascript
BCT.sendToMatlab('commandName', { data: value });
```

### Create UI Element
```javascript
const button = BCT.createElement('button', {
  className: 'btn btn-primary',
  onClick: handleClick
}, 'Click Me');
document.body.appendChild(button);
```

### State Management
```javascript
const state = new BCT.StateManager({ value: 0 });

// Get
const value = state.get('value');

// Set
state.set('value', 10);

// Subscribe
state.subscribe((newState, oldState) => {
  console.log('State changed:', newState);
});
```

## Available Components

### Toolstrip
```javascript
BctToolstrip.init(buttonGroups);
BctToolstrip.addButton(groupId, button);
```

### Sidebar
```javascript
BctSidebar.init(sections);
BctSidebar.updateControl(sectionId, controlId, value);
```

### Console
```javascript
BctConsole.log('Message');
BctConsole.success('Success message');
BctConsole.error('Error message');
```

### PlotPanel
```javascript
BctPlotPanel.plotMesh({ vertices, faces });
BctPlotPanel.setMode('pan');
```

### Modal
```javascript
BctModal.alert('Title', 'Message');
BctModal.confirm('Title', 'Question?', onConfirm);
BctModal.prompt('Title', 'Enter value:', defaultValue, onConfirm);
```

## UI Element Classes

### Buttons
```html
<button class="btn btn-primary">Primary</button>
<button class="btn btn-secondary">Secondary</button>
<button class="btn-icon"><svg>...</svg></button>
```

### Inputs
```html
<input type="text" class="input w-full" placeholder="Text">
<select class="select w-full"><option>...</option></select>
<input type="range" class="slider" min="0" max="100">
```

### Toggles
```html
<button class="toggle active">
  <span class="toggle-thumb"></span>
</button>
```

### Cards
```html
<div class="card">
  <div class="card-header">Title</div>
  <div class="card-body">Content</div>
</div>
```

### Badges
```html
<span class="badge badge-success">Success</span>
<span class="badge badge-error">Error</span>
```

## Need Help?

📖 **Full Documentation:** `TAILWIND_GUIDE.md`  
💻 **MATLAB Examples:** `MATLAB_INTEGRATION_EXAMPLE.m`  
🧩 **Element Reference:** `components/elements/ELEMENT_REFERENCE.md`  
📊 **Project Status:** `PROJECT_STATUS.md`  

## Troubleshooting

**CSS not loading?**
- Run `npm run build` in `tailwind/` directory
- Check `dist/bct-ui.css` exists

**Dark mode not working?**
- Add `class="dark"` to `<html>` element
- Call `BCT.initTheme()` on load

**MATLAB communication failing?**
- Check `HTMLPath` is correct
- Verify `loadHTML()` was called
- Check browser console for errors

## Next Steps

1. ✅ Build CSS (`npm run build`)
2. ✅ Preview components (open HTML files)
3. ✅ Read full documentation
4. ✅ Create MATLAB wrappers
5. ✅ Integrate with your app

**Happy coding! 🚀**
