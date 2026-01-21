function attrs = mapHeader(Header)
%MAPHEADER  Map Manifold Header to flat attribute dictionary
%
%   attrs = bct.file.manifold.prepare.mapHeader(Header)
%
% Purpose
%   Converts bct.Manifold.Header struct to flat attribute dictionary
%   suitable for HDF5 or Zarr export. Flattens nested Metric structure
%   and handles type conversions.
%
% Input
%   Header - struct, M.Header from bct.Manifold
%
% Output
%   attrs - struct, flat attribute dictionary with fields:
%           .schema            - "bct.manifold@1"
%           .id                - UUID
%           .name              - human-readable name
%           .coordinate_system - RAS, LPS, unknown
%           .face_winding      - CCW, CW
%           .normal_convention - right-hand-rule, left-hand-rule
%           .units             - m, mm, etc.
%           .metric            - nested struct with unit and rescale fields
%           .source            - file path
%           .created_at        - ISO8601 timestamp
%           .created_by        - username
%           .matlab_index_base - 1 (internal MATLAB convention)
%           .index_base_faces  - 0 (export convention)
%           .index_base_edges  - 0 (export convention)
%
% Export Policy
%   - Schema version: "bct.manifold@1"
%   - Index base: 0 for faces/edges (export), 1 for MATLAB (internal)
%   - Metric: nested structure preserved for Zarr, will be flattened for HDF5
%   - Timestamps: converted to ISO8601 strings
%
% Examples
%   attrs = bct.file.manifold.prepare.mapHeader(M.Header);
%   assert(attrs.index_base_faces == 0);
%   assert(attrs.metric.unit == "m");
%
% See also: bct.file.manifold.write.core, bct.file.manifold.write.zarr

arguments
    Header (1,1) struct
end

%% Initialize output
attrs = struct();

%% Schema and index base (export convention)
attrs.schema = 'bct.manifold@1';
attrs.index_base_faces = int32(0);
attrs.index_base_edges = int32(0);

%% ID (identifier)
if isfield(Header, 'ID') && ~isempty(Header.ID) && strlength(Header.ID) > 0
    attrs.id = char(Header.ID);
end

%% Name (human-readable)
if isfield(Header, 'Name') && ~isempty(Header.Name) && strlength(Header.Name) > 0
    attrs.name = char(Header.Name);
end

%% Coordinate system (RAS, LPS, etc.)
if isfield(Header, 'CoordinateSystem') && ~isempty(Header.CoordinateSystem) && strlength(Header.CoordinateSystem) > 0
    attrs.coordinate_system = char(Header.CoordinateSystem);
end

%% Face winding (CCW, CW)
if isfield(Header, 'FaceWinding') && ~isempty(Header.FaceWinding) && strlength(Header.FaceWinding) > 0
    attrs.face_winding = char(Header.FaceWinding);
end

%% Normal convention (right-hand-rule, left-hand-rule)
if isfield(Header, 'NormalConvention') && ~isempty(Header.NormalConvention) && strlength(Header.NormalConvention) > 0
    attrs.normal_convention = char(Header.NormalConvention);
end

%% Units (convenience top-level)
if isfield(Header, 'Units') && ~isempty(Header.Units) && strlength(Header.Units) > 0
    attrs.units = char(Header.Units);
end

%% Metric (nested structure for Zarr, will be flattened for HDF5)
if isfield(Header, 'Metric') && ~isempty(Header.Metric)
    M = Header.Metric;
    attrs.metric = struct();
    
    % metric.unit
    if isfield(M, 'unit') && ~isempty(M.unit)
        attrs.metric.unit = char(M.unit);
    end
    
    % metric.rescale substructure
    if isfield(M, 'rescale')
        attrs.metric.rescale = struct();
        
        if isfield(M.rescale, 'applied')
            attrs.metric.rescale.applied = logical(M.rescale.applied);
        end
        if isfield(M.rescale, 'fromUnit') && ~isempty(M.rescale.fromUnit)
            attrs.metric.rescale.fromUnit = char(M.rescale.fromUnit);
        end
        if isfield(M.rescale, 'factor')
            attrs.metric.rescale.factor = double(M.rescale.factor);
        end
        if isfield(M.rescale, 'timestamp') && ~isempty(M.rescale.timestamp)
            attrs.metric.rescale.timestamp = char(M.rescale.timestamp);
        end
    end
end

%% Source (file path)
if isfield(Header, 'Source') && ~isempty(Header.Source) && strlength(Header.Source) > 0
    attrs.source = char(Header.Source);
end

%% Created at (timestamp) - convert datetime to ISO8601 string
if isfield(Header, 'CreatedAt') && ~isempty(Header.CreatedAt)
    if isa(Header.CreatedAt, 'datetime')
        createdAtStr = char(datetime(Header.CreatedAt, 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
    else
        createdAtStr = char(Header.CreatedAt);
    end
    attrs.created_at = createdAtStr;
end

%% Created by (user/system)
if isfield(Header, 'CreatedBy') && ~isempty(Header.CreatedBy) && strlength(Header.CreatedBy) > 0
    attrs.created_by = char(Header.CreatedBy);
end

%% IndexBase (internal MATLAB convention) - optional metadata
if isfield(Header, 'IndexBase') && ~isempty(Header.IndexBase)
    attrs.matlab_index_base = int32(Header.IndexBase);
end

end
