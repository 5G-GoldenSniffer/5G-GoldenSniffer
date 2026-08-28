%OFDM_FFT Perform OFDM demodulation for a single symbol
%   [Y, CP_CORR] = OFDM_FFT(S, OFFSET, CP_SLACK, N_CP, N_FFT, CFO_COMP)
%   performs OFDM demodulation on a single symbol from the time domain
%   signal.
%
%   Inputs:
%       S        - Time domain signal
%       OFFSET   - Sample offset to start of symbol (including CP)
%       CP_SLACK - Number of samples to skip at CP edges for robustness
%       N_CP     - Cyclic prefix length
%       N_FFT    - FFT size
%       CFO_COMP - Enable CFO compensation using CP correlation (0 or 1)
%
%   Outputs:
%       Y       - Frequency domain symbol (N_FFT x 1)
%       CP_CORR - Cyclic prefix correlation (complex)
%
%   The function performs:
%   1. Extract symbol with CP
%   2. Optional CP-based CFO estimation and compensation
%   3. Remove CP and perform FFT
%   4. Return frequency domain representation
%
%   See also: whole_frame_fft
%   cfo_comp: per-symbol Cfo compensation based on the phase of the cyclic
%           prefix correlation

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
function [Y,cp_corr]=ofdm_fft(s,ofs,CP_slack,N_CP,N_FFT,cfo_comp)
	s1 = s(ofs+      (CP_slack+1:N_CP-CP_slack));
	s2 = s(ofs+N_FFT+(CP_slack+1:N_CP-CP_slack));
	cp_corr = s2*s1'/(norm(s1)*norm(s2));
	if cfo_comp
		dphi_est = angle(cp_corr)/N_FFT;
		Y = fftshift(fft(s(ofs+N_CP-CP_slack+(1:N_FFT)) ...
			.*exp(-1i*dphi_est*(-CP_slack:N_FFT-CP_slack-1))))...
			.*exp(2i*pi*(-N_FFT/2:N_FFT/2-1)*CP_slack/N_FFT);
	else % cfo_comp==0
		Y = fftshift(fft(s(ofs+N_CP-CP_slack+(1:N_FFT))))...
			.*exp(2i*pi*(-N_FFT/2:N_FFT/2-1)*CP_slack/N_FFT);
	end
end
