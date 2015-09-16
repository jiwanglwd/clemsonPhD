classdef MaterialProperties
    
    
    properties 
        E_material1 = 4; % The elastic mod of material 1
        E_material2 = 2; % The elastic mod of material 2
        K_material1 = 2; % heat conduction of material 1
        K_material2 = 4; % heat conduction of material 2    
        
        v = 0.3; % Piossons ratio
        G ; % = E_material1/(2*(1+v));
        
        dKelastic; % derivative of K elastic matrix with respect to a material vol fraction change.
        dKheat;   % derivative of K heat matrix with respect to a material vol fraction change.
    end
    
    methods

        % Constructor
        function obj = MaterialProperties
             obj.G = obj.E_material1/(2*(1+obj.v));
             
             E = 1;
             obj.dKelastic = elK_elastic(E,obj.v, obj.G)*(obj.E_material1-obj.E_material2);
                        
             heatCoefficient = 1;
              obj.dKheat =  elementK_heat(heatCoefficient)*(obj.K_material1-obj.K_material2);
        end
    
        
        % Calculate Elastic mod
        function e =  effectiveElasticProperties(obj, material1Fraction)
            e = material1Fraction*obj.E_material1+(1-material1Fraction)*obj.E_material2;
        end
        
        function ke = effectiveElasticKEmatrix(obj, material1Fraction)
            % Calculate E, then calculate the K element matrix
            E = effectiveElasticProperties(obj, material1Fraction);
            [ke]=elK_elastic(E,obj.v, obj.G);
            
        end
        
        
        
        % Calculate heat transfer coefficient
        function e =  effectiveHeatProperties(obj,material1Fraction)
             e = material1Fraction*obj.K_material1+(1-material1Fraction)*obj.K_material2;
        end

        % Calculate the heat conduction matrix
        function  kheat = effectiveHeatKEmatrix(obj, material1Fraction)
            heatCoefficient = obj.effectiveHeatProperties(material1Fraction);
            [kheat]=elementK_heat(heatCoefficient);            
        end
        
    end
    
    
    
end