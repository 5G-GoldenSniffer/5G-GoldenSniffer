%WHOLE_FRAME_FFT Perform OFDM demodulation for entire frame
%   [Y,CP_corr] = WHOLE_FRAME_FFT(S, N_FFT, NSYMB_FRAME, MU, PHASE_COMP) performs
%   OFDM demodulation on all symbols in a 10ms frame.
%
%   Inputs:
%       S           - Time domain signal (1 x NS samples)
%       N_FFT       - FFT size
%       NSYMB_FRAME - Number of OFDM symbols per frame
%       MU          - Numerology (0 for 15kHz, 1 for 30kHz, etc.)
%       PHASE_COMP  - Phase compensation per symbol (1 x NSYMB_SUBFRAME)
%
%   Output:
%       Y - Frequency domain frame (N_FFT x NSYMB_FRAME)
%
%   The function handles:
%   - Variable cyclic prefix lengths (first symbol of slot has longer CP)
%   - Phase compensation for each symbol
%   - Proper subcarrier ordering via fftshift
%
%   See also: ofdm_fft

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
function Y = whole_frame_fft(s,N_FFT,Nsymb_frame,mu,phase_comp,TDD_pattern,TA)
	ns = numel(s);
	N_CP = 9/128*N_FFT;
	N_CP_07 = (9+2^mu)/128*N_FFT;
	CP_slack = N_FFT/128;
	Nsymb_subframe = Nsymb_frame/10;

	% cf(15)
	% plot(abs(conv(s.*circshift(conj(s),[1 N_FFT]),ones(1,N_CP)))./sqrt(conv(abs(s).^2,ones(1,N_CP)).*circshift(conv(abs(s).^2,ones(1,N_CP)),[1 N_FFT])))
	
	ofs = 0;
	l = 0;
	i = 0;
	Y = zeros(N_FFT,Nsymb_frame);
	CP_corr = zeros(1,Nsymb_frame);
	while i < Nsymb_frame
		if TDD_pattern(1+mod(floor(i/14),10))==1
			ofs2 = -TA;
		elseif TDD_pattern(1+mod(floor(i/14),10))==0
			ofs2 = 0;
		else
			if mod(i,14)<6
				ofs2 = 0;
			else
				ofs2 = -TA;
			end
		end
		if mod(l,7*2^mu) == 0
			[Y(:,1+i),CP_corr(1+i)] = ofdm_fft(s,ofs+ofs2+N_CP_07-N_CP,CP_slack,N_CP,N_FFT,0);
			Y(:,1+i) = Y(:,1+i)*exp(1i*phase_comp(1+l));
			ofs = ofs + N_FFT + N_CP_07;
		else
			[Y(:,1+i),CP_corr(1+i)] = ofdm_fft(s,ofs+ofs2,CP_slack,N_CP,N_FFT,0);
			Y(:,1+i) = Y(:,1+i)*exp(1i*phase_comp(1+l));
			ofs = ofs + N_FFT + N_CP;
		end
		i = i+1;
		l = mod(l+1,Nsymb_subframe);
	end

end
