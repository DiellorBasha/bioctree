classdef test_operator_refactor < BaseBctTest
    methods (Test)
        function testRegistryStructure(testCase)
            specs = bct.registry.operators.defs();
            testCase.verifyClass(specs, 'dictionary');
            testCase.verifyTrue(isKey(specs, "gradient.dec"));
        end
    end
end
