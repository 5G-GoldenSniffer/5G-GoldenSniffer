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
function [SSB_found,iSSB,SSB_offset,ncellid,k120,H_est_PSS,signal_power_est,noise_power_est,SSS_freq,Cfo_eD,Cfo_eF2,...
		phi_SSB,hSSB_state,hPSS_state,hPSS_norm_state]=ACQUIRE(...
		s,f0_MHz,GSCN_MHz,phi_SSB,fs,SCS,hSSB,hSSB_decim,hSSB_state,SSB_ind,hPSS,hPSS_state,hPSS_norm_state,...
		PSS_freq,PSS_ind,PSS_corr_thres,CP_slack,cp_corr_thres,phase_comp,FIGURES,VERBOSITY,GSCN_corr_log)
	SSB_found = false;
	N_GSCN_MHz = numel(GSCN_MHz);
	NhSSB = numel(hSSB);
	NhPSS = size(hPSS,1);
	ns = numel(s);
	Ts = 1/fs;
	ts = (0:ns-1)*Ts;
	N_FFT = fs/SCS;
	N_CP = 9*N_FFT/128;

	% Reset max_val for each new block to find PSS in current window
	max_val = 0;
	for i = 1:N_GSCN_MHz
		f_SSB = (GSCN_MHz(i)-f0_MHz)*1e6;
		s_tmp=0;
		for j = 1:hSSB_decim
			[s_tmp_decim,hSSB_state((j-1)*(NhSSB/hSSB_decim-1)+(1:NhSSB/hSSB_decim-1),i)] = ...
				filter(hSSB(hSSB_decim+1-j:hSSB_decim:end),1,...
				s(j:hSSB_decim:end).*exp(-2i*pi*f_SSB*ts(j:hSSB_decim:end)+1i*phi_SSB(i)),...
				hSSB_state((j-1)*(NhSSB/hSSB_decim-1)+(1:NhSSB/hSSB_decim-1),i));
			s_tmp=s_tmp+s_tmp_decim;
		end
		phi_SSB(i) = phi_SSB(i) - 2*pi*f_SSB*ns*Ts;
		for j = 1:3
			[tmp,hPSS_state((i-1)*3+j,:)] = filter(hPSS(:,j),1,...
				s_tmp,hPSS_state((i-1)*3+j,:));
			[tmp_norm,hPSS_norm_state(i,:)] = filter(ones(NhPSS,1),1,...
				abs(s_tmp).^2,hPSS_norm_state(i,:));
			tmp_norm = 1./sqrt(tmp_norm);
			if bitand(FIGURES,0x0001)
				GSCN_corr_log(3*(i-1)+j,:) = abs(tmp.*tmp_norm);
			end
			[val,pos]=max(abs(tmp.*tmp_norm));
			if val > max_val
				max_val = val;
				max_pos = pos;
				GSCN_freq = GSCN_MHz(i);
				% GSCN frequency corresponds to subcarrier 120
				k120 = round((GSCN_freq-f0_MHz)*1e6/SCS);
				NID2 = j-1;
				SSB_offset = 1+pos*hSSB_decim-N_FFT-N_CP-round((NhSSB/hSSB_decim-1)/2*hSSB_decim);
			end
		end
	end

	if bitand(FIGURES,0x0002)
		CP_corr_log = zeros(4*CP_slack+1,2);
		for k = -2*CP_slack:2*CP_slack
			tmp = 0;
			for i = 0:3
				s1 = s(SSB_offset+i*(N_FFT+N_CP)+k      +(CP_slack+1:N_CP-CP_slack));
				s2 = s(SSB_offset+i*(N_FFT+N_CP)+k+N_FFT+(CP_slack+1:N_CP-CP_slack));
				tmp = tmp + s2*s1'/(norm(s1)*norm(s2));
			end
			CP_corr_log(1+2*CP_slack+k,:)=[k,tmp/4];
		end

		currentfigure(2)
		subplot(2,1,1)
		hold off
		plot(CP_corr_log(:,1),abs(CP_corr_log(:,2)))
		hold on
		plot(CP_slack*[1 1],[0 1.05],'k:')
		plot(-CP_slack*[1 1],[0 1.05],'k:')
		plot(2*CP_slack*[-1 1],[1 1],'k--')
		ylabel('|Normalized CP Correlation|')
		xlabel('Delay')
		title('Cyclic Prefix Correlation Magnitude (PSS)')
		ylim([0 1.05])
		xlim(2*CP_slack*[-1 1])

		subplot(2,1,2)
		hold off
		plot(CP_corr_log(:,1),angle(CP_corr_log(:,2))/(2*pi*N_FFT*Ts))
		hold on
		plot(CP_slack*[1 1],[-1 1]*1/(2*N_FFT*Ts),'k:')
		plot(-CP_slack*[1 1],[-1 1]*1/(2*N_FFT*Ts),'k:')
		plot(2*CP_slack*[-1 1],[1 1]*1/(2*N_FFT*Ts),'k--')
		plot(2*CP_slack*[-1 1],[1 1]*-1/(2*N_FFT*Ts),'k--')
		xlim(2*CP_slack*[-1 1])
		ylabel('Cfo_{est,CP} [Hz]')
		xlabel('Delay')
		title('Estimated CFO from Cyclic Prefix Correlation (PSS)')

		drawnow
	end

	Y_PBCH = zeros(240,4);
	CP_corr = zeros(1,4);
	for i = 0:3
		% last parameter: cfo_comp for symbol-by-symbol Cfo correction
		[tmp,tmp_corr] = ofdm_fft(s,SSB_offset+i*(N_FFT+N_CP),CP_slack,N_CP,N_FFT,true);
		Y_PBCH(:,1+i) = tmp(1+N_FFT/2+k120+SSB_ind)*exp(1i*phase_comp(2+i));
		CP_corr(1+i) = tmp_corr;
	end
	if min(abs(CP_corr)) > cp_corr_thres
		
		noise_power_est = mean(abs([Y_PBCH([1:56,184:240],1);Y_PBCH([49:56,184:192],3)]).^2);
		signal_power_est = mean(abs([Y_PBCH(57:183,1);Y_PBCH(:,2);Y_PBCH([1:48,57:183,193:240],3);Y_PBCH(:,4)]).^2);
		% SNR_PBCH_est = 10*log10(signal_power_est/noise_power_est);

		% Channel estimate will be used for timing error estimation
		H_est_PSS = Y_PBCH(1+120+PSS_ind,1+0)...
			.*PSS_freq(1+N_FFT/2+PSS_ind,1+NID2);
		SSS_freq = SSS_func(NID2);
		[PSS_SSS_corr,SSS_ind]=max(abs((Y_PBCH(1+120+PSS_ind,1+2)./H_est_PSS)'*SSS_freq));
		if PSS_SSS_corr/(norm(Y_PBCH(1+120+PSS_ind,1+2)./H_est_PSS)*norm(SSS_freq(:,SSS_ind))) < PSS_corr_thres
			iSSB=-1;
			SSB_offset=-1;
			ncellid=-1;
			k120=-1;
			H_est_PSS=[];
			signal_power_est=-1;
			noise_power_est=-1;
			SSS_freq=[];
			Cfo_eD=nan;
			Cfo_eF2=nan;
			return
		end
		SSB_found = true;

		if bitand(FIGURES,0x0001)
			currentfigure(1)
			for i = 1:3
				subplot(3,1,i);
				surf(GSCN_MHz, (1:fs*1e-3/hSSB_decim)/(fs/hSSB_decim)*1000, ...
					GSCN_corr_log(i:3:end, floor(max_pos/(fs*1e-3/hSSB_decim))*fs*1e-3/hSSB_decim + (1:fs*1e-3/hSSB_decim)).'/max_val, 'EdgeColor', 'none');
				xlabel('Global Synchronization Channel Number (GSCN) [MHz]')
				ylabel('Time [ms]')
				zlabel(['PSS #', num2str(i)])
				title(['GSCN Correlation Log - PSS #', num2str(i)])
				colormap default;
				view(35,30);
				zlim([0 1])
				drawnow
			end
		end

		VERBOSITY>0 && fprintf('  [PSS/SSS] GSCN: %gMHz ',GSCN_freq); %#ok <NASGU>

		NID1 = SSS_ind-1;
		H_est_SSS = Y_PBCH(1+120+PSS_ind,1+2)...
			.*SSS_freq(:,1+NID1);
		% this doesn't work well if the PSS/SSS are interfered (by
		% synchronous PBCHs trasnmitted by other cells)
		Cfo_est_PBCH=angle(sum(H_est_SSS.*conj(H_est_PSS)))/(4*pi*(N_FFT+N_CP)*Ts);

		ncellid = 3*NID1+NID2;
		Cfo_est_CP = mean(angle(CP_corr))/(2*pi*N_FFT*Ts);

		% as initial estimate we prefer the CP-based estimate (larger dynamic range)
		Cfo_eD = 0*Cfo_est_PBCH+1*Cfo_est_CP;
		% bootstrap
		Cfo_eF2 = Cfo_eD;
		% tracking
		% Cfo_eF2 = Cfo_eF2 + Kif*alpha*Cfo_eD;
		% Cfo_eF = Kpf*alpha*Cfo_eD+Cfo_eF2;
		VERBOSITY>0 && fprintf('ncellid: %d Cfo: %.1fkHz(CP) %.1fkHz(PSS->SSS)\n',...
			ncellid,Cfo_est_CP*1e-3,Cfo_est_PBCH*1e-3); %#ok <NASGU>
		
		% Initial noise estimate will be calculated after artificial noise injection
		% to ensure it reflects the true noise conditions

		% Unwrap QPSK to get channel estimate (DMRS is in symbols 1, 2 and 3)
		Ycorr = unwrap_QPSK(Y_PBCH(:,1+1));
		DMRS_ind = mod(ncellid,4):4:239;
		C_est = Y_PBCH(1+DMRS_ind,1+1)./Ycorr(1+DMRS_ind);
		%C_est = DMRS_heuristic(Y_PBCH(:,1+1),dmrs_ind,C_est);
		[is_ok,c_init_DMRS] = DMRS_process(C_est,0,4);
		if is_ok
			% c_init_DMRS ==  2^11*(iSSB+1)*(floor(ncellid/4)+1) ...
			%               + 2^6*(iSSB+1)
			%               + mod(ncellid,4)
			iSSB1 = floor(c_init_DMRS/2^11)/(1+floor(ncellid/4))-1;
			iSSB2 = floor(mod(c_init_DMRS,2^11)/2^6)-1;
			if iSSB1 == iSSB2
				iSSB = iSSB1;
			else
				is_ok = false;
			end
		end
		if ~is_ok
			dmrsIndices = nrPBCHDMRSIndices(ncellid);
			dmrsEst = zeros(1,8);
			for ibar_SSB = 0:7
				refGrid = zeros([240 4]);
				refGrid(dmrsIndices) = nrPBCHDMRS(ncellid,ibar_SSB);
				[hest,nest] = nrChannelEstimate(Y_PBCH,refGrid,'AveragingWindow',[0 1]);
				dmrsEst(ibar_SSB+1) = 10*log10(mean(abs(hest(:).^2)) / nest);
			end
			iSSB = find(dmrsEst==max(dmrsEst)) - 1;
			% fprintf(' iSSB(*): %d\n',iSSB);
		end
	end
	if ~SSB_found
		iSSB=-1;
		SSB_offset=-1;
		ncellid=-1;
		k120=-1;
		H_est_PSS=[];
		signal_power_est=-1;
		noise_power_est=-1;
		SSS_freq=[];
		Cfo_eD=nan;
		Cfo_eF2=nan;
	end
end
