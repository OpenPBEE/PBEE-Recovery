function inspection_imped = fn_inspection( is_essential_facility, ...
    is_borp_equivalent, surge_factor, sys_repair_trigger, ...
    inpsection_trigger, trunc_pd, beta, impeding_factor_medians )
% Simulute inspection time
%
% Parameters
% ----------
% is_essential_facility: logical
%   is the building deemed essential by the local jurisdiction
% is_borp_equivalent: logical
%   does the building have an inspector on retainer (BORP equivalent)
% surge_factor: number
%   amplification factor for impedance time based on a post disaster surge
%   in demand for skilled trades and construction supplies
% sys_repair_trigger: logical array [num_reals x num_systems]
%   systems that require repair for each realization
% inpsection_trigger: logical array [num_reals x 1]
%   defines which realizations require inspection
% trunc_pd: matlab normal distribution object
%   standard normal distrubtion, truncated at upper and lower bounds
% beta: number
%   lognormal standard deviation (dispersion)
% impeding_factor_medians: table
%   median delays for various impeding factors
%
% Returns
% -------
% inspection_imped: array [num_reals x num_sys]
%   Simulated inspection time for each system

%% Define inspection distribtuion parameters
inspection_medians = ...
    impeding_factor_medians(strcmp(impeding_factor_medians.factor,'inspection'),:);
    
if is_borp_equivalent
    filt = strcmp(inspection_medians.category,'borp');
    % BORP equivalent is not affected by surge
    median = inspection_medians.time_days(filt); 
elseif is_essential_facility
    filt = strcmp(inspection_medians.category,'essential');
    median = inspection_medians.time_days(filt) * surge_factor;
else
    filt = strcmp(inspection_medians.category,'default');
    median = inspection_medians.time_days(filt) * surge_factor;
end

%% Simulate 
% Truncated lognormal distribution
num_reals = length(inpsection_trigger);
prob_sim = rand(num_reals, 1);
x_vals_std_n = icdf(trunc_pd, prob_sim);
inspection_time = exp(x_vals_std_n * beta + log(median));

% Only use realizations that require inpsection
inspection_time(~inpsection_trigger) = 0;

% Affects all systems that need repair
% Assume impedance always takes a full day
inspection_imped = ceil(inspection_time .* sys_repair_trigger);

end

