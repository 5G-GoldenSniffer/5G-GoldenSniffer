function example_iq(id)
	if nargin < 1
		id = 1;
	end
	if id<1 || id > 25
		fprintf('supported ids: 1-25\n');
		return
	end

	if id <= 10 || (id>=19 && id <= 22) || id >= 24
		example_iq_fdd(id)
	else
		example_iq_tdd(id)
	end
end
