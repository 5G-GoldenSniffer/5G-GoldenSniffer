% from 38.331/38.214/38.213
% initialBandwidthPart = N_BWP^size*(L_RB-1)+RB_start = 14025
% => L_RB = 52 RB and RB_start = 0 with N_BWP^size=275

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
function [Lrbs,RBstart] = hDecodeRIV(NSizeBWP,RIV)
	Lrbs = floor(RIV / NSizeBWP) + 1;
	RBstart = RIV - ((Lrbs - 1) * NSizeBWP);
	if Lrbs > NSizeBWP - RBstart
		Lrbs = NSizeBWP - Lrbs + 2;
		RBstart = NSizeBWP - 1 - RBstart;
	end
end
