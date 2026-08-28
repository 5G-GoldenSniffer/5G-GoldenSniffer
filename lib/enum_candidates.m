% input:
% - runs (Nruns rows, one row for every run: [start stop MSE])
% - duration (1,2 or 3)
% - AL=2^log2AL
% output:
% - cand{1:Ncand}
%   every element is a matrix containing Nsc_cand = AL*Nsc_CCE = AL*6*Nsc_REG/duration subcarriers
%   - one row for every run inside the candidate (one for not interleaved candidates)
%   - two columns start:stop for the initial and final subcarrier indeces

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
function [cand,Ncand] = enum_candidates(runs,duration,log2AL)
	Nsc_REG = 12;
	Nsc_CCE = 6*Nsc_REG/duration;
	AL = 2^log2AL;
	Nsc_cand = AL*Nsc_CCE;

	Nruns = size(runs,1);
	run_len = runs(:,2)-runs(:,1)+1;

	Ncand = 0;
	cand = cell(0);
	
	for irun = 1:Nruns
		% for runs containing an integer multiple of Nsc_cand, add
		% disjoint not-interleaved candidates 
		if mod(run_len(irun),Nsc_cand)==0
			Ncand_run = run_len(irun)/Nsc_cand;
			for i = 1:Ncand_run
				cand{Ncand+i} = runs(irun,1)+(i-1)*Nsc_cand+[0 Nsc_cand-1];
			end
			Ncand = Ncand + Ncand_run;
		end
		% for runs containing an integer multiple and a half of Nsc_cand,
		% add candidates overlapping by Nsc_cand/2
		if run_len(irun)>Nsc_cand && mod(run_len(irun),Nsc_cand)==Nsc_cand/2
			Ncand_run = 1+floor((run_len(irun)-Nsc_cand)/(Nsc_cand/2));
			for i = 1:Ncand_run
				cand{Ncand+i} = runs(irun,1)+(i-1)*Nsc_cand/2+[0 Nsc_cand-1];
			end
			Ncand = Ncand + Ncand_run;
		end
	end
	% add interleaved candidates corresponding to couples of runs of equal length 
	for irun = 1:Nruns-1
		for jrun = irun+1:Nruns
			if mod(run_len(irun)+run_len(jrun),Nsc_cand)==0 && run_len(irun) == run_len(jrun) && mod(runs(irun,1)-1,Nsc_CCE)==mod(runs(jrun,1)-1,Nsc_CCE)
				Ncand_run = (run_len(irun)+run_len(jrun))/Nsc_cand;
				for i = 1:Ncand_run
					cand{Ncand+i} = runs([irun;jrun],1)+[0,Nsc_cand/(2*Ncand_run)-1]+(i-1)*Nsc_cand/(2*Ncand_run);
				end
				Ncand = Ncand + Ncand_run;
			end
		end
	end
	% add interleaved candidates for triples of runs of the same length, or
	% where the longest amounts to the sum of the lengths of the others
	for irun = 1:Nruns-2
		for jrun = irun+1:Nruns-1
			for krun = jrun+1:Nruns
				if mod(run_len(irun)+run_len(jrun)+run_len(krun),Nsc_cand)==0 && ...
						((run_len(irun) == run_len(jrun) && run_len(irun) == run_len(krun)) || run_len(irun) == run_len(jrun)+run_len(krun) || run_len(jrun) == run_len(irun)+run_len(krun) || run_len(krun) == run_len(irun)+run_len(jrun)) ...
						&& mod(runs(irun,1)-1,Nsc_CCE)==mod(runs(jrun,1)-1,Nsc_CCE) && mod(runs(irun,1)-1,Nsc_CCE)==mod(runs(krun,1)-1,Nsc_CCE)
					Ncand_run = (run_len(irun)+run_len(jrun)+run_len(krun))/Nsc_cand;
					if Ncand_run == 1
						cand{Ncand+1} = runs([irun,jrun,krun],1:2);
						Ncand = Ncand+1;
					% else
					% 	keyboard
					end
				end
			end
		end
	end
end
