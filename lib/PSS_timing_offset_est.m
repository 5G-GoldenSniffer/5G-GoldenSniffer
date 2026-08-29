%PSS_TIMING_OFFSET_EST Estimate timing offset using PSS correlation
%   [PBCH_IN_FRAME, SKIP, CFO_ED] = PSS_TIMING_OFFSET_EST(Y, K120, PSS_IND, 
%   SYMSSB_OFS, H_EST_PSS, PSS_FREQ, SSS_FREQ, NCELLID, THRES, FS) estimates
%   the timing offset of the current frame using PSS correlation.
%
%   Inputs:
%       Y           - Frequency domain frame (N_FFT x Nsymb_frame)
%       K120        - Subcarrier offset to GSCN frequency
%       PSS_IND     - PSS subcarrier indices relative to SSB center
%       SYMSSB_OFS  - Expected SSB symbol offset in frame
%       H_EST_PSS   - Channel estimate from previous PSS
%       PSS_FREQ    - PSS sequences in frequency domain
%       SSS_FREQ    - SSS sequences for this NID2
%       NCELLID     - Physical cell ID
%       THRES       - Correlation threshold
%       FS          - Sample rate
%
%   Outputs:
%       PBCH_IN_FRAME - Boolean indicating PBCH is present in current frame
%       SKIP          - Number of samples to skip/rewind for alignment
%       CFO_ED        - Estimated CFO correction
%
%   See also: whole_frame_fft, ofdm_fft

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
function [PBCH_in_frame,skip_for_sync,Cfo_est] = PSS_timing_offset_est(Y,k120,PSS_ind,...
		symSSB_ofs,H_est_PSS0,PSS_freq,SSS_freq,ncellid,PSS_corr_thres,fs,SCS,FIGURES)
	N_FFT = size(Y,1);
	NID2 = mod(ncellid,3);
	NID1 = (ncellid - NID2)/3;
	skip_for_sync = 0;
	Cfo_est = 0;
	PBCH_in_frame = false;
	
	% timing estimate based on the equalized PSS (high SNR).
	% If PSS is not present, val is low and skip_for_sync=0
	H_est_PSS = Y(1+N_FFT/2+k120+PSS_ind,1+symSSB_ofs).*PSS_freq(1+N_FFT/2+PSS_ind,1+NID2);
	H_est_PSS_corr = abs(H_est_PSS'*H_est_PSS0)/(norm(H_est_PSS0)*norm(H_est_PSS));
	if H_est_PSS_corr > PSS_corr_thres
		PBCH_in_frame = true;
		exp_iphi_epst = H_est_PSS./H_est_PSS0;
		tmp = fftshift(ifft(exp_iphi_epst,512))*512/127;
		[~,pos]=max_parab(abs(tmp));pos=(pos-1-512/2)/(512/127);
		Ts_tmp = 1/(fs/(127*SCS));
		skip_for_sync = round(pos/Ts_tmp);
		if bitand(FIGURES,0x0004)
			currentfigure(3)
			% Subplot 1: Magnitude of Estimated Phase
			subplot(3,1,1)
			plot(PSS_ind, abs(exp_iphi_epst), 'b-', 'LineWidth', 1.5)
			ylabel('|exp(i\phi)_{est}|')
			xlabel('Subcarrier Index (k)')
			title('Magnitude of H_{est,PSS}/H_{est,PSS0}')
			ylim([0 1.2])
			grid on

			% Subplot 2: Phase of Estimated Phase
			subplot(3,1,2)
			plot(PSS_ind, angle(exp_iphi_epst), 'r-', 'LineWidth', 1.5)
			ylabel('arg(exp(i\phi)_{est}) [rad]')
			xlabel('Subcarrier Index (k)')
			title('Phase of H_{est,PSS}/H_{est,PSS0}')
			ylim([-pi pi])
			grid on

			% Subplot 3: IFFT of Estimated Phase for Timing Offset Detection
			subplot(3,1,3)
			ifft_result = fftshift(ifft(exp_iphi_epst, 512)) * 512 / 127;
			plot(-256:255, abs(ifft_result), 'g-', 'LineWidth', 1.5)
			xlim([-10 10])
			xlabel('Time Domain Index (n)')
			ylabel('Magnitude |IFFT[exp(i\phi)_{est}]|')
			title('IFFT of H_{est,PSS}/H_{est,PSS0} for Timing Offset Detection')
			grid on

			drawnow
		end

		H_est_PSS = Y(1+N_FFT/2+k120+PSS_ind,1+symSSB_ofs)./PSS_freq(1+N_FFT/2+PSS_ind,1+NID2);
		H_est_SSS = Y(1+N_FFT/2+k120+PSS_ind,3+symSSB_ofs)./SSS_freq(:,1+NID1);
		N_CP=9/128*N_FFT;
		Cfo_est = angle(sum(H_est_SSS([1:63,67:127]).*conj(H_est_PSS([1:63,67:127]))))*fs/(4*pi*(N_FFT+N_CP));
		if bitand(FIGURES,0x0008)
			currentfigure(4)
			hold off
			plot(angle(H_est_PSS), 'b-', 'LineWidth', 1.5)
			hold on
			plot(angle(H_est_SSS), 'r--', 'LineWidth', 1.5)
			ylim([-pi pi])
			xlabel('Subcarrier Index (k)')
			ylabel('Phase of Channel Estimates [rad]')
			title('Phase Spectrum Comparison: PSS vs. SSS Channel Estimates')
			legend({'PSS Channel Estimate', 'SSS Channel Estimate'}, 'Location', 'best')
			grid on
			drawnow
		end
	end
end
