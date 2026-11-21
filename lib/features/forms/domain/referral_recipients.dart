/// Offices and persons a Referral Form (CC Form 4) can be e-mailed to.
class ReferralRecipient {
  const ReferralRecipient(this.id, this.label);

  final String id;
  final String label;
}

const referralRecipients = <ReferralRecipient>[
  ReferralRecipient('principal', 'School Principal'),
  ReferralRecipient('police', 'Police (PNP / Women and Children Desk)'),
  ReferralRecipient('dswd_lgu', 'DSWD / LGU'),
  ReferralRecipient('mental_health', 'Mental health professional'),
  ReferralRecipient('division_office', 'Division Mental Health Office'),
  ReferralRecipient('other', 'Other'),
];
