fname = "data/test_freqspace.h5";
if exist(fname,'file'), delete(fname); end
%%
% h5create	Create HDF5 dataset
% h5disp	Display contents of HDF5 file
% h5info	Information about HDF5 file
% h5read	Read data from HDF5 dataset
% h5readatt	Read attribute from HDF5 file
% h5write	Write data to HDF5 dataset
% h5writeatt	Write attribute to HDF5 file
% 
% Low-Level Functions for HDF5 Files
% Library (H5)	General-purpose functions for use with entire HDF5 library
% Attribute (H5A)	Metadata associated with datasets or groups
% Dataset (H5D)	Multidimensional arrays of data elements and supporting metadata
% Dimension Scale (H5DS)	Dimension scale associated with dataset dimensions
% Error (H5E)	Error handling
% File (H5F)	HDF5 file access
% Group (H5G)	Organization of objects in file
% Identifier (H5I)	HDF5 object identifiers
% Link (H5L)	Links in HDF5 file
% MATLAB (H5ML)	MATLAB utility functions not part of the HDF5 C library
% Object (H5O)	Objects in file
% Property (H5P)	Object property lists
% Reference (H5R)	HDF5 references
% Dataspace (H5S)	Dimensionality of dataset
% Datatype (H5T)	Datatype of elements in a dataset
% Filters and Compression (H5Z)	Inline data filters, data compression
%%

% Schema
%. Create dataspaces
spacetype = 'signals'
spaceID = H5S.create(spacetype)

% 1. Create file
fid = H5F.create(fname);
plist = "H5P_DEFAULT";

% 2. Create group
gid = H5G.create(fid,"signals",plist,plist,plist);
H5G.close(gid);

%3. Create dataset
dsname='geometry';
dsID = H5D.create(fid,dsname,typeID,spaceID,lcplID,dcplID,daplID) 

% Close file
% H5F.close(fid);


% %% As described previously, an HDF5 dataset consists of the raw data, as well as the metadata that describes the data (datatype, spatial information, and properties). To create a dataset you must:
% 
% Define the dataset characteristics (datatype, dataspace, properties).
% Decide which group to attach the dataset to.
% Create the dataset.
% Close the dataset handle from step 3.

% Root dataset is the subject information in /subject which also contains
% the subject manifold - in this case the brain mesh - subject source etc
% group manifold/topology: %'/vertices' %'/faces' /eigenvectors /eignenvalues /edges
% /eigentime /joint
% group manifold/geometry: points to vertices, faces, contains mesh vertex data like 
% group manifold/scales

 
% group signals: contains SNCT - points to mesh/vertices mesh/faces and
% contains ImagingKernal or mappings

%

% Define groups: 
N = 163842;                  % number of vertices (toy)
T = 1;                  % static for now
S = 3;                  % signals: coords, normals, curvature
C = 3;                  % max components across signals (coords/normals=3, curvature uses 1)
%% Datasets
% 1. Signals SCNT - rank 4, variable S , variabl C with max 3, fixed N ,
% fixed T
% 2. Mesh 

% A group is a collection of links !
%Groups
% 
% Groups do not have names
% Groups hold links
% Groups can be empty
% Groups do not hold objects
% The root group is automatically created when the HDF5 file is created
% The root group cannot be deleted
% H5G function calls are part of the Groups interface
% Links
% 
% Each link has a name
% Link names are unique within a group
% The target of each link is only one group or dataset
% Each group or dataset is the target of at least one hard link
% A group or dataset may be the target of many links
% Links may create circular references
% A link path is made of the links that it takes to get to a group or a dataset
% The links in a link path are separated by slashes
% A link path may be absolute or relative
% A link may be hard or symbolic
% H5L function calls are part of the Links interface
ds(1).name = 'signals'
ds(1).rank = 4;
ds(1).dim_label = {'nSignals', 'nComponents', 'nVertices', 'nTimesamples'};
ds(1).dims = [S C N T];
ds(1).dataspace =  [S C N T]; % also the subset definition - use filterbank to define scales
ds(1).datatype = 'single';
ds(1).properties = [];
ds(1).attributes = {};
ds(1).chunked=[];



ds(2).name = 'faces'
ds(2).rank = 4;
ds(2).dim_label = {'nSignals', 'nComponents', 'nFaces', 'nTimesamples'};
ds(2).dims = [S C F T];

ds(3).name = 'edges'
ds(3).rank = 4;
ds(3).dim_label = {'nWeights', 'nComponents', 'nEdges', 'nTimesamples'};
ds(3).dims = [W C E T];

ds(4).name = 'eigenvectors'
ds(4).rank = 2;
ds(4).dim_label = {'nVertices', 'nModes'};
ds(4).dims = [N, K];

ds(5).name = 'eigenvalues'
ds(5).rank = 1;
ds(5).dim_label = {'nModes'};
ds(5).dims = [K];



fid = H5F.create(fname);
plist = "H5P_DEFAULT";
gid = H5G.create(fid,"signals",plist,plist,plist);
H5G.close(gid);
%H5F.close(fid);
dsname='geometry';
dsID = H5D.create(fid,dsname,typeID,spaceID,lcplID,dcplID,daplID) 
%%

ds='/signals' ; 
h5create(fname, ds, [S C N T], 'Datatype', 'single');
%%
dsg='/signals/geometry' ;
h5create(fname, dsg, [S C N T], 'Datatype', 'single');

%%
bioctree_start
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B = bct.io.import.graph(path);

% Import curvature signal directly
curv_path = 'test-data\freesurfer\fsaverage\surf\lh.curv';
B = bct.io.signal.Import.fromFreeSurfer(curv_path, B);
B.mesh.computeNormals;
%%
signals = nan(S, C, N, T, 'single');
signals(1,1:3,:,1) = single(B.Vertices');              % coords
signals(2,1:3,:,1) = single(B.mesh.VertexNormals');    % normals
signals(3,1,:,1) = B.signals.data{1};               % toy curvature
h5create(fname, ds, [S C N T], 'Datatype', 'single');

h5write(fname, ds, signals/geometry);

%% H5F.get_name
