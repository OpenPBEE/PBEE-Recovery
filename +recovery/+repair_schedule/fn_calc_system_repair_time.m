function [schedule] = fn_calc_system_repair_time(damage, repair_type, systems, max_workers_per_building, max_workers_per_story)
% Determine the repair time for each system if repaired in isolation 
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage and loss data for each component in the building
% systems: table
%   data table containing information about each system's attributes
% max_workers_per_building: int
%   maximum number of workers allowed in the building at once
% max_workers_per_story: array [1 x num_stories]
%   maximum number of workers allowed in each story at once
%
% Returns
% -------
% schedule.per_system{sys}.repair_start_day [num reals x num stories]
%   The number of days from the start of repair of a specifc system until
%   the start of repair of each story for that given system (i.e. the day 
%   of the start of repairs relative the to start of this system ... e.g.
%   story 1 should always be zero)
% schedule.per_system{sys}.repair_complete_day [num reals x num stories]
%   The number of days from the start of repair of a specifc system until
%   each story is fully repaired for that given system.
% schedule.per_system{sys}.max_num_workers_per_story [num reals x num stories]
%   The number of workers required to repair each story of this system
% schedule.system_totals.repair_days [num reals x num systems]
%   The number of days required to repair each system in isolation
% schedule.system_totals.num_workers [num reals x num systems]
%   The number of workers required for the repair of each system
%
% Notes
% -----

%% Initial Setup
% Import Packages
import recovery.repair_schedule.fn_allocate_workers_stories

% General Varaible
[num_reals, ~] = size(damage.tenant_units{1}.worker_days);
schedule.system_totals.repair_days = zeros(num_reals,height(systems));
schedule.system_totals.num_workers = zeros(num_reals,height(systems));

%% Allocate workers to each story for each system
% Repair finish times assumes all sequences start on day zero
for sys = 1:height(systems)
    % Define the Crew workers and total workers days for this sequence
    % in arrays of [num reals by num stories]
    [ total_worker_days, num_workers, average_crew_size, max_crews_building ] ...
        = fn_repair_sequence_parameters( ...
            damage, ...
            repair_type, ...
            systems.id(sys), ...
            systems.num_du_per_crew(sys), ...
            systems.max_crews_per_comp_type(sys), ...
            max_workers_per_story, ...
            max_workers_per_building ...
            );
    
    % Allocate workers to each story and determine the total days until
    % repair is complete for each story and sequence
    [ ... 
        schedule.per_system{sys}.repair_start_day, ...
        schedule.per_system{sys}.repair_complete_day, ...
        schedule.per_system{sys}.max_num_workers_per_story ...
    ] = fn_allocate_workers_stories( ...
        total_worker_days, num_workers, average_crew_size, max_crews_building, max_workers_per_building);

    % How many days does it take to complete each system in isloation
    schedule.system_totals.repair_days(:,sys) = max(schedule.per_system{sys}.repair_complete_day,[],2);
    schedule.system_totals.num_workers(:,sys) = max(schedule.per_system{sys}.max_num_workers_per_story,[],2);
end 

end


function [total_worker_days, num_workers, average_crew_size, max_crews_building] = fn_repair_sequence_parameters( ...
    damage, repair_type, sys, num_du_per_crew, max_crews_per_comp_type, max_workers_per_story, max_workers_per_building)
% Define crew sizes, workers, and repair times for each story of a given
% system. Based on worker limiations, and component worker days data from
% the FEMA P-58 assessment.

% Define Repair Type Variables (variable within the damage object)
if strcmp(repair_type,'full')
    repair_time_var = 'worker_days';
    system_var = 'system';
    crew_size_var = 'crew_size';
elseif strcmp(repair_type,'temp')
    repair_time_var = 'tmp_worker_day';
    system_var = 'tmp_repair_class';
    crew_size_var = 'tmp_crew_size';
else
    error('Unexpected Repair Type')
end

% Define Initial Parameters
num_stories = length(damage.tenant_units);
[num_reals, num_comps] = size(damage.tenant_units{1}.worker_days);
sequence_filt = damage.comp_ds_table.(system_var)' == sys; % identifies which ds idices are in this seqeunce  
comp_types = unique(damage.comp_ds_table.comp_idx(sequence_filt)); % Types of components in this system

% Pre-allocatate variables
total_worker_days = zeros(num_reals,num_stories);
is_damaged_building = zeros(num_reals,num_comps);
num_damaged_comp_types = zeros(num_reals,num_stories);
num_damaged_units = zeros(num_reals,num_stories);
average_crew_size = zeros(num_reals,num_stories);

for s = 1:num_stories
    % Define damage properties of this system at this story
    num_damaged_units(:,s) = sum(sequence_filt .* damage.tenant_units{s}.qnt_damaged,2);
    is_damaged = damage.tenant_units{s}.qnt_damaged > 0;
    is_damaged_building = is_damaged_building | is_damaged;
    
    for c = 1:length(comp_types)
        num_damaged_comp_types(:,s) = num_damaged_comp_types(:,s) + any((damage.comp_ds_table.comp_idx' == comp_types(c)) .* is_damaged,2);
    end

    % Caluculate total worker days per story per sequeces
    total_worker_days(:,s) = sum(damage.tenant_units{s}.(repair_time_var)(:,sequence_filt),2); % perhaps consider doing when we first set up this damage data structure
    
    % Determine the required crew size needed for these repairs
    repair_time_per_comp = damage.tenant_units{s}.(repair_time_var) ./  damage.comp_ds_table.(crew_size_var)';
    average_crew_size(:,s) = total_worker_days(:,s) ./ sum(repair_time_per_comp(:,sequence_filt),2);
end
    
% Define the number of crews needed based on the extent of damage
num_crews = ceil(num_damaged_units / num_du_per_crew);
num_crews = min(num_crews,max_crews_per_comp_type .* num_damaged_comp_types);
num_crews = min(num_crews,ceil(num_damaged_units)); % Safety check: num crews should never be greater than the number of damaged components

% Round up total worker days to the nearest day to speed up the worker 
% allocation loop and implicitly consider change of trade delays
total_worker_days = ceil(total_worker_days);

% Round crew sizes such that we have a realistic size (still implicitly
% averaged based on type of damage)
average_crew_size(isnan(average_crew_size)) = 0;
average_crew_size = round(average_crew_size);

% Limit the number of crews based on the space limitations at this story
% and the assumed crew size
worker_upper_lim = min(max_workers_per_story,max_workers_per_building);
max_num_crews_per_story = max(floor(worker_upper_lim ./ average_crew_size),1);
num_crews = min(num_crews,max_num_crews_per_story);

% Calculate the total number of workers per story for this system
num_workers = average_crew_size .* num_crews;

% Repeat calc of number of uniquely damaged component types for the whole
% building
num_damaged_comp_types = zeros(num_reals,1);
for c = 1:length(comp_types)
    num_damaged_comp_types = num_damaged_comp_types + any((damage.comp_ds_table.comp_idx' == comp_types(c)) .* is_damaged_building,2);
end
max_crews_building = max_crews_per_comp_type .* num_damaged_comp_types;
end
