% Apply NLOS channel to frequency domain signal
%
%   Copyright 2024 GoldenSniffer Project
%   Licensed under MIT License
%
function [Y_channel, channel_response] = apply_nlos_channel(Y, channel_model, frame_time)
	[num_subcarriers, num_symbols] = size(Y);
	Y_channel = zeros(size(Y));
	channel_response = zeros(size(Y));

	% Calculate frequency spacing
	freq_spacing = channel_model.sample_rate / num_subcarriers;
	frequencies = (-num_subcarriers/2:num_subcarriers/2-1) * freq_spacing;

	% Apply channel to each OFDM symbol
	for sym_idx = 1:num_symbols
		symbol_time = frame_time + (sym_idx - 1) * (1/15000); % Assuming 15 kHz subcarrier spacing

		% Calculate channel frequency response
		H = zeros(num_subcarriers, 1);

		for path_idx = 1:length(channel_model.delays)
			% Path gain with Doppler shift
			path_gain = sqrt(10^(channel_model.powers(path_idx)/10));
			doppler_phase = 2 * pi * channel_model.doppler_shifts(path_idx) * symbol_time;
			path_gain_doppler = path_gain * exp(1j * doppler_phase);

			% Frequency response for this path
			delay = channel_model.delays(path_idx);
			H_path = path_gain_doppler * exp(-1j * 2 * pi * frequencies * delay);

			H = H + H_path.';
		end

		% Apply Rician fading if K-factor is specified
		if isfinite(channel_model.k_factor) && channel_model.k_factor > -inf
			K_linear = 10^(channel_model.k_factor/10);
			% Add LOS component
			los_gain = sqrt(K_linear / (K_linear + 1));
			nlos_gain = sqrt(1 / (K_linear + 1));
			H = los_gain * ones(size(H)) + nlos_gain * H;
		end

		% Apply channel to this symbol
		Y_channel(:, sym_idx) = Y(:, sym_idx) .* H;
		channel_response(:, sym_idx) = H;
	end
end
