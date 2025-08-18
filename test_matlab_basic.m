% Basic MATLAB test script
fprintf('MATLAB is working!\n');
fprintf('MATLAB version: %s\n', version);
fprintf('Current directory: %s\n', pwd);

% Test basic operations
A = rand(3, 3);
fprintf('Created 3x3 random matrix\n');

% Test sparse matrix (needed for our optimizations)
S = sparse(eye(5));
fprintf('Created 5x5 sparse identity matrix with %d non-zeros\n', nnz(S));

% Test parallel computing toolbox (if available)
try
    parfor i = 1:3
        x(i) = i^2;
    end
    fprintf('Parallel Computing Toolbox is available\n');
catch
    fprintf('Parallel Computing Toolbox not available or not licensed\n');
end

% Test optimization toolbox (critical for our scheduling)
try
    f = [1; 2];
    A = [1, 1];
    b = 3;
    lb = [0; 0];
    [x, fval] = linprog(f, A, b, [], [], lb);
    fprintf('Optimization Toolbox is available\n');
catch ME
    fprintf('Optimization Toolbox issue: %s\n', ME.message);
end

fprintf('Basic MATLAB test completed successfully!\n');