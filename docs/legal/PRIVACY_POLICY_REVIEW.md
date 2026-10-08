# Privacy policy draft: review and release notes

Prepared: **2026-10-08**. Status: **English draft; not approved for publication**.

The owner confirmed a Ukrainian publisher, broad international distribution, English only, and
placeholders for publisher identity and contact details. The proposed public text is
[PRIVACY_POLICY_DRAFT.md](PRIVACY_POLICY_DRAFT.md). It describes a connected production release
with platform recovery, purchases, leaderboards, and optional non-personalized rewarded ads.
It does not certify those features as deployed or clear every country for launch.

## Decisions to complete before publication

| Decision | Required outcome |
| --- | --- |
| Publisher and contacts | Replace legal name, business form, public address, monitored privacy email, website, and effective date. Match the operator named in store listings. Do not publish the current `.example` support address. |
| Launch feature set | Audit the actual Android/iOS builds and production configuration. Remove sections for excluded features or revise them to describe actual behavior. Development currently has no backend URL, mock shop/leaderboards, and ads disabled. |
| EU/EEA and UK coverage | Resolve Article 27 representatives before targeting these regions, or document a defensible exemption/scope assessment. Do not remove the placeholders simply because no representative is appointed. Routine cloud-account processing gives no clear basis to assume the occasional-processing exemption. This last point is an inference about the planned service, not a regulator ruling on this game. |
| International transfers | Confirm hosting locations, Ukrainian administrator access, vendor/subprocessor countries and roles, executed agreements, and any required assessments and safeguards. Identify the actual mechanism in section 6. A German database alone does not settle international access or onward transfers. |
| Children and age treatment | Decide the actual audience, relevant local thresholds, likely child access, age design if needed, parental consent, and store/SDK child flags. The approved internal general-audience “3+” baseline does not supply an age gate or establish legal eligibility. Do not invent “13+” language to resolve this. |
| Advertising | Audit shipped SDKs, permissions, identifiers, consent timing, rewarded offers, and Google account configuration. Verify non-personalized requests, iOS IDFA/tracking disabled, no mediation, and privacy-choice access. No consent-dependent ad processing should start before the appropriate choice. |
| Legal bases | Review each purpose under Ukrainian law and, where applicable, EU/UK law. In particular, confirm contract necessity for public leaderboards; document legitimate interests and balancing; separate ad delivery, measurement, fraud prevention, and device access. Cite the actual statute for legal-obligation processing. |
| Retention | Approve and justify the 7/10-year purchase and 7-year privacy/audit periods; they are engineering choices, not verified universal statutory requirements. Decide inactive-account, support-mailbox, and synchronization-history periods. Make cleanup enforceable before using definite public retention promises. |
| Deletion and access requests | Publish a working external deletion route, configure the inbox, schedule backend deletion/export/retention work, and verify physical Android and iOS release flows. Define identity verification and a secure export-fulfillment process for email requests. Do not advertise a client export button that does not exist. |
| Automated decisions | Inventory automatic rejection, risk scoring, bans, and any profiling. If any decision has legal or similarly significant effects, add the required logic/consequence explanation, legal basis, human review, and contest process. Routine game-rule checks alone do not establish that classification. |
| Regional coverage | Assess applicable US state laws and selling/sharing/targeted-ad definitions, including vendor purposes and applicable thresholds. Add opt-out, appeal, universal-signal handling, or other notices where required. Review other intended countries, including language, children, transfers, and local-representative requirements. This draft is not a worldwide compliance passport. |
| Website and publication | Separately inventory the eventual website's cookies, analytics, forms, and vendors. Publish the final policy as a public readable web page; place its link in the game and store listings. Remove the draft banner, internal review link, and all review placeholders only after the underlying work is complete. |

