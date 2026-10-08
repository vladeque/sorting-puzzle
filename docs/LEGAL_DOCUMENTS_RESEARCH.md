# Legal documents and release requirements

Research date: **2026-10-01**.

Status: **research baseline; documents, jurisdiction review, and release approval remain pending**.

The owner confirmed a Ukrainian publisher and distribution in as many regions as practical.
Existing product decisions target Android and iOS, a general audience described internally as
3+, optional non-personalized AdMob ads, guest/platform accounts, cloud saves, leaderboards, and
one-time purchases. The 3+ description is an internal product baseline, not a verified rating
for every store or a legal determination about children.

This investigation identifies the common release package and important regional questions. It
does not clear every country for distribution or supply publishable legal text. Runtime behavior
and canonical backend requirements were not changed.

## Follow-up — 2026-10-08

An [English privacy policy draft](legal/PRIVACY_POLICY_DRAFT.md) and
[review notes](legal/PRIVACY_POLICY_REVIEW.md) are now available, with publisher details left as
placeholders. Neither is approved for publication. Since this research baseline, in-app account
deletion and backend data export have been implemented; production validation, worker scheduling,
public deletion access, and privacy-request handling still have release work. Use the review
notes for current evidence; implementation-status observations below describe 2026-10-01.

## Required documents versus settings actions

| Item | Status for this game | Suggested treatment |
| --- | --- | --- |
| Privacy Policy / Privacy Statement | Required by both stores, including when ads are disabled. | One clearly named Privacy Policy, on a public website and persistently accessible in the app. |
| Terms of Use / Terms of Service | Recommended contract for accounts, purchases, virtual goods, and service rules; not a universal requirement for a separately titled document in every casual game. | One game-specific document containing the software-license provisions. |
| EULA | Apple's standard EULA applies when no custom EULA is supplied. A separate custom document is optional. | Decide whether to retain Apple's default plus game-service terms, or use reviewed combined Terms of Use and EULA. |
| Legal Notes / Legal Notices / Licenses | The label itself is not a universal store requirement. Notices required by the actual dependency and asset licenses must be supplied. | A Legal & Licenses page containing the applicable notices and publisher information. |
| Publisher information | Required disclosures depend on business form and applicable commercial/store rules. | Publish the legal operator's identity and appropriate contact/registration details; link from the legal pages. |
| Delete Account | A functional account/data workflow, rather than a legal document. Required for the intended account-enabled release. | Discoverable in-app initiation plus a public deletion-request resource for Google Play. |
| Privacy Choices | Conditional consent-management control, separate from the privacy notice. | Show the UMP privacy-options action when required; keep the Privacy Policy link available independently. |
| Data access/export instructions | Support applicable privacy rights; a dedicated settings button is a product choice. | Explain a working request channel in the policy/support pages; connect it to secure fulfillment. |

