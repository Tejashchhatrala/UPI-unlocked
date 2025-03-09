import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsSummary extends StatefulWidget {
  const AnalyticsSummary({super.key});

  @override
  State<AnalyticsSummary> createState() => _AnalyticsSummaryState();
}

class _AnalyticsSummaryState extends State<AnalyticsSummary> {
  String _timeRange = 'Today'; // Today, Week, Month
  bool _isLoading = false;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final vendorId = FirebaseAuth.instance.currentUser!.uid;
      final DateTime now = DateTime.now();
      DateTime startDate;

      // Calculate start date based on selected range
      switch (_timeRange) {
        case 'Week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'Month':
          startDate = now.subtract(const Duration(days: 30));
          break;
        default: // Today
          startDate = DateTime(now.year, now.month, now.day);
      }

      // Get orders within date range
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: vendorId)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .get();

      double totalRevenue = 0;
      int totalOrders = 0;
      Map<String, int> popularItems = {};

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        totalRevenue += (data['total'] ?? 0).toDouble();
        totalOrders++;

        // Count popular items
        for (var item in (data['items'] as List? ?? [])) {
          final itemName = item['name'] as String;
          popularItems[itemName] = (popularItems[itemName] ?? 0) + 1;
        }
      }

      setState(() {
        _stats = {
          'totalRevenue': totalRevenue,
          'totalOrders': totalOrders,
          'averageOrderValue': totalOrders > 0 ? totalRevenue / totalOrders : 0,
          'popularItems': popularItems,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading statistics: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time range selector
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Today', label: Text('Today')),
              ButtonSegment(value: 'Week', label: Text('Week')),
              ButtonSegment(value: 'Month', label: Text('Month')),
            ],
            selected: {_timeRange},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _timeRange = newSelection.first;
              });
              _loadStats();
            },
          ),
          const SizedBox(height: 24),

          // Summary cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Total Revenue',
                  value: '₹${_stats['totalRevenue']?.toStringAsFixed(2) ?? '0'}',
                  icon: Icons.currency_rupee,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: 'Total Orders',
                  value: '${_stats['totalOrders'] ?? 0}',
                  icon: Icons.shopping_bag,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Average Order',
                  value: '₹${_stats['averageOrderValue']?.toStringAsFixed(2) ?? '0'}',
                  icon: Icons.analytics,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: _StatCard(
                  title: 'Active Hours',
                  value: 'Coming soon',
                  icon: Icons.access_time,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text(
            'Popular Items',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Popular items chart
          if (_stats['popularItems']?.isNotEmpty ?? false)
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (_stats['popularItems'] as Map<String, int>)
                      .values
                      .reduce((a, b) => a > b ? a : b)
                      .toDouble(),
                  barGroups: _createBarGroups(),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final items = _stats['popularItems'] as Map<String, int>;
                          final itemName = items.keys.elementAt(value.toInt());
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              itemName.length > 10
                                  ? '${itemName.substring(0, 10)}...'
                                  : itemName,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            const Center(
              child: Text('No data available'),
            ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _createBarGroups() {
    final items = _stats['popularItems'] as Map<String, int>;
    return List.generate(items.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: items.values.elementAt(index).toDouble(),
            color: Colors.blue,
          ),
        ],
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}