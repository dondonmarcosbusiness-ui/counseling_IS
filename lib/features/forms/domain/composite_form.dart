import 'counseling_form.dart';

/// Name groups that mean the same person in every template, mapped to the
/// canonical group the merged batch page renders once.
const _sharedNameGroups = <String, String>{
  'learner_name': 'learner_name',
  'student_name': 'learner_name',
  'client_name': 'learner_name',
  'parent_guardian': 'parent_guardian',
  'guardian_name': 'parent_guardian',
};

/// Question IDs with identical meaning and options in every template that
/// carries them, shown once in the merged batch page's student block.
///
/// Anything NOT listed here is namespaced per form, because several IDs
/// collide with different meaning — `disposition` has different option
/// lists in the intake and the counseling record, and `observations`,
/// `remarks`, `form_number` and `referred_to` differ between templates.
const _sharedSimpleQuestionIds = <String>{
  'grade_section',
  'sex',
  'age',
  'date_of_birth',
  'home_address',
  'address_visited',
  'contact_number',
  'religion',
  'guardian_contact',
  'guardian_relationship',
};

String _namePartId(FormNamePart part) => switch (part) {
  FormNamePart.first => 'first',
  FormNamePart.middle => 'middle',
  FormNamePart.last => 'last',
  FormNamePart.suffix => 'suffix',
};

/// True when [value] carries no answer: empty text, a missing date or
/// choice, an unchecked box, or repeatable rows where every cell is blank.
bool isBlankAnswer(Object? value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  if (value is bool) return !value;
  if (value is List) {
    if (value.isEmpty) return true;
    if (value.every((item) => item is Map)) {
      return value.every((row) => (row as Map).values.every(isBlankAnswer));
    }
    return false;
  }
  return false;
}

/// Several form templates merged into the one page a batch is filled on.
///
/// Shared student fields keep their original question ID and appear once;
/// every other question is namespaced as `<formId>__<questionId>` so
/// colliding IDs never leak values between the saved records. [split]
/// turns the merged answers back into one map per source form.
class CompositeForm {
  const CompositeForm({
    required this.form,
    required this.sourceForms,
    required this.origins,
    required this.compositeByOriginal,
    required this.ownCompositeIds,
    required this.sectionBanners,
  });

  /// The merged form the page renders.
  final CounselingForm form;

  /// Source forms in the order they were chosen.
  final List<CounselingForm> sourceForms;

  /// Composite question ID → {source form ID → original question ID}.
  final Map<String, Map<String, String>> origins;

  /// Source form ID → {original question ID → composite question ID}.
  final Map<String, Map<String, String>> compositeByOriginal;

  /// Source form ID → composite IDs of its own (non-shared) questions.
  final Map<String, Set<String>> ownCompositeIds;

  /// Banner per merged section; non-null above the first section of each
  /// source form so the page reads as the original forms in sequence.
  final List<String?> sectionBanners;

  /// Composite question ID an original question of [formId] is stored under.
  String compositeIdFor(String formId, String questionId) =>
      compositeByOriginal[formId]?[questionId] ?? '${formId}__$questionId';

  /// Splits merged answers into one map per source form, injecting the
  /// shared student fields into every form that has those fields.
  Map<String, Map<String, Object?>> split(Map<String, Object?> data) {
    final result = {
      for (final source in sourceForms) source.id: <String, Object?>{},
    };
    data.forEach((compositeId, value) {
      final perForm = origins[compositeId];
      if (perForm == null) return;
      perForm.forEach((formId, originalId) {
        result[formId]?[originalId] = value;
      });
    });
    return result;
  }

  /// Whether [formId] carries at least one answer of its own, ignoring the
  /// shared student block — a form the administrator never worked on is
  /// skipped on save instead of being written from the shared fields alone.
  bool isAnswered(String formId, Map<String, Object?> data) {
    final own = ownCompositeIds[formId];
    if (own == null) return false;
    if (own.isEmpty) {
      return data.entries.any(
        (entry) =>
            origins[entry.key]?.containsKey(formId) == true &&
            !isBlankAnswer(entry.value),
      );
    }
    return own.any((id) => !isBlankAnswer(data[id]));
  }
}

bool _isSharedQuestion(FormQuestion question) {
  final group = question.nameGroup;
  if (group != null) return _sharedNameGroups.containsKey(group);
  return _sharedSimpleQuestionIds.contains(question.id);
}

FormQuestion _sharedQuestion(FormQuestion question) {
  final group = question.nameGroup;
  if (group == null) return question;
  final canonical = _sharedNameGroups[group];
  final part = question.namePart;
  if (canonical == null || part == null) return question;
  return FormQuestion.personNamePart(
    id: '${canonical}_${_namePartId(part)}',
    label: question.label,
    nameGroup: canonical,
    namePart: part,
    nameAnchor: question.nameAnchor,
  );
}

/// Merges [sourceForms] into a single fillable page. Forms may be given in
/// any order; duplicates are ignored.
CompositeForm buildCompositeForm(List<CounselingForm> sourceForms) {
  final sources = <CounselingForm>[];
  final seenForms = <String>{};
  for (final source in sourceForms) {
    if (seenForms.add(source.id)) sources.add(source);
  }

  final origins = <String, Map<String, String>>{};
  final compositeByOriginal = <String, Map<String, String>>{};
  final ownCompositeIds = <String, Set<String>>{
    for (final source in sources) source.id: <String>{},
  };
  final sharedQuestions = <FormQuestion>[];
  final sharedSeen = <String>{};
  final sections = <FormSection>[];
  final banners = <String?>[];

  void record(String compositeId, String formId, String originalId) {
    origins.putIfAbsent(compositeId, () => {})[formId] = originalId;
    compositeByOriginal.putIfAbsent(formId, () => {})[originalId] = compositeId;
  }

  for (final source in sources) {
    String? banner = '${source.documentNo} · ${source.title}';
    for (final section in source.sections) {
      final mapped = <FormQuestion>[];
      for (final question in section.questions) {
        if (_isSharedQuestion(question)) {
          final compositeQuestion = _sharedQuestion(question);
          record(compositeQuestion.id, source.id, question.id);
          if (sharedSeen.add(compositeQuestion.id)) {
            sharedQuestions.add(compositeQuestion);
          }
        } else {
          final compositeId = '${source.id}__${question.id}';
          mapped.add(
            FormQuestion(
              id: compositeId,
              label: question.label,
              type: question.type,
              options: question.options,
              hint: question.hint,
              nameGroup: question.nameGroup,
              namePart: question.namePart,
              nameAnchor: question.nameAnchor,
              entryFields: question.entryFields,
              entryLabel: question.entryLabel,
            ),
          );
          record(compositeId, source.id, question.id);
          ownCompositeIds[source.id]!.add(compositeId);
        }
      }
      if (mapped.isEmpty) continue;
      sections.add(
        FormSection(
          title: section.title,
          information: section.information,
          questions: mapped,
        ),
      );
      banners.add(banner);
      banner = null;
    }
  }

  if (sharedQuestions.isNotEmpty) {
    sections.insert(
      0,
      FormSection(
        title: 'Student information',
        information: 'Shown once here and saved into every selected form.',
        questions: sharedQuestions,
      ),
    );
    banners.insert(0, null);
  }

  return CompositeForm(
    form: CounselingForm(
      id: 'batch',
      documentNo: 'Batch fill',
      title: 'Combined student forms',
      sections: sections,
    ),
    sourceForms: sources,
    origins: origins,
    compositeByOriginal: compositeByOriginal,
    ownCompositeIds: ownCompositeIds,
    sectionBanners: banners,
  );
}
