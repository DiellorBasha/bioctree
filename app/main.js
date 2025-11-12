/**
 * Main application script for BCT Viewer
 */

import { BCTViewer } from './js/bctViewer.js';

class App {
    constructor() {
        this.viewer = null;
        this.init();
    }
    
    init() {
        // Initialize viewer
        const container = document.getElementById('viewer-container');
        this.viewer = new BCTViewer(container);
        
        // Setup event listeners
        this.setupEventListeners();
        
        // Load default mesh
        this.loadDefaultMesh();
    }
    
    setupEventListeners() {
        // File input
        document.getElementById('bct-file').addEventListener('change', this.handleFileLoad.bind(this));
        
        // Mesh controls
        document.getElementById('mesh-type').addEventListener('change', this.handleMeshTypeChange.bind(this));
        document.getElementById('hemisphere').addEventListener('change', this.handleHemisphereChange.bind(this));
        
        // Action buttons
        document.getElementById('load-fsaverage').addEventListener('click', this.loadFsaverage.bind(this));
        document.getElementById('create-example').addEventListener('click', this.createExample.bind(this));
        document.getElementById('export-glb').addEventListener('click', this.exportGLB.bind(this));
        document.getElementById('clear-scene').addEventListener('click', this.clearScene.bind(this));
        
        // View controls
        document.getElementById('view-front').addEventListener('click', () => this.setView('front'));
        document.getElementById('view-back').addEventListener('click', () => this.setView('back'));
        document.getElementById('view-left').addEventListener('click', () => this.setView('left'));
        document.getElementById('view-right').addEventListener('click', () => this.setView('right'));
        document.getElementById('view-top').addEventListener('click', () => this.setView('top'));
        document.getElementById('view-bottom').addEventListener('click', () => this.setView('bottom'));
        
        // Toggle controls
        document.getElementById('toggle-controls').addEventListener('click', this.toggleControlsPanel.bind(this));
    }
    
    async handleFileLoad(event) {
        const file = event.target.files[0];
        if (!file) return;
        
        try {
            this.viewer.setStatus('Loading BCT file...');
            
            const text = await file.text();
            const bctData = JSON.parse(text);
            
            await this.viewer.visualizeBCT(bctData);
            this.viewer.setStatus(`Loaded ${file.name}`);
            
        } catch (error) {
            console.error('Error loading BCT file:', error);
            this.viewer.setStatus('Error loading BCT file');
            alert('Error loading BCT file. Please check the file format.');
        }
    }
    
    async handleMeshTypeChange() {
        if (this.viewer) {
            const meshType = document.getElementById('mesh-type').value;
            const hemisphere = document.getElementById('hemisphere').value;
            await this.viewer.loadFsaverageMesh(meshType, hemisphere);
        }
    }
    
    async handleHemisphereChange() {
        if (this.viewer) {
            const meshType = document.getElementById('mesh-type').value;
            const hemisphere = document.getElementById('hemisphere').value;
            await this.viewer.loadFsaverageMesh(meshType, hemisphere);
        }
    }
    
    async loadFsaverage() {
        if (this.viewer) {
            const meshType = document.getElementById('mesh-type').value;
            const hemisphere = document.getElementById('hemisphere').value;
            await this.viewer.loadFsaverageMesh(meshType, hemisphere);
        }
    }
    
    async createExample() {
        if (this.viewer) {
            await this.viewer.createExampleBCT();
        }
    }
    
    async exportGLB() {
        if (this.viewer) {
            await this.viewer.exportToGLB();
        }
    }
    
    clearScene() {
        if (this.viewer) {
            this.viewer.clearMeshes();
            this.viewer.setStatus('Scene cleared');
        }
    }
    
    setView(direction) {
        if (!this.viewer || !this.viewer.camera) return;
        
        const camera = this.viewer.camera;
        const controls = this.viewer.controls;
        const distance = 100;
        
        switch (direction) {
            case 'front':
                camera.position.set(0, 0, distance);
                break;
            case 'back':
                camera.position.set(0, 0, -distance);
                break;
            case 'left':
                camera.position.set(-distance, 0, 0);
                break;
            case 'right':
                camera.position.set(distance, 0, 0);
                break;
            case 'top':
                camera.position.set(0, distance, 0);
                break;
            case 'bottom':
                camera.position.set(0, -distance, 0);
                break;
        }
        
        camera.lookAt(0, 0, 0);
        controls.update();
    }
    
    toggleControlsPanel() {
        const panel = document.getElementById('controls-panel');
        const button = document.getElementById('toggle-controls');
        
        if (panel.classList.contains('collapsed')) {
            panel.classList.remove('collapsed');
            button.textContent = 'Hide Controls';
        } else {
            panel.classList.add('collapsed');
            button.textContent = 'Show Controls';
        }
    }
    
    async loadDefaultMesh() {
        // Load default brain mesh on startup
        setTimeout(async () => {
            await this.loadFsaverage();
        }, 100);
    }
}

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new App();
});