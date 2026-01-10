function Fout = withMeta(F, metaStruct)
%WITHMETA Merge metadata into Field
%
% FOUT = WITHMETA(F, metaStruct) merges metadata struct into Field F
%
% Arguments:
%   F          - Field struct
%   metaStruct - Struct with metadata fields to add/update
%
% If F already has metadata, fields are merged (metaStruct takes precedence).
% Returns new Field with updated metadata.
%
% Examples:
%   % Add provenance metadata
%   meta = struct('source', 'simulation', 'date', datestr(now));
%   Fout = bct.fields.withMeta(F, meta);
%
%   % Update existing metadata
%   meta = struct('processed', true, 'filter', 'lowpass');
%   Fout = bct.fields.withMeta(F, meta);

arguments
    F struct
    metaStruct struct
end

% Validate metaStruct
if ~isstruct(metaStruct)
    error('bct:Field:InvalidMetadata', ...
        'metaStruct must be a struct');
end

% Copy input
Fout = F;

% Merge metadata
if isfield(F, 'metadata')
    % Merge with existing metadata (new values take precedence)
    existingFields = fieldnames(F.metadata);
    newFields = fieldnames(metaStruct);
    
    % Start with existing metadata
    mergedMeta = F.metadata;
    
    % Add/update with new fields
    for i = 1:length(newFields)
        mergedMeta.(newFields{i}) = metaStruct.(newFields{i});
    end
    
    Fout.metadata = mergedMeta;
else
    % No existing metadata, just add new
    Fout.metadata = metaStruct;
end

% Validate result
bct.fields.validate(Fout);

end
