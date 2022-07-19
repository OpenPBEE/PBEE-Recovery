function [repair_complete_day_per_system, worker_data] = ...
    fn_allocate_workers_systems(systems, sys_repair_days, sys_crew_size, ...
    max_workers_per_building, sys_idx_priority_matrix, ...
    sys_constraint_matrix, condition_tag, sys_impeding_factors)
% Stager repair to each system and allocate workers based on the repair
% constraints, priorities, and repair times of each system
%
% Parameters
% ----------
% system_repair_days: [num reals x num systems]
%   Number of days from the start of repair of each to the completion of
%   the system (assuming all sequences start on day zero)
% sys_crew_size: array [num reals x num systems]
%   required crew size for each system
% max_workers_per_building: int
%   Maximum number of workers that can work in the building at the same time 
% sys_idx_priority_matrix: matrix [num reals x systems]
%   worker allocation order of system id's prioritized for each realiztion
% sys_constraint_matrix: array [num reals x num_sys]
%   array of system ids which define which systems (column index) are delayed by the
%   system ids (array values)
% condition_tag: logical array [num reals x 1]
%   true/false if the building is red tagged
% sys_impeding_factors: array [num_reals x num_sys]
%   maximum impedance time (days) for each system. Pass in empty array when
%   calculating repair times (i.e. not including impeding factors).
%
% Returns
% -------
% repair_complete_day_per_system: matrix [num reals x num systems]
%   Number of days from the start of each sequence to the completion of the
%   sequence considering the allocation of workers to each sequence (ie
%   some sequences start before others)
% worker_data.total_workers: array [num reals x varies]
%   total number of workers in the building at each time step of the worker
%   allocation algorthim. The number of columns varies with the number of
%   increments of the worker allocation algorithm.
% worker_data.day_vector: array [num reals x varies]
%   Day of each time step of the worker allocation algorthim. The number of 
%   columns varies with the number of increments of the worker allocation algorithm.
%
% Notes
% -----

%% Initial Setup
% Initialize Variables
[num_reals, num_sys] = size(sys_repair_days);
priority_system_complete_day = zeros(num_reals,num_sys);
day_vector = zeros(num_reals, 0);
total_workers = zeros(num_reals, 0);

% Re-order system variables based on priority
[ priority_sys_workers_matrix ] = fitler_matrix_by_rows( sys_crew_size, sys_idx_priority_matrix );
[ priority_sys_constraint_matrix ] = fitler_matrix_by_rows( sys_constraint_matrix, sys_idx_priority_matrix );
[ priority_sys_repair_days ] = fitler_matrix_by_rows( sys_repair_days, sys_idx_priority_matrix );
if isempty(sys_impeding_factors)
    priority_sys_impeding_factors = zeros(num_reals, num_sys);
else
    [ priority_sys_impeding_factors ] = fitler_matrix_by_rows( sys_impeding_factors, sys_idx_priority_matrix );
end

% Round up days to the nearest day
% Provides an implicit change of trade delay, as well as help to reduce the
% number of delta increments in the following while loop
priority_sys_repair_days = ceil(priority_sys_repair_days);
priority_sys_impeding_factors = ceil(priority_sys_impeding_factors);

%% Assign workers to each system based on repair constraints
iter = 0;
current_day = zeros(num_reals,1);
priority_sys_waiting_days = priority_sys_impeding_factors;
while sum(sum(priority_sys_repair_days)) > 0.01
    iter = iter + 1; 
    if iter > 1000 % keep the while loop pandemic contained
        error('PBEE_Recovery:RepairSchedule', 'Could not converge worker allocations for among systems');
    end
    
    % zero out assigned workers matrix
    assigned_workers = zeros(num_reals,num_sys);
    
    % limit available workers to the max that can be on any one given story
    % this ensures next system cannot start until completely unblocked on
    % every story. Need to update for taller buildings which could start
    % next sequence on lower story once previous sequence was far enough
    % along
%     available_workers = min(max(max_workers_per_story),max_workers_per_building)*ones(num_reals, 1);  % currently assumes all stories have the same crew size limitation (uniform sq ft for each story)
    available_workers = max_workers_per_building*ones(num_reals, 1);
    
    % Define what systems are waiting to begin repairs
    sys_blocked = zeros(num_reals,num_sys);
    sys_incomplete = (priority_sys_repair_days > 0);
