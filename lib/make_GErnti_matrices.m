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
function [Grnti,b_tilde0rnti,EArnti,EBrnti,N_DCI_min,N_DCI_max_AL] = make_GErnti_matrices

	% two possible cases:
	% - N_RNTI_scr=0 N_NID=cellid
	% - N_RNTI_scr==N_RNTI_crc&0x7fff and N_NID==pdcch_DMRSscrID (known from the
	%     DM-RS phase analysis)
	% unknowns: DCI,N_RNTI_crc

	Nsc_RB = 12;
	Nsc_CCE = 6*Nsc_RB;
	Ndata_sc_CCE = 3/4*Nsc_CCE;
	Mbit = 2*Ndata_sc_CCE; % number of bits in a DCI with AL 1 (2:QPSK)

	N_DCI_min = 20;
	N_DCI_max_AL = 84*ones(1,5); % [84,140*ones(1,4)];

	log2AL_min = 0;
	log2AL_max = 4;

	DCI_filename=['lib/DCI_decoder_AL',num2str(2^log2AL_min),'-',num2str(2^log2AL_max),'.mat'];
	if exist(DCI_filename,'file')
		fprintf('Loading DCI decoding matrices...');
		DCI_load = load(DCI_filename,'Grnti','b_tilde0rnti','EArnti','EBrnti');
		Grnti = DCI_load.Grnti;
		b_tilde0rnti = DCI_load.b_tilde0rnti;
		EArnti = DCI_load.EArnti;
		EBrnti = DCI_load.EBrnti;
		fprintf(' done\n');
	else
		fprintf('Generating DCI decoding matrices, please wait:');
		for log2AL = log2AL_min:log2AL_max
			AL = 2^log2AL;
			fprintf(' AL%d',AL);
			for N_DCI = N_DCI_min:N_DCI_max_AL(1+log2AL)
				Grnti{N_DCI-N_DCI_min+1}{1+log2AL} = make_G_dci(N_DCI,Mbit*AL); %#ok<AGROW>
				[b_tilde0,EA,EB] = make_E_dci(Grnti{N_DCI-N_DCI_min+1}{1+log2AL});
				b_tilde0rnti{N_DCI-N_DCI_min+1}{1+log2AL} = b_tilde0; %#ok<AGROW>
				EArnti{N_DCI-N_DCI_min+1}{1+log2AL} = EA; %#ok<AGROW>
				EBrnti{N_DCI-N_DCI_min+1}{1+log2AL} = EB; %#ok<AGROW>
			end
		end
		save(DCI_filename,'Grnti','b_tilde0rnti','EArnti','EBrnti');
		fprintf(' done.\n');
	end
end
