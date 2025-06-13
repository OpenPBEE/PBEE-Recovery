function [ tmp_repair_complete_day ] = fn_simulate_tmp_repair_times( damage, inpsection_complete_day, beta_temp, surge_factor )
% Simulate temporary repair times for each componet (where applicable) per
% realization
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage and loss data for each component in the building
% inpsection_complete_day: array [num_reals x 1]
%   simulated day after the earthquake that inpection in completed 
% beta_temp: number
%   lognormal standard deviation defining the uncertianty in all temporary
%   repair times
% surge_factor: number
%   amplification factor for temporary repair time based on a post disaster surge
%   in demand for skilled trades and construction supplies

%
% Returns
% -------
% tmp_repair_complete_day: array [num_reals x num_comp]
%   contains the day (after the earthquake) the temporary repair time is 
%   resolved per damage state damage and realization. Inf represents that
%   there is not temporary repair time available for a given components
%   damage.
%
% Notes
% -----
% Currently simulate tmp repair times independently between components but correlated between stories

%% Initialize Parameters
num_tenant_units = length(damage.tenant_units);
[num_reals, num_comps] = size(damage.tenant_units{1}.qnt_damaged);

% Create basic trucated standard normal distribution for later simulation
pd = makedist('normal','mu',0,'sigma',1);
th_low = -2; % Truncate below -2 standard deviations
th_high = 2; % Truncate above +2 standard deviations
trunc_pd = truncate(pd,th_low,th_high);

% Determine which damage states require shoring
shoring_filt = damage.comp_ds_table.requires_shoring';
tmp_repair_filt = damage.comp_ds_table.tmp_fix' & ~damage.comp_ds_table.requires_shoring';

%% Go through damage and determine which relization have shoring repairs
is_shoring_damage = zeros(num_reals,1);
for tu = 1:num_tenant_units
    is_shoring_damage = is_shoring_damage | max(damage.tenant_units{tu}.qnt_damaged .* shoring_filt,[],2);
end

%% Simulate temporary repair times
% simulate shoring time (assumes correlated throughout whole building)
shoring_time_med = max(surge_factor * damage.comp_ds_table.tmp_fix_time' .* shoring_filt); % median shoring time for the building is the max among all components
prob_sim = rand(num_reals, 1); % assumes components are correlated
x_vals_std_n = icdf(trunc_pd, prob_sim); % Truncated lognormal distribution (via standard normal simulation)
sim_shoring_time = ceil(exp(x_vals_std_n * beta_temp + log(shoring_time_med)));% assume it takes whole days to temporarily fix things

% Find the time to perform all shoring in the building
building_shoring_time = sim_shoring_time .* is_shoring_damage;

% Simulate temp repair and clean up time
% assumes tmp repair times are independent between components but correlated between stories
tmp_repair_time = surge_factor * damage.comp_ds_table.tmp_fix_time' .* tmp_repair_filt;
tmp_repair_time(tmp_repair_time == 0) = inf; % convert zero day times to inf to not affect building repair time logic
prob_sim = rand(num_reals, num_comps); % This assumes components are indepednant
x_vals_std_n = icdf(trunc_pd, prob_sim); % Truncated lognormal distribution (via standard normal simulation)
sim_tmp_repair_time = ceil(exp(x_vals_std_n * beta_temp + log(tmp_repair_time)));% assume it takes whole days to temporarily fix things

% Combine to find total temp repair complete data for each component damage
% state (all stories and tenant units)
% clean up occurs after all shoring is complete which occurs after
% inspection is complete
tmp_repair_complete_day = inpsection_complete_day + ...
                          building_shoring_time + ...
                          sim_tmp_repair_time; % temp repairs dont start until after inspection

end

