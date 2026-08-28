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
function H_est = csi_H_est(Y,l,k0,csi_sc_spacing,N_RB,nID,FIGURES)

	Nsc_RB = 12;
	N_FFT = size(Y,1);
	sc = k0+(-N_RB*Nsc_RB/2:csi_sc_spacing:N_RB*Nsc_RB/2-1);
	Ycsi = Y(1+N_FFT/2+sc,1+l);
	c_init_CSI = mod(2^10*(l+1)*(2*nID+1)+nID,2^31);
	M_PN = 2*numel(sc);
	c = scrambling(M_PN,c_init_CSI).';
	C_csi = (1-2*c(1:2:end))+1i*(1-2*c(2:2:end));
	H_est = zeros(N_FFT,1);
	H_est(1+N_FFT/2+sc) = Ycsi./C_csi;
	temp=ifftshift(ifft(fftshift(H_est)));
	len = floor(N_FFT/(2*csi_sc_spacing));
	temp(N_FFT/2+(-len:len))=temp(N_FFT/2+(-len:len)).*gausswin(2*len+1,1);
	temp([1:N_FFT/2-len-1,N_FFT/2+len+1:end])=0;
	H_est_interp = fftshift(fft(ifftshift(temp)))*csi_sc_spacing;
	if bitand(FIGURES,0x0080)
		currentfigure(8)

		% Subplot 1: Magnitude of Estimated Channel
		subplot(2,1,1)
		hold off
		plot(-N_FFT/2:N_FFT/2-1, 20*log10(abs(H_est_interp)), 'b-', 'LineWidth', 1.5)
		xlabel('Subcarrier Index (k)')
		ylabel('|H_{est}| [dB]')
		title('Magnitude Spectrum of CSI-RS Estimated Channel (H_{est})')
		grid on

		% Subplot 2: Phase of Estimated Channel
		subplot(2,1,2)
		hold off
		plot(-N_FFT/2:N_FFT/2-1, angle(H_est_interp), 'r--', 'LineWidth', 1.5)
		xlabel('Subcarrier Index (k)')
		ylabel('Phase of H_{est} [rad]')
		title('Phase Spectrum of CSI-RS Estimated Channel (H_{est})')
		grid on

		drawnow
	end

end
