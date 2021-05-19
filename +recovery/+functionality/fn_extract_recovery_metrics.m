function [ recovery ] = fn_extract_recovery_metrics( tentant_unit_recovery_day, ...
   recovery_day, comp_breakdowns, replacement_time_days, global_fail, comp_id )
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
% replacement_time_days: number
%   number of days required to fully replace the building
% global_fail: logical array [num_reals x 1]
%   is the entire building unrepairable due to issues of collapse or
%   excessiv residual
% comp_id: cell array [1 x num comp damage states]
%   list of each fragility id associated with the per component damage
%   state structure of the damage object. With of array is the same as the
%   arrays in the comp_breakdowns structure
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

%% Post process tenant-level re-occupancy times
% Overwrite NaNs in tenant_unit_day_functional
% Only NaN where never had functional loss, therefore set to zero
tentant_unit_recovery_day(isnan(tentant_unit_recovery_day)) = 0;

% Global Consequences
% Set collapse and residual cases to complete hinderence prior to replacement time
tentant_unit_recovery_day(global_fail,:) = replacement_time_days;

%% Save building-level outputs to occupancy structure
% Tenant Unit level outputs
recovery.tenant_unit.recovery_day = tentant_unit_recovery_day;

% Building level outputs
recovery.building_level.recovery_day = max(tentant_unit_recovery_day,[],2);
recovery.building_level.initial_percent_affected = mean(tentant_unit_recovery_day > 0,2);

%% Recovery Trajectory -- calcualte from the tenant breakdowns
recovery.recovery_trajectory.recovery_day = sort([tentant_unit_recovery_day, tentant_unit_recovery_day],2);
recovery.recovery_trajectory.percent_recovered = sort([(0:(num_units-1)), (1:num_units)])/num_units;

%% Format and Save Component-level breakdowns
% Component Breakdowns - Find the day repairs start on each ds of each
% component for any story

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
% isolated recovery time for each component for all building damage
% aka time each component affects recovery anywhere in the building
component_breakdowns = max(component_breakdowns_per_story,[],3);

%% Format and Save System-level breakdowns
% System Breakdowns based on full building recovery day for each system minus day the repair
% starts for the given system anywhere in the building

% Go through each fault tree event and define its contribution to
% recovery time (in terms of isolated reocovery time)
system_breakdowns = [];
fault_tree_events_LV1 = fieldnames(recovery_day);
for i = 1:length(fault_tree_events_LV1)
    fault_tree_events_LV2 = fieldnames(recovery_day.(fault_tree_events_LV1{i}));
    for j = 1:length(fault_tree_events_LV2)
        % Combine among all stories or tenant units to represent the events
        % effect anywhere in the building 
        building_recovery_day = max(recovery_day.(fault_tree_events_LV1{i}).(fault_tree_events_LV2{j}),[],2);
        
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
% Define performance targets
perform_targ_days = [0, 3, 7, 14, 30, 182, 365]; % Number of days for each performance target stripe
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

% Save other variables
recovery.breakdowns.perform_targ_days = perform_targ_days;
recovery.breakdowns.system_names = system_names;
recovery.breakdowns.comp_names = comps';

end

