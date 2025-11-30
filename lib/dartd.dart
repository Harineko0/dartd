library dartd;

export 'src/models.dart';
export 'src/analyzer.dart'
    show
        analyzeProject,
        ProjectAnalyzer,
        computeUnusedGroups,
        computeDeletableNonModuleFiles,
        applyFixes;
