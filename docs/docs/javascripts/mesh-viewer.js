/**
 * Mesh Viewer Embed - Enable Three.js mesh visualization in documentation
 * 
 * Usage in markdown:
 *   <div class="mesh-viewer" 
 *        data-model="../assets/models/mesh.glb"
 *        data-field="../assets/data/field.json"
 *        data-height="500px">
 *   </div>
 */

class MeshViewerEmbed {
    constructor(containerEl, options = {}) {
        this.container = containerEl;
        this.options = {
            width: options.width || '100%',
            height: options.height || '500px',
            modelUrl: options.modelUrl || null,
            fieldUrl: options.fieldUrl || null,
            ...options
        };
        
        this.init();
    }
    
    init() {
        // Create iframe to isolate viewer context
        const iframe = document.createElement('iframe');
        iframe.style.width = this.options.width;
        iframe.style.height = this.options.height;
        iframe.style.border = 'none';
        iframe.style.borderRadius = '8px';
        iframe.style.boxShadow = '0 2px 8px rgba(0,0,0,0.1)';
        iframe.style.backgroundColor = '#f5f5f5';
        
        // Build viewer URL with parameters
        let viewerUrl = '../viewer/viewer-embed.html';
        const params = new URLSearchParams();
        
        if (this.options.modelUrl) {
            params.append('model', this.options.modelUrl);
        }
        
        if (this.options.fieldUrl) {
            params.append('field', this.options.fieldUrl);
        }
        
        if (params.toString()) {
            viewerUrl += '?' + params.toString();
        }
        
        iframe.src = viewerUrl;
        
        // Add loading indicator
        this.container.style.position = 'relative';
        this.container.style.minHeight = this.options.height;
        
        this.container.appendChild(iframe);
    }
}

// Auto-initialize viewers on page load
document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('.mesh-viewer').forEach(el => {
        new MeshViewerEmbed(el, {
            modelUrl: el.dataset.model,
            fieldUrl: el.dataset.field,
            height: el.dataset.height || '500px',
            width: el.dataset.width || '100%'
        });
    });
});

// Export for manual usage
if (typeof window !== 'undefined') {
    window.MeshViewerEmbed = MeshViewerEmbed;
}
