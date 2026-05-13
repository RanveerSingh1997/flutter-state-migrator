import 'package:flutter/material.dart';

void main() {
  runApp(const ArchitectureIntelligencePlatform());
}

class ArchitectureIntelligencePlatform extends StatelessWidget {
  const ArchitectureIntelligencePlatform({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Architecture Intelligence',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF673AB7),
        scaffoldBackgroundColor: const Color(0xFF0F0F12),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        useMaterial3: true,
      ),
      home: const DashboardHome(),
    );
  }
}

class _DashboardMetric {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _DashboardSmell {
  final String name;
  final String description;
  final String severity;
  final Color color;

  const _DashboardSmell({
    required this.name,
    required this.description,
    required this.severity,
    required this.color,
  });
}

class _GovernanceRule {
  final String name;
  final bool passed;
  final String detail;

  const _GovernanceRule({
    required this.name,
    required this.passed,
    required this.detail,
  });
}

class _MigrationStep {
  final String title;
  final String detail;
  final bool complete;

  const _MigrationStep({
    required this.title,
    required this.detail,
    required this.complete,
  });
}

class _AiInsight {
  final String title;
  final String recommendation;
  final String rationale;

  const _AiInsight({
    required this.title,
    required this.recommendation,
    required this.rationale,
  });
}

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  String _currentView = 'Overview';
  bool _strictGovernance = true;
  bool _mermaidExportEnabled = true;

  static const _architectureHealth = '84.2';

  static const _metrics = <_DashboardMetric>[
    _DashboardMetric(
      title: 'Total Components',
      value: '42',
      icon: Icons.category,
      color: Colors.blue,
    ),
    _DashboardMetric(
      title: 'Relationships',
      value: '128',
      icon: Icons.hub,
      color: Colors.orange,
    ),
    _DashboardMetric(
      title: 'Detected Smells',
      value: '12',
      icon: Icons.warning_amber_rounded,
      color: Colors.redAccent,
    ),
    _DashboardMetric(
      title: 'Governance Rules',
      value: '8',
      icon: Icons.verified_user_outlined,
      color: Colors.greenAccent,
    ),
  ];

  static const _smells = <_DashboardSmell>[
    _DashboardSmell(
      name: 'God Component',
      description:
          'UserAuthController has 24 methods and 11 state transitions.',
      severity: 'High',
      color: Colors.redAccent,
    ),
    _DashboardSmell(
      name: 'Circular Dependency',
      description: 'PaymentService depends on InvoiceGenerator and vice versa.',
      severity: 'High',
      color: Colors.redAccent,
    ),
    _DashboardSmell(
      name: 'State Explosion',
      description: 'OrderController manages 14 independent state fields.',
      severity: 'Medium',
      color: Colors.orangeAccent,
    ),
    _DashboardSmell(
      name: 'Improper Async Pattern',
      description:
          'SyncController uses several await points without AsyncNotifier.',
      severity: 'Info',
      color: Colors.lightBlueAccent,
    ),
  ];

  static const _governanceRules = <_GovernanceRule>[
    _GovernanceRule(
      name: 'Layer Isolation',
      passed: true,
      detail: 'Presentation logic does not read data-layer classes directly.',
    ),
    _GovernanceRule(
      name: 'Forbidden Imports',
      passed: false,
      detail: '1 feature still imports repository APIs from a UI package.',
    ),
    _GovernanceRule(
      name: 'Max Dependency Depth',
      passed: true,
      detail: 'Deepest semantic chain is 4, under the configured limit of 5.',
    ),
    _GovernanceRule(
      name: 'Notifier Hygiene',
      passed: true,
      detail: 'Async-heavy logic is isolated to notifier-style classes.',
    ),
  ];

