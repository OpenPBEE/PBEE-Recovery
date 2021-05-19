function [impeding_factors] = main_impeding_factors(damage, impedance_options, repair_cost, ...
    inpsection_trigger, systems, system_repair_time)
% Calculate ATC-138 impeding times for each system given simulation of damage
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage and loss data for each component in the building
% impedance_options: struct
%   general impedance assessment user inputs such as mitigation factors
% repair_cost: array [num_reals x 1]
%   total repair cost per realization normalized by building replacement
%   value
% inpsection_trigger: logical array [num_reals x 1]
%   defines which realizations require inspection
% num_stories: int
%   Total number of building stories
% systems: table
%   data table containing information about each system's attributes
% system_repair_time [num reals x num systems]
%   The number of days required to repair each system in isolation
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
import recovery.repair_schedule.impedance.fn_calculate_sdt_prt
import recovery.repair_schedule.impedance.fn_contractor
import recovery.repair_schedule.impedance.fn_engineering
import recovery.repair_schedule.impedance.fn_financing
import recovery.repair_schedule.impedance.fn_inspection
import recovery.repair_schedule.impedance.fn_permitting

% Initialize parameters
num_reals = length(inpsection_trigger);
num_sys = height(systems);

% Preallocatd each impance time
duration.inspection = zeros(num_reals, num_sys);
duration.financing = zeros(num_reals, num_sys);
duration.permitting = zeros(num_reals, num_sys);
duration.contractor_mob = zeros(num_reals, num_sys);
duration.eng_mob = zeros(num_reals, num_sys);
duration.design = zeros(num_reals, num_sys);

% System repair trigger
sys_repair_trigger = system_repair_time > 0;

[ system_design_time, permit_review_time, system_rapid_permit_trigger ] = fn_calculate_sdt_prt( ...
    damage, system_repair_time );

% Create basic trucated standard normal distribution for later simulation
pd = makedist('normal','mu',0,'sigma',1);
th_low = -2; % Truncate below -2 standard deviations
th_high = 2; % Truncate above +2 standard deviations
trunc_pd = truncate(pd,th_low,th_high);

%% Simulate impedance time for each impedance factor 
if impedance_options.include_impedance.inspection
    duration.inspection = fn_inspection( impedance_options.mitigation.is_essential_facility, ...
        impedance_options.surge_factor, sys_repair_trigger, inpsection_trigger, trunc_pd );
end

if impedance_options.include_impedance.financing
    duration.financing = fn_financing( impedance_options.mitigation.capital, ...
        impedance_options.mitigation.funding_source, sys_repair_trigger, repair_cost, trunc_pd );
end

if impedance_options.include_impedance.permitting
    duration.permitting = fn_permitting(  ...
        impedance_options.surge_factor, system_rapid_permit_trigger, permit_review_time, trunc_pd );
end

if impedance_options.include_impedance.contractor
    duration.contractor_mob = fn_contractor( ...
        impedance_options.surge_factor, sys_repair_trigger, system_repair_time, trunc_pd );
end

if impedance_options.include_impedance.engineering
    [ duration.eng_mob, duration.design ] = fn_engineering( ...
        impedance_options.surge_factor, system_design_time, trunc_pd);
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

start_day.permitting = complete_day.design;
complete_day.permitting = start_day.permitting + duration.permitting;

start_day.contractor_mob = max(max(complete_day.inspection,start_day.financing),start_day.eng_mob);
complete_day.contractor_mob = start_day.contractor_mob + duration.contractor_mob;

% Combine all impedance factors by system
impede_factors = fieldnames(complete_day);
impeding_factors.time_sys = 0;
for i = 1:length(impede_factors)
    impeding_factors.time_sys = max(impeding_factors.time_sys,...
        complete_day.(impede_factors{i}));
end
                                            
%% Format Impedance times for Gantt Charts
impeding_factors.breakdowns.inspection.start_day = max(start_day.inspection,[],2);
impeding_factors.breakdowns.inspection.complete_day = max(complete_day.inspection,[],2);
impeding_factors.breakdowns.financing.start_day = max(start_day.financing,[],2);
impeding_factors.breakdowns.financing.complete_day = max(complete_day.financing,[],2);

select_sys = [1, 2, 4]; % only for structure, exterior, and stairs
for ss = select_sys
    impeding_factors.breakdowns.eng_mob.(systems.name{ss}).start_day = start_day.eng_mob(:,ss);
    impeding_factors.breakdowns.eng_mob.(systems.name{ss}).complete_day = complete_day.eng_mob(:,ss);
    impeding_factors.breakdowns.design.(systems.name{ss}).start_day = start_day.design(:,ss);
    impeding_factors.breakdowns.design.(systems.name{ss}).complete_day = complete_day.design(:,ss);
end

for s = 1:height(systems)
    impeding_factors.breakdowns.permitting.(systems.name{s}).start_day = start_day.permitting(:,s);
    impeding_factors.breakdowns.permitting.(systems.name{s}).complete_day = complete_day.permitting(:,s);
    impeding_factors.breakdowns.contractor_mob.(systems.name{s}).start_day = start_day.contractor_mob(:,s);
    impeding_factors.breakdowns.contractor_mob.(systems.name{s}).complete_day = complete_day.contractor_mob(:,s);
end


end