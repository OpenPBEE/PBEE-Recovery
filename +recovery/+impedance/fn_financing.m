function financing_imped = fn_financing( capital_available_ratio, ...
    funding_source, surge_factor, sys_repair_trigger, repair_cost_ratio, ...
    trunc_pd, beta, impeding_factor_medians )
% Simulute financing time
%
% Parameters
% ----------
% capital_available_ratio: number
%   liquidable funding on hand to make repairs immediately after the
%   damaging event. Normalized by building replacment value.
% funding_source: string
%   accepted values: {'sba', 'private', 'insurance'}
%   type of funding source for required funds greater than the capital on
%   hand
% surge_factor: number
%   amplification factor for impedance time based on a post disaster surge
% sys_repair_trigger: logical array [num_reals x num_systems]
%   systems that require repair for each realization
% repair_cost_ratio: array [num_reals x 1]
%   simulated building repair cost; normalized by building replacemnt
%   value.
% trunc_pd: matlab normal distribution object
%   standard normal distrubtion, truncated at upper and lower bounds
% beta: number
%   lognormal standard deviation (dispersion)
% impeding_factor_medians: table
%   median delays for various impeding factors
%
% Returns
% -------
% financing_imped: array [num_reals x num_sys]
%   Simulated financing time for each system

%% Define financing distribution parameters
% Median financing times
finance_medians = ...
    impeding_factor_medians(strcmp(impeding_factor_medians.factor,'financing'),:);

% Required Financing
financing_trigger = repair_cost_ratio > capital_available_ratio;

% Financing Type
switch funding_source
    case 'sba'  % SBA Backed Loans
        filt = strcmp(finance_medians.category,'sba');
        median = finance_medians.time_days(filt) * surge_factor; %days
    case 'private'  % Private loans 
        filt = strcmp(finance_medians.category,'private');
        median = finance_medians.time_days(filt); % days, not affected by surge
    case 'insurance'  % Insurance
        filt = strcmp(finance_medians.category,'insurance');
        median = finance_medians.time_days(filt); % days, not affected by surge
    otherwise 
        error('PBEE_Recovery:RepairSchedule', 'Invalid financing type, "%s", for impedance factor simulation', funding_source)
end

%% Simulate
% Truncated lognormal distribution (via standard normal simulation)
num_reals = length(repair_cost_ratio);
prob_sim = rand(num_reals, 1);
x_vals_std_n = icdf(trunc_pd, prob_sim);
financing_time = exp(x_vals_std_n * beta + log(median));

% Only use realizations that require financing
financing_time(~financing_trigger) = 0;

% Affects all systems that need repair
% Assume impedance always takes a full day
financing_imped = ceil(financing_time .* sys_repair_trigger);


end

