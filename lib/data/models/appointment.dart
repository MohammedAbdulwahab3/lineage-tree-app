/// Represents an appointment/event in the family calendar
class Appointment {
  final String id;
  final String familyTreeId;
  final String title;
  final String? description;
  final DateTime dateTime;
  final String? location;
  final String createdBy;
  final List<String> attendees;

  Appointment({
    required this.id,
    required this.familyTreeId,
    required this.title,
    this.description,
    required this.dateTime,
    this.location,
    required this.createdBy,
    this.attendees = const [],
  });

  /// Create from JSON (Go backend response)
  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] ?? '',
      familyTreeId: json['familyTreeId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      dateTime: json['dateTime'] != null ? DateTime.parse(json['dateTime']) : DateTime.now(),
      location: json['location'],
      createdBy: json['createdBy'] ?? '',
      attendees: List<String>.from(json['attendees'] ?? []),
    );
  }

  /// Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyTreeId': familyTreeId,
      'title': title,
      'description': description,
      'dateTime': dateTime.toUtc().toIso8601String(),
      'location': location,
      'createdBy': createdBy,
      'attendees': attendees,
    };
  }

  Appointment copyWith({
    String? id,
    String? familyTreeId,
    String? title,
    String? description,
    DateTime? dateTime,
    String? location,
    String? createdBy,
    List<String>? attendees,
  }) {
    return Appointment(
      id: id ?? this.id,
      familyTreeId: familyTreeId ?? this.familyTreeId,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      createdBy: createdBy ?? this.createdBy,
      attendees: attendees ?? this.attendees,
    );
  }
}
