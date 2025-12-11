# BCT UI Elements Reference

Quick reference for all reusable UI components in the BCT Tailwind design system.

## Buttons

### Primary Button
```html
<button class="btn btn-primary">Primary Button</button>
```

### Secondary Button
```html
<button class="btn btn-secondary">Secondary Button</button>
```

### Ghost Button
```html
<button class="btn btn-ghost">Ghost Button</button>
```

### Icon Button
```html
<button class="btn-icon">
  <svg class="w-5 h-5"><!-- icon --></svg>
</button>
```

### Active Icon Button
```html
<button class="btn-icon active">
  <svg class="w-5 h-5"><!-- icon --></svg>
</button>
```

## Inputs

### Text Input
```html
<input type="text" class="input w-full" placeholder="Enter text">
```

### Number Input
```html
<input type="number" class="input w-full" placeholder="0">
```

### Disabled Input
```html
<input type="text" class="input w-full" disabled>
```

## Dropdowns

### Select Dropdown
```html
<select class="select w-full">
  <option>Option 1</option>
  <option>Option 2</option>
  <option>Option 3</option>
</select>
```

## Sliders

### Range Slider
```html
<input type="range" class="slider" min="0" max="100" value="50">
```

With label and value display:
```html
<div>
  <label class="block text-sm font-medium mb-2">Volume: <span id="value">50</span></label>
  <input type="range" class="slider" min="0" max="100" value="50" 
         oninput="document.getElementById('value').textContent = this.value">
</div>
```

## Toggle Switches

### Inactive Toggle
```html
<button class="toggle">
  <span class="toggle-thumb"></span>
</button>
```

### Active Toggle
```html
<button class="toggle active">
  <span class="toggle-thumb"></span>
</button>
```

### Toggle with Label
```html
<div class="flex items-center gap-3">
  <button class="toggle active">
    <span class="toggle-thumb"></span>
  </button>
  <span class="text-sm">Enable feature</span>
</div>
```

## Tabs

### Tab Navigation
```html
<div class="tabs">
  <button class="tab active">Tab 1</button>
  <button class="tab">Tab 2</button>
  <button class="tab">Tab 3</button>
</div>
```

## Cards

### Basic Card
```html
<div class="card">
  <div class="card-header">Card Title</div>
  <div class="card-body">
    <p>Card content goes here.</p>
  </div>
</div>
```

### Card Without Header
```html
<div class="card">
  <div class="card-body">
    <p>Card content without header.</p>
  </div>
</div>
```

## Badges

### Badge Variants
```html
<span class="badge badge-primary">Primary</span>
<span class="badge badge-success">Success</span>
<span class="badge badge-warning">Warning</span>
<span class="badge badge-error">Error</span>
```

## Notifications (Toasts)

### Info Notification
```html
<div class="toast info">
  <span class="text-xl">ℹ</span>
  <span class="flex-1">Info message</span>
  <button class="btn-icon p-1">&times;</button>
</div>
```

### Success Notification
```html
<div class="toast success">
  <span class="text-xl">✓</span>
  <span class="flex-1">Success message</span>
  <button class="btn-icon p-1">&times;</button>
</div>
```

### Warning Notification
```html
<div class="toast warning">
  <span class="text-xl">⚠</span>
  <span class="flex-1">Warning message</span>
  <button class="btn-icon p-1">&times;</button>
</div>
```

### Error Notification
```html
<div class="toast error">
  <span class="text-xl">✗</span>
  <span class="flex-1">Error message</span>
  <button class="btn-icon p-1">&times;</button>
</div>
```

### JavaScript API
```javascript
// Show notification
BCT.notify.show('Message text', 'info', 5000);  // type: info, success, warning, error

// Dismiss notification
BCT.notify.dismiss(notificationId);

// Clear all notifications
BCT.notify.clear();
```

## Dividers

### Horizontal Divider
```html
<div class="divider"></div>
```

### Vertical Divider
```html
<div class="divider-vertical h-12"></div>
```

## Panels

### Basic Panel
```html
<div class="panel">
  <div class="panel-header">
    <h3>Panel Title</h3>
  </div>
  <div class="panel-body">
    <p>Panel content</p>
  </div>
</div>
```

## Console Styling

### Console Line
```html
<div class="console">
  <div class="console-line">Default message</div>
  <div class="console-line info">Info message</div>
  <div class="console-line success">Success message</div>
  <div class="console-line warning">Warning message</div>
  <div class="console-line error">Error message</div>
</div>
```

## Layout Utilities

### Flexbox
```html
<div class="flex items-center justify-between gap-4">
  <!-- content -->
</div>
```

### Grid
```html
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  <!-- items -->
</div>
```

### Spacing
```html
<div class="space-y-4">  <!-- Vertical spacing -->
  <div>Item 1</div>
  <div>Item 2</div>
</div>

<div class="space-x-4">  <!-- Horizontal spacing -->
  <span>Item 1</span>
  <span>Item 2</span>
</div>
```

## Responsive Classes

All Tailwind responsive breakpoints are available:
- `sm:` - 640px and up
- `md:` - 768px and up
- `lg:` - 1024px and up
- `xl:` - 1280px and up
- `2xl:` - 1536px and up

Example:
```html
<div class="hidden md:block">Visible on medium screens and up</div>
<div class="text-sm md:text-base lg:text-lg">Responsive text size</div>
```

## Dark Mode

All components support dark mode automatically. Toggle dark mode:

```javascript
// Toggle dark/light theme
BCT.toggleDarkMode();

// Set specific theme
BCT.setTheme('dark');  // or 'light'

// Get current theme
const theme = BCT.getTheme();
```

Manual dark mode classes:
```html
<div class="bg-light-bg-primary dark:bg-dark-bg-primary">
  Content with theme-aware background
</div>
```

## Custom Colors

BCT brand colors are available:
- `bct-primary` - #2563eb
- `bct-secondary` - #7c3aed
- `bct-accent` - #06b6d4
- `bct-success` - #10b981
- `bct-warning` - #f59e0b
- `bct-error` - #ef4444
- `bct-info` - #3b82f6

Usage:
```html
<div class="bg-bct-primary text-white">Primary colored box</div>
<button class="text-bct-accent">Accent colored text</button>
```
