import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Provider for family members
final familyMembersProvider = StreamProvider.family<List<Person>, String>((ref, familyTreeId) {
  final repository = PersonRepository();
  return repository.watchFamilyMembers(familyTreeId);
});

/// Members tab showing all family members
class MembersTab extends ConsumerWidget {
  final bool isDark;
  
  const MembersTab({Key? key, this.isDark = true}) : super(key: key);
  
  /// Filter to show only the logged-in user, their spouse(s), and direct children
  List<Person> _getFilteredMembers(List<Person> allPersons, String? authUserId) {
    if (authUserId == null || allPersons.isEmpty) return [];
    
    // Find the person linked to the current user
    final linkedPerson = allPersons.where((p) => p.authUserId == authUserId).firstOrNull;
    if (linkedPerson == null) return allPersons; // No linked person, show all
    
    // Build a set of IDs: the linked person + spouse(s) + direct children only
    final Set<String> includedIds = {linkedPerson.id};
    
    // Add spouse(s)
    for (final spouseId in linkedPerson.relationships.spouseIds) {
      includedIds.add(spouseId);
    }
    
    // Add direct children only (not grandchildren)
    for (final person in allPersons) {
      if (person.relationships.parentIds.contains(linkedPerson.id)) {
        includedIds.add(person.id);
      }
    }
    
    return allPersons.where((p) => includedIds.contains(p.id)).toList();
  }
  