The representative requirement is separate from hosting, a data-protection officer, and a privacy
contact email. The [ICO representative guidance](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/international-transfers/receiving-personal-information-from-the-eea/)
describes the UK exception and publication of representative contacts; the
[EDPB territorial-scope guidance](https://www.edpb.europa.eu/system/files/documents/files/file1/edpb_guidelines_3_2018_territorial_scope_after_public_consultation_en_1.pdf)
addresses the EU assessment. The draft preserves both contact fields pending that assessment.

## Evidence and important qualifications

| Draft area | Repository evidence | Qualification for the final text |
| --- | --- | --- |
| Data inventory and retention | [Canonical backend privacy inventory](../../../sorting-puzzle-backend/docs/PRIVACY_RETENTION.md) | Includes pseudonymous account, device, gameplay, country, purchase, privacy, security, and operational records. Hashing/encryption does not automatically anonymize them. Support mailbox and website processing require separate inventories. |
| Production hosting | [Backend deployment](../../../sorting-puzzle-backend/docs/DEPLOYMENT.md) | Planned region is `europe-west3` in separate development/production projects. Verify deployed locations and contractual/global access; do not claim all data stays in the EU. |
| Account deletion | [Client implementation and release gates](../ACCOUNT_DELETION_PLAN.md), [backend deletion](../../../sorting-puzzle-backend/docs/ACCOUNT_DELETION.md) | In-app deletion is implemented with emulator/local-backend evidence. Registered guests are eligible. Acceptance revokes access and leaderboard visibility; asynchronous cleanup has a 30-day deadline, followed by up to 35 days of backup residuals. The external website is separate work. |
| Data access/export | [Backend export](../../../sorting-puzzle-backend/docs/PLAYER_DATA_EXPORT.md) | Device-bound export is implemented; generated server documents expire within 72 hours. A public client export UI and secure support fulfillment are not established by that API. Ordinary support cannot read export documents. |
| Rewarded ads | [Approved launch baseline](../ADS_001_PRODUCT_POLICY_AND_PROVIDER.md), `scripts/ads/admob_provider.gd` | Non-personalized only, optional rewarded formats, no launch interstitials or mediation. Reward verification uses a nonce and an empty provider user ID. Older “no integration” prose in the decision record is stale; actual native release behavior still needs verification. |
| Privacy controls | `scripts/production_main_menu.gd`, `scripts/ads/ad_service.gd` | Settings shows Privacy Choices when UMP requires it, otherwise the configured Privacy Policy link. When Choices is present, verify the final policy remains independently accessible in the app, as stores require. |
| Support | `scripts/support_contact.gd`, `scripts/support_screen.gd`, `project.godot` | Support opens an email app. The `.example` default is a placeholder, and no support vendor or mailbox retention period has been supplied. |
| Public profiles | `scripts/leaderboards/backend_leaderboard_provider.gd`, `scripts/leaderboard_row.gd`, backend privacy inventory | Name/avatar/frame/score/rank are displayed. Country-group membership can indicate country; do not claim precise location or a separately visible country field without checking the released UI. |

### Retention commitments need operational proof

The canonical policy defines periods for more classes than its currently described cleanup worker
implements. It explicitly leaves immutable synchronization-history compaction pending a reviewed
implementation. Before publication, verify enforcement for every promised limit, including long
purchase/security/audit lifetimes; do not equate a documented number with deployed deletion.

The deployment document requires scheduled worker execution **at least hourly** before production
for retention, deletion, and exports. Verify overdue alerts and restoration of deletion tombstones.
The deletion workflow retains some encrypted platform transaction identifiers, so “all remaining
records are anonymous” would be inaccurate. The draft deliberately discloses that limitation.

Current active-account retention has no specified inactivity deadline. Establish that rule and
its necessity. Restrict retained evidence to its stated purpose after account deletion. Do not
introduce indefinite exceptions or describe the unimplemented generic hold store as operational.

### Advertising disclosures must match the pinned build

The decision record pins Android GMA Next-Gen `1.4.0`, iOS Google Mobile Ads `13.9.0`, and iOS UMP
`3.1.0` via Poing Studios `v5.1.0`. Google's disclosure pages describe SDK behavior and, on Android,
the latest version rather than guaranteeing that exact pinned artifact's behavior. Inspect the
actual archive, manifest, iOS privacy manifest, network behavior, settings, and optional features.

The [Android Next-Gen data disclosure](https://developers.google.com/admob/android/next-gen/privacy/play-data-disclosure)
lists IP/general location, interactions, diagnostics, and identifiers; advertising-ID collection
is configurable. The [iOS data disclosure](https://developers.google.com/admob/ios/privacy/data-disclosure)
also requires checking the app's configuration. Non-personalized delivery does not mean zero
personal data or automatically remove consent requirements; see
[Google's non-personalized ads guidance](https://support.google.com/admob/answer/7676680?hl=en).
These are vendor data statements, not evidence that the game's release already enforces its plan.

Do not check “no tracking,” “no sharing,” or “no collection” in store forms merely because the
publisher avoids behavioral analytics or requests contextual ads. Store definitions and legal
selling/sharing definitions require separate assessments of the complete SDK and vendor behavior.

## Primary legal and store sources

Sources checked for this draft on **2026-10-08**. Recheck requirements against the release date.

- [Ukraine Law on Personal Data Protection](https://zakon.rada.gov.ua/laws/show/2297-17): review
  collection notices, individual rights, legal grounds, and foreign transfers, including Articles
  8, 11, 12, and 29. The direct page was inaccessible to the browsing tool; official-site search
  excerpts were available. Obtain and check the full current text in the legal review.
- [ICO privacy-information guidance](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/the-right-to-be-informed/what-privacy-information-should-we-provide/):
  notice content covers operator/contact details, purposes and bases, recipients, transfers,
  retention, and rights. Verify current UK changes where the ICO marks guidance under review.
- [ICO international-transfer guidance](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/international-transfers/a-brief-guide-to-international-transfers/):
  assess each relevant disclosure/access arrangement and the applicable safeguard; do not use
  blanket “by playing you consent to overseas transfers” language.
- [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en):
  the privacy policy must cover the app's actual data handling, including SDKs, contacts,
  retention, and deletion. Its link must be publicly accessible; a repository Markdown file or
  PDF alone is not the required published page.
- [Google account-deletion guidance](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en):
  applicable accounts need a functional outside-app request route, even with in-app deletion.
  A clear request email or form can be part of that route.
- [Apple App Review privacy rules](https://developer.apple.com/app-store/review/guidelines/#privacy)
  and [Apple account-deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion):
  verify in-app policy access and account deletion, including guest accounts.
- [FTC COPPA guidance](https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions):
  use the amended rule and current guidance when assessing US child-directed or known-under-13
  processing. A generic children's paragraph does not implement parental consent or SDK controls.
- [ICO Children's Code scope](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/childrens-information/childrens-code-guidance-and-resources/age-appropriate-design-a-code-of-practice-for-online-services/services-covered-by-this-code/):
  assess likely access by under-18s for a UK launch, even if the game is described as general
  audience. Child-directed status and likely access are different tests.

## Publication checklist

1. Resolve every placeholder and record the approved country/feature scope.
2. Verify the release data inventory and retention enforcement, including infrastructure and vendors.
3. Test privacy-choice access, policy access, external deletion, in-app deletion, and privacy-request
   handling with the real contacts and production-equivalent configuration.
4. Reconcile Google Play Data safety and App Store privacy answers with the final policy and build.
5. Complete the applicable jurisdiction review, then publish a stable web version and configure
   the game's policy URL. Keep a dated copy of each published version.

This documentation task changes no runtime configuration, store disclosures, or backend behavior.
The existing [legal-document research](../LEGAL_DOCUMENTS_RESEARCH.md) remains broader background;
its implementation-status observations dated 2026-10-01 are superseded by the evidence above.
