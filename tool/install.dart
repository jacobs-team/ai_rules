import 'dart:convert';
import 'dart:io';

/// Deploys this repo's rules and skills to every AI agent's global locations.
///
/// Usage: `dart tool/install.dart` to install or refresh,
/// `dart tool/install.dart --uninstall` to remove everything it installed.
///
/// Every file it writes carries [generatedMarker] and every folder it copies
/// holds a [managedMarkerFileName] file. Anything without those is never
/// deleted: a file in the way is moved to a backup first, and a folder in the
/// way is left alone.
void main(List<String> arguments) {
  if (arguments.contains('--uninstall')) {
    uninstall();
  } else {
    install();
  }
}

const generatedMarker = 'ai_rules:generated';
const managedMarkerFileName = '.ai_rules';
const backupSuffix = '.ai_rules.bak';

/// The installed copy of the rules and skills that agents are pointed at, so
/// they never depend on where the editing clone lives.
const mirrorPathFromHome = '.ai_rules';
const mirroredRepoPaths = ['AGENTS.md', 'languages', 'skills'];

/// A doc in `languages/` that agents load only for that language's files.
class LanguageDoc {
  const LanguageDoc({
    required this.fileName,
    required this.description,
    required this.globs,
  });

  final String fileName;
  final String description;
  final List<String> globs;

  String get ruleName => fileName.replaceAll('.md', '');
}

const languageDocs = [
  LanguageDoc(
    fileName: 'flutter-dart.md',
    description:
        'Dart/Flutter rules. Apply only when the task involves Dart or Flutter.',
    globs: ['**/*.dart', '**/pubspec.yaml', '**/analysis_options.yaml'],
  ),
];

/// Skill folders the agents scan, relative to the home folder.
const skillRootsFromHome = [
  '.claude/skills', // Claude Code
  '.agents/skills', // Codex, Copilot, Cursor, Grok, Gemini CLI
  '.gemini/config/skills', // Antigravity app and IDE
  '.gemini/antigravity-cli/skills', // Antigravity CLI
];

/// Folders of generated per-language rules and commands. A generated file in
/// one of them that the repo no longer produces is removed.
const generatedFileFoldersFromHome = [
  '.claude/rules',
  '.copilot/instructions',
  '.gemini/config/rules',
  '.gemini/commands',
  '.cursor/rules',
];

/// Files left by other setups that load the rules twice or shadow them.
const conflictingFilesFromHome = {
  '.grok/AGENTS.md':
      'Grok already reads ~/.claude/CLAUDE.md, so the rules load twice',
  '.gemini/AGENTS.md':
      'Antigravity reads it next to GEMINI.md, so the rules load twice',
  '.codex/AGENTS.override.md': 'Codex reads it instead of ~/.codex/AGENTS.md',
};

