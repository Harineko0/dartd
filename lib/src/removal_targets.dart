import 'models.dart';

/// Specifies which unused declarations should be removed by `fix`.
class RemovalTargets {
  const RemovalTargets(this.kinds);

  const RemovalTargets.all()
      : kinds = const {
          RemovalKind.file,
          RemovalKind.classType,
          RemovalKind.function,
          RemovalKind.variable,
          RemovalKind.method,
          RemovalKind.member,
          RemovalKind.import,
        };

  factory RemovalTargets.fromNames(List<String> names) {
    if (names.isEmpty || names.contains('all')) {
      return const RemovalTargets.all();
    }

    final normalized = names.map((name) => name.toLowerCase()).toSet();
    final kinds = <RemovalKind>{};

    void addIfPresent(String name, RemovalKind kind) {
      if (normalized.contains(name)) {
        kinds.add(kind);
      }
    }

    addIfPresent('file', RemovalKind.file);
    addIfPresent('class', RemovalKind.classType);
    addIfPresent('function', RemovalKind.function);
    addIfPresent('var', RemovalKind.variable);
    addIfPresent('method', RemovalKind.method);
    addIfPresent('member', RemovalKind.member);
    addIfPresent('import', RemovalKind.import);

    if (kinds.isEmpty) {
      return const RemovalTargets.all();
    }

    return RemovalTargets(Set.unmodifiable(kinds));
  }

  final Set<RemovalKind> kinds;

  bool get removeFiles => kinds.contains(RemovalKind.file);
  bool get removeClasses => kinds.contains(RemovalKind.classType);
  bool get removeFunctions => kinds.contains(RemovalKind.function);
  bool get removeVariables => kinds.contains(RemovalKind.variable);
  bool get removeMethods => kinds.contains(RemovalKind.method);
  bool get removeMembers => kinds.contains(RemovalKind.member);
  bool get removeImports => kinds.contains(RemovalKind.import);

  bool allowModule(ModuleDefinition module) {
    switch (module.kind) {
      case ModuleDeclarationKind.providerClass:
        return removeClasses;
      case ModuleDeclarationKind.providerVariable:
        return removeVariables;
      case ModuleDeclarationKind.riverpodFunction:
        return removeFunctions;
    }
  }

  bool allowClassMember(ClassMemberDefinition member) {
    switch (member.kind) {
      case ClassMemberKind.method:
      case ClassMemberKind.getter:
      case ClassMemberKind.setter:
        return removeMethods || removeMembers;
      case ClassMemberKind.field:
        return removeMembers;
    }
  }

  bool allowTopLevel(TopLevelDeclaration declaration) {
    switch (declaration.kind) {
      case TopLevelDeclarationKind.function:
        return removeFunctions;
      case TopLevelDeclarationKind.variable:
        return removeVariables;
      case TopLevelDeclarationKind.classType:
      case TopLevelDeclarationKind.enumType:
      case TopLevelDeclarationKind.extension:
      case TopLevelDeclarationKind.typeAlias:
        return removeClasses;
    }
  }
}

/// Types of declarations that can be removed.
enum RemovalKind {
  file,
  classType,
  function,
  variable,
  method,
  member,
  import,
}
