import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsSummary extends StatefulWidget {
  const AnalyticsSummary({super.key});

  @override
  State<AnalyticsSummary> createState() => _AnalyticsSummaryState();
}

class _AnalyticsSummaryState extends State<AnalyticsSummary> {
  String _timeRange = 'Week'; // Week, Month, Year
  bool _isLoading = false;
  Map<String, dynamic> _analyticsData = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
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
          startDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case 'Year':
          startDate = DateTime(now.year - 1, now.month, now.day);
          break;
        default:
          startDate = now.subtract(const Duration(days: 7));
      }

      // Get orders within date range
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: vendorId)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .get();

      // Calculate analytics
      double totalRevenue = 0;
      int totalOrders = 0;
      Map<String, int> itemsSold = {};
      Map<String, double> categoryRevenue = {};
      Map<String, int> ordersByDay = {};
      Map<String, double> revenueByDay = {};

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final orderDate = (data['createdAt'] as Timestamp).toDate();
        final dateKey = DateFormat('yyyy-MM-dd').format(orderDate);
        final items = data['items'] as List<dynamic>;
        final orderTotal = (data['total'] ?? 0).toDouble();

        // Update totals
        totalRevenue += orderTotal;
        totalOrders++;

        // Update daily stats
        ordersByDay[dateKey] = (ordersByDay[dateKey] ?? 0) + 1;
        revenueByDay[dateKey] = (revenueByDay[dateKey] ?? 0) + orderTotal;

        // Update item and category stats
        for (var item in items) {
          final itemName = item['name'] as String;
          final category = item['category'] as String;
          final quantity = item['quantity'] as int;
          final price = item['price'] as num;

          itemsSold[itemName] = (itemsSold[itemName] ?? 0) + quantity;
          categoryRevenue[category] = 
              (categoryRevenue[category] ?? 0) + (price * quantity);
        }
      }

      setState(() {
        _analyticsData = {
          'totalRevenue': totalRevenue,
          'totalOrders': totalOrders,
          'averageOrderValue': totalOrders > 0 ? totalRevenue / totalOrders : 0,
          'itemsSold': itemsSold,
          'categoryRevenue': categoryRevenue,
          'ordersByDay': ordersByDay,
          'revenueByDay': revenueByDay,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
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
              ButtonSegment(value: 'Week', label: Text('Week')),
              ButtonSegment(value: 'Month', label: Text('Month')),
              ButtonSegment(value: 'Year', label: Text('Year')),
            ],
            selected: {_timeRange},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() => _timeRange = newSelection.first);
              _loadAnalytics();
            },
          ),
          const SizedBox(height: 24),

          // Summary cards
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Total Revenue',
                  value: '₹${_analyticsData['totalRevenue']?.toStringAsFixed(2) ?? '0'}',
                  icon: Icons.currency_rupee,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  title: 'Total Orders',
                  value: '${_analyticsData['totalOrders'] ?? 0}',
                  icon: Icons.shopping_bag,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Average Order',
                  value: '₹${_analyticsData['averageOrderValue']?.toStringAsFixed(2) ?? '0'}',
                  icon: Icons.analytics,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: _SummaryCard(
                  title: 'Top Category',
                  value: 'Coming soon',
                  icon: Icons.category,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text(
            'Revenue Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _RevenueTrendChart(
              revenueByDay: _analyticsData['revenueByDay'] ?? {},
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Category Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _CategoryPieChart(
              categoryRevenue: _analyticsData['categoryRevenue'] ?? {},
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Top Selling Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _TopSellingItems(
            itemsSold: _analyticsData['itemsSold'] ?? {},
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
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
                Icon(icon, size: 20, color: Theme.of(context).primaryColor),
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

class _RevenueTrendChart extends StatelessWidget {
  final Map<String, double> revenueByDay;

  const _RevenueTrendChart({required this.revenueByDay});

  @override
  Widget build(BuildContext context) {
    final sortedDays = revenueByDay.keys.toList()..sort();
    final spots = sortedDays.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        revenueByDay[entry.value] ?? 0,
      );
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= sortedDays.length) return const Text('');
                final date = DateTime.parse(sortedDays[value.toInt()]);
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(DateFormat('dd/MM').format(date)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('₹${value.toInt()}');
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).primaryColor,
            barWidth: 3,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final Map<String, double> categoryRevenue;

  const _CategoryPieChart({required this.categoryRevenue});

  @override
  Widget build(BuildContext context) {
    final total = categoryRevenue.values.fold(0.0, (a, b) => a + b);
    int i = 0;
    final sections = categoryRevenue.entries.map((entry) {
      final color = Colors.primaries[i % Colors.primaries.length];
      i++;
      return PieChartSectionData(
        value: entry.value,
        title: '${(entry.value / total * 100).toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 12,
          color: Colors.white,
        ),
        color: color,
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: categoryRevenue.entries.map((entry) {
              final color = Colors.primaries[
                  categoryRevenue.keys.toList().indexOf(entry.key) %
                      Colors.primaries.length];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TopSellingItems extends StatelessWidget {
  final Map<String, int> itemsSold;

  const _TopSellingItems({required this.itemsSold});

  @override
  Widget build(BuildContext context) {
    final sortedItems = itemsSold.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topItems = sortedItems.take(5).toList();

    return Column(
      children: topItems.map((entry) {
        return ListTile(
          leading: CircleAvatar(
            child: Text('${topItems.indexOf(entry) + 1}'),
          ),
          title: Text(entry.key),
          trailing: Text(
            '${entry.value} sold',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      }).toList(),
    );
  }
}