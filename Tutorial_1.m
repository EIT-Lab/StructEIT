clc; clear; close all;

% Forward config

f_config = struct();
f_config.frequency = 50e3;        % Stimulation frequency
f_config.electrodes_rings = [16, 1]; % Number of electrodes and number of rings [n_elec, n_rings]
f_config.inj = [0, 1];            % Injection pattern
f_config.meas = [0, 1];           % Measurement pattern
f_config.options = {};            % Forward model options
f_config.amplitude = 10;          % Stimulation current amplitude (mA)
f_config.z_contact = 0.03;        % Electrode contact impedance
f_config.bkgnd = 0.5;             % Background conductivity


% root dir
dataroot="{dataset_path}/LIDC-IDRI-0001";

%%%%%%%%%%%% main %%%%%%%%%%%%

% === 1. build an eidors model ===
inv_mdl = mk_common_model('b3cr', [f_config.electrodes_rings(1), f_config.electrodes_rings(2)]);

% === 2. Replace the FEM mode ===
mesh = load(fullfile(dataroot, 'mesh_data.mat'));
inv_mdl.fwd_model.nodes     = double(mesh.nodes);
inv_mdl.fwd_model.boundary  = double(mesh.boundary);
inv_mdl.fwd_model.elems     = double(mesh.elements);

% === 3. set electrodes ===
e_info = load(fullfile(dataroot, 'electrode_points.mat'));
nodes  = double(e_info.electrode_data.nodes);
zc     = f_config.z_contact * ones(1, size(nodes, 1));

electrodes = arrayfun(@(i) struct('nodes', nodes(i,:), 'z_contact', zc(i)),1:size(nodes,1));
inv_mdl.fwd_model.electrode = electrodes;

% === 4. set stimulation ===
inv_mdl.fwd_model.stimulation = mk_stim_patterns( ...
    f_config.electrodes_rings(1), f_config.electrodes_rings(2), ...
    f_config.inj, ...
    f_config.meas, ...
    f_config.options, ...
    f_config.amplitude);

% === 5. set perturbation ===
data = struct(); 
data.filtered_indicesl = load(fullfile(dataroot,'left_lung_filtered_indices.txt')).';   % index of perturbation region 
data.filtered_indicesr = load(fullfile(dataroot, 'right_lung_filtered_indices.txt')).';
data.abnormal_valuelung    = 0.2;     % conductivity of perturbation region

img = mk_image(inv_mdl, f_config.bkgnd);
vh=fwd_solve(img);

img.elem_data(data.filtered_indicesl) = data.abnormal_valuelung ;
img.elem_data(data.filtered_indicesr) = data.abnormal_valuelung;
vi = fwd_solve(img);


% === 6. inverse  ===
vh_rel = ones(size(vh.meas)); 
delta_rel=(vi.meas-vh.meas)./vh.meas;
vi_rel = ones(size(vh.meas)) + delta_rel; 

inv2d = mk_common_gridmdl('backproj');  
imgr = inv_solve(inv2d, vh_rel, vi_rel);

show_fem(imgr);
