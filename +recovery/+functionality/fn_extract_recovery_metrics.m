function [ recovery ] = fn_extract_recovery_metrics( tentant_unit_recovery_day, ...
   recovery_day, comp_breakdowns, comp_id, simulated_replacement )
% Reformant tenant level recovery outcomes into outcomes at the building level, 
% system level, and compoennt level
%
% Parameters
% ----------
% tentant_unit_recovery_day: array [num_reals x num_tenant_units]
%   simulated recovery day of each tenant unit
% recovery_day: struct
%   simulation of the number of days each fault tree event is affecting
%   recovery
% comp_breakdowns: struct
%   simulation of each components contributions to each of the fault tree events 
% comp_id: cell array [1 x num comp damage states]
%   list of each fragility id associated with the per component damage
%   state structure of the damage object. With of array is the same as the
%   arrays in the comp_breakdowns structure
% simulated_replacement: array [num_reals x 1]
%   simulated time when the building needs to be replaced, and how long it
%   will take (in days). NaN represents no replacement needed (ie
%   building will be repaired)
%
% Returns
% -------
% recovery.tenant_unit.recovery_day: array [num_reals x num_tenant_units]
%   simulated recovery day of each tenant unit
% recovery.building_level.recovery_day: array [num_reals x 1]
%   simulated recovery day of the building (all tenant units recovered)
% recovery.building_level.initial_percent_affected: array [num_reals x 1]
%   simulated fraction of the building with initial loss of
%   reoccupancy/function
% recovery.recovery_trajectory.recovery_day: array [num_reals x num recovery steps]
%   simulated recovery trajectory y-axis
% recovery.recovery_trajectory.percent_recovered: array [1 x num recovery steps]
%   recovery trajectory x-axis
% recovery.breakdowns.system_breakdowns: array [num fault tree events x target days]
%   fraction of realizations affected by various fault tree events beyond
%   specific target recovery days
% recovery.breakdowns.component_breakdowns: array [num components x target days]
%   fraction of realizations affected by various components beyond
%   specific target recovery days
% recovery.breakdowns.perform_targ_days: array [0 x target days]
%   specific target recovery days
% recovery.breakdowns.system_names: array [num fault tree events x 1]
%   name of each fault tree event
% recovery.breakdowns.comp_names: array [num components x 1]
%   fragility IDs of each component


%% Initial Setup
num_units = size(tentant_unit_recovery_day,2);

% Define performance targets
perform_targ_days = [0, 3, 7, 14, 30, 60, 90, 120, 182, 270, 365]; % Number of days for each performance target stripe

% Determine replacement cases
replace_cases = ~isnan(simulated_replacement);

%% Post process tenant-level recovery times
% Overwrite NaNs in tenant_unit_day_functional
% Only NaN where never had functional loss, therefore set to zero
tentant_unit_recovery_day(isnan(tentant_unit_recovery_day)) = 0;

% Overwrite building replacment cases to replacement time
tentant_unit_recovery_day(replace_cases,:) = simulated_replacement(replace_cases)*ones(1,num_units);

%% Save building-level outputs to occupancy structure
% Tenant Unit level outputs
recovery.tenant_unit.recovery_day = tentant_unit_recovery_day;

% Building level outputs
recovery.building_level.recovery_day = max(tentant_unit_recovery_day,[],2);
recovery.building_level.initial_percent_affected = mean(tentant_unit_recovery_day > 0,2); % percent of building affected, not the percent of realizations
recovery.building_level.perform_targ_days = perform_targ_days;
recovery.building_level.prob_of_target = mean(recovery.building_level.recovery_day > perform_targ_days);

%% Recovery Trajectory -- calcualte from the tenant breakdowns
recovery.recovery_trajectory.recovery_day = sort([tentant_unit_recovery_day, tentant_unit_recovery_day],2);
recovery.recovery_trajectory.percent_recovered = sort([(0:(num_units-1)), (1:num_units)])/num_units;

%% Format and Save Component-level breakdowns
% Find the day each ds of each component stops affecting recovery for any story

