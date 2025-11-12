function export_freesurfer_to_glb(vertices, faces, filename, varargin)
%EXPORT_FREESURFER_TO_GLB Export FreeSurfer surface to GLB format
%   export_freesurfer_to_glb(vertices, faces, filename)
%   export_freesurfer_to_glb(vertices, faces, filename, 'UVCoords', uv_coords)
%   export_freesurfer_to_glb(vertices, faces, filename, 'Normals', normals)
%   export_freesurfer_to_glb(vertices, faces, filename, 'Texture', texture_path)
%
%   Exports FreeSurfer surface data to GLB (Binary glTF) format for three.js
%
%   Parameters:
%       vertices : Nx3 matrix of vertex coordinates
%       faces    : Mx3 matrix of face indices (1-based)
%       filename : output GLB filename
%       
%   Optional Name-Value pairs:
%       'UVCoords'    - Nx2 UV texture coordinates [0,1]
%       'Normals'     - Nx3 vertex normals (computed if not provided)
%       'Texture'     - Path to texture image file to embed
%       'Colors'      - Nx3 vertex colors [0,1]
%       'Scalars'     - Nx1 scalar data (e.g., curvature, thickness)
%
%   Example:
%       subject = in_fs_read_subject('test-data/freesurfer', 'fsaverage');
%       % Compute UV coordinates from sphere
%       uv_coords = compute_uv_from_sphere(subject.lh.sphere.vertices);
%       export_freesurfer_to_glb(subject.lh.pial.vertices, subject.lh.pial.faces, ...
%                                'lh_pial.glb', 'UVCoords', uv_coords);

    % Parse input arguments
    p = inputParser;
    addRequired(p, 'vertices', @(x) ismatrix(x) && size(x,2) == 3);
    addRequired(p, 'faces', @(x) ismatrix(x) && size(x,2) == 3);
    addRequired(p, 'filename', @ischar);
    addParameter(p, 'UVCoords', [], @(x) isempty(x) || (ismatrix(x) && size(x,2) == 2));
    addParameter(p, 'Normals', [], @(x) isempty(x) || (ismatrix(x) && size(x,2) == 3));
    addParameter(p, 'Texture', '', @ischar);
    addParameter(p, 'Colors', [], @(x) isempty(x) || (ismatrix(x) && size(x,2) == 3));
    addParameter(p, 'Scalars', [], @(x) isempty(x) || (isvector(x) && length(x) == size(vertices,1)));
    
    parse(p, vertices, faces, filename, varargin{:});
    
    uv_coords = p.Results.UVCoords;
    normals = p.Results.Normals;
    texture_path = p.Results.Texture;
    colors = p.Results.Colors;
    scalars = p.Results.Scalars;
    
    fprintf('Exporting %d vertices, %d faces to GLB format: %s\n', ...
            size(vertices,1), size(faces,1), filename);
    
    % Compute normals if not provided
    if isempty(normals)
        fprintf('Computing vertex normals...\n');
        normals = compute_vertex_normals(vertices, faces);
    end
    
    % Ensure faces are 0-based for glTF
    faces_0based = faces - 1;
    
    % Create glTF structure
    gltf = create_gltf_structure(vertices, faces_0based, normals, uv_coords, colors, scalars);
    
    % Handle texture embedding
    if ~isempty(texture_path) && exist(texture_path, 'file')
        fprintf('Embedding texture: %s\n', texture_path);
        gltf = embed_texture(gltf, texture_path);
    end
    
    % Write GLB file
    write_glb_file(gltf, filename);
    
    fprintf('Successfully exported to %s\n', filename);
end

