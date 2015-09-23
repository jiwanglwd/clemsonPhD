classdef Configuration
    
    properties
        % --------------------------------------
        % %% Settings
        % --------------------------------------------

        nelx = 80; % 40 # of elements in the x direcction
        nely = 40; % 18 number of elements in the y direction
        penal = 3; % penality used for the SIMP method
        rmin = 2; % smoothing radius for sensitivity smoothing. 
        
        % Optimization mode and configurations
        mode = 3; % 1 = topology only, 2 = material optimization only. 3 = both

       
        timestep = 0.1; % time step for the volume fraction update algorithm
        volFractionDamping = 1;
        iterationsPerPlot = 5;

        w1 = 0; % weight elastic for multi-objective
        w2;
        
        voidMaterialDensityCutOff = 0.1; % everything below this density is considered void. 
        
        
        doPlotHeat = 1;
        v1 = 1;
        v2 = 1;
        totalVolume; % = v1+v2;
        
        plotFinal = 1;
        plotToCSVFile = 1;
        
        iterationNum=0; %  used for parallel computing. 

        
    end
    
    
    methods
        
        function obj = Configuration()
             if obj.mode ==1    
                obj.doPlotHeat = 1;
                obj.v1 = 0.2; % fraction of material 1 to use
                obj.v2 = 0.2; % fraction of material 2 to use
                 obj.doPlotHeat = 0;
            elseif obj.mode ==2
                obj.v1 = 0.5; % fraction of material 1 to use
                obj.v2 = 0.5; % fraction of material 2 to use
                 obj.doPlotHeat = 0;

            elseif obj.mode ==3
                 obj.v1 = 0.2; % fraction of material 1 to use
                 obj.v2 = 0.05; % fraction of material 2 to use
                 obj.doPlotHeat = 0;

             end
            
            obj.w2  = 1- obj.w1; % weight heat transfer
            obj.totalVolume = obj.v1+obj.v2;
            
        end
        
    end
end