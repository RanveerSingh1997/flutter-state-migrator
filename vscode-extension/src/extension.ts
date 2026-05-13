import * as vscode from 'vscode';
import * as cp from 'child_process';
import * as path from 'path';

interface QuickFixPayload {
    title: string;
    command: string;
    kind: string;
    message?: string;
}

interface IdeDiagnosticPayload {
    filePath: string;
    startLine: number;
    startColumn: number;
    endLine: number;
    endColumn: number;
    severity: string;
    code: string;
    source: string;
    category: string;
    message: string;
    nodeId: string;
    quickFixes: QuickFixPayload[];
}

interface IdeAnalysisPayload {
    targetPath: string;
    summary: {
        totalDiagnostics: number;
        architectureDiagnosticCount: number;
        governanceDiagnosticCount: number;
    };
    diagnostics: IdeDiagnosticPayload[];
}

export function activate(context: vscode.ExtensionContext) {
    const outputChannel = vscode.window.createOutputChannel('Flutter State Migrator');
    const diagnostics = vscode.languages.createDiagnosticCollection('flutter-migrator');
    const quickFixRegistry = new Map<string, QuickFixPayload[]>();
    let refreshTimer: NodeJS.Timeout | undefined;

    const migrateFile = vscode.commands.registerCommand('flutter-migrator.migrateFile', async (uri: vscode.Uri) => {
        const filePath = uri ? uri.fsPath : vscode.window.activeTextEditor?.document.uri.fsPath;
        if (!filePath) {
            vscode.window.showErrorMessage('No file selected for migration.');
            return;
        }
        await runMigrator(filePath, outputChannel);
    });

    const migrateProject = vscode.commands.registerCommand('flutter-migrator.migrateProject', async (uri: vscode.Uri) => {
        const projectPath = uri ? uri.fsPath : vscode.workspace.workspaceFolders?.[0].uri.fsPath;
        if (!projectPath) {
            vscode.window.showErrorMessage('No project/folder selected for migration.');
            return;
        }
        await runMigrator(projectPath, outputChannel);
    });

    const refreshDiagnostics = vscode.commands.registerCommand('flutter-migrator.refreshDiagnostics', async () => {
        await updateDiagnostics(outputChannel, diagnostics, quickFixRegistry);
    });

    const showRecommendation = vscode.commands.registerCommand('flutter-migrator.showRecommendation', async (message?: string) => {
        if (!message) {
            return;
        }
        await vscode.window.showInformationMessage(message, { modal: true });
    });

    const openMigrationGuide = vscode.commands.registerCommand('flutter-migrator.openMigrationGuide', async () => {
        const workspaceRoot = vscode.workspace.workspaceFolders?.[0].uri.fsPath;
        if (!workspaceRoot) {
            vscode.window.showErrorMessage('Workspace root not found.');
            return;
        }
        const guideUri = vscode.Uri.file(path.join(workspaceRoot, 'MIGRATION_GUIDE.md'));
        await vscode.commands.executeCommand('vscode.open', guideUri);
    });

    const codeActionProvider = vscode.languages.registerCodeActionsProvider(
        { language: 'dart' },
        new FlutterMigratorCodeActionProvider(quickFixRegistry),
        {
            providedCodeActionKinds: [vscode.CodeActionKind.QuickFix]
        }
    );

    const scheduleDiagnosticsRefresh = () => {
        if (refreshTimer) {
            clearTimeout(refreshTimer);
        }
        refreshTimer = setTimeout(() => {
            void updateDiagnostics(outputChannel, diagnostics, quickFixRegistry);
        }, 350);
    };

    context.subscriptions.push(
        outputChannel,
        diagnostics,
        migrateFile,
        migrateProject,
        refreshDiagnostics,
        showRecommendation,
        openMigrationGuide,
        codeActionProvider,
        vscode.workspace.onDidSaveTextDocument((document) => {
            if (document.languageId === 'dart') {
                scheduleDiagnosticsRefresh();
            }
        }),
        vscode.window.onDidChangeActiveTextEditor((editor) => {
            if (editor?.document.languageId === 'dart') {
                scheduleDiagnosticsRefresh();
            }
        }),
    );

    void updateDiagnostics(outputChannel, diagnostics, quickFixRegistry);
}

class FlutterMigratorCodeActionProvider implements vscode.CodeActionProvider {
    constructor(private readonly quickFixRegistry: Map<string, QuickFixPayload[]>) {}

    provideCodeActions(
        document: vscode.TextDocument,
        _range: vscode.Range,
        context: vscode.CodeActionContext
    ): vscode.CodeAction[] {
        const actions: vscode.CodeAction[] = [];

        for (const diagnostic of context.diagnostics) {
            if (diagnostic.source !== 'flutter-migrator') {
                continue;
            }

            const key = diagnosticKey(document.uri, diagnostic.range, diagnostic.message);
            const fixes = this.quickFixRegistry.get(key) ?? [];
            for (const fix of fixes) {
                const action = new vscode.CodeAction(fix.title, vscode.CodeActionKind.QuickFix);
                action.diagnostics = [diagnostic];
                action.isPreferred = fix.kind === 'refactor';
                action.command = buildQuickFixCommand(fix, document.uri);
                actions.push(action);
            }
        }

        return actions;
    }
}

