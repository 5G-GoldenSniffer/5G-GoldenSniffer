%UNWRAP_QPSK Remove QPSK phase ambiguity for channel estimation
%   Y_CORR = UNWRAP_QPSK(Y) removes the QPSK modulation phase ambiguity
%   from the received symbols for channel estimation purposes.
%
%   Input:
%       Y - Received QPSK symbols (complex vector)
%
%   Output:
%       Y_CORR - Phase-corrected symbols suitable for channel estimation
%
%   The function performs phase unwrapping by rotating all symbols to
%   the first quadrant. This allows direct channel estimation from
%   QPSK-modulated pilots without knowing the transmitted data.
%
%   The correction assumes QPSK constellation points at:
%   (1+j)/sqrt(2), (-1+j)/sqrt(2), (-1-j)/sqrt(2), (1-j)/sqrt(2)
%
%   See also: DMRS_process, DMRS_heuristic

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
function Y_corr = unwrap_QPSK(Y,heuristic)
	if nargin < 2
		heuristic = true;
	end
	if min(size(Y))>1
		error('unwrap_QPSK expects a vector');
	end
	N = numel(Y);
	Y_corr = zeros(size(Y)); %correct the phase using the first symbol as reference
	%so that it lies between pi/4 and -pi/4 (around zero)
	Y_corr(1) = Y(1);
	phi = zeros(size(Y));
	phi(1) = angle(Y_corr(1));
	for i = 2:N
		%phase difference between the i-th actual symbol and the corrected (i-1)-th one
		tmp = angle(Y(i)*conj(Y_corr(i-1)));
		if abs(tmp) > 3*pi/4
			Y_corr(i) = -Y(i); %adjust by 180°
			if tmp < 0
				phi(i) = phi(i-1) + tmp+pi;
			else
				phi(i) = phi(i-1) + tmp-pi;
			end
		elseif tmp < -pi/4
			Y_corr(i) = 1i*Y(i); %adjust by +90°
			phi(i) = phi(i-1) + tmp+pi/2;
		elseif tmp > pi/4
			Y_corr(i) = -1i*Y(i); %adjust by -90°
			phi(i) = phi(i-1) + tmp-pi/2;
		else
			Y_corr(i) = Y(i);
			phi(i) = phi(i-1) + tmp;
		end
	end
	if heuristic
		J_min = inf;
		for i = -2:2
			phi_incr_try = phi(end)-phi(1)+i*pi/2;
			J = 0;
			for n = 1:N
				J = J + min(abs(angle(Y_corr(n)*exp(-1i*(phi(1)+(0:3)*pi/2+phi_incr_try/(N-1)*(n-1))))));
			end
			if J < J_min
				J_min = J;
				i_min = i;
			end
		end
		
		% cf(16)
		% subplot(1,1,1)
		% hold off
		% plot(unwrap(angle(Y_corr)))
		% hold on

		for n = 1:N
			tmp = phi(1)+(phi(end)-phi(1)+i_min*pi/2)*(n-1)/(N-1) - phi(n);
			if abs(tmp) > 3*pi/4
				Y_corr(n) = -Y_corr(n);
			elseif tmp > pi/4
				Y_corr(n) = 1i*Y_corr(n);
			elseif tmp < -pi/4
				Y_corr(n) = -1i*Y_corr(n);
			end
		end
		
		% plot(phi(1)+(phi(end)-phi(1)+i_min*pi/2)/(N-1)*(0:N-1));
		% plot(unwrap(angle(Y_corr)))
		% plot(unwrap(angle(1i*Y_corr)))
		% plot(unwrap(angle(-Y_corr)))
		% plot(unwrap(angle(-1i*Y_corr)))
		
		% tmp = diff(unwrap(angle(Y_corr)));
		% [max_val,max_pos]=max(abs(tmp(1:end-3)+tmp(2:end-2)+tmp(3:end-1)+tmp(4:end)));
		% if max_val > pi/4
			% keyboard
		% end
	end
end
