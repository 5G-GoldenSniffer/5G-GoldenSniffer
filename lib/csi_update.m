% noCDM NZP-CSI-RS tests

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
function csi = csi_update(Y,N_RB,SFN,csi,FIGURES)

	Nsymb_frame = size(Y,2);
	if csi.SFN_period < 0
		for l = 1:Nsymb_frame
			if csi.k0 < 0
				for k0 = 0:csi.sc_spacing-1
					[is_ok,c_init_CSI,nID_tmp] = csi_check(Y,l,k0,csi.sc_spacing,N_RB);
					if is_ok
						csi.nID = nID_tmp;
						% fprintf('  [CSI] symbol=%d nID=%d k0=%d\n',l-1,nID_tmp,k0);
						csi.k0 = k0;
						if csi.bitmap(l) == 0
							csi.bitmap(l) = 1;
							if csi.SFN < 0
								csi.SFN = SFN;
							end
						elseif csi.SFN_period < 0
							csi.SFN_period = SFN - csi.SFN;
							csi.SFN = mod(csi.SFN,csi.SFN_period);
						end
						break
					end
				end
			else
				[is_ok,c_init_CSI,nID_tmp] = csi_check(Y,l,csi.k0,csi.sc_spacing,N_RB);
				if is_ok
					csi.nID = nID_tmp;
					% fprintf('  [CSI] symbol=%d nID=%d',l-1,csi_nID_tmp);
					if csi.bitmap(l) == 0
						csi.bitmap(l) = 1;
						if csi.SFN < 0
							csi.SFN = SFN;
						end
						% fprintf('\n');
					elseif csi.SFN_period < 0
						csi.SFN_period = SFN - csi.SFN;
						csi.SFN = mod(csi.SFN,csi.SFN_period);
						% fprintf(' (SFN%%%d)==%d\n',csi_SFN_period,csi_SFN);
					else
						% fprintf('\n');
					end
				end
			end
		end
	elseif mod(SFN,csi.SFN_period) == csi.SFN
		for l = find(csi.bitmap)
			[is_ok,c_init_CSI,nID_tmp] = csi_check(Y,l,csi.k0,csi.sc_spacing,N_RB);
			if is_ok
				% fprintf('  [CSI] symbol=%d nID=%d\n',l-1,nID_tmp);
				csi.nID = nID_tmp;
			end
		end
		% else
		% csi.nID = -1;
	end
end
