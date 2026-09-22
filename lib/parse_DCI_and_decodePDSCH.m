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
function [isDL,rv,crc,bits,pcap_RNTIType,CSI0,RNTI_param] = ...
	parse_DCI_and_decodePDSCH(dci,ncellid,initialSystemInfo,CORESET0,Y,sc_ofs,N_RB,SCS,...
	CSI0,CSI1,CSI2,RNTI_param,RE_busy_thres,RE_free_thres,noise_power_est,...
	PDSCH_decoding,nrPCAPW,VERBOSITY,FIGURES)
	
	SFN = initialSystemInfo.NFrame;

	Nsc_RB = 12;
	Nsymb_slot = 14;

	persistent FDA_BWP_int Nmax_DCI_Fallback1_0
	if isempty(FDA_BWP_int)
		[FDA_BWP_int,nFDA_max] = FDA_BWP_int_calc(N_RB);
		Nmax_DCI_Fallback1_0 = 28 + nFDA_max;
		% Nmax_DCI_Fallback0_0 = 20 + nFDA_max;
	end

	% initialize the crc check result to non-zero
	crc = 1;
	bits = [];
	pcap_RNTIType = [];

	% we assume no delayed allocations
	K0 = 0;

	if dci.CORESET0 && numel(dci.bits) == CORESET0.Nmax_DCI_Fallback1_0 ...
			&& dci.NID == ncellid ...
			&& (dci.RNTI == 0xffff || dci.RNTI <= 0x4600)
		% SI-RNTI==0xffff, RA-RNTI<=0x4600

		grid_ofs = CORESET0.grid_RBstart;
		grid_N_RB = CORESET0.grid_N_RB;
		BWPstart = CORESET0.BWPstart;
		BWPsize = CORESET0.BWPsize;

		if dci.RNTI == 0xffff
			% this branch uses the MathWorks functions from the
			% sib1 recovery example
			carrier = hCarrierConfigSIB1(ncellid,initialSystemInfo,CORESET0.pdcch);
			dci_sib = DCIFormat1_0_SIRNTI(BWPsize);
			dci_sib = fromBits(dci_sib,dci.bits);
			pcap_RNTIType = nrPCAPW.SystemInfoRNTI;
			isDL = 1; rv = dci_sib.RedundancyVersion; % so we can use the C-RNTI code
			[L_RB,RBstart] = hDecodeRIV(BWPsize,dci_sib.FrequencyDomainResources);
			[code_rate,~] = hMCS(dci_sib.ModulationCoding);
			[pdsch,K0] = hSIB1PDSCHConfiguration(dci_sib,BWPsize,...
				initialSystemInfo.DMRSTypeAPosition,CORESET0.pattern);
			carrier.NSlot = dci.slot+K0;
			rxSlotGrid = Y(sc_ofs+(grid_ofs+BWPstart)*Nsc_RB+(1:BWPsize*Nsc_RB),(dci.slot+K0)*Nsymb_slot+(1:Nsymb_slot));
		else
			% this branch assumes that the configured Random
			% Access uses the CORESET#0 and not another CORESET
			% specified in the SIB1
			% Format_1_0 for RA-RNTI
			fdaNbits = numel(dci.bits) - 28;
			fda = sum(dci.bits(1:fdaNbits).*2.^(fdaNbits-1:-1:0));
			tdra = sum(dci.bits(fdaNbits+(1:4)).*[8 4 2 1]);
			interleaved_mapping = dci.bits(fdaNbits+5);
			mcs = sum(dci.bits(fdaNbits+(6:10)).*[16 8 4 2 1]);
			tb_scaling = sum(dci.bits(fdaNbits+(11:12)).*[2 1]);
			reserved = sum(dci.bits(fdaNbits+(13:28)).*2.^(15:-1:0));
			pcap_RNTIType = nrPCAPW.RandomAccessRNTI;
			isDL = 1; rv = 0; % so we can use the C-RNTI code
			if VERBOSITY>=3,fprintf('    fda:%d tdra:%d intlv:%d mcs:%d tb_scaling:%d rsvd:%d\n',...
					fda,tdra,interleaved_mapping,mcs,tb_scaling,reserved);end
			[L_RB,RBstart] = hDecodeRIV(BWPsize,fda);
			[code_rate,modulation] = hMCS(mcs);
			carrier = nrCarrierConfig('NCellID',ncellid,...
				'SubcarrierSpacing',SCS/1000,'CyclicPrefix','normal',...
				'NSizeGrid',grid_N_RB+grid_ofs,'NStartGrid',0,'NSlot',dci.slot,...
				'NFrame',SFN);
			pdsch=nrPDSCHConfig('NSizeBWP',BWPsize,'NStartBWP',BWPstart+grid_ofs,...
				'Modulation',modulation,'NumLayers',1,'MappingType','A',...
				'SymbolAllocation',[CORESET0.duration Nsymb_slot-CORESET0.duration],'PRBSet',RBstart+(0:L_RB-1),...
				'PRBSetType','VRB','VRBToPRBInterleaving',interleaved_mapping,...
				'VRBBundleSize',2,'NID',dci.NID,'RNTI',dci.RNTI);
			pdsch.DMRS = nrPDSCHDMRSConfig('DMRSConfigurationType',1,...
				'DMRSReferencePoint','CRB0','DMRSTypeAPosition',2,...
				'DMRSAdditionalPosition',2,'DMRSLength',1,...
				'CustomSymbolSet',[],'DMRSPortSet',[],...
				'NIDNSCID',ncellid,'NSCID',0);
			rxSlotGrid = Y(sc_ofs+(1:(grid_N_RB+grid_ofs)*Nsc_RB),(dci.slot+K0)*Nsymb_slot+(1:Nsymb_slot));
		end
		[bits,crc,CSI0] = hDecodePDSCH_new(carrier,pdsch,rxSlotGrid,code_rate,rv,CSI0,CSI1,CSI2,RE_free_thres,false,FIGURES);

	elseif PDSCH_decoding % non-SIB && non-RAR messages

		% we only support Fallback1_0 DCIs
		% check if the number of bits is compatible
		if dci.bits(1) && numel(dci.bits) <= Nmax_DCI_Fallback1_0
			fdaNbits = numel(dci.bits) - 28;
			isDL = dci.bits(1);
			fda = sum(dci.bits(2:fdaNbits+1).*2.^(fdaNbits-1:-1:0));
			tdra = sum(dci.bits(fdaNbits+(2:5)).*[8 4 2 1]);
			interleaved_mapping = dci.bits(fdaNbits+6);
			mcs = sum(dci.bits(fdaNbits+(7:11)).*[16 8 4 2 1]);
			ndi = dci.bits(fdaNbits+12);
			rv = sum(dci.bits(fdaNbits+(13:14)).*[2 1]);
			harqid = sum(dci.bits(fdaNbits+(15:18)).*[8 4 2 1]);
			dai = sum(dci.bits(fdaNbits+(19:20)).*[2 1]);
			tpc_cmd = sum(dci.bits(fdaNbits+(21:22)).*[2 1]);
			pucch_ri = sum(dci.bits(fdaNbits+(23:25)).*[4 2 1]);
			pdsch_harq_fbti = sum(dci.bits(fdaNbits+(26:28)).*[4 2 1]);
			pcap_RNTIType = nrPCAPW.CellRNTI;
			if VERBOSITY>=3,fprintf('    isDL:%d fda:%d tdra:%d intlv:%d mcs:%d ndi:%d rv:%d harqId:%d dai:%d tpc:%d pucch_ri:%d harq_fbti:%d\n',...
					isDL,fda,tdra,interleaved_mapping,mcs,ndi,rv,harqid,dai,tpc_cmd,pucch_ri,pdsch_harq_fbti);end
		else
			isDL = 0;
			rv = -1;
		end
		if isDL && rv == 0
			[code_rate,modulation]=hMCS(mcs);

			CORESET0_BWP_fits = CORESET0.grid_RBstart+CORESET0.BWPstart+CORESET0.BWPsize<=N_RB;
			CORESET0_flag_ambiguous = CORESET0.offset==0 && dci.CORESET0 && CORESET0_BWP_fits;
			trials_left = 1 + CORESET0_flag_ambiguous;
			while trials_left > 0
				trials_left = trials_left - 1;

				if CORESET0_flag_ambiguous
					if trials_left == 1
						grid_N_RB = N_RB;
						grid_ofs = 0;

						RNTI_listid = find(dci.RNTI == [RNTI_param.RNTI]);
						if isempty(RNTI_listid)
							BWPsize = -1;
							BWPstart = -1;
							symbAlloc = [];
							N_ID__nSCID = -1;
							nSCID = -1;
							DMRS_addPos = -1;
						else
							BWPsize = RNTI_param(RNTI_listid).BWPsize;
							BWPstart = RNTI_param(RNTI_listid).BWPstart;
							symbAlloc = RNTI_param(RNTI_listid).symbAlloc;
							N_ID__nSCID = RNTI_param(RNTI_listid).N_ID__nSCID;
							nSCID = RNTI_param(RNTI_listid).nSCID;
							DMRS_addPos = RNTI_param(RNTI_listid).DMRS_addPos;
						end
					else
						grid_ofs = CORESET0.grid_RBstart;
						grid_N_RB = CORESET0.grid_N_RB;
						BWPstart = CORESET0.BWPstart;
						BWPsize = CORESET0.BWPsize;

						N_ID__nSCID = ncellid;
						nSCID = 0;
						DMRS_addPos = 2; % RFC
						symbAlloc = [dci.duration Nsymb_slot-dci.duration];
					end
				elseif dci.CORESET0
					grid_ofs = CORESET0.grid_RBstart;
					grid_N_RB = CORESET0.grid_N_RB;
					BWPstart = CORESET0.BWPstart;
					BWPsize = CORESET0.BWPsize;

					N_ID__nSCID = ncellid;
					nSCID = 0;
					DMRS_addPos = 2; % RFC
					symbAlloc = [dci.duration Nsymb_slot-dci.duration];
				else
					grid_N_RB = N_RB;
					grid_ofs = 0;

					RNTI_listid = find(dci.RNTI == [RNTI_param.RNTI]);
					if isempty(RNTI_listid)
						BWPsize = -1;
						BWPstart = -1;
						symbAlloc = [];
						N_ID__nSCID = -1;
						nSCID = -1;
						DMRS_addPos = -1;
					else
						BWPsize = RNTI_param(RNTI_listid).BWPsize;
						BWPstart = RNTI_param(RNTI_listid).BWPstart;
						symbAlloc = RNTI_param(RNTI_listid).symbAlloc;
						N_ID__nSCID = RNTI_param(RNTI_listid).N_ID__nSCID;
						nSCID = RNTI_param(RNTI_listid).nSCID;
						DMRS_addPos = RNTI_param(RNTI_listid).DMRS_addPos;
					end
				end

				% if the BWPsize (and start RB is known, we can proceed directly)
				if BWPsize > 0
					[L_RB,RBstart] = hDecodeRIV(BWPsize,fda);
					if L_RB > 0
						carrier=nrCarrierConfig('NCellID',ncellid,...
							'SubcarrierSpacing',SCS/1000,'CyclicPrefix','normal',...
							'NSizeGrid',grid_N_RB+grid_ofs,'NStartGrid',0,'NSlot',dci.slot,...
							'NFrame',SFN);
						pdsch=nrPDSCHConfig('NSizeBWP',BWPsize,'NStartBWP',BWPstart+grid_ofs,...
							'Modulation',modulation,'NumLayers',1,'MappingType','A',...
							'SymbolAllocation',symbAlloc,'PRBSet',RBstart+(0:L_RB-1),...
							'PRBSetType','VRB','VRBToPRBInterleaving',interleaved_mapping,...
							'VRBBundleSize',2,'NID',N_ID__nSCID,'RNTI',dci.RNTI); % dci_param.NID ???
						pdsch.DMRS=nrPDSCHDMRSConfig('DMRSConfigurationType',1,...
							'DMRSReferencePoint','CRB0','DMRSTypeAPosition',2,...
							'DMRSAdditionalPosition',DMRS_addPos,'DMRSLength',1,...
							'CustomSymbolSet',[],'DMRSPortSet',[],...
							'NIDNSCID',N_ID__nSCID,'NSCID',nSCID);
						rxSlotGrid = Y(sc_ofs+(1:(grid_N_RB+grid_ofs)*Nsc_RB),...
							(dci.slot+K0)*Nsymb_slot+(1:Nsymb_slot));
						[bits,crc,CSI0] = hDecodePDSCH_new(carrier,pdsch,rxSlotGrid,code_rate,rv,CSI0,CSI1,CSI2,RE_free_thres,true,FIGURES);
					end
				else
					% need to find the BWPsize for this DCI
					% if a unique valid BWPsize/BWPstart configuration is
					% found, save its parameters in RNTI_list

					[FDA_BWP_hyp,nHyp] = find_FDA_BWP_hypotheses(...
						Y(1+sc_ofs+(0:Nsc_RB*N_RB-1),(dci.slot+K0)*Nsymb_slot+(dci.duration+1:Nsymb_slot)),...
						RE_busy_thres*sqrt(noise_power_est)*Nsc_RB*(Nsymb_slot-dci.duration),...
						FDA_BWP_int(1+fdaNbits,:),fda,(dci.cand(1)-1)/Nsc_RB,(dci.cand(2)-dci.cand(1)+1)/Nsc_RB);

					% the toolbox requires the whole slot, not just the BWP
					rxSlotGrid = Y(sc_ofs+grid_ofs*Nsc_RB+(1:grid_N_RB*Nsc_RB),(dci.slot+K0)*Nsymb_slot+(1:Nsymb_slot));
					carrier = nrCarrierConfig('NCellID',ncellid,...
						'SubcarrierSpacing',SCS/1000,'CyclicPrefix','normal',...
						'NSizeGrid',grid_N_RB,'NStartGrid',grid_ofs,'NSlot',dci.slot,...
						'NFrame',SFN);

					% for every possible interpretation of the
					% fda field, find the corresponding
					% BWPstart and try and decode the PDSCH
					for iHyp = 1:nHyp
						L_RB = FDA_BWP_hyp(iHyp,1);
						RBstart = FDA_BWP_hyp(iHyp,2);
						BWPsize = FDA_BWP_hyp(iHyp,3);
						BWPstart = FDA_BWP_hyp(iHyp,4);

						if isempty(RNTI_listid)
							symbAlloc = PDSCH_symbAlloc_autodetect(rxSlotGrid,BWPstart,RBstart,L_RB,dci.duration,RE_free_thres*sqrt(noise_power_est)*Nsc_RB*L_RB);
							[N_ID__nSCID,nSCID,DMRS_addPos] = PDSCH_DMRS_autodetect(rxSlotGrid,BWPstart,RBstart,L_RB,dci.slot,dci.duration);
							if N_ID__nSCID < 0
								continue % nHyp
							end
						end

						pdsch=nrPDSCHConfig('NSizeBWP',BWPsize,'NStartBWP',BWPstart,...
							'Modulation',modulation,'NumLayers',1,'MappingType','A',...
							'SymbolAllocation',symbAlloc,'PRBSet',RBstart+(0:L_RB-1),...
							'PRBSetType','VRB','VRBToPRBInterleaving',interleaved_mapping,...
							'VRBBundleSize',2,'NID',N_ID__nSCID,'RNTI',dci.RNTI);
						pdsch.DMRS=nrPDSCHDMRSConfig('DMRSConfigurationType',1,...
							'DMRSReferencePoint','CRB0','DMRSTypeAPosition',2,...
							'DMRSAdditionalPosition',DMRS_addPos,'DMRSLength',1,...
							'CustomSymbolSet',[],'DMRSPortSet',[],...
							'NIDNSCID',N_ID__nSCID,'NSCID',nSCID);

						[bits,crc,CSI0] = hDecodePDSCH_new(carrier,pdsch,rxSlotGrid,code_rate,rv,CSI0,CSI1,CSI2,RE_free_thres,false,FIGURES);

						if crc == 0
							BWP_unambiguous = FDA_BWP_hyp(iHyp,5)==0 && (BWPsize~=CORESET0.BWPsize || BWPstart~=CORESET0.grid_RBstart+CORESET0.BWPstart);
							if isempty(RNTI_listid)
								RNTI_listid = numel(RNTI_param) + 1;
								RNTI_param(RNTI_listid).RNTI = dci.RNTI;
								if BWP_unambiguous
									RNTI_param(RNTI_listid).BWPsize = BWPsize;
									RNTI_param(RNTI_listid).BWPstart = BWPstart;
									%fprintf('    RNTI: 0x%04x BWP discovered: %d@%d\n',dci_param.RNTI,BWPsize,BWPstart);pause;
								else
									RNTI_param(RNTI_listid).BWPsize = -1;
									RNTI_param(RNTI_listid).BWPstart = -1;
								end
								RNTI_param(RNTI_listid).symbAlloc = symbAlloc;
								RNTI_param(RNTI_listid).N_ID__nSCID = N_ID__nSCID;
								RNTI_param(RNTI_listid).nSCID = nSCID;
								RNTI_param(RNTI_listid).DMRS_addPos = DMRS_addPos;
							elseif RNTI_param(RNTI_listid).BWPsize==-1 && RNTI_param(RNTI_listid).BWPstart==-1 && BWP_unambiguous
								%fprintf('    RNTI: 0x%04x BWP discovered: %d@%d\n',dci_param.RNTI,BWPsize,BWPstart);pause;
								RNTI_param(RNTI_listid).BWPsize = BWPsize;
								RNTI_param(RNTI_listid).BWPstart = BWPstart;
							end
							break % nHyp
						end
					end
				end
				% % the BWP configuration changed(?!), invalidate the RNTI
				% if crc~=0 && numel(RNTI_listid)
				% 	RNTI_list(RNTI_listid) = RNTI_list(RNTI_listid)+0x10000;
				% end
				if crc==0
					trials_left=0;
				end
			end % while trials_left
		end
	else
		isDL = dci.bits(1);
		rv = -1;
	end
	if isDL && rv == 0
		if bitand(FIGURES,0x0040)
			if crc==0
				color = 'g';
			else
				color = 'r';
				% keyboard
			end
			currentfigure(7)
			rectangle('Position',...
				[(dci.slot+K0)*Nsymb_slot+dci.duration-0.5 ...
				(grid_ofs+BWPstart+RBstart)*Nsc_RB-0.5 ...
				Nsymb_slot-dci.duration L_RB*Nsc_RB],...
				'FaceColor',color,'EdgeColor','none','FaceAlpha',0.5)
			drawnow
		end
	end
end