function normals = compute_vertex_normals(vertices, faces)
    % Compute vertex normals from surface mesh
    nv = size(vertices, 1);
    normals = zeros(nv, 3);
    
    % Accumulate face normals to vertices
    for i = 1:size(faces, 1)
        v1 = vertices(faces(i,1), :);
        v2 = vertices(faces(i,2), :);
        v3 = vertices(faces(i,3), :);
        
        % Face normal
        fn = cross(v2 - v1, v3 - v1);
        
        % Add to each vertex
        normals(faces(i,1), :) = normals(faces(i,1), :) + fn;
        normals(faces(i,2), :) = normals(faces(i,2), :) + fn;
        normals(faces(i,3), :) = normals(faces(i,3), :) + fn;
    end
    
    % Normalize
    norm_lengths = sqrt(sum(normals.^2, 2));
    normals = normals ./ (norm_lengths + eps);
end

function gltf = create_gltf_structure(vertices, faces, normals, uv_coords, colors, scalars)
    % Create basic glTF 2.0 structure
    
    % Asset info
    gltf.asset.version = '2.0';
    gltf.asset.generator = 'MATLAB FreeSurfer to GLB Exporter';
    
    % Scene structure
    gltf.scenes = struct('nodes', 0);
    gltf.scene = 0;
    
    % Node
    gltf.nodes = struct('mesh', 0);
    
    % Mesh
    primitive = struct();
    primitive.attributes.POSITION = 0;  % Buffer view 0
    primitive.attributes.NORMAL = 1;    % Buffer view 1
    
    attr_count = 2;
    
    % Add UV coordinates if provided
    if ~isempty(uv_coords)
        primitive.attributes.TEXCOORD_0 = attr_count;
        attr_count = attr_count + 1;
    end
    
    % Add vertex colors if provided
    if ~isempty(colors)
        primitive.attributes.COLOR_0 = attr_count;
        attr_count = attr_count + 1;
    end
    
    % Add scalar data as another texture coordinate if provided
    if ~isempty(scalars)
        primitive.attributes.TEXCOORD_1 = attr_count;
        attr_count = attr_count + 1;
    end
    
    primitive.indices = attr_count;  % Indices buffer view
    primitive.mode = 4;  % TRIANGLES
    
    gltf.meshes = struct('primitives', primitive);
    
    % Create buffers and buffer views
    [gltf.buffers, gltf.bufferViews, gltf.accessors] = create_buffers( ...
        vertices, faces, normals, uv_coords, colors, scalars);
end

