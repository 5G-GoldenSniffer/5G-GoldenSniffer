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
function [RNTI_found,xr_est,RNTI_crc_check] = DCIdecode_try(b_tilde,N_DCI,Grnti,b_tilde0rnti,EArnti,EBrnti,ncellid,NID_dciDMRS,N_DCI_max_AL)
	N_DCI_min = 20;
	N_CRC = 24;
	N_RNTI_crc = 16;
	N_RNTI_scr = 15;
	N_NID = 16;
	Mbit = numel(b_tilde);
	log2AL = log2(Mbit/108);
	if log2AL < 0 || N_DCI > N_DCI_max_AL(1+log2AL)
		RNTI_found = false;
		RNTI_crc_check = [];
		xr_est = [];
		return
	end

	G = single(Grnti{N_DCI-N_DCI_min+1}{1+log2AL}(1:N_DCI+N_RNTI_crc,:));
	G_NID = single(Grnti{N_DCI-N_DCI_min+1}{1+log2AL}(N_DCI+N_RNTI_crc+N_RNTI_scr+(1:N_NID),:));
	RNTI_found = false;
	% Case B first
	if ncellid ~= NID_dciDMRS
		br = mod(b_tilde - single(b_tilde0rnti{N_DCI-N_DCI_min+1}{1+log2AL}) - (dec2bin(NID_dciDMRS,16)-'0')*G_NID,2);
		xr_est = mod(br*single(EBrnti{N_DCI-N_DCI_min+1}{1+log2AL}),2);
		RNTI_found = sum(xr_est(N_DCI+N_RNTI_crc+1:end))==0;
		% if ~RNTI_found
		% 	HB=EBrnti{N_DCI-N_DCI_min+1}{1+log2AL}(:,N_DCI+N_RNTI_crc+1:end);
		% 	ind = find(sum(mod(HB-repmat(xr_est(N_DCI+N_RNTI_crc+1:end),[Mbit,1]),2),2)==0);
		% 	if isscalar(ind)
		% 		xr_est = mod(xr_est+single(EBrnti{N_DCI-N_DCI_min+1}{1+log2AL}(ind,:)),2);
		% 		RNTI_found = sum(xr_est(N_DCI+N_RNTI_crc+1:end))==0;
		% 	end
		% end
	end
	% Case A
	if ncellid == NID_dciDMRS && ~RNTI_found
		br = mod(b_tilde - single(b_tilde0rnti{N_DCI-N_DCI_min+1}{1+log2AL}) - (dec2bin(ncellid,16)-'0')*G_NID,2);
		xr_est = mod(br*single(EArnti{N_DCI-N_DCI_min+1}{1+log2AL}),2);
		RNTI_found = sum(xr_est(N_DCI+N_RNTI_crc+1:end))==0;
		% if ~RNTI_found
		% 	% parity check matrix
		% 	HA = single(EArnti{N_DCI-N_DCI_min+1}{1+log2AL}(:,N_DCI+N_RNTI_crc+1:end));
		% 
		% 	% look for weight 1 coset leaders
		% 	Nind = 0;
		% 	for i = 1:Mbit
		% 		if sum(mod(HA(i,:)-xr_est(N_DCI+N_RNTI_crc+1:end),2))==0
		% 			ind = i;
		% 			Nind = Nind+1;
		% 		end
		% 	end
		% 	if Nind == 1
		% 		xr_est = mod(xr_est+single(EArnti{N_DCI-N_DCI_min+1}{1+log2AL}(ind,:)),2);
		% 		RNTI_found = sum(xr_est(N_DCI+N_RNTI_crc+1:end))==0;
		% 	end
		% 	if ~RNTI_found
		% 		% try with weight 2 (consecutive, same subcarrier) coset leaders
		% 		Nind = 0;
		% 		for i = 1:Mbit/2
		% 			if sum(mod(HA(2*i-1,:)+HA(2*i,:)-xr_est(N_DCI+N_RNTI_crc+1:end),2))==0
		% 				ind = i;
		% 				Nind = Nind+1;
		% 			end
		% 		end
		% 		if Nind == 1
		% 			xr_est = mod(xr_est+single(EArnti{N_DCI-N_DCI_min+1}{1+log2AL}(2*ind-1,:))+single(EArnti{N_DCI-N_DCI_min+1}{1+log2AL}(2*ind,:)),2);
		% 			RNTI_found = sum(xr_est(N_DCI+N_RNTI_crc+1:end))==0;
		% 		end
		% 	end
		% end
	end
	if RNTI_found
		RNTI_crc_check = sum(2.^(N_RNTI_crc-1:-1:0).*xr_est(N_DCI+(1:N_RNTI_crc)));
	else
		RNTI_crc_check = [];
	end
end