  static const _migrationSteps = <_MigrationStep>[
    _MigrationStep(
      title: 'Scanner hardening',
      detail: 'Provider, BLoC, GetX, and MobX scanning stabilized.',
      complete: true,
    ),
    _MigrationStep(
      title: 'Transformation correctness',
      detail: 'Consumer, Selector, and body rewrite flows validated.',
      complete: true,
    ),
    _MigrationStep(
      title: 'Architecture intelligence',
      detail: 'Graph, governance, smells, and drift detection are active.',
      complete: true,
    ),
    _MigrationStep(
      title: 'Dashboard rollout',
      detail:
          'Mermaid relationship views and governance summaries are exposed.',
      complete: true,
    ),
  ];

  static const _aiInsights = <_AiInsight>[
    _AiInsight(
      title: 'Split UserAuthController',
      recommendation:
          'Extract token refresh and session persistence into a service.',
      rationale:
          'The controller is responsible for too many unrelated state transitions.',
    ),
    _AiInsight(
      title: 'Break the payment cycle',
      recommendation:
          'Introduce an interface between invoice generation and payment orchestration.',
      rationale:
          'The current cycle prevents clear ownership and raises testing cost.',
    ),
    _AiInsight(
      title: 'Adopt AsyncNotifier',
      recommendation:
          'Move SyncController to AsyncNotifier for explicit loading/error states.',
      rationale:
          'The current async flow toggles loading manually across multiple await points.',
    ),
  ];

