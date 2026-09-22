function example_iq(id,run)
	if nargin < 1
		id = 1;
	end
	if id < 1 || id > 25
		fprintf('supported ids: 1-25\n');
		return
	end
    if nargin < 2
        run = 0;
    end
	if run < 0 || run > 2
		fprintf('supported runs: 0-2\n');
		return
	end

	if id <= 10 || (id>=19 && id <= 22) || id >= 24
		example_iq_fdd(id,run)
	else
		example_iq_tdd(id,run)
	end
end
