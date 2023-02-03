function [impeding_factors] = main_impeding_factors(damage, ...
    impedance_options, repair_cost_ratio_total, repair_cost_ratio_engineering, ...
    inpsection_trigger, systems, tmp_repair_class, building_value, impeding_factor_medians)
% Calculate ATC-138 impeding times for each system given simulation of damage
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage and loss data for each component in the building
% impedance_options: struct
%   general impedance assessment user inputs such as mitigation factors
% repair_cost_ratio_total: array [num_reals x 1]
%   total repair cost per realization normalized by building replacement
%   value
% repair_cost_ratio_engineering: array [num_reals x 1]
%   repair cost per realization that is used for engineering impedance (structural/stairs/envelope)
% inpsection_trigger: logical array [num_reals x 1]
%   defines which realizations require inspection
% num_stories: int
%   Total number of building stories
% systems: table
%   data table containing information about each system's attributes
% building_value: number
%   The replacement value of the building, in USD
% impeding_factor_medians: table
%   median delays for various impeding factors
%
% Returns
% -------
% impedingFactors.time_sys: array [num_reals x num_sys]
%   Simulated total impeding time for each system
% impedingFactors.breakdown: struct
%   feilds: 'inspection', 'financing', 'eng_mob', 'design', 'permitting', 'contractor_mob'
%   The simulated start day and complete day for each impeding factor,
%   broken down per system where applicable
%   
%
% Notes
% -----
% Correlation: Assuming factor-to-factor simulations are independent, but
% within a given factor, simulated system impedance time is fully
% correlated


%% Initial Setup
% Import packages
import recovery.impedance.fn_contractor
import recovery.impedance.fn_engineering
import recovery.impedance.fn_financing
import recovery.impedance.fn_inspection
import recovery.impedance.fn_permitting
import recovery.impedance.fn_default_surge_factor

% Initialize parameters
num_reals = length(inpsection_trigger);
num_sys = height(systems);

% Pre-allocate each type of impedance
duration.inspection = zeros(num_reals, num_sys);
duration.financing = zeros(num_reals, num_sys);
duration.permit_rapid = zeros(num_reals, num_sys);
duration.permit_full = zeros(num_reals, num_sys);
duration.contractor_mob = zeros(num_reals, num_sys);
duration.eng_mob = zeros(num_reals, num_sys);
duration.design = zeros(num_reals, num_sys);
duration.long_lead = zeros(num_reals, num_sys);

% Create basic trucated standard normal distribution for later simulation
pd = makedist('normal','mu',0,'sigma',1);
th_low = -impedance_options.impedance_truncation;
th_high = impedance_options.impedance_truncation;
trunc_pd = truncate(pd,th_low,th_high);
beta = impedance_options.impedance_beta;

%% Calculate Demand Surge (if applicble)
if impedance_options.demand_surge.include_surge
    surge_factor = fn_default_surge_factor( ...
        impedance_options.demand_surge.is_dense_urban_area, ...
        impedance_options.demand_surge.site_pga, ...
        impedance_options.demand_surge.pga_de ...
    );
else
    surge_factor = 1;
end
    
