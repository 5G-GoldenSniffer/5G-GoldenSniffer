%DMRS_PROCESS Process DMRS for channel estimation and scrambling ID recovery
%   [IS_OK, C_INIT, C_EST_DMRS] = DMRS_PROCESS(C_EST, K_OFFSET, SPACING)
%   processes DMRS channel estimates to extract the scrambling sequence
%   initialization value.
%
%   Inputs:
%       C_EST    - Channel estimates at DMRS positions (complex vector)
%       K_OFFSET - Subcarrier offset of first DMRS
%       SPACING  - DMRS subcarrier spacing (typically 4)
%
%   Outputs:
%       IS_OK      - Boolean indicating successful DMRS processing
%       C_INIT     - Recovered scrambling sequence initialization
%       C_EST_DMRS - Refined channel estimates for equalization
%
%   The DMRS (Demodulation Reference Signal) uses a pseudo-random QPSK
%   sequence. By correlating the phase difference between adjacent DMRS
%   symbols, we can identify the scrambling sequence and recover the
%   initialization value c_init, which encodes:
%   - Symbol index
%   - Slot index  
%   - Scrambling ID
%
%   See also: unwrap_QPSK, DMRS_heuristic, PDCCH_equalize

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
function [is_ok,c_init_DMRS,C_est_DMRS] = DMRS_process(C_est,k0,sc_spacing)
	M_PN = numel(C_est)*2;
	c_est = zeros(1,M_PN);
	Nc = 1600;
	% the PDCCH and PDSCH DMRS, and the CSI sequences, are generated with
	% the index k evaluated starting from the beginning of the BandwidthPart
	% (not from the beginning of the used part of the symbol), so we must align
	% the sequence by introducing a delay of:
	% - floor(k0/Nsc_RB)*Nsc_RB (number of resource blocks before the one
	%   from which we extracted the DMRS)
	% - /DMRSperRB (number of DMRS subcarriers per RB)
	% - *2 because modulated in QPSK, 2 bits per symbol
	Nsc_RB = 12;
	D = floor(k0/Nsc_RB)*Nsc_RB/sc_spacing*2;
	x2_est = zeros(1,Nc+D+M_PN);
	%reconstruction of initial states
	for i = 1:4
		C_est_DMRS = C_est*exp(1i*(pi/4+(i-1)*pi/2));
		c_est(1+(0:2:M_PN-1)) = real(C_est_DMRS)<0;
		c_est(1+(1:2:M_PN-1)) = imag(C_est_DMRS)<0;
		x2_est(Nc+D+(1:M_PN)) = mod(c_est+scrambling_x1(M_PN,D),2); %xor with presumed x1
		is_ok = true;
		%does x2 satisfy the recursion?
		for n = Nc+D+M_PN-31:-1:Nc+D+1
			if x2_est(n) ~= mod(x2_est(n+31)+x2_est(n+3)+x2_est(n+2)+x2_est(n+1),2)
				is_ok = false;
				break
			end
		end
		if is_ok
			break
		end
	end
	if M_PN > 31
		for n = Nc+D:-1:1
			x2_est(n) = mod(x2_est(n+31)+x2_est(n+3)+x2_est(n+2)+x2_est(n+1),2);
		end
	end
	c_init_DMRS = bi2de(x2_est(1+(0:30)));
end
