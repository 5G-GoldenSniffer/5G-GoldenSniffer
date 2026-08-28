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
function [is_ok,c_init_CSI,nID] = csi_check(Y,l,k0,csi_sc_spacing,N_RB)
	Nsc_RB = 12;
	N_FFT = size(Y,1);
	sc = k0+(-N_RB*Nsc_RB/2:csi_sc_spacing:N_RB*Nsc_RB/2-1);
	Ycsi = Y(1+N_FFT/2+sc,l);
	Ycsi_corr = unwrap_QPSK(Ycsi);
	C_csi = Ycsi./Ycsi_corr;
	[is_ok,c_init_CSI] = DMRS_process(C_csi,k0,csi_sc_spacing);
	if is_ok
		% c_init_CSI = mod(2^10*(Nsymb_slot*nsfmu+l+1)*(2*nID+1)+nID,2^31);
		nID = mod(c_init_CSI,2^10);
		if c_init_CSI ~= mod(2^10*l*(2*nID+1)+nID,2^31)
			is_ok = false;
		end
	end
	if ~is_ok
		c_init_CSI = [];
		nID = [];
	end
end
