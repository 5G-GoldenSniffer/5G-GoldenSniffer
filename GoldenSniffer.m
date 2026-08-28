% GOLDENSNIFFER 5G NR Passive Downlink Sniffer
%   This function implements a passive 5G NR sniffer for downlink traffic
%   analysis. It performs blind detection and decoding of:
%   - Synchronization Signal Block (SSB) and PBCH/MIB
%   - CORESET#0 and Search Space discovery
%   - DCI (Downlink Control Information)
%   - PDSCH (Physical Downlink Shared Channel) decoding
%   - PCAP file generation for Wireshark analysis
%
%   Supported Features:
%   - FR1 (Sub-6 GHz) with SCS 15/30 kHz
%   - Downlink only (FDD and TDD)
%   - Fallback DCI Formats 0_0 (UL grants) and 1_0 (DL grants)
%   - Aggregation Levels 1, 2, 4, 8, 16
%   - RNTI types: SI-RNTI, RA-RNTI, C-RNTI
%
%   Requirements:
%   - MATLAB R2023a or later
%   - 5G Toolbox
%   - Communications Toolbox
%   - Signal Processing Toolbox
%
%   Usage:
%     GoldenSniffer(config)
%   where config is a structure with several fields.
%
%   A minimal configuration:
%
% 	  config.dir = 'captures';
%     config.filename = 'capture.{fc32,sc16}';
%        will open the raw I/Q sample capture file config.filename in the folder
%        config.dir; interleaved complex float32 (fc32) or int16 (sc16) formats 
%        are supported
%
% 	  config.carrier_frequency_MHz = 1980;
% 	  config.frequency_offset_MHz = 0;
% 	  config.bandwidth_MHz = 20;
% 	  config.sample_rate_MHz = 23.04;
%        specify the carrier frequency, a possible frequency offset with
%        respect to the acquisition center frequency, the carrier bandwidth
%        and the sampling rate, in MHz
%
% 	  config.nzpCSI_known = false;
% 	  config.search_unknown_nzpCSI = true;
% 	  config.zpCSI_known = false;
%        specify the parameters of the noCDM NZP-CSI-RS (density 3 and
%        density 1) and ZP-CSI-RS (4RE x 1symbol), whose knowledge is
%        necessary for successful PDSCH decoding of slots containing the
%        CSI-RS
%        if the _known variables are set to false and the
%        search_unknown_nzpCSI is true, the execution will pause when a
%        valid configuration is found, so that the config variable can be
%        updated for faster future runs
%
% 	  config.PDSCH_decoding = true;
%        if enabled, per-RNTI BWP detection, PDSCH format autodetection and
%        DL-SCH decoding will be attempted. successfully decoded
%        allocations will be saved to the folder 'results' in a pcap file
%        with the same name as the capture file
%
% 	  config.KNOWN_UE_RNTIs = [];
%        a list of RNTI's that is known to be present in the capture file
%        if empty, it will be autodetected
%
%     config.enable_NLOS_channel = false;
%     config.SNR_reduction_dB = 0;
%        artificially include multipath channel and/or signal-to-noise ratio
%        degradation into the capture file (the phase recovery method
%        GoldenSniffer is based on requires good channel conditions)
%        see examples/config_add_impairments.m for configuration options
%
%     config.FIGURES = 0x0000-0xffff;
%        0x0001: [ACQUISITION] time-domain correlation for PSS (for every GSCN frequency)
%        0x0002: [ACQUISITION] autocorrelation of the CP (PSS correlation peak)
%        0x0004: [TRACKING] helpers for timing error estimation
%        0x0008: [TRACKING] PSS/SSS-based channel estimates for tracking
%        0x0010: [TRACKING] CFO and timing error log
%        0x0020: [SYNC CHECK] channel estimation for PBCH symbols
%        0x0040: Synchronized frame (with color marking)
%        0x0080: CSI-based channel estimation
%        0x0100: power clustering for blind PDCCH detection
%        0x0200: PDCCH equalized REs (QPSK)
%        0x0400: PDSCH equalized REs (QPSK/16-QAM/64-QAM)
%
%     config.VERBOSITY = 0-4
%        Command line output
%            0: none
%            1: state machine and short per-frame summary
%            2: dci candidates found and detailed per-frame summary
%            3: processed dci details
%            4: PDSCH byte dump
%
%     config.TDD_pattern = [0 0 0 0 0 0 1 1 1 1]; (all zeros for FDD)
%     config.TA = 360;
%        TDD_pattern specifies which slots are downlink (0) or uplink (1),
%        dependend on the gNB configuration
%        TA is the Timing Advance (in samples) to use in order to visualize
%        the PUSCH and PUCCH correctly (while shown in the figures, the
%        uplink is not processed), dependent on the system geometry
%
%   References:
%   - I.Palamà, S.Mangione, A.Dino, G.Focarelli, G.Bianchi; "Golden Sniffer:
%     Low-Complexity 5G New Radio Signal Interception Exploiting Gold Sequences"
%     The 32nd Annual International Conference on Mobile Computing and
%     Networking (MobiCom'26) Oct 26-30, 2026, Austin, Texas, USA
%
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
function GoldenSniffer(config)
	if nargin == 0
		fprintf(['GoldenSniffer needs a config struct as argument.\n'...
			'Check the provided documentation or the examples/ directory\n']);
		addpath('examples/');
		return
	end

	addpath('utils/','lib/','lib/MathWorks/');
	tic

	FIGURES = config.FIGURES;
	VERBOSITY = config.VERBOSITY;

	% ======================= TIMERS =======================
	% Main step timers
	step1_time = 0;  % Synchronization (Acquisition & Tracking)
	step2_time = 0;  % FFT
	step3_time = 0;  % PDCCH processing (blind ScramblingID & RNTI extraction)
	step4_time = 0;  % PDSCH processing (CSI-RS, BWP, PDSCH format, LDPC decoding)

	% ========== NLOS CHANNEL MODELING PARAMETERS ==========

	% Channel modeling configuration
	enable_NLOS_channel = config.enable_NLOS_channel;

	if enable_NLOS_channel
		NLOS_channel_type = config.NLOS_channel_type;
		NLOS_scenario = config.NLOS_scenario;
		NLOS_delay_spread = config.NLOS_delay_spread;
		NLOS_K_factor = config.NLOS_K_factor;
		NLOS_Doppler_freq = config.NLOS_Doppler_freq;
		NLOS_num_paths = config.NLOS_num_paths; 
		NLOS_channel_filter = config.NLOS_channel_filter;
		NLOS_channel_time = config.NLOS_channel_time;

		% Channel statistics tracking
		NLOS_channel_stats = struct();
		NLOS_channel_stats.avg_path_loss = 0;
		NLOS_channel_stats.rms_delay_spread = 0;
		NLOS_channel_stats.coherence_bandwidth = 0;
		NLOS_channel_stats.coherence_time = 0;
	end

	% ========== CAPTURE FILE CONFIGURATION ==========
	dir = config.dir;
	filename = config.filename;
	cap = filename;
	nskip = 0;

	fprintf('File:  %s\n', filename);
	if contains(filename,'.fc32')
		sample_type='float32';
		sample_size=8;
	elseif contains(filename,'.sc16')
		sample_type='int16';
		sample_size=4;
	end

	SNR_reduction_dB = config.SNR_reduction_dB;  % - SNR reduction in dB (<=0 disabled)
	enable_artificial_noise = SNR_reduction_dB > 0;

	f0_MHz = config.carrier_frequency_MHz;
	f0 = f0_MHz * 1e6;
	fs_MHz = config.sample_rate_MHz;
	fs = fs_MHz * 1e6;
	Ts = 1/fs;
	f0_corr = config.frequency_offset_MHz * 1e6;
	BW_MHz = config.bandwidth_MHz;

	if f0_MHz < 3000
		mu = 0;
		L_max = 4;
		BlockPattern = 'Case A';
		minChannelBW = 5;
	else
		mu = 1;
		L_max = 8;
		BlockPattern = 'Case C';
		minChannelBW = 10;
	end

	if isfield(config,'TDD_pattern')
		TDD_pattern = config.TDD_pattern;
		TA = config.TA;
	else
		TDD_pattern = zeros(1,10);
		TA = 0;
	end

	KNOWN_UE_RNTIs = config.KNOWN_UE_RNTIs;

	% ========== DETECTION PARAMETERS ==========

	% Correlation thresholds
	RE_busy_thres = 3.5;
	RE_free_thres = 2.5;
	cp_corr_thres = 0.5;
	PSS_corr_thres = 0.3;
	
	% PI filter parameters for CFO and STO tracking
	Kpf = 0.1;
	Kif = Kpf*Kpf/4;

	% ========== OPEN CAPTURE FILE ==========
	[fp, errmsg] = fopen(fullfile(dir, filename), 'rb');
	if fp == -1
		error('Failed to open file %s: %s', fullfile(dir,filename), errmsg);
	end

	% ========== FRAME PARAMETERS (3GPP TS 38.211) ==========

	Tf = 10e-3;
	Nsymb_slot = 14; % we consider numerologies 0 and 1 only
	Nsymb_subframe = Nsymb_slot*2^mu;
	Nsubframe_frame = 10;
	SCS = 15000*2^mu;
	Nslot_frame = Nsubframe_frame*2^mu;
	Nsymb_frame = Nsymb_slot*Nslot_frame;

	if bitand(FIGURES,0x0840)
		Ymax = 0;
	end

	% ========== DCI DECODING PARAMETERS ==========
	
	Nsc_RB = 12;

	% ========== BANDWIDTH TABLE (3GPP TS 38.104 Table 5.3.2-1) ==========
	
	% 38.104 Table 5.3.2-1 for numerology 0 and 1
	BW_MHz_tab = [...
		 5  10  15  20  25  30  40  50  60  80  90 100];
	N_RB_tab = [...
		25  52  79 106 133 160 216 270  -1  -1  -1  -1; ...
		11  24  38  51  65  78 106 133 162 217 245 273];
	
	% number of resource blocks in the grid
	N_RB = N_RB_tab(1+mu,BW_MHz==BW_MHz_tab);
	Nsc = Nsc_RB*N_RB;
	[FDA_BWP_int,nFDA_max] = FDA_BWP_int_calc(N_RB);
	Nmax_DCI_Fallback1_0 = 28 + nFDA_max;
	% Nmax_DCI_Fallback0_0 = 20 + nFDA_max;

	ns = Tf*fs;
	ts = (0:ns-1)*Ts;

	% in the ACQUIRE state we search for the PBCH and, when we find it,
	% we move to the TRACK state in which we are aligned to the frame and
	% have a fairly accurate idea of the Cfo
	state = 'ACQUIRE';

	GSCN_MHz = GSCN_freqs_MHz(f0_MHz,fs/1e6,BW_MHz,SCS/1e6);
	N_GSCN_MHz = numel(GSCN_MHz);

	[hSSB,NhSSB,hSSB_decim] = SSB_filter(fs,SCS,ns);
	hSSB_state = zeros((NhSSB/hSSB_decim-1)*hSSB_decim,N_GSCN_MHz);
	phi_SSB = zeros(1,N_GSCN_MHz);
	GSCN_corr_log = zeros(3*N_GSCN_MHz,ns/hSSB_decim);
	
	[hChannel,NhChannel] = Channel_filter(fs,BW_MHz);
	hChannel_state = zeros(NhChannel-1,1);

	% the sampling frequency must be a multiple of 128*15*2^mu kHz
	N_FFT = fs/SCS;
	if N_FFT ~= round(N_FFT)
		fprintf('The sampling frequency (fs) must be an integer multiple of %dMHz\n',1.92*2^mu);
		return
	end
	sc_ofs = N_FFT/2 - Nsc/2;
	N_CP = 9/128*N_FFT;
	N_CP_07 = (9+2^mu)/128*N_FFT; % symbols 0 or 7*2^mu
	CP_slack = N_FFT/128; % margin from estimated CP start point
	CP_len = N_CP*ones(1,Nsymb_subframe);
	CP_len(1+[0,7*2^mu]) = N_CP_07;
	sym_len = N_FFT+CP_len;
	% Phase compensation needed because transmitted signal is not simply Re{s(t)exp(2i*pi*f0*t)}
	% but each symbol is phase-shifted by the opposite of this quantity
	phase_comp = 2*pi*f0*(CP_len+[0,cumsum(sym_len(1:end-1))])*Ts;

	% -120 offset because GSCN frequency corresponds to SSB subcarrier 120
	PSS_ind = (56:182) -120;
	SSB_ind = (0:239)  -120;
	PSS_freq = zeros(N_FFT,3);
	PSS_freq(1+N_FFT/2+PSS_ind,:) = PSS_func;
	PSS_time = ifft(ifftshift(PSS_freq,1));
	hPSS = conj(flipud(PSS_time(1:hSSB_decim:end,:)));
	hPSS_state = zeros(N_GSCN_MHz*3,size(hPSS,1)-1);
	hPSS_norm_state = zeros(N_GSCN_MHz,size(hPSS,1)-1);

	% max_duration would be 3 but we never encountered it in practice and
	% it's not supported by SRSRAN/oCUDU
	max_duration = 2;

	nzpCSI_known = config.nzpCSI_known;
	if ~nzpCSI_known
		search_unknown_nzpCSI = config.search_unknown_nzpCSI;
	
		% blind search for CSI#1 (noCDM density 3) and #2 (noCDM density 1)
		CSI1.sc_spacing = 4;
		CSI1.k0 = -1;
		CSI1.bitmap = zeros(1,Nsymb_frame);
		CSI1.SFN = -1;
		CSI1.SFN_period = -1;
		CSI1.nID = -1;
		
		CSI2.sc_spacing = 12;
		CSI2.k0 = -1;
		CSI2.bitmap = zeros(1,Nsymb_frame);
		CSI2.SFN = -1;
		CSI2.SFN_period = -1;
		CSI2.nID = -1;
	else
		CSI1 = config.CSI1;
		CSI2 = config.CSI2;
	end

	% ZP-CSI-RS, used for Interference measurement
	% we assume there is only one 4REx1symbol group
	zpCSI_known = config.zpCSI_known;
	if ~zpCSI_known
		CSI0.sc_spacing = 12;
		CSI0.k0 = -1;
		CSI0.bitmap = zeros(1,Nsymb_frame);
		CSI0.SFN = -1;
		CSI0.SFN_period = -1;
		CSI0.SFNset = [];
	else
		CSI0 = config.CSI0;
	end

	if bitand(FIGURES,0x0010)
		% Log frequency and timing error over 100 frames
		Cfo_log = zeros(2,100); % eD,eF
		skip_for_sync_log = zeros(1,100);
	end

	% Skip initial samples if required (some radios have dynamic LO compensation
	% and have a long transient we may want to skip)
	fread(fp,[2 nskip],sample_type);

	% CORESET#0 format, shared by SIB1 and Random Access messages
	CORESET0_format_known = false;

	% list of RNTIs with PDSCH with CRC OK
	RNTI_count = 0;
	RNTI_list = zeros(1,100);
	RNTI_BWPstart = zeros(1,100); % -1 if unknown
	RNTI_BWPsize = zeros(1,100);  % -1 if unknown
	RNTI_symbAlloc = zeros(100,2); % symbol allocation
	RNTI_N_ID__nSCID = zeros(1,100); % PDSCH DMRS
	RNTI_nSCID = zeros(1,100);     % PDSCH DMRS
	RNTI_DMRS_addPos = zeros(1,100); % PDSCH DM-RS conf

	% counters for unconfirmed DCIs, Format1_0 with CRC ok or failed, and 0_0
	UE_RNTIs_count = zeros(size(KNOWN_UE_RNTIs));
	UE_RNTIs_Format10_crcOK = zeros(size(KNOWN_UE_RNTIs));
	UE_RNTIs_Format10_crcFail = zeros(size(KNOWN_UE_RNTIs));
	UE_RNTIs_FormatXX_UNC = zeros(size(KNOWN_UE_RNTIs));
	% list of unexpected RNTI's (may be all if KNOWN_UE_RNTIs is empty)
	UNKNOWN_UE_RNTIs = [];

	% ========== CREATE OUTPUT FOLDER FOR RESULTS ==========
	
	output_folder = 'results';
	if ~exist(output_folder, 'dir')
		mkdir(output_folder);
	end
	fprintf('Results will be saved in: %s\n', output_folder);

	% Save current directory and change to output folder for PCAP writing
	original_dir = pwd;
	cd(output_folder);

	% try and decode the PDSCH beyond extracting the DCIs 
	PDSCH_decoding = config.PDSCH_decoding;

	% this file will contain at least the SIB1 messages, always decoded
	% even if the PDSCH_decoding option is unset
	pcap_timestamp = 0;
	pcap_filename = ['capture_',cap,'.pcap'];
	if exist(pcap_filename,'file')
		delete(pcap_filename);
	end
	nrPCAPW = nrPCAPWriter(FileName=['capture_',cap],FileExtension='pcap',...
		FileComment='',Interface='5GNR',ByteOrder='little-endian');
	if f0_MHz < 3000
		pcap_RadioType = nrPCAPW.RadioFDD;
	else
		pcap_RadioType = nrPCAPW.RadioTDD;
	end

	% Return to original directory
	cd(original_dir);

	% main loop
	skip_for_sync = 0; % for timing synchronization
	Cfo_eF = 0; % frequency synchronization
	phi_s = 0; % continuous phase in the frequency correction
	SFN = -1; % frame number, 10 bit (-1: unknown)
	initialSystemInfo.NFrame = SFN;
	SFN_start = -1;
	alpha = 1; % counter for the PID estimation of Cfo
	
	if enable_artificial_noise
		fprintf('Artificial noise (TRACKING-only) enabled: SNR reduction = %.1f dB\n', SNR_reduction_dB);
	else
		fprintf('Artificial noise disabled\n');
	end

	VERBOSITY>=1 && fprintf('[ACQUIRE]\n'); %#ok <NASGU>

	% main loop
	while true
		fseek(fp,skip_for_sync*sample_size,'cof');
		phi_s = phi_s + 2*pi*(f0_corr-Cfo_eF)*skip_for_sync*Ts;
		pcap_timestamp = pcap_timestamp + ns*Ts*1e6; % us
		[s_raw,ns_read] = fread(fp,[2 ns],sample_type);
		if ns_read < 2*ns
			fclose(fp);
			break
		end
		if sample_size==4 % sc16
			s = [1 1i]*s_raw*3.0518e-5; % /32768
		else
			s = [1 1i]*s_raw;
		end
		[s,hChannel_state] = filter(hChannel,1,s,hChannel_state);
		% f0_corr is used to correct the trace if acquisition was not centered
		s = s .* exp(2i*pi*(f0_corr-Cfo_eF)*ts + 1i*phi_s);
		phi_s = phi_s + 2*pi*(f0_corr-Cfo_eF)*ns*Ts;
		
		switch state
			case 'ACQUIRE'
				% ========== STEP 1: ACQUISITION ==========
				step1_start = toc; % Start timing for Step 1
				[SSB_found,iSSB,SSB_offset,ncellid,k120,H_est_PSS,PBCH_power_est,noise_power_est,SSS_freq,Cfo_eD,Cfo_eF2,phi_SSB,hSSB_state,hPSS_state,hPSS_norm_state] = ...
					ACQUIRE(s,f0_MHz,GSCN_MHz,phi_SSB,fs,SCS,hSSB,hSSB_decim,hSSB_state,SSB_ind,hPSS,hPSS_state,hPSS_norm_state,...
					PSS_freq,PSS_ind,PSS_corr_thres,CP_slack,cp_corr_thres,phase_comp,FIGURES,VERBOSITY,GSCN_corr_log);
				step1_time = step1_time + toc - step1_start;

				if SSB_found
					% initialize baseline_noise_power
					baseline_noise_power = noise_power_est;
					noise_power_est_dB = 10*log10(noise_power_est);
					
					% set the Cfo to the PBCH-based estimate
					Cfo_eF = Cfo_eF2;

					% rewind after SSB acquisition
					frewind(fp);
					fread(fp,[2 nskip],sample_type);
					switch mu % 38.211
						case 0
							symSSB_tab = [ 2  8 16 22]; % Case A
						case 1
							symSSB_tab = [ 2  8 16 22 30 36 44 50]; % Case C
						otherwise
							error('Unsupported SSB case');
					end
					symSSB_ofs = symSSB_tab(1+iSSB);
					file_offset = SSB_offset - symSSB_ofs*(N_FFT+N_CP) ...
						- ceil(symSSB_ofs/(7*2^mu))*(N_CP_07-N_CP);
					fread(fp,[2 mod(file_offset,ns)],sample_type);

					% End Step 1 timing

					state = 'TRACK';
					VERBOSITY>=1 && fprintf('[TRACK]\n'); %#ok <NASGU>
				end

			case 'TRACK'
				
				% OFDM demodulation of entire frame (assumes uniform numerology)
				step2_start = toc;
				Y = whole_frame_fft(s,N_FFT,Nsymb_frame,mu,phase_comp,TDD_pattern,TA);
				step2_time = step2_time + toc - step2_start;

				% ========== NLOS CHANNEL MODELING (FREQUENCY DOMAIN) ==========
				if enable_NLOS_channel
					% Initialize channel model on first frame
					if isempty(NLOS_channel_filter)
						[NLOS_channel_filter, NLOS_channel_stats] = init_nlos_channel_model(...
							NLOS_channel_type, NLOS_scenario, NLOS_delay_spread, NLOS_K_factor, ...
							NLOS_Doppler_freq, NLOS_num_paths, fs, f0);

						fprintf('  [NLOS CHANNEL] Applied %s channel model (%s scenario)\n', ...
							NLOS_channel_type, NLOS_scenario);
					end

					% Apply NLOS channel to the FREQUENCY DOMAIN signal (after FFT)
					NLOS_channel_time = NLOS_channel_time + Tf;
					[Y, ~] = apply_nlos_channel(Y, NLOS_channel_filter, NLOS_channel_time);

					% % Calculate channel metrics
					% channel_metrics = calculate_channel_metrics_freq(Y, Y_NLOS, channel_response);
					% 
					% % Log channel performance impact (silent version - only first frame)
					% if SFN == -1
					% 	fprintf('  [NLOS CHANNEL] Frame %d: Path Loss = %.2f dB, Freq Selectivity = %.3f\n', ...
					% 		SFN, channel_metrics.path_loss_db, channel_metrics.avg_freq_selectivity);
					% end
				end

				% ========== ARTIFICIAL NOISE INJECTION ==========
				if enable_artificial_noise
					% Calculate target noise power and noise to add
					target_noise_power = 10^(SNR_reduction_dB/10) * baseline_noise_power;
					noise_power_to_add = target_noise_power - baseline_noise_power;

					% Add noise to signal
					Y = Y + sqrt(noise_power_to_add/2)*(randn(size(Y))+1i*randn(size(Y)));
					noise_power_est = target_noise_power;
				end

				if bitand(FIGURES,0x0040)
					Ymax = max(Ymax,max(abs(Y(:))));
				end

				% Determine if current frame contains PBCH and estimate timing offset
				% skip_for_sync is used at loop start to skip forward/backward in file
				step1_start = toc;
				[PBCH_in_frame,skip_for_sync,Cfo_eD] = PSS_timing_offset_est(Y,k120,...
					PSS_ind,symSSB_ofs,H_est_PSS,PSS_freq,SSS_freq,ncellid,PSS_corr_thres,fs,FIGURES);
				step1_time = step1_time + toc - step1_start;
				
				if PBCH_in_frame
					noise_power_est_new = mean(abs(Y(1+N_FFT/2+k120-120+([0:49,189:239]),1+symSSB_ofs)).^2);
					% AR estimate, but bootstrap if it's too different
					if noise_power_est_new/noise_power_est+noise_power_est/noise_power_est_new > 3
						noise_power_est = noise_power_est_new;
						%fprintf('new noise_power: %g\n',noise_power_est);
					else
						noise_power_est = 0.9*noise_power_est + 0.1*noise_power_est_new;
						%fprintf('upd noise_power: %g\n',noise_power_est);
					end
					noise_power_est_dB = 10*log10(noise_power_est);

					PBCH_power_est_new = mean(abs([Y(1+N_FFT/2+k120-120+(56:182),1+symSSB_ofs);...
						Y(1+N_FFT/2+k120-120+(0:239),2+symSSB_ofs);...
						Y(1+N_FFT/2+k120-120+[0:47,56:182,192:239],3+symSSB_ofs);...
						Y(1+N_FFT/2+k120-120+(0:239),4+symSSB_ofs)]).^2);
					if PBCH_power_est_new/PBCH_power_est+PBCH_power_est/PBCH_power_est_new > 3
						PBCH_power_est = PBCH_power_est_new;
					else
						PBCH_power_est = 0.9*PBCH_power_est + 0.1*PBCH_power_est_new;
					end
					% fprintf('  [DEBUG] Updated per-RE noise_est: %.2e (%.1f dB)\n', ...
					% 	noise_power_est, noise_power_est_dB);

					Cfo_eF2 = Cfo_eF2 + Kif*alpha*Cfo_eD;
					Cfo_eF = Kpf*alpha*Cfo_eD+Cfo_eF2;
					alpha = 1; % Time since last measurement

					% try decodeing the PBCH
					Y_PBCH = Y(1+N_FFT/2+k120+SSB_ind,symSSB_ofs+(1:4));
					[SFN,ssbIndex,crcBCH,initialSystemInfo] = hDecodePBCH(ncellid,Y_PBCH,iSSB,L_max,mod(SFN+1,1024),FIGURES);
					if SFN_start < 0
						SFN_start = SFN;
					end
				else
					if initialSystemInfo.NFrame >= 0
						initialSystemInfo.NFrame = mod(initialSystemInfo.NFrame + 1,1024);
					end
					SFN = initialSystemInfo.NFrame;
					alpha = alpha + 1; % Time since last measurement
				end

				if bitand(FIGURES,0x0040) && exist('noise_power_est_dB','var')
					currentfigure(7)
					hold off
					imagesc(0:Nsymb_frame-1,0:Nsc-1,20*log10(abs(Y(sc_ofs+(1:Nsc),:)))-noise_power_est_dB)
					hold on
					clim([-3 20*log10(Ymax)-noise_power_est_dB+3])
					colormap gray
					if SFN>=0
						title(['Synchronized Frame Visualization - SFN: ', num2str(SFN)])
					else
						title('Synchronized Frame Visualization - SFN: unknown')
					end
					xlabel('Symbol Index')
					ylabel('Subcarrier Index')

					if PBCH_in_frame
						if crcBCH == 0
							color = 'g';
						else
							color = 'r';
						end
						rectangle('Position',...
							[symSSB_ofs-0.5 N_FFT/2-sc_ofs+k120-120-0.5 4 240],...
							'FaceColor',color,'EdgeColor','none','FaceAlpha',0.3)
					end
					drawnow
				end

				% we are only interested in the CORESET#0 subcarrier
				% offset, as the DM-RS sequence is generated starting from it
				if (PBCH_in_frame && crcBCH == 0) && ~CORESET0_format_known
					scsSSB = hSSBurstSubcarrierSpacing(BlockPattern);
					scsKSSB = kSSBSubcarrierSpacing(initialSystemInfo.SubcarrierSpacingCommon);
					numRxSym = size(Y,2);
					csetSubcarriers = hPDCCH0MonitoringResources(initialSystemInfo,...
						scsSSB,minChannelBW,ssbIndex,numRxSym);
					CORESET0_grid_N_RB = hCORESET0DemodulationBandwidth(initialSystemInfo,scsSSB,minChannelBW);
					CORESET0_grid_RBstart = ((N_RB-CORESET0_grid_N_RB)*Nsc_RB/2+k120-initialSystemInfo.k_SSB*scsKSSB*1e3/SCS)/Nsc_RB;
					CORESET0_BWPstart = (csetSubcarriers(1)-1)/Nsc_RB;
					CORESET0_BWPsize = (csetSubcarriers(end)-csetSubcarriers(1)+1)/Nsc_RB;
					CORESET0_offset = (CORESET0_grid_RBstart+CORESET0_BWPstart)*Nsc_RB;
					scsCommon = initialSystemInfo.SubcarrierSpacingCommon;
					scsPair = [scsSSB scsCommon];
					[pdcch_CORESET0,CORESET0_pattern] = hPDCCH0Configuration(ssbIndex,initialSystemInfo,scsPair,ncellid,minChannelBW);
				end

				% noCDM NZP-CSI-RS and ZP-CSI-RS
				if SFN >= 0
					if nzpCSI_known
						if bitand(FIGURES,0x0080)
							if mod(SFN,CSI1.SFN_period) == CSI1.SFN
								for l = find(CSI1.bitmap)-1
									csi_H_est(Y,l,CSI1.k0,CSI1.sc_spacing,N_RB,CSI1.nID,FIGURES);
								end
							end
							if mod(SFN,CSI2.SFN_period) == CSI2.SFN
								for l = find(CSI2.bitmap)-1
									csi_H_est(Y,l,CSI2.k0,CSI2.sc_spacing,N_RB,CSI2.nID,FIGURES);
								end
							end
						end
					elseif search_unknown_nzpCSI
						% Search for CSI#1 or #2 sequence (using is_ok test of c_init)
						% Should be made more robust, searching until found first time, then by correlation
						step4_start = toc;
						CSI1=csi_update(Y,N_RB,SFN,CSI1,FIGURES);
						CSI2=csi_update(Y,N_RB,SFN,CSI2,FIGURES);
						step4_time = step4_time + toc - step4_start;
						if CSI1.SFN_period >= 0 && CSI2.SFN_period >= 0
							nzpCSI_known = true;
							fprintf('Add these instructions to the configuration file to speed up the next run (quasi static gNB configuration):\n');
							fprintf(['\n'...
								'config.CSI1.sc_spacing=%d;\nconfig.CSI1.SFN=%d;\nconfig.CSI1.SFN_period=%d;\nconfig.CSI1.k0=%d;\nconfig.CSI1.bitmap=zeros(1,%d);\nconfig.CSI1.bitmap(1+[%s])=1;\nconfig.CSI1.nID=%d;\n'...
								'config.CSI2.sc_spacing=%d;\nconfig.CSI2.SFN=%d;\nconfig.CSI2.SFN_period=%d;\nconfig.CSI2.k0=%d;\nconfig.CSI2.bitmap=zeros(1,%d);\nconfig.CSI2.bitmap(1+[%s])=1;\nconfig.CSI2.nID=%d;\n\n'],...
								CSI1.sc_spacing,CSI1.SFN,CSI1.SFN_period,CSI1.k0,Nsymb_frame,num2str(find(CSI1.bitmap)-1),CSI1.nID,...
								CSI2.sc_spacing,CSI2.SFN,CSI2.SFN_period,CSI2.k0,Nsymb_frame,num2str(find(CSI2.bitmap)-1),CSI2.nID);
							pause
						end
					end
				end

				if SFN < 0
					% if the SFN isn't known yet, skip
					continue
				end

				% blind search for DCIs
				step3_start = toc;
				dci = blind_search_for_DCIs(Y,sc_ofs,Nsc,CORESET0_offset,TDD_pattern,max_duration,ncellid,FIGURES);
				step3_time = step3_time + toc - step3_start;

				if bitand(FIGURES,0x0040) && exist('noise_power_est_dB','var')
					currentfigure(7)
					for iDci = 1:numel(dci)
						for irc = 1:size(dci(iDci).cand,1)
							rectangle('Position',[dci(iDci).slot*Nsymb_slot-0.5 dci(iDci).cand(irc,1)-1.5 dci(iDci).duration dci(iDci).cand(irc,2)-dci(iDci).cand(irc,1)+1],'FaceColor','g','EdgeColor','none','FaceAlpha',0.5)
						end
					end
					drawnow
				end

				for iDci = 1:numel(dci)

					if VERBOSITY>=2,fprintf('#%04d.%02d dur#%d AL#%d NID:0x%04x RNTI:0x%04x bits:%s\n',...
						SFN,dci(iDci).slot,dci(iDci).duration,dci(iDci).AL,dci(iDci).NID,dci(iDci).RNTI,char(dci(iDci).bits+'0'));end

					RNTI_ind = find(dci(iDci).RNTI==[KNOWN_UE_RNTIs UNKNOWN_UE_RNTIs]);
					if isscalar(RNTI_ind)
						UE_RNTIs_count(RNTI_ind) = UE_RNTIs_count(RNTI_ind)+1;
					else
						UNKNOWN_UE_RNTIs = [UNKNOWN_UE_RNTIs,dci(iDci).RNTI]; %#ok<AGROW>
						UE_RNTIs_count = [UE_RNTIs_count,1]; %#ok<AGROW>
						UE_RNTIs_Format10_crcOK = [UE_RNTIs_Format10_crcOK,0]; %#ok<AGROW>
						UE_RNTIs_Format10_crcFail = [UE_RNTIs_Format10_crcFail,0]; %#ok<AGROW>
						UE_RNTIs_FormatXX_UNC = [UE_RNTIs_FormatXX_UNC,0]; %#ok<AGROW>
					end

					% if it is a DCI Fallback 1_0, try and decode the payload, and if successful save it to the pcap
					% this branch uses the MathWorks functions from the sib1 recovery example
					if dci(iDci).CORESET0 && dci(iDci).NID == ncellid && dci(iDci).RNTI == 0xffff % SI-RNTI==FFFF

						grid_ofs = CORESET0_grid_RBstart;
						% grid_N_RB = CORESET0_grid_N_RB;
						BWPstart = CORESET0_BWPstart;
						BWPsize = CORESET0_BWPsize;

						step4_start = toc;
						dci_sib = DCIFormat1_0_SIRNTI(BWPsize);
						dci_sib = fromBits(dci_sib,dci(iDci).bits);
						pcap_RNTIType = nrPCAPW.SystemInfoRNTI;
						isDL = 1; rv = dci_sib.RedundancyVersion; % so we can use the C-RNTI code
						[L_RB,RBstart] = hDecodeRIV(BWPsize,dci_sib.FrequencyDomainResources);
						[code_rate,~] = hMCS(dci_sib.ModulationCoding);

						carrier = hCarrierConfigSIB1(ncellid,initialSystemInfo,pdcch_CORESET0);
						[pdsch,K0] = hSIB1PDSCHConfiguration(dci_sib,BWPsize,...
							initialSystemInfo.DMRSTypeAPosition,CORESET0_pattern);
						carrier.NSlot = dci(iDci).slot+K0;
						rxSlotGrid = Y(sc_ofs+(grid_ofs+BWPstart)*Nsc_RB+(1:BWPsize*Nsc_RB),(dci(iDci).slot+K0)*Nsymb_slot+(1:Nsymb_slot));
						[bits,crc,CSI0] = hDecodePDSCH_new(carrier,pdsch,rxSlotGrid,code_rate,rv,CSI0,CSI1,CSI2,RE_free_thres,false,FIGURES);
						step4_time = step4_time + toc - step4_start;

					elseif PDSCH_decoding % non-SIB messages

						% this code assumes that the configured Random Access uses the CORESET#0
						% and not another CORESET specified in the SIB1
						if dci(iDci).CORESET0 && dci(iDci).NID == ncellid && dci(iDci).RNTI <= 0x4600 && numel(dci(iDci).bits) <= Nmax_DCI_Fallback1_0 % RA-RNTI

							% Format_1_0 for RA-RNTI
							fdaNbits = numel(dci(iDci).bits) - 28;
							fda = sum(dci(iDci).bits(1:fdaNbits).*2.^(fdaNbits-1:-1:0));
							tdra = sum(dci(iDci).bits(fdaNbits+(1:4)).*[8 4 2 1]);
							interleaved_mapping = dci(iDci).bits(fdaNbits+5);
							mcs = sum(dci(iDci).bits(fdaNbits+(6:10)).*[16 8 4 2 1]);
							tb_scaling = sum(dci(iDci).bits(fdaNbits+(11:12)).*[2 1]);
							reserved = sum(dci(iDci).bits(fdaNbits+(13:28)).*2.^(15:-1:0));
							pcap_RNTIType = nrPCAPW.RandomAccessRNTI;
							isDL = 1; rv = 0; % so we can use the C-RNTI code
							if VERBOSITY>=3,fprintf('    fda:%d tdra:%d intlv:%d mcs:%d tb_scaling:%d rsvd:%d\n',...
								fda,tdra,interleaved_mapping,mcs,tb_scaling,reserved);end

						else % C-RNTI

							% we only support Fallback1_0 DCIs
							% check if the number of bits is compatible
							if dci(iDci).bits(1) && numel(dci(iDci).bits) <= Nmax_DCI_Fallback1_0
								fdaNbits = numel(dci(iDci).bits) - 28;
								isDL = dci(iDci).bits(1);
								fda = sum(dci(iDci).bits(2:fdaNbits+1).*2.^(fdaNbits-1:-1:0));
								tdra = sum(dci(iDci).bits(fdaNbits+(2:5)).*[8 4 2 1]);
								interleaved_mapping = dci(iDci).bits(fdaNbits+6);
								mcs = sum(dci(iDci).bits(fdaNbits+(7:11)).*[16 8 4 2 1]);
								ndi = dci(iDci).bits(fdaNbits+12);
								rv = sum(dci(iDci).bits(fdaNbits+(13:14)).*[2 1]);
								harqid = sum(dci(iDci).bits(fdaNbits+(15:18)).*[8 4 2 1]);
								dai = sum(dci(iDci).bits(fdaNbits+(19:20)).*[2 1]);
								tpc_cmd = sum(dci(iDci).bits(fdaNbits+(21:22)).*[2 1]);
								pucch_ri = sum(dci(iDci).bits(fdaNbits+(23:25)).*[4 2 1]);
								pdsch_harq_fbti = sum(dci(iDci).bits(fdaNbits+(26:28)).*[4 2 1]);
								pcap_RNTIType = nrPCAPW.CellRNTI;
								if VERBOSITY>=3,fprintf('    isDL:%d fda:%d tdra:%d intlv:%d mcs:%d ndi:%d rv:%d harqId:%d dai:%d tpc:%d pucch_ri:%d harq_fbti:%d\n',...
									isDL,fda,tdra,interleaved_mapping,mcs,ndi,rv,harqid,dai,tpc_cmd,pucch_ri,pdsch_harq_fbti);end
							else
								isDL = 0;
							end
						end
						if isDL && rv == 0
							[code_rate,modulation]=hMCS(mcs);
							% we also assume no delayed allocations
							K0 = 0;

							% might be CORESET#0 of a false positive
							if dci(iDci).CORESET0 && CORESET0_grid_RBstart>=0
								grid_N_RB = CORESET0_grid_N_RB;
								grid_ofs = CORESET0_grid_RBstart;

								BWPsize = CORESET0_BWPsize;
								BWPstart = CORESET0_grid_RBstart+CORESET0_BWPstart;

								N_ID__nSCID = ncellid;
								nSCID = 0;
								DMRS_addPos = 2;
								symbAlloc = [dci(iDci).duration Nsymb_slot-dci(iDci).duration];
							else
								grid_N_RB = N_RB;
								grid_ofs = 0;

								RNTI_listid = find(dci(iDci).RNTI == RNTI_list(1:RNTI_count));
								if numel(RNTI_listid)==0
									BWPsize = -1;
									BWPstart = -1;
									symbAlloc = [];
									N_ID__nSCID = -1;
									nSCID = -1;
									DMRS_addPos = -1;
								else
									BWPsize = RNTI_BWPsize(RNTI_listid);
									BWPstart = RNTI_BWPstart(RNTI_listid);
									symbAlloc = RNTI_symbAlloc(RNTI_listid,:);
									N_ID__nSCID = RNTI_N_ID__nSCID(RNTI_listid);
									nSCID = RNTI_nSCID(RNTI_listid);
									DMRS_addPos = RNTI_DMRS_addPos(RNTI_listid);
								end
							end

							% if the BWPsize (and start RB is known, we can proceed directly)
							if BWPsize > 0
								step4_start = toc;
								[L_RB,RBstart] = hDecodeRIV(BWPsize,fda);

								carrier=nrCarrierConfig('NCellID',ncellid,...
									'SubcarrierSpacing',SCS/1000,'CyclicPrefix','normal',...
									'NSizeGrid',grid_N_RB,'NStartGrid',grid_ofs,'NSlot',dci(iDci).slot,...
									'NFrame',SFN);
								pdsch=nrPDSCHConfig('NSizeBWP',BWPsize,'NStartBWP',BWPstart,...
									'Modulation',modulation,'NumLayers',1,'MappingType','A',...
									'SymbolAllocation',symbAlloc,'PRBSet',RBstart+(0:L_RB-1),...
									'PRBSetType','VRB','VRBToPRBInterleaving',interleaved_mapping,...
									'VRBBundleSize',2,'NID',ncellid,'RNTI',dci(iDci).RNTI);
								pdsch.DMRS=nrPDSCHDMRSConfig('DMRSConfigurationType',1,...
									'DMRSReferencePoint','CRB0','DMRSTypeAPosition',2,...
									'DMRSAdditionalPosition',DMRS_addPos,'DMRSLength',1,...
									'CustomSymbolSet',[],'DMRSPortSet',[],...
									'NIDNSCID',N_ID__nSCID,'NSCID',nSCID);

								rxSlotGrid = Y(sc_ofs+grid_ofs*Nsc_RB+(1:grid_N_RB*Nsc_RB),...
									(dci(iDci).slot+K0)*Nsymb_slot+(1:Nsymb_slot));
								[bits,crc,CSI0] = hDecodePDSCH_new(carrier,pdsch,rxSlotGrid,code_rate,rv,CSI0,CSI1,CSI2,RE_free_thres,true,FIGURES);
								step4_time = step4_time + toc - step4_start;
							else
								% need to find the BWPsize for this DCI
								% if a unique valid BWPsize/BWPstart configuration is
								% found, save its parameters in RNTI_list

								step4_start = toc;
								[FDA_BWP_hyp,nHyp] = find_FDA_BWP_hypotheses(...
									Y(1+sc_ofs+(0:Nsc_RB*N_RB-1),(dci(iDci).slot+K0)*Nsymb_slot+(dci(iDci).duration+1:Nsymb_slot)),...
									RE_busy_thres*sqrt(noise_power_est)*Nsc_RB*(Nsymb_slot-dci(iDci).duration),...
									FDA_BWP_int(1+fdaNbits,:),fda,dci(iDci).cand(1)/Nsc_RB,(dci(iDci).cand(2)-dci(iDci).cand(1)+1)/Nsc_RB);

								% for every possible interpretation of the
								% fda field, find the corresponding
								% BWPstart and try and decode the PDSCH
								for iHyp = 1:nHyp
									L_RB = FDA_BWP_hyp(iHyp,1);
									RBstart = FDA_BWP_hyp(iHyp,2);
									BWPsize = FDA_BWP_hyp(iHyp,3);
									BWPstart = FDA_BWP_hyp(iHyp,4);

									% the toolbox requires the whole slot, not just the BWP
									rxSlotGrid = Y(sc_ofs+grid_ofs*Nsc_RB+(1:grid_N_RB*Nsc_RB),...
										(dci(iDci).slot+K0)*Nsymb_slot+(1:Nsymb_slot));

									carrier = nrCarrierConfig('NCellID',ncellid,...
										'SubcarrierSpacing',SCS/1000,'CyclicPrefix','normal',...
										'NSizeGrid',grid_N_RB,'NStartGrid',grid_ofs,'NSlot',dci(iDci).slot,...
										'NFrame',SFN);

									symbAlloc = PDSCH_symbAlloc_autodetect(rxSlotGrid,BWPstart,RBstart,L_RB,dci(iDci).duration,RE_free_thres*sqrt(noise_power_est)*Nsc_RB*L_RB);

									% Create PDSCH configuration (same as in hDecodePDSCH)
									pdsch=nrPDSCHConfig('NSizeBWP',BWPsize,'NStartBWP',BWPstart,...
										'Modulation',modulation,'NumLayers',1,'MappingType','A',...
										'SymbolAllocation',symbAlloc,'PRBSet',RBstart+(0:L_RB-1),...
										'PRBSetType','VRB','VRBToPRBInterleaving',interleaved_mapping,...
										'VRBBundleSize',2,'NID',dci(iDci).NID,'RNTI',dci(iDci).RNTI);

									% Auto detect PDSCH DM-RS configuration
									[N_ID__nSCID,nSCID,DMRS_addPos] = PDSCH_DMRS_autodetect(rxSlotGrid,BWPstart,RBstart,L_RB,dci(iDci).slot,dci(iDci).duration);
									if N_ID__nSCID < 0
										continue % nHyp
									end
									pdsch.DMRS=nrPDSCHDMRSConfig('DMRSConfigurationType',1,...
										'DMRSReferencePoint','CRB0','DMRSTypeAPosition',2,...
										'DMRSAdditionalPosition',DMRS_addPos,'DMRSLength',1,...
										'CustomSymbolSet',[],'DMRSPortSet',[],...
										'NIDNSCID',N_ID__nSCID,'NSCID',nSCID);

									[bits,crc,CSI0] = hDecodePDSCH_new(carrier,pdsch,rxSlotGrid,code_rate,rv,CSI0,CSI1,CSI2,RE_free_thres,false,FIGURES);

									if crc == 0 && numel(RNTI_listid) == 0
										RNTI_count = RNTI_count + 1;
										RNTI_list(RNTI_count) = dci(iDci).RNTI;
										if FDA_BWP_hyp(iHyp,5) == 0
											RNTI_BWPsize(RNTI_count) = BWPsize; % If not ambiguous
										else
											RNTI_BWPsize(RNTI_count) = -1;
										end
										RNTI_BWPstart(RNTI_count) = BWPstart;
										RNTI_symbAlloc(RNTI_count,:) = symbAlloc;
										RNTI_N_ID__nSCID(RNTI_count) = N_ID__nSCID;
										RNTI_nSCID(RNTI_count) = nSCID;
										RNTI_DMRS_addPos(RNTI_count) = DMRS_addPos;
										break % nHyp
									end
								end
								step4_time = step4_time + toc - step4_start;
								% the BWP configuration changed, invalidate
								% the RNTI
								if exist('crc','var')
									if crc && numel(RNTI_listid)
										RNTI_list(RNTI_listid) = RNTI_list(RNTI_listid)+0x10000;
									end
								end
							end
						end
					else
						isDL = dci(iDci).bits(1);
						rv = -1;
					end
					
					RNTI_ind = find(dci(iDci).RNTI == KNOWN_UE_RNTIs);
					if ~isscalar(RNTI_ind)
						RNTI_ind = numel(KNOWN_UE_RNTIs) + find(dci(iDci).RNTI == UNKNOWN_UE_RNTIs);
					end
					if isDL && rv == 0
						if exist('crc','var') && crc == 0
							UE_RNTIs_Format10_crcOK(RNTI_ind) = UE_RNTIs_Format10_crcOK(RNTI_ind) + 1;
						else
							UE_RNTIs_Format10_crcFail(RNTI_ind) = UE_RNTIs_Format10_crcFail(RNTI_ind) + 1;
						end
					else
						UE_RNTIs_FormatXX_UNC(RNTI_ind) = UE_RNTIs_FormatXX_UNC(RNTI_ind) + 1;
					end

					if isDL && rv == 0
						if exist('crc','var') && crc == 0
							if VERBOSITY >= 4,fprintf('      trBlk: %s\n',reshape(dec2hex(reshape(2.^(7:-1:0)*reshape(single(bits),8,[]),1,[])).',1,[]));end

							% PCAP output
							nrMACPDU = reshape(2.^(7:-1:0)*reshape(double(bits),[8 numel(bits)/8]),[1 numel(bits)/8]);
							packetInfo = struct();
							packetInfo.RadioType = pcap_RadioType;
							packetInfo.LinkDir = nrPCAPW.Downlink;
							packetInfo.RNTIType = pcap_RNTIType;
							packetInfo.RNTI = dci(iDci).RNTI;
							packetInfo.SystemFrameNumber = SFN;
							packetInfo.SlotNumber = dci(iDci).slot;
							write(nrPCAPW,nrMACPDU,pcap_timestamp+dci(iDci).slot*1000,PacketInfo=packetInfo);
						end
						if bitand(FIGURES,0x0040) && exist('noise_power_est_dB','var')
							if exist('crc','var') && crc==0
								color ='g';
							else
								color='r';
							end
							currentfigure(7)
							rectangle('Position',...
								[(dci(iDci).slot+K0)*Nsymb_slot+dci(iDci).duration-0.5 ...
								(grid_ofs+BWPstart+RBstart)*Nsc_RB-0.5 ...
								Nsymb_slot-dci(iDci).duration L_RB*Nsc_RB],...
								'FaceColor',color,'EdgeColor','none','FaceAlpha',0.5)
							drawnow
						end
					end

				end % iDci
				if ~zpCSI_known && CSI0.SFN_period > 0
					zpCSI_known = true;
					fprintf('Add these instructions to the configuration file to speed up the next run (quasi static gNB configuration):\n');
					fprintf('\nconfig.CSI0.sc_spacing=%d;\nconfig.CSI0.SFN=%d;\nconfig.CSI0.SFN_period=%d;\nconfig.CSI0.k0=%d;\nconfig.CSI0.bitmap=zeros(1,%d);\nconfig.CSI0.bitmap(1+[%s])=1;\n\n',...
						CSI0.sc_spacing,CSI0.SFN,CSI0.SFN_period,CSI0.k0,Nsymb_frame,num2str(find(CSI0.bitmap)-1));
					pause
				end

			otherwise % state
				% keyboard
		end

		if VERBOSITY >= 2
			if SFN >= 0
				fprintf('\n  SFN: %4d\n',SFN);
				fprintf('  RNTI:    ');for i = 1:numel(KNOWN_UE_RNTIs),fprintf(' %04x',KNOWN_UE_RNTIs(i));end
				for i = 1:numel(UNKNOWN_UE_RNTIs),fprintf(' %04x',UNKNOWN_UE_RNTIs(i));end;fprintf('\n');
				%fprintf('         ');for i = 1:numel(UE_RNTIs_count),fprintf(' %4d',UE_RNTIs_count(i));end;fprintf('\n');
				fprintf('  1_0 crcOK');for i = 1:numel(UE_RNTIs_Format10_crcOK),fprintf(' %4d',UE_RNTIs_Format10_crcOK(i));end;fprintf('\n');
				fprintf('  1_0 crcKO');for i = 1:numel(UE_RNTIs_Format10_crcFail),fprintf(' %4d',UE_RNTIs_Format10_crcFail(i));end;fprintf('\n');
				fprintf('  X_X unc  ');for i = 1:numel(UE_RNTIs_FormatXX_UNC),fprintf(' %4d',UE_RNTIs_FormatXX_UNC(i));end;fprintf('\n\n');
			end
		elseif SFN >= 0
			fprintf('SFN: %4d - #DCI: %d (Format1_0 CRC OK: %d/%d = %5.1f%%)\n',SFN,sum(UE_RNTIs_count),...
				sum(UE_RNTIs_Format10_crcOK),sum(UE_RNTIs_Format10_crcOK)+sum(UE_RNTIs_Format10_crcFail),...
				100*sum(UE_RNTIs_Format10_crcOK)/(sum(UE_RNTIs_Format10_crcOK+UE_RNTIs_Format10_crcFail)));
		end

		if bitand(FIGURES,0x0010)
			Cfo_log = [Cfo_log(:,2:end),[Cfo_eD;Cfo_eF]];
			skip_for_sync_log = [skip_for_sync_log(2:end),skip_for_sync];
			currentfigure(5)

			subplot(3,1,1)
			plot(Cfo_log(1,:))
			ylabel('CFO_{eD} [Hz]')
			title('Estimated Carrier Frequency Offset (Doppler) Over Time')

			subplot(3,1,2)
			plot(Cfo_log(2,:))
			ylabel('CFO_{eF} [Hz]')
			title('Estimated Carrier Frequency Offset (Phase) Over Time')

			subplot(3,1,3)
			stem(skip_for_sync_log)
			ylabel('Number of Samples Skipped')
			xlabel('Frame Index')
			title('Synchronization Sample Skips Over Frames')

			drawnow
		end
	end
	SFN_stop = SFN;

	% ========== NLOS CHANNEL PERFORMANCE ANALYSIS ==========
	if enable_NLOS_channel && ~isempty(NLOS_channel_filter)
		fprintf('\n========== NLOS CHANNEL PERFORMANCE ANALYSIS ==========\n');
		fprintf('Channel Model:               %s (%s scenario)\n', NLOS_channel_type, NLOS_scenario);
		fprintf('RMS Delay Spread:            %.1f ns\n', NLOS_channel_stats.rms_delay_spread * 1e9);
		fprintf('Coherence Bandwidth:         %.2f MHz\n', NLOS_channel_stats.coherence_bandwidth / 1e6);
		fprintf('Max Doppler Frequency:       %.1f Hz\n', NLOS_Doppler_freq);
		fprintf('Coherence Time:              %.2f ms\n', NLOS_channel_stats.coherence_time * 1000);
		fprintf('Number of Multipath:         %d paths\n', length(NLOS_channel_filter.delays));

		% Calculate average path loss from channel
		avg_path_loss = mean(NLOS_channel_filter.powers);
		fprintf('Average Path Loss:           %.2f dB\n', avg_path_loss);

		% K-factor information
		if isfinite(NLOS_K_factor) && NLOS_K_factor > -inf
			fprintf('K-factor:                    %.1f dB (mixed LOS/NLOS)\n', NLOS_K_factor);
		else
			fprintf('K-factor:                    Pure NLOS (no LOS component)\n');
		end

		% Channel impact assessment
		fprintf('\n--- Channel Impact Assessment ---\n');
		if NLOS_channel_stats.rms_delay_spread > 200e-9
			fprintf('• High delay spread (>200ns): Significant frequency selectivity\n');
		elseif NLOS_channel_stats.rms_delay_spread > 100e-9
			fprintf('• Moderate delay spread (100-200ns): Some frequency selectivity\n');
		else
			fprintf('• Low delay spread (<100ns): Minimal frequency selectivity\n');
		end
		if NLOS_Doppler_freq > 50
			fprintf('• High Doppler (>50Hz): Significant time selectivity\n');
		elseif NLOS_Doppler_freq > 5
			fprintf('• Moderate Doppler (5-50Hz): Some time selectivity\n');
		else
			fprintf('• Low Doppler (<5Hz): Minimal time selectivity\n');
		end
		if NLOS_channel_stats.coherence_bandwidth < 1e6
			fprintf('• Narrow coherence bandwidth (<1MHz): Strong frequency selectivity\n');
		else
			fprintf('• Wide coherence bandwidth (>1MHz): Weak frequency selectivity\n');
		end
		if NLOS_channel_stats.coherence_time < 1e-3
			fprintf('• Short coherence time (<1ms): Fast channel variations\n');
		else
			fprintf('• Long coherence time (>1ms): Slow channel variations\n');
		end
		fprintf('========================================================\n');
	end

	total_time = toc;
	overh_time = total_time - (step1_time + step2_time + step3_time + step4_time);
	fprintf('\n========== GOLDEN SNIFFER TIMING ANALYSIS ===============\n');
	fprintf('STEP 1 (Acquisition & Tracking):             %9.2f ms (%.1f%%)\n', step1_time*1000,100*step1_time/total_time);
	fprintf('STEP 2 (FFT):                                %9.2f ms (%.1f%%)\n', step2_time*1000,100*step2_time/total_time);
	fprintf('STEP 3 (blind PDCCH detection):              %9.2f ms (%.1f%%)\n', step3_time*1000,100*step3_time/total_time);
	fprintf('STEP 4 (CSI-RS, PDSCH format detect/decode): %9.2f ms (%.1f%%)\n', step4_time*1000,100*step4_time/total_time);
	fprintf('OTHER PROCESSING / OVERHEAD                  %9.2f ms (%.1f%%)\n', overh_time*1000,100*overh_time/total_time);
	fprintf('TOTAL PROCESSING TIME:                       %9.2f ms\n', total_time*1000);
	fprintf('=========================================================\n');

	fprintf('SFN range: %d:%d\n\n',SFN_start,SFN_stop);
	fprintf('                     RNTI:');for i = 1:numel(KNOWN_UE_RNTIs),fprintf(' 0x%04x',KNOWN_UE_RNTIs(i));end
	for i = 1:numel(UNKNOWN_UE_RNTIs),fprintf(' 0x%04x',UNKNOWN_UE_RNTIs(i));end;fprintf('\n');
	fprintf('  Format1_0 with CRC pass:');for i = 1:numel(UE_RNTIs_Format10_crcOK),fprintf(' %6d',UE_RNTIs_Format10_crcOK(i));end;fprintf('\n');
	fprintf('  Format1_0 with CRC fail:');for i = 1:numel(UE_RNTIs_Format10_crcFail),fprintf(' %6d',UE_RNTIs_Format10_crcFail(i));end;fprintf('\n');
	fprintf('  FormatX_X (unconfirmed):');for i = 1:numel(UE_RNTIs_FormatXX_UNC),fprintf(' %6d',UE_RNTIs_FormatXX_UNC(i));end;fprintf('\n\n');
end
