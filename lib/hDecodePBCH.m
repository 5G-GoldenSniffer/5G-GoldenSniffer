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
function [SFN,ssbIndex,crcBCH,initialSystemInfo] = hDecodePBCH(ncellid,Y_PBCH,iSSB,L_max,expected_SFN,FIGURES)
	% Demodulate PBCH
	dmrsIndices = nrPBCHDMRSIndices(ncellid);
	pssIndices = nrPSSIndices;
	sssIndices = nrSSSIndices;
	refGrid = zeros(240,4);
	refGrid(pssIndices) = nrPSS(ncellid);
	refGrid(dmrsIndices) = nrPBCHDMRS(ncellid,iSSB);
	refGrid(sssIndices) = nrSSS(ncellid);

	[hest,nest,~] = nrChannelEstimate(Y_PBCH,refGrid,'AveragingWindow',[0 1]);

	if bitand(FIGURES,0x0020)
		currentfigure(6)
		plot([angle(hest(:,1)),angle(hest(:,2)),angle(hest(:,3)),angle(hest(:,4))])
		ylim([-pi pi])
		xlabel('k (PBCH)')
		ylabel('arg(H_est)');
		drawnow
	end
	[pbchIndices,pbchIndicesInfo] = nrPBCHIndices(ncellid);
	pbchRx = nrExtractResources(pbchIndices,Y_PBCH);
	pbchHest = nrExtractResources(pbchIndices,hest);
	[pbchEq,csi] = nrEqualizeMMSE(pbchRx,pbchHest,nest);
	Qm = pbchIndicesInfo.G / pbchIndicesInfo.Gd; % 2:QPSK for the PBCH
	csi = repmat(csi.',Qm,1);csi = reshape(csi,[],1);
	if L_max == 4
		ssbIndex = mod(iSSB,4);
	else
		ssbIndex = iSSB;
	end
	pbchLLR = nrPBCHDecode(pbchEq,ncellid,ssbIndex,nest) .* csi;
	polarListLength = 8;

	[~,crcBCH,trblk,sfn4lsb,~,msbidxoffset] = ...
		nrBCHDecode(pbchLLR,polarListLength,L_max,ncellid);

	%fprintf('crc:%d BCCH-BCH-Message:%s SFN%%16:%d hf:%d msbidxoffset:%d\n',crcBCH,...
	%	char(trblk+'0'),2.^(3:-1:0)*sfn4lsb,nHalfFrame,msbidxoffset);
	if crcBCH == 0
		% PBCH_decode_success = PBCH_decode_success + 1;
		if L_max==64 % FR2?
			ssbIndex = ssbIndex + (bit2int(msbidxoffset,3) * 8);
			k_SSB = 0;
		else
			k_SSB = msbidxoffset * 16;
		end
		mib = fromBits(MIB,trblk(2:end));
		initialSystemInfo = initSystemInfo(mib,sfn4lsb,k_SSB,L_max);
		%disp('BCH/MIB Content:')
		%disp(initialSystemInfo);
		% if DEBUG_PBCH
		%     fprintf('  [PBCH] SCS:%d kSSB:%d\n',...
		%         initialSystemInfo.SubcarrierSpacingCommon,...
		%         initialSystemInfo.k_SSB);
		% end
		% if ~isCORESET0Present(BlockPattern,initialSystemInfo.k_SSB)
		% 	fprintf('CORESET 0 is not present (k_SSB > k_SSB_max).\n');
		% 	keyboard
		% end
		SFN = initialSystemInfo.NFrame;
	else
		%fprintf('BCH CRC fail.\n')
		SFN = expected_SFN;
	end
end
