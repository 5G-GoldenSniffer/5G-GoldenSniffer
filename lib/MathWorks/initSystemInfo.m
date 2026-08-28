
%   Copyright The MathWorks, Inc.

function initSystemInfo = initSystemInfo(mib,sfn4lsb,k_SSB,L_max)
	% Create set of subcarrier spacings signaled by the 7th bit of the
	% decoded MIB, the set is different for FR1 (L_max=4 or 8) and FR2
	% (L_max=64)
	if (L_max==64)
		scsCommon = [60 120];
	else
		scsCommon = [15 30];
	end
	initSystemInfo = struct();
	initSystemInfo.NFrame = mib.systemFrameNumber*2^4 + bit2int(sfn4lsb,4);
	initSystemInfo.SubcarrierSpacingCommon = scsCommon(mib.subCarrierSpacingCommon + 1);
	initSystemInfo.k_SSB = k_SSB + mib.ssb_SubcarrierOffset;
	initSystemInfo.DMRSTypeAPosition = 2 + mib.dmrs_TypeA_Position;
	initSystemInfo.PDCCHConfigSIB1 = info(mib.pdcch_ConfigSIB1);
	initSystemInfo.CellBarred = mib.cellBarred;
	initSystemInfo.IntraFreqReselection = mib.intraFreqReselection;
end
