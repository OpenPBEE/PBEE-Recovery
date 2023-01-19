function [ surge_factor ] = fn_default_surge_factor( is_dense_urban_area, pga, pga_de )
% This function determines the surge factor based on the intensity of shaking
%
% Parameters
% ----------
% is_dense_urban_area: bool
%   if the building is in a dense urban area or not
% pga: number
%   peak ground acceleration, in g, of this intensity level
% pga_de: number
%   peak ground acceleration at the design intensity
%
% Returns
% -------
% surge_factor: number
%   surge factor which amplified impedance factor times
%
% Notes
% -----
%
%     |                                         _____________ 3.0
%     |                                       /              
%     |                                      /               
%     |                                     /                
%     |                                    /                 
%     |                                   /                  
%     |                                  /     ______________ 1.5
%     |                                 /    / |             
%     |                                /   /   |             
%     |                               /  /     |             
%     |                              / /       |             
%     |                             //         |             
% 1.0 |  __________________________/           |             
%     |                            |           |             
%     |                            |           |             
%     -----------------------------+-----------+-------------
%                                pga_1       pga_2

if is_dense_urban_area
    max_surge = 3;
else
    max_surge = 1.5;
end

pga_1 = max(0.2, pga_de);
pga_2 = pga_1 * 1.5;
surge_factor = interp1([pga_1, pga_2], [1, max_surge], min(max(pga,pga_1),pga_2));

end

