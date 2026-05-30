function suite = selectTestSuiteByProfile(suite,profile)
% selectTestSuiteByProfile Filter planWorkflow tests by execution profile.

if nargin < 2 || isempty(profile)
    profile = 'full';
end
profile = validatestring(char(profile),{'fast','full','real'}, ...
    mfilename,'Profile');

testNames = string({suite.Name});
testFiles = regexprep(testNames,'/.*$','');
realMask = endsWith(testFiles,'Real');

switch profile
    case 'fast'
        suite = suite(~realMask);
    case 'real'
        suite = suite(realMask);
    case 'full'
        % Keep the complete suite.
end

end