  static const _mermaidDiagram = '''
graph TD
  logic_UserAuthController["LOGIC: UserAuthController"]
  logic_PaymentService["SERVICE: PaymentService"]
  logic_InvoiceGenerator["SERVICE: InvoiceGenerator"]
  widget_CheckoutPage["WIDGET: CheckoutPage"]
  usage_CheckoutPageWatch["CONSUMER: PaymentService"]
  provider_RootScope{{"PROVIDER: MultiProvider"}}

  logic_UserAuthController -->|CALLS| logic_PaymentService
  logic_PaymentService -->|CALLS| logic_InvoiceGenerator
  logic_InvoiceGenerator -->|CALLS| logic_PaymentService
  provider_RootScope ===>|PROVIDES| widget_CheckoutPage
  logic_PaymentService -.->|WATCHES| usage_CheckoutPageWatch
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildNavigationRail(),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildNavigationRail() {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Color(0xFF16161D),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 48, bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Colors.deepPurpleAccent,
                  size: 32,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FLUTTER ARCH',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'INTELLIGENCE PLATFORM',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _buildNavItem(Icons.dashboard_rounded, 'Overview'),
          _buildNavItem(Icons.account_tree_rounded, 'Dependency Graph'),
          _buildNavItem(Icons.psychology_rounded, 'Arch Intelligence'),
          _buildNavItem(Icons.gavel_rounded, 'Governance'),
          _buildNavItem(Icons.rocket_launch_rounded, 'Migration Engine'),
          const Divider(color: Colors.white10, height: 32),
          _buildNavItem(Icons.settings_rounded, 'Settings'),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title) {
    final isSelected = _currentView == title;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () => setState(() => _currentView = title),
        leading: Icon(
          icon,
          color: isSelected ? Colors.deepPurpleAccent : Colors.grey,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected
            ? Colors.deepPurpleAccent.withValues(alpha: 0.12)
            : Colors.transparent,
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _currentView,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh),
                label: const Text('Rescan Project'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: SingleChildScrollView(child: _buildCurrentView())),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case 'Dependency Graph':
        return _buildDependencyGraphContent();
      case 'Arch Intelligence':
        return _buildIntelligenceContent();
      case 'Governance':
        return _buildGovernanceContent();
      case 'Migration Engine':
        return _buildMigrationContent();
      case 'Settings':
        return _buildSettingsContent();
      case 'Overview':
      default:
        return _buildOverviewContent();
    }
  }

  Widget _buildOverviewContent() {
    return Column(
      children: [
        Row(
          children: [
            _buildHealthScoreCard(_architectureHealth),
            const SizedBox(width: 24),
            for (final metric in _metrics.take(3)) ...[
              _buildMetricCard(metric),
              const SizedBox(width: 24),
            ],
          ]..removeLast(),
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildRecentSmellsCard()),
            const SizedBox(width: 24),
            Expanded(child: _buildGovernanceSummary()),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthScoreCard(String score) {
    return Expanded(
      child: Card(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurpleAccent.withValues(alpha: 0.22),
                Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Architecture Health',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              FittedBox(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(
                      score,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      ' / 100',
                      style: TextStyle(fontSize: 24, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: 0.842,
                backgroundColor: Colors.white10,
                color: Colors.greenAccent,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              const Text(
                'Driven by semantic smells, governance violations, and dependency graph stability.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(_DashboardMetric metric) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(metric.icon, color: metric.color, size: 32),
              const SizedBox(height: 16),
              Text(
                metric.value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(metric.title, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSmellsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detected Architecture Smells',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            for (final smell in _smells)
              _buildSmellItem(
                smell.name,
                smell.description,
                smell.severity,
                smell.color,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmellItem(
    String name,
    String description,
    String severity,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Container(
          width: 8,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Text(name),
        subtitle: Text(description, style: const TextStyle(color: Colors.grey)),
        trailing: Chip(
          label: Text(severity),
          backgroundColor: color.withValues(alpha: 0.12),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Widget _buildGovernanceSummary() {
    final passedCount = _governanceRules.where((rule) => rule.passed).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Governance Status',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '$passedCount / ${_governanceRules.length} rules passing',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            for (final rule in _governanceRules)
              _buildGovernanceRuleRow(rule.name, rule.passed),
          ],
        ),
      ),
    );
  }

  Widget _buildGovernanceRuleRow(String rule, bool passed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            passed
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            color: passed ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              rule,
              style: TextStyle(color: passed ? Colors.white : Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDependencyGraphContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildMetricCard(_metrics[0]),
            const SizedBox(width: 24),
            _buildMetricCard(_metrics[1]),
            const SizedBox(width: 24),
            _buildMetricCard(_metrics[3]),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mermaid Relationship Diagram',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Active export shape for the CLI visualizer. Teams can paste this into Mermaid-compatible tooling.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11131A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const SelectableText(
                    _mermaidDiagram,
                    key: Key('mermaid-diagram'),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntelligenceContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _aiInsights.map(_buildAiInsightCard).toList(),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Explainable intelligence',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'Every smell, governance warning, and migration recommendation is tied back to semantic graph relationships rather than regex-only heuristics.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiInsightCard(_AiInsight insight) {
    return SizedBox(
      width: 360,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                insight.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                insight.recommendation,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                insight.rationale,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGovernanceContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Governance Contracts',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            for (final rule in _governanceRules)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  rule.passed ? Icons.verified : Icons.warning_amber_rounded,
                  color: rule.passed ? Colors.greenAccent : Colors.orangeAccent,
                ),
                title: Text(rule.name),
                subtitle: Text(
                  rule.detail,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMigrationContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Migration Rollout',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            for (final step in _migrationSteps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  step.complete
                      ? Icons.task_alt_rounded
                      : Icons.timelapse_rounded,
                  color: step.complete
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                ),
                title: Text(step.title),
                subtitle: Text(
                  step.detail,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Runtime Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _strictGovernance,
              title: const Text('Strict governance enforcement'),
              subtitle: const Text(
                'Fail CI when architecture contracts are broken.',
              ),
              onChanged: (value) => setState(() => _strictGovernance = value),
            ),
            SwitchListTile(
              value: _mermaidExportEnabled,
              title: const Text('Mermaid export enabled'),
              subtitle: const Text(
                'Persist architecture_graph.mmd during visualization runs.',
              ),
              onChanged: (value) =>
                  setState(() => _mermaidExportEnabled = value),
            ),
          ],
        ),
      ),
    );
  }
}
