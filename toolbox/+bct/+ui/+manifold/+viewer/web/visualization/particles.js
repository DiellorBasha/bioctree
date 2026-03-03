/**
 * particles.js
 * 
 * GPU-accelerated particle system using THREE.Points and PointsMaterial
 * Much faster than InstancedMesh for large particle counts
 * 
 * Use cases:
 * - Flow visualization (particle traces)
 * - Large point clouds (>10k points)
 * - Animated particles
 * - Glyphs with texture sprites
 * 
 * Tradeoffs vs InstancedMesh spheres:
 * + Much faster rendering (GPU billboards)
 * + Can handle millions of particles
 * + Supports size attenuation (perspective scaling)
 * + Can use texture sprites for custom shapes
 * - Always faces camera (billboarded)
 * - Limited lighting (no 3D shading)
 * - Size in screen pixels, not world units (unless disabled)
 */

import * as THREE from "three";

/**
 * Create a particle system using THREE.Points with PointsMaterial
 * 
 * @param {Object} config - Configuration object
 * @param {Float32Array|Array} config.positions - Positions [x,y,z,x,y,z,...] (flat array)
 * @param {Float32Array|Array} [config.colors] - Per-particle colors [r,g,b,r,g,b,...] (0-1 range)
 * @param {Float32Array|Array} [config.sizes] - Per-particle sizes (optional)
 * @param {number} [config.size=1.0] - Uniform particle size (pixels if sizeAttenuation=true)
 * @param {number|THREE.Color} [config.color=0xffffff] - Uniform color (if no colors array)
 * @param {number} [config.opacity=1.0] - Opacity (0-1)
 * @param {boolean} [config.transparent=false] - Enable transparency
 * @param {boolean} [config.sizeAttenuation=true] - Size affected by distance
 * @param {THREE.Texture} [config.map=null] - Texture for sprite shapes
 * @param {boolean} [config.vertexColors=false] - Use per-vertex colors
 * 
 * @returns {THREE.Points} Points object with PointsMaterial
 */
export function createParticleSystem(config) {
  const {
    positions,
    colors = null,
    sizes = null,
    size = 1.0,
    color = 0xffffff,
    opacity = 1.0,
    transparent = false,
    sizeAttenuation = true,
    map = null,
    vertexColors = false
  } = config;

  if (!positions || positions.length === 0) {
    console.error('[createParticleSystem] No positions provided');
    return new THREE.Points();
  }

  const numParticles = positions.length / 3;

  // Create BufferGeometry
  const geometry = new THREE.BufferGeometry();
  
  // Add position attribute (required)
  const positionArray = positions instanceof Float32Array 
    ? positions 
    : new Float32Array(positions);
  geometry.setAttribute('position', new THREE.BufferAttribute(positionArray, 3));

  // Add color attribute (optional, per-particle colors)
  if (colors && vertexColors) {
    const colorArray = colors instanceof Float32Array 
      ? colors 
      : new Float32Array(colors);
    
    if (colorArray.length !== numParticles * 3) {
      console.warn('[createParticleSystem] Color array length mismatch. Expected', 
        numParticles * 3, 'got', colorArray.length);
    } else {
      geometry.setAttribute('color', new THREE.BufferAttribute(colorArray, 3));
    }
  }

  // Add size attribute (optional, per-particle sizes)
  if (sizes) {
    const sizeArray = sizes instanceof Float32Array 
      ? sizes 
      : new Float32Array(sizes);
    
    if (sizeArray.length !== numParticles) {
      console.warn('[createParticleSystem] Size array length mismatch. Expected', 
        numParticles, 'got', sizeArray.length);
    } else {
      geometry.setAttribute('size', new THREE.BufferAttribute(sizeArray, 1));
    }
  }

  // Create PointsMaterial
  const material = new THREE.PointsMaterial({
    size: size,
    color: color,
    opacity: opacity,
    transparent: transparent,
    sizeAttenuation: sizeAttenuation,
    vertexColors: vertexColors,
    map: map,
    alphaTest: 0.5,  // Discard transparent pixels
    depthWrite: !transparent  // Disable depth write for transparent particles
  });

  // Create Points object
  const points = new THREE.Points(geometry, material);
  points.userData.particleCount = numParticles;
  points.userData.type = 'particleSystem';

  return points;
}

