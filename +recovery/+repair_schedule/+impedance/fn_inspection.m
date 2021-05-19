function inspection_imped = fn_inspection( is_essential_facility, surge_factor, ...
    sys_repair_trigger, inpsection_trigger, trunc_pd )
% Simulute inspection time
%
% Parameters
% ----------
% is_essential_facility: logical
%   is the building deemed essential by the local jurisdiction
% surge_factor: number
%   amplification factor for impedance time based on a post disaster surge
%   in demand for skilled trades and construction supplies
% sys_repair_trigger: logical array [num_reals x num_systems]
%   systems that require repair for each realization
% inpsection_trigger: logical array [num_reals x 1]
%   defines which realizations require inspection
% trunc_pd: matlab normal distribution object
%   standard normal distrubtion, truncated at upper and lower bounds
%
% Returns
% -------
% inspection_imped: array [num_reals x num_sys]
%   Simulated inspection time for each system

%% Define inspection distribtuion parameters
if is_essential_facility
    median = 2;
else
    median = 7;
end
beta = 0.6;

%% Simulate 
% Truncated lognormal distribution
num_reals = length(inpsection_trigger);
prob_sim = rand(num_reals, 1);
x_vals_std_n = icdf(trunc_pd, prob_sim);
inspection_time = exp(x_vals_std_n * beta + log(median));

% Only use realizations that require inpsection
inspection_time(~inpsection_trigger) = 0;

% Affects all systems that need repair
inspection_imped = surge_factor * inspection_time .* sys_repair_trigger;

end

