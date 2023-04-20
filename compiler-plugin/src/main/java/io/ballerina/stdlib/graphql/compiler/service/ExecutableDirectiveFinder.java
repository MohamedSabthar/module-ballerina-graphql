package io.ballerina.stdlib.graphql.compiler.service;

import io.ballerina.compiler.api.SemanticModel;
import io.ballerina.compiler.api.symbols.ClassSymbol;
import io.ballerina.compiler.syntax.tree.ClassDefinitionNode;
import io.ballerina.compiler.syntax.tree.Node;
import io.ballerina.projects.DocumentId;
import io.ballerina.projects.Module;
import io.ballerina.projects.ModuleId;
import io.ballerina.projects.Project;
import io.ballerina.stdlib.graphql.compiler.service.validator.ExecutableDirectiveNodeVisitor;

import java.util.Collection;
import java.util.Optional;

import static io.ballerina.stdlib.graphql.compiler.Utils.hasDirectiveConfig;
import static io.ballerina.stdlib.graphql.compiler.Utils.hasDirectiveTypeInclusion;

/**
 * Validate Executable directives in Ballerina GraphQL services.
 */
public class ExecutableDirectiveFinder {

    private final ClassSymbol classSymbol;
    private final SemanticModel semanticModel;
    private final Project project;
    private final ModuleId moduleId;
    private String directiveClasName;

    public ExecutableDirectiveFinder(SemanticModel semanticModel, ClassSymbol classSymbol, Project project,
                                     ModuleId moduleID) {
        this.semanticModel = semanticModel;
        this.classSymbol = classSymbol;
        this.project = project;
        this.moduleId = moduleID;
    }

    public Optional<ClassDefinitionNode> getDirectiveNode() {
        if (classSymbol.getName().isEmpty() || !hasDirectiveTypeInclusionOrDirectiveConfig()) {
            return Optional.empty();
        }
        Optional<ClassDefinitionNode> classDefinitionNode = getClassDefinitionNodeFromModule();
        if (classDefinitionNode.isEmpty()) {
            return Optional.empty();
        }
        this.directiveClasName = this.classSymbol.getName().get();
        return classDefinitionNode;
    }

    private boolean hasDirectiveTypeInclusionOrDirectiveConfig() {
        boolean hasDirectiveTypeInclusion = hasDirectiveTypeInclusion(this.classSymbol);
        boolean hasDirectiveConfig = hasDirectiveConfig(this.classSymbol);
        return hasDirectiveTypeInclusion || hasDirectiveConfig;
    }

    private Optional<ClassDefinitionNode> getClassDefinitionNodeFromModule() {
        Module currentModule = this.project.currentPackage().module(this.moduleId);
        Collection<DocumentId> documentIds = currentModule.documentIds();
        ExecutableDirectiveNodeVisitor directiveVisitor = new ExecutableDirectiveNodeVisitor(this.semanticModel,
                                                                                             this.classSymbol);
        for (DocumentId documentId : documentIds) {
            Node rootNode = currentModule.document(documentId).syntaxTree().rootNode();
            rootNode.accept(directiveVisitor);
            if (directiveVisitor.getClassDefinitionNode().isPresent()) {
                break;
            }
        }
        return directiveVisitor.getClassDefinitionNode();
    }

    public String getDirectiveClassName() {
        if (this.directiveClasName == null) {
            throw new IllegalStateException("Directive class name is not set");
        }
        return this.directiveClasName;
    }
}
