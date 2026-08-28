
%   Copyright The MathWorks, Inc.

function nrb = hCORESET0DemodulationBandwidth(sysInfo,scsSSB,minChannelBW)
	% Determine the OFDM demodulation bandwidth from CORESET 0 bandwidth
	cset0Idx = sysInfo.PDCCHConfigSIB1.controlResourceSetZero;
	scsCommon = sysInfo.SubcarrierSpacingCommon;
	scsPair = [scsSSB scsCommon];
	[csetNRB,~,csetFreqOffset] = hCORESET0Resources(cset0Idx,scsPair,minChannelBW,sysInfo.k_SSB);

	% Calculate a suitable bandwidth in RB that includes CORESET 0 in
	% received waveform.
	c0 = csetFreqOffset + 10*scsSSB/scsCommon;  % CORESET frequency offset from carrier center
	nrb = 2*max(c0,csetNRB-c0)+2;               % Number of RB to cover CORESET 0
end
