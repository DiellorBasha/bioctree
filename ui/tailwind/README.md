# BCT UI Tailwind Design System

Modern, portable UI components built with Tailwind CSS for the BCT Toolbox.

## Quick Start

### Installation

```bash
cd toolbox/+bct/+ui/tailwind
npm install
```

### Build CSS

```bash
# Development build
npm run dev

# Production build (minified)
npm run build

# Watch mode (auto-rebuild on changes)
npm run watch
```

The compiled CSS will be output to `dist/bct-ui.css`.

## Project Structure

```
tailwind/
├── package.json              # npm configuration
├── tailwind.config.js        # Tailwind configuration
├── src/
│   └── tailwind.css          # Source CSS with Tailwind directives
├── dist/
│   ├── bct-ui.css            # Compiled CSS (generated)
│   └── bct-ui.js             # Shared JavaScript utilities
└── components/
    ├── toolstrip.html
    ├── toolstrip.js
    ├── sidebar.html
    ├── sidebar.js
    ├── console.html
    ├── console.js
    ├── plotpanel.html
    ├── plotpanel.js
    ├── modal.html
    ├── modal.js
    └── elements/             # Reusable UI elements
        ├── button.html
        ├── dropdown.html
        ├── slider.html
        ├── toggle.html
        ├── tabs.html
        └── notification.html
```

## Features

- **Dark/Light Mode**: Class-based theme switching
- **BCT Brand Colors**: Custom color palette with primary, secondary, accent
- **Responsive Layout**: Mobile-first utilities
- **Animation**: Fade-in, slide-in, slide-up transitions
- **Component Library**: Pre-styled buttons, cards, inputs, modals
- **Icon Support**: Ready for Heroicons or Lucide icons
- **MATLAB Integration**: Bridge API for bidirectional communication

## Usage

### In HTML Components

```html
<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="../dist/bct-ui.css">
  <title>BCT Component</title>
</head>
<body>
  <div class="panel">
    <div class="panel-header">
      <h2 class="text-lg font-semibold">Component Title</h2>
    </div>
    <div class="panel-body">
      <button class="btn btn-primary">Primary Action</button>
    </div>
  </div>
  
  <script src="../dist/bct-ui.js"></script>
  <script src="./component.js"></script>
</body>
</html>
```

### Dark Mode Toggle

```javascript
// Toggle dark mode
document.documentElement.classList.toggle('dark');
```

### MATLAB Integration

```javascript
// Send message to MATLAB
BCT.sendToMatlab('computeEigenbasis', { lambda: 100 });

// Receive message from MATLAB
BCT.onMatlabMessage((data) => {
  console.log('Received from MATLAB:', data);
});
```

## Customization

Edit `tailwind.config.js` to customize:

- Colors (BCT brand palette)
- Spacing scale
- Typography
- Shadows
- Border radius
- Animations

## Components

See individual component documentation in `components/` directory.

## License

MIT
