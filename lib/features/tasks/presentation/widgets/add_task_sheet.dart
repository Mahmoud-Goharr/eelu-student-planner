import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

import '../../data/models/task_model.dart';

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key, this.task});

  final TaskModel? task;

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _dueDate;


  @override
  void initState() {
    super.initState();

    final task = widget.task;

    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _dueDate = task?.dueDate ?? DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.task != null;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                editing ? l10n.editPersonalTask : l10n.addPersonalTask,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.name,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.requiredField;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.description,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.date,
                  ),
                  child: Text(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(_dueDate),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    editing ? l10n.saveChanges : l10n.addPersonalTask,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(DateTime.now())
          ? DateTime.now()
          : _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date != null && mounted) {
      setState(() => _dueDate = date);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      TaskDraft(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        dueDate: _dueDate,
      ),
    );
  }
}

class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.description,
    required this.dueDate,
    this.courseId = '',
    this.type = 'assignment',
    this.priority = 'medium',
  });

  final String title;
  final String? description;
  final DateTime dueDate;

  // Kept for compatibility with older Home/Schedule callers.
  // Personal assignments intentionally ignore these values.
  final String courseId;
  final String type;
  final String priority;
}