function buildQuickFixCommand(fix: QuickFixPayload, documentUri: vscode.Uri): vscode.Command {
    switch (fix.command) {
        case 'flutter-migrator.migrateFile':
            return {
                command: fix.command,
                title: fix.title,
                arguments: [documentUri],
            };
        case 'flutter-migrator.migrateProject': {
            const workspaceUri = vscode.workspace.workspaceFolders?.[0]?.uri;
            return {
                command: fix.command,
                title: fix.title,
                arguments: workspaceUri ? [workspaceUri] : [],
            };
        }
        case 'flutter-migrator.showRecommendation':
            return {
                command: fix.command,
                title: fix.title,
                arguments: [fix.message],
            };
        case 'flutter-migrator.openMigrationGuide':
            return {
                command: fix.command,
                title: fix.title,
            };
        default:
            return {
                command: 'flutter-migrator.refreshDiagnostics',
                title: 'Refresh architecture diagnostics',
            };
    }
}

async function updateDiagnostics(
    outputChannel: vscode.OutputChannel,
    diagnostics: vscode.DiagnosticCollection,
    quickFixRegistry: Map<string, QuickFixPayload[]>
): Promise<void> {
    const workspaceRoot = vscode.workspace.workspaceFolders?.[0].uri.fsPath;
    if (!workspaceRoot) {
        return;
    }

    const analysis = await runIdeAnalysis(workspaceRoot, outputChannel);
    if (!analysis) {
        return;
    }

    diagnostics.clear();
    quickFixRegistry.clear();

    const grouped = new Map<string, vscode.Diagnostic[]>();
    for (const payload of analysis.diagnostics) {
        const uri = vscode.Uri.file(payload.filePath);
        const range = new vscode.Range(
            Math.max(payload.startLine - 1, 0),
            Math.max(payload.startColumn - 1, 0),
            Math.max(payload.endLine - 1, 0),
            Math.max(payload.endColumn - 1, 1),
        );
        const diagnostic = new vscode.Diagnostic(
            range,
            payload.message,
            toDiagnosticSeverity(payload.severity),
        );
        diagnostic.source = payload.source;
        diagnostic.code = payload.code;

        const key = diagnosticKey(uri, range, payload.message);
        quickFixRegistry.set(key, payload.quickFixes ?? []);

        const fileDiagnostics = grouped.get(uri.fsPath) ?? [];
        fileDiagnostics.push(diagnostic);
        grouped.set(uri.fsPath, fileDiagnostics);
    }

    for (const [filePath, fileDiagnostics] of grouped.entries()) {
        diagnostics.set(vscode.Uri.file(filePath), fileDiagnostics);
    }

    outputChannel.appendLine(
        `🧭 IDE diagnostics refreshed: ${analysis.summary.totalDiagnostics} finding(s) across ${grouped.size} file(s).`
    );
}

function runIdeAnalysis(
    targetPath: string,
    outputChannel: vscode.OutputChannel
): Promise<IdeAnalysisPayload | undefined> {
    const workspaceRoot = vscode.workspace.workspaceFolders?.[0].uri.fsPath;
    if (!workspaceRoot) {
        return Promise.resolve(undefined);
    }

    return new Promise((resolve) => {
        const args = ['run', 'bin/migrator.dart', '--ide-json', targetPath];
        cp.execFile('dart', args, { cwd: workspaceRoot, maxBuffer: 10 * 1024 * 1024 }, (error, stdout, stderr) => {
            if (stderr) {
                outputChannel.append(stderr);
            }

            if (error) {
                outputChannel.appendLine(`❌ IDE analysis failed: ${error.message}`);
                vscode.window.showErrorMessage(`Architecture diagnostics failed: ${error.message}`);
                resolve(undefined);
                return;
            }

            try {
                const parsed = JSON.parse(stdout) as IdeAnalysisPayload;
                resolve(parsed);
            } catch (_parseError) {
                outputChannel.appendLine('❌ Could not parse IDE diagnostics payload.');
                outputChannel.appendLine(stdout);
                vscode.window.showErrorMessage('Architecture diagnostics returned invalid JSON.');
                resolve(undefined);
            }
        });
    });
}

function diagnosticKey(uri: vscode.Uri, range: vscode.Range, message: string): string {
    return `${uri.fsPath}:${range.start.line}:${range.start.character}:${range.end.line}:${range.end.character}:${message}`;
}

function toDiagnosticSeverity(severity: string): vscode.DiagnosticSeverity {
    switch (severity) {
        case 'error':
            return vscode.DiagnosticSeverity.Error;
        case 'info':
            return vscode.DiagnosticSeverity.Information;
        case 'warning':
        default:
            return vscode.DiagnosticSeverity.Warning;
    }
}

function runMigrator(targetPath: string, outputChannel: vscode.OutputChannel): Thenable<void> {
    return vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: 'Migrating to Riverpod...',
        cancellable: false
    }, async () => {
        return new Promise<void>((resolve) => {
            const workspaceRoot = vscode.workspace.workspaceFolders?.[0].uri.fsPath;
            if (!workspaceRoot) {
                vscode.window.showErrorMessage('Workspace root not found.');
                resolve();
                return;
            }

            const args = ['run', 'bin/migrator.dart', '--mode', 'aggressive', targetPath];
            const command = `dart ${args.join(' ')}`;

            outputChannel.show();
            outputChannel.appendLine(`🚀 Running: ${command}`);

            cp.execFile('dart', args, { cwd: workspaceRoot, maxBuffer: 10 * 1024 * 1024 }, (error, stdout, stderr) => {
                if (stdout) {
                    outputChannel.append(stdout);
                }
                if (stderr) {
                    outputChannel.append(stderr);
                }

                if (error) {
                    vscode.window.showErrorMessage(`Migration failed: ${error.message}`);
                    outputChannel.appendLine(`❌ Error: ${error.message}`);
                } else {
                    vscode.window.showInformationMessage('Migration complete! Review the changes and the report.');
                    outputChannel.appendLine('✨ Migration finished successfully.');
                    void vscode.commands.executeCommand('flutter-migrator.refreshDiagnostics');
                }
                resolve();
            });
        });
    });
}

export function deactivate() {}
