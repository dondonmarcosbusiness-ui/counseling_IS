import 'package:counseling_is/features/forms/domain/composite_form.dart';
import 'package:counseling_is/features/forms/domain/counseling_form.dart';
import 'package:flutter_test/flutter_test.dart';

CounselingForm _formById(String id) => counselingFormById(id)!;

void main() {
  group('buildCompositeForm', () {
    test('shows shared student fields once, unprefixed', () {
      final composite = buildCompositeForm([
        _formById('counseling_intake'),
        _formById('individual_counseling'),
      ]);

      final ids = [
        for (final section in composite.form.sections)
          for (final question in section.questions) question.id,
      ];
      expect(ids.where((id) => id == 'grade_section'), hasLength(1));
      expect(ids.where((id) => id == 'sex'), hasLength(1));
      expect(ids.where((id) => id == 'age'), hasLength(1));
      // Nothing in the shared block carries a form prefix.
      expect(
        ids.where((id) => id.startsWith('counseling_intake__grade')),
        isEmpty,
      );
      // The first section is the shared student block.
      expect(composite.form.sections.first.title, 'Student information');
      expect(composite.sectionBanners.first, isNull);
    });

    test('namespaces the colliding disposition question per form', () {
      final composite = buildCompositeForm([
        _formById('counseling_intake'),
        _formById('individual_counseling'),
      ]);

      final intakeDisposition = composite.compositeIdFor(
        'counseling_intake',
        'disposition',
      );
      final recordDisposition = composite.compositeIdFor(
        'individual_counseling',
        'disposition',
      );
      expect(intakeDisposition, 'counseling_intake__disposition');
      expect(recordDisposition, 'individual_counseling__disposition');
      expect(intakeDisposition, isNot(recordDisposition));

      // Both colliding questions survive with their own option lists.
      final questions = [
        for (final section in composite.form.sections)
          for (final question in section.questions) question,
      ];
      final intake = questions.singleWhere(
        (question) => question.id == intakeDisposition,
      );
      final record = questions.singleWhere(
        (question) => question.id == recordDisposition,
      );
      expect(intake.options, contains('Case resolved / closed'));
      expect(intake.options, isNot(contains('For follow-up')));
      expect(record.options, contains('For follow-up'));
      expect(record.options, isNot(contains('Case resolved / closed')));
    });

    test('split round-trips merged answers back into per-form maps', () {
      final sources = [
        _formById('counseling_intake'),
        _formById('referral'),
        _formById('home_visit'),
      ];
      final composite = buildCompositeForm(sources);

      final data = <String, Object?>{
        'learner_name_first': 'Ana',
        'grade_section': 'Grade 9 - Sampaguita',
        'contact_number': '09171234567',
        'counseling_intake__referral_other': 'Peer conflict in class',
        'referral__other_reason': 'Tardiness',
        'home_visit__visit_time': '3:00 PM',
      };

      final split = composite.split(data);

      expect(
        split.keys,
        containsAll(['counseling_intake', 'referral', 'home_visit']),
      );
      // Shared fields land in every source form that has them.
      expect(split['counseling_intake']!['learner_name_first'], 'Ana');
      expect(split['referral']!['learner_name_first'], 'Ana');
      expect(split['home_visit']!['learner_name_first'], 'Ana');
      expect(split['referral']!['grade_section'], 'Grade 9 - Sampaguita');
      expect(split['counseling_intake']!['contact_number'], '09171234567');
      // Own fields come back under their original IDs.
      expect(
        split['counseling_intake']!['referral_other'],
        'Peer conflict in class',
      );
      expect(split['referral']!['other_reason'], 'Tardiness');
      expect(split['home_visit']!['visit_time'], '3:00 PM');
      // No composite prefix leaks into the stored records.
      expect(
        split.values.expand((map) => map.keys),
        isNot(anyElement(contains('__'))),
      );
    });

    test('isAnswered ignores data that only comes from the shared block', () {
      final composite = buildCompositeForm([
        _formById('counseling_intake'),
        _formById('home_visit'),
      ]);

      const sharedOnly = {
        'learner_name_first': 'Ana',
        'learner_name_last': 'Cruz',
        'grade_section': 'Grade 9 - Sampaguita',
        'sex': 'Female',
        'age': '15',
        'home_address': 'Purok 3',
        'contact_number': '09171234567',
      };
      expect(composite.isAnswered('counseling_intake', sharedOnly), isFalse);
      expect(composite.isAnswered('home_visit', sharedOnly), isFalse);

      const withOwnAnswer = {
        ...sharedOnly,
        'home_visit__visit_time': '3:00 PM',
      };
      expect(composite.isAnswered('home_visit', withOwnAnswer), isTrue);
      expect(composite.isAnswered('counseling_intake', withOwnAnswer), isFalse);

      const blankOwnAnswer = {...sharedOnly, 'home_visit__visit_time': '   '};
      expect(composite.isAnswered('home_visit', blankOwnAnswer), isFalse);
    });

    test('canonicalizes student_name and guardian_name into shared groups', () {
      final composite = buildCompositeForm([
        _formById('counseling_intake'),
        _formById('informed_consent'),
        _formById('parent_conference'),
      ]);

      final questions = {
        for (final section in composite.form.sections)
          for (final question in section.questions) question.id: question,
      };

      // informed_consent calls it student_name; it merges with the intake's
      // learner_name instead of rendering a second name block.
      expect(questions.containsKey('learner_name_first'), isTrue);
      expect(questions.containsKey('student_name_first'), isFalse);
      expect(questions['learner_name_first']!.nameGroup, 'learner_name');

      // parent_conference's guardian_name merges with the intake's
      // parent_guardian group.
      expect(questions.containsKey('parent_guardian_first'), isTrue);
      expect(questions.containsKey('guardian_name_first'), isFalse);

      // Splitting still writes each form's own field names.
      final split = composite.split(const {
        'learner_name_first': 'Ana',
        'parent_guardian_first': 'Rosa',
      });
      expect(split['informed_consent']!['student_name_first'], 'Ana');
      expect(split['counseling_intake']!['learner_name_first'], 'Ana');
      expect(split['parent_conference']!['guardian_name_first'], 'Rosa');
      expect(split['counseling_intake']!['parent_guardian_first'], 'Rosa');
    });

    test('puts one banner at the head of each source form', () {
      final composite = buildCompositeForm([
        _formById('counseling_intake'),
        _formById('individual_counseling'),
        _formById('referral'),
      ]);

      final banners = composite.sectionBanners;
      expect(banners, hasLength(composite.form.sections.length));
      // Shared student block has no banner.
      expect(banners.first, isNull);
      // One banner per source form, in selection order.
      final distinct = banners.whereType<String>().toList();
      expect(distinct, hasLength(3));
      expect(distinct[0], 'GS Form 2 · Counseling Intake Form');
      expect(distinct[1], 'CC Form 3 · Individual Counseling Record');
      expect(distinct[2], 'CC Form 4 · Referral Form');
      // Banners line up with the first section of their own form that
      // carries form-specific questions (the intake's Client information
      // section is entirely shared student fields, so it renders in the
      // shared block instead).
      expect(
        composite.form.sections[banners.indexOf(distinct[0])].title,
        'Referral information',
      );
      expect(
        composite.form.sections[banners.indexOf(distinct[1])].title,
        'Session details',
      );
      expect(
        composite.form.sections[banners.indexOf(distinct[2])].title,
        'Referral source',
      );
    });

    test('ignores duplicate source forms', () {
      final intake = _formById('counseling_intake');
      final composite = buildCompositeForm([intake, intake]);

      expect(composite.sourceForms, hasLength(1));
      expect(
        composite.form.sections
            .expand((section) => section.questions)
            .where(
              (question) => question.id == 'counseling_intake__case_number',
            ),
        hasLength(1),
      );
    });
  });

  group('isBlankAnswer', () {
    test('treats empty, false and all-blank rows as blank', () {
      expect(isBlankAnswer(null), isTrue);
      expect(isBlankAnswer(''), isTrue);
      expect(isBlankAnswer('   '), isTrue);
      expect(isBlankAnswer(false), isTrue);
      expect(isBlankAnswer(<Object?>[]), isTrue);
      expect(
        isBlankAnswer([
          {'date': '', 'summary': '  '},
        ]),
        isTrue,
      );

      expect(isBlankAnswer('Ana'), isFalse);
      expect(isBlankAnswer(true), isFalse);
      expect(isBlankAnswer(['Male']), isFalse);
      expect(
        isBlankAnswer([
          {'date': '', 'summary': 'Talked about attendance'},
        ]),
        isFalse,
      );
    });
  });
}
