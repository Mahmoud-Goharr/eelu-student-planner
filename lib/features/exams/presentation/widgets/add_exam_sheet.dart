import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../data/models/exam_model.dart';

class ExamDraft {
  const ExamDraft({
    required this.courseName,
    required this.type,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.location,
  });
  final String courseName, type, location;
  final DateTime date, startTime, endTime;
}

class AddExamSheet extends StatefulWidget {
  const AddExamSheet({super.key, this.exam});
  final ExamModel? exam;
  @override
  State<AddExamSheet> createState() => _AddExamSheetState();
}

class _AddExamSheetState extends State<AddExamSheet> {
  late final TextEditingController _course;
  late final TextEditingController _location;
  late String _type;
  late DateTime _date, _start, _end;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final e = widget.exam;
    _course = TextEditingController(text: e?.courseName);
    _location = TextEditingController(text: e?.location);
    _type = e?.type ?? 'final';
    _date = e?.date ?? DateTime.now().add(const Duration(days: 1));
    _start = e?.startTime ?? DateTime(_date.year, _date.month, _date.day, 9);
    _end = e?.endTime ?? DateTime(_date.year, _date.month, _date.day, 11);
  }

  @override
  void dispose() {
    _course.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.exam == null
                ? AppLocalizations.of(context).addExam
                : AppLocalizations.of(context).editExam,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          TextFormField(
            controller: _course,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).course,
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? AppLocalizations.of(context).requiredField
                : null,
          ),
          TextFormField(
            controller: _location,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).location,
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).examType,
            ),
            items: [
              DropdownMenuItem(
                value: 'quiz',
                child: Text(AppLocalizations.of(context).quiz),
              ),
              DropdownMenuItem(
                value: 'midterm',
                child: Text(AppLocalizations.of(context).midterm),
              ),
              DropdownMenuItem(
                value: 'final',
                child: Text(AppLocalizations.of(context).finalExam),
              ),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(AppLocalizations.of(context).examDate),
            subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          Row(
            children: [
              Expanded(
                child: _timeTile(
                  AppLocalizations.of(context).startTime,
                  _start,
                  (v) => _start = v,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _timeTile(
                  AppLocalizations.of(context).endTime,
                  _end,
                  (v) => _end = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.pop(
                    context,
                    ExamDraft(
                      courseName: _course.text.trim(),
                      type: _type,
                      date: _date,
                      startTime: _start,
                      endTime: _end,
                      location: _location.text.trim(),
                    ),
                  );
                }
              },
              child: Text(AppLocalizations.of(context).saveExam),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _timeTile(
    String label,
    DateTime value,
    ValueChanged<DateTime> set,
  ) => OutlinedButton(
    onPressed: () async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(value),
      );
      if (picked != null) {
        setState(
          () => set(
            DateTime(
              _date.year,
              _date.month,
              _date.day,
              picked.hour,
              picked.minute,
            ),
          ),
        );
      }
    },
    child: Text(
      '$label\n${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
    ),
  );
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _start = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _start.hour,
          _start.minute,
        );
        _end = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _end.hour,
          _end.minute,
        );
      });
    }
  }
}
