/**
 * BCT BaseScrubber Component
 * Interactive 1D axis navigation with kernel visualization using D3.js
 */

import { select, scaleLinear, line, drag, brushX } from 'd3';
import { StateManager, $, postToMatlab, onMatlabMessage } from '../core/utils.js';

export class BaseScrubber {
  constructor(selector, options = {}) {
    this.container = $(selector);
    if (!this.container) {
      throw new Error(`BaseScrubber: Container not found for selector "${selector}"`);
    }

    // Initialize state
    this.state = new StateManager({
      // Axis configuration
      axisMin: options.min ?? 0,
      axisMax: options.max ?? 100,
      axisLabel: options.label ?? 'Axis',
      domainType: options.domain ?? 'generic',
      tickFormatter: options.tickFormatter ?? ((x) => x.toFixed(2)),
      snapFunction: options.snap ?? ((x) => x),
      
      // Window/kernel state
      center: options.center ?? 50,
      width: options.width ?? 20,
      leftBound: null,
      rightBound: null,
      isSymmetric: true,
      
      // Kernel configuration
      kernelShape: options.kernelShape ?? 'gaussian',
      kernelResolution: 200,
      
      // UI state
      isDragging: false,
      dragTarget: null
    });

    // D3 selections
    this.svg = null;
    this.kernelPath = null;
    this.centerLine = null;
    this.leftLine = null;
    this.rightLine = null;
    
    // Scales
    this.xScale = null;
    
    // Initialize
    this.init();
  }

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  init() {
    this.render();
    this.setupEventListeners();
    this.updateVisualization();
  }

  render() {
    // Get elements
    this.svg = select(this.container).select('#kernel-svg');
    this.selectionRegion = $(this.container, '#selection-region');
    this.centerKnob = $(this.container, '#center-knob');
    this.leftHandle = $(this.container, '#left-handle');
    this.rightHandle = $(this.container, '#right-handle');
    this.clickOverlay = $(this.container, '#click-overlay');
    
    // Create scale
    const axisMin = this.state.get('axisMin');
    const axisMax = this.state.get('axisMax');
    this.xScale = scaleLinear()
      .domain([axisMin, axisMax])
      .range([0, this.svg.node().clientWidth]);
    
    // Get SVG elements
    this.kernelPath = this.svg.select('#kernel-path');
    this.centerLine = this.svg.select('#center-line');
    this.leftLine = this.svg.select('#left-line');
    this.rightLine = this.svg.select('#right-line');
    
    // Update initial view
    this.renderAxisTicks();
    this.renderSelectionRegion();
  }

  setupEventListeners() {
    // Center knob drag
    if (this.centerKnob) {
      this.centerKnob.addEventListener('mousedown', (e) => this.startDrag(e, 'center'));
    }
    
    // Handle drags (asymmetric mode)
    if (this.leftHandle) {
      this.leftHandle.addEventListener('mousedown', (e) => this.startDrag(e, 'left'));
    }
    if (this.rightHandle) {
      this.rightHandle.addEventListener('mousedown', (e) => this.startDrag(e, 'right'));
    }
    
    // Click-to-set center
    if (this.clickOverlay) {
      this.clickOverlay.addEventListener('click', (e) => this.handleClickToSet(e));
    }
    
    // Scroll to adjust width
    if (this.selectionRegion) {
      this.selectionRegion.addEventListener('wheel', (e) => this.handleScroll(e), { passive: false });
    }
    
    // Kernel shape change
    const kernelSelect = $(this.container, '#kernel-shape');
    if (kernelSelect) {
      kernelSelect.addEventListener('change', (e) => {
        this.state.set('kernelShape', e.target.value);
        this.updateVisualization();
        this.notifyChange();
      });
    }
    
    // Symmetric toggle
    const btnSymmetric = $(this.container, '#btn-symmetric');
    if (btnSymmetric) {
      btnSymmetric.addEventListener('click', () => this.toggleSymmetricMode());
    }
    
    // Reset
    const btnReset = $(this.container, '#btn-reset');
    if (btnReset) {
      btnReset.addEventListener('click', () => this.reset());
    }
    
    // Global mouse events for dragging
    document.addEventListener('mousemove', (e) => this.handleDrag(e));
    document.addEventListener('mouseup', () => this.endDrag());
    
    // Listen for MATLAB messages
    onMatlabMessage((data) => this.handleMatlabMessage(data));
  }