Both stores require in-app policy access. Google additionally specifies a publicly accessible,
non-geofenced, non-editable web page rather than a PDF. Sources:
[Apple review guidelines, 5.1.1](https://developer.apple.com/app-store/review/guidelines/#privacy)
and [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en).

Apple confirms the default/custom license distinction in
[its EULA guidance](https://developer.apple.com/help/app-store-connect/manage-app-information/provide-a-custom-license-agreement/).
The checked shop catalog contains bundles and coin packs, not auto-renewing subscriptions.

Apple expressly includes automatically generated guest accounts in its deletion requirement.
Google requires an external route usable after uninstall; a working form or clearly explained
support request can qualify. Clearing a local save, signing out, or deactivating an account does
not fulfill server-account deletion. Sources:
[Apple account-deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
and [Google account-deletion guidance](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en).

Godot requires its license notice and appropriate notices for bundled third-party components.
The repository also includes Nunito and DynaPuff OFL texts and the Poing Studios plugin MIT
license. Audit the shipped engine, native dependencies, fonts, art, music, and sounds before
assembling the final notices. Source:
[Godot license-compliance guidance](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html).

## Content to prepare

### Privacy Policy

Describe the actual release's operator/contact, data categories and sources, purposes and lawful
bases, recipients and vendors, international processing/transfers and safeguards, retention,
security practices, applicable rights and complaint routes, consent withdrawal, children's
treatment, and effective date. Make deletion instructions, retained-data exceptions, and request
timing understandable. Source:
[ICO privacy-notice requirements](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/the-right-to-be-informed/what-privacy-information-should-we-provide/).

Build the game-specific inventory from the canonical
[backend privacy and retention policy](../../sorting-puzzle-backend/docs/PRIVACY_RETENTION.md),
then add client/native-SDK and support handling. Include guest/platform and installation
identifiers, profile/display name and coarse country, public leaderboard presentation,
progression and gameplay evidence, purchase/refund records, security/operational records,
AdMob processing, and support emails/attachments as applicable to the deployed release.

The backend's omission of raw IP persistence does not establish that a cloud infrastructure or
advertising vendor never processes IP addresses. Encrypted or linkable pseudonymous identifiers
also remain personal data. Source:
[European Commission GDPR scope and definitions](https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/application-gdpr_en?prefLang=nl).

The engineering inventory currently specifies some 2-, 7-, and 10-year retention windows and
restricted backup residuals. Those are existing engineering policies, not independently verified
statutory minimums for a Ukrainian publisher. Obtain a purpose-by-purpose legal justification
before promising those windows publicly. Do not promise complete immediate erasure or completed
export functionality that the production service cannot deliver.

### Terms of Use with license provisions

Recommended drafting scope: publisher identity; eligibility and parental responsibility where
appropriate; a limited software license; account/guest recovery; permitted conduct and
leaderboard/name moderation; anti-cheat enforcement and a support route; virtual coins and
abilities; purchases, refunds and reversals; deletion effects on progress and entitlements;
service changes/termination; mandatory consumer rights; disputes; and version/effective date.

Purchase terms should reflect actual one-time products and platform purchase processing.
Explain what the player receives before purchase, and substantiate discount/reference-price
claims. Do not use a blanket worldwide "no refunds" clause. EU digital-content withdrawal
exceptions have conditions, including prior express consent and acknowledgement, so hiding a
waiver in game terms is insufficient. Source:
[EU Consumer Rights Directive, Articles 14 and 16](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A02011L0083-20260927).

Terms acceptance and optional privacy consent need distinct designs. A privacy notice informs
the user; it is not blanket authorization for optional advertising processing. Decide and record
the legal basis for each purpose. Source:
[European Commission lawful-processing guidance](https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/legal-grounds-processing-data_en).

## Ukraine and international distribution

### Ukraine

Ukraine's personal-data law requires notice of the controller, collected data, purpose,
recipients, and rights; it also governs processing grounds and international transfers.
The Ukrainian policy should identify the actual publisher, not just the game's brand. Source:
[Law No. 2297-VI, especially Articles 8, 11, 12, and 29](https://zakon.rada.gov.ua/go/2297-17).

For applicable electronic commerce, Article 7 requires accessible seller identity,
address, email/site, registration/tax identification, and other relevant commercial information.
The precise disclosure set depends on whether the publisher is an individual entrepreneur or
company and its contractual role relative to the stores. Source:
[Law No. 675-VIII](https://zakon.rada.gov.ua/laws/show/675-19).

Businesses selling goods/services in Ukraine must provide a Ukrainian version of their mobile
app interface. Plan Ukrainian UI and legal/consumer-facing text alongside the international
English documents; a Ukrainian UI requirement is not satisfied by an English policy alone.
Confirm the website and consumer-language obligations for the publishing arrangement. Source:
[State-language law, particularly Articles 27 and 30](https://zakon.rada.gov.ua/go/2704-19).

The digital-content/service contract also needs Ukrainian consumer-law review. Relevant law:
[Law No. 3321-IX on digital content and digital services](https://zakon.rada.gov.ua/laws/show/3321-20).

### EU/EEA and UK

Being based in Ukraine does not exclude GDPR coverage when offering the game to people in the
EU. A small/free service is not automatically exempt. See the
[European Commission scope guidance](https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/application-gdpr_en?prefLang=nl).

Assess EU and UK representative appointments before launch. Relevant exemptions include
occasional, low-risk processing; ongoing account/cloud-save operation is a reason to examine
that exception carefully, not assume it applies. This is a project-specific assessment still
pending. Representative contacts belong in the policy where applicable. Sources:
[EDPB territorial-scope guidance](https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-32018-territorial-scope-gdpr-article-3-version_en)
and [ICO representative guidance](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/international-transfers/receiving-personal-information-from-the-eea/).

Document vendor/processor contracts and applicable transfer safeguards internally. They are
separate from the settings documents. Also complete Apple's EU trader verification and public
address/phone/email disclosures where the publisher is a trader. Source:
[Apple EU trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/).

### Advertising and children

Non-personalized ads still use data/local storage for purposes such as frequency capping and
reporting. Applicable consent requirements can remain. Source:
[Google's explanation of non-personalized ads](https://support.google.com/admob/answer/7676680?hl=en).
UMP manages the relevant privacy forms and their reopening entry point; it does not replace the
game's comprehensive policy. Source:
[Google UMP integration guidance](https://developers.google.com/admob/android/privacy).

The general-audience decision must be checked against intended audience, artwork, marketing,
and actual knowledge about under-13 users. A low content rating, a "13+" sentence in terms, or
avoiding birth-date collection does not by itself resolve US COPPA classification. If COPPA
applies, children's notices, parent-facing controls and verifiable consent requirements may
change the product, not just its documents. Use the amended rule rather than an old template.
Sources: [FTC COPPA guidance](https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions)
and [FTC rule amendments](https://www.ftc.gov/news-events/news/press-releases/2025/01/ftc-finalizes-changes-childrens-privacy-rule-limiting-companies-ability-monetize-kids-data).

### United States and remaining markets

CCPA-specific rights and sale/sharing controls depend on coverage and actual processing; do not
add a "Do Not Sell or Share" label without assessing those facts. Revenue and data-activity
thresholds matter; the inflation-adjusted revenue threshold for 2025/2026 is $26,625,000,
not the older $25 million figure still present in some summaries. Sources:
[California AG CCPA overview](https://oag.ca.gov/privacy/ccpa)
and [CPPA threshold update](https://www.cppa.ca.gov/regulations/cpi_adjustment.html).
California's broader online privacy-policy obligations also cover qualifying mobile apps;
CCPA exemption alone is not a privacy-policy exemption. Source:
[California AG CalOPPA guidance](https://oag.ca.gov/system/files/attachments/press_releases/CalOPPA%20Letter_0.pdf).

A shared core policy/terms package with appropriate regional sections and translations is a
practical starting point. A GDPR-oriented policy is not worldwide clearance. Brazil, Canada,
Australia, Japan, South Korea, Taiwan, Indonesia, Turkey, India, other US states, and other
selected territories still need screening for privacy, minors, consumer language, transfers,
local representation, and distribution rules. No country-by-country clearance for those
markets was performed in this investigation.

Mainland China is a concrete separate distribution gate: Apple identifies games missing an
NPPA approval number and supporting documents as unavailable there. Additional privacy text
does not satisfy that gate. Source:
[Apple country/submission status guidance](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses/).

## Current repository gaps and owners

| Finding | Current evidence | Follow-up owner/scope |
| --- | --- | --- |
| No configured public policy or real support contact | `project.godot`: empty `application/config/ad_privacy_policy_url`; support address uses `.example`. | Publisher-owned website/content and release configuration. |
| Policy access switches into a consent action | `scripts/production_main_menu.gd`, `_refresh_ad_compliance_actions()` and `_on_ad_privacy_requested()`; `scenes/ui/settings_menu.tscn`; documented in `ADS_008_COMPLIANCE_RELEASE_VALIDATION.md`. | Future client change: persistent policy access plus independent privacy choices. |
| No client deletion/export surface found | Search of `scripts/backend/*.gd` and `scripts/player_progress.gd`; current settings wiring. | Future client work integrated with approved backend operations. |
| Backend deletion/export/public request completion is not established | Canonical `IMPLEMENTATION_TICKETS.md` defines BE-607, BE-608, and BE-614; inspected app/package sources exposed schema/support references but no complete public deletion workflow. | Backend-owned implementation and verification; do not infer completion from table existence. |
| Ukrainian localization missing | `docs/LOCALIZATION.md` and `scripts/localization/locale_catalog.gd`: no `uk` locale; no translated interface catalogs yet. | Client localization plus reviewed Ukrainian legal/consumer content. |
| Release disclosure evidence incomplete | `configs/ad_release_evidence.json` and `docs/ADS_008_COMPLIANCE_RELEASE_VALIDATION.md`. | Publisher/store owner; validate exact released SDK/backend behavior. |
| License source texts exist but a complete player-facing notices package was not established | `assets/fonts/Nunito-OFL.txt`, `assets/fonts/DynaPuff-OFL.txt`, `addons/admob/LICENSE`. | Client/distribution dependency and asset audit. |

Backend retention remains owned by
[PRIVACY_RETENTION.md](../../sorting-puzzle-backend/docs/PRIVACY_RETENTION.md).
This document must not become a competing inventory or independently change those policies.

## Proposed settings and website package

Recommended settings entries:

- **Privacy Policy**: always accessible in the production game.
- **Terms of Use**: the reviewed service terms and chosen license arrangement.
- **Legal & Licenses**: publisher information and dependency/asset notices.
- **Privacy Choices**: independent consent-management action when applicable.
- **Delete Account**: clear confirmation, ownership verification, consequences, and request status.
- **Support**: real contact and privacy-rights request instructions.

Suggested public pages: `/privacy`, `/terms`, `/legal`, `/delete-account`, and `/support`.
Those are proposed routes, not deployed URLs. Keep app/developer naming consistent with store
listings; publish reviewed language versions and retain document version history.

Store declarations remain separate deliverables: Google's Data safety/Ads/target-audience
declarations and Apple's App Privacy/age-rating/trader information, plus applicable release
privacy manifests. The public policy must agree with the shipped app and SDKs. Sources:
[Google Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
and [Apple App Privacy guidance](https://developer.apple.com/app-store/app-privacy-details/).

## Decisions and next implementation sequence

1. Identify the Ukrainian legal publisher/business form and approved public contact details;
   select actual release territories and confirm the audience classification.
2. Inventory the exact release build, vendors, infrastructure, support handling, and data flows;
   review retention, representatives, transfers, and children's treatment.
3. Draft and obtain review of Privacy Policy, Terms/license provisions, publisher information,
   notices, and deletion/support instructions. Prepare Ukrainian and appropriate other languages.
4. Complete backend deletion/export and external request fulfillment, then implement the client
   settings/account flows through the approved boundaries. Backend changes require a separate
   explicitly scoped task and backend commit.
5. Publish functioning pages, configure real URLs/contact details, complete store disclosures,
   and verify the release's policy access, consent, deletion, and rights handling end to end.

The remaining legal work needs review by Ukrainian counsel familiar with international mobile
games. The central unresolved issues are publisher/business form, actual launch countries,
children's treatment, representative/transfer arrangements, and defensible retention periods.
