function [ damage_consequences ] = fn_define_door_racking( damage_consequences, num_stories )
% Define building level damage consquences when not specificed by the user.
%
% Parameters
% ----------
% damage_consequences: struct
%   data structure containing simulated building consequences, such as red
%   tags
% num_stories: int
%   Integer number of stories in the building being assessed
%
% Returns
% -------
% damage_consequences.racked_stair_doors_per_story: array, num real x num stories
%   simulated number of racked stairwell doors at each story
% damage_consequences.racked_entry_doors_side_1: array, num real x 1
%   simulated number of racked entry doors on one side of the building
% damage_consequences.racked_entry_doors_side_2: array, num real x 1
%   simulated number of racked entry doors on the other side of the building

%% Set door racking damage if not provided by user
[num_reals, ~] = size(damage_consequences.simulated_replacement);

% Assume there are no racked doors if not specified by the user
if ~isfield(damage_consequences,'racked_stair_doors_per_story')
    damage_consequences.racked_stair_doors_per_story = zeros(num_reals,num_stories); % 
end
if ~isfield(damage_consequences,'racked_entry_doors_side_1')
    damage_consequences.racked_entry_doors_side_1 = zeros(num_reals,1); % array, num real x num stories
end
if ~isfield(damage_consequences,'racked_entry_doors_side_2')
    damage_consequences.racked_entry_doors_side_2 = zeros(num_reals,1); % array, num real x num stories
end

end

