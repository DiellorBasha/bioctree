function Lap = discreteLaplacian5pt(Z, h)
% discreteLaplacian5pt  Standard 5-point finite-difference Laplacian on a rectangular grid.
%
% Lap(i,j) = ( sum of 4-neighbors - deg(i,j)*Z(i,j) ) / h^2
%   where deg(i,j) is 2,3,4 depending on boundary.
%
% Inputs:
%   Z  - Ny x Nx scalar field
%   h  - grid spacing (scalar). Use h=1 to match unit 2D grid graph weights.
%
% Output:
%   Lap - Ny x Nx Laplacian approximation

    if nargin < 2 || isempty(h), h = 1; end
    [Ny, Nx] = size(Z);

    % Accumulate neighbor sums with in-bounds shifts (no wrap-around)
    S = zeros(Ny, Nx);

    % left neighbor
    S(:,2:Nx) = S(:,2:Nx) + Z(:,1:Nx-1);
    % right neighbor
    S(:,1:Nx-1) = S(:,1:Nx-1) + Z(:,2:Nx);
    % up neighbor (row-1)
    S(1:Ny-1,:) = S(1:Ny-1,:) + Z(2:Ny,:);
    % down neighbor (row+1)
    S(2:Ny,:) = S(2:Ny,:) + Z(1:Ny-1,:);

    % degree: how many in-bounds neighbors each cell has
    deg = 4*ones(Ny, Nx);
    deg(:,[1 Nx]) = deg(:,[1 Nx]) - 1;
    deg([1 Ny],:) = deg([1 Ny],:) - 1;

    Lap = (S - deg.*Z) / (h^2);   % note: S - deg*Z == - (deg*Z - S)
end
