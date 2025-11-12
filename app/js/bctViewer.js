/**
 * BCT Viewer - Main Three.js visualization class
 */

import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { BCTConverter } from './utils/bctConverter.js';
import { NumpyLoader } from './utils/numpyLoader.js';

export class BCTViewer {
    constructor(container) {
        this.container = container;
        this.scene = null;
        this.camera = null;
        this.renderer = null;
        this.controls = null;
        this.meshes = {};
        this.currentBCT = null;
        this.stats = {
            vertices: 0,
            faces: 0,
            fps: 0
        };
        
        this.init();
        this.animate();
    }
    
    init() {
        // Scene
        this.scene = new THREE.Scene();
        this.scene.background = new THREE.Color(0x1a1a1a);
        
        // Camera
        this.camera = new THREE.PerspectiveCamera(
            75,
            this.container.clientWidth / this.container.clientHeight,
            0.1,
            1000
        );
        this.camera.position.set(0, 0, 100);
        
        // Renderer
        this.renderer = new THREE.WebGLRenderer({ antialias: true });
        this.renderer.setSize(this.container.clientWidth, this.container.clientHeight);
        this.renderer.setPixelRatio(window.devicePixelRatio);
        this.renderer.shadowMap.enabled = true;
        this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
        this.container.appendChild(this.renderer.domElement);
        
        // Controls
        this.controls = new OrbitControls(this.camera, this.renderer.domElement);
        this.controls.enableDamping = true;
        this.controls.dampingFactor = 0.05;
        this.controls.screenSpacePanning = false;
        this.controls.minDistance = 10;
        this.controls.maxDistance = 500;
        
        // Lighting
        this.setupLighting();
        
        // Event listeners
        window.addEventListener('resize', this.onWindowResize.bind(this));
    }
    
    setupLighting() {
        // Ambient light
        const ambientLight = new THREE.AmbientLight(0x404040, 0.6);
        this.scene.add(ambientLight);
        
        // Directional light
        const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
        directionalLight.position.set(50, 50, 50);
        directionalLight.castShadow = true;
        directionalLight.shadow.mapSize.width = 2048;
        directionalLight.shadow.mapSize.height = 2048;
        this.scene.add(directionalLight);
        
        // Point light for better brain surface illumination
        const pointLight = new THREE.PointLight(0x4a90e2, 0.4, 200);
        pointLight.position.set(-50, 20, 50);
        this.scene.add(pointLight);
    }
    
    async loadFsaverageMesh(meshType = 'brain', hemisphere = 'both') {
        this.clearMeshes();
        this.setStatus('Loading mesh data...');
        
        try {
            const basePath = '../test-data/mesh/fsaverage';
            const meshPromises = [];
            
            if (hemisphere === 'both' || hemisphere === 'left') {
                meshPromises.push(this.loadHemisphereMesh(basePath, 'left', meshType));
            }
            
            if (hemisphere === 'both' || hemisphere === 'right') {
                meshPromises.push(this.loadHemisphereMesh(basePath, 'right', meshType));
            }
            
            await Promise.all(meshPromises);
            this.updateStats();
            this.setStatus('Mesh loaded successfully');
            
        } catch (error) {
            console.error('Error loading fsaverage mesh:', error);
            this.setStatus('Error loading mesh');
        }
    }
    
    async loadHemisphereMesh(basePath, hemisphere, meshType) {
        try {
            let meshData;
            
            if (meshType === 'sphere') {
                // Load sphere mesh
                meshData = await NumpyLoader.loadMeshData(basePath, hemisphere);
                // Use sphere coordinates instead of brain coordinates
                const sphereCoords = await NumpyLoader.loadFloat32Array(`${basePath}/${hemisphere === 'left' ? 'lh' : 'rh'}_sphere_coords.npy`);
                meshData.vertices = sphereCoords.data;
            } else {
                // Load brain surface mesh
                meshData = await NumpyLoader.loadMeshData(basePath, hemisphere);
            }
            
            // Create Three.js geometry
            const geometry = new THREE.BufferGeometry();
            geometry.setAttribute('position', new THREE.BufferAttribute(meshData.vertices, 3));
            geometry.setIndex(new THREE.BufferAttribute(meshData.faces, 1));
            geometry.computeVertexNormals();
            
            // Create material
            const color = hemisphere === 'left' ? 0xcd853f : 0xd2b48c;
            const material = new THREE.MeshLambertMaterial({ 
                color: color,
                side: THREE.DoubleSide
            });
            
            // Create mesh
            const mesh = new THREE.Mesh(geometry, material);
            
            // Position right hemisphere
            if (hemisphere === 'right') {
                mesh.position.x = meshType === 'sphere' ? 0 : 80;
            }
            
            this.scene.add(mesh);
            this.meshes[hemisphere] = mesh;
            
        } catch (error) {
            console.error(`Error loading ${hemisphere} hemisphere:`, error);
            throw error;
        }
    }
    
    async createExampleBCT() {
        this.setStatus('Loading example BCT GLB file...');
        
        try {
            // Load a pre-generated GLB file instead of creating BCT
            await this.loadBCTGLB('data/fsaverage_lh_geodesic.glb', 'fsaverage left hemisphere');
            
            this.setStatus('Example BCT GLB loaded successfully');
            
        } catch (error) {
            console.error('Error loading example BCT GLB:', error);
            this.setStatus('Error loading example BCT GLB');
        }
    }
    
