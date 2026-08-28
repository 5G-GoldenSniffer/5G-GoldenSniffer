% remove from runs and cand the subcarrier indeces in cand{icand}
% if the remaining subcarriers in runs are not sufficient for 

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
function [runs,cand,Ncand] = update_candidates(runs,cand,icand,duration,log2AL)
	Nruns = size(runs,1);
	for irun = 1:Nruns
		runs_in_icand = size(cand{icand},1);
		for irc = 1:runs_in_icand
			if cand{icand}(irc,1) >= runs(irun,1) && cand{icand}(irc,2) <= runs(irun,2)
				if cand{icand}(irc,1) == runs(irun,1) && cand{icand}(irc,2) == runs(irun,2)
					runs(irun,1)=runs(irun,2)+1;
				elseif cand{icand}(irc,1) == runs(irun,1)
					runs(irun,1) = cand{icand}(irc,2)+1;
				elseif cand{icand}(irc,2) == runs(irun,2)
					runs(irun,2) = cand{icand}(irc,1)-1;
				else
					runs(Nruns+1,:) = [cand{icand}(irc,2)+1 runs(irun,2) runs(irun,3)];
					runs(irun,2) = cand{icand}(irc,1)-1;
				end
			end
		end
	end
	[cand,Ncand] = enum_candidates(runs,duration,log2AL);
end
