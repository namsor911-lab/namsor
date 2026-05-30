#!/usr/bin/env node

import { access, readFile, writeFile, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import readline from 'node:readline';
import { fileURLToPath } from 'node:url';
import chalk from 'chalk';
import ora from 'ora';
import fg from 'fast-glob';
import axios from 'axios';
import open from 'open';
import { execa } from 'execa';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname);
const firebaseJsonPath = path.join(rootDir, 'firebase.json');
const firebaseRcPath = path.join(rootDir, '.firebaserc');
const buildWebDir = path.join(rootDir, 'build', 'web');
const localWebDir = path.join(rootDir, 'web');
const envFilePath = path.join(rootDir, '.env');

const argv = process.argv.slice(2);
const flags = {
  fix: argv.includes('--fix'),
  json: argv.includes('--json'),
  verbose: argv.includes('--verbose') || argv.includes('-v'),
};

const defaultColors = {
  success: chalk.green,
  warning: chalk.yellow,
  error: chalk.red,
  info: chalk.cyan,
  title: chalk.bold.white,
};

const spinner = ora({
  color: 'cyan',
});

function formatDuration(ms) {
  const sec = Math.floor(ms / 1000);
  const min = Math.floor(sec / 60);
  const remainder = sec % 60;
  return `${min}m ${remainder}s`;
}

async function safeReadJson(filePath) {
  const raw = await readFile(filePath, 'utf8');
  return JSON.parse(raw);
}

