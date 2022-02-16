function permitting_imped = fn_permitting( damage, num_sys, num_reals, ...
    surge_factor, trunc_pd, beta, impeding_factor_medians )
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
% surge_factor: number
%   amplification factor for impedance time based on a post disaster surge
%   in demand for skilled trades and construction supplies
% trunc_pd: matlab normal distribution object
%   standard normal distrubtion, truncated at upper and lower bounds
% beta: number
%   lognormal standard deviation (dispersion)
% impeding_factor_medians: table
%   median delays for various impeding factors
%
% Returns
% -------
% permitting_imped: array [num_reals x num_sys]
%   Simulated permitting time for each system

%% Define permitting distribution parameters
% Find the median permit time for each system
permit_medians = ...
    impeding_factor_medians(strcmp(impeding_factor_medians.factor,'permitting'),:);
permitting_surge = 1 + (surge_factor-1)/4; % permitting is proportional to, but not directly scaled by surge

% Full Permits
filt = strcmp(permit_medians.category,'full');
full_permit_median = permit_medians.time_days(filt) * permitting_surge; % days

% Rapid Permits
filt = strcmp(permit_medians.category,'rapid');
rapid_permit_median = permit_medians.time_days(filt); % days

%% Parse damage object to figure out when permits are requried
rapid_permit = strcmp(damage.comp_ds_info.permit_type, 'rapid');
system_rapid_permit_trigger = zeros(num_reals, num_sys);
full_permiting = strcmp(damage.comp_ds_info.permit_type, 'full');
system_full_permit_trigger = zeros(num_reals, num_sys);
for sys = 1:num_sys
    sys_filt = damage.comp_ds_info.system == sys; 
    for tu = 1:length(damage.tenant_units)
        is_damaged = damage.tenant_units{tu}.qnt_damaged > 0;
        
        % Track if any damage exists that requires rapid permit per system
        system_rapid_permit_trigger(:,sys) = max( ...
            system_rapid_permit_trigger(:,sys), ...
            max(is_damaged .* (sys_filt & rapid_permit), [], 2) ...
        );
    
        % Track if any damage exists that requires full permit per system
        system_full_permit_trigger(:,sys) = max( ...
            system_full_permit_trigger(:,sys), ...
            max(is_damaged .* (sys_filt & full_permiting), [], 2) ...
        );
    end
end

%% Simulate
% Rapid Permits
prob_sim = rand(num_reals, 1); % This assumes systems are correlated
x_vals_std_n = icdf(trunc_pd, prob_sim); % Truncated lognormal distribution (via standard normal simulation)
rapid_permit_time = exp(x_vals_std_n * beta + log(rapid_permit_median));
rapid_permit_time_per_system = rapid_permit_time .* system_rapid_permit_trigger;

% Full Permits - simulated times are independent of rapid permit times
prob_sim = rand(num_reals, 1); % This assumes systems are correlated
x_vals_std_n = icdf(trunc_pd, prob_sim);% Truncated lognormal distribution (via standard normal simulation)
full_permit_time = exp(x_vals_std_n * beta + log(full_permit_median));
full_permit_time_per_system = full_permit_time .* system_full_permit_trigger;

% Take the max of full and rapid permit times per system
% Assume impedance always takes a full day
permitting_imped = ceil(max(rapid_permit_time_per_system, full_permit_time_per_system));

end

