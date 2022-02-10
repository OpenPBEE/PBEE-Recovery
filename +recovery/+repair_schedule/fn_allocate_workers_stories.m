function [repair_start_day, repair_complete_day, max_workers_per_story] = fn_allocate_workers_stories(...
    total_worker_days, required_workers_per_story, average_crew_size, max_crews_building, max_workers_per_building)
% For a given building system, allocate crews to each story to
% determine the system level repair time on each story; not considering
% impeding factors or construction constriants with other systems.
%
%
% Parameters
% ----------
% total_worker_days: [num reals x num stories]
%   The total worker days needed to repair damage each story for this
%   sequence
% required_workers_per_story: array [num reals x num stories]
%   Number of workers required to repair damage in each story
% average_crew_size: array [num reals x num stories]
%   Average crew size required to repair damage in each story
% max_crews_building: logical array [num reals x 1]
%   maximum number of crews allowed in the building for this system
% max_workers_per_building: int
%   maximum number of workers allowed in the buildings at a given time
%
% Returns
% -------
% repair_start_day: matrix [num reals x num stories]
%   The number of days from the start of repair of this system until the repair of this system 
%   starts on each story
% repair_complete_day: matrix [num reals x num stories]
%   The number of days from the start of repair of this system until each story is
%   repaired for damage in this system
% max_workers_per_story: matrix [num reals x num stories]
%   number of workers required for the repair of this story and system as
%
% Notes
% -----


%% Initial Setup
[num_reals, num_stories] = size(total_worker_days);
repair_complete_day = zeros(num_reals,num_stories);
repair_start_day = nan(num_reals,num_stories);
max_workers_per_story = zeros(num_reals,num_stories);

%% Allocate workers to each story
% Loop through iterations of time reduce damage on each story based on
% assigned workers
iter = 0;
while sum(sum(total_worker_days)) > 0.01
    iter = iter + 1; 
    if iter > 1000 % keep the while loop pandemic contained
        error('PBEE_Recovery:RepairSchedule', 'Could not converge worker allocations for among stories in sequence');
    end

    % Determine the available workers in the building
    available_workers_in_building = max_workers_per_building*ones(num_reals, 1);
    assigned_workers_per_story = zeros(num_reals,num_stories); 
    assigned_crews_per_story = zeros(num_reals,num_stories); 

    % Define where needs repair
    needs_repair = total_worker_days > 0;

    % Defined Required Workers
    required_workers_per_story = needs_repair .* required_workers_per_story;
    
    % Assign Workers to each story -- assumes that we wont drop the number
    % of crews in order to meet worker per sqft limitations, and instead
    % wait until more workers are made available
    for s = 1:num_stories
        % Are there enough workers to assign a crew
        sufficient_workers = required_workers_per_story(:,s) <= available_workers_in_building;
        
        % Assign Workers to this story
        assigned_workers_per_story(sufficient_workers,s) = required_workers_per_story(sufficient_workers,s);
        assigned_crews_per_story(:,s) = assigned_workers_per_story(:,s) ./ average_crew_size(:,s);
        assigned_crews_per_story(isnan(assigned_crews_per_story)) = 0;
        num_crews_in_building = sum(assigned_crews_per_story,2);
        exceeded_max_crews = num_crews_in_building > max_crews_building;
        assigned_workers_per_story(exceeded_max_crews,s) = 0; % don't assign workers if we have exceeded the number of crews allowed in the building
        
        % Define Available Workers
        available_workers_in_building = available_workers_in_building - assigned_workers_per_story(:,s);  
    end
    
    % Define the start of repairs for each story
    start_repair_filt = isnan(repair_start_day) & (assigned_workers_per_story > 0);
    max_day_completed_so_far = max(repair_complete_day,[],2) .* ones(num_reals,num_stories);
    repair_start_day(start_repair_filt) =  max_day_completed_so_far(start_repair_filt);
    
    % Calculate the time associated with this increment of the while loop
    in_progress = assigned_workers_per_story > 0; % stories where work is being done
    total_repair_days = inf(size(in_progress)); % pre-allocate with inf's becuase we take a min later
    total_repair_days(in_progress) = total_worker_days(in_progress) ./ assigned_workers_per_story(in_progress);
    delta_days = min(total_repair_days,[],2); % time increment is whatever in-progress story that finishes first
    delta_days(isinf(delta_days)) = 0; % Replace infs from real that has no repair with zero
    delta_worker_days = assigned_workers_per_story .* delta_days; % time increment is whatever in-progress story that finishes first
    total_worker_days(in_progress) = max(total_worker_days(in_progress) - delta_worker_days(in_progress),0);
    indx_neg_remaining = total_worker_days < 0.001; % find instances of remaining time that are excessively small and don't represent realistic amount of work
    total_worker_days(indx_neg_remaining) = 0;  % zero remaining work that is negligible as defined above
    
    % Define Start and Stop of Repair for each story in each sequence
    repair_complete_day = repair_complete_day + delta_days .* needs_repair;
    
    % Max Crew Size for use in later function
    max_workers_per_story = max(max_workers_per_story,assigned_workers_per_story);
end

end

