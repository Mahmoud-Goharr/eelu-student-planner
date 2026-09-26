import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../data/models/demo_lectures.dart';
import '../../data/models/lecture_model.dart';

class AddLectureSheet extends StatefulWidget {
  const AddLectureSheet({super.key, this.lecture});
  final LectureModel? lecture;
  @override
  State<AddLectureSheet> createState() => _AddLectureSheetState();
}

class _AddLectureSheetState extends State<AddLectureSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _instructor, _location, _description;
  late DateTime _date;
  late String _course, _start, _end;
  @override
  void initState() {
    super.initState();
    final item = widget.lecture;
    _title = TextEditingController(text: item?.title);
    _instructor = TextEditingController(text: item?.instructor);
    _location = TextEditingController(text: item?.location);
    _description = TextEditingController(text: item?.description);
    _date = item?.date ?? DateTime.now();
    _course = item?.courseId ?? lectureCourses.first;
    _start = item?.startTime ?? '09:00';
    _end = item?.endTime ?? '10:00';
  }

  @override
  void dispose() {
    _title.dispose();
    _instructor.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _form,
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
              widget.lecture == null
                  ? AppLocalizations.of(context).addLectureTitle
                  : AppLocalizations.of(context).editLecture,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).lectureTitle,
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? AppLocalizations.of(context).required
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _course,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).course,
              ),
              items: {
                ...lectureCourses,
                if (!lectureCourses.contains(_course)) _course,
              }.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _course = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instructor,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).instructor,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).date,
                ),
                child: Text('${_date.day}/${_date.month}/${_date.year}'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _start,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).starts,
                    ),
                    onChanged: (v) => _start = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _end,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).ends,
                    ),
                    onChanged: (v) => _end = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).location,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).description,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(
                  widget.lecture == null
                      ? AppLocalizations.of(context).addLecture
                      : AppLocalizations.of(context).saveChanges,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      (widget.lecture ??
              LectureModel(
                id: '',
                title: '',
                courseId: _course,
                courseName: _course,
                instructor: '',
                day: '',
                date: _date,
                startTime: _start,
                endTime: _end,
                location: '',
                level: 3,
                section: 'C&D',
              ))
          .copyWith(
            title: _title.text.trim(),
            courseId: _course,
            courseName: _course,
            instructor: _instructor.text.trim(),
            day: _date.weekday.toString(),
            date: _date,
            startTime: _start.trim(),
            endTime: _end.trim(),
            location: _location.text.trim(),
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
          ),
    );
  }
}