  // ==========================================================================
  // DRAG HANDLERS
  // ==========================================================================

  startDrag(e, target) {
    e.stopPropagation();
    e.preventDefault();
    
    this.state.set({
      isDragging: true,
      dragTarget: target,
      dragStartX: e.clientX,
      dragStartValue: this.state.get('center')
    });
    
    if (target === 'center' && this.centerKnob) {
      this.centerKnob.classList.remove('cursor-grab');
      this.centerKnob.classList.add('cursor-grabbing');
    }
  }

  handleDrag(e) {
    if (!this.state.get('isDragging')) return;
    
    const target = this.state.get('dragTarget');
    const rect = this.selectionRegion.getBoundingClientRect();
    const deltaX = e.clientX - this.state.get('dragStartX');
    const deltaValue = (deltaX / rect.parentElement.offsetWidth) * 
                       (this.state.get('axisMax') - this.state.get('axisMin'));
    
    if (target === 'center') {
      let newCenter = this.state.get('dragStartValue') + deltaValue;
      newCenter = this.clampToAxis(newCenter);
      newCenter = this.state.get('snapFunction')(newCenter);
      this.state.set('center', newCenter);
      this.updateVisualization();
    } else if (target === 'left') {
      const center = this.state.get('center');
      let newLeft = center - (this.state.get('width') / 2) + deltaValue;
      newLeft = this.clampToAxis(newLeft);
      this.state.set('leftBound', newLeft);
      this.updateVisualization();
    } else if (target === 'right') {
      const center = this.state.get('center');
      let newRight = center + (this.state.get('width') / 2) + deltaValue;
      newRight = this.clampToAxis(newRight);
      this.state.set('rightBound', newRight);
      this.updateVisualization();
    }
  }

  endDrag() {
    if (this.state.get('isDragging')) {
      this.state.set('isDragging', false);
      if (this.centerKnob) {
        this.centerKnob.classList.remove('cursor-grabbing');
        this.centerKnob.classList.add('cursor-grab');
      }
      this.notifyChange();
    }
  }

  handleClickToSet(e) {
    const rect = e.target.getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width;
    const value = this.state.get('axisMin') + x * (this.state.get('axisMax') - this.state.get('axisMin'));
    const snapped = this.state.get('snapFunction')(value);
    
    this.state.set('center', this.clampToAxis(snapped));
    this.updateVisualization();
    this.notifyChange();
  }

  handleScroll(e) {
    e.preventDefault();
    
    const delta = -Math.sign(e.deltaY);
    const currentWidth = this.state.get('width');
    const axisRange = this.state.get('axisMax') - this.state.get('axisMin');
    const widthStep = axisRange * 0.02;
    
    let newWidth = currentWidth + (delta * widthStep);
    newWidth = Math.max(axisRange * 0.01, Math.min(axisRange * 0.5, newWidth));
    
    this.state.set('width', newWidth);
    this.updateVisualization();
    this.notifyChange();
  }

  toggleSymmetricMode() {
    const isSymmetric = !this.state.get('isSymmetric');
    this.state.set('isSymmetric', isSymmetric);
    
    if (isSymmetric) {
      this.state.set({ leftBound: null, rightBound: null });
      if (this.leftHandle) this.leftHandle.style.opacity = '0';
      if (this.rightHandle) this.rightHandle.style.opacity = '0';
      this.leftLine.attr('opacity', 0);
      this.rightLine.attr('opacity', 0);
    } else {
      const center = this.state.get('center');
      const width = this.state.get('width');
      this.state.set({
        leftBound: center - width / 2,
        rightBound: center + width / 2
      });
      if (this.leftHandle) this.leftHandle.style.opacity = '1';
      if (this.rightHandle) this.rightHandle.style.opacity = '1';
      this.leftLine.attr('opacity', 0.5);
      this.rightLine.attr('opacity', 0.5);
    }
    
    this.updateVisualization();
    this.notifyChange();
  }

  reset() {
    const axisMin = this.state.get('axisMin');
    const axisMax = this.state.get('axisMax');
    
    this.state.set({
      center: (axisMin + axisMax) / 2,
      width: (axisMax - axisMin) * 0.2,
      leftBound: null,
      rightBound: null,
      isSymmetric: true,
      kernelShape: 'gaussian'
    });
    
    const kernelSelect = $(this.container, '#kernel-shape');
    if (kernelSelect) kernelSelect.value = 'gaussian';
    
    if (this.leftHandle) this.leftHandle.style.opacity = '0';
    if (this.rightHandle) this.rightHandle.style.opacity = '0';
    
    this.updateVisualization();
    this.notifyChange();
  }

