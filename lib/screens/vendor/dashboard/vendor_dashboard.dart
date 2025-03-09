import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/order_list.dart';
import 'widgets/catalog_manager.dart';
import 'widgets/analytics_summary.dart';
import 'widgets/ratings_tab.dart';
import '../../../services/sync_service.dart';
import '../settings/vendor_profile_settings.dart'; // Add this import

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  int _selectedIndex = 0;
  final SyncService _syncService = SyncService();
  bool _isSyncing = false;

  // List of tab titles
  final List<String> _tabTitles = [
    'Orders',
    'Catalog',
    'Analytics',
    'Ratings'
  ];

  Future<void> _syncData() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);
    try {
      await _syncService.syncCatalog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data synced successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tabTitles[_selectedIndex]),
          actions: [
            // Sync button
            IconButton(
              icon: Icon(
                _isSyncing ? Icons.sync : Icons.sync_outlined,
                color: _isSyncing ? Theme.of(context).primaryColor : null,
              ),
              onPressed: _isSyncing ? null : _syncData,
            ),
            // Profile/Settings menu
            PopupMenuButton(
              onSelected: (value) {
                if (value == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VendorProfileSettings(),
                    ),
                  );
                } else if (value == 'logout') {
                  FirebaseAuth.instance.signOut();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.settings),
                      SizedBox(width: 8),
                      Text('Profile Settings'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'businessHours',
                  child: Row(
                    children: [
                      Icon(Icons.access_time),
                      SizedBox(width: 8),
                      Text('Business Hours'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: const [
            OrderList(),
            CatalogManager(),
            AnalyticsSummary(),
            RatingsTab(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.list_alt),
              selectedIcon: Icon(Icons.list_alt_outlined),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory),
              selectedIcon: Icon(Icons.inventory_2_outlined),
              label: 'Catalog',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics),
              selectedIcon: Icon(Icons.analytics_outlined),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(Icons.star),
              selectedIcon: Icon(Icons.star_outline),
              label: 'Ratings',
            ),
          ],
        ),
        floatingActionButton: _getFloatingActionButton(),
      ),
    );
  }

  Widget? _getFloatingActionButton() {
    switch (_selectedIndex) {
      case 1: // Catalog tab
        return FloatingActionButton(
          onPressed: () {
            // TODO: Add new product/category
          },
          child: const Icon(Icons.add),
        );
      case 3: // Ratings tab
        return FloatingActionButton(
          onPressed: () {
            // TODO: Export ratings to CSV
          },
          child: const Icon(Icons.download),
        );
      default:
        return null;
    }
  }
}