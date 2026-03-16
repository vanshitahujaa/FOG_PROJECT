function [H, B, info] = computeJacobian(mpc)
    fprintf('Computing Jacobian matrix H...\n');
    [Ybus, ~, ~] = makeYbus(mpc);
    B = imag(Ybus);
    nBus = size(mpc.bus, 1);
    nBranch = size(mpc.branch, 1);
    ref = find(mpc.bus(:, 2) == 3);
    if isempty(ref)
        ref = 1;
    end
    nonref = setdiff(1:nBus, ref);
    nState = length(nonref);
    H_bus = B(nonref, nonref);
    H_branch = zeros(nBranch, nState);
    for k = 1:nBranch
        i = mpc.branch(k, 1);
        j = mpc.branch(k, 2);
        x = mpc.branch(k, 4);
        if x == 0
            x = 0.01;
        end
        b = 1 / x;
        i_pos = find(nonref == i);
        j_pos = find(nonref == j);
        if ~isempty(i_pos)
            H_branch(k, i_pos) = b;
        end
        if ~isempty(j_pos)
            H_branch(k, j_pos) = -b;
        end
    end
    H = [H_bus; H_branch];
    info.nBus = nBus;
    info.nBranch = nBranch;
    info.nState = nState;
    info.nMeas = size(H, 1);
    info.refBus = ref;
    info.nonref = nonref;
    info.B = B;
    fprintf('H matrix size: [%d measurements x %d states]\n', info.nMeas, info.nState);
end
