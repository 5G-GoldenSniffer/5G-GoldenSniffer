%SSS_FUNC Generate Secondary Synchronization Signal sequences
%   SSS = SSS_FUNC(NID2) returns the 336 SSS sequences for a given NID2.
%
%   Input:
%       NID2 - Physical layer cell identity group (0, 1, or 2)
%
%   Output:
%       SSS - 127x336 matrix containing SSS sequences in frequency domain
%             Column i corresponds to NID1 = i-1
%
%   The SSS is a product of two m-sequences, mapped to 127 subcarriers.
%   The sequence is defined in TS 38.211 Section 7.4.2.3.
%
%   See also: PSS_func, nrSSS

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
function d_SSS = SSS_func(NID2)
	x0 = zeros(1,127);
	x0(1+(0:6)) = [1 0 0 0 0 0 0];
	x1 = zeros(1,127);
	x1(1+(0:6)) = [1 0 0 0 0 0 0];
	for i = 8:127
		x0(i)=mod(x0(i-3)+x0(i-7),2);
		x1(i)=mod(x1(i-6)+x1(i-7),2);
	end
	d_SSS = zeros(127,336);
	for NID1 = 0:335
		m0 = 15*floor(NID1/112)+5*NID2;
		m1 = mod(NID1,112);
		d_SSS(1+(0:126),1+NID1) = (1-2*x0(1+mod((0:126)+m0,127))).*(1-2*x1(1+mod((0:126)+m1,127)));
	end
end
