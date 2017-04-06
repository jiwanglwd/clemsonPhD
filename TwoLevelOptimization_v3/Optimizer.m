classdef Optimizer
    % Optimizer - class contains only the code that actually optimizes.
    %
    
    properties
    end
    
    methods
        % -------------------------------
        % TOPOOLOGY, SIMP METHOD
        % -------------------------------
        function DV = OptimizeTopology(obj,DV, config, matProp,masterloop)
            DV = DV.CalculateTopologySensitivity(config, matProp, masterloop);
            % normalize the sensitivies  by dividing by their max values.
            if (config.w1 ~= 1) % if we are using the heat objective
                temp1Max =-1* min(min(DV.sensitivityElastic));
                DV.sensitivityElastic = DV.sensitivityElastic/temp1Max;
                temp2Max = -1* min(min(DV.sensitivityHeat));
                DV.sensitivityHeat = DV.sensitivityHeat/temp2Max;
                DV.dc = config.w1*DV.sensitivityElastic+config.w2*DV.sensitivityHeat; % add the two sensitivies together using their weights
            else
                DV.dc = config.w1*DV.sensitivityElastic;
            end
            % FILTERING OF SENSITIVITIES
            [DV.dc]   = DV.check( config.nelx, config.nely,config.rmin,DV.x,DV.dc);
            % DESIGN UPDATE BY THE OPTIMALITY CRITERIA METHOD
            moveLimit=0.1;
            [DV.x]    = OC( config.nelx, config.nely,DV.x,config.totalVolume,DV.dc, DV, config,moveLimit);
        end
        
        % ----------------------------------
        % VOLUME FRACTION OPTIMIZATION
        % ----------------------------------
        function DV = OptimizeVolumeFraction(obj,DV,config, matProp, masterloop)
            DV = DV.CalculateMaterialGradientSensitivity(config, matProp, masterloop);
            
            DV =  DV.CalculateVolumeFractions(config,matProp);
            
            totalVolLocal = DV.currentVol1Fraction+ DV.currentVol2Fraction;
            fractionCurrent_V1Local = DV.currentVol1Fraction/totalVolLocal;
            targetFraction_v1 = config.v1/(config.v1+config.v2);
            
            % Normalize the sensitives.
            if (config.w1 ~= 1) % if we are using the heat objective
                temp1Max = max(max(abs(DV.sensitivityElastic)));
                DV.sensitivityElastic = DV.sensitivityElastic/temp1Max;
                temp2Max = max(max(abs(DV.sensitivityHeat)));
                DV.sensitivityHeat = DV.sensitivityHeat/temp2Max;
                
                g1 = config.w1*DV.sensitivityElastic+config.w2*DV.sensitivityHeat; % Calculate the weighted volume fraction change sensitivity.
            else
                g1 = config.w1*DV.sensitivityElastic;
            end
            
            % Filter the g1 sensitivies
            [g1]   = DV.check( config.nelx, config.nely,config.rmin,DV.x,g1);
            G1 = g1 - DV.lambda1 +1/(DV.mu1)*( targetFraction_v1-fractionCurrent_V1Local); % add in the lagrangian
            DV.w = DV.w+config.timestep*G1; % update the volume fraction.
            DV.w = max(min( DV.w,1),0);    % Don't allow the    vol fraction to go above 1 or below 0
            DV.lambda1 =  DV.lambda1 -1/(DV.mu1)*(targetFraction_v1-fractionCurrent_V1Local)*config.volFractionDamping;
        end
        
        % ----------------------------------
        % ORTHO DISTRIBUTION OPTIMIZATION
        % ----------------------------------
        %         function [] = OptimizeOrthoDistribution(obj,DV,config, matProp, masterloop)
        %             DV = DV.CalculateOthogonalDistributionSensitivity(config, matProp, masterloop);
        %             DV.sensitivityElastic = check( config.nelx, config.nely,config.rmin,DV.x,DV.sensitivityElastic);
        %             % move= 0.1* 20/(20+masterloop);
        %             move = config.orthDistMoveLimit;
        %             config.orthDistMoveLimit= config.orthDistMoveLimit* 10/(10+masterloop);
        %             %-----------------------
        %             %
        %             % Update design var.
        %             %-----------------------
        %             for ely = 1:config.nely
        %                 for elx = 1:config.nelx
        %                     if(DV.sensitivityElastic(ely,elx)<0.05)
        %                         DV.d(ely,elx) =  max(  DV.d(ely,elx)-move,config.minDorth);
        %                     end
        %
        %                     if(DV.sensitivityElastic(ely,elx)>0.05)
        %                         DV.d(ely,elx) =  min(  DV.d(ely,elx)+ move,config.maxDorth);
        %                     end
        %
        %                 end
        %             end
        %         end
        
        % ----------------------------------
        % ROTATION OPTIMIZATION
        % ----------------------------------
        function DV = OptimizeRotation(obj,DV,config, matProp, masterloop)
            %                 move= 0.1* 20/(20+masterloop);    
            % allow multiple loading cases.
            [~, t2] = size(config.loadingCase);
            
            epsilon = pi/180; % 1 DEGREES ACCURACY
            elementsInRow = config.nelx+1;
            
            for ely = 1:config.nely
                rowMultiplier = ely-1;
                for elx = 1:config.nelx
                    rhoSIMP =  DV.x(ely,elx);
                    if(rhoSIMP>config.noNewMesoDesignDensityCutOff)
                        
                        % -------------------
                        % STEP 1, GET THE DISPLACEMENT FOR THIS NODE
                        % -------------------
                        nodes1=[rowMultiplier*elementsInRow+elx;
                            rowMultiplier*elementsInRow+elx+1;
                            (rowMultiplier +1)*elementsInRow+elx+1;
                            (rowMultiplier +1)*elementsInRow+elx];
                        
                        xNodes = nodes1*2-1;
                        yNodes = nodes1*2;
                        NodeNumbers = [xNodes(1) yNodes(1) xNodes(2) yNodes(2) xNodes(3) yNodes(3) xNodes(4) yNodes(4)];
                        UallCaseForElement = DV.U(1:t2,NodeNumbers);
                        U = UallCaseForElement;
                        
                        % -------------------
                        % STEP 2, SET UP GOLDEN RATIO METHOD TO FIND
                        % OPTIMAL THETA FOR ROTATION
                        % -------------------
                        
                        n = 0;
                        x0 = config.minRotation; %lower_bracket;
                        x3 = config.maxRotation;% higher_bracket;
                        leng = x3-x0;
                        grleng = leng*config.gr ; % golden ratio lenth
                        x1 = x3 - grleng;
                        x2 = x0 + grleng;
                        rhoSIMP =  DV.x(ely,elx);
                        mat1Frac  =[];% DV.w(ely,elx);
                        Exx = DV.Exx(ely,elx);
                        Eyy = DV.Eyy(ely,elx);
                        
                        thetaSubSystem = DV.thetaSub(ely,elx);
                        penaltyValue=DV.penaltyTheta(ely,elx);
                        lagraMultiplier=DV.lambdaTheta(ely,elx);
                        
                        %                         orthD = DV.d(ely,elx);
                        fx1 = obj.EvaluteARotation(U,rhoSIMP, mat1Frac,Exx,Eyy,x1,thetaSubSystem,penaltyValue,lagraMultiplier,matProp, config);
                        fx2 = obj.EvaluteARotation(U,rhoSIMP, mat1Frac,Exx,Eyy,x2,thetaSubSystem,penaltyValue,lagraMultiplier,matProp, config);             
                        
                        debug = 0;                       
                        verbosity = 0;
                        
                        if(   debug == 1)
                            xtemp = x0:pi/180:x3;
                            ytemp = zeros(1, size(xtemp,2));
                            count = 1;
                            for thetaTemp = xtemp
                                ytemp(count)= obj.EvaluteARotation(U,rhoSIMP, mat1Frac,Exx,Eyy,thetaTemp,thetaSubSystem,penaltyValue,lagraMultiplier,matProp, config);
                                count = count+1;
                            end
                            figure(2)
                            plot(xtemp,ytemp);
                            nothin = 1;
                        end
                        
                        
                        while(1 == 1)
                            if(debug == 1 && verbosity ==1)
                                str = sprintf('loop# = %d, x0 = %f, x1 = %f, x2 = %f, x3 = %f, fx1 = %f, fx2 = %f\n', n, x0, x1, x2, x3, fx1, fx2); display(str);
                            end
                            
                            if(fx1<=fx2) % less than or equal
                                % x0 = x0; % x0 stays the same
                                x3 = x2; % the old x2 is now x3
                                x2 = x1; % the old x1 is now x2
                                fx2 = fx1;
                                leng = x3 - x0; % find the length of the interval
                                x1 = x3 - leng*config.gr; % find golden ratio of length, subtract it from the x3 value
                                fx1 = obj.EvaluteARotation(U,rhoSIMP, mat1Frac,Exx,Eyy,x1,thetaSubSystem,penaltyValue,lagraMultiplier,matProp, config);% calculate the fx
                                
                            elseif(fx1>fx2) % greater than
                                x0 = x1; % the old x1 is now x0
                                x1 = x2; % the old x2 is now the new x1
                                fx1 = fx2;
                                % x3 = x3; % x3 stays the same.
                                
                                leng = (x3 - x0); % find the length of the interval
                                x2 = x0 + leng*config.gr; % find golden ratio of length, subtract it from the x3 value
                                fx2 = obj.EvaluteARotation(U,rhoSIMP, mat1Frac,Exx,Eyy,x2,thetaSubSystem,penaltyValue,lagraMultiplier,matProp, config);  % calculate the fx
                            end
                            
                            % check to see if we are as close as we want
                            if(leng < epsilon || n>100)
                                break;
                            end
                            n = n +1; % increment
                            
                        end
                        
                        % -------------------
                        % STEP 3, RECORD THE OPTIMAL THETA
                        % -------------------
                        minTvalue = (x2 + x3)/2;
                        moveLimit = config.rotationMoveLimit;
                        
                        if(minTvalue>DV.t(ely,elx)+moveLimit)
                            DV.t(ely,elx)= DV.t(ely,elx)+moveLimit;
                        elseif(minTvalue<DV.t(ely,elx)-moveLimit)
                            DV.t(ely,elx)= DV.t(ely,elx)-moveLimit;
                        else
                            DV.t(ely,elx)=minTvalue;
                        end
                    end
                end
            end
        end
        
        % ---------------------------
        % EVALUTE THE OBJECTIVE FUNCTION FOR A ROTATION
        %----------------------------
        function lagrangianValue = EvaluteARotation(obj,U,topDensity, material1Fraction,Exx,Eyy,thetaSys,thetaSubSystem,penaltyValue,lagraMultiplier,matProp, config)
            K = matProp.getKMatrixTopExxYyyRotVars(config,topDensity,Exx, Eyy,thetaSys,material1Fraction);
            % LOOP OVER LOADING CASES.
            % U'S ROWS ARE UNIQUE LOADING CASES
            % EACH ROW CONTAINS 8 VALUES FOR THE 8 DOF OF THE ELEMENT
            % allow multiple loading cases.
            [~, t2] = size(config.loadingCase);
            term1=0;
            for i = 1:t2
                Ucase = U(i,:)';
                term1= term1+Ucase'*K*Ucase;
            end
            term1=-term1;
            
            term2 = penaltyValue/2*(thetaSys-thetaSubSystem)^2;
            term3 = lagraMultiplier*(thetaSys-thetaSubSystem);
            lagrangianValue=term1+term2+term3;
        end
        
        
        % ----------------------------------
        % E_xx and E_yy  OPTIMIZATION
        % ----------------------------------
        function [DV] = OptimizeExxEyy(obj,DV,config, matProp, masterloop)
            DV = DV.CalculateExxEyySensitivity(config, matProp, masterloop);
            DV.sensitivityElastic = DV.check( config.nelx, config.nely,config.rmin,DV.x,DV.sensitivityElastic);
            DV.sensitivityElasticPart2 = DV.check( config.nelx, config.nely,config.rmin,DV.x,DV.sensitivityElasticPart2);
            
            
            if(config.testingVerGradMaterail ==1)
                avgSensitivy = 0.5*( DV.sensitivityElastic+  DV.sensitivityElasticPart2);
                DV.sensitivityElastic =avgSensitivy;
                DV.sensitivityElasticPart2 =avgSensitivy;
            end
            
            %---------------------------
            % Add ATC terms 
            %
            % Add in term 2 and 3 of the numerator for the consistency
            % constraints for ATC optimization. 
            %---------------------------
