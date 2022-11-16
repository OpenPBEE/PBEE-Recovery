function [ surge_factor ] = fn_default_surge_factor( is_dense_urban_area, pga )
% This function facilitates the ATC 138 functional recovery assessment
% within the SP3 Engine for a single intensity level
%
% Parameters
% ----------
% is_dense_urban_area: bool
%   if the building is in a dense urban area or not
% pga: number
%   peak ground acceleration, in g, of this intensity level
%
%
% Returns
% -------
% surge_factor: number
%   surge factor which amplified impedance factor times

if is_dense_urban_area
    max_surge = 4;
else
    max_surge = 3;
end

min_pga = 0.2;
max_pga = 0.7;
surge_factor = interp1([min_pga, max_pga], [1, max_surge], min(max(pga,min_pga),max_pga));

end