    async loadBCTGLB(glbPath, description = '') {
        this.setStatus(`Loading ${description || glbPath}...`);
        
        try {
            const loader = new GLTFLoader();
            
            return new Promise((resolve, reject) => {
                loader.load(
                    glbPath,
                    (gltf) => {
                        this.clearMeshes();
                        
                        // Add the loaded model to the scene
                        const model = gltf.scene;
                        this.scene.add(model);
                        
                        // Store reference for cleanup
                        this.meshes.bctModel = model;
                        
                        // Update stats
                        this.updateGLBStats(model);
                        
                        this.setStatus(`Loaded ${description || glbPath}`);
                        resolve(model);
                    },
                    (progress) => {
                        const percent = (progress.loaded / progress.total * 100) || 0;
                        this.setStatus(`Loading ${description}... ${percent.toFixed(0)}%`);
                    },
                    (error) => {
                        console.error('Error loading GLB:', error);
                        this.setStatus('Error loading GLB file');
                        reject(error);
                    }
                );
            });
            
        } catch (error) {
            console.error('Error in loadBCTGLB:', error);
            this.setStatus('Error loading BCT GLB');
            throw error;
        }
    }
    
    async visualizeBCT(bctData) {
        this.clearMeshes();
        
        try {
            const coords = bctData.graph.nodes.coords;
            const edges = {
                i: bctData.graph.edges.coo_i,
                j: bctData.graph.edges.coo_j,
                w: bctData.graph.edges.coo_w
            };
            
            // Create node visualization
            this.visualizeNodes(coords);
            
            // Create edge visualization (sample for performance)
            this.visualizeEdges(coords, edges, 1000); // Show only first 1000 edges
            
        } catch (error) {
            console.error('Error visualizing BCT data:', error);
            throw error;
        }
    }
    
    visualizeNodes(coords) {
        const geometry = new THREE.SphereGeometry(0.5, 8, 6);
        const material = new THREE.MeshLambertMaterial({ color: 0x4a90e2 });
        
        coords.forEach((coord, index) => {
            const mesh = new THREE.Mesh(geometry, material);
            mesh.position.set(coord[0], coord[1], coord[2]);
            this.scene.add(mesh);
        });
    }
    
    visualizeEdges(coords, edges, maxEdges) {
        const material = new THREE.LineBasicMaterial({ 
            color: 0x888888, 
            opacity: 0.3, 
            transparent: true 
        });
        
        const geometry = new THREE.BufferGeometry();
        const positions = [];
        
        const edgeCount = Math.min(edges.i.length, maxEdges);
        for (let i = 0; i < edgeCount; i++) {
            const startCoord = coords[edges.i[i]];
            const endCoord = coords[edges.j[i]];
            
            positions.push(
                startCoord[0], startCoord[1], startCoord[2],
                endCoord[0], endCoord[1], endCoord[2]
            );
        }
        
        geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
        const lines = new THREE.LineSegments(geometry, material);
        this.scene.add(lines);
    }
    
    async exportToGLB() {
        if (!this.currentBCT) {
            alert('No BCT data loaded to export');
            return;
        }
        
        try {
            this.setStatus('Exporting to GLB...');
            
            const blob = await BCTConverter.exportToGLB(this.scene);
            const filename = `bct_export_${new Date().toISOString().slice(0, 10)}.glb`;
            
            BCTConverter.downloadBlob(blob, filename);
            this.setStatus('GLB exported successfully');
            
        } catch (error) {
            console.error('Error exporting GLB:', error);
            this.setStatus('Error exporting GLB');
        }
    }
    
    clearMeshes() {
        Object.values(this.meshes).forEach(mesh => {
            this.scene.remove(mesh);
            if (mesh.geometry) mesh.geometry.dispose();
            if (mesh.material) mesh.material.dispose();
        });
        this.meshes = {};
        
        // Clear all other objects except lights
        const objectsToRemove = [];
        this.scene.traverse((object) => {
            if (object.type === 'Mesh' || object.type === 'LineSegments') {
                objectsToRemove.push(object);
            }
        });
        objectsToRemove.forEach(obj => this.scene.remove(obj));
    }
    
    updateStats() {
        let vertices = 0, faces = 0;
        
        Object.values(this.meshes).forEach(mesh => {
            if (mesh.geometry) {
                vertices += mesh.geometry.attributes.position.count;
                if (mesh.geometry.index) {
                    faces += mesh.geometry.index.count / 3;
                }
            }
        });
        
        this.stats.vertices = vertices;
        this.stats.faces = Math.floor(faces);
        
        // Update UI
        document.getElementById('vertices').textContent = vertices.toLocaleString();
        document.getElementById('faces').textContent = this.stats.faces.toLocaleString();
    }
    
    updateGLBStats(model) {
        let vertices = 0, faces = 0;
        
        model.traverse((child) => {
            if (child.isMesh && child.geometry) {
                vertices += child.geometry.attributes.position.count;
                if (child.geometry.index) {
                    faces += child.geometry.index.count / 3;
                }
            }
        });
        
        this.stats.vertices = vertices;
        this.stats.faces = Math.floor(faces);
        
        // Update UI
        document.getElementById('vertices').textContent = vertices.toLocaleString();
        document.getElementById('faces').textContent = this.stats.faces.toLocaleString();
    }
    
    setStatus(message) {
        document.getElementById('status').textContent = message;
    }
    
    onWindowResize() {
        this.camera.aspect = this.container.clientWidth / this.container.clientHeight;
        this.camera.updateProjectionMatrix();
        this.renderer.setSize(this.container.clientWidth, this.container.clientHeight);
    }
    
    animate() {
        requestAnimationFrame(this.animate.bind(this));
        
        this.controls.update();
        this.renderer.render(this.scene, this.camera);
        
        // Update FPS (simplified)
        this.stats.fps = Math.round(1000 / 16.67); // Approximate 60 FPS
        document.getElementById('fps').textContent = this.stats.fps;
    }
}