function [ sys_constraint_matrix ] = fn_set_repair_constraints( systems, repair_type, conditionTag )
% Define a constraint matrix to be used by repair schedule
%
% Delelops a matrix of various constriants between each system (i.e. what
% systems need to be repaired before others) for each realization

% Parameters
% ----------
% systems: table
%   data table containing information about each system's attributes
% conditionTag: logical array (num_reals x 1)
%   Is the building red tagged for each realization
%
% Returns
% -------
% sys_constraint_matrix: array [num reals x num_sys]
%   array of system ids which define which systems (column index) are delayed by the
%   system ids (array values)
%
% Notes
% -----
% Shortcoming: as implemented, each system can only be constrained by one
%              other system
% Example:
%   [0 0 1 0 0 0 0 6 0]
%   Interiors (column 3) are blocked by struture (value of 1 in the 3rd column)
%   HVAC (column 8) is blocked by plumbing (value of 6 in the 8th column)

%% Initial Setup
num_sys = height(systems);
num_reals = length(conditionTag);
sys_constraint_matrix = zeros(num_reals, num_sys);

%% Interior Constraints
if strcmp(repair_type,'full') 
    % Interiors are delayed by structural repairs
    interiors_idx = find(strcmp(systems.name,'interior'));
    structure_idx = find(strcmp(systems.name,'structural'));
    sys_constraint_matrix(:,interiors_idx) = structure_idx;

    % Red Tag Constraints
    % All systems blocked by structural when red tagged
    sys_constraint_matrix(logical(conditionTag),~strcmp(systems.name,'structural')) = structure_idx;
elseif strcmp(repair_type,'temp')
    % All temp repairs are blocked by shoring
    shoring_id = 5;
    shoring_filt = systems.id == shoring_id;
    shoring_idx = find(shoring_filt);
    sys_constraint_matrix(:,~shoring_filt') = shoring_idx; % all classes that are not shoring idx are blocked by the shoring idx
else
    error('Unexpected Repair Type')
end


end

