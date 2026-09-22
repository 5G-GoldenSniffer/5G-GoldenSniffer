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
end
