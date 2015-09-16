function combinedTopologyOptimization()
% --------------------------------------
% %% Settings
% --------------------------------------------
settings = Configuration;

% material properties Object
matProp = MaterialProperties;

% ---------------------------------
% Initialization of varriables
% ---------------------------------
designVars = DesignVars(settings);
designVars.x(1:settings.nely,1:settings.nelx) = settings.totalVolume; % artificial density of the elements
designVars.w(1:settings.nely,1:settings.nelx)  = 1; % actual volume fraction composition of each element

designVars.temp1(1:settings.nely,1:settings.nelx) = 0;
designVars.temp2(1:settings.nely,1:settings.nelx) = 0;
designVars.g1elastic(1:settings.nely,1:settings.nelx) = 0;
designVars.g1heat(1:settings.nely,1:settings.nelx) = 0;

designVars = designVars.CalcIENmatrix(settings);
designVars =  designVars.CalcElementLocation(settings);
designVars = designVars.PreCalculateXYmapToNodeNumber(settings);

% recvid=1;       %turn on or off the video recorder
% %% FEA and Elastic problem initialization
% if recvid==1
%     vidObj = VideoWriter('results_homog_level_set.avi');    %Prepare the new file for video
%     vidObj.FrameRate = 50;
%     vidObj.Quality = 100;
%     open(vidObj);
%     vid=1;
% end


loop = 0; 
change = 1.;
elementsInRow = settings.nelx+1;
% START ITERATION
while change > 0.01  
  loop = loop + 1;
  designVars.xold = designVars.x;
% FE-ANALYSIS
  [U]=FE_elasticV2(designVars, settings, matProp);   
  [U_heatColumn]=temperatureFEA_V3(designVars, settings, matProp,loop);   
% OBJECTIVE FUNCTION AND SENSITIVITY ANALYSIS
% [KE] = elK_elastic(matProp);


 %[KEHeat] = lkHeat;
   
            
            c = 0.; % c is the objective. Total strain energy


        for ely = 1:settings.nely
            rowMultiplier = ely-1;
            for elx = 1:settings.nelx
        %           n1 = (nely+1)*(elx-1)+ely; 
        %           n2 = (nely+1)* elx   +ely;
        %           Ue = U([2*n1-1;2*n1; 2*n2-1;2*n2; 2*n2+1;2*n2+2; 2*n1+1;2*n1+2],1);
                   nodes1=[rowMultiplier*elementsInRow+elx;
                            rowMultiplier*elementsInRow+elx+1;
                            (rowMultiplier +1)*elementsInRow+elx+1;
                            (rowMultiplier +1)*elementsInRow+elx];

                        
                    % Get the element K matrix for this partiular element
                    KE = matProp.effectiveElasticKEmatrix(  designVars.w(ely,elx));
                    KEHeat = matProp.effectiveHeatKEmatrix(  designVars.w(ely,elx));


                    xNodes = nodes1*2-1;
                    yNodes = nodes1*2;

                 % NodeNumbers = union(xNodeNumbers,yNodeNumbers);
                  NodeNumbers = [xNodes(1) yNodes(1) xNodes(2) yNodes(2) xNodes(3) yNodes(3) xNodes(4) yNodes(4)];

                 % NodeNumbers = union(xNodeNumbers,yNodeNumbers);
                  Ue = U(NodeNumbers,:);
                  U_heat = U_heatColumn(nodes1,:);

                  c = c + settings.w1*designVars.x(ely,elx)^settings.penal*Ue'*KE*Ue;
                  c = c + settings.w2*designVars.x(ely,elx)^settings.penal*U_heat'*KEHeat*U_heat;
              

                  % for the x location
                  % The first number is the row - "y value"
                  % The second number is the column "x value"

                %  dc(ely,elx) = -penal*x(ely,elx)^(penal-1)*Ue'*KE*Ue; % objective sensitivity, partial of c with respect to x

                % Temps are the sensitivies 
                 designVars.temp1(ely,elx) = -settings.penal*designVars.x(ely,elx)^(settings.penal-1)*Ue'*matProp.dKelastic*Ue; % objective sensitivity, partial of c with respect to x
                 designVars.temp2(ely,elx) = -settings.penal*designVars.x(ely,elx)^(settings.penal-1)*U_heat'*KEHeat*U_heat;
                 
                 % Calculate the derivative with respect to a material
                 % volume fraction composition change (not density change)
                 designVars.g1elastic(ely,elx) = designVars.x(ely,elx)^(settings.penal)*Ue'*matProp.dKelastic*Ue;
                 designVars.g1heat(ely,elx) = designVars.x(ely,elx)^(settings.penal)*U_heat'*matProp.dKheat*U_heat;


                   %dc(ely,elx) = w1*temp1+w2*temp2;

            end
        end

        %for loopTopology = 1:10
        if 1==0
            % normalize the sensitivies  by dividing by their max values. 
            temp1Max =-1* min(min(designVars.temp1));
            designVars.temp1 = designVars.temp1/temp1Max;
            temp2Max = -1* min(min(designVars.temp2));
            designVars.temp2 = designVars.temp2/temp2Max;

            designVars.dc = settings.w1*designVars.temp1+settings.w2*designVars.temp2; % add the two sensitivies together using their weights 

           



            % FILTERING OF SENSITIVITIES
              [designVars.dc]   = check(settings.nelx,settings.nely,settings.rmin,designVars.x,designVars.dc);    
            % DESIGN UPDATE BY THE OPTIMALITY CRITERIA METHOD
              [designVars.x]    = OC(settings.nelx,settings.nely,designVars.x,settings.totalVolume,designVars.dc); 
            % PRINT RESULTS
              change = max(max(abs(designVars.x-designVars.xold)));
              disp([' It.: ' sprintf('%4i',loop) ' Obj.: ' sprintf('%10.4f',c) ...
                   ' Vol.: ' sprintf('%6.3f',sum(sum(designVars.x))/(settings.nelx*settings.nely)) ...
                    ' ch.: ' sprintf('%6.3f',change )])
                
            p = plotResults;
            p.plotTopAndFraction(designVars); % plot the results. 
           
           
        end
        
        %for loopMaterialGradient = 1:10
        if 1==1
            
              g1 = settings.w1*designVars.g1elastic+settings.w2*designVars.g1heat; % Calculate the weighted volume fraction change sensitivity. 
              
              G1 = g1 - lambda1 +1/(mu1)*( settings.v1-percentV1Local);
              
              designVars.w = designVars.w+settings.timestep*G1; % update the volume fraction. 
              
              p = plotResults;
              p.plotTopAndFraction(designVars); % plot the results. 
             
              % PRINT RESULTS
              %change = max(max(abs(designVars.x-designVars.xold)));
              
              disp([' It.: ' sprintf('%4i',loop) ' Obj.: ' sprintf('%10.4f',c) ...
                   ' Vol.: ' sprintf('%6.3f',sum(sum(designVars.x))/(settings.nelx*settings.nely)) ...
                    ' ch.: ' sprintf('%6.3f',change )])