function [buffers, bufferViews, accessors] = create_buffers(vertices, faces, normals, uv_coords, colors, scalars)
    % Create binary data buffers for glTF
    
    % Convert to single precision and ensure proper format
    vertices = single(vertices);
    normals = single(normals);
    faces = uint32(faces);
    
    % Calculate buffer sizes and offsets
    vertex_size = numel(vertices) * 4;  % 4 bytes per float32
    normal_size = numel(normals) * 4;
    
    buffer_size = vertex_size + normal_size;
    buffer_offset = vertex_size + normal_size;
    
    % Add UV coordinates if provided
    uv_offset = 0;
    uv_size = 0;
    if ~isempty(uv_coords)
        uv_coords = single(uv_coords);
        uv_size = numel(uv_coords) * 4;
        uv_offset = buffer_offset;
        buffer_offset = buffer_offset + uv_size;
        buffer_size = buffer_size + uv_size;
    end
    
    % Add vertex colors if provided
    color_offset = 0;
    color_size = 0;
    if ~isempty(colors)
        colors = single(colors);
        color_size = numel(colors) * 4;
        color_offset = buffer_offset;
        buffer_offset = buffer_offset + color_size;
        buffer_size = buffer_size + color_size;
    end
    
    % Add scalar data if provided
    scalar_offset = 0;
    scalar_size = 0;
    if ~isempty(scalars)
        % Convert scalars to UV format (scalar, 0)
        scalar_uv = [single(scalars(:)), zeros(length(scalars), 1, 'single')];
        scalar_size = numel(scalar_uv) * 4;
        scalar_offset = buffer_offset;
        buffer_offset = buffer_offset + scalar_size;
        buffer_size = buffer_size + scalar_size;
    end
    
    % Add face indices
    face_size = numel(faces) * 4;  % 4 bytes per uint32
    face_offset = buffer_offset;
    buffer_size = buffer_size + face_size;
    
    % Create binary data
    binary_data = zeros(buffer_size, 1, 'uint8');
    offset = 1;
    
    % Pack vertices
    vertex_bytes = typecast(vertices(:), 'uint8');
    binary_data(offset:offset+length(vertex_bytes)-1) = vertex_bytes;
    offset = offset + length(vertex_bytes);
    
    % Pack normals
    normal_bytes = typecast(normals(:), 'uint8');
    binary_data(offset:offset+length(normal_bytes)-1) = normal_bytes;
    offset = offset + length(normal_bytes);
    
    % Pack UV coordinates
    if ~isempty(uv_coords)
        uv_bytes = typecast(uv_coords(:), 'uint8');
        binary_data(offset:offset+length(uv_bytes)-1) = uv_bytes;
        offset = offset + length(uv_bytes);
    end
    
    % Pack colors
    if ~isempty(colors)
        color_bytes = typecast(colors(:), 'uint8');
        binary_data(offset:offset+length(color_bytes)-1) = color_bytes;
        offset = offset + length(color_bytes);
    end
    
    % Pack scalar data
    if ~isempty(scalars)
        scalar_bytes = typecast(scalar_uv(:), 'uint8');
        binary_data(offset:offset+length(scalar_bytes)-1) = scalar_bytes;
        offset = offset + length(scalar_bytes);
    end
    
    % Pack faces
    face_bytes = typecast(faces(:), 'uint8');
    binary_data(offset:offset+length(face_bytes)-1) = face_bytes;
    
    % Create buffer
    buffers = struct('byteLength', buffer_size, 'data', binary_data);
    
    % Create buffer views
    bufferViews = [];
    accessors = [];
    
    view_idx = 0;
    acc_idx = 0;
    
    % Vertices buffer view and accessor
    bufferViews(view_idx + 1).buffer = 0;
    bufferViews(view_idx + 1).byteOffset = 0;
    bufferViews(view_idx + 1).byteLength = vertex_size;
    bufferViews(view_idx + 1).target = 34962;  % ARRAY_BUFFER
    
    accessors(acc_idx + 1).bufferView = view_idx;
    accessors(acc_idx + 1).componentType = 5126;  % FLOAT
    accessors(acc_idx + 1).count = size(vertices, 1);
    accessors(acc_idx + 1).type = 'VEC3';
    accessors(acc_idx + 1).min = double(min(vertices))';
    accessors(acc_idx + 1).max = double(max(vertices))';
    
    view_idx = view_idx + 1;
    acc_idx = acc_idx + 1;
    
    % Normals buffer view and accessor
    bufferViews(view_idx + 1).buffer = 0;
    bufferViews(view_idx + 1).byteOffset = vertex_size;
    bufferViews(view_idx + 1).byteLength = normal_size;
    bufferViews(view_idx + 1).target = 34962;  % ARRAY_BUFFER
    
    accessors(acc_idx + 1).bufferView = view_idx;
    accessors(acc_idx + 1).componentType = 5126;  % FLOAT
    accessors(acc_idx + 1).count = size(normals, 1);
    accessors(acc_idx + 1).type = 'VEC3';
    
    view_idx = view_idx + 1;
    acc_idx = acc_idx + 1;
    
    % UV coordinates
    if ~isempty(uv_coords)
        bufferViews(view_idx + 1).buffer = 0;
        bufferViews(view_idx + 1).byteOffset = uv_offset;
        bufferViews(view_idx + 1).byteLength = uv_size;
        bufferViews(view_idx + 1).target = 34962;  % ARRAY_BUFFER
        
        accessors(acc_idx + 1).bufferView = view_idx;
        accessors(acc_idx + 1).componentType = 5126;  % FLOAT
        accessors(acc_idx + 1).count = size(uv_coords, 1);
        accessors(acc_idx + 1).type = 'VEC2';
        
        view_idx = view_idx + 1;
        acc_idx = acc_idx + 1;
    end
    
    % Vertex colors
    if ~isempty(colors)
        bufferViews(view_idx + 1).buffer = 0;
        bufferViews(view_idx + 1).byteOffset = color_offset;
        bufferViews(view_idx + 1).byteLength = color_size;
        bufferViews(view_idx + 1).target = 34962;  % ARRAY_BUFFER
        
        accessors(acc_idx + 1).bufferView = view_idx;
        accessors(acc_idx + 1).componentType = 5126;  % FLOAT
        accessors(acc_idx + 1).count = size(colors, 1);
        accessors(acc_idx + 1).type = 'VEC3';
        
        view_idx = view_idx + 1;
        acc_idx = acc_idx + 1;
    end
    
    % Scalar data as TEXCOORD_1
    if ~isempty(scalars)
        bufferViews(view_idx + 1).buffer = 0;
        bufferViews(view_idx + 1).byteOffset = scalar_offset;
        bufferViews(view_idx + 1).byteLength = scalar_size;
        bufferViews(view_idx + 1).target = 34962;  % ARRAY_BUFFER
        
        accessors(acc_idx + 1).bufferView = view_idx;
        accessors(acc_idx + 1).componentType = 5126;  % FLOAT
        accessors(acc_idx + 1).count = length(scalars);
        accessors(acc_idx + 1).type = 'VEC2';
        
        view_idx = view_idx + 1;
        acc_idx = acc_idx + 1;
    end
    
    % Faces buffer view and accessor
    bufferViews(view_idx + 1).buffer = 0;
    bufferViews(view_idx + 1).byteOffset = face_offset;
    bufferViews(view_idx + 1).byteLength = face_size;
    bufferViews(view_idx + 1).target = 34963;  % ELEMENT_ARRAY_BUFFER
    
    accessors(acc_idx + 1).bufferView = view_idx;
    accessors(acc_idx + 1).componentType = 5125;  % UNSIGNED_INT
    accessors(acc_idx + 1).count = numel(faces);
    accessors(acc_idx + 1).type = 'SCALAR';
