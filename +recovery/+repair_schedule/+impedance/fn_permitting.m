function permitting_imped = fn_permitting( surge_factor, ...
    system_rapid_permit_trigger, permit_review_time, trunc_pd )
% Simulute permitting time
%
% Parameters
% ----------
% surge_factor: number
%   amplification factor for impedance time based on a post disaster surge
%   in demand for skilled trades and construction supplies
% system_rapid_permit_trigger: logical array [num_reals x num_systems]
%   systems that require any rapid permits for each realization
% permit_review_time: array [num_reals x num_systems]
%   portion of system repair time that requires permitting 
% trunc_pd: matlab normal distribution object
%   standard normal distrubtion, truncated at upper and lower bounds
%
% Returns
% -------
% permitting_imped: array [num_reals x num_sys]
%   Simulated permitting time for each system

%% Define financing distribution parameters
% Full Permit Bounds 
perm_min = 4 * 7; % 4 weeks converted to days
perm_max = 16 * 7; % 16 weeks converted to days

% Find the median permit time for each system
permit_median = min(perm_min + permit_review_time, perm_max);

%% Simulate
% Truncated lognormal distribution (via standard normal simulation)
[num_reals, ~] = size(permit_review_time);
beta = 0.6;
prob_sim = rand(num_reals, 1); % This assumes systems are correlated
x_vals_std_n = icdf(trunc_pd, prob_sim);
permit_time = exp(x_vals_std_n * beta + log(permit_median));

% Only use the simulated values for the realzation and system that
% require permitting
permit_trigger = permit_review_time > 0;
permit_time(~permit_trigger) = 0;

% Multiply by surge factor and save in data structure
permitting_imped = surge_factor * permit_time;

% Add in rapid permitting times
rapid_permit_time = ones(size(system_rapid_permit_trigger)); % 1 day over-the-counter permitting time
rapid_permit_time = surge_factor * rapid_permit_time;
rapid_permit_time(~system_rapid_permit_trigger) = 0;
permitting_imped = max(permitting_imped, rapid_permit_time);

end

