enum FormInputType {
  text,
  multiline,
  date,
  choice,
  choices,
  checkbox,
  repeatable,
}

enum FormNamePart { first, middle, last, suffix }

class FormEntryField {
  const FormEntryField({
    required this.id,
    required this.label,
    this.type = FormInputType.text,
    this.options = const [],
  });

  const FormEntryField.date({required this.id, required this.label})
    : type = FormInputType.date,
      options = const [];

  const FormEntryField.choice({
    required this.id,
    required this.label,
    required this.options,
  }) : type = FormInputType.choice;

  final String id;
  final String label;
  final FormInputType type;
  final List<String> options;
}

class FormQuestion {
  const FormQuestion({
    required this.id,
    required this.label,
    this.type = FormInputType.text,
    this.options = const [],
    this.hint,
    this.nameGroup,
    this.namePart,
    this.nameAnchor,
    this.entryFields = const [],
    this.entryLabel = 'record',
  });

  final String id;
  final String label;
  final FormInputType type;
  final List<String> options;
  final String? hint;
  final String? nameGroup;
  final FormNamePart? namePart;
  final String? nameAnchor;
  final List<FormEntryField> entryFields;
  final String entryLabel;

  const FormQuestion.text(String id, String label, {String? hint})
    : this(id: id, label: label, hint: hint);

  const FormQuestion.multiline(String id, String label, {String? hint})
    : this(id: id, label: label, type: FormInputType.multiline, hint: hint);

  const FormQuestion.date(String id, String label)
    : this(id: id, label: label, type: FormInputType.date);

  const FormQuestion.choice(String id, String label, List<String> options)
    : this(id: id, label: label, type: FormInputType.choice, options: options);

  const FormQuestion.choices(String id, String label, List<String> options)
    : this(id: id, label: label, type: FormInputType.choices, options: options);

  const FormQuestion.checkbox(String id, String label)
    : this(id: id, label: label, type: FormInputType.checkbox);

  const FormQuestion.repeatable(
    String id,
    String label, {
    required List<FormEntryField> fields,
    String entryLabel = 'record',
  }) : this(
         id: id,
         label: label,
         type: FormInputType.repeatable,
         entryFields: fields,
         entryLabel: entryLabel,
       );

  const FormQuestion.personNamePart({
    required this.id,
    required this.label,
    required this.nameGroup,
    required this.namePart,
    required this.nameAnchor,
  }) : type = FormInputType.text,
       options = const [],
       hint = null,
       entryFields = const [],
       entryLabel = 'record';
}

List<FormQuestion> personNameQuestions(
  String id,
  String subject, {
  required String anchor,
}) => [
  FormQuestion.personNamePart(
    id: '${id}_first',
    label: '$subject — First name',
    nameGroup: id,
    namePart: FormNamePart.first,
    nameAnchor: anchor,
  ),
  FormQuestion.personNamePart(
    id: '${id}_middle',
    label: '$subject — Middle name (optional)',
    nameGroup: id,
    namePart: FormNamePart.middle,
    nameAnchor: anchor,
  ),
  FormQuestion.personNamePart(
    id: '${id}_last',
    label: '$subject — Last name',
    nameGroup: id,
    namePart: FormNamePart.last,
    nameAnchor: anchor,
  ),
  FormQuestion.personNamePart(
    id: '${id}_suffix',
    label: '$subject — Suffix (optional)',
    nameGroup: id,
    namePart: FormNamePart.suffix,
    nameAnchor: anchor,
  ),
];

class FormSection {
  const FormSection({
    required this.title,
    required this.questions,
    this.information,
  });

  final String title;
  final List<FormQuestion> questions;
  final String? information;
}

class CounselingForm {
  const CounselingForm({
    required this.id,
    required this.documentNo,
    required this.title,
    required this.sections,
  });

  final String id;
  final String documentNo;
  final String title;
  final List<FormSection> sections;

  int get questionCount =>
      sections.fold(0, (total, section) => total + section.questions.length);
}

