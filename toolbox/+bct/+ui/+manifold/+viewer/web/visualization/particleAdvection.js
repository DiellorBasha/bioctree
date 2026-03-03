/**
 * particleAdvection.js
 * 
 * Surface-constrained particle advection for flow visualization
 * Transports particles along vector fields on triangulated surfaces
 * 
 * Features:
 * - Real-time particle advection in animation loop
 * - Surface-constrained motion (particles stay on mesh)
 * - Face-to-face tracking with boundary crossing
 * - Supports face-based and vertex-based vector fields
 * - Efficient batched updates
 * 
 * Use cases:
 * - Heat diffusion visualization (gradient flow)
 * - Direction field visualization (connection-based flow)
 * - Principal curvature direction flow
 * - Dynamic field visualization
 */

import * as THREE from "three";
import { createParticleSystem, updateParticlePositions } from './particles.js';

/**
 * Particle advection system manager
 * Handles particle transport along vector fields on mesh surface
 */
export class ParticleAdvection {
  constructor(config) {
    const {
      mesh = null,
      vectorField = null,
      numParticles = 1000,
      initialPositions = null,
      stepSize = 0.1,
      particleSize = 2.0,
      particleColor = 0x00ffff,
      fade = true,
      fadeTime = 2.0,
      respawn = true
    } = config;

    this.mesh = mesh;
    this.vectorField = vectorField;  // { support: 'face'|'vertex', data: [nF×3] or [nV×3] }
    this.numParticles = numParticles;
    this.stepSize = stepSize;
    this.fade = fade;
    this.fadeTime = fadeTime;
    this.respawn = respawn;

    // Particle state
    this.positions = null;           // Current positions [nP×3]
    this.faceIndices = null;         // Which face each particle is on [nP]
    this.ages = null;                // Age of each particle (for fading) [nP]
    this.velocities = null;          // Current velocities [nP×3]

    // Three.js objects
    this.particleSystem = null;

    // Mesh data (extracted for fast lookup)
    this.vertices = null;
    this.faces = null;
    this.faceNormals = null;
    this.faceCentroids = null;
    this.faceNeighbors = null;       // [nF×3] neighbor face indices

    // Animation control
    this.isAnimating = false;
    this.time = 0;

    // Initialize if mesh provided
    if (mesh) {
      this.setMesh(mesh);
    }

    if (initialPositions) {
      this.setParticles(initialPositions);
    } else if (mesh) {
      this.initializeParticlesRandom();
    }

    // Create particle system
    this.particleSystem = this._createParticleSystem(particleSize, particleColor);
  }

  /**
   * Set mesh and extract geometry data
   */
  setMesh(mesh) {
    this.mesh = mesh;

    // Extract geometry
    const geometry = mesh.geometry;
    const posAttr = geometry.getAttribute('position');
    const indexAttr = geometry.index;

    if (!posAttr || !indexAttr) {
      console.error('[ParticleAdvection] Mesh missing required attributes');
      return;
    }

    // Extract vertices
    const nV = posAttr.count;
    this.vertices = new Float32Array(nV * 3);
    for (let i = 0; i < nV * 3; i++) {
      this.vertices[i] = posAttr.array[i];
    }

    // Extract faces
    const nF = indexAttr.count / 3;
    this.faces = new Uint32Array(nF * 3);
    for (let i = 0; i < nF * 3; i++) {
      this.faces[i] = indexAttr.array[i];
    }

    // Compute face normals and centroids
    this._computeFaceGeometry();

    // Build face adjacency (for boundary crossing)
    this._buildFaceAdjacency();

    console.log(`[ParticleAdvection] Mesh loaded: ${nV} vertices, ${nF} faces`);
  }

  /**
   * Set vector field for particle advection
   */
  setVectorField(vectorField) {
    this.vectorField = vectorField;
    console.log(`[ParticleAdvection] Vector field set: ${vectorField.support} support, ${vectorField.data.length / 3} vectors`);
  }

