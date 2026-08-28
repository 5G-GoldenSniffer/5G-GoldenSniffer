
%   Copyright The MathWorks, Inc.

function c = hCarrierConfigSIB1(ncellid,initSystemInfo,pdcch)
	c = nrCarrierConfig;
	c.SubcarrierSpacing = initSystemInfo.SubcarrierSpacingCommon;
	c.NStartGrid = pdcch.NStartBWP;
	c.NSizeGrid = pdcch.NSizeBWP;
	c.NSlot = pdcch.SearchSpace.SlotPeriodAndOffset(2);
	c.NFrame = initSystemInfo.NFrame;
	c.NCellID = ncellid;
end
