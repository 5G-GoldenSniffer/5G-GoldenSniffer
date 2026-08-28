% set a figure current (and docked) without stealing focus from the current window
%
%   Copyright 2024 GoldenSniffer Project
%   Licensed under MIT License
%
function currentfigure(nf)
	if ishghandle(nf)
		set(0,'CurrentFigure',nf)
	else
		figure(nf)
	end
	set(nf,'WindowStyle','docked')
end
