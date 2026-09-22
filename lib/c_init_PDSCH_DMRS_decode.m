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
function [found,N_ID__nSCID,nSCID] = c_init_PDSCH_DMRS_decode(c_init_DMRS,K)
	% K = 2^17*(N_symb^slot*n_{s,f}^mu+l+1)
	% c_init = mod(K*(2*N_ID^nSCID+1)+2*N_ID^nSCID+nSCID,2^31);
	nSCID = mod(c_init_DMRS,2);
	N_ID__nSCID = mod(c_init_DMRS/2,2^16);
	found = c_init_DMRS == mod(K*(2*N_ID__nSCID+1)+2*N_ID__nSCID+nSCID,2^31);
end
