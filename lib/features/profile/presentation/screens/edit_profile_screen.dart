import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_error_localizer.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../data/models/course_group_selection.dart';
import '../viewmodels/profile_cubit.dart';
import '../viewmodels/profile_state.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nameController;

  XFile? _selectedImage;
  String? _selectedGroup;

  @override
  void initState() {
    super.initState();

    final profile = context.read<ProfileCubit>().state.profile;

    _nameController = TextEditingController(text: profile?.name ?? '');

    final groups = context
        .read<ProfileCubit>()
        .state
        .courseGroups
        .map((item) => item.groupCode.trim().toUpperCase())
        .where((code) => {'A', 'B', 'C', 'D'}.contains(code))
        .toSet()
        .toList();
    _selectedGroup = groups.length == 1 ? groups.first : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final profileState = context.watch<ProfileCubit>().state;
    final profile = profileState.profile;

    final avatarUrl = profile?.avatarUrl;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.editProfile)),
      body: BlocListener<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state.status == ProfileStatus.updateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localizations.profileUpdated)),
            );

            Navigator.of(context).pop();
          } else if (state.status == ProfileStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppErrorLocalizer.message(
                    context,
                    state.error,
                    fallback: localizations.unableToUpdateProfile,
                  ),
                ),
              ),
            );
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 58,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        backgroundImage: _selectedImage != null
                            ? FileImage(File(_selectedImage!.path))
                            : (avatarUrl != null && avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null),
                        child:
                            _selectedImage == null &&
                                (avatarUrl == null || avatarUrl.isEmpty)
                            ? Icon(
                                Icons.person,
                                size: 55,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: Theme.of(context).colorScheme.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _pickImage,
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: localizations.name),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return localizations.requiredField;
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 14),

                TextFormField(
                  initialValue: profile?.email ?? localizations.notSet,
                  readOnly: true,
                  decoration: InputDecoration(labelText: localizations.email),
                ),

                const SizedBox(height: 14),

                TextFormField(
                  initialValue: profile?.role ?? localizations.student,
                  readOnly: true,
                  decoration: InputDecoration(labelText: localizations.role),
                ),

                const SizedBox(height: 14),

                TextFormField(
                  initialValue: profile?.level?.toString() ?? localizations.notSet,
                  readOnly: true,
                  decoration: InputDecoration(labelText: localizations.level),
                ),

                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: _selectedGroup ?? _singleGroup(profileState.courseGroups),
                  decoration: InputDecoration(labelText: localizations.group),
                  items: const ['A', 'B', 'C', 'D']
                      .map(
                        (group) => DropdownMenuItem<String>(
                          value: group,
                          child: Text(group),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedGroup = value);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localizations.requiredField;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                BlocBuilder<ProfileCubit, ProfileState>(
                  builder: (context, state) {
                    final saving = state.status == ProfileStatus.updating;

                    return SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving ? null : _save,
                        child: saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(localizations.saveChanges),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _selectedImage = image;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorLocalizer.message(
              context,
              error,
              fallback: AppLocalizations.of(context).imageUploadFailed,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await context.read<ProfileCubit>().updateProfile(
      name: _nameController.text.trim(),
      groupCode: _selectedGroup ?? _singleGroup(context.read<ProfileCubit>().state.courseGroups) ?? '',
      avatarFilePath: _selectedImage?.path,
    );
  }
}

String? _singleGroup(List<CourseGroupSelection> selections) {
  final groups = selections
      .map((selection) => selection.groupCode.trim().toUpperCase())
      .where((code) => {'A', 'B', 'C', 'D'}.contains(code))
      .toSet()
      .toList();
  return groups.length == 1 ? groups.first : null;
}

String _groupSummary(
  AppLocalizations l10n,
  List<CourseGroupSelection> selections,
) {
  final groups = selections
      .map((selection) => selection.groupCode.trim().toUpperCase())
      .where((code) => code.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  if (groups.isEmpty) return l10n.noCourseGroupsSelected;
  return groups.length == 1
      ? '${l10n.group} ${groups.first}'
      : '${l10n.group} ${groups.join(', ')}';
}
