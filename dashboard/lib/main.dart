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

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  String _currentView = 'Overview';

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
      child: Column(
        children: [
          const SizedBox(height: 48),
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
          const Spacer(),
          const Divider(color: Colors.white10),
          _buildNavItem(Icons.settings_rounded, 'Settings'),
          const SizedBox(height: 24),
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
            ? Colors.deepPurpleAccent.withOpacity(0.1)
            : Colors.transparent,
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currentView,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh),
                label: const Text('Rescan Project'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (_currentView == 'Overview') _buildOverviewContent(),
          if (_currentView == 'Arch Intelligence') _buildIntelligenceContent(),
        ],
      ),
    );
  }

  Widget _buildOverviewContent() {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: [
                _buildHealthScoreCard('84.2'),
                const SizedBox(width: 24),
                _buildMetricCard(
                  'Total Components',
                  '42',
                  Icons.category,
                  Colors.blue,
                ),
                const SizedBox(width: 24),
                _buildMetricCard(
                  'Relationships',
                  '128',
                  Icons.hub,
                  Colors.orange,
                ),
                const SizedBox(width: 24),
                _buildMetricCard(
                  'Detected Smells',
                  '12',
                  Icons.warning_amber_rounded,
                  Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildRecentSmellsCard()),
                const SizedBox(width: 32),
                Expanded(flex: 1, child: _buildGovernanceSummary()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthScoreCard(String score) {
    return Expanded(
      child: Card(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurpleAccent.withOpacity(0.2),
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
              Row(
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
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: 0.84,
                backgroundColor: Colors.white10,
                color: Colors.greenAccent,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSmellsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detected Architecture Smells',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSmellItem(
              'God Component',
              'UserAuthController has 24 methods.',
              'High',
              Colors.redAccent,
            ),
            _buildSmellItem(
              'Circular Dependency',
              'PaymentService ↔️ InvoiceGenerator',
              'High',
              Colors.redAccent,
            ),
            _buildSmellItem(
              'State Explosion',
              'OrderController has 14 state fields.',
              'Medium',
              Colors.orangeAccent,
            ),
            _buildSmellItem(
              'Logic Leakage',
              'SettingsPage.dart contains heavy inline logic.',
              'Medium',
              Colors.orangeAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmellItem(
    String name,
    String desc,
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
        subtitle: Text(desc, style: const TextStyle(color: Colors.grey)),
        trailing: Chip(
          label: Text(severity),
          backgroundColor: color.withOpacity(0.1),
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
      ),
    );
  }

  Widget _buildGovernanceSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Governance Status',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildGovRule('Layer Isolation', true),
            _buildGovRule('Forbidden Imports', false),
            _buildGovRule('Max Dependency Depth', true),
            _buildGovRule('Naming Conventions', true),
          ],
        ),
      ),
    );
  }

  Widget _buildGovRule(String rule, bool passed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            passed
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            color: passed ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 12),
          Text(
            rule,
            style: TextStyle(color: passed ? Colors.white : Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildIntelligenceContent() {
    return const Center(
      child: Text('Deep Architecture Analysis Engine arriving in Phase 38.'),
    );
  }
}