  // ==========================================================================
  // RENDERING
  // ==========================================================================

  updateVisualization() {
    this.renderAxisTicks();
    this.renderSelectionRegion();
    this.renderKernelVisualization();
    this.renderValueDisplays();
  }

  renderAxisTicks() {
    const formatter = this.state.get('tickFormatter');
    const min = this.state.get('axisMin');
    const max = this.state.get('axisMax');
    const mid = (min + max) / 2;
    
    const tickMin = $(this.container, '#tick-min');
    const tickMid = $(this.container, '#tick-mid');
    const tickMax = $(this.container, '#tick-max');
    
    if (tickMin) tickMin.textContent = formatter(min);
    if (tickMid) tickMid.textContent = formatter(mid);
    if (tickMax) tickMax.textContent = formatter(max);
    
    const axisLabel = $(this.container, '#axis-label');
    const domainBadge = $(this.container, '#domain-badge');
    
    if (axisLabel) axisLabel.textContent = this.state.get('axisLabel');
    if (domainBadge) domainBadge.textContent = this.state.get('domainType');
  }

  renderSelectionRegion() {
    const center = this.state.get('center');
    const width = this.state.get('width');
    const min = this.state.get('axisMin');
    const max = this.state.get('axisMax');
    const range = max - min;
    
    let leftBound, rightBound;
    if (this.state.get('isSymmetric')) {
      leftBound = center - width / 2;
      rightBound = center + width / 2;
    } else {
      leftBound = this.state.get('leftBound');
      rightBound = this.state.get('rightBound');
    }
    
    const leftNorm = (leftBound - min) / range;
    const rightNorm = (rightBound - min) / range;
    const centerNorm = (center - min) / range;
    
    if (this.selectionRegion) {
      const parentWidth = this.selectionRegion.parentElement.offsetWidth;
      const left = leftNorm * parentWidth;
      const regionWidth = (rightNorm - leftNorm) * parentWidth;
      
      this.selectionRegion.style.left = `${left}px`;
      this.selectionRegion.style.width = `${regionWidth}px`;
    }
    
    if (this.centerKnob) {
      this.centerKnob.style.left = `${(centerNorm - leftNorm) / (rightNorm - leftNorm) * 100}%`;
    }
  }

  renderKernelVisualization() {
    const center = this.state.get('center');
    const width = this.state.get('width');
    const min = this.state.get('axisMin');
    const max = this.state.get('axisMax');
    const shape = this.state.get('kernelShape');
    const resolution = this.state.get('kernelResolution');
    
    if (!this.svg.node()) return;
    
    const svgRect = this.svg.node().getBoundingClientRect();
    const svgWidth = svgRect.width;
    const svgHeight = svgRect.height;
    
    // Generate kernel data
    const kernelData = this.generateKernel(min, max, center, width, shape, resolution);
    
    // Create D3 line generator
    const lineGenerator = line()
      .x((d, i) => (i / (kernelData.length - 1)) * svgWidth)
      .y(d => svgHeight - (d * svgHeight * 0.8));
    
    // Create path data
    const pathData = lineGenerator(kernelData);
    const closedPath = `M 0 ${svgHeight} L${pathData.substring(1)} L ${svgWidth} ${svgHeight} Z`;
    
    // Update kernel path
    this.kernelPath.attr('d', closedPath);
    
    // Update center line using D3
    const centerNorm = (center - min) / (max - min);
    const centerX = centerNorm * svgWidth;
    this.centerLine
      .attr('x1', centerX)
      .attr('x2', centerX)
      .attr('y1', 0)
      .attr('y2', svgHeight);
    
    // Update left/right lines (asymmetric mode)
    if (!this.state.get('isSymmetric')) {
      const leftBound = this.state.get('leftBound');
      const rightBound = this.state.get('rightBound');
      
      const leftX = ((leftBound - min) / (max - min)) * svgWidth;
      const rightX = ((rightBound - min) / (max - min)) * svgWidth;
      
      this.leftLine
        .attr('x1', leftX)
        .attr('x2', leftX)
        .attr('y1', 0)
        .attr('y2', svgHeight);
      
      this.rightLine
        .attr('x1', rightX)
        .attr('x2', rightX)
        .attr('y1', 0)
        .attr('y2', svgHeight);
    }
  }

