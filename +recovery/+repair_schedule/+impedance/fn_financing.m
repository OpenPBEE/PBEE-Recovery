function financing_imped = fn_financing( ...
    capital_available_ratio, funding_source, sys_repair_trigger, repair_cost_ratio, trunc_pd )
% Simulute financing time
%
% Parameters
% ----------
% capital_available_ratio: number
%   liquidable funding on hand to make repairs immediately after the
%   damaging event. Normalized by building replacment value.
% funding_source: string
%   accepted values: {'pre_arranged', 'sba', 'private', 'insurance'}
%   type of funding source for required funds greater than the capital on
%   hand
% sys_repair_trigger: logical array [num_reals x num_systems]
%   systems that require repair for each realization
% repair_cost: array [num_reals x 1]
%   simulated building repair cost; normalized by building replacemnt
%   value.
% trunc_pd: matlab normal distribution object
%   standard normal distrubtion, truncated at upper and lower bounds
%
% Returns
% -------
% financing_imped: array [num_reals x num_sys]
%   Simulated financing time for each system

%% Define financing distribution parameters
% Required Financing
financing_trigger = repair_cost_ratio > capital_available_ratio;
loan_ratio = max(repair_cost_ratio - capital_available_ratio, 0);

% Financing Type
switch funding_source
    case 'pre_arranged' % Pre-arranged line of credit
        median = 7; 
    case 'sba'  % SBA Backed Loans
        median = (6*loan_ratio + 6)*30; % calc in months, multiplied by 30 to put into days
    case 'private'  % Private loans 
        median = (6*loan_ratio + 6)*7; % calc in weeks, multiplied by 7 to put into days
    case 'insurance'  % Insurance (same as private
        median = (6*loan_ratio + 6)*7; % calc in weeks, multiplied by 7 to put into days
    otherwise 
        error('SPEX:RecoveryError', 'Invalid financing type, "%s", for impedance factor simulation', impedance_options.mitigation.funding_source)
end

% Simulate delay
beta = 0.6;

%% Simulate
% Truncated lognormal distribution (via standard normal simulation)
num_reals = length(repair_cost_ratio);
prob_sim = rand(num_reals, 1);
x_vals_std_n = icdf(trunc_pd, prob_sim);
financing_time = exp(x_vals_std_n * beta + log(median));

% Only use realizations that require financing
financing_time(~financing_trigger) = 0;

% Affects all systems that need repair
financing_imped = financing_time .* sys_repair_trigger;


end