%              term1Exx = DV.sensitivityElastic;
%              term1Eyy= DV.sensitivityElasticPart2;
             
            
            
            %-----------------------
            %
            % Update design var.
            %-----------------------
            l1 = 0; l2 = 1000000;% move = 0.2;
            
            E_target =(config.v1*matProp.E_material1+config.v2*matProp.E_material2)/(config.v1+config.v2);
            DV.targetAverageE = E_target;
            
            move = matProp.E_material1*0.05;
            minimum = matProp.E_material2;
            
            % ----------------
            % Exx
            % ----------------
            ExxNew = DV.Exx;
            EyyNew = DV.Eyy;
            
            
            offsetup = 10000;
            
 
            
            
            min1= min(min(min(DV.sensitivityElastic)),min(min(DV.sensitivityElasticPart2)));
            
%             % Prevent negative sensitivies.
%             if(min1<=0 )
%                 DV.sensitivityElastic = DV.sensitivityElastic-min1+1;
%                 DV.sensitivityElasticPart2 = DV.sensitivityElasticPart2-min1+1;
%             end
%             
            
            totalMaterial = sum(sum(DV.x));
            
            term1Exx = DV.sensitivityElastic;
            term1Eyy= DV.sensitivityElasticPart2;
            
            % ---------------------------------------------------
            %
            % TARGET E AS THE CONSTRAINT
            %
            % ---------------------------------------------------
            if(config.useTargetMesoDensity~=1)
                while (l2-l1 > 1e-4)
                    lmid = 0.5*(l2+l1);
                  
                    
                     %---------------------------
                    % Add ATC terms 
                    %
                    % Add in term 2 and 3 of the numerator for the consistency
                    % constraints for ATC optimization.
                    %---------------------------                    
                    term2Exx = DV.penaltyExx.*(ExxNew- DV.ExxSub);
                    term2Eyy = DV.penaltyEyy.*(EyyNew- DV.EyySub);
                    
                    term3Exx = DV.lambdaExx;
                    term3Eyy = DV.lambdaEyy;
                    
                    completeExx = term1Exx+term2Exx+term3Exx;
                    completeEyy = term1Eyy+term2Eyy+term3Eyy;
                    
                    % scale the sensitivies to make them easiler to work with if
                    % they are small.
                    min1= min(min(abs(completeExx)));
                    min2= min(min(abs(completeEyy)));
                    if(min1<=1000 || min2<=1000)
                        completeExx = completeExx*offsetup;
                        completeEyy = completeEyy*offsetup;
                    end
                    
                    % Don't allow negative
                     min1= min(min(completeExx));
                    min2= min(min(completeEyy));
                    min3 = min(min1,min2);
                    if(min1<=0 || min2<=0)
                        completeExx = completeExx-min3+1;
                        completeEyy = completeEyy-min3+1;
                    end
                    
                    
                    
                    
                    
                    
                    %                     ExxNew = max( minimum - EyyNew,  max(DV.Exx-move ,  min(  min(DV.Exx.*sqrt(DV.sensitivityElastic     ./lmid),DV.Exx+move ),matProp.E_material1)));
                    %                     EyyNew = max(minimum -  ExxNew,  max(DV.Eyy-move ,  min(  min(DV.Eyy.*sqrt(DV.sensitivityElasticPart2./lmid),DV.Eyy+move ),matProp.E_material1)));
                    ExxNew = max( minimum - EyyNew,  max(DV.Exx-move ,  min(  min(DV.Exx.*sqrt(completeExx     ./lmid),DV.Exx+move ),matProp.E_material1)));
                    EyyNew = max(minimum -  ExxNew,  max(DV.Eyy-move ,  min(  min(DV.Eyy.*sqrt(completeEyy./lmid),DV.Eyy+move ),matProp.E_material1)));
                    
                    
                    totalExx =DV.x.*ExxNew;
                    totalEyy = DV.x.* EyyNew;
                    avgE = (totalExx+totalEyy)/2;
                    averageElasticLocal= sum(sum(avgE))/totalMaterial;
                    %               averageElasticLocal = (sum(sum(EyyNew.*Xtemp))+sum(sum(ExxNew.*Xtemp)))/neSolid;
                    %               averageElasticLocal=averageElasticLocal/2; % Becuse Eyy and Exx are from one element, so to get the average divide by 2
                    if E_target- averageElasticLocal<0;
                        l1 = lmid;
                    else
                        l2 = lmid;
                    end
                end
            else
                % ---------------------------------------------------
                %
                % TARGET AVG MESO DENSITY AS CONSTRAINT.
                %
                % ---------------------------------------------------
                  [dDensityEyy, dDensityExx] = obj.GetdensitySensitivityEyyandExx(config, DV);
                while (l2-l1 > 1e-4)
                    lmid = 0.5*(l2+l1);
                    % xnew = max(0.01,max(x-move,min(1.,min(x+move,x.*sqrt(-dc./lmid)))));
                    
                    ExxNew = max( minimum - EyyNew,  max(DV.Exx-move ,  min(  min(DV.Exx.*sqrt(DV.sensitivityElastic     ./(dDensityExx*lmid)),DV.Exx+move ),matProp.E_material1)));
                    EyyNew = max(minimum -  ExxNew,  max(DV.Eyy-move ,  min(  min(DV.Eyy.*sqrt(DV.sensitivityElasticPart2./(dDensityEyy*lmid)),DV.Eyy+move ),matProp.E_material1)));
                    
                    sumDensity =0;
                   for i = 1:config.nelx
                      for j = 1:config.nely
                           eleDensity = DV.x(j,i)*max(ExxNew(j,i),EyyNew(j,i))/matProp.E_material1;
                           sumDensity =sumDensity+eleDensity;
                      end
                   end
                    sumDensity = sumDensity/(config.nelx*config.nely*config.totalVolume);
                 
                    if config.targetExxEyyDensity- sumDensity<0;
                        l1 = lmid;
                    else
                        l2 = lmid;
                    end
                end
                
            end
            
            if(config.testingVerGradMaterail ==1)
                averageNewE = 0.5*(ExxNew+EyyNew);
                ExxNew=averageNewE;
                EyyNew=averageNewE;
            end
            
