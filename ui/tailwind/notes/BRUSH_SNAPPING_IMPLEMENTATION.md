# D3 Brush Snapping Implementation

## Overview

Successfully implemented Observable-style brush snapping with smooth transitions for the BaseScrubber component, following the pattern from https://observablehq.com/@d3/brush-snapping-transitions.

## Key Features

### 1. **D3 brushX Integration**
- Replaced manual drag handlers with D3's `brushX()` for native 1D selection
- Provides built-in drag behavior with better UX than custom handlers
- Automatic handle positioning and visual feedback

### 2. **Smart Snapping**
- **Snap Threshold**: 5 pixels (configurable via `snapThreshold` option)
- Small movements (< 5px) don't trigger snapping to avoid visual jitter
- Only snaps on release, not during drag for smooth interaction

### 3. **Smooth Transitions**
- **Duration**: 300ms (configurable via `transitionDuration` option)
- Uses D3 transitions for animated snap: `.transition().duration(300).call(brush.move, extent)`
- Provides visual feedback when brush "jumps" to snap point

### 4. **Dual Snap Modes**
- **Symmetric**: Snaps center point, maintains width
- **Asymmetric**: Snaps both boundaries independently

### 5. **Complementary Interactions**
- **Click-to-set**: Click outside brush to jump to position (also snaps)
- **Scroll-to-adjust**: Scroll over brush to change width
- **Controls**: Toggle symmetric mode, reset, kernel shape selection

## Implementation Details

### Modified Files

#### `ui/src/js/scrubber/BaseScrubber.js`
- **Removed**: Manual drag handlers (`startDrag`, `handleDrag`, `endDrag`)
- **Added**: `setupBrush()`, `styleBrush()`, `onBrush()`, `onBrushEnd()`
- **Updated**: `init()`, `render()`, `setupEventListeners()`, `handleClickToSet()`, `handleScroll()`, `reset()`

#### `ui/tailwind/test/test_brush_snapping.html`
- Comprehensive test page with 3 scrubbers
- Different snap functions: 0.01 increments, 5 Hz bins, 0.1 increments
- Real-time state display and test controls

### Key Methods

#### `setupBrush()`
```javascript
setupBrush() {
  this.brush = brushX()
    .extent([[0, 0], [width, height]])
    .on('brush', this.onBrush.bind(this))
    .on('end', this.onBrushEnd.bind(this));
  
  this.brushGroup.call(this.brush);
  this.brushGroup.call(this.brush.move, [x0, x1]); // Set initial extent
}
```

#### `onBrushEnd()` - The Snap Logic
```javascript
onBrushEnd(event) {
  if (!event.sourceEvent || this.isSnapping) return;
  
  const selection = event.selection;
  if (!selection) return;
  
  // Convert to data coordinates
  const [x0, x1] = selection;
  const left = this.xScale.invert(x0);
  const right = this.xScale.invert(x1);
  const center = (left + right) / 2;
  
  // Apply snap function
  const snapFunction = this.state.get('snapFunction');
  const snappedCenter = snapFunction(center);
  const snappedLeft = snapFunction(left);
  const snappedRight = snapFunction(right);
  
  // Check if snapping is needed (threshold)
  const centerDiff = Math.abs(this.xScale(snappedCenter) - this.xScale(center));
  const needsSnap = centerDiff > this.snapThreshold;
  
  if (needsSnap) {
    this.isSnapping = true;
    
    // Calculate snapped extent based on mode
    let newX0, newX1;
    if (this.state.get('isSymmetric')) {
      const halfWidth = (right - left) / 2;
      newX0 = this.xScale(snappedCenter - halfWidth);
      newX1 = this.xScale(snappedCenter + halfWidth);
    } else {
      newX0 = this.xScale(snappedLeft);
      newX1 = this.xScale(snappedRight);
    }
    
    // Animate brush to snapped position
    this.brushGroup
      .transition()
      .duration(this.transitionDuration)
      .call(this.brush.move, [newX0, newX1])
      .on('end', () => {
        this.isSnapping = false;
        this.updateVisualization();
        this.notifyChange();
      });
  } else {
    // No snap needed, just update state
    this.notifyChange();
  }
}
```

## Configuration

### Constructor Options
```javascript
new BCT.BaseScrubber('#container', {
  min: 0,                  // Axis minimum
  max: 100,                // Axis maximum
  center: 50,              // Initial center position
  width: 20,               // Initial width
  snap: (x) => x,          // Snap function (default: identity)
  snapThreshold: 5,        // Snap threshold in pixels
  transitionDuration: 300, // Transition duration in ms
  label: 'Axis',           // Axis label
  domain: 'generic'        // Domain type
});
```

