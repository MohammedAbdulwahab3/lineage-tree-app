import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/features/tree_view/controllers/tree_controller.dart';
import 'package:family_tree/features/tree_view/tree_canvas.dart';
import 'package:family_tree/features/tree_view/widgets/person_details_dialog.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';

/// View mode for family tree
enum FamilyViewMode {
  descendants, // My family - me and all my children/grandchildren
  ancestors,   // My lineage - me and all my parents/grandparents
  all,         // Full tree (demo mode)
}

/// Main screen for the family tree view
class TreeScreen extends ConsumerStatefulWidget {
  final String familyTreeId;
  final bool isDemo;

  const TreeScreen({
    Key? key,
    required this.familyTreeId,
    this.isDemo = false,
  }) : super(key: key);

  @override
  ConsumerState<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends ConsumerState<TreeScreen> {
  FamilyViewMode _viewMode = FamilyViewMode.descendants;
  String? _linkedPersonId;
  bool _initialized = false;
  
  /// Get the logged-in user's linked person
  Person? _getLinkedPerson(List<Person> allPersons, String? authUserId) {
    if (authUserId == null || widget.isDemo) return null;
    return allPersons.where((p) => p.authUserId == authUserId).firstOrNull;
  }
  
  /// Get filtered persons based on view mode
  List<Person> _getFilteredPersons(List<Person> allPersons, String? authUserId) {
    if (authUserId == null || widget.isDemo) {
      // Demo mode or not logged in - show all
      return allPersons;
    }
    
    // Find the person linked to this auth user
    final linkedPerson = _getLinkedPerson(allPersons, authUserId);
    
    if (linkedPerson == null) {
      // User not linked to any person - show all (they can link later)
      return allPersons;
    }
    
    final Set<String> includedIds = {linkedPerson.id};
    
    if (_viewMode == FamilyViewMode.descendants) {
      // Get all descendants (lineage only - no spouses)
      void addDescendants(String personId) {
        for (final person in allPersons) {
          if (person.relationships.parentIds.contains(personId)) {
            if (!includedIds.contains(person.id)) {
              includedIds.add(person.id);
              addDescendants(person.id);
            }
          }
        }
      }
      addDescendants(linkedPerson.id);
      // No spouses - lineage only
    } else if (_viewMode == FamilyViewMode.ancestors) {
      // Get all ancestors (lineage only - no spouses)
      void addAncestors(String personId) {
        final person = allPersons.where((p) => p.id == personId).firstOrNull;
        if (person == null) return;
        
        for (final parentId in person.relationships.parentIds) {
          if (!includedIds.contains(parentId)) {
            includedIds.add(parentId);
            addAncestors(parentId);
            // No spouses - lineage only
          }
        }
      }
      addAncestors(linkedPerson.id);
    }
    
    return allPersons.where((p) => includedIds.contains(p.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(treeControllerProvider(widget.familyTreeId));
    final controller = ref.read(treeControllerProvider(widget.familyTreeId).notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Get current user for filtering
    final authUser = ref.watch(authStateProvider).value;
    final authUserId = authUser?.uid;
    
    // Get linked person for display
    final linkedPerson = _getLinkedPerson(state.persons, authUserId);
    
    // Auto-select linked person and set focus mode on first load
    if (!_initialized && linkedPerson != null && !widget.isDemo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.selectPerson(linkedPerson.id);
        controller.setLayoutMode(LayoutMode.focus);
        setState(() {
          _linkedPersonId = linkedPerson.id;
          _initialized = true;
        });
      });
    }
    
    // Filter persons based on view mode
    final filteredPersons = _getFilteredPersons(state.persons, authUserId);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(widget.isDemo ? '/' : '/dashboard'),
          tooltip: widget.isDemo ? 'Home' : 'Dashboard',
        ),
        title: Text(widget.isDemo ? 'Family Tree Demo' : _getViewTitle()),
        actions: [
          // View Mode Toggle (only for authenticated users)
          if (!widget.isDemo && linkedPerson != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : ElegantColors.champagne,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildViewModeButton(
                    icon: Icons.arrow_downward,
                    label: 'My Family',
                    isSelected: _viewMode == FamilyViewMode.descendants,
                    onTap: () => setState(() => _viewMode = FamilyViewMode.descendants),
                    isDark: isDark,
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: isDark ? Colors.white24 : ElegantColors.warmGray.withOpacity(0.3),
                  ),
                  _buildViewModeButton(
                    icon: Icons.arrow_upward,
                    label: 'My Lineage',
                    isSelected: _viewMode == FamilyViewMode.ancestors,
                    onTap: () => setState(() => _viewMode = FamilyViewMode.ancestors),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
          
          // Navigation menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            tooltip: 'Navigate',
            onSelected: (route) => context.go(route),
            itemBuilder: (context) => [
              if (widget.isDemo) ...[
                const PopupMenuItem(
                  value: '/',
                  child: Row(
                    children: [
                      Icon(Icons.home),
                      SizedBox(width: 8),
                      Text('Home'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: '/login',
                  child: Row(
                    children: [
                      Icon(Icons.login),
                      SizedBox(width: 8),
                      Text('Sign In'),
                    ],
                  ),
                ),
              ] else ...[
                const PopupMenuItem(
                  value: '/dashboard',
                  child: Row(
                    children: [
                      Icon(Icons.dashboard),
                      SizedBox(width: 8),
                      Text('Dashboard'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: '/group',
                  child: Row(
                    children: [
                      Icon(Icons.people),
                      SizedBox(width: 8),
                      Text('Family Group'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: '/',
                  child: Row(
                    children: [
                      Icon(Icons.explore),
                      SizedBox(width: 8),
                      Text('Landing Page'),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 4),
          // Layout mode selector
          PopupMenuButton<LayoutMode>(
            icon: const Icon(Icons.view_module),
            tooltip: 'Change Layout',
            onSelected: (mode) => controller.setLayoutMode(mode),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: LayoutMode.tree,
                child: Row(
                  children: [
                    Icon(Icons.account_tree),
                    SizedBox(width: 8),
                    Text('Tree View'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: LayoutMode.radial,
                child: Row(
                  children: [
                    Icon(Icons.radio_button_checked),
                    SizedBox(width: 8),
                    Text('Radial View'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: LayoutMode.timeline,
                child: Row(
                  children: [
                    Icon(Icons.timeline),
                    SizedBox(width: 8),
                    Text('Timeline View'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: LayoutMode.list,
                child: Row(
                  children: [
                    Icon(Icons.list),
                    SizedBox(width: 8),
                    Text('List View'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: LayoutMode.focus,
                child: Row(
                  children: [
                    Icon(Icons.center_focus_strong),
                    SizedBox(width: 8),
                    Text('Focus View'),
                  ],
                ),
              ),
            ],
          ),
          
          // Auth buttons
          if (widget.isDemo)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
              child: ElevatedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Sign In'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMd,
                    vertical: AppTheme.spaceSm,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: () async {
                final authController = ref.read(authControllerProvider.notifier);
                await authController.signOut();
                if (context.mounted) {
                  context.go('/');
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppTheme.error,
                          ),
                          const SizedBox(height: AppTheme.spaceMd),
                          Text(
                            'Error: ${state.error}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    )
                  : filteredPersons.isEmpty
                      ? _buildEmptyState(context, controller, ref)
                      : TreeCanvas(
                      persons: filteredPersons,
                      selectedPersonId: state.selectedPersonId,
                      focusedSubtreeRoot: state.focusedSubtreeRoot,
                      focusedPersonIds: state.focusedPersonIds,
                      layoutMode: state.layoutMode,
                      onPersonTapped: (id) {
                        controller.selectPerson(id);
                      },
                      onPersonDoubleTapped: (id) {
                        final person = filteredPersons.firstWhere((p) => p.id == id);
                        final spouses = filteredPersons.where((p) => person.relationships.spouseIds.contains(p.id)).toList();
                        final children = filteredPersons.where((p) => person.relationships.childrenIds.contains(p.id)).toList();
                        
                        showDialog(
                          context: context,
                          barrierColor: Colors.black.withValues(alpha: 0.5),
                          builder: (context) => PersonDetailsDialog(
                            person: person,
                            spouses: spouses,
                            children: children,
                            onPersonTapped: (relativeId) {
                              Navigator.of(context).pop();
                              controller.selectPerson(relativeId);
                            },
                          ),
                        );
                      },
                      onPersonLongPressed: (id) {
                        // Long-press for subtree focus
                        controller.focusOnSubtree(id);
                      },
                      onClearSubtreeFocus: () {
                        controller.clearSubtreeFocus();
                      },
                          onBackgroundTapped: () {
                            controller.selectPerson(null);
                          },
                        ),
        ],
      ),
    );
  }
  
  String _getViewTitle() {
    switch (_viewMode) {
      case FamilyViewMode.descendants:
        return 'My Family';
      case FamilyViewMode.ancestors:
        return 'My Lineage';
      case FamilyViewMode.all:
        return 'Family Tree';
    }
  }
  
  Widget _buildViewModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? AppTheme.primaryLight : ElegantColors.terracotta)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected 
                  ? Colors.white
                  : (isDark ? Colors.white70 : ElegantColors.charcoal),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected 
                    ? Colors.white
                    : (isDark ? Colors.white70 : ElegantColors.charcoal),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, TreeController controller, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.family_restroom,
            size: 80,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: AppTheme.spaceLg),
          Text(
            'No family members yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'The family tree is empty.\nUse the Admin Panel to add members.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
