% maximum with parabolic interpolation
%
%   Copyright 2024 GoldenSniffer Project
%   Licensed under MIT License
%
function [y0_est,x0_est] = max_parab(y,x)
	n = numel(y);
	[~,pos] = max(y);
	if nargin < 2
		x = 1:n;
		dx = 1;
	else
		dx = x(2)-x(1);
	end
	x0 = x(pos);
	y0 = y(pos);
	xm = x(1+mod(pos-2,n));
	ym = y(1+mod(pos-2,n));
	xp = x(1+mod(pos,n));
	yp = y(1+mod(pos,n));
	corr_x = (yp-ym)/2/(2*y0-ym-yp);
	if isnan(corr_x)
		x0_est = x0;
		y0_est = y0;
	elseif abs(corr_x)<0.5001
		x0_est = x0 + corr_x*dx;
		corr_y = (yp-ym)^2/8/(2*y0-ym-yp);
		y0_est = y0 + corr_y;
	else
		%%%keyboard
	end
end
