clear all;
close all; 
clc;

% Lecture du fichier
mon_fichier = xlsread('materiaux2');
mon_fichier2 = mon_fichier(3:end,:);
Instant = mon_fichier2(:,1);
Excitation = mon_fichier2(:,2); 

nombre = 0;
for i = 2:length(Instant)
    if (Excitation(i) == 1) && (Excitation(i-1) == 0)
        nombre = nombre + 1;
    end
end
fprintf('Nombre total d''excitations : %d\n', nombre);

% Colonnes et noms des matériaux
Colonn = [3,7,11,15,19,23,27,31];
noms_materiaux = {'beton','Granit','inox','verre','brique','sapin','platre','laine de verre'};

for k = 1:length(Colonn)
    rep = mon_fichier2(:, Colonn(k));
    figure(k+1);
    plot(Instant, rep);
    xlabel('Instant');
    ylabel('Rep Alea');
    title(['Rep Alea ', noms_materiaux{k}]);
    grid on;
end

indices_debut = [];
for i = 2:length(Excitation)
    if (Excitation(i) == 1) && (Excitation(i-1) == 0)
        indices_debut = [indices_debut; i];
    end
end
indices_debut = [indices_debut; length(Excitation)+1]; % Fin de la dernière excitation

fprintf('\n\n========== STATISTIQUES PAR EXCITATION ==========\n');

for k = 1:length(Colonn)
    Rep = mon_fichier2(:, Colonn(k));
    fprintf('\n--- Matériau : %s ---\n', noms_materiaux{k});

    durees = [];
    max_vals = [];
    min_vals = [];
    pentes = [];

    for j = 1:length(indices_debut)-1
        idx_start = indices_debut(j);
        idx_end = indices_debut(j+1) - 1;

        segment = Rep(idx_start:idx_end);

        val_max = max(segment);
        val_min = min(segment);
        duree = Instant(idx_end) - Instant(idx_start);
        pente = (val_max - val_min) / duree;

        durees = [durees; duree];
        max_vals = [max_vals; val_max];
        min_vals = [min_vals; val_min];
        pentes = [pentes; pente];

        fprintf('  Excitation %d : Durée = %.3f s | Max = %.3f | Min = %.3f | Pente = %.3f\n', ...
                j, duree, val_max, val_min, pente);
    end

    R1 = corrcoef(durees, max_vals);
    corr_duree_max = R1(1,2);

    R2 = corrcoef(durees, pentes);
    corr_duree_pente = R2(1,2);

    fprintf('  Corrélation durée vs max pour %s : %.3f\n', noms_materiaux{k}, corr_duree_max);
    fprintf('  Corrélation durée vs pente pour %s : %.3f\n', noms_materiaux{k}, corr_duree_pente);

    figure
    subplot(1,2,1);
    scatter(durees, max_vals, 'filled');
    xlabel('Durée de l''excitation (s)');
    ylabel('Valeur max de la réponse');
    title(['Durée vs Max - ', noms_materiaux{k}]);
    grid on;

    subplot(1,2,2);
    scatter(durees, pentes, 'filled');
    xlabel('Durée de l''excitation (s)');
    ylabel('Pente');
    title(['Durée vs Pente - ', noms_materiaux{k}]);
    grid on;

    % Instants de début
    instants_debut = Instant(indices_debut(1:end-1));

    % Graphe 3D valeur max en fonction de la durée et des instants, coloré par la durée
    figure;
    scatter3(instants_debut, durees, max_vals, 50, durees, 'filled');
    xlabel('Instant de début (s)');
    ylabel('Durée (s)');
    zlabel('Valeur max de la réponse');
    title(['3D - Max vs Instant et Durée - ', noms_materiaux{k}]);
    grid on;
    colorbar;
    colormap('jet');
    caxis([min(durees) max(durees)]);
    view(45,32);
    rotate3d on;

    % Surface interpolée pour ce graphe 3D
    [X1, Y1] = meshgrid(linspace(min(instants_debut), max(instants_debut), 50), ...
                        linspace(min(durees), max(durees), 50));
    Z1 = griddata(instants_debut, durees, max_vals, X1, Y1, 'cubic');

    figure;
    surf(X1, Y1, Z1, 'EdgeColor', 'none');
    xlabel('Instant de début (s)');
    ylabel('Durée (s)');
    zlabel('Valeur max de la réponse');
    title(['Surface interpolée - Max vs Instant et Durée - ', noms_materiaux{k}]);
    colorbar;
    colormap('jet');
    view(45,32);
    rotate3d on;
    grid on;

    % Graphe 3D min, durée et max coloré par durée
    figure;
    scatter3(min_vals, durees, max_vals, 50, durees, 'filled');
    xlabel('Valeur min de la réponse');
    ylabel('Durée (s)');
    zlabel('Valeur max de la réponse');
    title(['3D - Min, Durée, Max - ', noms_materiaux{k}]);
    grid on;
    colorbar;
    colormap('jet');
    caxis([min(durees) max(durees)]);
    view(45,32);
    rotate3d on;

    % Surface interpolée pour ce graphe 3D
    [X2, Y2] = meshgrid(linspace(min(min_vals), max(min_vals), 50), ...
                        linspace(min(durees), max(durees), 50));
    Z2 = griddata(min_vals, durees, max_vals, X2, Y2, 'cubic');

    figure;
    surf(X2, Y2, Z2, 'EdgeColor', 'none');
    xlabel('Valeur min de la réponse');
    ylabel('Durée (s)');
    zlabel('Valeur max de la réponse');
    title(['Surface interpolée - Min, Durée, Max - ', noms_materiaux{k}]);
    colorbar;
    colormap('jet');
    view(45,32);
    rotate3d on;
    grid on;
end
