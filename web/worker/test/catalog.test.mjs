// The web catalog must match the app's: same clause types in the same order, same parameter names.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { SPECS, typesFor } from "../src/catalog.js";

const swift = readFileSync(new URL("../../../FinePrintCore/Sources/FinePrintCore/ClauseCatalog.swift", import.meta.url), "utf8");
const models = readFileSync(new URL("../../../FinePrintCore/Sources/FinePrintCore/Models.swift", import.meta.url), "utf8");
const rawValue = (c) => (models.match(new RegExp(`case ${c} = "([a-z_]+)"`)) || [])[1] || c;

test("clause types match ClauseCatalog.swift, in order", () => {
  const swiftTypes = [...swift.matchAll(/\.init\(type: \.(\w+)/g)].map((m) => rawValue(m[1]));
  assert.deepEqual(SPECS.map((s) => s.type), swiftTypes);
});

test("parameter names match", () => {
  const swiftParams = [...swift.matchAll(/\("(\w+)", "/g)].map((m) => m[1]).sort();
  assert.deepEqual(SPECS.flatMap((s) => s.parameters.map(([n]) => n)).sort(), swiftParams);
});

test("a lease is checked for lease and universal clauses, not employment ones", () => {
  const t = typesFor("residential_lease");
  assert.ok(t.includes("pets") && t.includes("arbitration") && !t.includes("vacation"));
  assert.deepEqual(typesFor("unknown")[0], "non_compete");
});