final homePath =
    (Platform.isWindows
            ? Platform.environment['USERPROFILE']
            : Platform.environment['HOME'])!
        .replaceAll(r'\', '/');

final repoPath = File.fromUri(
  Platform.script,
).parent.parent.path.replaceAll(r'\', '/');

void install() {
  final installableSkills = findInstallableSkills();

  syncManagedDirectory(
    sourceFiles: mirroredRepoFiles(),
    sourceRoot: Directory(repoPath),
    target: Directory('$homePath/$mirrorPathFromHome'),
  );

  final generatedFiles = generatedFilesFromHome(installableSkills.keys);
  for (final MapEntry(key: pathFromHome, value: content)
      in generatedFiles.entries) {
    writeGeneratedFile(pathFromHome, content);
  }
  removeStaleGeneratedFiles(keep: generatedFiles.keys.toSet());

  for (final skillRootFromHome in skillRootsFromHome) {
    final skillRoot = Directory('$homePath/$skillRootFromHome');
    skillRoot.createSync(recursive: true);

    for (final MapEntry(key: skillName, value: skillDirectory)
        in installableSkills.entries) {
      syncManagedDirectory(
        sourceFiles: filesIn(skillDirectory),
        sourceRoot: skillDirectory,
        target: Directory('${skillRoot.path}/$skillName'),
      );
    }

    for (final installedSkill in skillRoot.listSync().whereType<Directory>()) {
      final isRemovedFromRepo = !installableSkills.containsKey(
        nameOf(installedSkill),
      );
      if (isRemovedFromRepo && isManagedDirectory(installedSkill)) {
        installedSkill.deleteSync(recursive: true);
        report('removed', '${installedSkill.path}/');
      }
    }
  }

  mergeSettings('settings/claude.json', '.claude/settings.json');
  mergeSettings('settings/copilot.json', '.copilot/settings.json');

  for (final MapEntry(key: pathFromHome, value: reason)
      in conflictingFilesFromHome.entries) {
    final type = FileSystemEntity.typeSync(
      '$homePath/$pathFromHome',
      followLinks: false,
    );
    if (type != FileSystemEntityType.notFound) {
      warn('~/$pathFromHome exists: $reason. Remove it.');
    }
  }

  useRepoGitHooks();
}

void uninstall() {
  for (final pathFromHome in generatedFilesFromHome(const []).keys) {
    removeGeneratedFile(pathFromHome);
  }
  removeStaleGeneratedFiles(keep: const {});

  final managedDirectories = [
    Directory('$homePath/$mirrorPathFromHome'),
    for (final skillRootFromHome in skillRootsFromHome)
      if (Directory('$homePath/$skillRootFromHome').existsSync())
        ...Directory(
          '$homePath/$skillRootFromHome',
        ).listSync().whereType<Directory>(),
  ];
  for (final managedDirectory in managedDirectories) {
    if (isManagedDirectory(managedDirectory)) {
      managedDirectory.deleteSync(recursive: true);
      report('removed', '${managedDirectory.path}/');
    }
  }

  if (Directory('$repoPath/.git').existsSync()) {
    Process.runSync('git', [
      'config',
      '--unset',
      'core.hooksPath',
    ], workingDirectory: repoPath);
  }

  print(
    'Settings merged into ~/.claude/settings.json and '
    '~/.copilot/settings.json were left as they are.',
  );
}

/// Every instruction and command file this installer owns, keyed by path
/// from home.
Map<String, String> generatedFilesFromHome(Iterable<String> skillNames) {
  final masterRules = readRepoFile('AGENTS.md');

  final generatedFiles = {
    // Claude Code. Grok and VS Code's local agent read it too.
    '.claude/CLAUDE.md': generated(masterRules),
    '.codex/AGENTS.md': generated(masterRules),
    // Copilot CLI and VS Code's Copilot agent.
    '.copilot/copilot-instructions.md': generated(masterRules),
    // Gemini CLI and Antigravity.
    '.gemini/GEMINI.md': generated(masterRules),
    '.cursor/rules/ai_rules.mdc': generated(
      masterRules,
      frontmatter:
          'description: Master instructions for every task. Always apply.\n'
          'alwaysApply: true',
    ),
  };

  for (final languageDoc in languageDocs) {
    final languageRules = readRepoFile('languages/${languageDoc.fileName}');
    final ruleName = languageDoc.ruleName;
    final description = languageDoc.description;

    // Grok loads every file in ~/.claude/rules whatever its `paths`, so this
    // stays a short pointer and Claude pulls in the full doc through the import.
    generatedFiles['.claude/rules/$ruleName.md'] = generated(
      '$description Read and follow:\n\n'
      '@~/$mirrorPathFromHome/languages/${languageDoc.fileName}\n',
      frontmatter: [
        'paths:',
        for (final glob in languageDoc.globs) '  - "$glob"',
      ].join('\n'),
    );
    generatedFiles['.copilot/instructions/$ruleName.instructions.md'] =
        generated(
          languageRules,
          frontmatter:
              'description: $description\n'
              'applyTo: "${languageDoc.globs.join(',')}"',
        );
    generatedFiles['.gemini/config/rules/$ruleName.md'] = generated(
      languageRules,
      frontmatter:
          'trigger: glob\n'
          'globs: "${languageDoc.globs.join(', ')}"\n'
          'description: "$description"',
    );
    generatedFiles['.cursor/rules/$ruleName.mdc'] = generated(
      languageRules,
      frontmatter:
          'description: $description\n'
          'globs: "${languageDoc.globs.join(',')}"\n'
          'alwaysApply: false',
    );
  }

  // Gemini CLI has no manual-only skill flag, so its explicit invocation is a
  // `/<name>` command that activates the skill.
  for (final skillName in skillNames) {
    generatedFiles['.gemini/commands/$skillName.toml'] =
        '''
# $generatedMarker: edit the ai_rules repo, not this file
description = "Run the $skillName skill (manual only)"
prompt = """
I am explicitly invoking the `$skillName` skill. Activate the `$skillName` skill and follow it exactly.

Task: {{args}}
"""
''';
  }

  return generatedFiles;
}

String generated(String body, {String? frontmatter}) {
  final frontmatterBlock = frontmatter == null
      ? ''
      : '---\n$frontmatter\n---\n';
  final notice =
      '<!-- $generatedMarker: edit the ai_rules repo, not this file -->';
  return '$frontmatterBlock$notice\n\n$body';
}

bool isGeneratedFile(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false) ==
        FileSystemEntityType.file &&
    File(path).readAsStringSync().contains(generatedMarker);

void writeGeneratedFile(String pathFromHome, String content) {
  final targetPath = '$homePath/$pathFromHome';
  final target = File(targetPath);
  final isOurs = isGeneratedFile(targetPath);

  if (isOurs && target.readAsStringSync() == content) return;

  final targetType = FileSystemEntity.typeSync(targetPath, followLinks: false);
  if (targetType != FileSystemEntityType.notFound && !isOurs) {
    moveToBackup(targetPath, targetType);
  }

  target.parent.createSync(recursive: true);
  target.writeAsStringSync(content);
  report('updated', targetPath);
}

void removeGeneratedFile(String pathFromHome) {
  final targetPath = '$homePath/$pathFromHome';
  if (!isGeneratedFile(targetPath)) return;

  File(targetPath).deleteSync();
  report('removed', targetPath);

  final backupPath = '$targetPath$backupSuffix';
  final backupType = FileSystemEntity.typeSync(backupPath, followLinks: false);
  switch (backupType) {
    case FileSystemEntityType.link:
      Link(backupPath).renameSync(targetPath);
      report('restored', targetPath);
    case FileSystemEntityType.file:
      File(backupPath).renameSync(targetPath);
      report('restored', targetPath);
    default:
      break;
  }
}

/// Removes generated files the repo no longer produces, such as the rules of
/// a deleted language or the command of a deleted skill.
void removeStaleGeneratedFiles({required Set<String> keep}) {
  for (final folderFromHome in generatedFileFoldersFromHome) {
    final folder = Directory('$homePath/$folderFromHome');
    if (!folder.existsSync()) continue;

    for (final file in folder.listSync().whereType<File>()) {
      final pathFromHome = '$folderFromHome/${nameOf(file)}';
      if (!keep.contains(pathFromHome) && isGeneratedFile(file.path)) {
        removeGeneratedFile(pathFromHome);
      }
    }
  }
}

/// Moves a file or link out of the way. The first backup keeps the plain
/// [backupSuffix] name, so uninstall restores what was there originally.
void moveToBackup(String path, FileSystemEntityType type) {
  final firstBackupPath = '$path$backupSuffix';
  final firstBackupIsTaken =
      FileSystemEntity.typeSync(firstBackupPath, followLinks: false) !=
      FileSystemEntityType.notFound;
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final backupPath = firstBackupIsTaken
      ? '$path.ai_rules.$timestamp.bak'
      : firstBackupPath;

  switch (type) {
    case FileSystemEntityType.link:
      Link(path).renameSync(backupPath);
    case FileSystemEntityType.directory:
      Directory(path).renameSync(backupPath);
    default:
      File(path).renameSync(backupPath);
  }
  report('backed up', '$path -> $backupPath');
}

/// The repo's skills that are manual-only in every agent, keyed by name.
/// Any other skill is reported and left out.
Map<String, Directory> findInstallableSkills() {
  final installableSkills = <String, Directory>{};
  final skillDirectories = Directory(
    '$repoPath/skills',
  ).listSync().whereType<Directory>();

  for (final skillDirectory in skillDirectories) {
    final skillName = nameOf(skillDirectory);
    final manualOnlyProblem = findManualOnlyProblem(skillDirectory, skillName);
    if (manualOnlyProblem == null) {
      installableSkills[skillName] = skillDirectory;
    } else {
      warn('skill "$skillName" not installed: $manualOnlyProblem');
    }
  }
  return installableSkills;
}

/// Why a skill isn't manual-only in every agent, or null when it is.
String? findManualOnlyProblem(Directory skillDirectory, String skillName) {
  final skillFile = File('${skillDirectory.path}/SKILL.md');
  if (!skillFile.existsSync()) return 'no SKILL.md';

  final frontmatterLines = frontmatterOf(skillFile.readAsStringSync());
  if (!frontmatterLines.contains('name: $skillName')) {
    return 'its frontmatter needs "name: $skillName"';
  }
  if (!frontmatterLines.contains('disable-model-invocation: true')) {
    return 'its frontmatter needs "disable-model-invocation: true"';
  }
  if (frontmatterLines.contains('user-invocable: false')) {
    return '"user-invocable: false" would make it unreachable';
  }

  final codexPolicyFile = File('${skillDirectory.path}/agents/openai.yaml');
  final hasCodexPolicy =
      codexPolicyFile.existsSync() &&
      codexPolicyFile.readAsStringSync().contains(
        'allow_implicit_invocation: false',
      );
  if (!hasCodexPolicy) {
    return 'it needs agents/openai.yaml with "allow_implicit_invocation: false"';
  }
  return null;
}

List<String> frontmatterOf(String markdown) {
  final lines = const LineSplitter().convert(markdown);
  if (lines.isEmpty || lines.first.trim() != '---') return [];
  final closingIndex = lines.indexWhere((line) => line.trim() == '---', 1);
  if (closingIndex == -1) return [];
  return [for (final line in lines.sublist(1, closingIndex)) line.trim()];
}

List<File> mirroredRepoFiles() => [
  for (final repoPathToMirror in mirroredRepoPaths)
    if (File('$repoPath/$repoPathToMirror').existsSync())
      File('$repoPath/$repoPathToMirror')
    else
      ...filesIn(Directory('$repoPath/$repoPathToMirror')),
];

/// Makes [target] an exact copy of [sourceFiles], laid out relative to
/// [sourceRoot]. A [target] that this installer didn't create is left alone.
void syncManagedDirectory({
  required List<File> sourceFiles,
  required Directory sourceRoot,
  required Directory target,
}) {
  final targetType = FileSystemEntity.typeSync(target.path, followLinks: false);
  final isManagedTarget =
      targetType == FileSystemEntityType.directory &&
      isManagedDirectory(target);

  if (targetType != FileSystemEntityType.notFound && !isManagedTarget) {
    warn(
      '${target.path} already exists and isn\'t from ai_rules; left it alone. '
      'Remove it to install the repo\'s copy.',
    );
    return;
  }

  if (isManagedTarget) {
    final isUnchanged =
        fingerprintOf(sourceFiles, sourceRoot) ==
        fingerprintOf(filesIn(target), target);
    if (isUnchanged) return;
    target.deleteSync(recursive: true);
  }

  for (final sourceFile in sourceFiles) {
    final targetFile = File(
      '${target.path}/${relativePathOf(sourceFile, sourceRoot)}',
    );
    targetFile.parent.createSync(recursive: true);
    sourceFile.copySync(targetFile.path);
  }
  File('${target.path}/$managedMarkerFileName').writeAsStringSync(
    'Installed by the ai_rules repo. Edit the repo, not this folder.\n',
  );
  report('updated', '${target.path}/');
}

bool isManagedDirectory(Directory directory) =>
    File('${directory.path}/$managedMarkerFileName').existsSync();

/// Every file's relative path and content, ignoring the managed marker.
String fingerprintOf(List<File> files, Directory root) {
  final entries = <String>[];
  for (final file in files) {
    final relativePath = relativePathOf(file, root);
    if (relativePath == managedMarkerFileName) continue;
    entries.add('$relativePath\n${base64Encode(file.readAsBytesSync())}');
  }
  entries.sort();
  return entries.join('\n\u0000\n');
}

/// Deep-merges a settings fragment from the repo into a tool's settings file,
/// keeping every key the fragment doesn't mention.
void mergeSettings(String fragmentPathInRepo, String settingsPathFromHome) {
  final fragment =
      jsonDecode(readRepoFile(fragmentPathInRepo)) as Map<String, dynamic>;
  final settingsPath = '$homePath/$settingsPathFromHome';
  final settingsFile = File(settingsPath);

  var currentSettings = <String, dynamic>{};
  if (settingsFile.existsSync()) {
    try {
      currentSettings =
          jsonDecode(settingsFile.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException {
      warn(
        '$settingsPath isn\'t plain JSON, so it was left alone. '
        'Add these keys yourself: ${jsonEncode(fragment)}',
      );
      return;
    }
  }

  final mergedSettings = deepMerge(currentSettings, fragment);
  if (jsonEncode(mergedSettings) == jsonEncode(currentSettings)) return;

  final backupPath = '$settingsPath$backupSuffix';
  if (settingsFile.existsSync() && !File(backupPath).existsSync()) {
    settingsFile.copySync(backupPath);
    report('backed up', '$settingsPath -> $backupPath');
  }

  settingsFile.parent.createSync(recursive: true);
  settingsFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(mergedSettings)}\n',
  );
  report('updated', settingsPath);
}

Map<String, dynamic> deepMerge(
  Map<String, dynamic> base,
  Map<String, dynamic> overrides,
) {
  final merged = {...base};
  for (final MapEntry(:key, :value) in overrides.entries) {
    final baseValue = merged[key];
    final bothAreMaps =
        baseValue is Map<String, dynamic> && value is Map<String, dynamic>;
    merged[key] = bothAreMaps ? deepMerge(baseValue, value) : value;
  }
  return merged;
}

/// Points git at `.githooks/`, whose hooks re-run this installer after every
/// commit, pull, and rebase.
void useRepoGitHooks() {
  if (!Directory('$repoPath/.git').existsSync()) {
    print('Not a git clone yet, so the auto-install hooks are off.');
    return;
  }
  Process.runSync('git', [
    'config',
    'core.hooksPath',
    '.githooks',
  ], workingDirectory: repoPath);
  if (!Platform.isWindows) {
    final hookPaths = Directory(
      '$repoPath/.githooks',
    ).listSync().whereType<File>().map((hookFile) => hookFile.path);
    Process.runSync('chmod', ['+x', ...hookPaths]);
  }
}

String readRepoFile(String pathInRepo) =>
    File('$repoPath/$pathInRepo').readAsStringSync();

List<File> filesIn(Directory directory) =>
    directory.listSync(recursive: true).whereType<File>().toList();

String nameOf(FileSystemEntity entity) =>
    entity.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty);

String relativePathOf(File file, Directory root) => file.path
    .replaceAll(r'\', '/')
    .substring(root.path.replaceAll(r'\', '/').length + 1);

void report(String action, String paths) =>
    print('${action.padRight(10)} ${withHomeAsTilde(paths)}');

void warn(String message) =>
    print('${'warning'.padRight(10)} ${withHomeAsTilde(message)}');

String withHomeAsTilde(String text) =>
    text.replaceAll(r'\', '/').replaceAll(homePath, '~');