final counselingFormCatalog = <CounselingForm>[
  CounselingForm(
    id: 'student_information',
    documentNo: 'CC Form 1',
    title: 'Student Information Sheet',
    sections: [
      FormSection(
        title: 'Personal information',
        questions: [
          FormQuestion.text('form_number', 'Form number'),
          FormQuestion.date('date_accomplished', 'Date accomplished'),
          ...personNameQuestions(
            'student_name',
            'Student',
            anchor: 'Full name (Last, First, MI)',
          ),
          FormQuestion.text('grade_section', 'Grade and section'),
          FormQuestion.date('date_of_birth', 'Date of birth'),
          FormQuestion.text('age', 'Age'),
          FormQuestion.choice('sex', 'Gender', [
            'Male',
            'Female',
            'Prefer not to say',
          ]),
          FormQuestion.multiline('home_address', 'Home address'),
          FormQuestion.text('contact_number', 'Contact number'),
          FormQuestion.text('religion', 'Religion'),
          FormQuestion.text('nationality', 'Nationality'),
          FormQuestion.text('parents_civil_status', 'Civil status of parents'),
        ],
      ),
      FormSection(
        title: 'Family background',
        questions: [
          ...personNameQuestions('father_name', 'Father', anchor: 'Name'),
          FormQuestion.text('father_occupation', 'Father: occupation'),
          FormQuestion.text(
            'father_education',
            'Father: highest educational attainment',
          ),
          FormQuestion.text('father_contact', 'Father: contact number'),
          ...personNameQuestions('mother_name', 'Mother', anchor: 'Name'),
          FormQuestion.text('mother_occupation', 'Mother: occupation'),
          FormQuestion.text(
            'mother_education',
            'Mother: highest educational attainment',
          ),
          FormQuestion.text('mother_contact', 'Mother: contact number'),
          ...personNameQuestions(
            'guardian_name',
            'Guardian (if applicable)',
            anchor: 'Name',
          ),
          FormQuestion.text('guardian_relationship', 'Guardian: relationship'),
          FormQuestion.multiline(
            'guardian_contact_address',
            'Guardian: contact number and address',
          ),
        ],
      ),
      FormSection(
        title: 'Siblings and education',
        questions: [
          FormQuestion.repeatable(
            'siblings',
            'Siblings',
            entryLabel: 'sibling',
            fields: [
              FormEntryField(id: 'first_name', label: 'First name'),
              FormEntryField(id: 'middle_name', label: 'Middle name'),
              FormEntryField(id: 'last_name', label: 'Last name'),
              FormEntryField(id: 'suffix', label: 'Suffix'),
              FormEntryField(id: 'age', label: 'Age'),
              FormEntryField.choice(
                id: 'gender',
                label: 'Gender',
                options: ['Male', 'Female', 'Prefer not to say'],
              ),
              FormEntryField(id: 'grade_year_work', label: 'Grade/year/work'),
              FormEntryField(id: 'school', label: 'School'),
            ],
          ),
          FormQuestion.repeatable(
            'education_background',
            'Educational background',
            fields: [
              FormEntryField(
                id: 'school_last_attended',
                label: 'School last attended',
              ),
              FormEntryField(id: 'year_graduated', label: 'Year graduated'),
              FormEntryField(id: 'awards_honors', label: 'Awards / honors'),
            ],
          ),
        ],
      ),
      FormSection(
        title: 'Personal assessment and declaration',
        questions: [
          FormQuestion.multiline(
            'strengths',
            'My strengths / what I am good at',
          ),
          FormQuestion.multiline(
            'challenges',
            'My challenges / areas for improvement',
          ),
          FormQuestion.multiline(
            'career_aspiration',
            'My career aspiration / dream',
          ),
          FormQuestion.checkbox(
            'information_certified',
            'I certify that the information provided is true and correct.',
          ),
          ...personNameQuestions(
            'student_signature',
            'Student signature',
            anchor: "Student's Signature",
          ),
          FormQuestion.date('declaration_date', 'Date'),
        ],
      ),
    ],
  ),
  CounselingForm(
    id: 'counseling_intake',
    documentNo: 'GS Form 2',
    title: 'Counseling Intake Form',
    sections: [
      FormSection(
        title: 'Client information',
        questions: [
          ...personNameQuestions(
            'learner_name',
            'Learner',
            anchor: 'Name of learner',
          ),
          ...personNameQuestions(
            'parent_guardian',
            'Parent / guardian',
            anchor: 'Parent / guardian',
          ),
          FormQuestion.text('grade_section', 'Grade and section'),
          FormQuestion.choice('sex', 'Gender', [
            'Male',
            'Female',
            'Prefer not to say',
          ]),
          FormQuestion.text('age', 'Age'),
          FormQuestion.date('date_of_birth', 'Date of birth'),
          FormQuestion.multiline('home_address', 'Home address'),
          FormQuestion.text('contact_number', 'Contact number'),
        ],
      ),
      FormSection(
        title: 'Referral information',
        questions: [
          FormQuestion.text('form_number', 'Form number'),
          FormQuestion.text('case_number', 'Case number'),
          ...personNameQuestions(
            'referred_by',
            'Referred by',
            anchor: 'Referred by',
          ),
          FormQuestion.text('designation', 'Designation'),
          FormQuestion.text('referrer_contact', 'Contact number'),
          FormQuestion.date('referral_date', 'Date referred'),
          FormQuestion.choices('referral_nature', 'Nature of referral', [
            'Academic difficulty',
            'Chronic absenteeism',
            'Behavioral problem',
            'Bullying / cyberbullying',
            'Peer conflict',
            'Family / home problem',
            'Mental health concern',
            'Substance abuse',
            'Child protection (RA 7610)',
            'Self-harm / suicidal ideation',
            'Career concern',
            'Others',
          ]),
          FormQuestion.multiline('referral_other', 'Other referral reason'),
          FormQuestion.multiline(
            'concern_description',
            'Brief description of concern',
          ),
        ],
      ),
      FormSection(
        title: 'Counseling sessions',
        questions: [
          FormQuestion.repeatable(
            'session_records',
            'Counseling sessions',
            entryLabel: 'session',
            fields: [
              FormEntryField.date(id: 'date', label: 'Date'),
              FormEntryField(id: 'summary', label: 'Session summary'),
              FormEntryField(id: 'interventions', label: 'Interventions'),
              FormEntryField(id: 'next_steps', label: 'Next steps'),
            ],
          ),
        ],
      ),
      FormSection(
        title: 'Disposition',
        questions: [
          FormQuestion.choices('disposition', 'Disposition', [
            'Case resolved / closed',
            'For continued counseling',
            'Referred to the school principal',
            'Referred to DSWD / LGU',
            'Referred to a mental health professional',
            'Referred to Division Mental Health Office (RA 12080)',
            'Others',
          ]),
          FormQuestion.multiline('disposition_other', 'Other disposition'),
          FormQuestion.multiline('counselor_remarks', 'Counselor remarks'),
        ],
      ),
    ],
  ),
  CounselingForm(
    id: 'individual_counseling',
    documentNo: 'CC Form 3',
    title: 'Individual Counseling Record',
    sections: [
      FormSection(
        title: 'Session details',
        questions: [
          FormQuestion.text('case_number', 'Case number'),
          FormQuestion.date('session_date', 'Date'),
          FormQuestion.text('session_time', 'Time'),
          FormQuestion.text('session_number', 'Session number'),
          ...personNameQuestions(
            'learner_name',
            'Learner',
            anchor: 'Name of learner',
          ),
          FormQuestion.text('grade_section', 'Grade and section'),
          FormQuestion.text('school_year', 'School year'),
          FormQuestion.text('age', 'Age'),
          FormQuestion.choice('sex', 'Gender', [
            'Male',
            'Female',
            'Prefer not to say',
          ]),
          FormQuestion.choices('session_type', 'Type of session', [
            'Walk-in',
            'Referred',
            'Follow-up',
            'Group counseling',
            'Parent conference',
            'Others',
          ]),
          FormQuestion.text('session_duration', 'Session duration'),
          FormQuestion.text('venue', 'Venue'),
        ],
      ),
      FormSection(
        title: 'Confidential session notes',
        questions: [
          FormQuestion.multiline(
            'presenting_concern',
            'Presenting concern / problem statement',
          ),
          FormQuestion.multiline('background', 'Background information'),
          FormQuestion.multiline(
            'observations',
            'Counselor observations / assessment',
          ),
          FormQuestion.multiline(
            'interventions',
            'Interventions / techniques applied',
          ),
          FormQuestion.multiline(
            'action_plan',
            'Action plan / agreed next steps',
          ),
        ],
      ),
      FormSection(
        title: 'Disposition',
        questions: [
          FormQuestion.choices('disposition', 'Disposition', [
            'Case closed / resolved',
            'For follow-up',
            'Referred to',
            'Endorsed to Division Mental Health Office',
          ]),
          FormQuestion.date('next_session_date', 'Date of next session'),
          FormQuestion.text('next_session_time', 'Time of next session'),
          FormQuestion.text('referred_to', 'Referred to'),
          ...personNameQuestions(
            'learner_signature',
            'Learner / client signature',
            anchor: 'Learner signature',
          ),
        ],
      ),
    ],
  ),
  CounselingForm(
    id: 'referral',
    documentNo: 'CC Form 4',
    title: 'Referral Form',
    sections: [
      FormSection(
        title: 'Referral source',
        questions: [
          FormQuestion.text('referral_number', 'Referral number'),
          ...personNameQuestions(
            'referring_person',
            'Referring person',
            anchor: 'Referring person',
          ),
          FormQuestion.text('designation', 'Designation'),
          FormQuestion.text('department', 'Department / subject area'),
          FormQuestion.text('referrer_contact', 'Contact number'),
          FormQuestion.date('referral_date', 'Date referred'),
        ],
      ),
      FormSection(
        title: 'Learner information',
        questions: [
          ...personNameQuestions(
            'learner_name',
            'Learner',
            anchor: 'Name of learner',
          ),
          FormQuestion.text('grade_section', 'Grade and section'),
          FormQuestion.text('age', 'Age'),
          ...personNameQuestions(
            'parent_guardian',
            'Parent / guardian',
            anchor: 'Parent / guardian',
          ),
          FormQuestion.text('guardian_contact', 'Contact number'),
        ],
      ),
      FormSection(
        title: 'Reason and actions already taken',
        questions: [
          FormQuestion.choices('referral_reasons', 'Reasons for referral', [
            'Academic difficulty / failing grades',
            'Chronic absenteeism / tardiness',
            'Behavioral problem in class',
            'Bullying / cyberbullying (RA 10627)',
            'Peer conflict / aggression',
            'Family problem / home situation',
            'Mental health concern (RA 11036)',
            'Substance abuse / drug-related',
            'Child abuse / neglect (RA 7610)',
            'Self-harm / suicidal ideation',
            'Career / academic decision concern',
            'Others',
          ]),
          FormQuestion.multiline('other_reason', 'Other reason'),
          FormQuestion.multiline(
            'concern_description',
            'Brief description of concern',
          ),
          FormQuestion.choices('actions_taken', 'Actions already taken', [
            'Talked to the learner',
            'Notified parent / guardian',
            'Coordinated with co-teachers',
            'None yet',
          ]),
        ],
      ),
      FormSection(
        title: 'Guidance office action',
        questions: [
          FormQuestion.date('date_received', 'Date received'),
          FormQuestion.text('time_received', 'Time received'),
          FormQuestion.choices('office_actions', 'Action taken', [
            'Individual counseling conducted',
            'Parent conference scheduled / held',
            'Referred to external agency / specialist',
            'Case monitored / follow-up scheduled',
          ]),
          FormQuestion.multiline('remarks', 'Remarks'),
          ...personNameQuestions(
            'referrer_signature',
            'Referring person signature',
            anchor: 'Referring person',
          ),
        ],
      ),
    ],
  ),
  CounselingForm(
    id: 'home_visit',
    documentNo: 'CC Form 5',
    title: 'Home Visit Report',
    sections: [
      FormSection(
        title: 'Visit information',
        questions: [
          FormQuestion.date('visit_date', 'Date of visit'),
          FormQuestion.text('visit_time', 'Time'),
          FormQuestion.multiline('address_visited', 'Home address visited'),
          ...personNameQuestions(
            'learner_name',
            'Learner',
            anchor: 'Name of learner',
          ),
          FormQuestion.text('grade_section', 'Grade and section'),
          FormQuestion.text('school_year', 'School year'),
          ...personNameQuestions(
            'parent_guardian',
            'Parent / guardian',
            anchor: 'Parent / guardian',
          ),
          FormQuestion.text('relationship', 'Relationship'),
        ],
      ),
      FormSection(
        title: 'Purpose of visit',
        questions: [
          FormQuestion.choices('visit_purpose', 'Select all that apply', [
            'Follow-up on chronic absenteeism',
            'Academic monitoring / low performance',
            'Behavioral concern',
            'Family situation assessment',
            'Child protection concern (RA 7610)',
            'Mental health follow-up (RA 11036 / RA 12080)',
            'Drop-out prevention / retrieval',
            'Others',
          ]),
          FormQuestion.multiline('other_purpose', 'Other purpose'),
        ],
      ),
      FormSection(
        title: 'Findings and action plan',
        questions: [
          FormQuestion.multiline(
            'observations',
            'Observations during the home visit',
          ),
          FormQuestion.multiline(
            'discussion',
            'Matters discussed with parent / guardian',
          ),
          FormQuestion.multiline(
            'home_environment',
            'Home environment / learner situation',
          ),
          FormQuestion.multiline('recommendations', 'Recommended next steps'),
          FormQuestion.date('follow_up_date', 'Follow-up date'),
          FormQuestion.text('follow_up_mode', 'Mode of follow-up'),
          ...personNameQuestions(
            'conducted_by',
            'Conducted by',
            anchor: 'Conducted by',
          ),
        ],
      ),
    ],
  ),
  CounselingForm(
    id: 'follow_up_monitoring',
    documentNo: 'CC Form 6',
    title: 'Follow-up Monitoring Sheet',
    sections: [
      FormSection(
        title: 'Learner and case information',
        questions: [
          ...personNameQuestions(
            'learner_name',
            'Learner',
            anchor: 'Name of learner',
          ),
          FormQuestion.text('grade_section', 'Grade and section'),
          FormQuestion.text('case_number', 'Case number'),
          FormQuestion.multiline('nature_of_concern', 'Nature of concern'),
          FormQuestion.date('case_opened', 'Date case opened'),
          ...personNameQuestions('counselor', 'Counselor', anchor: 'Counselor'),
        ],
      ),
      FormSection(
        title: 'Follow-up log',
        questions: [
          FormQuestion.repeatable(
            'follow_up_entries',
            'Follow-up entries',
            entryLabel: 'follow-up',
            fields: [
              FormEntryField.date(id: 'date', label: 'Date'),
              FormEntryField(id: 'mode', label: 'Mode'),
              FormEntryField(
                id: 'observation_update',
                label: 'Observation / update',
              ),
              FormEntryField(id: 'next_action', label: 'Next action'),
            ],
          ),
        ],
      ),
      FormSection(
        title: 'Case status',
        questions: [
          FormQuestion.choices('case_status', 'Status', [
            'Case ongoing — continued monitoring',
            'Case closed / resolved',
            'Referred to external agency',
            'Endorsed to the next school year',
          ]),
          FormQuestion.multiline('final_remarks', 'Summary / final remarks'),
        ],
      ),
    ],
  ),
  CounselingForm(
    id: 'parent_conference',
    documentNo: 'CC Form 7',
    title: 'Parent / Guardian Conference Report',
    sections: [
      FormSection(
        title: 'Conference details',
        questions: [
          FormQuestion.date('conference_date', 'Date'),
          FormQuestion.text('conference_time', 'Time'),
          FormQuestion.text('venue', 'Venue'),
          FormQuestion.text('conference_number', 'Conference number'),
        ],
      ),
      FormSection(
        title: 'Learner and parent / guardian',
        questions: [
          ...personNameQuestions(
            'learner_name',
            'Learner',
            anchor: 'Name of learner',
          ),
          FormQuestion.text('grade_section', 'Grade and section'),
          ...personNameQuestions(
            'class_adviser',
            'Class adviser',
            anchor: 'Class adviser',
          ),
          ...personNameQuestions(
            'guardian_name',
            'Parent / guardian',
            anchor: 'Parent / guardian name',
          ),
          FormQuestion.text('relationship', 'Relationship'),
          FormQuestion.text('guardian_contact', 'Contact number'),
        ],
      ),
      FormSection(
        title: 'Participants and documentation',
        questions: [
          FormQuestion.repeatable(
            'participants',
            'Participants',
            entryLabel: 'participant',
            fields: [
              FormEntryField(id: 'first_name', label: 'First name'),
              FormEntryField(
                id: 'middle_name',
                label: 'Middle name (optional)',
              ),
              FormEntryField(id: 'last_name', label: 'Last name'),
              FormEntryField(id: 'suffix', label: 'Suffix (optional)'),
              FormEntryField(
                id: 'designation_role',
                label: 'Designation / role',
              ),
            ],
          ),
          FormQuestion.multiline('agenda', 'Agenda / purpose of conference'),
          FormQuestion.multiline('discussion', 'Matters discussed'),
          FormQuestion.multiline('agreements', 'Agreements / action plan'),
          FormQuestion.date('next_conference_date', 'Next conference date'),
          FormQuestion.text('mode', 'Mode'),
        ],
      ),
    ],
  ),
  CounselingForm(
    id: 'testing_log',
    documentNo: 'GS Form 8',
    title: 'Testing Service Log',
    sections: [
      FormSection(
        title: 'Learner information',
        questions: [
          ...personNameQuestions(
            'learner_name',
            'Learner',
            anchor: 'Name of learner',
          ),
          FormQuestion.text('grade_section', 'Grade and section'),
          FormQuestion.date('testing_date', 'Date of testing'),
          FormQuestion.text('age', 'Age'),
          FormQuestion.choice('sex', 'Gender', [
            'Male',
            'Female',
            'Prefer not to say',
          ]),
        ],
      ),
      FormSection(
        title: 'Test administered',
        questions: [
          FormQuestion.choices('test_types', 'Type of test administered', [
            'NCAE',
            'Interest inventory',
            'Career aptitude test',
            'Psychological screening tool',
            'Learning style inventory',
            'Personality assessment',
            'Others',
          ]),
          FormQuestion.multiline('other_test_type', 'Other test type'),
          FormQuestion.text('test_title', 'Test title / instrument used'),
          FormQuestion.date('date_administered', 'Date administered'),
          FormQuestion.date('date_interpreted', 'Date interpreted'),
        ],
      ),
      FormSection(
        title: 'Results and discussion',
        questions: [
          FormQuestion.repeatable(
            'results',
            'Results by area / dimension',
            entryLabel: 'result',
            fields: [
              FormEntryField(id: 'area_dimension', label: 'Area / dimension'),
              FormEntryField(id: 'raw_score', label: 'Raw score'),
              FormEntryField(id: 'standard_score', label: 'Standard score'),
              FormEntryField(id: 'level_category', label: 'Level / category'),
              FormEntryField(id: 'interpretation', label: 'Interpretation'),
            ],
          ),
          FormQuestion.multiline(
            'remarks',
            'Counselor observations / recommendations',
          ),
          FormQuestion.date(
            'learner_discussion_date',
            'Results discussed with learner on',
          ),
          ...personNameQuestions(
            'learner_signature',
            'Learner signature',
            anchor: 'Learner signature',
          ),
          FormQuestion.date(
            'parent_discussion_date',
            'Results discussed with parent on',
          ),
          ...personNameQuestions(
            'parent_signature',
            'Parent signature',
            anchor: 'Parent signature',
          ),
        ],
      ),
    ],
  ),
  CounselingForm(
    id: 'monthly_accomplishment',
    documentNo: 'CC Form 9',
    title: 'Monthly Accomplishment Report',
    sections: [
      FormSection(
        title: 'Report details',
        questions: [
          FormQuestion.text('period_covered', 'Month / period covered'),
          FormQuestion.date('date_submitted', 'Date submitted'),
          ...personNameQuestions(
            'submitted_by',
            'Submitted by',
            anchor: 'Submitted by',
          ),
        ],
      ),
      FormSection(
        title: 'Guidance services summary',
        questions: [
          FormQuestion.multiline(
            'services_summary',
            'Targets, accomplishments, percentage rate, and remarks',
            hint: 'Record orientation, individual inventory, counseling, information, testing, career guidance, placement, follow-up, referral, and research/evaluation services.',
          ),
        ],
      ),
      FormSection(
        title: 'Counseling statistics',
        questions: [
          FormQuestion.multiline(
            'counseling_statistics',
            'Male, female, and total counts',
            hint: 'Record walk-in, referred, and follow-up counseling; parent conferences; group counseling; cases resolved; and cases referred to external agencies.',
          ),
        ],
      ),
      FormSection(
        title: 'Activities and plans',
        questions: [
          FormQuestion.repeatable(
            'activities',
            'Activities / programs conducted',
            entryLabel: 'activity',
            fields: [
              FormEntryField.date(id: 'date', label: 'Date'),
              FormEntryField(id: 'venue', label: 'Venue'),
              FormEntryField(
                id: 'number_of_participants',
                label: 'Number of participants',
              ),
              FormEntryField(id: 'remarks', label: 'Remarks'),
            ],
          ),
          FormQuestion.multiline(
            'challenges',
            'Problems / challenges encountered',
          ),
          FormQuestion.multiline(
            'recommendations',
            'Recommendations / plans for next month',
          ),
        ],
      ),
    ],
  ),
  CounselingForm(
    id: 'informed_consent',
    documentNo: 'CC Form 9',
    title: 'Informed Consent for Counseling Services',
    sections: [
      FormSection(
        title: 'Purpose, confidentiality, and data protection',
        information: 'Counseling is a voluntary, confidential professional service that supports academic, personal, social, and career development. Sessions help learners explore concerns and develop ways to address challenges; participation may be paused or stopped at any time. Sessions are usually 30–60 minutes. Confidentiality may be limited when there is imminent risk of harm to self, a credible threat to another person, suspected child abuse, neglect or exploitation, a court or legal order, or a necessary school safety disclosure. Records are handled for counseling purposes under the Data Privacy Act of 2012, retained as required, and securely disposed of. Learners may ask about the process, request a summary of their records, and withdraw consent without penalty. Learners are expected to attend, communicate honestly, respect the counseling space, protect group-session confidentiality, and participate in agreed activities.',
        questions: [
          FormQuestion.text('form_number', 'Form number'),
          ...personNameQuestions(
            'student_name',
            'Student',
            anchor: 'Naka-print na Pangalan ng Mag-aaral',
          ),
          FormQuestion.text('grade_section', 'Grade and section'),
          FormQuestion.date('completion_date', 'Date completed'),
        ],
      ),
      FormSection(
        title: 'Student acknowledgements',
        questions: [
          FormQuestion.checkbox(
            'ack_read',
            'I have read and understood this informed consent form.',
          ),
          FormQuestion.checkbox(
            'ack_purpose',
            'I understand the purpose and nature of counseling services.',
          ),
          FormQuestion.checkbox(
            'ack_confidentiality',
            'I understand confidentiality and its limits.',
          ),
          FormQuestion.checkbox(
            'ack_voluntary',
            'I voluntarily agree to participate in counseling services.',
          ),
          FormQuestion.checkbox(
            'ack_withdraw',
            'I understand that I may withdraw consent at any time without penalty.',
          ),
          ...personNameQuestions(
            'student_signature',
            'Student signature',
            anchor: 'Lagda ng Mag-aaral',
          ),
          FormQuestion.date('student_signature_date', 'Date'),
        ],
      ),
      FormSection(
        title: 'Parent / guardian consent (for learners under 18)',
        questions: [
          FormQuestion.multiline(
            'guardian_consent',
            'Consent statement',
            hint: 'Record the parent / guardian’s consent for the learner to participate in counseling services.',
          ),
          ...personNameQuestions(
            'guardian_name',
            'Parent / guardian',
            anchor: 'Pangalan ng Magulang / Tagapag-alaga',
          ),
          FormQuestion.text('guardian_relationship', 'Relationship to student'),
          FormQuestion.text('guardian_contact', 'Contact number'),
          ...personNameQuestions(
            'guardian_signature',
            'Parent / guardian signature',
            anchor: 'Lagda',
          ),
          FormQuestion.date('guardian_signature_date', 'Date'),
        ],
      ),
      FormSection(
        title: 'Acknowledged by the guidance counselor',
        questions: [
          FormQuestion.date('counselor_received_date', 'Date received'),
        ],
      ),
    ],
  ),
  CounselingForm(
    id: 'care_center_log',
    documentNo: 'CC Form 10',
    title: 'Care Center Visit Log Sheet',
    sections: [
      FormSection(
        title: 'Log sheet details',
        questions: [
          FormQuestion.text('month_year', 'Month / year'),
          FormQuestion.text('quarter', 'Quarter'),
          FormQuestion.text('page_number', 'Page number'),
        ],
      ),
      FormSection(
        title: 'Visit entries',
        questions: [
          FormQuestion.repeatable(
            'visit_entries',
            'Care Center visit entries',
            entryLabel: 'visit',
            fields: [
              FormEntryField.date(id: 'date', label: 'Date'),
              FormEntryField(id: 'first_name', label: 'First name'),
              FormEntryField(
                id: 'middle_name',
                label: 'Middle name (optional)',
              ),
              FormEntryField(id: 'last_name', label: 'Last name'),
              FormEntryField(id: 'suffix', label: 'Suffix (optional)'),
              FormEntryField(id: 'grade_section', label: 'Grade / section'),
              FormEntryField(id: 'reason_referral', label: 'Reason / referral'),
              FormEntryField(
                id: 'concern_code',
                label: 'Concern code (AK/PS/KR/PG/PM/IB)',
              ),
              FormEntryField(id: 'action_taken', label: 'Action taken'),
              FormEntryField(id: 'follow_up_needed', label: 'Follow-up needed'),
              FormEntryField(id: 'counselor_staff', label: 'Counselor / staff'),
              FormEntryField(id: 'remarks', label: 'Remarks'),
            ],
          ),
        ],
      ),
      FormSection(
        title: 'Prepared and reviewed by',
        questions: [
          ...personNameQuestions(
            'prepared_by',
            'Prepared by',
            anchor: 'Prepared by',
          ),
          FormQuestion.date('prepared_date', 'Date'),
          ...personNameQuestions(
            'reviewed_by',
            'Received and reviewed by',
            anchor: 'Received and reviewed by',
          ),
          FormQuestion.text('reviewed_by_designation', 'Designation'),
          FormQuestion.date('reviewed_date', 'Date'),
        ],
      ),
    ],
  ),
  CounselingForm(
    id: 'child_protection_intake',
    documentNo: 'Local workflow',
    title: 'Child Protection Intake (Confidential)',
    sections: [
      FormSection(
        title: 'Intake notice',
        information:
            'Internal intake aid only; this is not an official DepEd form. '
            'Follow current school and division child-protection protocols. '
            'Record only information needed to respond safely.',
        questions: [
          FormQuestion.date('date_received', 'Date received'),
          FormQuestion.choice(
            'intake_method',
            'How was the concern received?',
            [
              'Learner disclosure',
              'Parent / guardian',
              'School personnel',
              'Referral',
              'Other',
            ],
          ),
          FormQuestion.text('intake_method_other', 'Other intake method'),
          FormQuestion.choice('concern_type', 'Concern type', [
            'Bullying',
            'Abuse or neglect concern',
            'Violence or threat',
            'Discrimination',
            'Online safety concern',
            'Other',
          ]),
          FormQuestion.text('concern_type_other', 'Other concern type'),
        ],
      ),
      FormSection(
        title: 'Learner and incident',
        questions: [
          ...personNameQuestions('learner', 'Learner', anchor: 'Learner name'),
          FormQuestion.text('grade_section', 'Grade and section'),
          FormQuestion.date('incident_date', 'Reported incident date'),
          FormQuestion.text('incident_location', 'Reported location'),
          FormQuestion.multiline(
            'factual_account',
            'Factual account of concern',
            hint: 'Use the learner’s own words where appropriate.',
          ),
        ],
      ),
      FormSection(
        title: 'Safety response and referral',
        questions: [
          FormQuestion.multiline(
            'immediate_safety_action',
            'Immediate safety action taken',
          ),
          FormQuestion.choice('referral_status', 'Referral status', [
            'Not referred',
            'Referred internally',
            'Referred to external agency',
            'Follow-up required',
          ]),
          FormQuestion.text('referred_to', 'Referred to / receiving office'),
          FormQuestion.date('referral_date', 'Referral date'),
          FormQuestion.multiline('follow_up_plan', 'Follow-up plan'),
          FormQuestion.date('next_follow_up_date', 'Next follow-up date'),
          FormQuestion.text('intake_officer', 'Receiving personnel'),
        ],
      ),
    ],
  ),
];

CounselingForm? counselingFormById(String id) {
  for (final form in counselingFormCatalog) {
    if (form.id == id) return form;
  }
  return null;
}
