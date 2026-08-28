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
function [N_ID__nSCID,nSCID,DMRS_addPos] = PDSCH_DMRS_autodetect(rxSlotGrid,BWPstart,RBstart,L_RB,slot,duration)
	Nsc_RB = 12;

	% single layer PDSCH DM-RS has the odd subcarriers empty
	DMRS_ind = (BWPstart+RBstart)*Nsc_RB+(0:2:L_RB*Nsc_RB-1);
	tmp = abs(rxSlotGrid((BWPstart+RBstart)*Nsc_RB+(1:L_RB*Nsc_RB),duration+1:end));
	l_dmrs_set = duration + find(mean(tmp(1:2:end,:))-mean(tmp(2:2:end,:)) > 3*(std(tmp(1:2:end,:))+std(tmp(2:2:end,:)))) - 1;
	if isempty(l_dmrs_set) || L_RB<3
		N_ID__nSCID = -1;
		nSCID = -1;
		DMRS_addPos = -1;
		return
	end
	for l_dmrs = l_dmrs_set
		Ydmrs = rxSlotGrid(1+DMRS_ind,1+l_dmrs);
		Ydmrs_corr = unwrap_QPSK(Ydmrs);
		C_est = Ydmrs./Ydmrs_corr;
		[is_ok,c_init_DMRS,~] = DMRS_process(C_est(max(L_RB-4,0)*Nsc_RB/2+1:end),...
			(BWPstart+RBstart)*Nsc_RB+max(L_RB-4,0)*Nsc_RB,2);
		if ~is_ok
			continue % next PDSCH-DMRS
		end
		[n_b_found,N_ID__nSCID,nsfmu,l_est,nSCID] = c_init_PDSCH_DMRS_decode(c_init_DMRS);
		if n_b_found && l_est==l_dmrs && nsfmu==slot
			break % found a working set
		end
	end
	if ~is_ok % Not the expected DMRS format
		N_ID__nSCID = -1;
		nSCID = -1;
		DMRS_addPos = -1;
		return
	end
	if numel(l_dmrs_set)==3 && all(l_dmrs_set==[2 7 11])
		DMRS_addPos = 2;
	elseif numel(l_dmrs_set)==2 && all(l_dmrs_set==[2 11])
		DMRS_addPos = 1;
	else
		N_ID__nSCID = -1;
		nSCID = -1;
		DMRS_addPos = -1;
	end
end