end

function gltf = embed_texture(gltf, texture_path)
    % Embed texture image in glTF
    
    [~, ~, ext] = fileparts(texture_path);
    
    % Read image file
    img_data = fileread(texture_path);
    img_bytes = uint8(img_data);
    
    % Determine MIME type
    switch lower(ext)
        case '.png'
            mime_type = 'image/png';
        case '.jpg'
        case '.jpeg'
            mime_type = 'image/jpeg';
        otherwise
            warning('Unsupported texture format: %s', ext);
            return;
    end
    
    % Add image buffer
    if ~isfield(gltf, 'buffers')
        gltf.buffers = [];
    end
    
    buffer_idx = length(gltf.buffers) + 1;
    gltf.buffers(buffer_idx).byteLength = length(img_bytes);
    gltf.buffers(buffer_idx).data = img_bytes;
    
    % Add buffer view for image
    if ~isfield(gltf, 'bufferViews')
        gltf.bufferViews = [];
    end
    
    view_idx = length(gltf.bufferViews) + 1;
    gltf.bufferViews(view_idx).buffer = buffer_idx - 1;  % 0-based
    gltf.bufferViews(view_idx).byteOffset = 0;
    gltf.bufferViews(view_idx).byteLength = length(img_bytes);
    
    % Add image
    gltf.images.bufferView = view_idx - 1;  % 0-based
    gltf.images.mimeType = mime_type;
    
    % Add sampler
    gltf.samplers.magFilter = 9729;  % LINEAR
    gltf.samplers.minFilter = 9987;  % LINEAR_MIPMAP_LINEAR
    gltf.samplers.wrapS = 10497;     % REPEAT
    gltf.samplers.wrapT = 10497;     % REPEAT
    
    % Add texture
    gltf.textures.source = 0;
    gltf.textures.sampler = 0;
    
    % Add material
    gltf.materials.pbrMetallicRoughness.baseColorTexture.index = 0;
    gltf.materials.pbrMetallicRoughness.metallicFactor = 0.0;
    gltf.materials.pbrMetallicRoughness.roughnessFactor = 1.0;
    
    % Update mesh to use material
    gltf.meshes.primitives.material = 0;