### Custom Snap Functions

#### Sample Snapping (0.01 increments)
```javascript
snap: (v) => Math.round(v * 100) / 100
```

#### Frequency Bin Snapping (5 Hz bins)
```javascript
snap: (v) => Math.round(v / 5) * 5
```

#### Eigenvalue Snapping (discrete indices)
```javascript
snap: (v) => {
  const index = Math.round(v);
  return eigenvalues[index];
}
```

## Bundle Details

- **File**: `ui/tailwind/dist/bct-ui.js`
- **Size**: ~299KB minified
- **D3 Version**: 7.9.0 (tree-shaken)
- **Format**: IIFE, exposes `window.BCT`

## Testing

### Test Page
`ui/tailwind/test/test_brush_snapping.html`

### Test Scenarios
1. **Drag and release** - Watch smooth 300ms snap transition
2. **Small drags** (< 5px) - Should not trigger snapping
3. **Click-to-set** - Click outside brush to jump (with snap)
4. **Scroll-to-adjust** - Scroll over brush to change width
5. **Symmetric mode** - Snaps center, maintains width
6. **Asymmetric mode** - Snaps both boundaries independently
7. **Reset** - Returns to default state with animated brush move

### Browser Testing
```powershell
# Open test page
Start-Process "c:\CodingProjects\bioctree\ui\tailwind\test\test_brush_snapping.html"
```

## MATLAB Integration

### Data Property Communication
The brush snapping works seamlessly with MATLAB's HTML UI Component:

```matlab
% In MATLAB
comp = uihtml(fig);
comp.HTMLSource = 'scrubber_d3.html';

% Listen for changes
comp.DataChangedFcn = @(src, event) handleScrubberChange(event.Data);

function handleScrubberChange(data)
    fprintf('Center: %.3f, Width: %.3f\n', data.center, data.width);
end
```

### State Updates
- `onBrush`: Real-time updates during drag
- `onBrushEnd`: Final update after snap with `notifyChange()`
- Click/scroll: Immediate updates with brush animation

## Architecture Benefits

### 1. **Separation of Concerns**
- D3 brush handles interaction logic
- Snap function handles domain-specific constraints
- Transition handles visual feedback

### 2. **Reusability**
- Any domain can provide its own snap function
- Time domain: samples
- Frequency domain: bins
- Lambda domain: eigenvalue indices

### 3. **Performance**
- Snap threshold prevents unnecessary transitions
- `isSnapping` flag prevents recursive updates
- Tree-shaken D3 keeps bundle size reasonable

### 4. **UX Excellence**
- Smooth animations feel natural
- Click and scroll provide quick adjustments
- Visual feedback throughout interaction
- No visual jitter on small movements

## Next Steps

### Recommended Enhancements
1. **Multi-brush support**: Select multiple regions
2. **Brush constraints**: Enforce min/max width
3. **Snap indicators**: Show snap points on axis
4. **Touch support**: Test on touch devices
5. **Keyboard navigation**: Arrow keys for fine control

### Domain Wrappers
Update the domain-specific scrubbers:
- `TimeScrubber`: Sample-based snapping
- `OmegaScrubber`: Frequency bin snapping
- `LambdaScrubber`: Eigenvalue index snapping

### Documentation
Add brush snapping examples to:
- `docs/tutorials/scrubber-usage.md`
- `docs/api/scrubber-api.md`
- `D3_INTEGRATION.md`

## Commit

```bash
git add ui/src/js/scrubber/BaseScrubber.js
git add ui/tailwind/dist/bct-ui.js
git add ui/tailwind/test/test_brush_snapping.html
git commit -m "feat: Add D3 brush with Observable-style snapping and smooth transitions

- Replace manual drag handlers with D3 brushX()
- Implement snap threshold (5px) to prevent jitter
- Add smooth 300ms transitions on snap
- Support symmetric (snap center) and asymmetric (snap boundaries) modes
- Keep complementary interactions (click-to-set, scroll-to-adjust)
- Update test page with 3 different snap functions
- Bundle size: ~299KB (tree-shaken D3 v7.9.0)

Follows Observable pattern: https://observablehq.com/@d3/brush-snapping-transitions"
```

## References

- **Observable Example**: https://observablehq.com/@d3/brush-snapping-transitions
- **D3 Brush API**: https://github.com/d3/d3-brush
- **D3 Transitions**: https://github.com/d3/d3-transition
- **Integration Guide**: `ui/tailwind/notes/D3_INTEGRATION.md`
