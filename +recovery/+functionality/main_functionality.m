function [ recovery ] = main_functionality( ...
    damage, building_model, damage_consequences, utilities, repair_time_options )
% Calculates building re-occupancy and function based on simulations of
% building damage and calculates the recovery times of each recovery state
% based on a given repair schedule
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage, loss, and repair time data for each 
%   component in the building
% building_model: struct
%   general attributes of the building model
% damage_consequences: struct
%   data structure containing simulated building consequences, such as red
%   tags and repair costs ratios
% utilities: struct
%   data structure containing simulated utility downtimes
% repair_time_options: struct
%   recovery time optional inputs such as various damage thresholds
%
% Returns
% -------
% recovery.reoccupancy: struct
%   contains data on the recovery of tenant- and building-level reoccupancy, 
%   recovery trajectorires, and contributions from systems and components 
% recovery.functional: struct
%   contains data on the recovery of tenant- and building-level function, 
%   recovery trajectorires, and contributions from systems and components 

%% Import Packages
import recovery.functionality.fn_calculate_reoccupancy
import recovery.functionality.fn_calculate_functionality

%% Calaculate Building Functionality Restoration Curves
% Downtime including external delays
[recovery.reoccupancy] = fn_calculate_reoccupancy( damage, damage_consequences, utilities, ...
    building_model, repair_time_options.subsystems, repair_time_options );

[recovery.functional] =  fn_calculate_functionality( damage, damage_consequences, utilities,  ...
    building_model, repair_time_options.subsystems, recovery.reoccupancy, repair_time_options );

end

