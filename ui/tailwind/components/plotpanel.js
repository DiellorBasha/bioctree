/**
 * BCT PlotPanel Component
 * Interactive 2D/3D visualization container
 */

(function() {
  'use strict';

  // ============================================================================
  // STATE & CONFIGURATION
  // ============================================================================

  const state = new BCT.StateManager({
    mode: 'rotate',
    data: null,
    camera: { x: 0, y: 0, zoom: 1 },
    isLoading: false,
    stats: { vertices: 0, fps: 0 }
  });

  let canvas2d, ctx2d, svgLayer, webglContainer;
  let isDragging = false;
  let lastMouse = { x: 0, y: 0 };
  let fpsCounter = { frames: 0, lastTime: Date.now() };

  // ============================================================================
  // RENDERING
  // ============================================================================

  /**
   * Clear all rendering layers
   */
  function clearLayers() {
    if (ctx2d) {
      ctx2d.clearRect(0, 0, canvas2d.width, canvas2d.height);
    }
    if (svgLayer) {
      BCT.$('#svg-content').innerHTML = '';
    }
  }

  /**
   * Update status bar
   */
  function updateStatus() {
    const mode = state.get('mode');
    const stats = state.get('stats');

    BCT.$('#status-mode span').textContent = mode.charAt(0).toUpperCase() + mode.slice(1);
    BCT.$('#status-vertices').textContent = `Vertices: ${stats.vertices}`;
    BCT.$('#status-fps').textContent = `FPS: ${stats.fps}`;
  }

  /**
   * Update coordinate display
   */
  function updateCoords(x, y) {
    BCT.$('#status-coords').textContent = `X: ${x.toFixed(2)}, Y: ${y.toFixed(2)}`;
  }

  /**
   * Show/hide loading overlay
   */
  function setLoading(loading) {
    state.set('isLoading', loading);
    const overlay = BCT.$('#loading-overlay');
    if (loading) {
      overlay.classList.remove('hidden');
    } else {
      overlay.classList.add('hidden');
    }
  }

  /**
   * Calculate FPS
   */
  function updateFPS() {
    fpsCounter.frames++;
    const now = Date.now();
    const delta = now - fpsCounter.lastTime;
    
    if (delta >= 1000) {
      const fps = Math.round((fpsCounter.frames * 1000) / delta);
      const stats = state.get('stats');
      stats.fps = fps;
      state.set({ stats });
      updateStatus();
      
      fpsCounter.frames = 0;
      fpsCounter.lastTime = now;
    }
  }

  // ============================================================================
  // INTERACTION
  // ============================================================================

  /**
   * Handle mouse down
   */
  function handleMouseDown(e) {
    isDragging = true;
    lastMouse = { x: e.clientX, y: e.clientY };
    BCT.$('#plot-canvas').style.cursor = 'grabbing';
  }

  /**
   * Handle mouse move
   */
  function handleMouseMove(e) {
    const rect = BCT.$('#plot-canvas').getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width;
    const y = (e.clientY - rect.top) / rect.height;
    updateCoords(x, y);

    if (!isDragging) return;

    const dx = e.clientX - lastMouse.x;
    const dy = e.clientY - lastMouse.y;
    lastMouse = { x: e.clientX, y: e.clientY };

    const mode = state.get('mode');
    const camera = state.get('camera');

    switch (mode) {
      case 'rotate':
        BCT.sendToMatlab('rotate', { dx, dy });
        break;
      case 'pan':
        camera.x += dx;
        camera.y += dy;
        state.set({ camera });
        BCT.sendToMatlab('pan', { dx, dy });
        break;
      case 'zoom':
        camera.zoom *= (1 + dy * 0.01);
        camera.zoom = BCT.clamp(camera.zoom, 0.1, 10);
        state.set({ camera });
        BCT.sendToMatlab('zoom', { delta: dy });
        break;
    }
  }

  /**
   * Handle mouse up
   */
  function handleMouseUp(e) {
    isDragging = false;
    BCT.$('#plot-canvas').style.cursor = 'default';
  }

  /**
   * Handle mouse wheel
   */
  const handleWheel = BCT.throttle((e) => {
    e.preventDefault();
    const camera = state.get('camera');
    const delta = e.deltaY > 0 ? 0.9 : 1.1;
    camera.zoom *= delta;
    camera.zoom = BCT.clamp(camera.zoom, 0.1, 10);
    state.set({ camera });
    
    BCT.sendToMatlab('zoom', { delta: e.deltaY });
  }, 50);

  /**
   * Set interaction mode
   */
  function setMode(mode) {
    state.set('mode', mode);
    
    // Update button states
    BCT.$$('.mode-btn').forEach(btn => {
      if (btn.dataset.mode === mode) {
        btn.classList.add('active', 'bg-bct-primary', 'text-white');
      } else {
        btn.classList.remove('active', 'bg-bct-primary', 'text-white');
      }
    });

    updateStatus();
    BCT.sendToMatlab('modeChanged', { mode });
  }

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  /**
   * Initialize plot panel
   */
  function init() {
    // Get elements
    canvas2d = BCT.$('#canvas-2d');
    svgLayer = BCT.$('#svg-layer');
    webglContainer = BCT.$('#webgl-container');
    
    if (canvas2d) {
      ctx2d = canvas2d.getContext('2d');
      // Set canvas size
      const resize = () => {
        canvas2d.width = canvas2d.offsetWidth;
        canvas2d.height = canvas2d.offsetHeight;
      };
      resize();
      window.addEventListener('resize', resize);
    }

    // Setup event listeners
    const canvas = BCT.$('#plot-canvas');
    BCT.on(canvas, 'mousedown', handleMouseDown);
    BCT.on(canvas, 'mousemove', handleMouseMove);
    BCT.on(canvas, 'mouseup', handleMouseUp);
    BCT.on(canvas, 'mouseleave', handleMouseUp);
    BCT.on(canvas, 'wheel', handleWheel);

    // Mode buttons
    BCT.$$('.mode-btn').forEach(btn => {
      BCT.on(btn, 'click', () => setMode(btn.dataset.mode));
    });

    // Action buttons
    BCT.on(BCT.$('#reset-view'), 'click', resetView);
    BCT.on(BCT.$('#export-image'), 'click', exportImage);

    // Initial status
    updateStatus();

    // Start FPS counter
    const fpsLoop = () => {
      updateFPS();
      BCT.raf(fpsLoop);
    };
    fpsLoop();

    // Notify MATLAB
    BCT.sendToMatlab('plotPanelReady');
  }

  /**
   * Plot mesh data
   */
  function plotMesh(data) {
    setLoading(true);
    
    // Store data
    state.set('data', data);
    
    // Update stats
    const stats = state.get('stats');
    stats.vertices = data.vertices?.length || 0;
    state.set({ stats });
    
    // Clear layers
    clearLayers();
    
    // Send to MATLAB for rendering
    BCT.sendToMatlab('renderMesh', { data });
    
    setTimeout(() => setLoading(false), 500);
  }

  /**
   * Plot signal on mesh
   */
  function plotSignal(signal, options = {}) {
    setLoading(true);
    
    BCT.sendToMatlab('renderSignal', { 
      signal, 
      options 
    });
    
    setTimeout(() => setLoading(false), 500);
  }

  /**
   * Plot spectrum
   */
  function plotSpectrum(spectrum, options = {}) {
    setLoading(true);
    
    // Use SVG for 2D spectrum plot
    svgLayer.classList.remove('hidden');
    canvas2d.classList.add('hidden');
    
    BCT.sendToMatlab('renderSpectrum', { 
      spectrum, 
      options 
    });
    
    setTimeout(() => setLoading(false), 500);
  }

  /**
   * Clear plot
   */
  function clear() {
    clearLayers();
    state.set({ 
      data: null,
      stats: { vertices: 0, fps: 0 }
    });
    updateStatus();
  }

  /**
   * Reset view
   */
  function resetView() {
    state.set({
      camera: { x: 0, y: 0, zoom: 1 }
    });
    BCT.sendToMatlab('resetView');
    BCT.notify.show('View reset', 'info', 2000);
  }

  /**
   * Export current view as image
   */
  function exportImage() {
    // For canvas
    if (!canvas2d.classList.contains('hidden')) {
      const dataURL = canvas2d.toDataURL('image/png');
      downloadImage(dataURL);
    } 
    // For SVG
    else if (!svgLayer.classList.contains('hidden')) {
      const svgData = new XMLSerializer().serializeToString(svgLayer);
      const blob = new Blob([svgData], { type: 'image/svg+xml' });
      const url = URL.createObjectURL(blob);
      downloadImage(url, 'svg');
    }
    // For WebGL - request from MATLAB
    else {
      BCT.sendToMatlab('exportImage');
    }
    
    BCT.notify.show('Image exported', 'success', 2000);
  }

  /**
   * Download image helper
   */
  function downloadImage(url, format = 'png') {
    const a = document.createElement('a');
    a.href = url;
    a.download = `bct-plot-${Date.now()}.${format}`;
    a.click();
  }

  /**
   * Handle message from MATLAB
   */
  function onMessage(data) {
    switch (data.cmd) {
      case 'plotMesh':
        plotMesh(data.data);
        break;
      case 'plotSignal':
        plotSignal(data.signal, data.options);
        break;
      case 'plotSpectrum':
        plotSpectrum(data.spectrum, data.options);
        break;
      case 'clear':
        clear();
        break;
      case 'resetView':
        resetView();
        break;
      case 'setMode':
        setMode(data.mode);
        break;
      case 'updateData':
        // Handle real-time data updates
        state.set('data', data.data);
        break;
      default:
        console.warn('Unknown command:', data.cmd);
    }
  }

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  // Setup message handler
  BCT.onMatlabMessage(onMessage);

  // Initialize on load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // Export API
  window.BctPlotPanel = {
    init,
    plotMesh,
    plotSignal,
    plotSpectrum,
    clear,
    resetView,
    exportImage,
    setMode,
    getState: () => state.get()
  };

})();