% Combine among all fault tree events
component_breakdowns_per_story = 0;
fault_tree_events_LV1 = fieldnames(comp_breakdowns);
for i = 1:length(fault_tree_events_LV1)
    fault_tree_events_LV2 = fieldnames(comp_breakdowns.(fault_tree_events_LV1{i}));
    for j = 1:length(fault_tree_events_LV2)
        component_breakdowns_per_story = max(component_breakdowns_per_story,...
            comp_breakdowns.(fault_tree_events_LV1{i}).(fault_tree_events_LV2{j}));
    end
end

% Combine among all stories
% aka time each component's DS affects recovery anywhere in the building
component_breakdowns = max(component_breakdowns_per_story,[],3);

% Ignore repalcement cases
component_breakdowns(replace_cases,:) = []; 

%% Format and Save System-level breakdowns
% Find the day each system stops affecting recovery for any story

% Combine among all fault tree events
system_breakdowns = [];
fault_tree_events_LV1 = fieldnames(recovery_day);
for i = 1:length(fault_tree_events_LV1)
    fault_tree_events_LV2 = fieldnames(recovery_day.(fault_tree_events_LV1{i}));
    for j = 1:length(fault_tree_events_LV2)
        % Combine among all stories or tenant units to represent the events
        % effect anywhere in the building 
        building_recovery_day = max(recovery_day.(fault_tree_events_LV1{i}).(fault_tree_events_LV2{j}),[],2);
        
        % Ignore repalcement cases
        building_recovery_day(replace_cases,:) = []; 
        
        % Save per "system", which typically represents the fault tree level 2
        if isfield(system_breakdowns,fault_tree_events_LV2{j})
            % If this "system" has already been defined in another fault
            % tree branch, combine togeter by taking the max (i.e., max
            % days this system affects recovery anywhere in the building)
            system_breakdowns.(fault_tree_events_LV2{j}) = ...
                max(system_breakdowns.(fault_tree_events_LV2{j}),building_recovery_day);
        else
            system_breakdowns.(fault_tree_events_LV2{j}) = building_recovery_day;
        end
    end
end

%% Format breakdowns as performance targets
system_names = fieldnames(system_breakdowns);

% pre-allocating variables
comps = unique(comp_id);
recovery.breakdowns.system_breakdowns = zeros(length(system_names),length(perform_targ_days));
recovery.breakdowns.component_breakdowns = zeros(length(comps),length(perform_targ_days));

% Calculate fraction of realization each system affects recovery for each
% performance target time
for s = 1:length(system_names)
    recovery.breakdowns.system_breakdowns(s,:) = mean(system_breakdowns.(system_names{s}) > perform_targ_days);
end

% Calculate fraction of realization each component affects recovery for each
% performance target time
for c = 1:length(comps)
    comp_filt = strcmp(comp_id,comps{c}); % find damage states associated with this component
    recovery.breakdowns.component_breakdowns(c,:) = mean(max(component_breakdowns(:,comp_filt'),[],2) > perform_targ_days);
end

% store this so we can properly overalap the reoccupancy and functionality
recovery.breakdowns.component_breakdowns_all_reals = component_breakdowns;

% Save other variables
recovery.breakdowns.perform_targ_days = perform_targ_days;
recovery.breakdowns.system_names = system_names;
recovery.breakdowns.comp_names = comps';

%% Save specific breakdowns for red tags
% Note for future updates: Perhaps instead, all realizations of red tag time
% should be output andthe statistics calculated here should be done as a post process
if isfield(recovery_day, 'building_safety')
    red_tag_time = recovery_day.building_safety.red_tag;
    red_tag_time(replace_cases,:) = []; % Ignore replacement cases
    recovery.red_tag.probability = mean(red_tag_time > 0);
    recovery.red_tag.mean = mean(red_tag_time);
    recovery.red_tag.median = median(red_tag_time);
    recovery.red_tag.fractile_90 = prctile(red_tag_time, 90);
end

end

