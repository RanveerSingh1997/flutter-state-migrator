import 'package:flutter/material.dart';

void main() {
  runApp(const MigrationDashboard());
}

class MigrationDashboard extends StatelessWidget {
  const MigrationDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter State Migrator Dashboard',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚀 Migration Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {},
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            color: Colors.black26,
            child: ListView(
              children: [
                const DrawerHeader(
                  child: Center(
                    child: Text(
                      'Migrator v1.0.0',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Overview'),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Logic Units'),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.widgets),
                  title: const Text('Widgets'),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.bar_chart),
                  title: const Text('Audit Report'),
                  onTap: () {},
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Migration Overview',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildStatCard('Total Files', '24', Colors.blue),
                      _buildStatCard('Providers', '12', Colors.orange),
                      _buildStatCard('Consumers', '45', Colors.green),
                      _buildStatCard('Complexity', '84.5', Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Pending Transformations',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      child: ListView.builder(
                        itemCount: 5,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(Icons.insert_drive_file),
                            title: Text('lib/models/counter_model_${index + 1}.dart'),
                            subtitle: const Text('3 Logic Units, 1 Provider'),
                            trailing: ElevatedButton(
                              onPressed: () {},
                              child: const Text('View Diff'),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
