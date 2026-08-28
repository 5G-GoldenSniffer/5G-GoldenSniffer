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
function [duration,bitmap,runs_out] = power_detect_REGs(Y,CORESET0_offset)
	% this heuristic assumes that the CORESET#0 duration and UE-dedicated
	% CORESETS have the same duration
	CORR_THRES = 0.975; % FIXME
	if size(Y,2) > 1
		corr12 = abs(Y(:,1))'*abs(Y(:,2))/norm(Y(:,1))/norm(Y(:,2));
		if corr12 > CORR_THRES
			if size(Y,2) > 2
				corr13 = (abs(Y(:,1))+abs(Y(:,2)))'*abs(Y(:,3))/norm(abs(Y(:,1))+abs(Y(:,2)))/norm(Y(:,3));
				if corr13 > CORR_THRES
					duration = 3;
				else
					duration = 2;
				end
			else
				duration = 2;
			end
		else
			duration = 1;
		end
	end
	% fprintf('duration: %d',duration);

	Nsc_REG = 12;
	Nsc_CCE = 6*Nsc_REG/duration;
	bitmap = false(size(Y,1),duration);
	runs = [];
	Nruns = 0;

	N = size(Y,1);
	Y = sum(abs(Y(:,1:duration)),2);
	AMPLITUDE_TOL = 0.4;
	loops = 3;
	while loops > 0
		[val,pos]=max(Y);
		pos_r = pos;
		while pos_r<N && abs(Y(pos_r+1)-Y(pos_r)) < AMPLITUDE_TOL*(Y(pos_r+1)+Y(pos_r))
			pos_r = pos_r+1;
		end
		pos_l = pos;
		while pos_l>1 && abs(Y(pos_l-1)-Y(pos_l)) < AMPLITUDE_TOL*(Y(pos_l-1)+Y(pos_l))
			pos_l = pos_l-1;
		end
		if mod(pos_r-pos_l+1,Nsc_REG)==0
			runs = [runs;pos_l,pos_r,mean(abs(Y(pos_l:pos_r)).^2)];
			Nruns = Nruns + 1;
		else
			runs = [runs;pos_l,pos_r,mean(abs(Y(pos_l:pos_r)).^2)];
			Nruns = Nruns + 1;
			loops = loops - 1;
		end
		Y(pos_l:pos_r) = 0;
	end
	runs_out = [];
	if numel(runs)
		runs = sortrows(runs);
		i = 1;
		while i <= Nruns-1
			if runs(i+1,1)-runs(i,2)<=2 && runs(i,3)/runs(i+1,3)+runs(i+1,3)/runs(i,3)<20 % RFC
				runs(i,3) = (runs(i,3)*(runs(i,2)-runs(i,1)+1)+runs(i+1,3)*(runs(i+1,2)-runs(i+1,1)+1))/(runs(i+1,2)-runs(i,1)+1);
				runs(i,2) = runs(i+1,2);
				for j = i+1:Nruns-1
					runs(j,:) = runs(j+1,:);
				end
				Nruns = Nruns-1;
			else
				i = i + 1;
			end
		end
		for i = 1:Nruns
			if mod(runs(i,2)-runs(i,1)+1,Nsc_CCE)==0 && ...
					(mod(runs(i,1)-1,Nsc_CCE)==0 || mod(runs(i,1)-1-CORESET0_offset,Nsc_CCE)==0)
				runs_out = [runs_out;runs(i,:)];
			end
		end
	end
	% if size(runs_out,1) > 1
	% 	[~,perm] = sort(runs_out(:,2)-runs_out(:,1)+1,'descend');
	% 	runs_out = runs_out(perm,:);
	% end
end
