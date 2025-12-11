classdef IFFT < bct.factory.transforms.TransformBase
    %IFFT  Frequency (Omega) → Time transform

    methods
        function obj = IFFT(omegaDomain)
            obj@bct.factory.transforms.TransformBase();

            % Forward = IFFT (Ω → t)
            obj.forward = @(X) ifft(X, [], 1);

            % Inverse = FFT (t → Ω)
            obj.inverse = @(x) fft(x, [], 1);

            obj.metadata = omegaDomain.metadata;
        end
    end
end
