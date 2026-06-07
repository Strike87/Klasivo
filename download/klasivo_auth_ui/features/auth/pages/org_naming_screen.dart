import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_constants.dart';
import '../../../providers/auth_provider.dart';

/// Post-login screen where the teacher names their organization/workspace.
/// Shows auto-generated name suggestions based on the user's name.
/// Cannot be skipped — required for org setup.
class OrgNamingScreen extends ConsumerStatefulWidget {
  const OrgNamingScreen({super.key});

  @override
  ConsumerState<OrgNamingScreen> createState() => _OrgNamingScreenState();
}

class _OrgNamingScreenState extends ConsumerState<OrgNamingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orgNameController = TextEditingController();
  List<String> _suggestions = [];
  bool _isLoading = false;
  bool _isGeneratingSuggestions = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isGeneratingSuggestions = true);
    try {
      final suggestions = await ref
          .read(authNotifierProvider.notifier)
          .generateWorkspaceSuggestions();
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isGeneratingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingSuggestions = false);
      }
    }
  }

  Future<void> _handleCompleteSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authNotifierProvider.notifier).completeOwnerSetup(
            organizationName: _orgNameController.text.trim(),
          );

      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to set up workspace. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectSuggestion(String suggestion) {
    _orgNameController.text = suggestion;
    _orgNameController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // ── Header ──
                _buildHeader(theme),
                const SizedBox(height: 36),

                // ── Org Name Input ──
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _orgNameController,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.words,
                        onFieldSubmitted: (_) => _handleCompleteSetup(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Workspace name is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          if (value.trim().length > 60) {
                            return 'Name must be 60 characters or less';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Workspace Name',
                          hintText: 'e.g. Al-Noor Academy',
                          prefixIcon: Icon(
                            Icons.business_outlined,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Submit Button ──
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _handleCompleteSetup,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Set Up Workspace'),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 20,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // ── Auto-Suggestions ──
                _buildSuggestionsSection(theme),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.primary.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.rocket_launch_rounded,
            size: 42,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Name Your Workspace',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Give your school or organization a name.\nYou can always change it later in Settings.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSuggestionsSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    if (_isGeneratingSuggestions) {
      return Column(
        children: [
          Text(
            'Generating suggestions for you...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      );
    }

    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: colorScheme.tertiary,
            ),
            const SizedBox(width: 6),
            Text(
              'Suggested Names',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.tertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions.map((suggestion) {
            return ActionChip(
              label: Text(suggestion),
              onPressed: () => _selectSuggestion(suggestion),
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              side: BorderSide(
                color: colorScheme.primary.withOpacity(0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