  renderValueDisplays() {
    const formatter = this.state.get('tickFormatter');
    const center = this.state.get('center');
    const width = this.state.get('width');
    
    const valueCenterSpan = $(this.container, '#value-center');
    const valueWidthSpan = $(this.container, '#value-width');
    
    if (valueCenterSpan) valueCenterSpan.textContent = formatter(center);
    if (valueWidthSpan) valueWidthSpan.textContent = formatter(width);
  }

  // ==========================================================================
  // KERNEL GENERATION
  // ==========================================================================

  generateKernel(min, max, center, width, shape, resolution) {
    const data = new Array(resolution);
    const range = max - min;
    
    for (let i = 0; i < resolution; i++) {
      const x = min + (i / (resolution - 1)) * range;
      const distance = Math.abs(x - center);
      const normalized = distance / (width / 2);
      
      let value;
      switch (shape) {
        case 'gaussian':
          value = Math.exp(-0.5 * normalized * normalized * 9);
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

  // ==========================================================================
  // UTILITIES
  // ==========================================================================

  clampToAxis(value) {
    return Math.max(this.state.get('axisMin'), Math.min(this.state.get('axisMax'), value));
  }

  notifyChange() {
    const center = this.state.get('center');
    const width = this.state.get('width');
    const leftBound = this.state.get('leftBound');
    const rightBound = this.state.get('rightBound');
    const isSymmetric = this.state.get('isSymmetric');
    
    postToMatlab('onChange', {
      center: center,
      width: width,
      leftBound: leftBound,
      rightBound: rightBound,
      isSymmetric: isSymmetric,
      domain: this.state.get('domainType'),
      kernelShape: this.state.get('kernelShape')
    });
  }

  // ==========================================================================
  // MATLAB MESSAGE HANDLER
  // ==========================================================================

  handleMatlabMessage(data) {
    if (!data || !data.cmd) return;
    
    switch (data.cmd) {
      case 'setCenter':
        if (data.value !== undefined) this.setCenter(data.value);
        break;
      case 'setWidth':
        if (data.value !== undefined) this.setWidth(data.value);
        break;
      case 'setAxis':
        if (data.axisSpec) this.setAxis(data.axisSpec);
        break;
      case 'setKernelShape':
        if (data.shape) this.setKernelShape(data.shape);
        break;
      case 'enableAsymmetricMode':
        if (data.enable !== undefined) {
          if (data.enable !== !this.state.get('isSymmetric')) {
            this.toggleSymmetricMode();
          }
        }
        break;
      case 'update':
        if (data.spec) this.updateFromExternalChange(data.spec);
        break;
      case 'reset':
        this.reset();
        break;
    }
  }

  // ==========================================================================
  // PUBLIC API
  // ==========================================================================

  setCenter(value) {
    this.state.set('center', this.clampToAxis(value));
    this.updateVisualization();
  }

  setWidth(value) {
    this.state.set('width', Math.abs(value));
    this.updateVisualization();
  }

  setAxis(axisSpec) {
    this.state.set({
      axisMin: axisSpec.min,
      axisMax: axisSpec.max,
      axisLabel: axisSpec.label || 'Axis',
      domainType: axisSpec.domain || 'generic',
      tickFormatter: axisSpec.tickFormatter || ((x) => x.toFixed(2)),
      snapFunction: axisSpec.snap || ((x) => x)
    });
    this.updateVisualization();
  }

  setKernelShape(shape) {
    this.state.set('kernelShape', shape);
    const kernelSelect = $(this.container, '#kernel-shape');
    if (kernelSelect) kernelSelect.value = shape;
    this.updateVisualization();
  }

  updateFromExternalChange(spec) {
    if (spec.center !== undefined) this.state.set('center', spec.center);
    if (spec.width !== undefined) this.state.set('width', spec.width);
    if (spec.leftBound !== undefined) this.state.set('leftBound', spec.leftBound);
    if (spec.rightBound !== undefined) this.state.set('rightBound', spec.rightBound);
    this.updateVisualization();
  }

  getCurrentKernel() {
    return {
      center: this.state.get('center'),
      width: this.state.get('width'),
      leftBound: this.state.get('leftBound'),
      rightBound: this.state.get('rightBound'),
      isSymmetric: this.state.get('isSymmetric'),
      shape: this.state.get('kernelShape'),
      domain: this.state.get('domainType')
    };
  }
}
