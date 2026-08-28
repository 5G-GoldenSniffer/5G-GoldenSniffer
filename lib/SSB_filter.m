%SSB_FILTER Create filter for SSB extraction
%   [H, N, DECIM] = SSB_FILTER(FS, SCS, NS) creates a lowpass filter for
%   SSB (Synchronization Signal Block) extraction from a wideband signal.
%
%   Inputs:
%       FS   - Sample rate [Hz]
%       SCS  - Subcarrier spacing [Hz]
%       NS   - Number of samples per frame
%
%   Outputs:
%       H     - Filter coefficients
%       N     - Filter length
%       DECIM - Decimation factor
%
%   The filter is designed to pass the SSB bandwidth (240 subcarriers)
%   while rejecting out-of-band signals.
%
%   See also: Channel_filter, PSS_func, SSS_func

%   Copyright 2024-2026 the authors
%   Licensed under MIT License
%
%   Permission is hereby granted, free of charge, to any person obtaining a copy
%   of this software and associated documentation files (the "Software"), to
%   deal in the Software without restriction, including without limitation the
%   rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
%   sell copies of the Software, and to permit persons to whom the Software is
%   furnished to do so, subject to the following conditions:
%
%   The above copyright notice and this permission notice shall be included in
%   all copies or substantial portions of the Software.
%
%   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
%   IN THE SOFTWARE.
%
function [hSSB,NhSSB,decim] = SSB_filter(fs,SCS,ns)
	decim = floor(fs/(240*SCS));
	while mod(ns,decim) ~= 0
		decim = decim - 1;
	end
	if 1 % FIRPM
		Fpass = 120*SCS;
		Fstop = Fpass+(80-64)*SCS;
		Wpass = 1;
		Wstop = 1;
		dens  = 100;
		LP_order = 32;
		N = LP_order*decim;
		Fs_filt = fs;
		b  = firpm(N, [0 Fpass Fstop Fs_filt/2]/(Fs_filt/2), [1 1 0 0], [Wpass Wstop], {dens});
		Hd = dfilt.dffir(b);
		set(Hd, 'Arithmetic', 'single');
		hSSB = Hd.Numerator(1:end-1);
		NhSSB = numel(hSSB);
		% rp = 1;           % Passband ripple in dB
		% rs = 20;          % Stopband ripple in dB
		% f = [120*SCS 120*SCS+0.055*fs];
		% a = [1 0];        % Desired amplitudes
		% dev = [(10^(rp/20)-1)/(10^(rp/20)+1) 10^(-rs/20)];
		% [n,fo,ao,w] = firpmord(f,a,dev,fs);
		% hSSB = firpm(n,fo,ao,w);
		% NhSSB = numel(hSSB);
	else % RCOS
		fs_decim = fs/decim;
		f = [120*SCS fs_decim/2];
		a = (f(2)-f(1))/(f(2)+f(1));
		while a < 0.16
			decim = decim - 1;
			while mod(ns,decim) ~= 0
				decim = decim - 1;
			end
			fs_decim = fs/decim;
			f = [120*SCS fs_decim/2];
			a = (f(2)-f(1))/(f(2)+f(1));
		end
		LSSB = 6;
		hSSB = raised_cosine(a,(-LSSB*decim:LSSB*decim+decim-1)/fs,decim/fs)/decim;
		NhSSB = (2*LSSB+1)*decim;
		% hold off
		% plot((0:4095)*fs/4096,20*log10(abs(fft(hSSB,4096))));
		% hold on
		% plot([0 1 1]*SCS*120,[0 0 -40]);
		% plot([fs/decim,fs/decim,fs]/2,[0 -40 -40])
		% keyboard
	end
end
% function [h, N, decim] = SSB_filter(fs, SCS, ns)
%     % SSB spans 240 subcarriers = 240 * SCS Hz
%     SSB_BW = 240 * SCS;
% 
%     % Decimation factor for efficient processing
%     decim = max(1, floor(fs / (4 * SSB_BW)));
% 
%     % Filter design parameters
%     Fpass = SSB_BW / 2;           % Passband frequency
%     Fstop = SSB_BW;               % Stopband frequency
%     Apass = 0.5;                  % Passband ripple (dB)
%     Astop = 40;                   % Stopband attenuation (dB)
% 
%     % Design lowpass filter
%     d = designfilt('lowpassfir', ...
%         'PassbandFrequency', Fpass, ...
%         'StopbandFrequency', Fstop, ...
%         'PassbandRipple', Apass, ...
%         'StopbandAttenuation', Astop, ...
%         'SampleRate', fs);
% 
%     h = d.Coefficients;
%     N = length(h);
% 
%     % Adjust filter length to be compatible with decimation
%     if mod(N, decim) ~= 0
%         N = ceil(N / decim) * decim;
%         h = [h, zeros(1, N - length(h))];
%     end
% end
