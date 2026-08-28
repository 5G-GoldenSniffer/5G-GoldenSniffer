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
function dci = blind_search_for_DCIs(Y,grid_ofs,Nsc,CORESET0_offset,TDD_pattern,max_duration,ncellid,FIGURES)
	Nsymb_slot = 14;
	Nslot_frame = size(Y,2)/Nsymb_slot;
	Nsc_REG = 12;
	Nsc_CCE = 6*Nsc_REG;
	sc_period_DMRS=4;
	
	persistent Grnti b_tilde0rnti EArnti EBrnti N_DCI_min N_DCI_max_AL DCI_sizes DCI_count DCI_size_order
	if isempty(Grnti)
		% DCI decoding matrices, will be generated if not found
		[Grnti,b_tilde0rnti,EArnti,EBrnti,N_DCI_min,N_DCI_max_AL] = make_GErnti_matrices;

		% Track most frequent DCI sizes for optimization
		DCI_sizes = N_DCI_min:max(N_DCI_max_AL);
		DCI_count = zeros(1,numel(DCI_sizes));
		[~,DCI_size_order] = sort(DCI_count,'descend');
	end
	dci = struct([]);
	dci_count = 0;

	% search REGs in the first symbols of every slot (PDCCH candidates)
	% with live captures, these will contain interference from
	% other cells (or beams of the same cell)
	H_est_ambiguous = zeros(Nsc,max_duration);
	for slot = 0:Nslot_frame-1
		if TDD_pattern(1+mod(slot,10))==1 % UL slots
			continue
		end

		% perform power-based detection of REGs in the first symbols
		% of a slot
		sym = slot*Nsymb_slot;
		[duration,~,RE_busy_runs] = ...
			power_detect_REGs(Y(grid_ofs+(1:Nsc),sym+(1:max_duration)),CORESET0_offset);
		Nruns = size(RE_busy_runs,1);
		if Nruns == 0
			continue
		end
		if bitand(FIGURES,0x0100)
			tmp = sum(abs(Y(grid_ofs+(1:Nsc),sym+(1:duration))).^2,2);
			tmp_max = max(tmp);
			currentfigure(9)
			hold off
			semilogy(0:Nsc-1,tmp)
			hold on
			for irun = 1:Nruns
				semilogy([RE_busy_runs(irun,1)*[1 1],RE_busy_runs(irun,2)*[1 1]]-1,1.2*tmp_max*[0.01 1 1 0.01],'r');
			end
			xlim([0 Nsc-1])
			xlabel('subcarrier')
			ylabel('|Y|^2')
			title('Power distribution in the PDCCH and detected runs');
			drawnow
		end

		% PDCCH channel estimates (with a multiple of pi/2 ambiguity) can be obtained
		% through phase unwrapping.
		for irun = 1:Nruns
			H_est_ambiguous(RE_busy_runs(irun,1):RE_busy_runs(irun,2),1) = ...
				unwrap_QPSK(Y(grid_ofs+(RE_busy_runs(irun,1):RE_busy_runs(irun,2)),sym+1));
			for l = 2:duration
				H_est_tmp = unwrap_QPSK(Y(grid_ofs+(RE_busy_runs(irun,1):RE_busy_runs(irun,2)),sym+l));
				% the phases of consecutive symbols should be almost equal
				rho = H_est_tmp\H_est_ambiguous(RE_busy_runs(irun,1):RE_busy_runs(irun,2),1);
				H_est_tmp = H_est_tmp * exp(1i*pi/2*round(angle(rho)*2/pi));
				H_est_ambiguous(RE_busy_runs(irun,1):RE_busy_runs(irun,2),l) = H_est_tmp;
			end
		end

		% find the maximum possible AL given the set of runs
		log2AL = floor(log2(sum(RE_busy_runs(:,2)-RE_busy_runs(:,1)+1)*duration/Nsc_CCE));
		while log2AL >= 0

			[cand,Ncand] = enum_candidates(RE_busy_runs,duration,log2AL);
			if Ncand == 0
				log2AL = log2AL - 1;
				continue
			end
			icand = 0;
			while icand+1 <= Ncand
				icand = icand+1;
				dci_found = false;

				% interleaved DCIs have more than one run
				runs_in_cand = size(cand{icand},1);
				NID_est_cand = -1*ones(runs_in_cand);

				% accumulate equalized REs in this buffer
				nYeq = round(sum((cand{icand}(:,2)-cand{icand}(:,1)+1))*3/4); % (sc_period_DMRS-1)/sc_period_DMRS
				iYeq = 0;
				Yeq = zeros(nYeq,duration);

				for irc = 1:runs_in_cand

					% if the number of DM-RS subcarriers is sufficient, use the direct method
					if cand{icand}(irc,2)-cand{icand}(irc,1)+1 >= Nsc_CCE
						Ydci = Y(grid_ofs+(cand{icand}(irc,1):cand{icand}(irc,2)),sym+(1:duration));
						C_ambiguous = Ydci./H_est_ambiguous(cand{icand}(irc,1):cand{icand}(irc,2),1:duration);
						for l = 0:duration-1
							[is_ok,c_init_DMRS,C_est_DMRS] = DMRS_process(C_ambiguous(2:4:end,1+l),cand{icand}(irc,1)-1,sc_period_DMRS);
							if is_ok
								[n_b_found,NID_dciDMRS] = c_init_PDCCH_DMRS_decode(c_init_DMRS,2^17*(Nsymb_slot*slot+l+1));
								found_in_CORESET0 = false || CORESET0_offset == 0;
							end
							if ~is_ok || ~n_b_found
								[is_ok,c_init_DMRS,C_est_DMRS] = DMRS_process(C_ambiguous(2:4:end,1+l),cand{icand}(irc,1)-1-CORESET0_offset,sc_period_DMRS);
								if is_ok
									[n_b_found,NID_dciDMRS] = c_init_PDCCH_DMRS_decode(c_init_DMRS,2^17*(Nsymb_slot*slot+l+1));
									found_in_CORESET0 = true;
								end
							end
							if is_ok && n_b_found
								NID_est_cand(irc) = NID_dciDMRS;
								break % l
							end
						end
						if is_ok && n_b_found
							% equalize and detect the DCI
							Yeq(iYeq+(1:size(Ydci,1)*3/4),:) = PDCCH_equalize(Ydci,C_est_DMRS,l);
							iYeq = iYeq + size(Ydci,1)*3/4;
						end
					elseif (cand{icand}(irc,2)-cand{icand}(irc,1)+1)*duration >= Nsc_CCE

						% not enough subcarriers to use the direct method, use the matrix-based method
						% color='y';

						Ydci = Y(grid_ofs+(cand{icand}(irc,1):cand{icand}(irc,2)),sym+(1:duration));
						C_ambiguous = Ydci./H_est_ambiguous(cand{icand}(irc,1):cand{icand}(irc,2),1:duration);

						[is_ok,NID_dciDMRS,C_est_DMRS] = PDCCH_DMRS_solve_underdet(C_ambiguous(2:4:end,:),cand{icand}(irc,1)-1,2^17*(Nsymb_slot*slot+1));
						if is_ok
							found_in_CORESET0 = false || CORESET0_offset==0;
						else
							[is_ok,NID_dciDMRS,C_est_DMRS] = PDCCH_DMRS_solve_underdet(C_ambiguous(2:4:end,:),cand{icand}(irc,1)-1-CORESET0_offset,2^17*(Nsymb_slot*slot+1));
							if is_ok
								found_in_CORESET0 = true;
							end
						end
						if is_ok
							NID_est_cand(irc) = NID_dciDMRS;

							% equalize and append the DCI data to the buffer
							Yeq(iYeq+(1:size(Ydci,1)*3/4),:) = PDCCH_equalize(Ydci,C_est_DMRS(:,1),0);
							iYeq = iYeq + size(Ydci,1)*3/4;
						end
					end
				end
				NID_est = unique(NID_est_cand(1:runs_in_cand));
				if iYeq == nYeq && isscalar(NID_est)
					b_tilde = zeros(1,2*numel(Yeq)); % QPSK
					b_tilde(1:2:end) = real(Yeq)<0;
					b_tilde(2:2:end) = imag(Yeq)<0;
					for N_DCI = DCI_sizes(DCI_size_order)
						[RNTI_found,xr_est,RNTI_CRC] = DCIdecode_try(b_tilde,N_DCI,Grnti,b_tilde0rnti,EArnti,EBrnti,ncellid,NID_est,N_DCI_max_AL);
						if ~RNTI_found
							continue
						end
						if bitand(FIGURES,0x0200)
							currentfigure(10)
							hold off
							plot(Yeq(:),'.')
							xlabel('I')
							ylabel('Q')
							axis equal
							xlim([-1.5 1.5])
							ylim([-1.5 1.5])
							title('PDCCH equalized REs');
							drawnow
						end
						DCI_count(N_DCI-N_DCI_min+1) = DCI_count(N_DCI-N_DCI_min+1) + 1;
						[~,DCI_size_order] = sort(DCI_count,'descend');
						% add the dci to the output
						dci_found = true;
						dci_count = dci_count+1;
						dci(dci_count).slot = slot;
						dci(dci_count).duration = duration;
						dci(dci_count).AL = 2^log2AL;
						dci(dci_count).cand = cand{icand};
						dci(dci_count).CORESET0 = found_in_CORESET0;
						dci(dci_count).NID = NID_est;
						dci(dci_count).RNTI = RNTI_CRC;
						dci(dci_count).bits = xr_est(1:N_DCI);
						break % N_DCI
					end
					if dci_found
						% update RE_busy_runs and candidates
						[RE_busy_runs,cand,Ncand] = update_candidates(RE_busy_runs,cand,icand,duration,log2AL);
						log2AL = 1+floor(log2(sum(RE_busy_runs(:,2)-RE_busy_runs(:,1)+1)*duration/Nsc_CCE));
						icand = 0;
					end
				end
			end
			log2AL = log2AL-1;
		end
	end
end
