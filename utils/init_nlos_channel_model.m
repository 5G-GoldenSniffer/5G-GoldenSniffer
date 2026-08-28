% Initialize NLOS channel model
%
%   Copyright 2024 GoldenSniffer Project
%   Licensed under MIT License
%
function [channel_model, channel_stats] = init_nlos_channel_model(channel_type, scenario, delay_spread, k_factor, doppler_freq, num_paths, sample_rate, carrier_freq)
	channel_model = struct();
	channel_stats = struct();

	% Set default parameters based on scenario
	switch scenario
		case 'outdoor'
			% Urban Macro NLOS (Table 7.5-6 in TR 38.901)
			if isempty(delay_spread)
				delay_spread = 300e-9;  % 300 ns RMS delay spread
			end
			path_loss_exp = 3.8;  % Path loss exponent
			shadow_std = 8.0;     % Shadow fading standard deviation (dB)

		case 'indoor'
			% Indoor Office NLOS (Table 7.5-7 in TR 38.901)
			if isempty(delay_spread)
				delay_spread = 150e-9;  % 150 ns RMS delay spread
			end
			path_loss_exp = 2.8;  % Path loss exponent
			shadow_std = 6.0;     % Shadow fading standard deviation (dB)

		case 'urban_macro'
			% Urban Macro NLOS with higher delay spread
			if isempty(delay_spread)
				delay_spread = 500e-9;  % 500 ns RMS delay spread
			end
			path_loss_exp = 4.0;  % Path loss exponent
			shadow_std = 10.0;    % Shadow fading standard deviation (dB)

		case 'urban_micro'
			% Urban Micro NLOS
			if isempty(delay_spread)
				delay_spread = 200e-9;  % 200 ns RMS delay spread
			end
			path_loss_exp = 3.5;  % Path loss exponent
			shadow_std = 7.0;     % Shadow fading standard deviation (dB)
	end

	% Generate multipath delays based on channel type
	switch channel_type
		case 'CDL-A'
			% Non-Line-of-Sight, moderate delay spread
			relative_delays = [0, 0.3819, 0.4025, 0.5868, 0.4610, 0.5375, 0.6708, 0.5750, 0.7618, 1.5375] * 1e-6;
			relative_powers = [0, -13.4, -13.4, -13.4, -15.8, -15.8, -15.8, -17.2, -17.2, -17.2]; % dB

		case 'CDL-B'
			% Non-Line-of-Sight, small delay spread
			relative_delays = [0, 0.2099, 0.2219, 0.2329, 0.2176, 0.6366, 0.6448, 0.6560, 0.6584, 0.7935] * 1e-6;
			relative_powers = [0, -2.2, -4.0, -6.0, -8.2, -9.9, -12.5, -13.7, -15.0, -16.0]; % dB

		case 'CDL-C'
			% Non-Line-of-Sight, large delay spread
			relative_delays = [0, 0.2099, 0.2219, 0.2329, 0.2176, 0.6366, 0.6448, 0.6560, 0.6584, 0.7935, 1.2648, 1.5491] * 1e-6;
			relative_powers = [0, -4.4, -1.2, -3.5, -5.2, -2.5, -3.0, -9.0, -11.1, -12.9, -15.8, -18.5]; % dB

		case 'CDL-D'
			% Non-Line-of-Sight, very large delay spread
			relative_delays = [0, 0.035, 0.612, 1.363, 1.405, 1.804, 2.596, 1.775, 4.042, 7.937, 9.424, 10.024] * 1e-6;
			relative_powers = [0, -10.5, -10.2, -12.8, -13.0, -15.0, -17.2, -15.8, -17.9, -21.4, -22.4, -22.9]; % dB

		case 'CDL-E'
			% Non-Line-of-Sight, extremely large delay spread
			relative_delays = [0, 0.5133, 0.5440, 0.5630, 0.5440, 0.7112, 1.9092, 1.9293, 1.9589, 2.6426, 3.7136, 5.4524] * 1e-6;
			relative_powers = [0, -0.9, -1.7, -2.6, -1.5, -3.0, -8.9, -9.4, -13.2, -13.9, -13.9, -15.8]; % dB

		case 'TDL-A'
			% Tapped Delay Line Model A (moderate delay spread)
			relative_delays = [0, 0.3819, 0.4025, 0.5868, 0.4610, 0.5375, 0.6708, 0.5750, 0.7618, 1.5375] * 1e-6;
			relative_powers = [-13.4, 0, 0, 0, -2.2, -2.2, -2.2, -4.0, -4.0, -4.0]; % dB

		case 'TDL-B'
			% Tapped Delay Line Model B (small delay spread)
			relative_delays = [0, 0.1072, 0.2155, 0.2095, 0.2870, 0.2986, 0.3752, 0.5055, 0.3681, 0.3697] * 1e-6;
			relative_powers = [-0.2, -2.5, -8.4, -9.3, -10.0, -22.4, -20.7, -25.5, -16.0, -18.3]; % dB

		case 'TDL-C'
			% Tapped Delay Line Model C (large delay spread)
			relative_delays = [0, 0.2099, 0.2219, 0.2329, 0.2176, 0.6366, 0.6448, 0.6560, 0.6584, 0.7935, 1.2648, 1.5491] * 1e-6;
			relative_powers = [-4.4, -1.2, -3.5, -5.2, -2.5, -3.0, -9.0, -11.1, -12.9, -15.8, -18.5, -20.7]; % dB

		otherwise
			error('Unknown channel type: %s', channel_type);
	end

	% Scale delays by the desired RMS delay spread
	actual_rms_delay = sqrt(sum(10.^(relative_powers/10) .* relative_delays.^2) / sum(10.^(relative_powers/10)));
	if actual_rms_delay > 0
		scale_factor = delay_spread / actual_rms_delay;
		scaled_delays = relative_delays * scale_factor;
	else
		scaled_delays = relative_delays;
	end

	% Limit number of paths if specified
	if num_paths < length(scaled_delays)
		[~, idx] = sort(relative_powers, 'descend');
		selected_idx = idx(1:num_paths);
		scaled_delays = scaled_delays(selected_idx);
		relative_powers = relative_powers(selected_idx);
	end

	% Generate Doppler shifts for each path (assuming uniform angular spread)
	doppler_shifts = doppler_freq * (2*rand(size(scaled_delays)) - 1);

	% Generate initial deterministic phases for each path (for repeatable results)
	% Use path index for deterministic but realistic phase distribution
	initial_phases = 2 * pi * (0:length(scaled_delays)-1) / length(scaled_delays);
	initial_phases = initial_phases(:); % Ensure column vector

	% Store channel model parameters
	channel_model.type = channel_type;
	channel_model.scenario = scenario;
	channel_model.delays = scaled_delays;
	channel_model.powers = relative_powers;
	channel_model.doppler_shifts = doppler_shifts;
	channel_model.initial_phases = initial_phases;  % Add initial phases
	channel_model.k_factor = k_factor;
	channel_model.sample_rate = sample_rate;
	channel_model.carrier_freq = carrier_freq;
	channel_model.path_loss_exp = path_loss_exp;
	channel_model.shadow_std = shadow_std;

	% Initialize channel filter taps
	max_delay_samples = ceil(max(scaled_delays) * sample_rate);
	channel_model.filter_taps = zeros(max_delay_samples + 1, 1);

	% Calculate channel statistics
	channel_stats.rms_delay_spread = sqrt(sum(10.^(relative_powers/10) .* scaled_delays.^2) / sum(10.^(relative_powers/10)));
	channel_stats.coherence_bandwidth = 1 / (2 * pi * channel_stats.rms_delay_spread);
	channel_stats.coherence_time = 1 / (2 * pi * doppler_freq);
	channel_stats.avg_path_loss = mean(relative_powers);
end
