function names = list()
%BCT.KERNEL.LIST  List available kernel names
    r = bct.kernel.registry();
    names = fieldnames(r);
end