%             if 1==1
%                  p = plotResults;
%                  p.PlotArrayGeneric( array, titleText)
%             end
         
            
            DV.Exx=ExxNew ;
            DV.Eyy=EyyNew ;
            
         
        end
        
        function [dDensityEyy, dDensityExx] = GetdensitySensitivityEyyandExx(obj,config, DV)
            dDensityExx = zeros(config.nely,config.nelx);
            dDensityEyy = zeros(config.nely,config.nelx);
            
            minSensitivity = 0.2;
            for i = 1:config.nelx
                for j = 1:config.nely
                    if(DV.Exx(j,i)>DV.Eyy(j,i))
                        dDensityExx(j,i) = 1;
                        dDensityEyy(j,i) = minSensitivity;
                    else
                        dDensityExx(j,i) = minSensitivity;
                        dDensityEyy(j,i) = 1;
                    end
                    %                    dDensityEyy =max(obj.Exx(j,i),obj.Eyy(j,i))/(matProp.E_material1-minE);
                end
            end
        end
        
        %-----------------------------------
        % Meso Optimization
        %-----------------------------------
        function [DVmeso] = MesoDensityOptimization(~,mesoConfig, DVmeso,old_muMatrix,penaltyValue,macroElemProps)
            ne = mesoConfig.nelx*mesoConfig.nely; % number of elements
