%PSS_FUNC Generate Primary Synchronization Signal sequences
%   PSS = PSS_FUNC() returns the three PSS sequences for NID2 = 0, 1, 2.
%
%   Output:
%       PSS - 127x3 matrix containing PSS sequences in frequency domain
%             Column 1: NID2 = 0
%             Column 2: NID2 = 1
%             Column 3: NID2 = 2
%
%   The PSS is an m-sequence of length 127, mapped to 127 subcarriers
%   centered around the SSB center frequency. The sequence is defined
%   in TS 38.211 Section 7.4.2.2.
%
%   See also: SSS_func, nrPSS

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
function d_PSS = PSS_func
	x = zeros(1,127);
	x(1+(0:6)) = [0 1 1 0 1 1 1];
	for i = 8:127
		x(i)=mod(x(i-7)+x(i-3),2);
	end
	d_PSS = zeros(127,3);
	for NID2 = 0:2
		d_PSS(:,1+NID2) = 1-2*x(1+mod((0:126)+43*NID2,127));
	end
end
