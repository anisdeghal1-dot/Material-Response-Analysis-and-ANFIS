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

%% ====================== PARTIE ANFIS OPTIMISÉE =====================

%% ----------------------- BASE D’ENTRAÎNEMENT -----------------------
mes_diffentrainement = [4.2e-7*ones(64,1) ;
                        5.3e-7*ones(64,1) ;
                        6.0e-7*ones(64,1) ;
                        4.0e-6*ones(64,1) ;
                        9.63e-8*ones(64,1)];

durees_tot = [Duree_beton ;
              Duree_brique ;
              Duree_platre ;
              Duree_inox ;
              Duree_sapin];

mesvalmax_entrainement = [Max_beton ;
                          Max_brique ;
                          Max_platre ;
                          Max_inox ;
                          Max_sapin];

%% ==================== NORMALISATION (OBLIGATOIRE) ====================
durees_n = normalize(durees_tot,'range');
max_n    = normalize(mesvalmax_entrainement,'range');
diff_n   = normalize(mes_diffentrainement,'range');

Dtrain = [durees_n max_n diff_n];   % data pour ANFIS

%% ------------------------- GENFIS ROBUSTE -------------------------
genOpt = genfisOptions('SubtractiveClustering');
genOpt.ClusterInfluenceRange = 0.9;  % amélioration validation

inFIS = genfis([durees_n max_n], diff_n, genOpt);

%% ------- Correction MF (sigma > 0) --------------------------------
for i = 1:numel(inFIS.Inputs)
    for j = 1:numel(inFIS.Inputs(i).MembershipFunctions)
        p = inFIS.Inputs(i).MembershipFunctions(j).Parameters;
        if p(2) <= 1e-4
            p(2) = 1e-4;
            inFIS.Inputs(i).MembershipFunctions(j).Parameters = p;
        end
    end
end

%% ------------------------- ANFIS TRAINING --------------------------
opt = anfisOptions('InitialFIS',inFIS);
opt.EpochNumber = 100;
opt.OptimizationMethod = 1;  
opt.DisplayErrorValues = 1;

outFIS = anfis(Dtrain, opt);

%% ------------------- AFFICHAGE TRAINING ----------------------------
figure;
plot(diff_n,'b','LineWidth',1.3); hold on;
plot(evalfis(outFIS,[durees_n max_n]),'r*');
legend('Training Data','ANFIS Output');
title('Performance ANFIS – Entraînement (normalisé)');

%% ---------------------- VALIDATION --------------------------------
mesvalmax_validation = [Max_Granit ;
                        Max_verre ;
                        Max_laine_de_verre];

mes_diffvalidation = [1.1e-6*ones(64,1) ;
                      5.8e-7*ones(64,1) ;
                      3.0e-7*ones(64,1)];

durees2_tot = [Duree_Granit ;
               Duree_verre ;
               Duree_laine_de_verre];

% Normalisation validation
durees_val_n = normalize(durees2_tot,'range');
max_val_n    = normalize(mesvalmax_validation,'range');

% prédiction normalisée
pred_norm = evalfis(outFIS,[durees_val_n max_val_n]);

% DÉNORMALISATION → comparaison vraie !
pred = pred_norm*(max(mes_diffvalidation)-min(mes_diffvalidation)) + min(mes_diffvalidation);

%% ----------------------- AFFICHAGE VALIDATION ----------------------
figure;
plot(mes_diffvalidation,'b','LineWidth',1.3); hold on;
plot(pred,'r*');
legend('Validation Data','Prédiction ANFIS optimisée');
title('Performance ANFIS – Validation améliorée');
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
%% ====================== PARTIE ANFIS OPTIMISÉE =====================
% ----------------------- BASE D’ENTRAÎNEMENT -----------------------

mes_diffentrainement = [4.2e-7*ones(64,1) ;
                        5.3e-7*ones(64,1) ;
                        6.0e-7*ones(64,1) ;
                        4.0e-6*ones(64,1) ;
                        9.63e-8*ones(64,1)];

durees_tot = [Duree_beton ;
              Duree_brique ;
              Duree_platre ;
              Duree_inox ;
              Duree_sapin];

mesvalmax_entrainement = [Max_beton ;
                          Max_brique ;
                          Max_platre ;
                          Max_inox ;
                          Max_sapin];

pentes_tot = [Diff_beton ;
              Diff_brique ;
              Diff_platre ;
              Diff_inox ;
              Diff_sapin];

%% ==================== CAS 1 : (durées + max) ====================

%% -------- NORMALISATION ---------
durees_n = normalize(durees_tot,'range');
max_n    = normalize(mesvalmax_entrainement,'range');
diff_n   = normalize(mes_diffentrainement,'range');

