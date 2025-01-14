function [ desired_state ] = trajectory_generator(t, qn, map, path)
% TRAJECTORY_GENERATOR: Turn a Dijkstra or A* path into a trajectory
%
% NOTE: This function would be called with variable number of input
% arguments. In init_script, it will be called with arguments
% trajectory_generator([], [], map, path) and later, in test_trajectory,
% it will be called with only t and qn as arguments, so your code should
% be able to handle that. This can be done by checking the number of
% arguments to the function using the "nargin" variable, check the
% MATLAB documentation for more information.
%
% map: The map structure returned by your load_map function
% path: This is the path returned by your planner (dijkstra function)

% desired_state: Contains all the information that is passed to the
% controller, as in phase 2
% It is suggested to use "persistent" variables to store map and path
% during the initialization call of trajectory_generator, e.g.
persistent mapquad
persistent pathall
persistent coefficient
persistent finalpath
persistent timepoint
persistent timesegment


if nargin ~= 2
    
    mapquad = map;
    pathall = path;
    pathqn = pathall{1};
    ttotal = 10;
    
    xy_res = map.resolution(1);
    basicdata  = map.basicdata;
    [rowbasicdata ~] = size(basicdata);
    if rowbasicdata >= 2
        block = basicdata(2:rowbasicdata,:);
    else
        block = [];
    end
    
    finalpath = simplify_path(pathqn,block,mapquad);
    
    %----------------------------------------------------------------------    
    %If use quintic function, then the order of the system should be three.
    %This means the number of the freedom of the system is 6m where m is the
    %number of the segments of the path. m is equal to the "pathlength" - 1.
    [pathlength ~] = size(finalpath);
    m = pathlength - 1;
    %The matrice that describes all the constraints of the system is named as
    %constraints in this file
    constraints = zeros (6*m,6*m);
    conditions = zeros (6*m ,3);
    % x    = a0 + a1*t + a2*t^2 + a3*t^3   + a4*t^4     + a5*t^5   ; position
    % x'   = 0  + a1   + 2*a2*t + 3*a3*t^2 + 4*a4*t^3   + 5*a5*t^4 ; velocity
    % x''  = 0  + 0    + 2*a2   + 6*a3*t   + 12*a4*t^2  + 20*a5*t^3; acceleration
    %constraint conditions = constraints * coefficient matrix
    %constraints and constraints condition for the start position
    for i = 1:m
        previous = finalpath(i,:);
        afterward = finalpath(i+1,:);
        distance(i,:) = norm(- previous + afterward);
        if (distance(i,:) <= 1)
            timesegment(i,1) = distance(i,:);
            timesegment(i,2) = 1;%this is the flag for jumping step
        else
            timesegment(i,:) = sqrt(distance(i,:))*2;
            timesegment(i,2) = 0;%this is the flag for the normal one
        end
    end
    
    %timesegment = distance;
    time_temp = 0;
    timepoint = zeros(m,1);
    for i = 1:m
        time_temp = time_temp+timesegment(i,1);
        timepoint(i,1)   = time_temp;
    end
    timepoint = [0;timepoint];
    condition = zeros(6*m,3);
    constraints = zeros(6*m,6);
    
    for j = 1:m
        tstart = 0;
        tend   = timesegment(j,1);
        constraints(6*j-5,:) = [1 tstart tstart^2 tstart^3   tstart^4    tstart^5   ];
        constraints(6*j-4,:) = [0 1      2*tstart 3*tstart^2 4*tstart^3  5*tstart^4 ];
        constraints(6*j-3,:) = [0 0      2        6*tstart   12*tstart^2 20*tstart^3];
        constraints(6*j-2,:) = [1 tend   tend^2   tend^3     tend^4      tend^5     ];
        constraints(6*j-1,:) = [0 1      2*tend   3*tend^2   4*tend^3    5*tend^4   ];
        constraints(6*j  ,:) = [0 0      2        6*tend     12*tend^2   20*tend^3  ];
        condition  (6*j-5,:) = finalpath(j,:);
        condition  (6*j-2,:) = finalpath(j+1,:);
        inverse = inv(constraints(6*j-5:6*j,1:6));
        coefficient_temp = inverse*condition(6*j-5:6*j,1:3);
        coefficient(6*j-5:6*j,1:3) = coefficient_temp;
        
    end
    
    % coefficient matrix = inv(constraints) * constraint conditions
elseif nargin == 2
    
    [lengthtime widthtime] = size(timepoint);
    length = lengthtime - 1;
    desired_state.yaw = 0;
    desired_state.yawdot = 0;
    for i = 1 : length
        if t >= timepoint(i) && t < timepoint(i+1)&& timesegment(i,2) == 0
            currenttstart = timepoint(i);
            state = [1 (t-currenttstart) (t-currenttstart)^2 (t-currenttstart)^3   (t-currenttstart)^4    (t-currenttstart)^5;
                0 1 2*(t-currenttstart) 3*(t-currenttstart)^2 4*(t-currenttstart)^3  5*(t-currenttstart)^4;
                0 0 2   6*(t-currenttstart)   12*(t-currenttstart)^2 20*(t-currenttstart)^3] * coefficient(6*i-5:6*i,1:3);
        elseif t >= timepoint(i) && t < timepoint(i+1)&& timesegment(i,2) == 1
            state(1,:) = finalpath(i+1,:);
            state(2,:) = [0 0 0];
            state(3,:) = [0 0 0];
        elseif t >= timepoint(lengthtime)
            state(1,:) = finalpath(lengthtime,:);
            state(2,:) = [0 0 0];
            state(3,:) = [0 0 0];
        end
    end
    desired_state.pos = state(1,:)';
    desired_state.vel = state(2,:)';
    desired_state.acc = state(3,:)';
end