%% Parse through damage to determine which systems require repair
rapid_permit_filt = strcmp(damage.comp_ds_table.permit_type', 'rapid');
full_permiting_filt = strcmp(damage.comp_ds_table.permit_type', 'full');
redesign_filt = damage.comp_ds_table.redesign' == 1;

sys_repair_trigger.any = zeros(num_reals, num_sys);
sys_repair_trigger.rapid_permit = zeros(num_reals, num_sys);
sys_repair_trigger.full_permit = zeros(num_reals, num_sys);
sys_repair_trigger.redesign = zeros(num_reals, num_sys);
for sys = 1:num_sys
    sys_filt = damage.comp_ds_table.system' == sys; 
    for tu = 1:length(damage.tenant_units)
        is_damaged = damage.tenant_units{tu}.qnt_damaged > 0 & damage.tenant_units{tu}.worker_days > 0; % There is damage that needs to be fixed
        % Track if any damage exists that requires repair (assumes all
        % damage requires repair)
        sys_repair_trigger.any(:,sys) = max( ...
            sys_repair_trigger.any(:,sys), ...
            max(is_damaged .* sys_filt, [], 2) ...
        );
        
        % Track if any damage exists that requires rapid permit per system
        sys_repair_trigger.rapid_permit(:,sys) = max( ...
            sys_repair_trigger.rapid_permit(:,sys), ...
            max(is_damaged .* (sys_filt & rapid_permit_filt), [], 2) ...
        );
    
        % Track if any damage exists that requires full permit per system
        sys_repair_trigger.full_permit(:,sys) = max( ...
            sys_repair_trigger.full_permit(:,sys), ...
            max(is_damaged .* (sys_filt & full_permiting_filt), [], 2) ...
        );
    
        % Track if any systems require redesign
        sys_repair_trigger.redesign(:,sys) = max( ...
            sys_repair_trigger.redesign(:,sys), ...
            max(is_damaged .* (sys_filt & redesign_filt), [], 2) ...
        );
    end
end

%% Simulate impedance time for each impedance factor 
if impedance_options.include_impedance.inspection
    duration.inspection = fn_inspection( ...
        impedance_options.mitigation.is_essential_facility, ...
        impedance_options.mitigation.is_borp_equivalent, ...
        surge_factor, sys_repair_trigger.any, ...
        inpsection_trigger, trunc_pd, beta, impeding_factor_medians );
end

if impedance_options.include_impedance.financing
    duration.financing = fn_financing( ...
        impedance_options.mitigation.capital_available_ratio, ...
        impedance_options.mitigation.funding_source, ...
        surge_factor, sys_repair_trigger.any, ...
        repair_cost_ratio_total, trunc_pd, beta, impeding_factor_medians );
end

if impedance_options.include_impedance.permitting
    [duration.permit_rapid, duration.permit_full ]= fn_permitting( ...
        num_reals, sys_repair_trigger, trunc_pd, beta, impeding_factor_medians );
end

if impedance_options.include_impedance.contractor
    duration.contractor_mob = fn_contractor( num_reals, surge_factor, ...
        sys_repair_trigger.any, trunc_pd, impedance_options.mitigation );
end

if impedance_options.include_impedance.engineering
    [ duration.eng_mob, duration.design ] = fn_engineering( num_reals, ...
        repair_cost_ratio_engineering, building_value, surge_factor, ...
        sys_repair_trigger.redesign, ...
        impedance_options.mitigation.is_engineer_on_retainer, ...
        impedance_options.system_design_time, ...
        impedance_options.eng_design_min_days', ...
        impedance_options.eng_design_max_days', ...
        trunc_pd, beta, impeding_factor_medians);
end

if impedance_options.include_impedance.long_lead
    for sys = 1:num_sys
        sys_filt = damage.comp_ds_table.system' == sys; 
        
        % Simulate long lead times. Assume long lead times are correlated among
        % all components within the system, but independant between systems
        prob_sim = rand(num_reals, 1);
        x_vals_std_n = icdf(trunc_pd, prob_sim);% Truncated lognormal distribution (via standard normal simulation)
        sim_long_lead = exp(x_vals_std_n * beta + log(damage.comp_ds_table.long_lead_time'));
        
        for tu = 1:length(damage.tenant_units)
            is_damaged = damage.tenant_units{tu}.qnt_damaged > 0 & damage.tenant_units{tu}.worker_days > 0;
            
            % Track if any damage exists that requires repair (assumes all
            % damage requires repair). The long lead time for the system is
            % the max long lead time for any component within the system
            duration.long_lead(:,sys) = max( ...
                duration.long_lead(:,sys), ...
                max(is_damaged .* sys_filt .* sim_long_lead, [], 2) ...
            );
        end
    end
    
end

%% Aggregate experienced impedance time for each system/sequence and realization 
% Figure out when each impeding factor finishes
start_day.inspection = zeros(num_reals,num_sys);
complete_day.inspection = duration.inspection;

start_day.financing = complete_day.inspection;
complete_day.financing = start_day.financing + duration.financing;

start_day.eng_mob = max(complete_day.inspection,start_day.financing);
complete_day.eng_mob = start_day.eng_mob + duration.eng_mob;

start_day.design = complete_day.eng_mob;
complete_day.design = start_day.design + duration.design;

start_day.permit_rapid = complete_day.design;
complete_day.permit_rapid = start_day.permit_rapid + duration.permit_rapid;

start_day.permit_full = complete_day.design;
complete_day.permit_full = start_day.permit_full + duration.permit_full;

start_day.contractor_mob = max(complete_day.inspection,start_day.financing);
complete_day.contractor_mob = start_day.contractor_mob + duration.contractor_mob;

start_day.long_lead = max(complete_day.inspection,start_day.financing);
complete_day.long_lead = start_day.long_lead + duration.long_lead;

% Combine all impedance factors by system
impede_factors = fieldnames(complete_day);
impeding_factors.time_sys = 0;
for i = 1:length(impede_factors)
    impeding_factors.time_sys = max(impeding_factors.time_sys,...
        complete_day.(impede_factors{i}));
end
    
%% Simulate Impeding Factors for Temporary Repairs
% Determine median times for each system
switch impedance_options.mitigation.contractor_relationship
    case 'retainer'
        temp_impede_med = surge_factor*tmp_repair_class.impeding_time'; % days
    case 'good'
        temp_impede_med = surge_factor*tmp_repair_class.impeding_time'; % days
    case 'none'
        temp_impede_med = surge_factor*tmp_repair_class.impeding_time_no_contractor'; % days
    otherwise
        error('PBEE_Recovery:RepairSchedule', 'Invalid contractor relationship type, "%s", for impedance factor simulation', contractor_relationship)
end

% Find the which realization have damage that can be resolved by temp
% repairs
tmp_repair_class_trigger = zeros(num_reals, height(tmp_repair_class));
for sys = 1:height(tmp_repair_class) 
    sys_filt = damage.comp_ds_table.tmp_repair_class' == sys; 
    for tu = 1:length(damage.tenant_units)
        is_damaged = damage.tenant_units{tu}.qnt_damaged > 0 & damage.tenant_units{tu}.worker_days > 0;
        % Track if any damage exists that requires repair (assumes all
        % damage requires repair)
        tmp_repair_class_trigger(:,sys) = max( ...
            tmp_repair_class_trigger(:,sys), ...
            max(is_damaged .* sys_filt, [], 2) ...
        );
    end
end

% Simulate Impedance Time
prob_sim = rand(num_reals, 1); % This assumes systems are correlated
x_vals_std_n = icdf(trunc_pd, prob_sim); % Truncated lognormal distribution (via standard normal simulation)
tmp_impede_sys = exp(x_vals_std_n * beta + log(temp_impede_med));

% Only use the simulated values for the realzation and system that
% trigger temporary repair damage
tmp_impede_sys = tmp_impede_sys .* tmp_repair_class_trigger;

% Assume impedance always takes a full day
impeding_factors.temp_repair.time_sys = ceil(tmp_impede_sys);

% Temporary scaffolding for falling hazards
prob_sim = rand(num_reals, 1);
x_vals_std_n = icdf(trunc_pd, prob_sim);% Truncated lognormal distribution (via standard normal simulation)
scaffold_impede_time = ceil(surge_factor*exp(x_vals_std_n * beta + log(impedance_options.scaffolding_lead_time))); % always round up
prob_sim = rand(num_reals, 1); % repair time is not correlated to impedance time
x_vals_std_n = icdf(trunc_pd, prob_sim);% Truncated lognormal distribution (via standard normal simulation)
scaffold_repair_time = exp(x_vals_std_n * beta + log(impedance_options.scaffolding_erect_time)); 
impeding_factors.temp_repair.scaffold_day = ceil(scaffold_impede_time + scaffold_repair_time); % round up (dont resolve issue on the same day repairs are complete)

%% Format Impedance times for Gantt Charts
% Full repair
impeding_factors.breakdowns.full.inspection.start_day = max(start_day.inspection,[],2);
impeding_factors.breakdowns.full.inspection.complete_day = max(complete_day.inspection,[],2);
impeding_factors.breakdowns.full.financing.start_day = max(start_day.financing,[],2);
impeding_factors.breakdowns.full.financing.complete_day = max(complete_day.financing,[],2);
impeding_factors.breakdowns.full.contractor_mob.start_day = max(start_day.contractor_mob,[],2);
impeding_factors.breakdowns.full.contractor_mob.complete_day = max(complete_day.contractor_mob,[],2);
impeding_factors.breakdowns.full.eng_mob.start_day = max(start_day.eng_mob,[],2);
impeding_factors.breakdowns.full.eng_mob.complete_day = max(complete_day.eng_mob,[],2);
impeding_factors.breakdowns.full.design.start_day = max(start_day.design,[],2);
impeding_factors.breakdowns.full.design.complete_day = max(complete_day.design,[],2);
impeding_factors.breakdowns.full.permit_rapid.start_day = max(start_day.permit_rapid,[],2);
impeding_factors.breakdowns.full.permit_rapid.complete_day = max(complete_day.permit_rapid,[],2);
impeding_factors.breakdowns.full.permit_full.start_day = max(start_day.permit_full,[],2);
impeding_factors.breakdowns.full.permit_full.complete_day = max(complete_day.permit_full,[],2);

% Represent long lead times per system
for s = 1:height(systems)
    impeding_factors.breakdowns.long_lead.(systems.name{s}).start_day = start_day.long_lead(:,s);
    impeding_factors.breakdowns.long_lead.(systems.name{s}).complete_day = complete_day.long_lead(:,s);
end

% Temporary Repairs - hard coded fixed to 5 temp repair class
for tmp = 1:height(tmp_repair_class)
    impeding_factors.breakdowns.temp.(tmp_repair_class.name_short{tmp}).start_day = zeros(num_reals,1);
    impeding_factors.breakdowns.temp.(tmp_repair_class.name_short{tmp}).complete_day = impeding_factors.temp_repair.time_sys(:,1);
end


end