/**
 * Update particle positions (for animation/flow)
 * 
 * @param {THREE.Points} points - Points object
 * @param {Float32Array|Array} newPositions - New positions [x,y,z,...]
 * @param {boolean} [updateBounds=true] - Recompute bounding sphere
 */
export function updateParticlePositions(points, newPositions, updateBounds = true) {
  if (!points || !points.isPoints) {
    console.error('[updateParticlePositions] Invalid Points object');
    return;
  }

  const positionAttr = points.geometry.getAttribute('position');
  
  if (!positionAttr) {
    console.error('[updateParticlePositions] No position attribute found');
    return;
  }

  const expectedLength = positionAttr.count * 3;
  if (newPositions.length !== expectedLength) {
    console.error('[updateParticlePositions] Position count mismatch. Expected', 
      expectedLength, 'got', newPositions.length);
    return;
  }

  // Update position array
  if (newPositions instanceof Float32Array) {
    positionAttr.array.set(newPositions);
  } else {
    for (let i = 0; i < newPositions.length; i++) {
      positionAttr.array[i] = newPositions[i];
    }
  }

  positionAttr.needsUpdate = true;

  // Recompute bounding sphere for frustum culling
  if (updateBounds) {
    points.geometry.computeBoundingSphere();
  }
}

/**
 * Update particle colors (for animation)
 * 
 * @param {THREE.Points} points - Points object
 * @param {Float32Array|Array} newColors - New colors [r,g,b,...] (0-1 range)
 */
export function updateParticleColors(points, newColors) {
  if (!points || !points.isPoints) {
    console.error('[updateParticleColors] Invalid Points object');
    return;
  }

  const colorAttr = points.geometry.getAttribute('color');
  
  if (!colorAttr) {
    console.warn('[updateParticleColors] No color attribute. Enable vertexColors first.');
    return;
  }

  const expectedLength = colorAttr.count * 3;
  if (newColors.length !== expectedLength) {
    console.error('[updateParticleColors] Color count mismatch. Expected', 
      expectedLength, 'got', newColors.length);
    return;
  }

  // Update color array
  if (newColors instanceof Float32Array) {
    colorAttr.array.set(newColors);
  } else {
    for (let i = 0; i < newColors.length; i++) {
      colorAttr.array[i] = newColors[i];
    }
  }

  colorAttr.needsUpdate = true;
}

/**
 * Update particle sizes (for animation)
 * 
 * @param {THREE.Points} points - Points object
 * @param {Float32Array|Array} newSizes - New sizes per particle
 */
export function updateParticleSizes(points, newSizes) {
  if (!points || !points.isPoints) {
    console.error('[updateParticleSizes] Invalid Points object');
    return;
  }

  const sizeAttr = points.geometry.getAttribute('size');
  
  if (!sizeAttr) {
    console.warn('[updateParticleSizes] No size attribute found');
    return;
  }

  const expectedLength = sizeAttr.count;
  if (newSizes.length !== expectedLength) {
    console.error('[updateParticleSizes] Size count mismatch. Expected', 
      expectedLength, 'got', newSizes.length);
    return;
  }

  // Update size array
  if (newSizes instanceof Float32Array) {
    sizeAttr.array.set(newSizes);
  } else {
    for (let i = 0; i < newSizes.length; i++) {
      sizeAttr.array[i] = newSizes[i];
    }
  }

  sizeAttr.needsUpdate = true;
}

