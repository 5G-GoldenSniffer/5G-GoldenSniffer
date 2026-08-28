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
function [b_tilde0,EA,EB] = make_E_dci(G)
	N_RNTI_crc = 16;
	%                    Case A          Case B
	N_RNTI_scr = 15; % = 0x0000  || RNTI_crc & 0x7fff
	N_NID = 16;      % = ncellid || DMRS_scramblingID
	N_CRC = 24;      % = ones(1,24)
	N_X1 = 1;        % = 1
	N_DCI = size(G,1) - (N_RNTI_crc+N_RNTI_scr+N_NID+N_CRC+N_X1);
	Mbit = size(G,2);

	b_tilde0 = uint8(mod(ones(1,N_CRC+N_X1)*single(G(end-N_CRC-N_X1+1:end,:)),2));
	% G_NID = G(N_DCI+N_RNTI_crc+N_RNTI_scr+(1:N_NID),:);
	% GA = G(1:N_DCI+N_RNTI_crc,:)
	GB = G(1:N_DCI+N_RNTI_crc,:);
	GB(N_DCI+2:end,:) = mod(GB(N_DCI+2:end,:)+G(N_DCI+N_RNTI_crc+(1:N_RNTI_scr),:),2);
	
	% case A:
	% b_tilde - b_tilde0 - [ncellid]*G_NID           = [dci,rnti_crc]*GA
	% case B:
	% b_tilde - b_tilde0 - [DMRS_scramblingID]*G_NID = [dci,rnti_crc]*GB

	% since crc_init, x1_init are known:
	% b_tilde - [crc_init,x1_init]*G(end-N_CRC-N_X1+1:end,:) = ...
	%                                [dci,rnti_crc,rnti_scr,nid]*G(1:N_DCI+N_RNTI_crc+N_RNTI_scr+N_NID,:)
	% solve: x * G = b_tilde * I
	%       x(DCI,RNTIcrc,RNTIscr,NID) * G(DCI,RNTIcrc,RNTIsrc,NID) = ...
	%                                         b_tilde - x(CRC,X1)*G(CRC,X1)
	% by Gauss elimination
	if N_DCI+N_RNTI_crc > Mbit
		fprintf('N_DCI max = %d\n',Mbit-(N_RNTI_crc+8)); % RFC
		%%%keyboard
	end
	
	EA = gauss_el(G(1:N_DCI+N_RNTI_crc,:));
	EB = gauss_el(GB);
end

% Gauss elimination with pivoting
function E = gauss_el(G)
	Mbit = size(G,2);
	E = eye(Mbit,'uint8');
	for i = 1:size(G,1)
		if G(i,i)==0
			pivot = 0;
			for j = i+1:Mbit
				if G(i,j)
					G(:,i)=mod(G(:,i)+G(:,j),2);
					E(:,i)=mod(E(:,i)+E(:,j),2);
					pivot = 1;
					break
				end
			end
			if pivot == 0
				%%%keyboard
			end
		end
		for j = i+1:Mbit
			if G(i,j)
				G(:,j)=mod(G(:,j)+G(:,i),2);
				E(:,j)=mod(E(:,j)+E(:,i),2);
			end
		end
	end
	for i = size(G,1):-1:2
		for j = i-1:-1:1
			if G(i,j)
				G(:,j)=mod(G(:,j)+G(:,i),2);
				E(:,j)=mod(E(:,j)+E(:,i),2);
			end
		end
	end 
end
