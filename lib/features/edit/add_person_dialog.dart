import 'package:flutter/material.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:uuid/uuid.dart';

/// Dialog for adding a new person
class AddPersonDialog extends StatefulWidget {
  final String familyTreeId;
  final Function(Person) onSave;

  const AddPersonDialog({
    Key? key,
    required this.familyTreeId,
    required this.onSave,
  }) : super(key: key);

  @override
  State<AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<AddPersonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();
  
  DateTime? _birthDate;
  DateTime? _deathDate;
  String? _gender;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final person = Person(
        id: const Uuid().v4(),
        familyTreeId: widget.familyTreeId,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        birthDate: _birthDate,
        deathDate: _deathDate,
        gender: _gender,
        bio: _bioController.text.trim(),
        relationships: Relationships(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      widget.onSave(person);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add Family Member',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceLg),
                
                // First Name
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    hintText: 'Enter first name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a first name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spaceMd),
                
                // Last Name
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    hintText: 'Enter last name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a last name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spaceMd),
                
                // Gender
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) => setState(() => _gender = value),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                
                // Birth Date
                _buildDateField(
                  label: 'Birth Date',
                  date: _birthDate,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _birthDate ?? DateTime(1950),
                      firstDate: DateTime(1800),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _birthDate = date);
                    }
                  },
                  onClear: () => setState(() => _birthDate = null),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                
                // Death Date
                _buildDateField(
                  label: 'Death Date (optional)',
                  date: _deathDate,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _deathDate ?? DateTime.now(),
                      firstDate: _birthDate ?? DateTime(1800),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _deathDate = date);
                    }
                  },
                  onClear: () => setState(() => _deathDate = null),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                
                // Bio
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'Biography (optional)',
                    hintText: 'Write a brief bio...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: AppTheme.spaceXl),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppTheme.spaceMd),
                    ElevatedButton(
                      onPressed: _save,
                      child: const Text('Add Person'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: date != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                )
              : null,
        ),
        child: Text(
          date != null
              ? '${date.month}/${date.day}/${date.year}'
              : 'Select date',
          style: TextStyle(
            color: date != null ? AppTheme.textPrimary : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
