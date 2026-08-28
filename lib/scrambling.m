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
% 5.2.1 38.211
function c = scrambling(M_PN,c_init,x1_init)
	if nargin < 3
		x1_init = 1;
	end
	if nargin < 2
		% N_symb^slot = 14 except for mu=2
		% n_{s,f}^mu = slot number within the frame (for given mu) {0-9 for mu=0}
		% l = OFDM symbol number within the slot {0-13 for mu=0}
		% N_ID: pdcch-DMRS-ScramblingID
		% c_init = mod(2^17*(N_symb^slot*n_{s,f}^mu+l+1)*(2*N_ID+1)+2*N_ID,2^31);
		c_init = 1;
	end
	Nc = 1600;
	x1 = zeros(1,Nc+M_PN);
	x2 = zeros(1,Nc+M_PN);
	x1(1+ 0) = x1_init;
	x1(1+ (1:30)) = 0;
	x2(1+ (0:30)) = de2bi(c_init,31);
	for n = 1:M_PN+Nc-31
		x1(n+31) = mod(x1(n+3)+x1(n),2);
		x2(n+31) = mod(x2(n+3)+x2(n+2)+x2(n+1)+x2(n),2);
	end
	c = zeros(1,M_PN);
	for n = 1:M_PN
		c(n) = mod(x1(n+Nc)+x2(n+Nc),2);
	end
end
