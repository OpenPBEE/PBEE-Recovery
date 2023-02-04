function [ damage ] = fn_populate_damage_per_tu( damage )
% Check to see if the damage.tenant_units variable has been defined. If
% not, assume its the same as damage.story. This assumption creates a 1:1
% coupling between stories and tenant_units (one tenant unit per story)
%
% Parameters
% ----------
% damage.story: array of struct
%   contains simulated per component and damage state damage info
%   disagregated by story
%
% Returns
% -------
%   contains simulated per component and damage state damage info
%   disagregated by tenant unit
%

%% If tenant unit damage is not provided by the user, assume its the same as per story damage
if ~isfield(damage,'tenant_units')
    damage.tenant_units = damage.story;
end

end

