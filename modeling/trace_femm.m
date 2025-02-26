%load all the FEMM functions. the folder with all the M files for FEMM should have already been added to path 
addpath('c:\\femm42\\mfiles');
openfemm;

function make_round_turn(x, y, radius, material, circuit)
	x1 = x - radius;
	x2 = x + radius; 
	y1 = y; 
	y2 = y; 

	mi_drawarc(x1, y1, x2, y2, 180, 10);
	mi_addarc(x2, y2, x1, y1, 180, 10);

	mi_addblocklabel(x,y);
	mi_selectlabel(x,y);
	%comment out first for automeshing
	mi_setblockprop(material, 1, 0, circuit, 0, 0, 1); 
	%mi_setblockprop(material, 0, 10E-3, circuit, 0, 0, 1);
	mi_clearselected;
endfunction

function make_rectangle(x, y, w, h, material, circuit)
	x1 = x - w/2
	y1 = y - h/2
	x2 = x + w/2
	y2 = y - h/2
	x3 = x + w/2
	y3 = y + h/2
	x4 = x - w/2
	y4 = y + h/2

	mi_drawpolygon([x1,y1;x2,y2;x3,y3;x4,y4])

	mi_addblocklabel(x,y);
	mi_selectlabel(x,y);
	%comment out first for automeshing
	mi_setblockprop(material, 1, 0, circuit, 0, 0, 1); 
	%mi_setblockprop(material, 0, 10E-3, circuit, 0, 0, 1);
	mi_clearselected;
endfunction

% materials 
copper_conductivity = 58.0;

%parameters. All dimentions in mm 
w_trace = 1; % width trace 
h_trace = 0.035; %thickness of 1oz copper
h_pcb = 1.6 - 2* h_trace; % 1.6mm thick pcb 
freq = 100000;
probe_offset = 0.05; % distance from probe tip to wire

%constants 
i_wire = 1;
sensor_offset = 1.6; %offset of from sensor to end of probe tip
probe_sensitivity_H = 0.8; %volts/gauss
probe_sensitivity_L = 0.2; 
probe_max_G = 6.0; % max field strength for sensor saturation


%create new document 
% "0 for a magnetics problem, 1 for an electrostatics problem, 2 for a heat flow problem, or 3 for a current flow problem"
newdocument(0);

% Define the problem type.  Magnetostatic; Units of mm; Axisymmetric; 
% Precision of 10^(-8) for the linear solver; a placeholder of 0 for 
% the depth dimension, and an angle constraint of 30 degrees

%(freq,units,type,precision,depth,minangle,(acsolver))
mi_probdef(freq, 'millimeters', 'planar', 1.e-8, 100, 30);

%define materials and circuits 

mi_addmaterial('Air', 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0);
mi_addmaterial('Copper', 1, 1, 0, 0, copper_conductivity, 0, 0, 1, 0, 0, 0);

mi_addcircprop('iwire', i_wire, 1);
mi_addcircprop('iwireN', -1*i_wire, 1);

%air 
mi_addblocklabel(0, -2);
mi_selectlabel(0,-2);
% (’blockname’, automesh, meshsize, ’incircuit’, magdir, group, turns) 
mi_setblockprop('Air', 1, 0, '<None>', 0, 0, 0);
mi_clearselected

% top trace
make_rectangle(0, h_pcb/2 + h_trace/2, w_trace, h_trace, 'Copper', 'iwire');
% return path
make_rectangle(0, -h_pcb/2- h_trace/2, w_trace * 20, h_trace, 'Copper', 'iwireN');


%boundary condition 
mi_makeABC(5, 50, 0,0, 0);
mi_saveas('wire.fem');

% mesh 
smartmesh(1);
mi_createmesh();


%run simulation 
mi_analyze();
mi_loadsolution();

%obtain B field

measuredB = abs(mo_getb(0,(h_pcb/2 + probe_offset + sensor_offset))(1));
measuredG = measuredB ./ 1E-4; % convert tesla to gauss
current_sensitivity_H = measuredG * probe_sensitivity_H;
current_sensitivity_L = measuredG * probe_sensitivity_L;

probe_max_current = probe_max_G ./ measuredG;
disp("Field Strength:");
disp(measuredG);
disp("Sensitivity High Gain:");
disp(current_sensitivity_H);
disp("Sensitivity Low Gain:");
disp(current_sensitivity_L);
disp("Max Current:");
disp(probe_max_current);


