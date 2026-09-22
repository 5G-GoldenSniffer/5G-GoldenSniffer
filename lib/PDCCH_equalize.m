%PDCCH_EQUALIZE Equalize PDCCH symbols using DMRS channel estimates
%   Y_EQ = PDCCH_EQUALIZE(Y, DMRS_IND, C_EST) performs MMSE equalization
%   on PDCCH symbols using channel estimates from DMRS.
%
%   Inputs:
%       Y        - Received PDCCH symbols (complex vector)
%       DMRS_IND - Indices of DMRS subcarriers within Y (1-based)
%       C_EST    - Channel estimates at DMRS positions
%
%   Output:
%       Y_EQ - Equalized symbols at data positions (DMRS removed)
%
%   The function:
%   1. Interpolates channel estimates to all subcarriers
%   2. Performs MMSE equalization
%   3. Removes DMRS positions from output
%
%   See also: DMRS_process, DMRS_heuristic

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
function Yeq = PDCCH_equalize(Y,C_est_DMRS,l)
	if nargin < 3
		l = 0;
	end
	N_DMRS = numel(C_est_DMRS);
	H_est = zeros(4*N_DMRS,1);
	sc_ind = sort([4*(0:N_DMRS-1),2+4*(0:N_DMRS-1),3+4*(0:N_DMRS-1)]).';
	H_est(1+(1+4*(0:N_DMRS-1))) = Y(2:4:end,1+l)./C_est_DMRS;
	tmp = unwrap(angle(H_est(2:4:end)));
	slope_angle_H_est = (tmp(end)-tmp(1))/(N_DMRS-1);
	mean_angle_H_est = mean(tmp);

	temp_h = ifft(H_est.*exp(-1i*mean_angle_H_est-1i*(0:4*N_DMRS-1).'*slope_angle_H_est/4));
	temp_h(floor(N_DMRS/2)+1:N_DMRS*4-floor(N_DMRS/2)-1) = 0;
	temp_h([floor(N_DMRS/2),N_DMRS*4-floor(N_DMRS/2)]) = ...
		0.5*temp_h([floor(N_DMRS/2),N_DMRS*4-floor(N_DMRS/2)]);
	temp_H = 4*fft(temp_h).*exp(1i*mean_angle_H_est+1i*(0:N_DMRS*4-1).'*slope_angle_H_est/4);
	%hold off
	%plot(0:N_DMRS*4-1,temp_H);
	%hold on
	%plot(1+4*(0:N_DRMS-1),abs(H_est(2:4:end)))

	Yeq = Y(1+sc_ind,:)./temp_H(1+sc_ind,ones(1,size(Y,2))); % ZF
end
