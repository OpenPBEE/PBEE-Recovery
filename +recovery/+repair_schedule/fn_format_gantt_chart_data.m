function [ repair_schedule ] = fn_format_gantt_chart_data( damage, systems )
% Reformat data from the damage structure into data that is used for the
% gantt charts
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage and loss data for each component in the building
% systems: table
%   data table containing information about each system's attributes
%
% Returns
% -------
% repair_schedule: struct
%   Contians reformated repair schedule data for gantt chart plots for
%   bothy repair time and downtime calculations. Data is reformanted to
%   show breakdowns by component, by story, by system, by story within each
%   system, and by system within each story.
%
% Notes
% -----
% Since this all has to do with plotting gantt charts, a form of this
% (whether the damage structure or a higher level repair schedule
% structure) should be output and this reformatting logic moved outside the
% functional recovery assessment and into the data visuallation logic

%% Initial Setup
num_stories = length(damage.story);
[num_reals, ~] = size(damage.story{1}.recovery.repair_start_day);
comps = unique(damage.comp_ds_info.comp_id);

%% Reformate repair schedule data into various breakdowns
% Per component
repair_schedule.repair_start_day.per_component = nan(num_reals,length(comps));
repair_schedule.repair_complete_day.per_component = zeros(num_reals,length(comps));
for c = 1:length(comps)
    comps_filt = strcmp(damage.comp_ds_info.comp_id,comps{c});
    for s = 1:num_stories
        repair_schedule.repair_start_day.per_component(:,c) = min([repair_schedule.repair_start_day.per_component(:,c), damage.story{s}.recovery.repair_start_day(:,comps_filt)],[],2);
        repair_schedule.repair_complete_day.per_component(:,c) = max([repair_schedule.repair_complete_day.per_component(:,c), damage.story{s}.recovery.repair_complete_day(:,comps_filt)],[],2);
    end
    repair_schedule.component_names{c} = comps{c};
end

% Per Story
repair_schedule.repair_start_day.per_story = nan(num_reals,num_stories);
repair_schedule.repair_complete_day.per_story = zeros(num_reals,num_stories);
for s = 1:num_stories
    repair_schedule.repair_start_day.per_story(:,s) = min([repair_schedule.repair_start_day.per_story(:,s), damage.story{s}.recovery.repair_start_day],[],2);
    repair_schedule.repair_complete_day.per_story(:,s) = max([repair_schedule.repair_complete_day.per_story(:,s), damage.story{s}.recovery.repair_complete_day],[],2);
end

% Per Repair System
repair_schedule.repair_start_day.per_system = nan(num_reals,height(systems));
repair_schedule.repair_complete_day.per_system = zeros(num_reals,height(systems));
for sys = 1:height(systems)
    sys_filt = damage.comp_ds_info.system == systems.id(sys); % identifies which ds idices are in this seqeunce  
    for s = 1:num_stories
        repair_schedule.repair_start_day.per_system(:,sys) = min([repair_schedule.repair_start_day.per_system(:,sys), damage.story{s}.recovery.repair_start_day(:,sys_filt)],[],2);
        repair_schedule.repair_complete_day.per_system(:,sys) = max([repair_schedule.repair_complete_day.per_system(:,sys), damage.story{s}.recovery.repair_complete_day(:,sys_filt)],[],2);
    end
end
repair_schedule.system_names = systems.name;

% Per system per story
num_sys_stories = num_stories * height(systems);
repair_schedule.repair_start_day.per_system_story = nan(num_reals,num_sys_stories);
repair_schedule.repair_complete_day.per_system_story = zeros(num_reals,num_sys_stories);
id = 0;
for s = 1:num_stories
    for sys = 1:height(systems)
        id = id + 1;
        sys_filt = damage.comp_ds_info.system == systems.id(sys); % identifies which ds idices are in this seqeunce  
        repair_schedule.repair_start_day.per_system_story(:,id) = min([repair_schedule.repair_start_day.per_system_story(:,id), damage.story{s}.recovery.repair_start_day(:,sys_filt)],[],2);
        repair_schedule.repair_complete_day.per_system_story(:,id) = max([repair_schedule.repair_complete_day.per_system_story(:,id), damage.story{s}.recovery.repair_complete_day(:,sys_filt)],[],2);
    end
end

% Per story per system
num_sys_stories = num_stories * height(systems);
repair_schedule.repair_start_day.per_story_system = nan(num_reals,num_sys_stories);
repair_schedule.repair_complete_day.per_story_system = zeros(num_reals,num_sys_stories);
id = 0;
for sys = 1:height(systems)
    for s = 1:num_stories
        id = id + 1;
        sys_filt = damage.comp_ds_info.system == systems.id(sys); % identifies which ds idices are in this seqeunce  
        repair_schedule.repair_start_day.per_story_system(:,id) = min([repair_schedule.repair_start_day.per_story_system(:,id), damage.story{s}.recovery.repair_start_day(:,sys_filt)],[],2);
        repair_schedule.repair_complete_day.per_story_system(:,id) = max([repair_schedule.repair_complete_day.per_story_system(:,id), damage.story{s}.recovery.repair_complete_day(:,sys_filt)],[],2);
    end
end

end

