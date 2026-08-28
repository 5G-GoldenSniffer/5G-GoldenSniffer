%GSCN_FREQS_MHZ Calculate GSCN frequencies for SSB search
%   GSCN = GSCN_FREQS_MHZ(F0_MHZ, FS_MHZ, BW_MHZ, SCS_MHZ) calculates the
%   Global Synchronization Channel Numbers (GSCN) frequencies that fall
%   within the capture bandwidth.
%
%   Inputs:
%       F0_MHZ  - Center frequency [MHz]
%       FS_MHZ  - Sample rate [MHz]
%       BW_MHZ  - Channel bandwidth [MHz]
%       SCS_MHZ - Subcarrier spacing [MHz]
%
%   Output:
%       GSCN - Array of GSCN frequencies [MHz]
%
%   The GSCN is defined in TS 38.104 and determines the possible SSB
%   center frequencies. For FR1, GSCN frequencies are given by:
%   - N * 1.2 MHz + M * 0.05 MHz, where M ∈ {1, 3, 5}
%
%   See also: SSB_filter

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
function GSCN = GSCN_freqs_MHz(f0_MHz,fs_MHz,BW_MHz,SCS_MHz)
	% 38.104 5.4.3
	if BW_MHz == 3
		%%%keyboard
		%BW=3MHz
		% #GSCN = 26638+3N+(M-3)/2
		% 0-1GHz: N*0.6MHz+M*50kHz, N=1:1665, M={1,3,5}
		% Band n100
		% #GSCN=41637 920.73MHz
		% #GSCN=41638 921.45MHz
	else % BW>3MHz
		if f0_MHz < 3000
			% #GSCN = 3*N+(M-3)/2
			% 0-3GHz: N*1.2MHz + M*0.05MHz, N=1:2499 M={1,3,5}

			% N_min*1.2+0.05 - 120*SCS_MHz >= f0_MHz-BW_MHz/2
			N_min = ceil((f0_MHz-BW_MHz/2 + 120*SCS_MHz - 0.05)/1.2);
			% N_max*1.2+0.25 + 119*SCS_MHz <= f0_MHz+BW_MHz/2
			N_max = floor((f0_MHz+BW_MHz/2 - 119*SCS_MHz - 0.25)/1.2);
			for M = [1 3 5]
				GSCN = (N_min:N_max)*1.2 + M*0.05;
				if abs(mod((GSCN(1)-f0_MHz)/SCS_MHz+0.5,1)-0.5)<0.05
					break
				end
			end
			% k_GSCN_vec = round((GSCN-f0_MHz)/SCS_MHz);
		elseif f0_MHz<24250
			% #GSCN = 7499+N
			% 3-24.25GHz: 3GHz + N*1.44MHz, N=0:14756

			% 3000+N_min*1.44 - 120*SCS_MHz >= f0_MHz-BW_MHz/2
			N_min = ceil((f0_MHz-BW_MHz/2 - 3000 + 120*SCS_MHz)/1.44);
			% 3000+N_max*1.44 + 119*SCS_MHz <= f0_MHz+BW_MHz/2
			N_max = floor((f0_MHz+BW_MHz/2 - 3000 - 119*SCS_MHz)/1.44);
			GSCN = 3000+(N_min:N_max)*1.44;
		else
			%%%keyboard
			% #GSCN = 22256+N
			% 24.25-100GHz: 24.25008GHz + N*17.28MHz, N=22256:26639
		end
	end
end
