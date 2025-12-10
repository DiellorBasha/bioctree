/**
 * BCT PlotPanel JavaScript
 * 
 * Manages the plot panel for visualizing meshes, signals, and spectra
 * using HTML5 Canvas and WebGL.
 */

(function() {
    'use strict';
    
    const COMPONENT_ID = 'PlotPanel';
    let state = new BCT.StateManager({
        plotType: 'none',
        viewOptions: {},
        interactionMode: 'rotate',
        data: null,
        camera: { rotation: [0, 0, 0], position: [0, 0, 5], zoom: 1 },
        initialized: false
    });
    
    // DOM elements
    let canvas, canvasContainer, overlay, loading, empty;
    let ctx;
    let statusType, statusVertices, statusFaces, statusMode;
    
    // Interaction state
    let isDragging = false;
    let lastMousePos = { x: 0, y: 0 };
    
    /**
     * Initialize the plot panel component
     */
    function init() {
        canvas = document.getElementById('plotpanel-canvas');
        canvasContainer = document.getElementById('canvas-container');
        overlay = document.getElementById('plotpanel-overlay');
        loading = document.getElementById('plotpanel-loading');
        empty = document.getElementById('plotpanel-empty');
        
        statusType = document.getElementById('status-type');
        statusVertices = document.getElementById('status-vertices');
        statusFaces = document.getElementById('status-faces');
        statusMode = document.getElementById('status-mode');
        
        if (!canvas || !canvasContainer) {
            console.error('PlotPanel elements not found');
            return;
        }
        
        // Get canvas context
        ctx = canvas.getContext('2d');
        
        // Set up canvas sizing
        resizeCanvas();
        window.addEventListener('resize', resizeCanvas);
        
        // Set up toolbar buttons
        setupToolbar();
        
        // Set up canvas interactions
        setupInteractions();
        
        // Set up MATLAB message listener
        setupMessageListener();
        
        // Show empty state initially
        showEmpty();
        
        // Notify MATLAB that component is ready
        BCT.sendToMatlab(COMPONENT_ID, 'ready');
        
        console.log('PlotPanel initialized');
    }
    
    /**
     * Resize canvas to fill container
     */
    function resizeCanvas() {
        const rect = canvasContainer.getBoundingClientRect();
        canvas.width = rect.width;
        canvas.height = rect.height;
        
        // Redraw if we have data
        if (state.get('data')) {
            render();
        }
    }
    
    /**
     * Set up toolbar button handlers
     */
    function setupToolbar() {
        // Interaction mode buttons
        const modeButtons = document.querySelectorAll('[data-mode]');
        modeButtons.forEach(btn => {
            btn.addEventListener('click', function() {
                setInteractionMode(this.getAttribute('data-mode'));
            });
        });
        
        // Reset view
        document.getElementById('btn-reset').addEventListener('click', resetView);
        
        // Export image
        document.getElementById('btn-export').addEventListener('click', exportImage);
        
        // Clear
        document.getElementById('btn-clear').addEventListener('click', clearPlot);
    }
    
    /**
     * Set up canvas interaction handlers
     */
    function setupInteractions() {
        canvas.addEventListener('mousedown', handleMouseDown);
        canvas.addEventListener('mousemove', handleMouseMove);
        canvas.addEventListener('mouseup', handleMouseUp);
        canvas.addEventListener('mouseleave', handleMouseUp);
        canvas.addEventListener('wheel', handleWheel);
        canvas.addEventListener('click', handleClick);
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
                    
                case 'plotMesh':
                    plotMesh(data.data);
                    break;
                    
                case 'plotSignal':
                    plotSignal(data.data);
                    break;
                    
                case 'plotSpectrum':
                    plotSpectrum(data.data);
                    break;
                    
                case 'clear':
                    clearPlot();
                    break;
                    
                case 'setViewOptions':
                    setViewOptions(data.options);
                    break;
                    
                case 'resetView':
                    resetView();
                    break;
                    
                case 'setInteractionMode':
                    setInteractionMode(data.mode);
                    break;
                    
                case 'exportImage':
                    exportImageToFile(data.filename);
                    break;
                    
                default:
                    console.warn('Unknown command:', cmd);
            }
        });
    }
    
    /**
     * Configure the plot panel
     */
    function configure(config) {
        if (!config) return;
        
        state.set({
            plotType: config.plotType || 'none',
            viewOptions: config.viewOptions || {},
            interactionMode: config.interactionMode || 'rotate',
            initialized: true
        });
        
        updateStatus();
    }
    
    /**
     * Plot a mesh
     */
    function plotMesh(data) {
        if (!data || !data.vertices || !data.faces) {
            console.error('Invalid mesh data');
            return;
        }
        
        showLoading();
        
        setTimeout(() => {
            state.set({
                plotType: 'mesh',
                data: data
            });
            
            hideOverlay();
            render();
            updateStatus();
        }, 100);
    }
    
    /**
     * Plot a signal on mesh
     */
    function plotSignal(data) {
        if (!data || !data.vertices || !data.faces || !data.signal) {
            console.error('Invalid signal data');
            return;
        }
        
        showLoading();
        
        setTimeout(() => {
            state.set({
                plotType: 'signal',
                data: data
            });
            
            hideOverlay();
            render();
            updateStatus();
        }, 100);
    }
    
    /**
     * Plot spectrum
     */
    function plotSpectrum(data) {
        if (!data || !data.frequencies || !data.values) {
            console.error('Invalid spectrum data');
            return;
        }
        
        showLoading();
        
        setTimeout(() => {
            state.set({
                plotType: 'spectrum',
                data: data
            });
            
            hideOverlay();
            render();
            updateStatus();
        }, 100);
    }
    
    /**
     * Render the current plot
     */
    function render() {
        const plotType = state.get('plotType');
        const data = state.get('data');
        
        if (!data) {
            clearCanvas();
            return;
        }
        
        clearCanvas();
        
        switch (plotType) {
            case 'mesh':
            case 'signal':
                renderMesh();
                break;
            case 'spectrum':
                renderSpectrum();
                break;
            default:
                clearCanvas();
        }
    }
    
    /**
     * Render mesh (simplified 2D projection)
     */
    function renderMesh() {
        const data = state.get('data');
        const camera = state.get('camera');
        const vertices = data.vertices;
        const faces = data.faces;
        
        if (!vertices || !faces) return;
        
        // Simple 3D to 2D projection
        const projected = projectVertices(vertices, camera);
        
        // Draw faces
        ctx.strokeStyle = '#333';
        ctx.lineWidth = 1;
        
        for (let i = 0; i < faces.length; i++) {
            const face = faces[i];
            const v1 = projected[face[0] - 1]; // MATLAB 1-indexed
            const v2 = projected[face[1] - 1];
            const v3 = projected[face[2] - 1];
            
            if (!v1 || !v2 || !v3) continue;
            
            // Fill with signal color if available
            if (state.get('plotType') === 'signal' && data.signal) {
                const signalVal = (data.signal[face[0] - 1] + 
                                  data.signal[face[1] - 1] + 
                                  data.signal[face[2] - 1]) / 3;
                ctx.fillStyle = getColorFromValue(signalVal, data.clim);
            } else {
                ctx.fillStyle = 'rgba(200, 200, 200, 0.5)';
            }
            
            ctx.beginPath();
            ctx.moveTo(v1.x, v1.y);
            ctx.lineTo(v2.x, v2.y);
            ctx.lineTo(v3.x, v3.y);
            ctx.closePath();
            ctx.fill();
            ctx.stroke();
        }
        
        // Draw info
        ctx.fillStyle = '#333';
        ctx.font = '12px monospace';
        ctx.fillText(`Rotation: [${camera.rotation.map(r => r.toFixed(1)).join(', ')}]`, 10, 20);
    }
    
    /**
     * Render spectrum plot
     */
    function renderSpectrum() {
        const data = state.get('data');
        const freq = data.frequencies;
        const vals = data.values;
        
        if (!freq || !vals) return;
        
        const w = canvas.width;
        const h = canvas.height;
        const padding = 40;
        
        // Find ranges
        const xMin = Math.min(...freq);
        const xMax = Math.max(...freq);
        const yMin = Math.min(...vals);
        const yMax = Math.max(...vals);
        
        // Draw axes
        ctx.strokeStyle = '#333';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(padding, padding);
        ctx.lineTo(padding, h - padding);
        ctx.lineTo(w - padding, h - padding);
        ctx.stroke();
        
        // Draw line
        ctx.strokeStyle = data.lineColor || 'blue';
        ctx.lineWidth = data.lineWidth || 2;
        ctx.beginPath();
        
        for (let i = 0; i < freq.length; i++) {
            const x = padding + ((freq[i] - xMin) / (xMax - xMin)) * (w - 2 * padding);
            const y = h - padding - ((vals[i] - yMin) / (yMax - yMin)) * (h - 2 * padding);
            
            if (i === 0) {
                ctx.moveTo(x, y);
            } else {
                ctx.lineTo(x, y);
            }
        }
        ctx.stroke();
        
        // Labels
        ctx.fillStyle = '#333';
        ctx.font = '12px sans-serif';
        ctx.fillText('Frequency', w / 2 - 30, h - 10);
        ctx.save();
        ctx.translate(15, h / 2);
        ctx.rotate(-Math.PI / 2);
        ctx.fillText('Magnitude', 0, 0);
        ctx.restore();
    }
    
    /**
     * Project 3D vertices to 2D canvas coordinates
     */
    function projectVertices(vertices, camera) {
        const w = canvas.width;
        const h = canvas.height;
        const scale = Math.min(w, h) * 0.3 * camera.zoom;
        const cx = w / 2;
        const cy = h / 2;
        
        return vertices.map(v => {
            // Apply rotation (simplified)
            let x = v[0];
            let y = v[1];
            let z = v[2];
            
            // Rotate around Y axis
            const ry = camera.rotation[1];
            const cosY = Math.cos(ry);
            const sinY = Math.sin(ry);
            const x1 = x * cosY - z * sinY;
            const z1 = x * sinY + z * cosY;
            
            // Rotate around X axis
            const rx = camera.rotation[0];
            const cosX = Math.cos(rx);
            const sinX = Math.sin(rx);
            const y1 = y * cosX - z1 * sinX;
            
            return {
                x: cx + x1 * scale,
                y: cy - y1 * scale
            };
        });
    }
    
    /**
     * Get color from value using colormap
     */
    function getColorFromValue(value, clim) {
        if (!clim || clim.length !== 2) clim = [0, 1];
        const normalized = (value - clim[0]) / (clim[1] - clim[0]);
        const clamped = Math.max(0, Math.min(1, normalized));
        
        // Simple hot colormap
        const r = Math.floor(255 * clamped);
        const g = Math.floor(255 * (clamped - 0.5) * 2);
        const b = Math.floor(255 * Math.max(0, (clamped - 0.75) * 4));
        
        return `rgb(${r}, ${g}, ${b})`;
    }
    
    /**
     * Clear canvas
     */
    function clearCanvas() {
        ctx.fillStyle = 'white';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
    }
    
    /**
     * Clear plot
     */
    function clearPlot() {
        state.set({
            plotType: 'none',
            data: null
        });
        clearCanvas();
        showEmpty();
        updateStatus();
    }
    
    /**
     * Reset view to default
     */
    function resetView() {
        state.set('camera', { rotation: [0, 0, 0], position: [0, 0, 5], zoom: 1 });
        render();
        
        BCT.sendToMatlab(COMPONENT_ID, 'viewChanged', {
            camera: state.get('camera')
        });
    }
    
    /**
     * Set interaction mode
     */
    function setInteractionMode(mode) {
        state.set('interactionMode', mode);
        updateStatus();
        
        // Update button states
        document.querySelectorAll('[data-mode]').forEach(btn => {
            if (btn.getAttribute('data-mode') === mode) {
                btn.classList.add('active');
            } else {
                btn.classList.remove('active');
            }
        });
    }
    
    /**
     * Set view options
     */
    function setViewOptions(options) {
        state.set('viewOptions', options);
        render();
    }
    
    /**
     * Export image
     */
    function exportImage() {
        const imageData = canvas.toDataURL('image/png');
        BCT.sendToMatlab(COMPONENT_ID, 'imageExported', {
            imageData: imageData.split(',')[1], // base64 part only
            filename: 'plot.png'
        });
    }
    
    /**
     * Export image to specific file
     */
    function exportImageToFile(filename) {
        const imageData = canvas.toDataURL('image/png');
        BCT.sendToMatlab(COMPONENT_ID, 'imageExported', {
            imageData: imageData.split(',')[1],
            filename: filename
        });
    }
    
    /**
     * Mouse interaction handlers
     */
    function handleMouseDown(e) {
        isDragging = true;
        lastMousePos = { x: e.clientX, y: e.clientY };
    }
    
    function handleMouseMove(e) {
        if (!isDragging) return;
        
        const mode = state.get('interactionMode');
        const dx = e.clientX - lastMousePos.x;
        const dy = e.clientY - lastMousePos.y;
        
        const camera = state.get('camera');
        
        if (mode === 'rotate') {
            camera.rotation[1] += dx * 0.01;
            camera.rotation[0] += dy * 0.01;
        } else if (mode === 'pan') {
            camera.position[0] += dx * 0.01;
            camera.position[1] -= dy * 0.01;
        }
        
        state.set('camera', camera);
        render();
        
        lastMousePos = { x: e.clientX, y: e.clientY };
    }
    
    function handleMouseUp() {
        if (isDragging) {
            isDragging = false;
            BCT.sendToMatlab(COMPONENT_ID, 'viewChanged', {
                camera: state.get('camera')
            });
        }
    }
    
    function handleWheel(e) {
        e.preventDefault();
        const camera = state.get('camera');
        camera.zoom *= (1 - e.deltaY * 0.001);
        camera.zoom = Math.max(0.1, Math.min(10, camera.zoom));
        state.set('camera', camera);
        render();
    }
    
    function handleClick(e) {
        // TODO: Implement vertex picking
    }
    
    /**
     * Update status bar
     */
    function updateStatus() {
        const plotType = state.get('plotType');
        const data = state.get('data');
        const mode = state.get('interactionMode');
        
        statusType.textContent = `Type: ${plotType}`;
        statusMode.textContent = `Mode: ${mode}`;
        
        if (data && data.vertices) {
            statusVertices.textContent = `Vertices: ${data.vertices.length}`;
            statusFaces.textContent = data.faces ? `Faces: ${data.faces.length}` : 'Faces: 0';
        } else {
            statusVertices.textContent = 'Vertices: 0';
            statusFaces.textContent = 'Faces: 0';
        }
    }
    
    /**
     * Show/hide overlay states
     */
    function showLoading() {
        overlay.style.display = 'flex';
        loading.style.display = 'block';
        empty.style.display = 'none';
    }
    
    function showEmpty() {
        overlay.style.display = 'flex';
        loading.style.display = 'none';
        empty.style.display = 'block';
    }
    
    function hideOverlay() {
        overlay.style.display = 'none';
    }
    
    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
    
})();