%               dH_total=[DVmeso.d11;
%                     DVmeso.d12;
%                     DVmeso.d22;
%                     DVmeso.d33];
            Diff_Sys_Sub =  (macroElemProps.D_subSys- macroElemProps.D_sys);
            localD = zeros(3,3);
            for e = 1:ne
               
                [x,y]= DVmeso.GivenNodeNumberGetXY(e);
                xx=DVmeso.x(y,x); % =min(optimalEta, designVars.x+move)
%                  term1 = 10*xx^9;
%                  power = 1/4;
%                  term1 = power*xx^(power-1);
                term1=2*xx;
                
                
                
                rowIndex = [1,1,2,3];
                columnIndex = [1,2,2,3];
              
                dH = zeros(3,3);
                dH(1,1) = DVmeso.d11(y,x);
                dH(1,2) = DVmeso.d12(y,x);
                dH(2,2) = DVmeso.d22(y,x);
                dH(3,3) = DVmeso.d33(y,x);
                
                 localD(1,1) = DVmeso.De11(y,x);
                localD(1,2) = DVmeso.De11(y,x);
                localD(2,2) = DVmeso.De11(y,x);
                localD(3,3) = DVmeso.De11(y,x);
                
                Diff_Sys_Sub =  (localD- macroElemProps.D_sys);
                
                constraintCount = 0;
                term2=0;
%                 term1=0;
                for k = [1 2 3 ]
%                     term1=  dH(1,1)+  dH(1,2)+  dH(2,2)+  dH(3,3);
                    i = rowIndex(k);
                    j = columnIndex(k);
                    Ctemp = dH(i,j)*(-old_muMatrix(i,j)-penaltyValue*Diff_Sys_Sub(i,j));
                    term2 =term2 +Ctemp;
                    constraintCount=constraintCount+1;
                end
                
                dL = term1+term2;
                delta = 0.1;
                optimalEta=xx+delta*dL;
                move = 0.02;
                DVmeso.x(y,x)=  max(0.01,max(xx-move,min(1.,min(xx+move,optimalEta))));
                
                  DVmeso.x([10:13],[10:13])=1;
            end
        end
    end
end
    