  /**
   * Initialize particles at random face centroids
   */
  initializeParticlesRandom() {
    if (!this.mesh) {
      console.error('[ParticleAdvection] No mesh set');
      return;
    }

    const nF = this.faces.length / 3;
    this.positions = new Float32Array(this.numParticles * 3);
    this.faceIndices = new Uint32Array(this.numParticles);
    this.ages = new Float32Array(this.numParticles);
    this.velocities = new Float32Array(this.numParticles * 3);

    for (let i = 0; i < this.numParticles; i++) {
      // Random face
      const faceIdx = Math.floor(Math.random() * nF);
      this.faceIndices[i] = faceIdx;

      // Random position in triangle (barycentric coordinates)
      const bary = this._randomBarycentric();
      const pos = this._barycentricToPosition(faceIdx, bary);

      this.positions[i * 3] = pos[0];
      this.positions[i * 3 + 1] = pos[1];
      this.positions[i * 3 + 2] = pos[2];

      this.ages[i] = 0;
    }

    console.log(`[ParticleAdvection] Initialized ${this.numParticles} random particles`);
  }

  /**
   * Set particle positions explicitly
   */
  setParticles(positions, faceIndices = null) {
    this.numParticles = positions.length / 3;
    this.positions = new Float32Array(positions);
    this.ages = new Float32Array(this.numParticles);
    this.velocities = new Float32Array(this.numParticles * 3);

    if (faceIndices) {
      this.faceIndices = new Uint32Array(faceIndices);
    } else {
      // Find containing face for each particle
      this.faceIndices = new Uint32Array(this.numParticles);
      for (let i = 0; i < this.numParticles; i++) {
        const pos = [
          this.positions[i * 3],
          this.positions[i * 3 + 1],
          this.positions[i * 3 + 2]
        ];
        this.faceIndices[i] = this._findContainingFace(pos);
      }
    }

    console.log(`[ParticleAdvection] Set ${this.numParticles} particles`);
  }

  /**
   * Update particle positions by one time step
   */
  step(dt) {
    if (!this.vectorField || !this.positions) {
      return;
    }

    const nF = this.faces.length / 3;

    for (let i = 0; i < this.numParticles; i++) {
      const faceIdx = this.faceIndices[i];
      if (faceIdx >= nF || faceIdx < 0) {
        // Invalid face - respawn
        if (this.respawn) {
          this._respawnParticle(i);
        }
        continue;
      }

      // Get current position
      const pos = new THREE.Vector3(
        this.positions[i * 3],
        this.positions[i * 3 + 1],
        this.positions[i * 3 + 2]
      );

      // Get velocity from vector field
      const velocity = this._getVelocityAtPosition(pos, faceIdx);

      // Euler integration
      const newPos = new THREE.Vector3(
        pos.x + velocity.x * dt * this.stepSize,
        pos.y + velocity.y * dt * this.stepSize,
        pos.z + velocity.z * dt * this.stepSize
      );

      // Project to face tangent plane
      const normal = new THREE.Vector3(
        this.faceNormals[faceIdx * 3],
        this.faceNormals[faceIdx * 3 + 1],
        this.faceNormals[faceIdx * 3 + 2]
      );

      const centroid = new THREE.Vector3(
        this.faceCentroids[faceIdx * 3],
        this.faceCentroids[faceIdx * 3 + 1],
        this.faceCentroids[faceIdx * 3 + 2]
      );

      // Project: remove component perpendicular to face
      const toPos = newPos.clone().sub(centroid);
      const perp = normal.dot(toPos);
      newPos.sub(normal.clone().multiplyScalar(perp));

      // Check if particle is still in current face
      const bary = this._positionToBarycentric(faceIdx, newPos);
      
      if (this._isInsideTriangle(bary)) {
        // Still in same face
        this.positions[i * 3] = newPos.x;
        this.positions[i * 3 + 1] = newPos.y;
        this.positions[i * 3 + 2] = newPos.z;
      } else {
        // Crossed face boundary - find next face
        const nextFace = this._findNextFace(faceIdx, bary);
        
        if (nextFace >= 0) {
          // Move to next face
          this.faceIndices[i] = nextFace;
          this.positions[i * 3] = newPos.x;
          this.positions[i * 3 + 1] = newPos.y;
          this.positions[i * 3 + 2] = newPos.z;
        } else {
          // Hit boundary or couldn't find next face - respawn
          if (this.respawn) {
            this._respawnParticle(i);
          }
        }
      }

      // Update age
      this.ages[i] += dt;
      if (this.fade && this.ages[i] > this.fadeTime && this.respawn) {
        this._respawnParticle(i);
      }
    }

    // Update particle system
    if (this.particleSystem) {
      updateParticlePositions(this.particleSystem, this.positions);
    }
  }

  /**
   * Start animation loop
   */
  start() {
    this.isAnimating = true;
    console.log('[ParticleAdvection] Animation started');
  }

