import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Visitor that collects every referenced identifier name from a compilation
/// unit, but ignores declaration contexts (e.g. function names, class names).
class UsedNamesVisitor extends RecursiveAstVisitor<void> {
  final Set<String> usedNames;

  UsedNamesVisitor(this.usedNames);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (!node.inDeclarationContext()) {
      usedNames.add(node.name);
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    // Always treat the type name as a usage.
    final identifier = node.name2;
    usedNames.add(identifier.lexeme);
    super.visitNamedType(node);
  }
}
