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
	Hsc_ind = sort([4*(0:N_DMRS-1),2+4*(0:N_DMRS-1),3+4*(0:N_DMRS-1)]);
	H_est(1+(1+4*(0:N_DMRS-1))) = Y(2:4:end,1+l)./C_est_DMRS;
	tmp = unwrap(angle(H_est(2:4:end)));
	slope_angle_H_est = (tmp(end)-tmp(1))/(N_DMRS-1);
	mean_angle_H_est = mean(tmp);

	k = 0:N_DMRS-1;
	sc_ind = sort([4*k(:);4*k(:)+2;4*k(:)+3]);

	temp_h = ifft(H_est.*exp(-1i*mean_angle_H_est-1i*(0:4*N_DMRS-1).'*slope_angle_H_est/4));
	temp_h(floor(N_DMRS/2)+1:N_DMRS*4-floor(N_DMRS/2)-1) = 0;
	temp_h([floor(N_DMRS/2),N_DMRS*4-floor(N_DMRS/2)]) = ...
		0.5*temp_h([floor(N_DMRS/2),N_DMRS*4-floor(N_DMRS/2)]);
	temp_H = 4*fft(temp_h).*exp(1i*mean_angle_H_est+1i*(0:N_DMRS*4-1).'*slope_angle_H_est/4);
	%hold off
	%plot(0:N_DMRS*4-1,temp_H);
	%hold on
	%plot(1+4*k,abs(H_est(2:4:end)))

	Yeq = Y(1+sc_ind,:)./temp_H(1+Hsc_ind,ones(1,size(Y,2))); % ZF
end
% 
% 
% function Y_eq = PDCCH_equalize(Y, dmrs_ind, C_est)
%     Y = Y(:);
%     C_est = C_est(:);
% 
%     N = length(Y);
% 
%     % Ensure dmrs_ind is 1-based
%     dmrs_ind = dmrs_ind(:)';
%     if min(dmrs_ind) == 0
%         dmrs_ind = dmrs_ind + 1;
%     end
% 
%     % Interpolate channel estimates to all subcarriers
%     H_interp = zeros(N, 1);
% 
%     if length(C_est) >= 2
%         % Use linear interpolation
%         H_interp = interp1(dmrs_ind, C_est, 1:N, 'linear', 'extrap');
%     else
%         % Single DMRS - use constant channel
%         H_interp(:) = C_est(1);
%     end
% 
%     % Estimate noise variance from DMRS residual
%     if length(C_est) > 2
%         H_at_dmrs = H_interp(dmrs_ind);
%         noise_power = mean(abs(C_est - H_at_dmrs.').^2);
%     else
%         noise_power = 0.01 * mean(abs(C_est).^2);  % Assume 20 dB SNR
%     end
% 
%     % MMSE equalization
%     H_interp = H_interp(:);
%     signal_power = mean(abs(H_interp).^2);
% 
%     if noise_power > 0
%         mmse_weights = conj(H_interp) ./ (abs(H_interp).^2 + noise_power/signal_power);
%     else
%         mmse_weights = conj(H_interp) ./ (abs(H_interp).^2 + 1e-10);
%     end
% 
%     Y_eq_all = Y .* mmse_weights;
% 
%     % Remove DMRS positions
%     data_ind = setdiff(1:N, dmrs_ind);
%     Y_eq = Y_eq_all(data_ind);
% end