  /**
   * Stop animation loop
   */
  stop() {
    this.isAnimating = false;
    console.log('[ParticleAdvection] Animation stopped');
  }

  /**
   * Get particle system for adding to scene
   */
  getParticleSystem() {
    return this.particleSystem;
  }

  // ========== Private Methods ==========

  _createParticleSystem(size, color) {
    return createParticleSystem({
      positions: this.positions,
      size: size,
      color: color,
      transparent: true,
      opacity: 0.8,
      sizeAttenuation: true
    });
  }

  _computeFaceGeometry() {
    const nF = this.faces.length / 3;
    this.faceNormals = new Float32Array(nF * 3);
    this.faceCentroids = new Float32Array(nF * 3);

    const v0 = new THREE.Vector3();
    const v1 = new THREE.Vector3();
    const v2 = new THREE.Vector3();
    const e1 = new THREE.Vector3();
    const e2 = new THREE.Vector3();
    const normal = new THREE.Vector3();

    for (let f = 0; f < nF; f++) {
      const i0 = this.faces[f * 3];
      const i1 = this.faces[f * 3 + 1];
      const i2 = this.faces[f * 3 + 2];

      v0.set(this.vertices[i0 * 3], this.vertices[i0 * 3 + 1], this.vertices[i0 * 3 + 2]);
      v1.set(this.vertices[i1 * 3], this.vertices[i1 * 3 + 1], this.vertices[i1 * 3 + 2]);
      v2.set(this.vertices[i2 * 3], this.vertices[i2 * 3 + 1], this.vertices[i2 * 3 + 2]);

      // Centroid
      this.faceCentroids[f * 3] = (v0.x + v1.x + v2.x) / 3;
      this.faceCentroids[f * 3 + 1] = (v0.y + v1.y + v2.y) / 3;
      this.faceCentroids[f * 3 + 2] = (v0.z + v1.z + v2.z) / 3;

      // Normal
      e1.subVectors(v1, v0);
      e2.subVectors(v2, v0);
      normal.crossVectors(e1, e2).normalize();

      this.faceNormals[f * 3] = normal.x;
      this.faceNormals[f * 3 + 1] = normal.y;
      this.faceNormals[f * 3 + 2] = normal.z;
    }
  }

  _buildFaceAdjacency() {
    const nF = this.faces.length / 3;
    this.faceNeighbors = new Int32Array(nF * 3);
    this.faceNeighbors.fill(-1);

    // Build edge-to-face map
    const edgeMap = new Map();

    for (let f = 0; f < nF; f++) {
      const v0 = this.faces[f * 3];
      const v1 = this.faces[f * 3 + 1];
      const v2 = this.faces[f * 3 + 2];

      const edges = [
        [v0, v1, 0],
        [v1, v2, 1],
        [v2, v0, 2]
      ];

      for (const [va, vb, edgeIdx] of edges) {
        const key = va < vb ? `${va}_${vb}` : `${vb}_${va}`;
        
        if (edgeMap.has(key)) {
          // Second face sharing this edge
          const [otherFace, otherEdgeIdx] = edgeMap.get(key);
          this.faceNeighbors[f * 3 + edgeIdx] = otherFace;
          this.faceNeighbors[otherFace * 3 + otherEdgeIdx] = f;
        } else {
          // First face with this edge
          edgeMap.set(key, [f, edgeIdx]);
        }
      }
    }
  }

  _getVelocityAtPosition(pos, faceIdx) {
    if (this.vectorField.support === 'face') {
      // Use face-based vector directly
      return new THREE.Vector3(
        this.vectorField.data[faceIdx * 3],
        this.vectorField.data[faceIdx * 3 + 1],
        this.vectorField.data[faceIdx * 3 + 2]
      );
    } else if (this.vectorField.support === 'vertex') {
      // Interpolate from vertices using barycentric coordinates
      const bary = this._positionToBarycentric(faceIdx, pos);
      const v0 = this.faces[faceIdx * 3];
      const v1 = this.faces[faceIdx * 3 + 1];
      const v2 = this.faces[faceIdx * 3 + 2];

      const vec = new THREE.Vector3();
      vec.x = bary[0] * this.vectorField.data[v0 * 3] +
              bary[1] * this.vectorField.data[v1 * 3] +
              bary[2] * this.vectorField.data[v2 * 3];
      vec.y = bary[0] * this.vectorField.data[v0 * 3 + 1] +
              bary[1] * this.vectorField.data[v1 * 3 + 1] +
              bary[2] * this.vectorField.data[v2 * 3 + 1];
      vec.z = bary[0] * this.vectorField.data[v0 * 3 + 2] +
              bary[1] * this.vectorField.data[v1 * 3 + 2] +
              bary[2] * this.vectorField.data[v2 * 3 + 2];

      return vec;
    }

    return new THREE.Vector3();
  }

