function A = hModelBrainConnectivity(Coordinates)
% Compute pairwise distance
C = Coordinates';
pd = computePairwiseDistance(C);
% Compute correlation based on power law
d0 = mean(pd);
gamma = 2;
W0 = 1;
corr = 1./(W0.*(pd./d0).^gamma);

% Create structural connectivity
A = convertToSquareMatrix(corr);
end

function d = computePairwiseDistance(C)
% Compute pairwise Euclidean distance
D = dot(C,C,1)+(dot(C,C,1)')-2*(C'*C);
% To make sure there is no negative element due to numerical rounding, the
% negative elements are set to 0
D(D < 0) = 0;
D = sqrt(D);
% Create a lower triangular matrix with all the elements below the main
% diagonal
Dlt = tril(D,-1);
% Find index of lower triangular elements
ltIdx = (1:size(Dlt,1)) < (1:size(Dlt,2)).';
d = Dlt(ltIdx);
end

function S = convertToSquareMatrix(d)
N = numel(d); % N must be a triabular number, i.e. N = n*(n-1)/2
n = ceil(sqrt(2*N)); % (1+sqrt(1+8*N))/2
% Create a symmetric square matrix from vector d
S = zeros(n);
S(tril(true(n),-1)) = d;
S = S+S.';
end