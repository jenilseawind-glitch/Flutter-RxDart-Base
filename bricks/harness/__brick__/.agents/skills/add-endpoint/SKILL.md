---
name: add-endpoint
description: Connects a backend API endpoint to this Flutter Redux + RxDart + Dio app the architecture's way - contract from Postman/OpenAPI, ApiConstants entry, transport-only repo method on ApiBaseHelper, defensive Model.fromJson, BLoC call with cancellation and typed ApiException handling, tests with the real response. Use when asked to call, integrate, consume, add or change an API, endpoint, request, upload or response model, or when a response shape, status:false, 422 or parsing error comes up.
---

# Add or change an endpoint

The data path is fixed: `ApiConstants` → repo (transport) → BLoC (parse + state) → widget (render). Each layer has one job, and three of the 🔒 lint rules guard the boundaries.

## 0. Load what this project learned
1. Read `.harness/skills/add-endpoint.md` if it exists: backend quirks and conventions already discovered here. It wins over this file.
2. Run `dart run scripts/agent/learn.dart list add-endpoint`.

## 1. Read the contract, don't guess it
Look for `*.postman_collection.json`, then OpenAPI/Swagger, then docs (`AGENTS.md` §3). Write down the method, path and path params, query params, request body, **one real success response**, and the error shape. No real response → ask for one. Never infer field names or types from the endpoint's name.

Check the contract against what the base does to every call:
- A top-level JSON array comes back as `{'items': [...]}`. An empty body becomes `{}`. A non-JSON body throws `MalformedResponseException`.
- HTTP 200/201 with `{"status": false, "message": ...}` becomes `BusinessLogicException`, and that message is shown to users verbatim.
- `PlatformInjectorInterceptor` adds `"platform": "app"` to every JSON body. A strict backend that rejects unknown fields fails with 400.
- Only GET/HEAD/OPTIONS/PUT/DELETE are retried (twice). POST is never retried, so make writes idempotent on the server or guard against double taps in the BLoC.
- The bearer token goes only to the `BASE_URL` host (same scheme, host and port). A 401 while signed in dispatches `LogoutAction` by itself.

## 2. Endpoint constant
Add the endpoint to `lib/networking/api_constants.dart`, following the commented pattern there:

```dart
static String get ordersEndpoint => '$baseUrl/orders';
static String orderEndpoint(String id) => '$baseUrl/orders/$id';
```

A third-party absolute URL (CDN, presigned upload) is fine and never receives the token.

## 3. Repo method: transport only (rule 1 🔒)
```dart
Future<Map<String, dynamic>> fetchOrders({
  required int page,
  CancelToken? cancelToken,
}) {
  return _api.get(
    ApiConstants.ordersEndpoint,
    queryParameters: {'page': page},
    cancelToken: cancelToken,
  );
}
```
- Return the raw `Map<String, dynamic>`. Never call `fromJson`/`fromMap` here, not even as a tear-off. `repo_transport_only` fails the gate.
- Always accept and forward `CancelToken? cancelToken`.
- `ApiBaseHelper` methods: `get`, `post`, `put`, `delete`, and `postFormData` / `putFormData` (multipart, with an `onSendProgress` callback). Put `MultipartFile` values in the form map.
- There is no `patch`. If the backend needs PATCH, add a `patch` method to `ApiBaseHelper` that mirrors `put` exactly. That changes shared networking, so say so in your summary.
- Let exceptions propagate. The repo never catches.

## 4. Model: defensive parsing (rule 12)
```dart
factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
  id: (json['id'] as num?)?.toInt() ?? 0,
  title: json['title']?.toString() ?? '',
  total: (json['total'] as num?)?.toDouble() ?? 0,
  placedAt: DateTime.tryParse(json['placed_at']?.toString() ?? ''),
  lines: (json['lines'] as List? ?? [])
      .whereType<Map<String, dynamic>>()
      .map(OrderLineModel.fromJson)
      .toList(),
);
```
- Never a bare `as String` / `as int` on wire data: one null or one `"12"` instead of `12` crashes the screen.
- Make a field nullable only when "absent" means something different from the default.
- Enums: map unknown values to an explicit fallback instead of throwing.
- Request bodies: the BLoC builds the map (or calls `model.toJson()`) and passes it to the repo.

## 5. BLoC call
- **Reads** mirror the generated `fetch({bool refresh = false})`. Call `createNewToken()` first, emit loading (unless refreshing over content), then `Model.fromJson`. Catch `RequestCancelledException` and do nothing. Catch `ApiException` and emit `ApiResponse.error(e, retry: fetch)`. Catch `Object` and wrap it in `MalformedResponseException`, never showing `e.toString()`.
- **Writes** (submit, delete, upload): guard double taps, don't auto-retry, and report the result through a state stream and/or a one-off event. The recipe is section A of `.agents/skills/manage-state/bloc-recipes.md`.
- **Several requests on one screen** share the BLoC's single cancel token. Calling `createNewToken()` in two independent methods cancels the other request. See section E of the recipes.

## 6. Tests with the real response
Copy the contract's success response into the BLoC test as a `const` map literal, then cover:
1. Real response → `SuccessResponse` with the fields parsed.
2. Missing and wrongly-typed fields → defaults, no throw.
3. `{'items': [...]}` when the endpoint returns a top-level array.
4. The relevant errors: a business error, a 422 message, a 404.

Use the generated `Fake<Feature>Repo` pattern. Details: `.agents/skills/write-tests/SKILL.md`.

## 7. Gate and close out
Run `dart run scripts/agent/verify.dart`, then close out per `AGENTS.md` §6. Record any backend quirk you found (date format, pagination style, an error field name) with `learn.dart add add-endpoint ...`, because the next endpoint on this backend will hit it too.

## Changing an existing endpoint
Find every caller first. Use the MCP `lsp` references or grep for the repo method and the `ApiConstants` getter. Update the model and its tests together. When a field is removed, keep parsing tolerant until the backend change has shipped everywhere.
