%% ================================================================
%   APPROCHE 2 – ANFIS SUR LES MATERIAUX (CORRIGE ET STABLE)
%   Entrées  : Durée + Pente
%   Sortie   : Diffusivité
% ================================================================
clear;
close all;
clc;

%% -------------------- LECTURE DU FICHIER ------------------------
data = xlsread('materiaux2');
data = data(3:end,:);

t = data(:,1);
u = data(:,2);

%% -------------------- DETECTION DES EXCITATIONS -----------------
idx_start = find(u(2:end)==1 & u(1:end-1)==0) + 1;
idx_start = [idx_start; length(u)+1];
NbExc = length(idx_start)-1;

fprintf('Nombre total d''excitations : %d\n', NbExc);

%% -------------------- COLONNES MATERIAUX ------------------------
cols  = [3 7 11 15 19 23 27 31];
names = {'beton','Granit','inox','verre','brique','sapin','platre','laine_de_verre'};

%% -------------------- EXTRACTION PARAMETRES ---------------------
for k = 1:length(cols)

    y = data(:,cols(k));

    Duree = zeros(NbExc,1);
    Pente = zeros(NbExc,1);

    for i = 1:NbExc
        i1 = idx_start(i);
        i2 = idx_start(i+1)-1;

        seg = y(i1:i2);

        vmax = max(seg);
        vmin = min(seg);
        duree = t(i2) - t(i1);
        pente = (vmax - vmin) / duree;

        Duree(i) = duree;
        Pente(i) = pente;
    end

    assignin('base',['Duree_' names{k}],Duree);
    assignin('base',['Pente_' names{k}],Pente);
end

%% -------------------- DIFFUSIVITES REELLES ----------------------
Diff = [
    4.2e-7  * ones(54,1);   % beton
    1.1e-6  * ones(54,1);   % granit
    4.0e-6  * ones(54,1);   % inox
    5.8e-7  * ones(54,1);   % verre
    5.3e-7  * ones(54,1);   % brique
    9.63e-8 * ones(54,1);   % sapin
    6.0e-7  * ones(54,1);   % platre
    3.0e-7  * ones(54,1)    % laine de verre
];

%% -------------------- DONNEES GLOBALES --------------------------
Duree_all = [
    Duree_beton; Duree_Granit; Duree_inox; Duree_verre;
    Duree_brique; Duree_sapin; Duree_platre; Duree_laine_de_verre
];

Pente_all = [
    Pente_beton; Pente_Granit; Pente_inox; Pente_verre;
    Pente_brique; Pente_sapin; Pente_platre; Pente_laine_de_verre
];

%% -------------------- SEPARATION 2/3 – 1/3 ----------------------
Nmat = 8;
Nexc = 54;
Ntrain = 36;

idx_train = [];
idx_val   = [];

for k = 0:Nmat-1
    base = k*Nexc;
    idx_train = [idx_train; (1:Ntrain)' + base];
    idx_val   = [idx_val; (Ntrain+1:Nexc)' + base];
end

Xtrain_raw = [Duree_all(idx_train) Pente_all(idx_train)];
Ytrain_raw = Diff(idx_train);

Xval_raw   = [Duree_all(idx_val)   Pente_all(idx_val)];
Yval_raw   = Diff(idx_val);

%% -------------------- NORMALISATION -----------------------------
Xtrain = normalize(Xtrain_raw,'range');
Xval   = normalize(Xval_raw,'range');

Ymin = min(Ytrain_raw);
Ymax = max(Ytrain_raw);
Ytrain = (Ytrain_raw - Ymin) / (Ymax - Ymin);

%% -------------------- GENFIS ------------------------------------
genOpt = genfisOptions('GridPartition');
genOpt.NumMembershipFunctions = 3;
genOpt.InputMembershipFunctionType = 'gaussmf';

fis0 = genfis(Xtrain, Ytrain, genOpt);

%% -------------------- ENTRAINEMENT ------------------------------
opt = anfisOptions('InitialFIS', fis0);
opt.EpochNumber = 80;
opt.DisplayErrorValues = 1;

[fis, trainError] = anfis([Xtrain Ytrain], opt);

%% -------------------- PREDICTION + DENORMALISATION --------------
Ypred_norm = evalfis(Xval, fis);
Ypred = Ypred_norm * (Ymax - Ymin) + Ymin;

%% -------------------- AFFICHAGE RESULTATS -----------------------
figure;
plot(Yval_raw,'b','LineWidth',1.5); hold on;
plot(Ypred,'r*');
legend('Diffusivité réelle','Diffusivité estimée');
xlabel('Échantillons');
ylabel('Diffusivité');
title('Approche 2 – ANFIS (Durée + Pente)');
grid on;

%% -------------------- ERREUR RELATIVE ---------------------------
err_rel = abs(Ypred - Yval_raw) ./ Yval_raw;
fprintf('Erreur relative moyenne = %.2f %%\n', mean(err_rel)*100);

disp('APPROCHE 2 ANFIS TERMINEE SANS ERREUR');
