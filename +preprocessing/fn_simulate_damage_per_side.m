function [ damage ] = fn_simulate_damage_per_side( damage )
% Simulate damage per side for the exterior falling hazard check, if not 
% provided by the user. Component location within a story is typically not 
% Provided in most PBEE assessments. Therefore, this script make the rough 
% assumptions to distribute damage to 4 sides, randomly.
%
% Parameters
% ----------
% damage: struct
%   contains simulated damage info and damage state attributes
%
% Returns
% -------
% damage: struct
%   contains simulated damage info and damage state attributes
%

%% Simulate damage per side, if not provided by the user
if ~isfield(damage.tenant_units{1},'qnt_damaged_side_1')
    [num_reals,~] = size(damage.tenant_units{1}.qnt_damaged);
    
    % Randomly split damage between 4 sides
    % (this will only matter for cladding components)
    ratio_damage_per_side = rand(num_reals,4); % assumes square footprint
    ratio_damage_per_side = ratio_damage_per_side ./ sum(ratio_damage_per_side,2); % force it to add to one

    % Assing damage
    for tu = 1:length(damage.tenant_units)
        for s = 1:4
            damage.tenant_units{tu}.(['qnt_damaged_side_' num2str(s)]) = ...
                ratio_damage_per_side(:,s).*damage.tenant_units{tu}.qnt_damaged;
        end
    end
end

