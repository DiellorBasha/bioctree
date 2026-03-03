function [chanNames, isFileBased] = sdsGetChannelNames(sds)
%SDSGETCHANNELNAMES Get channel names from a signalDatastore (in-memory or file-based).
%
%   [chanNames, isFileBased] = sdsGetChannelNames(sds)
%
%   In-memory datastores use MemberNames. File-based datastores use the
%   filenames (without extension) from the Files property.
%
%   Outputs:
%       chanNames   - [N x 1] string array of channel names
%       isFileBased - true if the datastore is backed by files
%
%   See also: signalDatastore, readSourceSegment, writeSourceDatastore

    try
        % In-memory datastores support MemberNames
        chanNames = string(sds.MemberNames);
        isFileBased = false;
    catch
        % File-based datastores: extract names from file paths
        files = sds.Files;
        chanNames = strings(numel(files), 1);
        for i = 1:numel(files)
            [~, chanNames(i)] = fileparts(files{i});
        end
        isFileBased = true;
    end
    chanNames = chanNames(:);
end
