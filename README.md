# windmill-oss-build

Builds an open-source (AGPLv3) Windmill server/worker image from the upstream
source at a pinned tag, without any enterprise or private code.

| Item | Value |
| --- | --- |
| Upstream | https://github.com/windmill-labs/windmill |
| Tag / commit | see `UPSTREAM` |
| Cargo features | `oss_core,python` (no `enterprise`, no `private`, no `no_auth`) |
| Languages | Python and TypeScript (Bun) |
| Output | `ghcr.io/<owner>/windmill-oss:<tag>-oss.<run number>` |

The upstream `Dockerfile` is used unchanged. The workflow only:

1. checks out the pinned upstream commit and verifies it matches `UPSTREAM`;
2. builds with `--build-arg features=oss_core,python`;
3. smoke-tests the image (version string, `/api/version`, unauthenticated
   API returns 401 so `no_auth` is not compiled in);
4. pushes to GHCR only if the smoke test passes, and records the digest.

The workflow runs only on manual dispatch. It uses the built-in
`GITHUB_TOKEN` and no other secrets.

To upgrade, change `UPSTREAM` to a new tag and commit, then run the workflow.
