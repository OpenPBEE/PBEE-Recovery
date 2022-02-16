function [ eng_mob_imped, eng_design_imped ] = fn_engineering( ...
    damage, num_sys, num_reals, repair_cost_ratio, building_value, ...
    surge_factor, is_engineer_on_retainer, user_options, design_min, ...
    design_max, trunc_pd, beta, impeding_factor_medians )
% Simulute permitting time
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage and loss data for each component in the building
% num_sys: int
%   number of building systems considered in the assessment
% num_reals: int
%   number of Monte Carlo simulations assessed
% repair_cost_ratio: array [num_reals x 1]
%   simulated building repair cost; normalized by building replacemnt
%   value.
% building_value: number
%   replacment value of building, in USD, non including land
% surge_factor: number
%   amplification factor for impedance time based on a post disaster surge
%   in demand for skilled trades and construction supplies
% is_engineer_on_retainer: logical
%   is there a pre-arranged agreement with an engineer for priorization of
%   redesign
% user_options: struct
%   contains paramters of system design time function, set by user
% design_min: row vector [1 x n_systems]
%   lower bound on the median for each system
% design_max: row vector [1 x n_systems]
%   upper bound on the median for each system
% trunc_pd: matlab normal distribution object
%   standard normal distrubtion, truncated at upper and lower bounds
% beta: number
%   lognormal standard deviation (dispersion)
% impeding_factor_medians: table
%   median delays for various impeding factors
%
% Returns
% -------
% eng_mob_imped: array [num_reals x num_sys]
%   Simulated enginering mobilization time for each system
% eng_design_imped: array [num_reals x num_sys]
%   Simulated enginering design time for each system

% Notes
% ------
% assumes engineering mobilization and re-design time are independant, but
% are correlated between each system. In other words, you will have the same 
% designers for the structural, stairs, exterior, and whatever other systems 
% need design time, but the time it takes to spin up an engineer is not
% related to the time it takes for them to complete the re-design.


%% Parse damage object to figure out when redesign is requried
redesign_filt = damage.comp_ds_info.redesign == 1;
redesign_trigger = zeros(num_reals, num_sys);
for sys = 1:num_sys
    sys_filt = damage.comp_ds_info.system == sys; 
    for tu = 1:length(damage.tenant_units)
        is_damaged = damage.tenant_units{tu}.qnt_damaged > 0;
        redesign_trigger(:,sys) = max( redesign_trigger(:,sys), ...
            max(is_damaged .* (sys_filt & redesign_filt), [], 2) ...
        );
    end
end

%% Calculate System Design Time
RC_total = repair_cost_ratio .* building_value;
SDT = RC_total * user_options.f / ...
    (user_options.r * user_options.t * user_options.w);

%% Engineering Mobilization Time
% Mobilization medians
eng_mob_medians = ...
    impeding_factor_medians(strcmp(impeding_factor_medians.factor,'engineering mobilization'),:);

if is_engineer_on_retainer
    filt = strcmp(eng_mob_medians.category,'retainer');
else
    filt = strcmp(eng_mob_medians.category,'default');
end
median_eng_mob = surge_factor * eng_mob_medians.time_days(filt); % days

% Truncated lognormal distribution (via standard normal simulation)
prob_sim = rand(num_reals, 1); % This assumes systems are correlated
x_vals_std_n = icdf(trunc_pd, prob_sim);
eng_mob_time = exp(x_vals_std_n * beta + log(median_eng_mob));
% Assume impedance always takes a full day
eng_mob_imped = ceil(eng_mob_time .* redesign_trigger);

%% Engineering Design Time
design_med = min(max(SDT, design_min), design_max);

% Truncated lognormal distribution (via standard normal simulation)
% Assumes engineering design time is independant of mobilization time
beta = 0.6;
prob_sim = rand(num_reals,1); % This assumes systems are correlated
x_vals_std_n = icdf(trunc_pd ,prob_sim);
eng_design_time = exp(x_vals_std_n * beta + log(design_med));
% Assume impedance always takes a full day
eng_design_imped = ceil(eng_design_time .* redesign_trigger);

end

