clear all;
close all; 
clc;

%% -------------------- LECTURE DU FICHIER -----------------------
mon_fichier = xlsread('materiaux2');
mon_fichier2 = mon_fichier(3:end,:);

Instant = mon_fichier2(:,1);
Excitation = mon_fichier2(:,2); 

%% -------------------- COMPTER LES EXCITATIONS -------------------
nombre = sum((Excitation(2:end)==1) & (Excitation(1:end-1)==0));
fprintf('Nombre total d''excitations : %d\n', nombre);

%% ------------------ COLONNES ET MATERIAUX -----------------------
Colonn = [3,7,11,15,19,23,27,31];
noms_materiaux = {'beton','Granit','inox','verre','brique','sapin','platre','laine de verre'};

%% --------------------- PLOTS DES RÉPONSES -----------------------
for k = 1:length(Colonn)
    rep = mon_fichier2(:, Colonn(k));
    figure(k);
    plot(Instant, rep);
    xlabel('Instant');
    ylabel('Réponse');
    title(['Rep ', noms_materiaux{k}]);
    grid on;
end

%% ------------- DÉTECTION DES DÉBUTS D’EXCITATION ----------------
indices_debut = find((Excitation(2:end)==1) & (Excitation(1:end-1)==0)) + 1;
indices_debut = [indices_debut ; length(Excitation)+1];

nb_excitations = length(indices_debut)-1;

fprintf('\n\n========== STATISTIQUES PAR EXCITATION ==========\n');

%% ------------------ EXTRACTION DES STATISTIQUES -----------------
for k = 1:length(Colonn)

    Rep = mon_fichier2(:, Colonn(k));
    nom_materiau = strrep(noms_materiaux{k},' ','_');

    max_vals = zeros(nb_excitations,1);
    pentes   = zeros(nb_excitations,1);
    durees   = zeros(nb_excitations,1);

    fprintf('\n--- Matériau : %s ---\n', noms_materiaux{k});

    for j = 1:nb_excitations
        idx_start = indices_debut(j);
        idx_end   = indices_debut(j+1) - 1;

        seg = Rep(idx_start:idx_end);

        val_max = max(seg);
        val_min = min(seg);
        duree   = Instant(idx_end) - Instant(idx_start);
        pente   = (val_max - val_min) / duree;

        max_vals(j) = val_max;
        pentes(j)   = pente;
        durees(j)   = duree;

        fprintf("  Excitation %d : Durée=%.4f | Max=%.4f | Min=%.4f | Pente=%.4e\n", ...
                 j, duree, val_max, val_min, pente);
    end

    assignin('base', ['Max_' nom_materiau], max_vals);
    assignin('base', ['Diff_' nom_materiau], pentes);
    assignin('base', ['Duree_' nom_materiau], durees);

end

%% ------------------ CONSTRUCTION DES BASES PAR MATERIAU ------------------

materiaux = {'beton','Granit','inox','verre','brique','sapin','platre','laine_de_verre'};
All_durees_train = [];
All_max_train = [];
All_pentes_train = [];
All_diff_train = [];

All_durees_test = [];
All_max_test = [];
All_pentes_test = [];
All_diff_test = [];

for k = 1:length(materiaux)
    
    mat = materiaux{k};
    
    durees_mat = eval(['Duree_' mat]);
    max_mat    = eval(['Max_' mat]);
    pentes_mat = eval(['Diff_' mat]);
    
    % Diffusivité selon matériau
    switch mat
        case 'beton'
            diff_mat = 4.2e-7*ones(length(durees_mat),1);
        case 'Granit'
            diff_mat = 1.1e-6*ones(length(durees_mat),1);
        case 'inox'
            diff_mat = 4.0e-6*ones(length(durees_mat),1);
        case 'verre'
            diff_mat = 5.8e-7*ones(length(durees_mat),1);
        case 'brique'
            diff_mat = 5.3e-7*ones(length(durees_mat),1);
        case 'sapin'
            diff_mat = 9.63e-8*ones(length(durees_mat),1);
        case 'platre'
            diff_mat = 6.0e-7*ones(length(durees_mat),1);
        case 'laine_de_verre'
            diff_mat = 3.0e-7*ones(length(durees_mat),1);
    end
    
    N = length(durees_mat);
    Ntrain = round(2*N/3);
    
    % Sélection 2/3 pour entraînement, 1/3 pour test
    train_idx = 1:Ntrain;
    test_idx  = Ntrain+1:N;
    
    % Concaténation dans l'ordre
    All_durees_train = [All_durees_train; durees_mat(train_idx)];
    All_max_train    = [All_max_train; max_mat(train_idx)];
    All_pentes_train = [All_pentes_train; pentes_mat(train_idx)];
    All_diff_train   = [All_diff_train; diff_mat(train_idx)];
    
    All_durees_test = [All_durees_test; durees_mat(test_idx)];
    All_max_test    = [All_max_test; max_mat(test_idx)];
    All_pentes_test = [All_pentes_test; pentes_mat(test_idx)];
    All_diff_test   = [All_diff_test; diff_mat(test_idx)];
    