Dtrain = [durees_n max_n diff_n];

%% --------- GENFIS ROBUSTE ----------
genOpt = genfisOptions('SubtractiveClustering');
genOpt.ClusterInfluenceRange = 0.9;

inFIS = genfis([durees_n max_n], diff_n, genOpt);

%% ------ Correction MF -------
for i = 1:numel(inFIS.Inputs)
    for j = 1:numel(inFIS.Inputs(i).MembershipFunctions)
        p = inFIS.Inputs(i).MembershipFunctions(j).Parameters;
        if p(2) <= 1e-4
            p(2) = 1e-4;
            inFIS.Inputs(i).MembershipFunctions(j).Parameters = p;
        end
    end
end

%% -------- ANFIS TRAINING --------
opt = anfisOptions('InitialFIS',inFIS);
opt.EpochNumber = 100;
opt.OptimizationMethod = 1;
opt.DisplayErrorValues = 1;

outFIS = anfis(Dtrain, opt);

%% -------- Affichage --------
figure;
plot(diff_n,'b','LineWidth',1.3); hold on;
plot(evalfis(outFIS,[durees_n max_n]),'r*');
legend('Training Data','ANFIS Output');
title('ANFIS – Cas 1 (durées + max)');

%% --------- VALIDATION Cas 1 --------
mesvalmax_validation = [Max_Granit ;
                        Max_verre ;
                        Max_laine_de_verre];

mes_diffvalidation = [1.1e-6*ones(64,1) ;
                      5.8e-7*ones(64,1) ;
                      3.0e-7*ones(64,1)];

durees2_tot = [Duree_Granit ;
               Duree_verre ;
               Duree_laine_de_verre];

durees_val_n = normalize(durees2_tot,'range');
max_val_n    = normalize(mesvalmax_validation,'range');

pred_norm = evalfis(outFIS,[durees_val_n max_val_n]);

pred = pred_norm*(max(mes_diffvalidation)-min(mes_diffvalidation)) + min(mes_diffvalidation);

figure;
plot(mes_diffvalidation,'b','LineWidth',1.3); hold on;
plot(pred,'r*');
legend('Validation Data','Prédiction ANFIS Cas 1');
title('Validation – Cas 1 (durées + max)');


%% *********************************************************************
%% *********************************************************************
%% ============= CAS 2 : ANFIS AVEC (durées + pentes) =================
%% *********************************************************************
%% *********************************************************************

disp('============ CAS 2 : Entrées = durées + pentes ================')

%% -------- NORMALISATION Cas 2 -----------
durees2_n = normalize(durees_tot,'range');
pentes_n  = normalize(pentes_tot,'range');
diff2_n   = normalize(mes_diffentrainement,'range');

Dtrain2 = [durees2_n pentes_n diff2_n];

%% -------- Création FIS Cas 2 --------
genOpt2 = genfisOptions('SubtractiveClustering');
genOpt2.ClusterInfluenceRange = 0.85;   % réglage différent pour stabilité

inFIS2 = genfis([durees2_n pentes_n], diff2_n, genOpt2);

%% ----- Correction MF -----
for i = 1:numel(inFIS2.Inputs)
    for j = 1:numel(inFIS2.Inputs(i).MembershipFunctions)
        p = inFIS2.Inputs(i).MembershipFunctions(j).Parameters;
        if p(2) <= 1e-4
            p(2) = 1e-4;
            inFIS2.Inputs(i).MembershipFunctions(j).Parameters = p;
        end
    end
end

%% ------- Entraînement Cas 2 -------
opt2 = anfisOptions('InitialFIS',inFIS2);
opt2.EpochNumber = 120;
opt2.OptimizationMethod = 1;

outFIS2 = anfis(Dtrain2, opt2);

%% -------- Affichage Training Cas 2 ------
figure;
plot(diff2_n,'b','LineWidth',1.3); hold on;
plot(evalfis(outFIS2,[durees2_n pentes_n]),'r*');
legend('Training Data','ANFIS Output');
title('ANFIS – Cas 2 (durées + pentes)');

%% -------- VALIDATION Cas 2 --------
pentes_val = [Diff_Granit ;
              Diff_verre ;
              Diff_laine_de_verre];

pentes_val_n = normalize(pentes_val,'range');

pred2_norm = evalfis(outFIS2,[durees_val_n pentes_val_n]);

pred2 = pred2_norm*(max(mes_diffvalidation)-min(mes_diffvalidation)) + min(mes_diffvalidation);

figure;
plot(mes_diffvalidation,'b','LineWidth',1.3); hold on;
plot(pred2,'r*');
legend('Validation Data','Prédiction ANFIS Cas 2');
title('Validation – Cas 2 (durées + pentes)');

