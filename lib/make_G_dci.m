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
function G = make_G_dci(N_DCI,Mbit)

	N_RNTI_crc = 16;
	N_RNTI_scr = 15; % = 0x0000  || RNTI_crc & 0x7fff
	N_NID = 16;      % = ncellid || DMRS_scramblingID
	N_CRC = 24;      % = ones(1,24)
	N_X1 = 1;        % = 1

	% DCI encoding matrix:
	% b_tilde = [dci,rnti_crc,rnti_scr,N_ID,crc_init,x1_init]*G

	G = zeros(N_DCI+N_RNTI_crc+N_RNTI_scr+N_NID+N_CRC+N_X1,Mbit,'uint8');
	dci = zeros(1,N_DCI);
	rnti_crc = zeros(1,N_RNTI_crc);
	rnti_scr = zeros(1,N_RNTI_scr);
	N_ID = zeros(1,N_NID);
	crc_init = zeros(1,N_CRC);
	x1_init = 0;
	for i = 1:N_DCI
		dci(i) = 1;
		G(i,:) = uint8(dci_encode(dci,rnti_crc,rnti_scr,N_ID,Mbit,crc_init,x1_init));
		dci(i) = 0;
	end
	for i = 1:N_RNTI_crc
		rnti_crc(i) = 1;
		G(N_DCI+i,:) = uint8(dci_encode(dci,rnti_crc,rnti_scr,N_ID,Mbit,crc_init,x1_init));
		rnti_crc(i) = 0;
	end
	for i = 1:N_RNTI_scr
		rnti_scr(i) = 1;
		G(N_DCI+N_RNTI_crc+i,:) = uint8(dci_encode(dci,rnti_crc,rnti_scr,N_ID,Mbit,crc_init,x1_init));
		rnti_scr(i) = 0;
	end
	for i = 1:N_NID
		N_ID(i) = 1;
		G(N_DCI+N_RNTI_crc+N_RNTI_scr+i,:) = uint8(dci_encode(dci,rnti_crc,rnti_scr,N_ID,Mbit,crc_init,x1_init));
		N_ID(i) = 0;
	end
	for i = 1:N_CRC
		crc_init(i) = 1;
		G(N_DCI+N_RNTI_crc+N_RNTI_scr+N_NID+i,:) = uint8(dci_encode(dci,rnti_crc,rnti_scr,N_ID,Mbit,crc_init,x1_init));
		crc_init(i) = 0;
	end
	x1_init = 1;
	G(N_DCI+N_RNTI_crc+N_RNTI_scr+N_NID+N_CRC+N_X1,:) = uint8(dci_encode(dci,rnti_crc,rnti_scr,N_ID,Mbit,crc_init,x1_init));
	x1_init = 0;

	if 0
		% verify
		dci = floor(2*rand(1,N_DCI));
		rnti_crc = floor(2*rand(1,N_RNTI_crc));
		rnti_scr = floor(2*rand(1,N_RNTI_scr));
		N_ID = floor(2*rand(1,N_NID));
		crc_init = floor(2*rand(1,N_CRC));
		x1_init = floor(2*rand);
		b_tilde = dci_encode(dci,rnti_crc,rnti_scr,N_ID,Mbit,crc_init,x1_init);
		sum(b_tilde-mod([dci,rnti_crc,rnti_scr,N_ID,crc_init,x1_init]*G,2))
		%%%keyboard
	end
end
