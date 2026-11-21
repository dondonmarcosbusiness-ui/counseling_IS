import 'package:counseling_is/features/forms/domain/counseling_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog offers the active templates only', () {
    expect(counselingFormCatalog, hasLength(11));
    expect(counselingFormCatalog.map((form) => form.id).toSet(), hasLength(11));
    expect(
      counselingFormCatalog.every((form) => form.questionCount > 0),
      isTrue,
    );
    expect(
      counselingFormCatalog.where((form) => form.documentNo == 'CC Form 9'),
      hasLength(2),
    );
  });

  test('student information sheet is retired but still resolvable', () {
    // Removed from the Student Forms tabs: students are registered through
    // the New student dialog, which mirrors this sheet.
    expect(
      counselingFormCatalog.map((form) => form.id),
      isNot(contains('student_information')),
    );
    expect(
      retiredCounselingForms.map((form) => form.id),
      contains('student_information'),
    );

    final form = counselingFormById('student_information');
    expect(form, isNotNull);
    expect(form!.title, 'Student Information Sheet');
    expect(form.documentNo, 'CC Form 1');
    expect(form.questionCount, greaterThan(0));
  });

  test('child-protection intake is labeled as an internal workflow', () {
    final form = counselingFormById('child_protection_intake')!;
    expect(form.title, contains('Confidential'));
    expect(form.documentNo, 'Local workflow');
    expect(
      form.sections.first.information,
      contains('not an official DepEd form'),
    );
    expect(
      form.sections.expand((section) => section.questions).map((q) => q.id),
      containsAll([
        'factual_account',
        'immediate_safety_action',
        'referral_status',
        'next_follow_up_date',
      ]),
    );
  });

  test('person-name questions use four structured components', () {
    for (final form in counselingFormCatalog) {
      final groups = <String, Set<FormNamePart>>{};
      for (final section in form.sections) {
        for (final question in section.questions) {
          final group = question.nameGroup;
          final part = question.namePart;
          if (group == null || part == null) continue;
          groups.putIfAbsent(group, () => <FormNamePart>{}).add(part);
        }
      }

      for (final parts in groups.values) {
        expect(
          parts,
          containsAll(FormNamePart.values),
          reason: '${form.title} should capture every name component.',
        );
      }
    }
  });

  test('gender fields offer prefer not to say in every form', () {
    final genderQuestions = [
      for (final form in counselingFormCatalog)
        for (final section in form.sections)
          for (final question in section.questions)
            if (question.id == 'sex') question,
    ];

    expect(genderQuestions, hasLength(3));
    for (final question in genderQuestions) {
      expect(question.label, 'Gender');
      expect(question.options, contains('Prefer not to say'));
      expect(question.type, FormInputType.choice);
    }

    final siblingGender = counselingFormById('student_information')!.sections
        .firstWhere((section) => section.title == 'Siblings and education')
        .questions
        .first
        .entryFields
        .firstWhere((field) => field.id == 'gender');
    expect(siblingGender.type, FormInputType.choice);
    expect(
      siblingGender.options,
      containsAll(['Male', 'Female', 'Prefer not to say']),
    );
  });

  test('siblings and education are defined as repeatable field groups', () {
    final section = counselingFormById('student_information')!.sections
        .firstWhere((section) => section.title == 'Siblings and education');
    final siblings = section.questions.first;
    final education = section.questions.last;

    expect(siblings.type, FormInputType.repeatable);
    expect(siblings.entryFields.map((field) => field.id), [
      'first_name',
      'middle_name',
      'last_name',
      'suffix',
      'age',
      'gender',
      'grade_year_work',
      'school',
    ]);
    expect(education.type, FormInputType.repeatable);
    expect(education.entryFields.map((field) => field.id), [
      'school_last_attended',
      'year_graduated',
      'awards_honors',
    ]);
  });

  test('multi-value form sections use separate repeatable entry fields', () {
    const expectedFields = {
      'session_records': ['date', 'summary', 'interventions', 'next_steps'],
      'follow_up_entries': [
        'date',
        'mode',
        'observation_update',
        'next_action',
      ],
      'participants': [
        'first_name',
        'middle_name',
        'last_name',
        'suffix',
        'designation_role',
      ],
      'results': [
        'area_dimension',
        'raw_score',
        'standard_score',
        'level_category',
        'interpretation',
      ],
      'activities': ['date', 'venue', 'number_of_participants', 'remarks'],
      'visit_entries': [
        'date',
        'first_name',
        'middle_name',
        'last_name',
        'suffix',
        'grade_section',
        'reason_referral',
        'concern_code',
        'action_taken',
        'follow_up_needed',
        'counselor_staff',
        'remarks',
      ],
    };

    for (final form in counselingFormCatalog) {
      for (final section in form.sections) {
        for (final question in section.questions) {
          final expected = expectedFields[question.id];
          if (expected == null) continue;
          expect(
            question.type,
            FormInputType.repeatable,
            reason: '${form.id}.${question.id} should use separate entries.',
          );
          expect(
            question.entryFields.map((field) => field.id).toList(),
            expected,
            reason: '${form.id}.${question.id} should expose each data field.',
          );
        }
      }
    }
  });

  test('repeatable date fields are date pickers rather than text fields', () {
    final repeatableDateFields = [
      for (final form in counselingFormCatalog)
        for (final section in form.sections)
          for (final question in section.questions)
            if (question.type == FormInputType.repeatable)
              for (final field in question.entryFields)
                if (field.label.toLowerCase() == 'date') field,
    ];

    expect(repeatableDateFields, hasLength(4));
    expect(
      repeatableDateFields.every((field) => field.type == FormInputType.date),
      isTrue,
    );
  });
}
