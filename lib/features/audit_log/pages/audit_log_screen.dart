import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../providers/audit_log_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/config/app_constants.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(auditLogsListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
      ),
      body: logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No Activity Yet',
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('Actions performed by your team will appear here',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final log = logs[index];
                return _AuditLogTile(log: log);
              },
            ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  final AuditLogData log;
  const _AuditLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(log.actionColor).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(log.actionIcon, size: 16, color: Color(log.actionColor)),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User + Action
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: log.userName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: ' ${_actionVerb(log.action)} ',
                        style: TextStyle(color: Color(log.actionColor), fontWeight: FontWeight.w500),
                      ),
                      TextSpan(
                        text: _targetLabel(log.targetType),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (log.targetName != null)
                        TextSpan(
                          text: ' "${log.targetName}"',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),

                // Details + Timestamp
                if (log.details != null)
                  Text(log.details!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(
                  log.timestamp != null ? timeago.format(log.timestamp!) : '',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _actionVerb(String action) => switch (action) {
    'create' => 'created',
    'update' => 'updated',
    'delete' => 'deleted',
    'publish' => 'published',
    'archive' => 'archived',
    'submit' => 'submitted',
    'grade' => 'graded',
    'link' => 'linked',
    'revoke' => 'revoked',
    _ => action,
  };

  String _targetLabel(String type) => switch (type) {
    'exam' => 'exam',
    'class' => 'class',
    'student' => 'student',
    'teacher' => 'teacher',
    'assignment' => 'assignment',
    'announcement' => 'announcement',
    'gradebook' => 'gradebook',
    'attendance' => 'attendance',
    'question_bank' => 'question bank',
    'organization' => 'organization',
    'invite_code' => 'invite code',
    'academic_year' => 'academic year',
    _ => type,
  };
}
