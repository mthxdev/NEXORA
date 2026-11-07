# SwiftData generation-store prototype

This is an isolated iOS 17 Swift package. It contains no Nexora model or business source. The tests use their own temporary stores; the default-container adoption test uses the prototype test runner's isolated app sandbox and never opens Nexora's container or files.

## What the prototype tests

- Creates N and N+1 at distinct explicit file URLs, stores separate records and generation markers, releases the creation scope, reopens both stores, and checks their data.
- Publishes a generation ID, verifies the manifest checksum and strict JSON shape, resolves the ID only through an independently configured `GenerationStoreCatalog`, opens the authorized URL, and verifies the persisted marker and records match the selected generation.
- Selects N and N+1 and rejects an unknown generation, duplicate URLs in the catalog, a mismatched generation-to-store association, and a URL field added to the manifest.
- Checks a missing manifest, malformed JSON, a valid-JSON payload change with the old checksum, and the expected explicit errors.
- Injects interruptions after writing staging data and after publishing the manifest. These are exception-injection tests at those boundaries.
- Publishes concurrently through two manifest-store instances that share a process-wide lock, then verifies the final manifest is a complete, checksum-valid selection.
- Hosts a SwiftUI `@Query` view with N, then replaces it with a view injected with N+1 and checks the displayed query values.
- Creates a default `ModelContainer`, records its configuration and URL, then reopens that URL using an explicit configuration and checks the saved test record.

Each temporary test directory is registered for teardown cleanup. The default-container test's store is in the isolated test runner sandbox rather than a temporary URL, because it specifically tests SwiftData's default location mechanism. The test runner is separate from the Nexora app and its data.

## What it does not test

- It does not reproduce Nexora's production container, entitlements, schema, migration plan, store URL, restore flow, or services.
- It does not validate migration of a real Nexora store or authorize a production generation switch.
- It does not simulate process termination in the middle of the atomic manifest write or a power failure. The file operation is not a transaction with SwiftData and does not establish power-loss durability.
- The serialization lock covers manifest operations within this process only; it does not coordinate another process or device.
- UI injection is tested on the simulator OS below, not on iOS 17 itself.

## Workflow and local command

The dedicated workflow `.github/workflows/swiftdata-generations.yml` uses `macos-15`, selects Xcode 16.4, and runs on `iPhone 16 / iOS Simulator 18.5`:

```sh
xcodebuild -scheme SwiftDataGenerationPrototype \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  -parallel-testing-enabled NO test
```

The package declares iOS 17 as its deployment target. The CI simulator runtime is iOS 18.5, so this prototype does not verify runtime behavior on iOS 17.

## Test status

No build or test has been executed in the current Windows environment. Results remain unverified until the dedicated GitHub Actions workflow runs successfully; no passing result is claimed. Even a successful CI run would validate only this isolated prototype, not a real Nexora migration.
