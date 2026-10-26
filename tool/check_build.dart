// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String defaultRepo = 'onebotyt/Smart-To-Do';

void main(List<String> args) async {
  bool watchMode = args.contains('--watch') || args.contains('-w');
  String? targetCommit;
  String? targetRunId;
  String repo = defaultRepo;

  for (final arg in args) {
    if (arg.startsWith('--commit=')) {
      targetCommit = arg.substring('--commit='.length);
    } else if (arg.startsWith('--run=')) {
      targetRunId = arg.substring('--run='.length);
    } else if (arg.startsWith('--repo=')) {
      repo = arg.substring('--repo='.length);
    }
  }

  // If no commit specified, try reading the current git HEAD commit
  if (targetCommit == null && targetRunId == null) {
    try {
      final res = await Process.run('git', ['rev-parse', 'HEAD']);
      if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
        targetCommit = res.stdout.toString().trim();
      }
    } catch (_) {}
  }

  print('======================================================');
  print('       SyncTask CI/CD Build & Status Monitor          ');
  print('======================================================');
  print('Repository: $repo');
  if (targetCommit != null) {
    print('Target Commit: ${targetCommit.substring(0, targetCommit.length.clamp(0, 7))}');
  }

  do {
    final status = await checkStatus(
      repo: repo,
      targetCommit: targetCommit,
      targetRunId: targetRunId,
    );

    if (!watchMode || status.isFinished) {
      if (status.isFailed) {
        exitCode = 1;
      }
      break;
    }

    print('\n[Watch Mode] Workflow in progress (${status.status}). Re-checking in 12s... (Ctrl+C to stop)\n');
    await Future.delayed(const Duration(seconds: 12));
  } while (watchMode);
}

class RunStatusSummary {
  final bool isFinished;
  final bool isFailed;
  final String status;
  final String? conclusion;

  const RunStatusSummary({
    required this.isFinished,
    required this.isFailed,
    required this.status,
    this.conclusion,
  });
}

Future<RunStatusSummary> checkStatus({
  required String repo,
  String? targetCommit,
  String? targetRunId,
}) async {
  final client = HttpClient();
  client.userAgent = 'SyncTask-Build-Monitor';

  try {
    Map<String, dynamic>? run;

    if (targetRunId != null) {
      final uri = Uri.parse('https://api.github.com/repos/$repo/actions/runs/$targetRunId');
      final data = await _fetchJson(client, uri);
      if (data is Map<String, dynamic>) {
        run = data;
      }
    } else {
      final uri = Uri.parse('https://api.github.com/repos/$repo/actions/runs?per_page=10');
      final data = await _fetchJson(client, uri);
      if (data is Map<String, dynamic> && data['workflow_runs'] is List) {
        final runs = (data['workflow_runs'] as List).cast<Map<String, dynamic>>();

        if (targetCommit != null) {
          final prefix = targetCommit.substring(0, targetCommit.length.clamp(0, 7));
          for (final r in runs) {
            final sha = (r['head_sha'] as String? ?? '');
            if (sha.startsWith(prefix) || prefix.startsWith(sha)) {
              run = r;
              break;
            }
          }
        }

        // Fallback to latest run if commit match not found
        run ??= runs.isNotEmpty ? runs.first : null;
      }
    }

    if (run == null) {
      print('No GitHub Actions workflow runs found for $repo.');
      return const RunStatusSummary(
        isFinished: true,
        isFailed: false,
        status: 'not_found',
      );
    }

    final runId = run['id'];
    final runNumber = run['run_number'];
    final title = run['display_title'] ?? 'No title';
    final headSha = (run['head_sha'] as String? ?? '').substring(0, 7);
    final status = run['status'] as String? ?? 'unknown';
    final conclusion = run['conclusion'] as String?;
    final htmlUrl = run['html_url'] as String? ?? '';
    final createdAt = run['created_at'] as String? ?? '';

    print('\nWorkflow Run #$runNumber (ID: $runId)');
    print('Title: $title');
    print('Commit: $headSha | Created: $createdAt');
    print('URL: $htmlUrl');

    _printStatusBanner(status: status, conclusion: conclusion);

    // Fetch individual jobs for this run
    final jobsUri = Uri.parse('https://api.github.com/repos/$repo/actions/runs/$runId/jobs');
    final jobsData = await _fetchJson(client, jobsUri);

    final failedJobs = <Map<String, dynamic>>[];

    if (jobsData is Map<String, dynamic> && jobsData['jobs'] is List) {
      final jobs = (jobsData['jobs'] as List).cast<Map<String, dynamic>>();
      print('\nJobs Summary (${jobs.length} jobs):');

      for (final job in jobs) {
        final jobName = job['name'] as String? ?? 'Unnamed Job';
        final jStatus = job['status'] as String? ?? 'unknown';
        final jConclusion = job['conclusion'] as String?;
        final symbol = _statusSymbol(jStatus, jConclusion);

        print('  $symbol $jobName: ${jConclusion ?? jStatus}');

        if (job['steps'] is List) {
          final steps = (job['steps'] as List).cast<Map<String, dynamic>>();
          for (final step in steps) {
            final sName = step['name'] as String? ?? 'Step';
            final sStatus = step['status'] as String? ?? '';
            final sConclusion = step['conclusion'] as String?;
            if (sConclusion == 'failure') {
              print('      ✖ FAILED STEP: $sName');
            } else if (sStatus == 'in_progress') {
              print('      ⏳ Running step: $sName');
            }
          }
        }

        if (jConclusion == 'failure') {
          failedJobs.add(job);
        }
      }
    }

    final isFinished = status == 'completed';
    final isFailed = conclusion == 'failure';

    // If any jobs failed, fetch and display their error logs!
    if (failedJobs.isNotEmpty) {
      print('\n======================================================');
      print('                 FAILURE DIAGNOSTICS                  ');
      print('======================================================');

      for (final job in failedJobs) {
        final jobId = job['id'];
        final jobName = job['name'];
        print('\nFetching error logs for job "$jobName" (ID: $jobId)...');

        final logText = await _fetchJobLogs(client, repo, jobId);
        if (logText != null && logText.isNotEmpty) {
          final errorSnippet = _extractErrorSnippet(logText);
          print('\n--- [Log Output: $jobName] ---');
          print(errorSnippet);
          print('--- [End Log Output] ---\n');
        } else {
          print('Could not retrieve raw log text. View job directly at: ${job['html_url']}');
        }
      }
    }

    if (conclusion == 'success') {
      print('\n✔ Push workflow completed successfully! Release artifacts are published.');
    }

    return RunStatusSummary(
      isFinished: isFinished,
      isFailed: isFailed,
      status: status,
      conclusion: conclusion,
    );
  } finally {
    client.close();
  }
}

