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
function [FDA_BWP_hyp,nHyp] = find_FDA_BWP_hypotheses(Yslot,RB_busy_thres,BWP_int,fda,RBst_dci,L_RB_dci)
	Nsc_RB = 12;
	N_RB = size(Yslot,1)/Nsc_RB;

	% bitmap of the busy RBs in the slot
	RB_bitmap = zeros(1,N_RB);
	tmp = sum(reshape(sum(abs(Yslot),2),Nsc_RB,N_RB));
	RB_contiguous_max = 0;
	RB_contiguous = 0;
	for i = 1:N_RB
		if tmp(i) > RB_busy_thres
			RB_bitmap(i) = 1;
			RB_contiguous = RB_contiguous + 1;
		else
			if RB_contiguous > RB_contiguous_max
				RB_contiguous_max = RB_contiguous;
			end
			RB_contiguous = 0;
		end
	end
	if RB_bitmap(N_RB) == 1 && RB_contiguous >= RB_contiguous_max
		RB_contiguous_max = RB_contiguous;
	end
	if RB_contiguous_max == 0
		% if it is an empty slot but a DL DCI,
		% it's probably a delayed allocation
		FDA_BWP_hyp = [];
		return
	end

	% possible interpretations of the fda field
	list_size = BWP_int(2)-BWP_int(1)+1;
	L_RB_list = zeros(list_size,1);
	RBst_list = zeros(list_size,1);
	for i = 1:list_size
		BWPsize_try = BWP_int(1)+(i-1);
		[L_RB_list(i),RBst_list(i)] = hDecodeRIV(BWPsize_try,fda);
	end
	[~,ind] = sort(L_RB_list,'descend');

	% filter the ones compatible with the busy RB bitmap
	nHyp = 0;
	FDA_BWP_hyp = zeros(list_size,5);
	for i = 1:list_size
		RBstart_try = RBst_list(ind(i));
		L_RB_try = L_RB_list(ind(i));
		if L_RB_try > RB_contiguous_max
			continue % next BWPsize
		end
		BWPsize_try = BWP_int(1)+ind(i)-1;

		% tmp: offsets (RBstart) of the possible allocations in the RB_bitmap
		tmp = find(conv(RB_bitmap,ones(1,L_RB_try))==L_RB_try)-L_RB_try;
		for tmp_i = 1:numel(tmp)
			BWPstart_try = tmp(tmp_i)-RBstart_try;
			if BWPstart_try<0 ...
					|| RBst_dci < BWPstart_try ...
					|| RBst_dci+L_RB_dci > BWPstart_try + BWPsize_try ...
					|| BWPstart_try+BWPsize_try > N_RB
				continue
			end
			tmp_ambiguous = 0;
			for tmp_j = 1:nHyp
				if L_RB_try == FDA_BWP_hyp(tmp_j,1) ...
						&& RBstart_try+BWPstart_try == FDA_BWP_hyp(tmp_j,2)+FDA_BWP_hyp(tmp_j,4)
					FDA_BWP_hyp(tmp_j,5) = 1;
					tmp_ambiguous = 1;
				end
			end
			if tmp_ambiguous == 0
				nHyp = nHyp + 1;
				% RBstart_try = RBst_list(ind(i));
				% BWPstart_try = tmp(tmp_i)-RBst_list(ind(i));
				% BWPsize_try = FDA_BWP_int(1+fdaNbits,1)+ind(i)-1;
				FDA_BWP_hyp(nHyp,:) = [L_RB_try,RBstart_try,BWPsize_try,BWPstart_try,0];
				% fprintf('FDA:%d@%d BWP:%d@%d\n',L_RB_try,RBst_list(ind(i)),BWPsize,BWPstart);
			end
		end
	end
end
