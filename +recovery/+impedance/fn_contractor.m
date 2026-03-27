function contractor_mob_imped = fn_contractor( num_reals, surge_factor, ...
    sys_repair_trigger, trunc_pd, contractor_options )
% Simulute contractor mobilization time
%
% Parameters
% ----------
% num_sys: int
%   number of building systems considered in the assessment
% num_reals: int
%   number of Monte Carlo simulations assessed
% surge_factor: number
%   amplification factor for impedance time based on a post disaster surge
%   in demand for skilled trades and construction supplies
% sys_repair_trigger: logical array [num_reals x num_systems]
%   systems that require repair for each realization
% trunc_pd: matlab normal distribution object
%   standard normal distrubtion, truncated at upper and lower bounds
% contractor_options: struct
%   various options that controll the contracting impedance time
%
% Returns
% -------
% contractor_mob_imped: array [num_reals x num_sys]
%   Simulated contractor mobilization time for each system

%% Define contractor distribution parameters
switch contractor_options.contractor_relationship
    case 'retainer'
        med = surge_factor * contractor_options.contractor_retainer_time;
        beta = 0.4;
    case 'good'
        med = (1 + 0.5*(surge_factor-1)) * 3;
        beta = 0.4;
    case 'none'
        med = surge_factor * 42;
        beta = 0.8;
    otherwise
        error('PBEE_Recovery:RepairSchedule', 'Invalid contractor relationship type, "%s", for impedance factor simulation', contractor_relationship)
end

%% Set median for each realization
contr_med = med * ones(num_reals,1);

%% Simulate Impedance Time
prob_sim = rand(num_reals, 1); % This assumes systems are correlated
x_vals_std_n = icdf(trunc_pd, prob_sim);% Truncated lognormal distribution (via standard normal simulation)
contractor_mob_imped = exp(x_vals_std_n * beta + log(contr_med));

% Only use the simulated values for the realzation and system that
% require permitting
contractor_mob_imped = contractor_mob_imped .* sys_repair_trigger;

% Amplify by the surge factor
% Assume impedance always takes a full day
contractor_mob_imped = ceil(contractor_mob_imped);

end