%            
            
            
        end
end 

% if recvid==1
%          close(vidObj);  %close video

%%%%%%%%%% OPTIMALITY CRITERIA UPDATE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [xnew]=OC(nelx,nely,x,volfrac,dc)  
l1 = 0; l2 = 100000; move = 0.2;
while (l2-l1 > 1e-4)
  lmid = 0.5*(l2+l1);
  xnew = max(0.001,max(x-move,min(1.,min(x+move,x.*sqrt(-dc./lmid)))));
  
%   desvars = max(VOID, max((x - move), min(SOLID,  min((x + move),(x * (-dfc / lammid)**self.eta)**self.q))))
 
  if sum(sum(xnew)) - volfrac*nelx*nely > 0;
    l1 = lmid;
  else
    l2 = lmid;
  end
end
%%%%%%%%%% MESH-INDEPENDENCY FILTER %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [dcn]=check(nelx,nely,rmin,x,dc)
dcn=zeros(nely,nelx);
for i = 1:nelx
  for j = 1:nely
    sum=0.0; 
    for k = max(i-floor(rmin),1):min(i+floor(rmin),nelx)
      for l = max(j-floor(rmin),1):min(j+floor(rmin),nely)
        fac = rmin-sqrt((i-k)^2+(j-l)^2);
        sum = sum+max(0,fac);
        dcn(j,i) = dcn(j,i) + max(0,fac)*x(l,k)*dc(l,k);
      end
    end
    dcn(j,i) = dcn(j,i)/(x(j,i)*sum);
  end
end
%%%%%%%%%% FE-ANALYSIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [KE]=lkHeat

KE= [0.6667   -0.1667   -0.3333   -0.1667;
   -0.1667    0.6667   -0.1667   -0.3333;
   -0.3333   -0.1667    0.6667   -0.1667;
   -0.1667   -0.3333   -0.1667    0.6667];

% function [U]=FE(nelx,nely,x,penal,F,fixeddofs)
% [KE] = lk; 
% K = sparse(2*(nelx+1)*(nely+1), 2*(nelx+1)*(nely+1));
% %F = sparse(2*(nely+1)*(nelx+1),1);
% U = zeros(2*(nely+1)*(nelx+1),1);
% for elx = 1:nelx
%   for ely = 1:nely
%     n1 = (nely+1)*(elx-1)+ely; 
%     n2 = (nely+1)* elx   +ely;
%     edof = [2*n1-1; 2*n1; 2*n2-1; 2*n2; 2*n2+1; 2*n2+2; 2*n1+1; 2*n1+2];
%     K(edof,edof) = K(edof,edof) + x(ely,elx)^penal*KE;
%   end
% end
% % DEFINE LOADS AND SUPPORTS (HALF MBB-BEAM)
% % F(2,1) = -1;
% % fixeddofs   = union([1:2:2*(nely+1)],[2*(nelx+1)*(nely+1)])
% alldofs     = [1:2*(nely+1)*(nelx+1)];
% freedofs    = setdiff(alldofs,fixeddofs);
% % SOLVING
% U(freedofs,:) = K(freedofs,freedofs) \ F(freedofs,:);      
% U(fixeddofs,:)= 0;
%%%%%%%%%% ELEMENT STIFFNESS MATRIX %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [KE]=lk
% 
% KE= [0.6667   -0.1667   -0.3333   -0.1667;
%    -0.1667    0.6667   -0.1667   -0.3333;
%    -0.3333   -0.1667    0.6667   -0.1667;
%    -0.1667   -0.3333   -0.1667    0.6667];