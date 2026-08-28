%C_INIT_PDCCH_DMRS_DECODE Decode PDCCH DMRS scrambling initialization
%   [FOUND, NID] = C_INIT_PDCCH_DMRS_DECODE(C_INIT, K) extracts the NID
%   from the C_INIT value and checks its coherence with the slot and symbol
%   index encoded in K = 2^17 * (n_sf * 2^mu + l + 1)
%
%   Inputs:
%       C_INIT - Scrambling sequence initialization value
%       K      - 2^17 * (n_sf^mu + l + 1)
%
%   Outputs:
%       FOUND - Boolean indicating successful decode
%       NID   - DMRS scrambling ID (N_ID or cell ID)
%
%   The PDCCH DMRS c_init is calculated as:
%   c_init = 2^17 * (n_sf * 2^mu + l + 1) * (2*N_ID + 1) + 2*N_ID
%
%   Where:
%   - n_sf: Slot number
%   - l: Symbol index within slot
%   - N_ID: Scrambling ID
%
%   See also: DMRS_process

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
function [found,N_ID] = c_init_PDCCH_DMRS_decode(c_init_DMRS,K)
	if mod(c_init_DMRS,2)==0
		N_ID = mod(c_init_DMRS/2,2^16);
		found = c_init_DMRS == mod(K*(2*N_ID+1)+2*N_ID,2^31);
	else
		N_ID = [];
		found = false;
	end
end