  /// Get the linked person for the current user
  Person? _getLinkedPerson(List<Person> allPersons, String? authUserId) {
    if (authUserId == null) return null;
    return allPersons.where((p) => p.authUserId == authUserId).firstOrNull;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    const familyTreeId = 'main-family-tree';
    final membersAsync = ref.watch(familyMembersProvider(familyTreeId));

    return membersAsync.when(
      data: (members) {
        final linkedPerson = _getLinkedPerson(members, user?.uid);
        
        if (linkedPerson == null) {
          return _buildEmptyState();
        }
        
        // Get spouse(s)
        final spouses = members.where(
          (p) => linkedPerson.relationships.spouseIds.contains(p.id)
        ).toList();
        
        // Get direct children
        final children = members.where(
          (p) => p.relationships.parentIds.contains(linkedPerson.id)
        ).toList()..sort((a, b) => a.fullName.compareTo(b.fullName));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(familyMembersProvider(familyTreeId));
          },
          color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            children: [
              // You section
              _buildSectionHeader('You', Icons.person),
              const SizedBox(height: 8),
              _buildMemberCard(linkedPerson, isYou: true),
              const SizedBox(height: 20),
              
              // Spouse section
              _buildSectionHeader(
                'Spouse', 
                Icons.favorite,
                showAddButton: spouses.isEmpty,
                onAddPressed: () => _showAddSpouseDialog(context, ref, linkedPerson, members),
              ),
              const SizedBox(height: 8),
              if (spouses.isEmpty)
                _buildAddSpouseCard(context, ref, linkedPerson, members)
              else
                ...spouses.map((spouse) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildMemberCard(spouse, isSpouse: true),
                )),
              const SizedBox(height: 20),
              
              // Children section
              _buildSectionHeader('Children', Icons.child_care),
              const SizedBox(height: 8),
              if (children.isEmpty)
                _buildEmptyChildrenState()
              else
                ...children.map((child) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildMemberCard(child),
                )),
            ],
          ),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
        ),
      ),
      error: (error, stack) => Center(
        child: Text(
          'Error loading members: $error',
          style: GoogleFonts.cormorantGaramond(color: AppTheme.error),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {bool showAddButton = false, VoidCallback? onAddPressed}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
          ),
        ),
        if (showAddButton && onAddPressed != null) ...[
          const Spacer(),
          TextButton.icon(
            onPressed: onAddPressed,
            icon: Icon(
              Icons.add,
              size: 18,
              color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
            ),
            label: Text(
              'Add',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildMemberCard(Person member, {bool isYou = false, bool isSpouse = false}) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark.withOpacity(0.6) : ElegantColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isYou 
              ? (isDark ? AppTheme.primaryLight : ElegantColors.terracotta)
              : isSpouse
                  ? (isDark ? Colors.pinkAccent.withOpacity(0.5) : ElegantColors.dustyRose)
                  : (isDark ? AppTheme.primaryLight.withOpacity(0.1) : ElegantColors.champagne),
          width: isYou || isSpouse ? 2 : 1,
        ),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: ElegantColors.sienna.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: isSpouse 
                  ? LinearGradient(colors: [Colors.pink.shade300, Colors.pink.shade400])
                  : (isDark ? AppTheme.primaryGradient : ElegantColors.warmGradient),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: isDark 
                      ? AppTheme.primaryLight.withOpacity(0.3)
                      : ElegantColors.terracotta.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: member.profilePhotoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(member.profilePhotoUrl!, fit: BoxFit.cover),
                  )
                : Center(
                    child: Text(
                      member.firstName.isNotEmpty ? member.firstName[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),

          const SizedBox(width: AppTheme.spaceMd),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.fullName,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                        ),
                      ),
                    ),
                    if (isYou)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'You',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (isSpouse)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite, size: 10, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Spouse',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (member.birthDate != null)
                  Text(
                    _formatBirthDate(member.birthDate!),
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 14,
                      color: isDark ? AppTheme.textSecondary : ElegantColors.warmGray,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAddSpouseCard(BuildContext context, WidgetRef ref, Person linkedPerson, List<Person> allMembers) {
    return InkWell(
      onTap: () => _showAddSpouseDialog(context, ref, linkedPerson, allMembers),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark.withOpacity(0.3) : ElegantColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white24 : ElegantColors.champagne,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 24,
              color: isDark ? Colors.white54 : ElegantColors.warmGray,
            ),
            const SizedBox(width: 8),
            Text(
              'Add your spouse',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 16,
                color: isDark ? Colors.white54 : ElegantColors.warmGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyChildrenState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark.withOpacity(0.3) : ElegantColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white24 : ElegantColors.champagne,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.child_care,
            size: 24,
            color: isDark ? Colors.white38 : ElegantColors.warmGray.withOpacity(0.5),
          ),
          const SizedBox(width: 8),
          Text(
            'No children yet',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              color: isDark ? Colors.white38 : ElegantColors.warmGray,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showAddSpouseDialog(BuildContext context, WidgetRef ref, Person linkedPerson, List<Person> allMembers) {
    // Get potential spouses (anyone not already a spouse and not a child/parent)
    final potentialSpouses = allMembers.where((p) {
      if (p.id == linkedPerson.id) return false;
      if (linkedPerson.relationships.spouseIds.contains(p.id)) return false;
      if (linkedPerson.relationships.parentIds.contains(p.id)) return false;
      if (linkedPerson.relationships.childrenIds.contains(p.id)) return false;
      if (p.relationships.parentIds.contains(linkedPerson.id)) return false;
      return true;
    }).toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.surfaceDark : ElegantColors.warmWhite,
        title: Text(
          'Add Spouse',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
          ),
        ),
        content: SizedBox(
          width: 300,
          child: potentialSpouses.isEmpty
              ? Text(
                  'No available family members to add as spouse.',
                  style: GoogleFonts.cormorantGaramond(
                    color: isDark ? AppTheme.textSecondary : ElegantColors.warmGray,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a family member:',
                      style: GoogleFonts.cormorantGaramond(
                        color: isDark ? AppTheme.textSecondary : ElegantColors.warmGray,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...potentialSpouses.map((person) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
                        child: Text(
                          person.firstName.isNotEmpty ? person.firstName[0] : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        person.fullName,
                        style: TextStyle(
                          color: isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _assignSpouse(ref, linkedPerson, person);
                      },
                    )),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppTheme.textSecondary : ElegantColors.warmGray,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _assignSpouse(WidgetRef ref, Person linkedPerson, Person spouse) async {
    final repository = PersonRepository();
    
    // Create spouse relationship connection
    final newSpouseConnection = RelationshipConnection(
      personId: spouse.id,
      type: RelationshipType.marriage,
    );
    
    final reverseSpouseConnection = RelationshipConnection(
      personId: linkedPerson.id,
      type: RelationshipType.marriage,
    );
    
    // Update both persons to be each other's spouse
    final updatedLinkedPerson = linkedPerson.copyWith(
      relationships: linkedPerson.relationships.copyWith(
        spouses: [...linkedPerson.relationships.spouses, newSpouseConnection],
      ),
    );
    
    final updatedSpouse = spouse.copyWith(
      relationships: spouse.relationships.copyWith(
        spouses: [...spouse.relationships.spouses, reverseSpouseConnection],
      ),
    );
    
    await repository.updatePerson(updatedLinkedPerson);
    await repository.updatePerson(updatedSpouse);
    
    ref.invalidate(familyMembersProvider('main-family-tree'));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [AppTheme.primaryLight.withOpacity(0.2), AppTheme.accentTeal.withOpacity(0.2)]
                    : [ElegantColors.terracotta.withOpacity(0.15), ElegantColors.sage.withOpacity(0.15)],
              ),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Icon(
              Icons.people_outline,
              size: 64,
              color: isDark ? AppTheme.primaryLight : ElegantColors.terracotta,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'No family members yet',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Link your profile to see your family.',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              color: isDark ? AppTheme.textSecondary : ElegantColors.warmGray,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBirthDate(DateTime date) {
    final now = DateTime.now();
    final age = now.year - date.year;
    return 'Age $age';
  }

}
