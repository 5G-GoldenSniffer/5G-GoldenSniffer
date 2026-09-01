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
function [bits,crc,CSI0] = hDecodePDSCH_new(carrier,pdsch,rxSlotGrid,code_rate,rv,CSI0,CSI1,CSI2,RE_free_thres,CSI0_update,FIGURES)

	Nsc_RB = 12;
	Nsymb_slot = carrier.SymbolsPerSlot;
	SFN = carrier.NFrame;
	slot = carrier.NSlot;
	L_RB=length(pdsch.PRBSet);

	% 'ReservedRE' to avoid the CSI-RS
	ReservedRE = [];
	if CSI0.SFN_period>0 && mod(SFN,CSI0.SFN_period)==CSI0.SFN
		for l = 0:Nsymb_slot-1
			if CSI0.bitmap(1+slot*Nsymb_slot+l)
				% this assumes contiguous allocations
				ReservedRE = [ReservedRE,...
					l*pdsch.NSizeBWP*Nsc_RB+pdsch.PRBSet(1)*Nsc_RB+(CSI0.k0+0:CSI0.sc_spacing:L_RB*Nsc_RB-1),...
					l*pdsch.NSizeBWP*Nsc_RB+pdsch.PRBSet(1)*Nsc_RB+(CSI0.k0+1:CSI0.sc_spacing:L_RB*Nsc_RB-1),...
					l*pdsch.NSizeBWP*Nsc_RB+pdsch.PRBSet(1)*Nsc_RB+(CSI0.k0+2:CSI0.sc_spacing:L_RB*Nsc_RB-1),...
					l*pdsch.NSizeBWP*Nsc_RB+pdsch.PRBSet(1)*Nsc_RB+(CSI0.k0+3:CSI0.sc_spacing:L_RB*Nsc_RB-1)]; %#ok<AGROW>
			end
		end
	end
	if CSI1.SFN_period>0 && mod(SFN,CSI1.SFN_period)==CSI1.SFN
		for l = 0:Nsymb_slot-1
			if CSI1.bitmap(1+slot*Nsymb_slot+l)
				ReservedRE = [ReservedRE,l*pdsch.NSizeBWP*Nsc_RB+pdsch.PRBSet(1)*Nsc_RB+(CSI1.k0:CSI1.sc_spacing:L_RB*Nsc_RB-1)]; %#ok<AGROW>
			end
		end
	end
	if CSI2.SFN_period>0 && mod(SFN,CSI2.SFN_period)==CSI2.SFN
		for l = 0:Nsymb_slot-1
			if CSI2.bitmap(1+slot*Nsymb_slot+l)
				ReservedRE = [ReservedRE,l*pdsch.NSizeBWP*Nsc_RB+pdsch.PRBSet(1)*Nsc_RB+(CSI2.k0:CSI2.sc_spacing:L_RB*Nsc_RB-1)]; %#ok<AGROW>
			end
		end
	end
	pdsch.ReservedRE = ReservedRE;

	tries = 1 + (CSI0.SFN_period < 0);
	while tries > 0
		% channel estimation and soft-output equalization
		pdschDmrsIndices = nrPDSCHDMRSIndices(carrier,pdsch);
		pdschDmrsSymbols = nrPDSCHDMRS(carrier,pdsch);
		[hest,nVar,~] = nrChannelEstimate(rxSlotGrid,pdschDmrsIndices,pdschDmrsSymbols);
		[pdschIndices,pdschIndicesInfo] = nrPDSCHIndices(carrier,pdsch);
		[pdschRxSym,pdschHest] = nrExtractResources(pdschIndices,rxSlotGrid,hest);
		pdschEqSym = sqrt(2)*nrEqualizeMMSE(pdschRxSym,pdschHest,nVar);
		cw = nrPDSCHDecode(carrier,pdsch,pdschEqSym,nVar);

		if bitand(FIGURES,0x0400)
			currentfigure(11)
			hold off
			plot(pdschEqSym(:),'.')
			xlabel('I')
			ylabel('Q')
			axis equal
			xlim([-1.5 1.5])
			ylim([-1.5 1.5])
			title('PDSCH equalized REs');
			drawnow
		end

		% LDPC decoding
		Xoh_PDSCH = 0;%6*pdsch.EnablePTRS; % TS 38.214 Section 5.1.3.2
		decodeDLSCH = nrDLSCHDecoder(...
			'LDPCDecodingAlgorithm','Normalized min-sum',...
			'TargetCodeRate',code_rate,...
			'TransportBlockLength',nrTBS(pdsch.Modulation,pdsch.NumLayers,...
			L_RB,pdschIndicesInfo.NREPerPRB,code_rate,Xoh_PDSCH));
		if numel(cw)
			[bits,crc] = decodeDLSCH(cw,pdsch.Modulation,pdsch.NumLayers,rv);
		else
			crc = 1;
		end
		if crc == 0
			tries = 0;
		else
			tries = tries - 1;
			if tries > 0
				l_dmrs = [2 7 11];
				for l = pdsch.SymbolAllocation(1)+(0:pdsch.SymbolAllocation(2)-1)
					if all(l~=l_dmrs)
						tmp=zeros(Nsc_RB,1);
						for i = 1:L_RB
							tmp = tmp + abs(rxSlotGrid((pdsch.NStartBWP+pdsch.PRBSet(i))*Nsc_RB+(1:Nsc_RB),1+l));
						end
						tmp = tmp < RE_free_thres*L_RB*sqrt(nVar);
						for k = 0:Nsc_RB-4
							if all(tmp(k+(1:4)))
								ReservedRE = [ReservedRE,...
									l*pdsch.NSizeBWP*Nsc_RB+pdsch.PRBSet(1)*Nsc_RB+(k+0:CSI0.sc_spacing:L_RB*Nsc_RB-1),...
									l*pdsch.NSizeBWP*Nsc_RB+pdsch.PRBSet(1)*Nsc_RB+(k+1:CSI0.sc_spacing:L_RB*Nsc_RB-1),...
									l*pdsch.NSizeBWP*Nsc_RB+pdsch.PRBSet(1)*Nsc_RB+(k+2:CSI0.sc_spacing:L_RB*Nsc_RB-1),...
									l*pdsch.NSizeBWP*Nsc_RB+pdsch.PRBSet(1)*Nsc_RB+(k+3:CSI0.sc_spacing:L_RB*Nsc_RB-1)]; %#ok<AGROW>
								if CSI0_update
									CSI0.bitmap(1+slot*Nsymb_slot+l) = 1;
									CSI0.k0 = k;
									if CSI0.SFN < 0
										CSI0.SFN = SFN;
										CSI0.SFNset = SFN;
									elseif CSI0.SFN_period < 0
										if (SFN-CSI0.SFNset(end)>0) || (SFN-CSI0.SFNset(end)<-512)
											CSI0.SFNset = [CSI0.SFNset SFN];
										end
										if numel(CSI0.SFNset) == 6
											tmp2 = mod(diff(CSI0.SFNset),1024);
											SFN_period = tmp2(1);
											for i = 2:5
												SFN_period = gcd(SFN_period,tmp2(i));
											end
											CSI0.SFN_period = SFN_period;
											CSI0.SFN = mod(CSI0.SFN,SFN_period);
										end
									else
										CSI0.SFN_period = gcd(CSI0.SFN_period,mod(SFN - CSI0.SFN,1024));
										CSI0.SFN = mod(CSI0.SFN,CSI0.SFN_period);
									end
									fprintf('CSI-ZP@%d.%d.%d\n',SFN,slot*Nsymb_slot+l,k);
								end
							end
						end
					end
				end
			end
			pdsch.ReservedRE = ReservedRE;
		end
	end
end
