% computes the possible BWPsize values for a given N_RB

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
function [FDA_BWP_int,nFDA_max] = FDA_BWP_int_calc(N_RB)

	% a BWP must be able to contain the DCI and the minimum bandwidth of a DCI
	% is obtained with AL 1 and duration 3, 2 RB
	N_RB_min = 2;
	nFDA_max = ceil(log2(N_RB*(N_RB+1)/2));
	FDA_BWP_int = zeros(1+nFDA_max,2);
	for i = N_RB_min:N_RB
		n = ceil(log2(i*(i+1)/2));
		if FDA_BWP_int(1+n,1)==0
			FDA_BWP_int(1+n,:) = i;
		else
			FDA_BWP_int(1+n,2) = i;
		end
	end
end
