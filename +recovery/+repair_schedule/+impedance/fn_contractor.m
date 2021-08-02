function contractor_mob_imped = fn_contractor( ...
    surge_factor, sys_repair_trigger, system_repair_time, contr_min, contr_max, trunc_pd )
% Simulute contractor mobilization time
%
% Parameters
% ----------
% surge_factor: number
%   amplification factor for impedance time based on a post disaster surge
%   in demand for skilled trades and construction supplies
% sys_repair_trigger: logical array [num_reals x num_systems]
%   systems that require repair for each realization
% permit_review_time: array [num_reals x num_systems]
%   simulatefd repair time of each system in isolation 
% trunc_pd: matlab normal distribution object
%   standard normal distrubtion, truncated at upper and lower bounds
% contr_min: row vector [1 x n_systems]
%   lower bound on the median for each system
% contr_max: row vector [1 x n_systems]
%   upper bound on the median for each system
%
% Returns
% -------
% contractor_mob_imped: array [num_reals x num_sys]
%   Simulated contractor mobilization time for each system

%% Define financing distribution parameters
NDS = sum(sys_repair_trigger,2); % number of damaged systems

contr_median = (1 + (NDS - 1)/8) .* system_repair_time;
contr_median = max(contr_median, contr_min);
contr_median = min(contr_median, contr_max);

%% Simulate
% Truncated lognormal distribution (via standard normal simulation)
[num_reals, ~] = size(system_repair_time);
beta = 0.6;
prob_sim = rand(num_reals, 1); % This assumes systems are correlated
x_vals_std_n = icdf(trunc_pd, prob_sim);
contractor_mob_imped = exp(x_vals_std_n * beta + log(contr_median));

% Only use the simulated values for the realzation and system that
% require permitting
contractor_mob_imped(~sys_repair_trigger) = 0;

% Amplify by the surge factor
contractor_mob_imped = surge_factor * contractor_mob_imped;

end