end

%% ------------------ CAS 1 : durées + max ------------------
% Normalisation
d_n_train = normalize(All_durees_train,'range');
m_n_train = normalize(All_max_train,'range');
diff_n_train = normalize(All_diff_train,'range');

d_n_test = normalize(All_durees_test,'range');
m_n_test = normalize(All_max_test,'range');

TrainData1 = [d_n_train m_n_train diff_n_train];

opt1 = genfisOptions('SubtractiveClustering');
opt1.ClusterInfluenceRange = 0.45;

fis1 = genfis([d_n_train m_n_train], diff_n_train, opt1);

% Correction MF
for i=1:numel(fis1.Inputs)
    for j=1:numel(fis1.Inputs(i).MembershipFunctions)
        p = fis1.Inputs(i).MembershipFunctions(j).Parameters;
        if p(2)<=1e-4, p(2)=1e-4; end
        fis1.Inputs(i).MembershipFunctions(j).Parameters = p;
    end
end

% Entraînement
train_opt1 = anfisOptions('InitialFIS',fis1);
train_opt1.EpochNumber = 120;
train_opt1.OptimizationMethod = 1;

fis_out1 = anfis(TrainData1, train_opt1);

% Validation
pred1_norm = evalfis(fis_out1,[d_n_test m_n_test]);
pred1 = pred1_norm*(max(All_diff_test)-min(All_diff_test)) + min(All_diff_test);

figure;
plot(All_diff_test,'b','LineWidth',1.5); hold on;
plot(pred1,'ro');
legend('Vraie diffusivité','Prédiction ANFIS');
title('CAS 1 : Validation (durées + max)');
grid on;

%% ------------------ CAS 2 : durées + pentes ------------------
% Normalisation
d2_n_train = normalize(All_durees_train,'range');
p2_n_train = normalize(All_pentes_train,'range');
diff2_n_train = normalize(All_diff_train,'range');

d2_n_test = normalize(All_durees_test,'range');
p2_n_test = normalize(All_pentes_test,'range');

TrainData2 = [d2_n_train p2_n_train diff2_n_train];

opt2 = genfisOptions('SubtractiveClustering');
opt2.ClusterInfluenceRange = 0.45;

fis2 = genfis([d2_n_train p2_n_train], diff2_n_train, opt2);

% Correction MF
for i=1:numel(fis2.Inputs)
    for j=1:numel(fis2.Inputs(i).MembershipFunctions)
        p = fis2.Inputs(i).MembershipFunctions(j).Parameters;
        if p(2)<=1e-4, p(2)=1e-4; end
        fis2.Inputs(i).MembershipFunctions(j).Parameters = p;
    end
end

% Entraînement
train_opt2 = anfisOptions('InitialFIS',fis2);
train_opt2.EpochNumber = 120;
train_opt2.OptimizationMethod = 1;

fis_out2 = anfis(TrainData2, train_opt2);

% Validation
pred2_norm = evalfis(fis_out2,[d2_n_test p2_n_test]);
pred2 = pred2_norm*(max(All_diff_test)-min(All_diff_test)) + min(All_diff_test);

figure;
plot(All_diff_test,'b','LineWidth',1.5); hold on;
plot(pred2,'r*');
legend('Vraie diffusivité','Prédiction ANFIS');
title('CAS 2 : Validation (durées + pentes)');
grid on;
