import * as vscode from 'vscode';
import * as cp from 'child_process';
import * as path from 'path';

export function activate(context: vscode.ExtensionContext) {
    const outputChannel = vscode.window.createOutputChannel("Flutter State Migrator");

    let migrateFile = vscode.commands.registerCommand('flutter-migrator.migrateFile', async (uri: vscode.Uri) => {
        const filePath = uri ? uri.fsPath : vscode.window.activeTextEditor?.document.uri.fsPath;
        if (!filePath) {
            vscode.window.showErrorMessage("No file selected for migration.");
            return;
        }
        runMigrator(filePath, outputChannel);
    });

    let migrateProject = vscode.commands.registerCommand('flutter-migrator.migrateProject', async (uri: vscode.Uri) => {
        const projectPath = uri ? uri.fsPath : vscode.workspace.workspaceFolders?.[0].uri.fsPath;
        if (!projectPath) {
            vscode.window.showErrorMessage("No project/folder selected for migration.");
            return;
        }
        runMigrator(projectPath, outputChannel);
    });

    context.subscriptions.push(migrateFile, migrateProject);
}

function runMigrator(targetPath: String, outputChannel: vscode.OutputChannel) {
    vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: "Migrating to Riverpod...",
        cancellable: false
    }, async (progress) => {
        return new Promise<void>((resolve, reject) => {
            const workspaceRoot = vscode.workspace.workspaceFolders?.[0].uri.fsPath;
            if (!workspaceRoot) {
                vscode.window.showErrorMessage("Workspace root not found.");
                resolve();
                return;
            }

            // Command: dart run bin/migrator.dart --mode aggressive <targetPath>
            // We assume the user has the migrator available in the workspace
            const command = `dart run bin/migrator.dart --mode aggressive "${targetPath}"`;
            
            outputChannel.show();
            outputChannel.appendLine(`🚀 Running: ${command}`);

            cp.exec(command, { cwd: workspaceRoot }, (error, stdout, stderr) => {
                if (stdout) outputChannel.append(stdout);
                if (stderr) outputChannel.append(stderr);

                if (error) {
                    vscode.window.showErrorMessage(`Migration failed: ${error.message}`);
                    outputChannel.appendLine(`❌ Error: ${error.message}`);
                } else {
                    vscode.window.showInformationMessage("Migration complete! Review the changes and the report.");
                    outputChannel.appendLine("✨ Migration finished successfully.");
                }
                resolve();
            });
        });
    });
}

export function deactivate() {}
