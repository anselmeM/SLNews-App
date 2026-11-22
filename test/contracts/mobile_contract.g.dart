// ignore_for_file: prefer_single_quotes
// GENERATED FILE — do not edit by hand.
// Source: SLNews-Web/contracts/openapi.json and contracts/fixtures/.
// Regenerate from the Web repo with:
//   node contracts/scripts/generate-dart-contract.mjs
//
// The App contract test imports these values so the fixture cannot silently
// drift when the Web OpenAPI contract changes.

const Set<String> adUnitContractFields = <String>{
  "advertiser",
  "altText",
  "assetLabel",
  "body",
  "brandAccentHex",
  "brandHex",
  "ctaLabel",
  "disclosure",
  "eventToken",
  "eventTokenExpiresAt",
  "headline",
  "id",
  "imageUrl",
  "placement",
  "targetUrl",
};

const Set<String> adUnitRequiredFields = <String>{
  "advertiser",
  "body",
  "brandAccentHex",
  "brandHex",
  "ctaLabel",
  "headline",
  "id",
  "placement",
};

const Map<String, dynamic> adUnitContractFixture = <String, dynamic>{
  "id": "sp_contract_fixture",
  "placement": "feed",
  "advertiser": "Contract Partner",
  "headline": "CONTRACT FIXTURE",
  "body": "One canonical AdUnit shape",
  "ctaLabel": "Open",
  "brandHex": "#0B6FD1",
  "brandAccentHex": "#2E9BF5",
  "assetLabel": "NLe 20",
  "disclosure": "Sponsored by Contract Partner",
  "imageUrl":
      "https://store.public.blob.vercel-storage.com/sponsorships/contract.jpg",
  "altText": "Contract Partner logo",
  "targetUrl": "https://example.com/offer",
  "eventToken": "signed-event-token",
  "eventTokenExpiresAt": "2026-11-22T00:00:00.000Z",
};

const Set<String> eventRequestContractFields = <String>{
  "eventId",
  "id",
  "token",
  "type",
};

const Map<String, dynamic> eventRequestContractFixture = <String, dynamic>{
  "id": "sp_contract_fixture",
  "type": "impression",
  "eventId": "ev_contract_fixture_0001",
  "token": "signed-event-token",
};
