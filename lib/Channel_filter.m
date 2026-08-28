%CHANNEL_FILTER Create channel filter for signal conditioning
%   [H, N] = CHANNEL_FILTER(FS, BW_MHZ) creates a lowpass filter for
%   channel extraction based on the signal bandwidth.
%
%   Inputs:
%       FS     - Sample rate [Hz]
%       BW_MHZ - Channel bandwidth [MHz]
%
%   Outputs:
%       H - Filter coefficients
%       N - Filter length
%
%   The filter passes the desired channel bandwidth while rejecting
%   out-of-band interference and noise.
%
%   See also: SSB_filter

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
function [hChannel,NhChannel] = Channel_filter(fs,BW_MHz)
	if 1 % FIRPM
		rp = 0.1;           % Passband ripple in dB
		rs = 30;          % Stopband ripple in dB
		BW = BW_MHz*1e6;
		f = [BW/2 BW/2+450e3];  % Cutoff frequencies
		a = [1 0];        % Desired amplitudes
		dev = [(10^(rp/20)-1)/(10^(rp/20)+1) 10^(-rs/20)];
		[n,fo,ao,w] = firpmord(f,a,dev,fs);
		hChannel = firpm(n,fo,ao,w);
	else
		a = 0.18;
		f = [(1-a/2)*BW_MHz/2 (1+a/2)*BW_MHz/2+450e3];
		a = (f(2)-f(1))/(f(2)+f(1));
		LChannel = 31;
		hChannel = raised_cosine(a,(-LChannel:LChannel)/fs,1/fs);
	end
	NhChannel = numel(hChannel);
end
% 
% 
% function [h, N] = Channel_filter(fs, BW_MHz)
%     % Channel bandwidth in Hz
%     BW_Hz = BW_MHz * 1e6;
% 
%     % Filter design parameters
%     % Use 90% of bandwidth as passband to account for guard bands
%     Fpass = 0.45 * BW_Hz;         % Passband frequency
%     Fstop = 0.55 * BW_Hz;         % Stopband frequency
%     Apass = 0.5;                  % Passband ripple (dB)
%     Astop = 60;                   % Stopband attenuation (dB)
% 
%     % Ensure filter frequencies are within Nyquist limit
%     Fnyq = fs / 2;
%     if Fstop >= Fnyq
%         Fpass = 0.4 * Fnyq;
%         Fstop = 0.45 * Fnyq;
%     end
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
% end
