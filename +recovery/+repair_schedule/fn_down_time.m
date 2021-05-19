function [downTime, impedance_time, inspection_time]=fn_down_time(repair_class_days, simulatedConsequences)
% Calculate REDi downtime based on repair time and impeding factors
%
% Calculates downtimes for REDi re-occupancy, functional recovery, and full
% recovery.
%
% Parameters
% ----------
% repair_class_days:  array [num reals x 3]
%   Time to repair building to Full (1), functional(2), or re-occupancy(3) targets
% simulatedConsequences: Structure
%   SP3 P-58 Engine simulated consequences
%
% Returns
% -------
% downTime: matrix [numReals x 3]
%   REDi downtime for each repair objective for each realization. The 
%   three repair objectives Full (1), functional(2), or re-occupancy(3).         
%
% Notes
% -----
% 1) Time units are ussually in days, however the units do not matter for
% this function, as long as they are consistent.
%
%
%% Intial Setup
global_fail = simulatedConsequences.global_fail;
maxRC = simulatedConsequences.maxRC;
maxStructuralRC = simulatedConsequences.maxStructuralRC;
impedingFactors = simulatedConsequences.impedingFactors;
utilityFactors = simulatedConsequences.utilityFactors;
num_reals = length(maxRC);
inspection_time = zeros(num_reals,1);
downTime = zeros(num_reals,3);

%% Calculate Inspection delays
filt = maxRC > 2 | global_fail;
inspection_time(filt) = impedingFactors.inspection(filt); % inspection

%% Full Recovery
filt_3_5 = maxRC > 0 | global_fail;           % Contractor Mobilization and Financing
filt_2_4 = maxStructuralRC > 0 | global_fail; % Engineering Mobilization and Permitting

% Add Full Recovery impeding time to Full Recovery repair time
[downTime(:,1), impedance_time(:,1)] = fn_add_impeding_time(impedingFactors, inspection_time, filt_2_4, filt_3_5, repair_class_days(:,1), utilityFactors);

%% Functional
filt_3_5 = maxRC > 1 | global_fail;           % Contractor Mobilization and Financing
filt_2_4 = maxStructuralRC > 2 | global_fail; % Engineering Mobilization and Permitting

% Add Functional impeding time to Functional repair time
[downTime(:,2), impedance_time(:,2)] = fn_add_impeding_time(impedingFactors, inspection_time, filt_2_4, filt_3_5, repair_class_days(:,2), utilityFactors);

%% Re-Occupancy
filt_3_5 = maxRC > 2 | global_fail;           % Contractor Mobilization and Financing
filt_2_4 = maxStructuralRC > 2 | global_fail; % Engineering Mobilization and Permitting

% Add Re-Occupancy impeding time to Re-Occupancy repair time
[downTime(:,3), impedance_time(:,3)] = fn_add_impeding_time(impedingFactors, inspection_time, filt_2_4, filt_3_5, repair_class_days(:,3), []);

end


function [downTime, impedance_time] = fn_add_impeding_time(impedingFactors, inspection_time, filt_2_4, filt_3_5, rediRepairTime, utilityFactors)
% Function to calculate downtime for any repair target. Adds longest
% sequence of impeding factors to the repair time to determine downtime.

% Initialize Variables
factors = zeros(length(rediRepairTime),4); % num reals by 5 impeding factors
sequence = zeros(length(rediRepairTime),3);% num reals by 3 external delay sequences

% Define the impeding factors that are triggered, else leave empty
factors(filt_2_4,1) = impedingFactors.engineer_mobilization(filt_2_4); % engineering mobilizations
factors(filt_3_5,2) = impedingFactors.contractor_mobilization(filt_3_5); % contractor mobilization
factors(filt_2_4,3) = impedingFactors.permitting(filt_2_4); % permitting
factors(filt_3_5,4) = impedingFactors.financing(filt_3_5); % financing

% Define each delay sequence
sequence(:,1) = inspection_time + factors(:,4);
sequence(:,2) = inspection_time + factors(:,1) + factors(:,3);
sequence(:,3) = inspection_time + factors(:,2);

% Downtime is the largest sequence plus time to repair
impedance_time = max(sequence,[],2);
downTime = rediRepairTime + impedance_time;

% If utility repair is considered
if ~isempty(utilityFactors)
    % increase downtime if the longest utility repair time is longer than
    % time isolated building downtime
    downTime = max(downTime,max(utilityFactors,[],2));
end
end
