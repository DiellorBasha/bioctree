/**
 * BCT Base Scrubber Component
 * Interactive 1D axis navigation with kernel visualization
 */

(function() {
  'use strict';

  // ============================================================================
  // STATE & CONFIGURATION
  // ============================================================================

  const state = new BCT.StateManager({
    // Axis configuration
    axisMin: 0,
    axisMax: 100,
    axisLabel: 'Axis',
    domainType: 'generic',
    tickFormatter: (x) => x.toFixed(2),
    snapFunction: (x) => x,
    
    // Window/kernel state
    center: 50,
    width: 20,
    leftBound: null,  // null = symmetric
    rightBound: null, // null = symmetric
    isSymmetric: true,
    
    // Kernel configuration
    kernelShape: 'gaussian',
    kernelResolution: 200,
    
    // UI state
    isDragging: false,
    dragTarget: null,  // 'center', 'left', 'right'
    dragStartX: 0,
    dragStartValue: 0
  });

  // DOM elements
  let container, svg, kernelPath, centerLine, leftLine, rightLine;
  let selectionRegion, centerKnob, leftHandle, rightHandle;
  let clickOverlay, axisLabel, domainBadge;
  let valueCenterSpan, valueWidthSpan;
  let tickMin, tickMid, tickMax;
  let kernelShapeSelect, btnSymmetric, btnReset;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  function init() {
    // Get DOM elements
    container = BCT.$('#scrubber-container');
    svg = BCT.$('#kernel-svg');
    kernelPath = BCT.$('#kernel-path');
    centerLine = BCT.$('#center-line');
    leftLine = BCT.$('#left-line');
    rightLine = BCT.$('#right-line');
    
    selectionRegion = BCT.$('#selection-region');
    centerKnob = BCT.$('#center-knob');
    leftHandle = BCT.$('#left-handle');
    rightHandle = BCT.$('#right-handle');
    
    clickOverlay = BCT.$('#click-overlay');
    axisLabel = BCT.$('#axis-label');
    domainBadge = BCT.$('#domain-badge');
    
    valueCenterSpan = BCT.$('#value-center');
    valueWidthSpan = BCT.$('#value-width');
    
    tickMin = BCT.$('#tick-min');
    tickMid = BCT.$('#tick-mid');
    tickMax = BCT.$('#tick-max');
    
    kernelShapeSelect = BCT.$('#kernel-shape');
    btnSymmetric = BCT.$('#btn-symmetric');
    btnReset = BCT.$('#btn-reset');
    
    setupEventListeners();
    render();
  }

  // ============================================================================
  // EVENT LISTENERS
  // ============================================================================

  function setupEventListeners() {
    // Center knob drag
    centerKnob.addEventListener('mousedown', (e) => startDrag(e, 'center'));
    
    // Handle drags (asymmetric mode)
    leftHandle.addEventListener('mousedown', (e) => startDrag(e, 'left'));
    rightHandle.addEventListener('mousedown', (e) => startDrag(e, 'right'));
    
    // Click-to-set center
    clickOverlay.addEventListener('click', handleClickToSet);
    
    // Scroll to adjust width
    selectionRegion.addEventListener('wheel', handleScroll, { passive: false });
    
    // Kernel shape change
    kernelShapeSelect.addEventListener('change', (e) => {
      state.set('kernelShape', e.target.value);
      render();
      notifyChange();
    });
    
    // Symmetric mode toggle
    btnSymmetric.addEventListener('click', toggleSymmetricMode);
    
    // Reset
    btnReset.addEventListener('click', reset);
    
    // Global mouse events for dragging
    document.addEventListener('mousemove', handleDrag);
    document.addEventListener('mouseup', endDrag);
  }

  function startDrag(e, target) {
    e.stopPropagation();
    e.preventDefault();
    
    state.set({
      isDragging: true,
      dragTarget: target,
      dragStartX: e.clientX,
      dragStartValue: state.get('center')
    });
    
    if (target === 'center') {
      centerKnob.classList.remove('cursor-grab');
      centerKnob.classList.add('cursor-grabbing');
    }
  }

  function handleDrag(e) {
    if (!state.get('isDragging')) return;
    
    const target = state.get('dragTarget');
    const rect = selectionRegion.getBoundingClientRect();
    const deltaX = e.clientX - state.get('dragStartX');
    const deltaValue = (deltaX / rect.parentElement.offsetWidth) * 
                       (state.get('axisMax') - state.get('axisMin'));
    
    if (target === 'center') {
      let newCenter = state.get('dragStartValue') + deltaValue;
      newCenter = clampToAxis(newCenter);
      newCenter = state.get('snapFunction')(newCenter);
      state.set('center', newCenter);
    } else if (target === 'left') {
      // Adjust left boundary (asymmetric mode)
      const center = state.get('center');
      let newLeft = center - (state.get('width') / 2) + deltaValue;
      newLeft = clampToAxis(newLeft);
      state.set('leftBound', newLeft);
    } else if (target === 'right') {
      // Adjust right boundary (asymmetric mode)
      const center = state.get('center');
      let newRight = center + (state.get('width') / 2) + deltaValue;
      newRight = clampToAxis(newRight);
      state.set('rightBound', newRight);
    }
    
    render();
  }

  function endDrag() {
    if (state.get('isDragging')) {
      state.set('isDragging', false);
      centerKnob.classList.remove('cursor-grabbing');
      centerKnob.classList.add('cursor-grab');
      notifyChange();
    }
  }

  function handleClickToSet(e) {
    const rect = e.target.getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width;
    const value = state.get('axisMin') + x * (state.get('axisMax') - state.get('axisMin'));
    const snapped = state.get('snapFunction')(value);
    
    state.set('center', clampToAxis(snapped));
    render();
    notifyChange();
  }

  function handleScroll(e) {
    e.preventDefault();
    
    const delta = -Math.sign(e.deltaY);
    const currentWidth = state.get('width');
    const axisRange = state.get('axisMax') - state.get('axisMin');
    const widthStep = axisRange * 0.02; // 2% of axis range per scroll
    
    let newWidth = currentWidth + (delta * widthStep);
    newWidth = Math.max(axisRange * 0.01, Math.min(axisRange * 0.5, newWidth));
    
    state.set('width', newWidth);
    render();
    notifyChange();
  }

  function toggleSymmetricMode() {
    const isSymmetric = !state.get('isSymmetric');
    state.set('isSymmetric', isSymmetric);
    
    if (isSymmetric) {
      // Reset to symmetric
      state.set({ leftBound: null, rightBound: null });
      leftHandle.style.opacity = '0';
      rightHandle.style.opacity = '0';
      leftLine.setAttribute('opacity', '0');
      rightLine.setAttribute('opacity', '0');
    } else {
      // Enable asymmetric mode
      const center = state.get('center');
      const width = state.get('width');
      state.set({
        leftBound: center - width / 2,
        rightBound: center + width / 2
      });
      leftHandle.style.opacity = '1';
      rightHandle.style.opacity = '1';
      leftLine.setAttribute('opacity', '0.5');
      rightLine.setAttribute('opacity', '0.5');
    }
    
    render();
    notifyChange();
  }

  function reset() {
    const axisMin = state.get('axisMin');
    const axisMax = state.get('axisMax');
    
    state.set({
      center: (axisMin + axisMax) / 2,
      width: (axisMax - axisMin) * 0.2,
      leftBound: null,
      rightBound: null,
      isSymmetric: true,
      kernelShape: 'gaussian'
    });
    
    kernelShapeSelect.value = 'gaussian';
    leftHandle.style.opacity = '0';
    rightHandle.style.opacity = '0';
    
    render();
    notifyChange();
  }

  // ============================================================================
  // RENDERING
  // ============================================================================

  function render() {
    renderAxisTicks();
    renderSelectionRegion();
    renderKernelVisualization();
    renderValueDisplays();
  }

  function renderAxisTicks() {
    const formatter = state.get('tickFormatter');
    const min = state.get('axisMin');
    const max = state.get('axisMax');
    const mid = (min + max) / 2;
    
    tickMin.textContent = formatter(min);
    tickMid.textContent = formatter(mid);
    tickMax.textContent = formatter(max);
    
    axisLabel.textContent = state.get('axisLabel');
    domainBadge.textContent = state.get('domainType');
  }

  function renderSelectionRegion() {
    const center = state.get('center');
    const width = state.get('width');
    const min = state.get('axisMin');
    const max = state.get('axisMax');
    const range = max - min;
    
    // Calculate bounds
    let leftBound, rightBound;
    if (state.get('isSymmetric')) {
      leftBound = center - width / 2;
      rightBound = center + width / 2;
    } else {
      leftBound = state.get('leftBound');
      rightBound = state.get('rightBound');
    }
    
    // Normalize to [0, 1]
    const leftNorm = (leftBound - min) / range;
    const rightNorm = (rightBound - min) / range;
    const centerNorm = (center - min) / range;
    
    // Position selection region
    const parentWidth = selectionRegion.parentElement.offsetWidth;
    const left = leftNorm * parentWidth;
    const regionWidth = (rightNorm - leftNorm) * parentWidth;
    
    selectionRegion.style.left = `${left}px`;
    selectionRegion.style.width = `${regionWidth}px`;
    
    // Position center knob
    centerKnob.style.left = `${(centerNorm - leftNorm) / (rightNorm - leftNorm) * 100}%`;
  }

  function renderKernelVisualization() {
    const center = state.get('center');
    const width = state.get('width');
    const min = state.get('axisMin');
    const max = state.get('axisMax');
    const shape = state.get('kernelShape');
    const resolution = state.get('kernelResolution');
    
    const svgRect = svg.getBoundingClientRect();
    const svgWidth = svgRect.width;
    const svgHeight = svgRect.height;
    
    // Generate kernel values
    const kernelData = generateKernel(min, max, center, width, shape, resolution);
    
    // Create SVG path
    let pathD = `M 0 ${svgHeight}`;
    
    for (let i = 0; i < kernelData.length; i++) {
      const x = (i / (kernelData.length - 1)) * svgWidth;
      const y = svgHeight - (kernelData[i] * svgHeight * 0.8); // 80% max height
      pathD += ` L ${x} ${y}`;
    }
    
    pathD += ` L ${svgWidth} ${svgHeight} Z`;
    kernelPath.setAttribute('d', pathD);
    
    // Update center line
    const centerNorm = (center - min) / (max - min);
    const centerX = centerNorm * svgWidth;
    centerLine.setAttribute('x1', centerX);
    centerLine.setAttribute('x2', centerX);
    centerLine.setAttribute('y1', 0);
    centerLine.setAttribute('y2', svgHeight);
    
    // Update left/right lines (asymmetric mode)
    if (!state.get('isSymmetric')) {
      const leftBound = state.get('leftBound');
      const rightBound = state.get('rightBound');
      
      const leftX = ((leftBound - min) / (max - min)) * svgWidth;
      const rightX = ((rightBound - min) / (max - min)) * svgWidth;
      
      leftLine.setAttribute('x1', leftX);
      leftLine.setAttribute('x2', leftX);
      leftLine.setAttribute('y1', 0);
      leftLine.setAttribute('y2', svgHeight);
      
      rightLine.setAttribute('x1', rightX);
      rightLine.setAttribute('x2', rightX);
      rightLine.setAttribute('y1', 0);
      rightLine.setAttribute('y2', svgHeight);
    }
  }

  function renderValueDisplays() {
    const formatter = state.get('tickFormatter');
    const center = state.get('center');
    const width = state.get('width');
    
    valueCenterSpan.textContent = formatter(center);
    valueWidthSpan.textContent = formatter(width);
  }

  // ============================================================================
  // KERNEL GENERATION
  // ============================================================================

  function generateKernel(min, max, center, width, shape, resolution) {
    const data = new Array(resolution);
    const range = max - min;
    
    for (let i = 0; i < resolution; i++) {
      const x = min + (i / (resolution - 1)) * range;
      const distance = Math.abs(x - center);
      const normalized = distance / (width / 2);
      
      let value;
      switch (shape) {
        case 'gaussian':
          value = Math.exp(-0.5 * normalized * normalized * 9); // σ = width/6
          break;
        case 'rectangular':
          value = normalized <= 1 ? 1 : 0;
          break;
        case 'triangular':
          value = Math.max(0, 1 - normalized);
          break;
        case 'hamming':
          value = normalized <= 1 ? 0.54 + 0.46 * Math.cos(Math.PI * normalized) : 0;
          break;
        case 'hann':
          value = normalized <= 1 ? 0.5 * (1 + Math.cos(Math.PI * normalized)) : 0;
          break;
        case 'tukey':
          const alpha = 0.5;
          if (normalized <= alpha / 2) {
            value = 1;
          } else if (normalized <= 1) {
            value = 0.5 * (1 + Math.cos(Math.PI * (normalized - alpha / 2) / (1 - alpha / 2)));
          } else {
            value = 0;
          }
          break;
        default:
          value = Math.exp(-0.5 * normalized * normalized * 9);
      }
      
      data[i] = value;
    }
    
    return data;
  }

  // ============================================================================
  // UTILITY FUNCTIONS
  // ============================================================================

  function clampToAxis(value) {
    return Math.max(state.get('axisMin'), Math.min(state.get('axisMax'), value));
  }

  function notifyChange() {
    const center = state.get('center');
    const width = state.get('width');
    const leftBound = state.get('leftBound');
    const rightBound = state.get('rightBound');
    const isSymmetric = state.get('isSymmetric');
    
    BCT.postToMatlab('onChange', {
      center: center,
      width: width,
      leftBound: leftBound,
      rightBound: rightBound,
      isSymmetric: isSymmetric,
      domain: state.get('domainType'),
      kernelShape: state.get('kernelShape')
    });
  }

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  window.ScrubberAPI = {
    setCenter(value) {
      state.set('center', clampToAxis(value));
      render();
    },
    
    setWidth(value) {
      state.set('width', Math.abs(value));
      render();
    },
    
    setAxis(axisSpec) {
      state.set({
        axisMin: axisSpec.min,
        axisMax: axisSpec.max,
        axisLabel: axisSpec.label || 'Axis',
        domainType: axisSpec.domain || 'generic',
        tickFormatter: axisSpec.tickFormatter || ((x) => x.toFixed(2)),
        snapFunction: axisSpec.snap || ((x) => x)
      });
      render();
    },
    
    setKernelShape(shape) {
      state.set('kernelShape', shape);
      kernelShapeSelect.value = shape;
      render();
    },
    
    enableAsymmetricMode(enable) {
      if (enable !== state.get('isSymmetric')) {
        toggleSymmetricMode();
      }
    },
    
    updateFromExternalChange(spec) {
      if (spec.center !== undefined) state.set('center', spec.center);
      if (spec.width !== undefined) state.set('width', spec.width);
      if (spec.leftBound !== undefined) state.set('leftBound', spec.leftBound);
      if (spec.rightBound !== undefined) state.set('rightBound', spec.rightBound);
      render();
    },
    
    getCurrentKernel() {
      return {
        center: state.get('center'),
        width: state.get('width'),
        leftBound: state.get('leftBound'),
        rightBound: state.get('rightBound'),
        isSymmetric: state.get('isSymmetric'),
        shape: state.get('kernelShape'),
        domain: state.get('domainType')
      };
    }
  };

  // ============================================================================
  // MESSAGE HANDLER
  // ============================================================================

  BCT.onMatlabMessage((data) => {
    if (!data || !data.cmd) return;
    
    switch (data.cmd) {
      case 'setCenter':
        if (data.value !== undefined) window.ScrubberAPI.setCenter(data.value);
        break;
      case 'setWidth':
        if (data.value !== undefined) window.ScrubberAPI.setWidth(data.value);
        break;
      case 'setAxis':
        if (data.axisSpec) window.ScrubberAPI.setAxis(data.axisSpec);
        break;
      case 'setKernelShape':
        if (data.shape) window.ScrubberAPI.setKernelShape(data.shape);
        break;
      case 'enableAsymmetricMode':
        if (data.enable !== undefined) window.ScrubberAPI.enableAsymmetricMode(data.enable);
        break;
      case 'update':
        if (data.spec) window.ScrubberAPI.updateFromExternalChange(data.spec);
        break;
      case 'reset':
        reset();
        break;
    }
  });

  // Initialize on load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
