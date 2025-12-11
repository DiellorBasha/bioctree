classdef FFT < bct.factory.transforms.TransformBase
    %FFT  Time → Frequency (Omega) transform using FFT

    methods
        function obj = FFT(timeDomain)
            obj@bct.factory.transforms.TransformBase();

            % Forward = FFT
            obj.forward = @(x) fft(x, [], 1);

            % Inverse = IFFT
            obj.inverse = @(X) ifft(X, [], 1);

            % Metadata
            N  = timeDomain.N;
            fs = timeDomain.fs;
            obj.metadata.f     = (0:N-1)*(fs/N);
            obj.metadata.omega = 2*pi*obj.metadata.f;
        end
    end
end
