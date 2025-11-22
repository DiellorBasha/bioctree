function tests = test_bct_create_open, tests = functiontests(localfunctions); end
function setupOnce(t)
root = fileparts(mfilename('fullpath'));
t.TestData.fn = fullfile(root,'..','..','data','temp','unit_demo.bct.h5');
if ~exist(fileparts(t.TestData.fn),'dir'), mkdir(fileparts(t.TestData.fn)); end
end
function testCreateWriteRead(t)
B = bct.bct.create(t.TestData.fn);
N=10; T=100; fs=100;
G = struct('coords',rand(N,3),'E',[randi(N,30,1) randi(N,30,1)],'lap_type','normalized','lmax',single(2));
B.write_graph(G); B.write_raw(single(randn(T,N)), fs);
B.validate();
X = B.read_raw([1 10],[1 5]);
verifySize(t, X, [10 5]);
end