%     constraining_systems = unique(priority_sys_constraint_matrix(priority_sys_constraint_matrix ~=0));
    for s = 1:num_sys % Loop over each system that may constrain something
        constrained_systems = priority_sys_constraint_matrix == s; % These systems are contrained by looped system
        constraining_sys_filt = sys_idx_priority_matrix == s; % location in matrix of this system
        is_constraining_sys_incomplete = max(sys_incomplete .* constraining_sys_filt,[],2); % Vec of relizations for looped system
        sys_blocked = sys_blocked | (constrained_systems .* is_constraining_sys_incomplete); % System is constrained if blocked by an incomplete system
    end
    
    % Need to wait for impeding factors or other repairs to finish
    is_waiting = (current_day < priority_sys_impeding_factors) | sys_blocked; % assuming impeding factors are the only constraints
    
    % Define where needs repair
    % System needs repair if there are still repairs days left and it is
    % not waiting to be unblocked
    needs_repair = (priority_sys_repair_days > 0) & ~is_waiting;

    % Defined Required Workers
    required_workers = needs_repair .* priority_sys_workers_matrix;
    
    % Assign Workers to each system
    for s = 1:num_sys
        % Assign Workers to this systems
        enough_workers = required_workers(:,s) <= available_workers;
        assigned_workers(enough_workers,s) = min(required_workers(enough_workers,s), available_workers(enough_workers));

        % Define Available Workers
        % when in series limit available workers to the workers in this system 
        % (occurs for structural systems when the building is red tagged
        is_sturctural = strcmp(systems.name{s},'structural');
        in_series = condition_tag & is_sturctural;
        available_workers(in_series & assigned_workers(:,s) > 0) = 0; 
        % when not in series, calc the remaining workers
        available_workers(~in_series) = available_workers(~in_series) - assigned_workers(~in_series,s); 
    end
    
    % Calculate the time associated with this increment of the while loop
    in_progress = assigned_workers > 0; % sequences where work is being done
    total_repair_days = inf(size(in_progress)); % pre-allocate with inf's becuase we take a min later
    total_repair_days(in_progress) = priority_sys_repair_days(in_progress);
    total_waiting_days = priority_sys_waiting_days;
    total_waiting_days(total_waiting_days == 0) = inf; % Convert zeros to inf such that zeros are not included in the min in the next step
    total_time = min(total_repair_days,total_waiting_days); % combime repair time and waiting time
    delta_days = min(total_time,[],2); % time increment is whatever in-progress story that finishes first
    delta_days(isinf(delta_days)) = 0; % Replace infs from real that has no repair with zero
    
    % Reduce waiting time
    priority_sys_waiting_days = max(priority_sys_waiting_days - delta_days,0);
    
    % Reduce time needed for repairs
    delta_days_in_progress = delta_days .* in_progress; % change in repair time for all sequences being worked on
    priority_sys_repair_days(in_progress) = max(priority_sys_repair_days(in_progress) - delta_days_in_progress(in_progress),0);
    
    % Define Start and Stop of Repair for each sequence
    priority_system_complete_day = priority_system_complete_day + delta_days .* (needs_repair | is_waiting);
    
    % Define Cummulative day of repair
    day_vector = [day_vector, current_day];
    current_day = current_day + delta_days;
    
    % Save worker data data over time
    total_workers = [total_workers, sum(assigned_workers,2), sum(assigned_workers,2)];
    day_vector = [day_vector, current_day];
end
    
% Untangle system_complete_day back into system table order
[~, sys_idx_untangle_matrix] = sort(sys_idx_priority_matrix, 2);
[ repair_complete_day_per_system ] = fitler_matrix_by_rows( priority_system_complete_day, sys_idx_untangle_matrix );

% Save worker data matrices
worker_data.total_workers = total_workers;
worker_data.day_vector = day_vector;
end


function [ filtered_values ] = fitler_matrix_by_rows( values, filter )
% Use a identiry matrix to filter values from another matrix by rows

% Parameters
% ----------
% values: matrix [n x m]
%   values to filter by row
% filter: matrix [n x m]
%   array indexes to grab from each row of values
%
% Returns
% -------
% filtered_values: matrix [n x m]
%   values filtered by rows

% Method
x2t = values.';
idx1 = filter.';
y4         = zeros(size(idx1));
for r = 1:size(values,1)
    y4(:, r) = x2t(idx1(:, r), r);
end
filtered_values = y4.';


end