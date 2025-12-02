import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Visitor that collects every referenced identifier name from a compilation
/// unit, but ignores declaration contexts (e.g. function names, class names).
class UsedNamesVisitor extends RecursiveAstVisitor<void> {
  final Set<String> usedNames;

  final List<String> _declarationStack = [];

  UsedNamesVisitor(this.usedNames);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_isConstructorReturnType(node)) {
      // Using the class/enum name in its own constructor does not count as a
      // real usage of that type elsewhere.
      return;
    }

    final parent = node.parent;
    if (parent is NamedExpression && parent.name.label == node) {
      // Named argument labels should not count as usages of the underlying
      // fields or parameters.
      return;
    }

    if (!node.inDeclarationContext() &&
        !_declarationStack.contains(node.name)) {
      usedNames.add(node.name);
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    // Always treat the type name as a usage.
    final identifier = node.name2;
    if (!_declarationStack.contains(identifier.lexeme)) {
      usedNames.add(identifier.lexeme);
    }
    super.visitNamedType(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _declarationStack.add(node.name.lexeme);
    super.visitClassDeclaration(node);
    _declarationStack.removeLast();
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _declarationStack.add(node.name.lexeme);
    super.visitEnumDeclaration(node);
    _declarationStack.removeLast();
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final name = node.name?.lexeme;
    if (name != null) _declarationStack.add(name);
    super.visitExtensionDeclaration(node);
    if (name != null) _declarationStack.removeLast();
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _declarationStack.add(node.name.lexeme);
    super.visitFunctionDeclaration(node);
    _declarationStack.removeLast();
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    _declarationStack.add(node.name.lexeme);
    super.visitGenericTypeAlias(node);
    _declarationStack.removeLast();
  }

  bool _isConstructorReturnType(SimpleIdentifier node) {
    final parent = node.parent;
    return parent is ConstructorDeclaration && parent.returnType == node;
  }
}
