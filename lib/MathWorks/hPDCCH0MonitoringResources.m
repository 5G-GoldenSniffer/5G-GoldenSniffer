
%   Copyright The MathWorks, Inc.

function [k,slots,slotSymbols,ssStartSym,c0Duration] = hPDCCH0MonitoringResources(systemInfo,scsSSB,minChannelBW,ssbIndex,numRxSym)
	cset0Idx = systemInfo.PDCCHConfigSIB1.controlResourceSetZero;
	scsCommon = systemInfo.SubcarrierSpacingCommon;
	scsPair = [scsSSB scsCommon];
	k_SSB = systemInfo.k_SSB;
	[c0NRB,c0Duration,c0FreqOffset,c0Pattern] = hCORESET0Resources(cset0Idx,scsPair,minChannelBW,k_SSB);

	ssIdx = systemInfo.PDCCHConfigSIB1.searchSpaceZero;
	[ssSlot,ssStartSym,isOccasion] = hPDCCH0MonitoringOccasions(ssIdx,ssbIndex,scsPair,c0Pattern,c0Duration,systemInfo.NFrame);

	% PDCCH monitoring occasions associated to different SS blocks can be
	% in different frames. If there are no monitoring occasions in this
	% frame, there must be one in the next one. Adjust the slots associated
	% to the search space by one frame if needed.
	slotsPerFrame = 10*scsCommon/15;
	ssSlot = ssSlot + (~isOccasion)*slotsPerFrame;

	% For FR1, UE monitors PDCCH in the Type0-PDCCH CSS over two consecutive
	% slots for CORESET pattern 1
	monSlotsPerPeriod = 1 + (c0Pattern==1);

	% Calculate 1-based subscripts of the subcarriers and OFDM symbols for
	% the slots containing the PDCCH0 associated to the detected SS block
	% in this and subsequent 2-frame blocks
	nrb = hCORESET0DemodulationBandwidth(systemInfo,scsSSB,minChannelBW);
	k = 12*(nrb-20*scsSSB/scsCommon)/2 - c0FreqOffset*12 + (1:c0NRB*12);

	symbolsPerSlot = 14;
	numRxSlots = ceil(numRxSym/symbolsPerSlot);
	slots = ssSlot + (0:monSlotsPerPeriod-1)' + (0:2*slotsPerFrame:(numRxSlots-ssSlot-1));
	slots = slots(:)';
	slotSymbols = slots*symbolsPerSlot + (1:symbolsPerSlot)';
	slotSymbols = slotSymbols(:)';

	% Remove monitoring symbols exceeding waveform limits
	slotSymbols(slotSymbols>numRxSym) = [];

	% Calculate the monitoring slots after removing symbols
	slots = (slotSymbols(1:symbolsPerSlot:end)-1)/symbolsPerSlot;
end