  _randomBarycentric() {
    // Random point in triangle using sqrt method
    const r1 = Math.random();
    const r2 = Math.random();
    const sqrt_r1 = Math.sqrt(r1);
    return [1 - sqrt_r1, sqrt_r1 * (1 - r2), sqrt_r1 * r2];
  }

  _barycentricToPosition(faceIdx, bary) {
    const v0idx = this.faces[faceIdx * 3];
    const v1idx = this.faces[faceIdx * 3 + 1];
    const v2idx = this.faces[faceIdx * 3 + 2];

    return [
      bary[0] * this.vertices[v0idx * 3] + bary[1] * this.vertices[v1idx * 3] + bary[2] * this.vertices[v2idx * 3],
      bary[0] * this.vertices[v0idx * 3 + 1] + bary[1] * this.vertices[v1idx * 3 + 1] + bary[2] * this.vertices[v2idx * 3 + 1],
      bary[0] * this.vertices[v0idx * 3 + 2] + bary[1] * this.vertices[v1idx * 3 + 2] + bary[2] * this.vertices[v2idx * 3 + 2]
    ];
  }

  _positionToBarycentric(faceIdx, pos) {
    const v0idx = this.faces[faceIdx * 3];
    const v1idx = this.faces[faceIdx * 3 + 1];
    const v2idx = this.faces[faceIdx * 3 + 2];

    const v0 = new THREE.Vector3(
      this.vertices[v0idx * 3],
      this.vertices[v0idx * 3 + 1],
      this.vertices[v0idx * 3 + 2]
    );
    const v1 = new THREE.Vector3(
      this.vertices[v1idx * 3],
      this.vertices[v1idx * 3 + 1],
      this.vertices[v1idx * 3 + 2]
    );
    const v2 = new THREE.Vector3(
      this.vertices[v2idx * 3],
      this.vertices[v2idx * 3 + 1],
      this.vertices[v2idx * 3 + 2]
    );

    const v0v1 = v1.clone().sub(v0);
    const v0v2 = v2.clone().sub(v0);
    const v0p = pos.clone().sub(v0);

    const d00 = v0v1.dot(v0v1);
    const d01 = v0v1.dot(v0v2);
    const d11 = v0v2.dot(v0v2);
    const d20 = v0p.dot(v0v1);
    const d21 = v0p.dot(v0v2);

    const denom = d00 * d11 - d01 * d01;
    const v = (d11 * d20 - d01 * d21) / denom;
    const w = (d00 * d21 - d01 * d20) / denom;
    const u = 1 - v - w;

    return [u, v, w];
  }

  _isInsideTriangle(bary) {
    return bary[0] >= 0 && bary[1] >= 0 && bary[2] >= 0;
  }

  _findNextFace(currentFace, bary) {
    // Find which edge was crossed (most negative barycentric coordinate)
    let minIdx = 0;
    let minVal = bary[0];
    if (bary[1] < minVal) { minIdx = 1; minVal = bary[1]; }
    if (bary[2] < minVal) { minIdx = 2; }

    // Return neighbor across that edge
    return this.faceNeighbors[currentFace * 3 + minIdx];
  }

  _findContainingFace(pos) {
    // Brute force search (could be optimized with spatial index)
    const p = new THREE.Vector3(pos[0], pos[1], pos[2]);
    const nF = this.faces.length / 3;
    
    for (let f = 0; f < nF; f++) {
      const bary = this._positionToBarycentric(f, p);
      if (this._isInsideTriangle(bary)) {
        return f;
      }
    }

    // Not found - return random face
    return Math.floor(Math.random() * nF);
  }

  _respawnParticle(particleIdx) {
    const nF = this.faces.length / 3;
    const faceIdx = Math.floor(Math.random() * nF);
    this.faceIndices[particleIdx] = faceIdx;

    const bary = this._randomBarycentric();
    const pos = this._barycentricToPosition(faceIdx, bary);

    this.positions[particleIdx * 3] = pos[0];
    this.positions[particleIdx * 3 + 1] = pos[1];
    this.positions[particleIdx * 3 + 2] = pos[2];

    this.ages[particleIdx] = 0;
  }
}