void _printStatusBanner({required String status, String? conclusion}) {
  if (conclusion == 'success') {
    print('Status: COMPLETED (SUCCESS) ✔');
  } else if (conclusion == 'failure') {
    print('Status: COMPLETED (FAILED) ✖');
  } else if (conclusion == 'cancelled') {
    print('Status: CANCELLED ⚠');
  } else if (status == 'in_progress') {
    print('Status: IN PROGRESS ⏳ (Running build steps...)');
  } else if (status == 'queued') {
    print('Status: QUEUED ⏱ (Waiting for build runner...)');
  } else {
    print('Status: $status ($conclusion)');
  }
}

String _statusSymbol(String status, String? conclusion) {
  if (conclusion == 'success') return '✔';
  if (conclusion == 'failure') return '✖';
  if (conclusion == 'cancelled') return '⚠';
  if (conclusion == 'skipped') return '↷';
  if (status == 'in_progress') return '⏳';
  return '⏱';
}

Future<dynamic> _fetchJson(HttpClient client, Uri uri) async {
  try {
    final req = await client.getUrl(uri);
    final res = await req.close();
    if (res.statusCode == 200) {
      final body = await utf8.decoder.bind(res).join();
      return jsonDecode(body);
    }
  } catch (_) {}
  return null;
}

Future<String?> _fetchJobLogs(HttpClient client, String repo, dynamic jobId) async {
  try {
    final uri = Uri.parse('https://api.github.com/repos/$repo/actions/jobs/$jobId/logs');
    final req = await client.getUrl(uri);
    req.followRedirects = true;
    final res = await req.close();

    if (res.statusCode == 200) {
      return await utf8.decoder.bind(res).join();
    }
  } catch (_) {}
  return null;
}

String _extractErrorSnippet(String fullLog) {
  final lines = fullLog.split('\n');

  // Search backwards for error markers, or return the tail of the log
  int startIndex = (lines.length - 80).clamp(0, lines.length);

  for (int i = 0; i < lines.length; i++) {
    final l = lines[i].toLowerCase();
    if (l.contains('error:') ||
        l.contains('failed:') ||
        l.contains('fatal:') ||
        l.contains('exception:') ||
        l.contains('failure:')) {
      // Pick a window around the error
      final start = (i - 10).clamp(0, lines.length);
      final end = (i + 40).clamp(0, lines.length);
      return lines.sublist(start, end).join('\n');
    }
  }

  return lines.sublist(startIndex).join('\n');
}
