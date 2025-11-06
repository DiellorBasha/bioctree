classdef H5ChannelDatastore < matlab.io.Datastore
    % Iterate columns (channels) of /signals/F from a single HDF5.
    % Each read() returns ONE channel as a timetable with variable 'x'.

    properties
        Filename (1,1) string
        DataPath (1,1) string = "/signals/F"   % <--- NEW (default raw)
        ChannelNames (1,:) string
        Fs (1,1) double
        NumSamples (1,1) double
        NumChannels (1,1) double
        SubjectName (1,1) string
    end

    properties (Access=private)
        Idx (1,1) double = 1
    end

    methods
function ds = H5ChannelDatastore(h5file, dataPath)
    validateattributes(h5file, {'string','char'}, {'nonempty','row'});
    ds.Filename = string(h5file);
    if nargin >= 2 && ~isempty(dataPath)
        ds.DataPath = string(dataPath);
    end

    % Inspect the chosen dataset (e.g., '/signals/F' or '/preproc/F')
    infoF = h5info(ds.Filename, ds.DataPath);
    sz    = infoF.Dataspace.Size;          % [nSamp, nChan]
    ds.NumSamples  = sz(1);
    ds.NumChannels = sz(2);

    % Figure out the parent group (for attributes)
    [grpPath,~] = fileparts(ds.DataPath);  % '/signals' or '/preproc'

    % Sample rate: prefer group attribute, else root
    try
        ds.Fs = h5readatt(ds.Filename, grpPath, 'SampleRateHz');
    catch
        ds.Fs = h5readatt(ds.Filename, '/', 'SampleRateHz');
    end

    % Channel names: prefer group attribute, else root
    try
        nm = h5readatt(ds.Filename, grpPath, 'ChannelNames'); % cellstr
    catch
        nm = h5readatt(ds.Filename, '/', 'ChannelNames');
    end
    ds.ChannelNames = string(nm(:)).';
    
    % SubjectName (unchanged)
    try
        ds.SubjectName = string(h5readatt(ds.Filename, '/', 'SubjectName'));
    catch
        ds.SubjectName = "";
    end
end

        function tf = hasdata(ds)
            tf = ds.Idx <= ds.NumChannels;
        end

        function reset(ds)
            ds.Idx = 1;
        end

        function frac = progress(ds)
            frac = (ds.Idx-1) / max(1, ds.NumChannels);
        end

        function TT = preview(ds)
            k = min(ds.Idx, ds.NumChannels);
            TT = readAtIndex_(ds, k); % non-advancing peek
        end

function [TT, info] = read(ds)
    if ~ds.hasdata(), error("H5ChannelDatastore:NoData","No more channels to read."); end
    k    = ds.Idx;
    name = ds.ChannelNames(k);
    TT   = readAtIndex_(ds, k, name);   % <— pass name
    info = struct('ChannelName', name, 'Index', k, 'Fs', ds.Fs);
    ds.Idx = ds.Idx + 1;
end

function [TT, info] = readByIndex(ds, k)
    arguments, ds (1,1) H5ChannelDatastore, k (1,1) double {mustBeInteger,mustBePositive}, end
    assert(k <= ds.NumChannels, 'Index exceeds NumChannels.');
    name = ds.ChannelNames(k);
    TT   = ds.readAtIndex_(k, name);   % your private helper already returns a timetable
    info = struct('ChannelName', name, 'Index', k, 'Fs', ds.Fs);
end

function [TT, info] = readByName(ds, name)
    idx = find(ds.ChannelNames == string(name), 1, 'first');
    assert(~isempty(idx), "Channel '%s' not found.", name);
    [TT, info] = readByIndex(ds, idx);
end
    end

    methods (Access=private)
function TT = readAtIndex_(ds, k, chName)
    if nargin < 3, chName = ds.ChannelNames(k); end
    raw = h5read(ds.Filename, ds.DataPath, [1 k], [ds.NumSamples 1]); % <--- changed
    Time   = seconds((0:ds.NumSamples-1).'/ds.Fs);
    var = matlab.lang.makeValidName(string(chName));
    TT  = timetable(Time, single(raw), 'VariableNames', cellstr(var));
    TT.Properties.VariableDescriptions = cellstr(string(chName));
end

    end
end
