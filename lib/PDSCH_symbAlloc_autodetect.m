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
function symbAlloc = PDSCH_symbAlloc_autodetect(rxSlotGrid,BWPstart,RBstart,L_RB,duration,symb_free_thres)
	Nsc_RB = 12;
	Nsymb_slot = size(rxSlotGrid,2);
	tmp=sum(abs(rxSlotGrid((BWPstart+RBstart)*Nsc_RB+(1:L_RB*Nsc_RB),duration+1:end)));
	if tmp(1) < symb_free_thres
		symbAlloc = [duration+1 Nsymb_slot-1-duration];
	else
		symbAlloc = [duration Nsymb_slot-duration];
	end
end