end

function write_glb_file(gltf, filename)
    % Write GLB (binary glTF) file
    
    % Extract binary data first
    binary_data = [];
    if isfield(gltf, 'buffers')
        % Pre-calculate total size for efficiency
        total_size = 0;
        for i = 1:length(gltf.buffers)
            if isfield(gltf.buffers(i), 'data')
                total_size = total_size + length(gltf.buffers(i).data(:));
            end
        end
        
        % Pre-allocate array
        if total_size > 0
            binary_data = zeros(total_size, 1, 'uint8');
            offset = 1;
            
            for i = 1:length(gltf.buffers)
                if isfield(gltf.buffers(i), 'data')
                    data_chunk = gltf.buffers(i).data(:);
                    binary_data(offset:offset+length(data_chunk)-1) = data_chunk;
                    offset = offset + length(data_chunk);
                    % Remove data field from JSON
                    gltf.buffers(i) = rmfield(gltf.buffers(i), 'data');
                end
            end
        end
    end
    
    % Convert gltf struct to JSON (after removing binary data)
    json_str = jsonencode(gltf, 'PrettyPrint', false);
    json_bytes = uint8(json_str);
    
    % Pad JSON to 4-byte alignment
    json_padding = mod(4 - mod(length(json_bytes), 4), 4);
    json_bytes = [json_bytes; repmat(uint8(' '), json_padding, 1)];
    
    % Pad binary data to 4-byte alignment
    if ~isempty(binary_data)
        bin_padding = mod(4 - mod(length(binary_data), 4), 4);
        binary_data = [binary_data; zeros(bin_padding, 1, 'uint8')];
    end
    
    % Create GLB header
    magic = uint32(0x46546C67);  % 'glTF'
    version = uint32(2);
    if isempty(binary_data)
        bin_size = 0;
    else
        bin_size = 8 + length(binary_data);
    end
    total_length = uint32(12 + 8 + length(json_bytes) + bin_size);
    
    % JSON chunk header
    json_chunk_length = uint32(length(json_bytes));
    json_chunk_type = uint32(0x4E4F534A);  % 'JSON'
    
    % Binary chunk header (if binary data exists)
    if ~isempty(binary_data)
        bin_chunk_length = uint32(length(binary_data));
        bin_chunk_type = uint32(0x004E4942);  % 'BIN\0'
    end
    
    % Write GLB file
    fid = fopen(filename, 'wb');
    if fid == -1
        error('Could not open file %s for writing', filename);
    end
    
    try
        % Write header
        fwrite(fid, magic, 'uint32');
        fwrite(fid, version, 'uint32');
        fwrite(fid, total_length, 'uint32');
        
        % Write JSON chunk
        fwrite(fid, json_chunk_length, 'uint32');
        fwrite(fid, json_chunk_type, 'uint32');
        fwrite(fid, json_bytes, 'uint8');
        
        % Write binary chunk
        if ~isempty(binary_data)
            fwrite(fid, bin_chunk_length, 'uint32');
            fwrite(fid, bin_chunk_type, 'uint32');
            fwrite(fid, binary_data, 'uint8');
        end
        
    catch ME
        fclose(fid);
        rethrow(ME);
    end
    
    fclose(fid);
end

function uv_coords = compute_uv_from_sphere(sphere_vertices) %#ok<DEFNU>
    % Compute UV coordinates from spherical surface
    % This is a utility function that can be called externally
    % Example: uv_coords = compute_uv_from_sphere(subject.lh.sphere.vertices);
    x = sphere_vertices(:, 1);
    y = sphere_vertices(:, 2);
    z = sphere_vertices(:, 3);
    
    % Spherical to UV mapping
    u = (atan2(y, x) / (2 * pi)) + 0.5;  % [0, 1]
    u = mod(u, 1.0);  % Ensure [0, 1]
    v = (asin(z) / pi) + 0.5;  % [0, 1]
    v = max(0, min(1, v));  % Clamp to [0, 1]
    
    uv_coords = [u, v];
end