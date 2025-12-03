import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/appointment.dart';
import 'package:family_tree/data/repositories/group_repository.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Provider for appointments stream
final appointmentsProvider = StreamProvider.family<List<Appointment>, String>((ref, familyTreeId) {
  final repository = GroupRepository();
  return repository.watchAppointments(familyTreeId);
});

/// Events tab for family appointments and gatherings
class EventsTab extends ConsumerStatefulWidget {
  final bool isDark;
  
  const EventsTab({Key? key, this.isDark = true}) : super(key: key);

  @override
  ConsumerState<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends ConsumerState<EventsTab> {
  final GroupRepository _repository = GroupRepository();
  bool _isCalendarView = false; // Toggle between list and calendar view

  void _toggleRSVP(String appointmentId, String userId) async {
    await _repository.toggleRSVP(appointmentId, userId);
  }

  void _deleteAppointment(String appointmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.deleteAppointment(appointmentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    const familyTreeId = 'main-family-tree';
    final appointmentsAsync = ref.watch(appointmentsProvider(familyTreeId));

    return Column(
      children: [
        // View toggle
        Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          child: Row(
            children: [
              Text(
                'Events',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                decoration: AppTheme.glassDecoration(),
                child: Row(
                  children: [
                    _buildViewToggleButton(
                      icon: Icons.list,
                      isSelected: !_isCalendarView,
                      onTap: () => setState(() => _isCalendarView = false),
                    ),
                    _buildViewToggleButton(
                      icon: Icons.calendar_month,
                      isSelected: _isCalendarView,
                      onTap: () => setState(() => _isCalendarView = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: appointmentsAsync.when(
            data: (appointments) {
              if (appointments.isEmpty) {
                return _buildEmptyState();
              }

              return _isCalendarView
                  ? _buildCalendarView(appointments, user?.uid ?? '')
                  : _buildListView(appointments, user?.uid ?? '');
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text(
                'Error loading events: $error',
                style: GoogleFonts.inter(color: AppTheme.error),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceSm),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<Appointment> appointments, String currentUserId) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(appointmentsProvider(currentUserId));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appointment = appointments[index];
          final isCreator = appointment.createdBy == currentUserId;
          final isAttending = appointment.attendees.contains(currentUserId);

          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
            child: _buildEventCard(appointment, currentUserId, isCreator, isAttending),
          );
        },
      ),
    );
  }

  Widget _buildCalendarView(List<Appointment> appointments, String currentUserId) {
    // Group appointments by month
    final grouped = <String, List<Appointment>>{};
    for (final apt in appointments) {
      final monthKey = DateFormat('MMMM yyyy').format(apt.dateTime);
      grouped.putIfAbsent(monthKey, () => []).add(apt);
    }

    final sortedMonths = grouped.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMMM yyyy').parse(a);
        final dateB = DateFormat('MMMM yyyy').parse(b);
        return dateA.compareTo(dateB);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      itemCount: sortedMonths.length,
      itemBuilder: (context, index) {
        final month = sortedMonths[index];
        final monthAppointments = grouped[month]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
              child: Text(
                month,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryLight,
                ),
              ),
            ),

            // Events in this month
            ...monthAppointments.map((appointment) {
              final isCreator = appointment.createdBy == currentUserId;
              final isAttending = appointment.attendees.contains(currentUserId);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                child: _buildEventCard(appointment, currentUserId, isCreator, isAttending),
              );
            }),

            const SizedBox(height: AppTheme.spaceMd),
          ],
        );
      },
    );
  }

  Widget _buildEventCard(Appointment appointment, String currentUserId, bool isCreator, bool isAttending) {
    final dateStr = DateFormat('MMM dd, yyyy').format(appointment.dateTime);
    final timeStr = DateFormat('h:mm a').format(appointment.dateTime);
    final isPast = appointment.dateTime.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and menu
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceSm),
                decoration: BoxDecoration(
                  gradient: isPast
                      ? LinearGradient(colors: [Colors.grey, Colors.grey.shade700])
                      : AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.event, color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '$dateStr · $timeStr',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCreator)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.textMuted),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteAppointment(appointment.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
            ],
          ),

          // Description
          if (appointment.description != null && appointment.description!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              appointment.description!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ],

          // Location
          if (appointment.location != null && appointment.location!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: AppTheme.accentCyan),
                const SizedBox(width: AppTheme.spaceXs),
                Expanded(
                  child: Text(
                    appointment.location!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                // Open in Maps button
                if (appointment.mapLink != null && appointment.mapLink!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.map, color: AppTheme.primaryLight),
                    tooltip: 'Open in Maps',
                    onPressed: () async {
                      final uri = Uri.parse(appointment.mapLink!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open map link')),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ],

          const SizedBox(height: AppTheme.spaceMd),

          // Attendees and RSVP button
          Row(
            children: [
              Icon(
                Icons.people,
                size: 16,
                color: AppTheme.textMuted,
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Text(
                '${appointment.attendees.length} attending',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              // RSVP button
              if (!isPast)
                ElevatedButton(
                  onPressed: () => _toggleRSVP(appointment.id, currentUserId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAttending ? AppTheme.success : AppTheme.primaryLight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMd,
                      vertical: AppTheme.spaceXs,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAttending ? Icons.check_circle : Icons.add_circle_outline,
                        size: 16,
                      ),
                      const SizedBox(width: AppTheme.spaceXs),
                      Text(
                        isAttending ? 'Attending' : 'Join',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_outlined,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'No events yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Create an event to get started!',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