/**
 * Create sprite texture for custom particle shapes
 * 
 * @param {string} shape - Shape type: 'circle', 'square', 'cross', 'ring'
 * @param {Object} [config] - Shape configuration
 * @param {number} [config.size=64] - Texture size (power of 2)
 * @param {string} [config.color='white'] - Shape color
 * @param {number} [config.thickness=2] - Line thickness for 'cross' and 'ring'
 * @param {number} [config.innerRadius=0.3] - Inner radius for 'ring' (0-1)
 * 
 * @returns {THREE.Texture} Canvas texture for PointsMaterial.map
 */
export function createParticleTexture(shape, config = {}) {
  const {
    size = 64,
    color = 'white',
    thickness = 2,
    innerRadius = 0.3
  } = config;

  // Create canvas
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');

  const center = size / 2;
  const radius = size / 2 - 2;

  ctx.clearRect(0, 0, size, size);
  ctx.fillStyle = color;
  ctx.strokeStyle = color;
  ctx.lineWidth = thickness;

  switch (shape) {
    case 'circle':
      // Filled circle with soft edge
      const gradient = ctx.createRadialGradient(center, center, 0, center, center, radius);
      gradient.addColorStop(0, color);
      gradient.addColorStop(0.8, color);
      gradient.addColorStop(1, 'transparent');
      ctx.fillStyle = gradient;
      ctx.beginPath();
      ctx.arc(center, center, radius, 0, Math.PI * 2);
      ctx.fill();
      break;

    case 'square':
      ctx.fillRect(2, 2, size - 4, size - 4);
      break;

    case 'cross':
      // Draw cross
      ctx.beginPath();
      ctx.moveTo(center, thickness);
      ctx.lineTo(center, size - thickness);
      ctx.moveTo(thickness, center);
      ctx.lineTo(size - thickness, center);
      ctx.stroke();
      break;

    case 'ring':
      // Draw ring (hollow circle)
      ctx.beginPath();
      ctx.arc(center, center, radius, 0, Math.PI * 2);
      ctx.arc(center, center, radius * innerRadius, 0, Math.PI * 2, true);
      ctx.fill();
      break;

    default:
      console.warn('[createParticleTexture] Unknown shape:', shape);
      // Default to circle
      ctx.beginPath();
      ctx.arc(center, center, radius, 0, Math.PI * 2);
      ctx.fill();
  }

  // Create Three.js texture
  const texture = new THREE.CanvasTexture(canvas);
  texture.needsUpdate = true;

  return texture;
}

/**
 * Example: Create animated particle trail for flow visualization
 * 
 * @param {Array<Array<THREE.Vector3>>} streamlines - Array of streamline paths
 * @param {Object} [config] - Configuration
 * @param {number} [config.pointsPerLine=50] - Number of particles per streamline
 * @param {number} [config.size=2.0] - Particle size
 * @param {THREE.Color} [config.color] - Particle color
 * 
 * @returns {THREE.Points} Animated particle system
 */
export function createFlowParticles(streamlines, config = {}) {
  const {
    pointsPerLine = 50,
    size = 2.0,
    color = new THREE.Color(0x00ffff)
  } = config;

  const positions = [];
  const colors = [];

  streamlines.forEach((line, lineIndex) => {
    const lineColor = new THREE.Color().setHSL(lineIndex / streamlines.length, 0.8, 0.5);
    
    for (let i = 0; i < pointsPerLine; i++) {
      const t = i / pointsPerLine;
      const pointIndex = Math.floor(t * (line.length - 1));
      const point = line[pointIndex];

      positions.push(point.x, point.y, point.z);
      colors.push(lineColor.r, lineColor.g, lineColor.b);
    }
  });

  return createParticleSystem({
    positions: new Float32Array(positions),
    colors: new Float32Array(colors),
    size: size,
    vertexColors: true,
    transparent: true,
    opacity: 0.8,
    sizeAttenuation: true
  });
}
