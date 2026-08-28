config.enable_NLOS_channel = false;
% config.enable_NLOS_channel = true;  % Enable NLOS channel modeling (uses frequency domain)

if config.enable_NLOS_channel
	config.NLOS_channel_type = 'CDL-A';  % Options: 'CDL-A', 'CDL-B', 'CDL-C', 'CDL-D', 'CDL-E', 'TDL-A', 'TDL-B', 'TDL-C'
	config.NLOS_scenario = 'outdoor';  % Options: 'outdoor', 'indoor', 'urban_macro', 'urban_micro'
	config.NLOS_delay_spread = [];  % RMS delay spread (empty = use default for scenario)
	config.NLOS_K_factor = -inf;  % K-factor in dB (-inf for pure NLOS)
	config.NLOS_Doppler_freq = 1000; % Maximum Doppler frequency in Hz
	config.NLOS_num_paths = 20;  % Number of multipath components
	config.NLOS_channel_filter = [];  % Channel filter state
	config.NLOS_channel_time = 0;
end

config.SNR_reduction_dB = 0;
% config.SNR_reduction_dB = 10;
