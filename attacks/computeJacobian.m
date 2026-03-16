% % COMPUTE JACOBIAN MATRIX FOR DC STATE ESTIMATION %
    Computes the H matrix relating measurements to state variables % %
    For DC power flow
    : P = B * theta % H relates measurements to state(voltage angles) % %
              Inputs : % mpc -
          MATPOWER case struct % % Outputs:
% H - Jacobian matrix[nMeasurements x nStates] % B - Susceptance matrix % info -
    Additional information about the system

        function[H, B, info] =
    computeJacobian(mpc) fprintf('Computing Jacobian matrix H...\n');

% Get bus admittance matrix[Ybus, ~, ~] = makeYbus(mpc);
B = imag(Ybus);
% Susceptance matrix(imaginary part)

        nBus = size(mpc.bus, 1);
nBranch = size(mpc.branch, 1);

% Find reference bus(slack bus, type = 3) ref = find(mpc.bus( :, 2) == 3);
if isempty (ref)
  ref = 1;
% Default to first bus warning('No reference bus found. Using bus 1.');
end

        % Non -
    reference buses(states are their voltage angles) nonref = setdiff(1 : nBus,
                                                                      ref);
nState = length(nonref);

    %% Build DC power flow Jacobian
    % Measurements: P_injection at each non-ref bus + P_flow on each branch
    % States: theta (voltage angle) at each non-ref bus
    
    % Part 1: Bus power injections
    % P_i = sum_j(B_ij * theta_j) for all j != ref
    H_bus = B(nonref, nonref);

    % Part 2 : Branch power flows % P_ij = (theta_i - theta_j) / x_ij H_branch =
                                               zeros(nBranch, nState);

    for
      k = 1 : nBranch i = mpc.branch(k, 1);
    % From bus j = mpc.branch(k, 2);
    % To bus x = mpc.branch(k, 4);
    % Reactance

            if x ==
        0 x = 0.01;
    % Avoid division by zero end b = 1 / x;
    % Branch susceptance

        % Find positions in state vector i_pos = find(nonref == i);
    j_pos = find(nonref == j);

    if
      ~isempty(i_pos) H_branch(k, i_pos) = b;
    end if ~isempty(j_pos) H_branch(k, j_pos) = -b;
    end end

        % Combine into full H matrix %
        Measurements : [P_bus(non - ref); P_branch] H = [H_bus; H_branch];

    % Store additional info info.nBus = nBus;
    info.nBranch = nBranch;
    info.nState = nState;
    info.nMeas = size(H, 1);
    info.refBus = ref;
    info.nonref = nonref;
    info.B = B;

    fprintf('H matrix size: [%d measurements x %d states]\n', info.nMeas,
            info.nState);
    fprintf('Reference bus: %d\n', ref);
    end

        % % Validate H matrix properties function isValid =
        validateJacobian(H, mpc) fprintf('\nValidating Jacobian matrix...\n');

    isValid = true;

    % Check 1 : H should be full rank(or close to it) rankH = rank(H);
    [ m, n ] = size(H);
    fprintf('  Rank of H: %d (expected: %d)\n', rankH, min(m, n));

    if rankH
      < min(m, n) - 1 warning('H matrix may be rank deficient');
    isValid = false;
    end

        % Check 2 : Verify H *c produces valid attack c = randn(n, 1) * 0.01;
    % Small random attack a = H * c;

    % The attack should affect measurements proportionally to H
            fprintf('  Attack vector norm: %.6f\n', norm(a));

    % Check 3: Condition number
    condH = cond(H' * H);
    fprintf('  Condition number of H''H: %.2e\n', condH);
    
    if condH > 1e10
        warning('H matrix is ill-conditioned');
    end
    
    fprintf('Jacobian validation complete.\n');
end