async function fileExists(filePath) {
  try {
    await access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function runCommand(command, args, opts = {}) {
  try {
    const result = await execa(command, args, { preferLocal: true, ...opts });
    return { success: true, stdout: result.stdout, stderr: result.stderr };
  } catch (error) {
    return {
      success: false,
      stdout: error.stdout?.toString() ?? '',
      stderr: error.stderr?.toString() ?? '',
      message: error.message,
    };
  }
}

function logResult(label, message, type = 'info') {
  if (flags.json) return;
  const prefix = {
    info: defaultColors.info('[INFO]'),
    success: defaultColors.success('[OK]'),
    warning: defaultColors.warning('[WARN]'),
    error: defaultColors.error('[ERR]'),
  }[type];
  console.log(`${prefix} ${label}${message ? ` ${message}` : ''}`);
}

function visible(value) {
  return typeof value === 'string' && value.trim().length > 0 ? value : String(value);
}

async function promptUser(question, choices = []) {
  if (flags.json) return null;
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const finalQuestion = choices.length
    ? `${question}\n${choices.map((c, idx) => `  ${idx + 1}. ${c}`).join('\n')}\nEnter number: `
    : `${question} `;

  return new Promise((resolve) => {
    rl.question(finalQuestion, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

async function loadJsonFile(filePath) {
  if (!(await fileExists(filePath))) return null;
  try {
    return await safeReadJson(filePath);
  } catch (error) {
    return null;
  }
}

function inspectRewriteConfig(firebaseJson) {
  const errors = [];
  const warnings = [];
  if (!firebaseJson.hosting) {
    errors.push('Missing hosting configuration in firebase.json');
    return { errors, warnings };
  }

  const hosting = firebaseJson.hosting;
  const hasPublic = typeof hosting.public === 'string' && hosting.public.length > 0;
  if (!hasPublic) {
    warnings.push('firebase.json does not define a hosting.public directory');
  } else if (hosting.public !== 'build/web') {
    warnings.push(`hosting.public is set to '${hosting.public}', expected 'build/web' for Flutter web deployment`);
  }

  const rewrites = Array.isArray(hosting.rewrites) ? hosting.rewrites : [];
  const hasFallback = rewrites.some((rewrite) => rewrite.source === '**' && rewrite.destination === '/index.html');
  if (!hasFallback) {
    errors.push('firebase.json is missing a single-page app fallback rewrite for Flutter web');
  }

  return { errors, warnings, hasFallback, hasPublic };
}

function summarizeIssues(issues) {
  const summary = [];
  for (const issue of issues) {
    const prefix = issue.severity === 'error' ? 'ERROR' : issue.severity === 'warning' ? 'WARNING' : 'NOTE';
    summary.push({ level: prefix, message: issue.message, fix: issue.fix || null });
  }
  return summary;
}

function buildCorrectedFirebaseJson(originalJson) {
  const copy = JSON.parse(JSON.stringify(originalJson ?? {}));
  if (!copy.hosting) copy.hosting = {};
  copy.hosting.public = 'build/web';
  copy.hosting.ignore = copy.hosting.ignore || ['firebase.json', '**/.*', '**/node_modules/**'];
  copy.hosting.rewrites = [{ source: '**', destination: '/index.html' }];
  return copy;
}

async function scanForLocalhostPatterns(rootPath) {
  const patterns = ['**/*.{dart,html,js,ts,css,yaml,yml,json}'];
  const ignore = ['**/node_modules/**', '**/.git/**', '**/build/**'];
  const paths = await fg(patterns, { cwd: rootPath, absolute: true, ignore, onlyFiles: true, unique: true });
  const findings = [];
  const regex = /localhost|127\.0\.0\.1|http:\/\/localhost|https?:\/\/127\.0\.0\.1/gi;
  for (const filePath of paths) {
    try {
      const content = await readFile(filePath, 'utf8');
      let match;
      while ((match = regex.exec(content))) {
        findings.push({ file: path.relative(rootDir, filePath), match: match[0] });
      }
    } catch {
      // ignore unreadable files
    }
  }
  return findings;
}

function formatFixCommand(issue) {
  if (!issue.fix) return null;
  return issue.fix;
}

async function createEnvFile(recommendedUrl, outputPath) {
  const contents = `# Flutter environment configuration
APP_BASE_URL=${recommendedUrl}
# Add other API or auth endpoints below
# SECONDARY_API=https://api.example.com
`;
  await writeFile(outputPath, contents, 'utf8');
  return outputPath;
}

async function analyzeHosting() {
  const issues = [];
  const results = {
    firebaseToolsInstalled: false,
    firebaseVersion: null,
    firebaseJson: null,
    firebaseRc: null,
    hostingSites: null,
    hostingChannels: null,
    localBuild: null,
    remoteIndexStatus: null,
    remoteHeaders: null,
    localhostFindings: null,
    flutterBuildStatus: null,
    fileComparisons: null,
    suggestedUrl: null,
  };

  spinner.start('Checking Firebase CLI availability');
  const firebaseV = await runCommand('firebase', ['--version']);
  if (firebaseV.success) {
    results.firebaseToolsInstalled = true;
    results.firebaseVersion = firebaseV.stdout.trim();
    spinner.succeed(`Firebase CLI available: ${results.firebaseVersion}`);
  } else {
    spinner.fail('Firebase CLI not found or not available in PATH');
    issues.push({ severity: 'error', message: 'firebase-tools is not installed or not available in PATH', fix: 'Install Firebase CLI: npm install -g firebase-tools' });
  }

  spinner.start('Reading firebase.json configuration');
  const firebaseJson = await loadJsonFile(firebaseJsonPath);
  results.firebaseJson = firebaseJson;
  if (!firebaseJson) {
    spinner.fail('Unable to read firebase.json');
    issues.push({ severity: 'error', message: 'firebase.json is missing or malformed', fix: 'Create a valid firebase.json with hosting configuration' });
  } else {
    const rewriteInspection = inspectRewriteConfig(firebaseJson);
    if (rewriteInspection.errors.length) {
      rewriteInspection.errors.forEach((message) => issues.push({ severity: 'error', message, fix: 'Add a fallback rewrite in firebase.json: {"source":"**","destination":"/index.html"}' }));
    }
    if (rewriteInspection.warnings.length) {
      rewriteInspection.warnings.forEach((message) => issues.push({ severity: 'warning', message }));
    }
    spinner.succeed('firebase.json loaded and validated');
  }

  spinner.start('Reading .firebaserc alias configuration');
  const firebaseRc = await loadJsonFile(firebaseRcPath);
  results.firebaseRc = firebaseRc;
  if (!firebaseRc) {
    spinner.fail('.firebaserc missing or malformed');
    issues.push({ severity: 'error', message: '.firebaserc is missing or malformed', fix: 'Create .firebaserc with default project alias' });
  } else {
    const defaultProject = firebaseRc.projects?.default;
    if (!defaultProject) {
      spinner.fail('.firebaserc does not contain a default project alias');
      issues.push({ severity: 'warning', message: '.firebaserc missing default project alias', fix: 'Add {"projects":{"default":"<project-id>"}} to .firebaserc' });
    } else {
      spinner.succeed(`.firebaserc default alias found: ${defaultProject}`);
      results.suggestedUrl = `https://${defaultProject}.web.app`;
    }
  }

  if (results.firebaseToolsInstalled) {
    spinner.start('Listing Firebase Hosting sites');
    const sites = await runCommand('firebase', ['hosting:sites:list', '--json']);
    if (sites.success && sites.stdout) {
      try {
        results.hostingSites = JSON.parse(sites.stdout);
        spinner.succeed('Firebase Hosting sites listed');
      } catch {
        spinner.fail('Unable to parse hosting site list output');
        results.hostingSites = null;
      }
    } else {
      spinner.fail('Could not list Firebase Hosting sites');
      results.hostingSites = null;
      if (flags.verbose) logResult('debug', sites.stderr || sites.message, 'warning');
    }

    spinner.start('Listing Firebase Hosting channels');
    const channels = await runCommand('firebase', ['hosting:channel:list', '--json']);
    if (channels.success && channels.stdout) {
      try {
        results.hostingChannels = JSON.parse(channels.stdout);
        spinner.succeed('Firebase Hosting channels listed');
      } catch {
        spinner.fail('Unable to parse hosting channels output');
      }
    } else {
      spinner.fail('Could not list Firebase Hosting channels');
      if (flags.verbose) logResult('debug', channels.stderr || channels.message, 'warning');
    }
  }

  spinner.start('Scanning for hardcoded localhost URLs');
  const localhostFindings = await scanForLocalhostPatterns(rootDir);
  results.localhostFindings = localhostFindings;
  if (localhostFindings.length) {
    spinner.warn(`Found ${localhostFindings.length} hardcoded localhost/127.0.0.1 references`);
    localhostFindings.forEach((finding) => {
      issues.push({ severity: 'warning', message: `Localhost reference in ${finding.file}: ${finding.match}`, fix: 'Replace hardcoded localhost with an environment-driven base URL' });
    });
  } else {
    spinner.succeed('No hardcoded localhost references found');
  }

  spinner.start('Checking local Flutter web build artifacts');
  const buildIndexPath = path.join(buildWebDir, 'index.html');
  const buildMainPath = path.join(buildWebDir, 'main.dart.js');
  const assetsDir = path.join(buildWebDir, 'assets');
  const localBuildExists = await fileExists(buildIndexPath) && await fileExists(buildMainPath) && await fileExists(assetsDir);
  results.localBuild = { exists: localBuildExists, index: buildIndexPath, main: buildMainPath, assetsDir };
  if (!localBuildExists) {
    spinner.fail('Local Flutter build/web artifacts are missing');
    issues.push({ severity: 'error', message: 'build/web artifacts not found. Run flutter build web --release', fix: 'flutter build web --release' });
  } else {
    spinner.succeed('Local build/web artifacts found');
  }

  if (results.suggestedUrl) {
    spinner.start(`Validating deployed URL ${results.suggestedUrl}`);
    try {
      const response = await axios.get(results.suggestedUrl, { timeout: 15000, maxRedirects: 5 });
      results.remoteIndexStatus = response.status;
      results.remoteHeaders = response.headers;
      spinner.succeed(`Deployed URL reachable: HTTP ${response.status}`);
      if (response.status !== 200) {
        issues.push({ severity: 'warning', message: `Deployed URL returned HTTP ${response.status}` });
      }
      const corsHeader = response.headers['access-control-allow-origin'];
      if (!corsHeader) {
        issues.push({ severity: 'warning', message: 'No Access-Control-Allow-Origin header found on deployed site. External API requests may fail due to CORS.' });
      }
    } catch (error) {
      spinner.fail(`Unable to access deployed URL: ${error.message}`);
      issues.push({ severity: 'error', message: `Failed to reach deployed URL ${results.suggestedUrl}`, fix: 'Verify the hosting site is deployed and the domain is correct' });
    }
  }

  if (results.localBuild.exists && results.suggestedUrl) {
    spinner.start('Comparing local build index.html with deployed index.html');
    try {
      const remoteIndex = await axios.get(results.suggestedUrl, { timeout: 15000, maxRedirects: 5 });
      const localIndex = await readFile(path.join(buildWebDir, 'index.html'), 'utf8');
      const deployedHtml = remoteIndex.data.toString();
      const localHash = Buffer.from(localIndex).toString('base64').slice(0, 16);
      const remoteHash = Buffer.from(deployedHtml).toString('base64').slice(0, 16);
      results.fileComparisons = { localHash, remoteHash, remoteStatus: remoteIndex.status };
      if (localHash !== remoteHash) {
        spinner.warn('Local build differs from deployed index.html');
        issues.push({ severity: 'warning', message: 'Local build/web/index.html content differs from deployed site', fix: 'Deploy the latest build with firebase deploy --only hosting' });
      } else {
        spinner.succeed('Local build index.html matches the deployed file signature');
      }
    } catch (error) {
      spinner.fail(`Comparison failed: ${error.message}`);
    }
  }

  spinner.start('Checking Flutter web build command');
  const flutterBuild = await runCommand('flutter', ['build', 'web', '--release'], { cwd: rootDir, timeout: 1000 * 300 });
  if (flutterBuild.success) {
    results.flutterBuildStatus = { success: true, output: flutterBuild.stdout.slice(0, 4000) };
    spinner.succeed('flutter build web --release completed successfully');
  } else {
    results.flutterBuildStatus = { success: false, stderr: flutterBuild.stderr || flutterBuild.stdout || flutterBuild.message };
    spinner.fail('flutter build web --release failed');
    issues.push({ severity: 'error', message: 'Flutter web build failed', fix: 'Inspect flutter build web --release output and fix build issues' });
    if (flags.verbose) logResult('debug', flutterBuild.stderr || flutterBuild.stdout || flutterBuild.message, 'warning');
  }

  if (results.localBuild.exists) {
    const indexHtml = await readFile(path.join(buildWebDir, 'index.html'), 'utf8');
    if (indexHtml.includes('canvaskit') || indexHtml.includes('flutter_canvas')) {
      issues.push({ severity: 'warning', message: 'Flutter web build may include CanvasKit assets; verify this matches your desired renderer strategy', fix: 'Set renderer or use auto in index.html if needed' });
    }
    if (indexHtml.includes('flutter.js') && !indexHtml.includes('flutter_service_worker.js')) {
      issues.push({ severity: 'warning', message: 'The build index.html may not include service worker configuration expected for Flutter web' });
    }
  }

  if (await fileExists(path.join(rootDir, 'firestore.rules')) || await fileExists(path.join(rootDir, 'storage.rules'))) {
    spinner.start('Inspecting Firebase security rules files');
    const hasFirestoreRules = await fileExists(path.join(rootDir, 'firestore.rules'));
    const hasStorageRules = await fileExists(path.join(rootDir, 'storage.rules'));
    if (!hasFirestoreRules && !hasStorageRules) {
      spinner.info('No Firestore or Storage rules found in project root');
    } else {
      if (hasFirestoreRules) issues.push({ severity: 'warning', message: 'Review Firestore security rules for open access if using Firestore APIs from web', fix: 'Restrict Firestore rules to authenticated users where appropriate' });
      if (hasStorageRules) issues.push({ severity: 'warning', message: 'Review Storage security rules for open access if using Firebase Storage from web', fix: 'Restrict Storage rules to authenticated users where appropriate' });
      spinner.succeed('Security rules presence detected');
    }
  }

  if (flags.fix && firebaseJson) {
    const corrected = buildCorrectedFirebaseJson(firebaseJson);
    await writeFile(firebaseJsonPath, JSON.stringify(corrected, null, 2), 'utf8');
    issues.push({ severity: 'info', message: 'firebase.json was auto-corrected for Flutter web hosting fallback and public directory', fix: null });
  }

  const summary = summarizeIssues(issues);
  results.issues = summary;
  results.commands = [
    'npm install -g firebase-tools',
    'flutter build web --release',
    'firebase deploy --only hosting',
    'firebase login',
  ];
  results.recommendedFirebaseJson = buildCorrectedFirebaseJson(firebaseJson);
  results.envExample = {
    APP_BASE_URL: results.suggestedUrl || 'https://<your-project>.web.app',
    API_BASE_URL: 'https://api.example.com',
  };

  return results;
}

function printSummary(results) {
  if (flags.json) {
    console.log(JSON.stringify(results, null, 2));
    return;
  }

  console.log(defaultColors.title('\nFirebase Hosting Diagnostics Summary\n'));
  if (!results.issues.length) {
    console.log(defaultColors.success('No issues found. Your Flutter web hosting setup looks healthy.'));
  } else {
    results.issues.forEach((issue) => {
      const color = issue.level === 'ERROR' ? defaultColors.error : issue.level === 'WARNING' ? defaultColors.warning : defaultColors.info;
      console.log(color(`${issue.level}: ${issue.message}`));
      if (issue.fix) console.log(defaultColors.info(`    Fix: ${issue.fix}`));
    });
  }

  console.log(defaultColors.title('\nRecommended fix commands:'));
  results.commands.forEach((cmd) => console.log(`  ${chalk.white(cmd)}`));

  console.log(defaultColors.title('\nCorrected firebase.json preview:'));
  console.log(chalk.gray(JSON.stringify(results.recommendedFirebaseJson, null, 2)));

  console.log(defaultColors.title('\nEnvironment variable strategy:'));
  console.log(chalk.gray(`Use a .env file to define APP_BASE_URL and API_BASE_URL, then read these values in your Flutter web app on startup.`));
  console.log(chalk.gray(`Example: APP_BASE_URL=${results.envExample.APP_BASE_URL}`));
  console.log(chalk.gray(`          API_BASE_URL=${results.envExample.API_BASE_URL}`));
}

async function runPostChecks(results) {
  if (flags.json) return;
  const choices = [
    'View detailed deployment instructions',
    'Run firebase deploy --only hosting',
    'Open the deployed URL in browser',
    'Generate a .env configuration file for URL management',
    'Exit without additional actions',
  ];

  const answer = await promptUser('Choose one action to continue:', choices);
  const choice = parseInt(answer, 10);
  switch (choice) {
    case 1:
      console.log(defaultColors.info('\nDetailed deployment instructions:'));
      console.log(chalk.white(`1) Confirm firebase.json has public: build/web and SPA rewrite.`));
      console.log(chalk.white(`2) Run flutter build web --release.`));
      console.log(chalk.white(`3) Run firebase deploy --only hosting.`));
      console.log(chalk.white(`4) Open ${results.suggestedUrl || '<your-hosting-url>'} to validate the live site.`));
      break;
    case 2:
      console.log(defaultColors.info('\nRunning firebase deploy --only hosting...'));
      await execa('firebase', ['deploy', '--only', 'hosting'], { stdio: 'inherit', cwd: rootDir });
      break;
    case 3:
      if (!results.suggestedUrl) {
        console.log(defaultColors.warning('No deployed URL detected from .firebaserc default project alias.')); 
        break;
      }
      console.log(defaultColors.info(`Opening ${results.suggestedUrl}`));
      await open(results.suggestedUrl);
      break;
    case 4:
      const targetUrl = results.suggestedUrl || 'https://<your-project>.web.app';
      await createEnvFile(targetUrl, envFilePath);
      console.log(defaultColors.success(`Generated ${envFilePath}`));
      break;
    default:
      console.log(defaultColors.info('No additional action taken.'));
  }
}

async function main() {
  try {
    const results = await analyzeHosting();
    spinner.stop();
    printSummary(results);
    await runPostChecks(results);
  } catch (error) {
    spinner.fail('Unexpected error during diagnostics');
    if (flags.verbose) console.error(error);
    else console.error(chalk.red(error.message || String(error)));
    process.exit(1);
  }
}

main();
